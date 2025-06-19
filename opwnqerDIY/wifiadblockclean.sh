#!/bin/sh

# ================================================================
# OpenWrt 首次启动优化脚本 (专业调试版)
# 版本: 6.0
# 设备: HiWiFi HC5962 (mt7621)
# OpenWrt: 24.10.1
# 最后更新: 2025-06-17
# 功能: 系统优化 + 缓存清理 + 日志管理
# ================================================================

# uci-defaults 规范要求:
# 1. 必须返回 0 (成功) 或 1 (失败) 退出码
# 2. 执行时间应尽量短 (<2分钟)
# 3. 成功执行后系统会自动删除此脚本

# 初始化日志
logger -t uci-defaults "开始执行首次启动配置脚本"
exec >/tmp/uci-defaults.log 2>&1

# 设置变量
wlan_name0="openwrt_2.4G"
wlan_name1="openwrt_5G"
wlan_password="aa12345678"
root_password="root"
lan_ip_address="192.168.2.1"
hostname="openwrt-wifi"

# 错误检查函数 (增强版)
check_status() {
    local status=$?
    if [ $status -ne 0 ]; then
        logger -t uci-defaults "错误: $1 失败 (状态码: $status)"
        # 记录调试信息
        {
            echo "===== 调试信息 ====="
            date
            echo "失败命令: $1"
            echo "当前状态:"
            uci changes
            echo "系统日志:"
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

# 配置无线网络 (增强稳定性)
configure_wireless() {
    logger -t uci-defaults "配置无线网络"
    
    # 2.4GHz 无线 (添加高级参数)
    if [ -n "$wlan_name0" ] && [ -n "$wlan_password" ] && [ ${#wlan_password} -ge 8 ]; then
        uci set wireless.radio0.disabled='0'
        uci set wireless.radio0.htmode='HT40'
        uci set wireless.radio0.channel='auto'
        uci set wireless.radio0.cell_density='0'
        uci set wireless.default_radio0.ssid="$wlan_name0"
        uci set wireless.default_radio0.encryption='sae-mixed'
        uci set wireless.default_radio0.key="$wlan_password"
        
        # 2.4GHz 高级优化参数 (减少断流)
        uci set wireless.radio0.country='CN'
        uci set wireless.radio0.distance='1000'
        uci set wireless.radio0.frag_threshold='2346'
        uci set wireless.radio0.rts_threshold='2347'
        uci set wireless.default_radio0.disassoc_low_ack='0'  # 防止误断开
        uci set wireless.default_radio0.wmm='1'              # QoS支持
        uci set wireless.default_radio0.legacy_rates='0'     # 禁用低速协议
    fi

    # 5GHz 无线 (添加高级参数)
    if [ -n "$wlan_name1" ] && [ -n "$wlan_password" ] && [ ${#wlan_password} -ge 8 ]; then
        uci set wireless.radio1.disabled='0'
        uci set wireless.radio1.htmode='VHT80'
        uci set wireless.radio1.channel='auto'
        uci set wireless.radio1.cell_density='0'
        uci set wireless.default_radio1.ssid="$wlan_name1"
        uci set wireless.default_radio1.encryption='sae-mixed'
        uci set wireless.default_radio1.key="$wlan_password"
        
        # 5GHz 高级优化参数 (提升速率)
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

# ==================== 通用wwan转发规则 =====================
configure_wwan_firewall() {
    logger -t uci-defaults "配置通用wwan转发规则"
    
    # 检查是否已存在wwan区域
    if uci get firewall.@zone[0] | grep -q 'wwan'; then
        logger -t uci-defaults "wwan区域已存在，跳过"
        return 0
    fi
    
    # 创建wwan区域
    uci add firewall zone
    uci set firewall.@zone[-1].name='wwan'
    uci set firewall.@zone[-1].input='ACCEPT'
    uci set firewall.@zone[-1].output='ACCEPT'
    uci set firewall.@zone[-1].forward='ACCEPT'
    uci set firewall.@zone[-1].network='wwan'
    uci set firewall.@zone[-1].masq='1'
    
    # LAN到WAN转发 (桥接关键)
    uci add firewall forwarding
    uci set firewall.@forwarding[-1].src='lan'
    uci set firewall.@forwarding[-1].dest='wwan'
    
    # 关键规则：允许DNS转发 (防止DNS问题)
    uci add firewall rule
    uci set firewall.@rule[-1].name='Allow-DNS-Forward'
    uci set firewall.@rule[-1].src='lan'
    uci set firewall.@rule[-1].dest='wwan'
    uci set firewall.@rule[-1].proto='tcpudp'
    uci set firewall.@rule[-1].dest_port='53'
    uci set firewall.@rule[-1].target='ACCEPT'
    
    # 允许ICMP (用于网络诊断)
    uci add firewall rule
    uci set firewall.@rule[-1].name='Allow-ICMP'
    uci set firewall.@rule[-1].proto='icmp'
    uci set firewall.@rule[-1].target='ACCEPT'
    
    # 允许DHCP (确保客户端获取IP)
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

# 设置主机名和时区
logger -t uci-defaults "配置系统设置"
if [ -n "$hostname" ]; then
    uci set system.@system[0].hostname="$hostname"
fi
uci set system.@system[0].zonename='Asia/Shanghai'
uci set system.@system[0].timezone='CST-8'
uci commit system
check_status "配置系统设置" || exit 1

# 2. 网络服务重启 ===========================================
logger -t uci-defaults "重启网络服务"
/etc/init.d/network restart
sleep 5  # 延长等待时间确保网络稳定

logger -t uci-defaults "重启无线服务"
wifi up
sleep 3

# 3. 软件源和基础包配置 =====================================
logger -t uci-defaults "配置软件源"
if ! grep -q "mirrors.tuna.tsinghua.edu.cn" /etc/opkg/distfeeds.conf; then
    sed -i 's_https\?://downloads.openwrt.org_https://mirrors.tuna.tsinghua.edu.cn/openwrt_' /etc/opkg/distfeeds.conf
    check_status "配置软件源" || exit 1
else
    logger -t uci-defaults "软件源已配置，跳过"
fi

# 4. 替换默认shell ==========================================
logger -t uci-defaults "替换默认shell"
if grep -q "/bin/ash" /etc/passwd; then
    sed -i 's|/bin/ash|/bin/bash|' /etc/passwd
    check_status "替换默认shell" || exit 1
else
    logger -t uci-defaults "默认shell已替换，跳过"
fi

# 5. adblock 基础配置 =======================================
configure_adblock() {
    logger -t uci-defaults "配置 adblock"
    
    # 基本配置
    uci set adblock.global.adb_enabled='1'
    uci set adblock.global.adb_dns='dnsmasq'
    uci set adblock.global.adb_fetchutil='uclient-fetch'
    uci set adblock.global.adb_fetchparm='--timeout=20 --ca-certificate=/etc/ssl/certs/ca-certificates.crt -qO -'
    uci set adblock.global.adb_compress='1'
    uci set adblock.global.adb_backup='0'
    uci set adblock.global.adb_zonetype='ipset'
    uci set adblock.global.adb_maxqueue='4'
    uci set adblock.global.adb_dnsflush='0'
    
    # 广告源 (使用轻量级源)
    uci delete adblock.global.adb_sources
    uci add_list adblock.global.adb_sources='adaway'
    uci add_list adblock.global.adb_sources='stevenblack'
    
    # 白名单
    uci add_list adblock.global.adb_whitelist='.hiwifi.com'
    uci add_list adblock.global.adb_whitelist='.openwrt.org'
    uci add_list adblock.global.adb_whitelist='.ntp.org'
    
    # 更新策略
    uci set adblock.global.adb_trigger='timer'
    uci set adblock.global.adb_maxtime='48'
    
    uci commit adblock
    check_status "adblock 配置" || return 1
    
    # 防火墙规则
    uci add firewall rule
    uci set firewall.@rule[-1].name='Allow-LAN-DNS'
    uci set firewall.@rule[-1].src='lan'
    uci set firewall.@rule[-1].proto='udp'
    uci set firewall.@rule[-1].dest_port='53'
    uci set firewall.@rule[-1].target='ACCEPT'
    
    uci commit firewall
    check_status "DNS 防火墙规则" || return 1
    
    # 创建初始广告列表 (避免首次启动无列表)
    mkdir -p /etc/adblock
    cat << EOF > /etc/adblock/adblock.overall
0.0.0.0 ad.doubleclick.net
0.0.0.0 analytics.google.com
0.0.0.0 ads.facebook.com
0.0.0.0 tracking.amazon.com
0.0.0.0 adservice.google.com
EOF
    gzip -f /etc/adblock/adblock.overall
    
    return 0
}

# 仅在 adblock 包存在时配置
if opkg list-installed | grep -q '^adblock'; then
    configure_adblock || {
        logger -t uci-defaults "adblock配置失败，但继续执行"
        uci revert adblock >/dev/null 2>&1
    }
else
    logger -t uci-defaults "adblock 未安装，跳过配置"
fi

# 6. 创建后台任务脚本 ========================================
create_background_tasks() {
    logger -t uci-defaults "创建后台任务脚本"
    
    cat << 'EOF' > /etc/rc.local
#!/bin/sh

# 等待系统完全启动
sleep 45

# 1. 更新 adblock 列表 (如果已安装)
if [ -f /etc/init.d/adblock ]; then
    logger -t background "开始更新 adblock 列表"
    adblock update
    logger -t background "adblock 列表更新完成"
fi

# 2. 无线驱动优化检查
if [ -x /etc/hotplug.d/ieee80211/10-mt76-optimize ] && \
   [ -d /sys/kernel/debug/ieee80211 ]; then
    logger -t background "应用MT76驱动优化"
    /etc/hotplug.d/ieee80211/10-mt76-optimize
fi

# 3. 无线连接质量检查
if [ -x /usr/sbin/iw ]; then
    logger -t background "检查无线连接质量"
    iw dev wlan0 link | logger -t wifi-status
fi

# 4. 定期清理任务 (每天凌晨3点)
if [ -x /usr/bin/cleanup-system ]; then
    logger -t background "执行系统清理"
    /usr/bin/cleanup-system
fi

exit 0
EOF

    chmod +x /etc/rc.local
    logger -t uci-defaults "后台任务脚本已创建"
}

create_background_tasks

# 7. 最终服务启动 ============================================
# 重启防火墙使规则生效
logger -t uci-defaults "重启防火墙"
/etc/init.d/firewall restart

# 启用 adblock 服务 (如果存在)
if [ -f /etc/init.d/adblock ]; then
    logger -t uci-defaults "启用 adblock 服务"
    /etc/init.d/adblock enable
    /etc/init.d/adblock start
fi

# 8. 创建系统清理脚本 ========================================
create_cleanup_script() {
    logger -t uci-defaults "创建系统清理脚本"
    
    cat << 'EOF' > /usr/bin/cleanup-system
#!/bin/sh

# 专业系统清理脚本
# 版本: 1.2
# 安全清理缓存和日志，不影响系统运行

# 1. 清理软件包缓存
logger -t system-clean "清理opkg缓存"
rm -rf /tmp/opkg-lists/* >/dev/null 2>&1
find /tmp -maxdepth 1 -name "*.ipk" -delete >/dev/null 2>&1

# 2. 清理临时下载文件 (保留最近2小时)
logger -t system-clean "清理临时下载文件"
find /tmp -maxdepth 1 -type f -mmin +120 \( \
    -name "*.gz" ! -name "adblock.overall.gz" \
    -o -name "*.tar" \
    -o -name "*.tmp" \
    -o -name "*.temp" \
    -o -name "*.download" \
\) -delete >/dev/null 2>&1

# 3. 清理内存缓存
logger -t system-clean "清理内存缓存"
sync
echo 1 > /proc/sys/vm/drop_caches
echo 2 > /proc/sys/vm/drop_caches
echo 3 > /proc/sys/vm/drop_caches

# 4. 清理DNS缓存
logger -t system-clean "清理DNS缓存"
if [ -f /etc/init.d/dnsmasq ]; then
    /etc/init.d/dnsmasq restart
fi

# 5. 日志清理 (保留最近24小时)
logger -t system-clean "清理系统日志"
log_dir="/var/log"
[ -d "$log_dir" ] || log_dir="/tmp"

# 清理旧日志 (保留最近24小时)
find $log_dir -type f -mtime +0 \( \
    -name "*.log" \
    -o -name "messages.*" \
    -o -name "syslog.*" \
\) -delete >/dev/null 2>&1

# 清理大日志文件 (超过1MB)
find $log_dir -type f -size +1M \( \
    -name "*.log" \
    -o -name "messages" \
    -o -name "syslog" \
\) -exec truncate -s 0 {} \; >/dev/null 2>&1

# 6. 清理内核日志缓冲区
dmesg -c >/dev/null 2>&1

# 7. 清理用户日志
logger -t system-clean "清理用户日志"
logread | grep -v "system-clean" > /tmp/syslog
logread -r -f /tmp/syslog
rm -f /tmp/syslog

# 8. 清理临时目录
logger -t system-clean "清理临时目录"
find /tmp -mindepth 1 -maxdepth 1 \
    ! -name "uci-defaults-complete" \
    ! -name "adblock" \
    ! -name "run" \
    -exec rm -rf {} + >/dev/null 2>&1

# 9. 清理崩溃报告
logger -t system-clean "清理崩溃报告"
rm -f /tmp/core-* /tmp/*.core >/dev/null 2>&1

# 10. 清理浏览器缓存 (如果存在)
logger -t system-clean "清理浏览器缓存"
find /tmp -maxdepth 2 -type d \( \
    -name "cache" \
    -o -name "chromium" \
    -o -name "firefox" \
\) -exec rm -rf {} + >/dev/null 2>&1

logger -t system-clean "系统清理完成"
exit 0
EOF

    chmod +x /usr/bin/cleanup-system
    logger -t uci-defaults "系统清理脚本已创建"
    
    # 添加定时清理任务
    echo "0 3 * * * /usr/bin/cleanup-system" >> /etc/crontabs/root
    /etc/init.d/cron restart
    logger -t uci-defaults "定时清理任务已添加"
}

create_cleanup_script

# 9. 脚本完成前清理 ==========================================
logger -t uci-defaults "执行最终清理"

# 清理安装过程临时文件
find /tmp -maxdepth 1 -type f \( \
    -name "*.ipk" \
    -o -name "*.gz" ! -name "adblock.overall.gz" \
    -o -name "*.tar" \
    -o -name "*.tmp" \
    -o -name "*.download" \
\) -delete >/dev/null 2>&1

# 清理opkg缓存
rm -rf /tmp/opkg-lists/* >/dev/null 2>&1

# 清理日志缓冲区
logread -r >/dev/null 2>&1
dmesg -c >/dev/null 2>&1

# 10. 脚本完成 ===============================================
logger -t uci-defaults "首次启动配置成功完成"
touch /etc/uci-defaults-complete  # 创建完成标记

# 性能优化报告
{
    echo "===== 系统优化报告 ====="
    echo "优化时间: $(date)"
    echo "清理空间: $(df -h / | awk 'NR==2 {print $4}') 可用"
    echo "内存状态: $(free -m | awk '/Mem:/ {print $4"MB 可用 / "$2"MB 总量"}')"
    echo "内核参数:"
    sysctl -a | grep -E 'rmem|wmem|tcp_|netdev|conntrack'
    echo "MT76优化状态:"
    [ -f /etc/hotplug.d/ieee80211/10-mt76-optimize ] && echo "已安装" || echo "未安装"
    echo "防火墙规则:"
    uci show firewall | grep -E 'zone|forwarding|rule'
    echo "========================="
} > /tmp/optimization-report.txt

# 最终空间报告
logger -t uci-defaults "清理后空间: $(df -h / | awk 'NR==2 {print $4}') 可用"

# 必须返回 0 表示成功
exit 0
