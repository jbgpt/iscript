#!/bin/sh

# ================================================================
# OpenWrt 首次启动优化脚本（极简日志+缓存清理版）
# 设备: HiWiFi HC5962 (mt7621)
# OpenWrt: 24.10.1
# 最后更新: 2025-06-20
# 功能: 基本系统优化 + 日志清理 + 缓存清理（仅首次启动执行，无定时/后台）
# ================================================================

logger -t uci-defaults "开始执行首次启动配置脚本"
exec >/tmp/uci-defaults.log 2>&1

# 设置变量
wlan_name0="openwrt_2.4G"
wlan_name1="openwrt_5G"
wlan_password="aa12345678"
root_password="root"
lan_ip_address="192.168.2.1"
hostname="openwrt-wifi"

# 错误检查函数
check_status() {
    local status=$?
    if [ $status -ne 0 ]; then
        logger -t uci-defaults "错误: $1 失败 (状态码: $status)"
        {
            echo "===== 调试信息 ====="
            date
            echo "失败命令: $1"
            uci changes
            logread | tail -n 20
            echo "===================="
        } >> /tmp/uci-defaults-debug.log
        return $status
    fi
    return 0
}

# 1. 基础系统配置 =============================================

# 设置 root 密码
if [ -n "$root_password" ]; then
    logger -t uci-defaults "设置 root 密码"
    (echo "$root_password"; sleep 1; echo "$root_password") | passwd root >/dev/null 2>&1
    check_status "设置 root 密码" || exit 1
fi

# 配置 LAN 网络
if [ -n "$lan_ip_address" ]; then
    logger -t uci-defaults "配置 LAN IP: $lan_ip_address"
    uci set network.lan.ipaddr="$lan_ip_address"
    uci set network.lan.netmask="255.255.255.0"
    uci commit network
    check_status "配置 LAN 网络" || exit 1
fi

# 配置无线网络
configure_wireless() {
    logger -t uci-defaults "配置无线网络"
    if [ -n "$wlan_name0" ] && [ -n "$wlan_password" ] && [ ${#wlan_password} -ge 8 ]; then
        uci set wireless.radio0.disabled='0'
        uci set wireless.radio0.htmode='HT40'
        uci set wireless.radio0.channel='auto'
        uci set wireless.radio0.cell_density='0'
        uci set wireless.default_radio0.ssid="$wlan_name0"
        uci set wireless.default_radio0.encryption='sae-mixed'
        uci set wireless.default_radio0.key="$wlan_password"
        uci set wireless.radio0.country='CN'
       # uci set wireless.radio0.distance='1000'
        uci set wireless.radio0.frag_threshold='2346'
        uci set wireless.radio0.rts_threshold='2347'
        uci set wireless.default_radio0.disassoc_low_ack='0'
        uci set wireless.default_radio0.wmm='1'
        uci set wireless.default_radio0.legacy_rates='0'
    fi
    if [ -n "$wlan_name1" ] && [ -n "$wlan_password" ] && [ ${#wlan_password} -ge 8 ]; then
        uci set wireless.radio1.disabled='0'
        uci set wireless.radio1.htmode='VHT80'
        uci set wireless.radio1.channel='auto'
        uci set wireless.radio1.cell_density='0'
        uci set wireless.default_radio1.ssid="$wlan_name1"
        uci set wireless.default_radio1.encryption='sae-mixed'
        uci set wireless.default_radio1.key="$wlan_password"
        uci set wireless.radio1.country='CN'
        uci set wireless.radio1.distance='1000'
        uci set wireless.radio1.frag_threshold='2346'
        uci set wireless.radio1.rts_threshold='2347'
        uci set wireless.default_radio1.disassoc_low_ack='0'
        uci set wireless.default_radio1.wmm='1'
        uci set wireless.default_radio1.legacy_rates='0'
    fi
    uci commit wireless
    check_status "提交无线配置" || exit 1
}
configure_wireless

# 内核网络加速优化
optimize_kernel_network() {
    logger -t uci-defaults "优化内核网络参数"
    if grep -q "net.core.rmem_max" /etc/sysctl.conf; then
        logger -t uci-defaults "内核优化已存在，跳过"
        return 0
    fi
    cat << EOF >> /etc/sysctl.conf
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
    sysctl -p >/dev/null
    check_status "应用内核优化" || return 1
    logger -t uci-defaults "内核网络优化完成"
    return 0
}
optimize_kernel_network || exit 1

# wwan防火墙
configure_wwan_firewall() {
    logger -t uci-defaults "配置通用wwan转发规则"
    if uci get firewall.@zone[0] | grep -q 'wwan'; then
        logger -t uci-defaults "wwan区域已存在，跳过"
        return 0
    fi
    uci add firewall zone
    uci set firewall.@zone[-1].name='wwan'
    uci set firewall.@zone[-1].input='ACCEPT'
    uci set firewall.@zone[-1].output='ACCEPT'
    uci set firewall.@zone[-1].forward='ACCEPT'
    uci set firewall.@zone[-1].network='wwan'
    uci set firewall.@zone[-1].masq='1'
    uci add firewall forwarding
    uci set firewall.@forwarding[-1].src='lan'
    uci set firewall.@forwarding[-1].dest='wwan'
    uci add firewall rule
    uci set firewall.@rule[-1].name='Allow-DNS-Forward'
    uci set firewall.@rule[-1].src='lan'
    uci set firewall.@rule[-1].dest='wwan'
    uci set firewall.@rule[-1].proto='tcpudp'
    uci set firewall.@rule[-1].dest_port='53'
    uci set firewall.@rule[-1].target='ACCEPT'
    uci add firewall rule
    uci set firewall.@rule[-1].name='Allow-ICMP'
    uci set firewall.@rule[-1].proto='icmp'
    uci set firewall.@rule[-1].target='ACCEPT'
    uci add firewall rule
    uci set firewall.@rule[-1].name='Allow-DHCP'
    uci set firewall.@rule[-1].proto='udp'
    uci set firewall.@rule[-1].src_port='67-68'
    uci set firewall.@rule[-1].dest_port='67-68'
    uci set firewall.@rule[-1].target='ACCEPT'
    uci commit firewall
    check_status "配置wwan防火墙规则" || return 1
    logger -t uci-defaults "防火墙规则配置完成"
    return 0
}
configure_wwan_firewall || exit 1

# MT76驱动优化脚本
optimize_mt76_driver() {
    logger -t uci-defaults "应用MT76驱动深度优化"
    if [ -f /etc/hotplug.d/ieee80211/10-mt76-optimize ]; then
        logger -t uci-defaults "MT76优化脚本已存在，跳过"
        return 0
    fi
    cat << 'EOF' > /etc/hotplug.d/ieee80211/10-mt76-optimize
#!/bin/sh
[ "$ACTION" = "add" ] || exit 0
sleep 1
for phy in /sys/kernel/debug/ieee80211/phy*; do
    phy_name=$(basename "$phy")
    if ! iw phy "$phy_name" info | grep -q "mt76"; then continue; fi
    [ -f "$phy/mt76/tx_queues" ] && echo 4 > "$phy/mt76/tx_queues"
    [ -f "$phy/mt76/tx_queues/ac0/qlen" ] && echo 1024 > "$phy/mt76/tx_queues/ac0/qlen"
    [ -f "$phy/mt76/tx_queues/ac1/qlen" ] && echo 1024 > "$phy/mt76/tx_queues/ac1/qlen"
    [ -f "$phy/mt76/tx_queues/ac2/qlen" ] && echo 2048 > "$phy/mt76/tx_queues/ac2/qlen"
    [ -f "$phy/mt76/agc" ] && echo 1 > "$phy/mt76/agc"
    [ -f "$phy/mt76/retries" ] && echo 16 > "$phy/mt76/retries"
    [ -f "$phy/mt76/ampdu_density" ] && echo 8 > "$phy/mt76/ampdu_density"
    freq_range=$(iw phy "$phy_name" info | grep -E 'MHz' | awk '{print $2}' | head -1)
    if [ "$freq_range" -gt 5000 ]; then
        iw phy "$phy_name" set txpower fixed 23
    else
        iw phy "$phy_name" set txpower fixed 20
    fi
    for dev in /sys/class/ieee80211/"$phy_name"/device/net/*; do
        dev_name=$(basename "$dev")
        iw dev "$dev_name" set power_save off
    done
    iw phy "$phy_name" set ampdu_density 8
    iw phy "$phy_name" set ampdu_factor 4
    iw phy "$phy_name" set a_msdu enable
done
logger -t mt76-optimize "MT76驱动优化已应用"
exit 0
EOF
    chmod +x /etc/hotplug.d/ieee80211/10-mt76-optimize
    logger -t uci-defaults "MT76驱动优化脚本已安装"
    if [ -d /sys/kernel/debug/ieee80211 ]; then
        logger -t uci-defaults "立即应用MT76优化"
        /etc/hotplug.d/ieee80211/10-mt76-optimize
    fi
    return 0
}
optimize_mt76_driver || exit 1

# 设置主机名和时区
logger -t uci-defaults "配置系统设置"
if [ -n "$hostname" ]; then
    uci set system.@system[0].hostname="$hostname"
fi
uci set system.@system[0].zonename='Asia/Shanghai'
uci set system.@system[0].timezone='CST-8'
uci commit system
check_status "配置系统设置" || exit 1

# 网络服务重启
logger -t uci-defaults "重启网络服务"
/etc/init.d/network restart
sleep 5
logger -t uci-defaults "重启无线服务"
wifi up
sleep 3

# 软件源配置
logger -t uci-defaults "配置软件源"
if ! grep -q "mirrors.tuna.tsinghua.edu.cn" /etc/opkg/distfeeds.conf; then
    sed -i 's_https\?://downloads.openwrt.org_https://mirrors.tuna.tsinghua.edu.cn/openwrt_' /etc/opkg/distfeeds.conf
    opkg update
    check_status "配置软件源" || exit 1
else
    logger -t uci-defaults "软件源已配置，跳过"
fi

# 替换默认shell
logger -t uci-defaults "替换默认shell"
if grep -q "/bin/ash" /etc/passwd; then
    sed -i 's|/bin/ash|/bin/bash|' /etc/passwd
    check_status "替换默认shell" || exit 1
else
    logger -t uci-defaults "默认shell已替换，跳过"
fi

# 防火墙重启
logger -t uci-defaults "重启防火墙"
/etc/init.d/firewall restart

# 一次性日志与缓存清理（无定时、无后台，仅首次启动）
logger -t uci-defaults "清理系统与软件包日志和缓存"
log_dir="/var/log"
[ -d "$log_dir" ] || log_dir="/tmp"
# 日志清理
find $log_dir -type f -mtime +0 \( \
    -name "*.log" \
    -o -name "messages.*" \
    -o -name "syslog.*" \
\) -delete >/dev/null 2>&1
find $log_dir -type f -size +1M \( \
    -name "*.log" \
    -o -name "messages" \
    -o -name "syslog" \
\) -exec truncate -s 0 {} \; >/dev/null 2>&1
dmesg -c >/dev/null 2>&1
logread -r >/dev/null 2>&1

# 缓存清理（仅系统常见缓存，不影响运行）
rm -rf /tmp/opkg-lists/* >/dev/null 2>&1
find /tmp -maxdepth 1 -type f \( -o -name "*.gz" -o -name "*.tar" -o -name "*.tmp" -o  \) -delete >/dev/null 2>&1
sync
echo 1 > /proc/sys/vm/drop_caches
echo 2 > /proc/sys/vm/drop_caches
echo 3 > /proc/sys/vm/drop_caches

logger -t uci-defaults "日志与缓存清理完成"

logger -t uci-defaults "首次启动配置成功完成"
touch /etc/uci-defaults-complete

logger -t uci-defaults "清理后空间: $(df -h / | awk 'NR==2 {print $4}') 可用"
exit 0
