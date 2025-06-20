#!/bin/sh

# ================================================================
# OpenWrt 首次启动优化脚本（安全及自定义软件源版）
# 版本: 6.2
# 设备: HiWiFi HC5962 (mt7621)
# OpenWrt: 24.10.1
# 最后更新: 2025-06-20
# ================================================================

logger -t uci-defaults "开始执行首次启动优化脚本"
exec >/tmp/uci-defaults.log 2>&1

# 配置参数
wlan_name0="openwrt_2.4G"
wlan_name1="openwrt_5G"
wlan_password="aa12345678"
root_password="root"
lan_ip_address="192.168.2.1"
hostname="openwrt-wifi"

# 错误检查
check_status() {
    local status=$?
    if [ $status -ne 0 ]; then
        logger -t uci-defaults "错误: $1 失败 (状态码: $status)"
        return $status
    fi
    return 0
}

# 1. 设置 root 密码
if [ -n "$root_password" ]; then
    logger -t uci-defaults "设置 root 密码"
    (echo "$root_password"; sleep 1; echo "$root_password") | passwd root >/dev/null 2>&1
    check_status "设置 root 密码" || exit 1
fi

# 2. 配置 LAN 网络
if [ -n "$lan_ip_address" ]; then
    logger -t uci-defaults "配置 LAN IP: $lan_ip_address"
    uci set network.lan.ipaddr="$lan_ip_address"
    uci set network.lan.netmask="255.255.255.0"
    uci commit network
    check_status "配置 LAN 网络" || exit 1
fi

# 3. 配置无线网络，确保信号启用
configure_wireless() {
    logger -t uci-defaults "配置无线网络"
    # 2.4G
    if [ -n "$wlan_name0" ] && [ -n "$wlan_password" ] && [ ${#wlan_password} -ge 8 ]; then
        uci set wireless.radio0.disabled='0'
        uci set wireless.default_radio0.ssid="$wlan_name0"
        uci set wireless.default_radio0.encryption='sae-mixed'
        uci set wireless.default_radio0.key="$wlan_password"
        uci set wireless.radio0.country='CN'
    else
        uci set wireless.radio0.disabled='0'
    fi
    # 5G
    if [ -n "$wlan_name1" ] && [ -n "$wlan_password" ] && [ ${#wlan_password} -ge 8 ]; then
        uci set wireless.radio1.disabled='0'
        uci set wireless.default_radio1.ssid="$wlan_name1"
        uci set wireless.default_radio1.encryption='sae-mixed'
        uci set wireless.default_radio1.key="$wlan_password"
        uci set wireless.radio1.country='CN'
    else
        uci set wireless.radio1.disabled='0'
    fi
    uci commit wireless
    check_status "提交无线配置" || exit 1
}
configure_wireless

# 4. 内核网络参数优化（仅追加）
if ! grep -q "net.core.rmem_max" /etc/sysctl.conf; then
    logger -t uci-defaults "写入内核网络参数优化"
    cat << EOF >> /etc/sysctl.conf
# 优化参数
net.core.rmem_max=4194304
net.core.wmem_max=4194304
net.ipv4.tcp_rmem=4096 87380 4194304
net.ipv4.tcp_wmem=4096 16384 4194304
EOF
    sysctl -p >/dev/null
    check_status "应用内核优化" || true
fi


# 6. MT76 驱动优化脚本（如无则新建，内容最小化）
if [ ! -f /etc/hotplug.d/ieee80211/10-mt76-optimize ]; then
cat << 'EOF' > /etc/hotplug.d/ieee80211/10-mt76-optimize
#!/bin/sh
[ "$ACTION" = "add" ] || exit 0
sleep 1
for phy in /sys/kernel/debug/ieee80211/phy*; do
    iw phy "$(basename "$phy")" info | grep -q "mt76" || continue
    [ -f "$phy/mt76/tx_queues" ] && echo 4 > "$phy/mt76/tx_queues"
done
exit 0
EOF
chmod +x /etc/hotplug.d/ieee80211/10-mt76-optimize
fi

# 7. 设置主机名和时区
logger -t uci-defaults "配置系统设置"
[ -n "$hostname" ] && uci set system.@system[0].hostname="$hostname"
uci set system.@system[0].zonename='Asia/Shanghai'
uci set system.@system[0].timezone='CST-8'
uci commit system
check_status "配置系统设置" || exit 1

# 8. 替换 opkg 软件源，不执行 opkg update
logger -t uci-defaults "替换软件源"
if ! grep -q "mirrors.tuna.tsinghua.edu.cn" /etc/opkg/distfeeds.conf; then
    sed -i 's_https\?://downloads.openwrt.org_https://mirrors.tuna.tsinghua.edu.cn/openwrt_' /etc/opkg/distfeeds.conf
    check_status "替换软件源" || exit 1
else
    logger -t uci-defaults "软件源已配置，跳过"
fi

# 9. 逐步重启网络和无线
logger -t uci-defaults "重启网络服务"
/etc/init.d/network restart
sleep 3
logger -t uci-defaults "重启无线"
/sbin/wifi up || true

logger -t uci-defaults "首次启动优化脚本完成"
touch /etc/uci-defaults-complete

exit 0
