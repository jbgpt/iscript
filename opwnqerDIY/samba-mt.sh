#!/bin/sh

# 设置变量
# 设置变量
wlan_name0="openwrt_2.4G"
wlan_name1="openwrt_5G"
wlan_password="aa12345678"
root_password="root"
lan_ip_address="192.168.2.1"
hostname="openwrt-wifi"

# 记录潜在错误
exec >/tmp/setup.log 2>&1

# 设置管理员密码
if [ -n "$root_password" ]; then
  (echo "$root_password"; sleep 1; echo "$root_password") | passwd > /dev/null
fi

# 配置LAN
if [ -n "$lan_ip_address" ]; then
  uci set network.lan.ipaddr="$lan_ip_address"
  uci set network.lan.netmask="255.255.255.0"
  uci commit network
fi

# 配置WLAN
if [ -n "$wlan_name0" -a -n "$wlan_password" -a ${#wlan_password} -ge 8 ]; then
  uci set wireless.radio0.disabled='0'
  uci set wireless.radio0.htmode='HT40'
  uci set wireless.radio0.channel='auto'
  uci set wireless.radio0.cell_density='0'
  uci set wireless.default_radio0.ssid="$wlan_name0"
  uci set wireless.default_radio0.encryption='sae-mixed'
  uci set wireless.default_radio0.key="$wlan_password"
fi

if [ -n "$wlan_name1" -a -n "$wlan_password" -a ${#wlan_password} -ge 8 ]; then
  uci set wireless.radio1.disabled='0'
  uci set wireless.radio1.htmode='VHT80'
  uci set wireless.radio1.channel='auto'
  uci set wireless.radio1.cell_density='0'
  uci set wireless.default_radio1.ssid="$wlan_name1"
  uci set wireless.default_radio1.encryption='sae-mixed'
  uci set wireless.default_radio1.key="$wlan_password"
fi

uci commit wireless
# ==================== 内核网络加速优化 ======================
optimize_kernel_network() {
    logger -t uci-defaults "优化内核网络参数"
    
    # 检查是否已优化
    if grep -q "net.core.rmem_max" /etc/sysctl.conf; then
        logger -t uci-defaults "内核优化已存在，跳过"
        return 0
    fi
    
    # 内核网络参数优化 (减少延迟，提升吞吐量)
    cat << EOF >> /etc/sysctl.conf
# 无线优化参数
net.core.rmem_max=4194304
net.core.wmem_max=4194304
net.ipv4.tcp_rmem=4096 87380 4194304
net.ipv4.tcp_wmem=4096 16384 4194304
net.netfilter.nf_conntrack_acct=1
net.netfilter.nf_conntrack_checksum=0
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_mtu_probing=1
net.ipv4.tcp_fastopen=3
net.core.netdev_budget=600
net.core.netdev_max_backlog=3000
EOF
    
    # 立即应用优化
    sysctl -p >/dev/null
    check_status "应用内核优化" || return 1
    
    logger -t uci-defaults "内核网络优化完成"
    return 0
}

optimize_kernel_network || exit 1
# 设置主机名
if [ -n "$hostname" ]; then
  uci set system.@system[0].hostname="$hostname"
  uci commit system
fi
# ==================== MT76驱动深度优化 =====================
optimize_mt76_driver() {
    logger -t uci-defaults "应用MT76驱动深度优化"
    
    # 检查是否已存在优化脚本
    if [ -f /etc/hotplug.d/ieee80211/10-mt76-optimize ]; then
        logger -t uci-defaults "MT76优化脚本已存在，跳过"
        return 0
    fi
    
    # 创建驱动优化脚本
    cat << 'EOF' > /etc/hotplug.d/ieee80211/10-mt76-optimize
#!/bin/sh

[ "$ACTION" = "add" ] || exit 0

# 等待接口完全初始化
sleep 1

# 为每个无线接口应用优化
for phy in /sys/kernel/debug/ieee80211/phy*; do
    phy_name=$(basename "$phy")
    
    # 检查是否MT76驱动
    if ! iw phy "$phy_name" info | grep -q "mt76"; then
        continue
    fi
    
    # 调整中断平衡 (减少CPU占用)
    [ -f "$phy/mt76/tx_queues" ] && echo 4 > "$phy/mt76/tx_queues"
    [ -f "$phy/mt76/tx_queues/ac0/qlen" ] && echo 1024 > "$phy/mt76/tx_queues/ac0/qlen"
    [ -f "$phy/mt76/tx_queues/ac1/qlen" ] && echo 1024 > "$phy/mt76/tx_queues/ac1/qlen"
    [ -f "$phy/mt76/tx_queues/ac2/qlen" ] && echo 2048 > "$phy/mt76/tx_queues/ac2/qlen"
    
    # 启用硬件加密加速 (提升性能)
    [ -f "$phy/mt76/agc" ] && echo 1 > "$phy/mt76/agc"
    
    # 优化重传设置 (减少丢包)
    [ -f "$phy/mt76/retries" ] && echo 16 > "$phy/mt76/retries"
    [ -f "$phy/mt76/ampdu_density" ] && echo 8 > "$phy/mt76/ampdu_density"
    
    # 智能功率控制 (根据频段调整)
    freq_range=$(iw phy "$phy_name" info | grep -E 'MHz' | awk '{print $2}' | head -1)
    if [ "$freq_range" -gt 5000 ]; then
        # 5GHz 接口 (提高功率)
        iw phy "$phy_name" set txpower fixed 23
    else
        # 2.4GHz 接口 (标准功率)
        iw phy "$phy_name" set txpower fixed 20
    fi
    
    # 禁用节能模式 (提升稳定性)
    for dev in /sys/class/ieee80211/"$phy_name"/device/net/*; do
        dev_name=$(basename "$dev")
        iw dev "$dev_name" set power_save off
    done
    
    # 启用A-MSDU和A-MPDU聚合 (提升吞吐量)
    iw phy "$phy_name" set ampdu_density 8
    iw phy "$phy_name" set ampdu_factor 4
    iw phy "$phy_name" set a_msdu enable
done

logger -t mt76-optimize "MT76驱动优化已应用"
exit 0
EOF

    chmod +x /etc/hotplug.d/ieee80211/10-mt76-optimize
    logger -t uci-defaults "MT76驱动优化脚本已安装"
    
    # 立即执行一次优化
    if [ -d /sys/kernel/debug/ieee80211 ]; then
        logger -t uci-defaults "立即应用MT76优化"
        /etc/hotplug.d/ieee80211/10-mt76-optimize
    fi
    
    return 0
}

optimize_mt76_driver || exit 1
# 设置时区
uci set system.@system[0].zonename='Asia/Shanghai'
uci set system.@system[0].timezone='CST-8'


# 重启网络服务
/etc/init.d/network restart

# 重启无线网络服务
wifi up

#设置本机防火墙
uci add firewall rule 
uci set firewall.@rule[-1].name='Allow_Local'
uci set firewall.@rule[-1].family='ipv6'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].dest_port='22 18080 18443'
uci set firewall.@rule[-1].target='ACCEPT'

#设置WireGuard区域防火墙
uci add firewall rule 
uci set firewall.@rule[-1].name='Allow_VPN'
uci set firewall.@rule[-1].family='ipv6'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].dest_port='52080'
uci set firewall.@rule[-1].target='ACCEPT'

#设置LAN转发
uci add firewall rule 
uci set firewall.@rule[-1].name='Allow_LAN'
uci set firewall.@rule[-1].family='ipv6'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].dest='lan'
uci set firewall.@rule[-1].dest_port='22 8006 8069 9090 18080 18443'
uci set firewall.@rule[-1].target='ACCEPT'

#添加uhttpd监听端口
uci add_list uhttpd.main.listen_http='[::]:18080'
uci add_list uhttpd.main.listen_https='[::]:18443'
sed -i 's_https\?://downloads.openwrt.org_https://mirrors.tuna.tsinghua.edu.cn/openwrt_' /etc/opkg/distfeeds.conf

echo "All done!"
