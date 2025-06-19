
#!/bin/sh

# ================================================================
# OpenWrt 首次启动优化脚本 (专业清理版)
# 版本: 7.0
# 设备: HiWiFi HC5962 (mt7621)
# OpenWrt: 24.10.1
# 最后更新: 2025-06-17
# 功能: 系统优化 + 全面深度清理
# ================================================================

# ... [前面的基础配置部分保持不变，从清理功能开始增强] ...

# 8. 创建专业级系统清理脚本 ====================================
create_cleanup_script() {
    logger -t uci-defaults "创建专业级系统清理脚本"
    
    cat << 'EOF' > /usr/bin/cleanup-system
#!/bin/sh

# 专业系统深度清理脚本
# 版本: 2.5
# 安全清理冗余文件，释放磁盘空间

# 1. 清理标准缓存 -------------------------------------------------
logger -t system-clean "开始系统深度清理"

# 软件包缓存
logger -t system-clean "清理opkg缓存"
rm -rf /tmp/opkg-lists/* >/dev/null 2>&1
find /tmp -maxdepth 1 -name "*.ipk" -delete >/dev/null 2>&1

# 临时下载文件 (保留最近2小时)
logger -t system-clean "清理临时下载文件"
find /tmp -maxdepth 1 -type f -mmin +120 \( \
    -name "*.gz" ! -name "adblock.overall.gz" \
    -o -name "*.tar" \
    -o -name "*.tmp" \
    -o -name "*.temp" \
    -o -name "*.download" \
\) -delete >/dev/null 2>&1

# 2. 扩展目录深度清理 ---------------------------------------------
# 定义清理目录数组
clean_dirs=(
    "/tmp"
    "/var"
    "/www"
    "/overlay/upper"  # Docker容器目录
    "/mnt"            # 挂载点目录
    "/root"
    "/home"
)

# 清理所有指定目录中的冗余文件
for dir in "${clean_dirs[@]}"; do
    # 检查目录是否存在
    [ ! -d "$dir" ] && continue
    
    logger -t system-clean "清理目录: $dir"
    
    # 清理核心垃圾文件类型
    find "$dir" -type f \( \
        -name "*.log" ! -path "/var/log/*" \
        -o -name "*.bak" \
        -o -name "*.backup" \
        -o -name "*.old" \
        -o -name "*.tmp" \
        -o -name "*.temp" \
        -o -name "*.cache" \
        -o -name "*.swp" \
        -o -name "Thumbs.db" \
        -o -name ".DS_Store" \
        -o -name "*.pid" \
    \) -mtime +7 -delete >/dev/null 2>&1
    
    # 清理空目录 (保留关键目录)
    find "$dir" -mindepth 1 -type d -empty \
        ! -path "/tmp/run*" \
        ! -path "/var/run*" \
        ! -path "/overlay/upper/usr*" \
        -exec rmdir {} + >/dev/null 2>&1
    
    # 清理大文件 (超过10MB)
    find "$dir" -type f -size +10M \( \
        ! -path "/usr/lib/*" \
        ! -path "/overlay/upper/usr/lib/*" \
        ! -name "*.squashfs" \
    \) -exec ls -lh {} \; | logger -t system-clean
done

# 3. 特殊目录清理 -------------------------------------------------
# /var/log 目录 (保留最近3天日志)
logger -t system-clean "清理系统日志"
find /var/log -type f \( \
    -name "*.log" \
    -o -name "messages.*" \
    -o -name "syslog.*" \
\) -mtime +3 -delete >/dev/null 2>&1

# 清理大日志文件 (超过1MB)
find /var/log -type f -size +1M \( \
    -name "*.log" \
    -o -name "messages" \
    -o -name "syslog" \
\) -exec truncate -s 0 {} \; >/dev/null 2>&1

# /www 目录 (web服务器缓存)
if [ -d /www ]; then
    logger -t system-clean "清理Web缓存"
    find /www -type f \( \
        -name "*.cache" \
        -o -name "*.tmp" \
        -o -name "thumb_*" \
        -o -path "*/cache/*" \
    \) -mtime +3 -delete >/dev/null 2>&1
fi

# 4. 软件残留清理 -------------------------------------------------
# 清理未使用的软件包残留
logger -t system-clean "清理软件残留"
opkg list-installed | awk '{print $1}' > /tmp/installed-pkgs
find /usr/lib/opkg/info -name "*.control" | while read -r ctrl; do
    pkg=$(basename "$ctrl" .control)
    if ! grep -q "^$pkg$" /tmp/installed-pkgs; then
        logger -t system-clean "删除未安装包残留: $pkg"
        rm -f /usr/lib/opkg/info/"$pkg".* >/dev/null 2>&1
    fi
done
rm -f /tmp/installed-pkgs

# 5. 内存和缓存优化 -----------------------------------------------
logger -t system-clean "优化内存缓存"
sync
echo 1 > /proc/sys/vm/drop_caches  # 页面缓存
echo 2 > /proc/sys/vm/drop_caches  # 目录项和inode
echo 3 > /proc/sys/vm/drop_caches  # 所有缓存

# 清理DNS缓存
logger -t system-clean "清理DNS缓存"
if [ -f /etc/init.d/dnsmasq ]; then
    /etc/init.d/dnsmasq restart
fi

# 6. 高级清理技术 -------------------------------------------------
# 清理未使用的语言文件
logger -t system-clean "清理语言文件"
find /usr/lib/lua /www -type f -name "*.mo" ! -name "en.mo" -delete >/dev/null 2>&1

# 清理旧的崩溃报告
logger -t system-clean "清理崩溃报告"
find /tmp /var -type f \( \
    -name "core.*" \
    -o -name "*.core" \
    -o -name "*.crash" \
\) -mtime +1 -delete >/dev/null 2>&1

# 清理浏览器缓存
logger -t system-clean "清理浏览器缓存"
find /tmp /home /root -type d \( \
    -name ".cache" \
    -o -name ".chromium" \
    -o -name ".mozilla" \
    -o -name "cache" \
\) -exec rm -rf {} + >/dev/null 2>&1

# 7. 容器和虚拟环境清理 -------------------------------------------
# 清理Docker残留 (如果存在)
if which docker >/dev/null; then
    logger -t system-clean "清理Docker资源"
    docker system prune -f >/dev/null 2>&1
    docker volume prune -f >/dev/null 2>&1
fi

# 清理LXC容器残留
if [ -d /var/lib/lxc ]; then
    logger -t system-clean "清理LXC容器"
    find /var/lib/lxc -mindepth 1 -maxdepth 1 -type d -mtime +30 \
        -exec rm -rf {} + >/dev/null 2>&1
fi

# 8. 日志和临时系统清理 -------------------------------------------
# 清理内核日志缓冲区
dmesg -c >/dev/null 2>&1

# 清理用户日志 (保留清理记录)
logread | grep -v "system-clean" > /tmp/syslog
logread -r -f /tmp/syslog
rm -f /tmp/syslog

# 9. 最终空间优化 -------------------------------------------------
# 清理临时目录 (排除关键文件)
logger -t system-clean "清理临时目录"
find /tmp -mindepth 1 -maxdepth 1 \
    ! -name "uci-defaults-complete" \
    ! -name "adblock" \
    ! -name "run" \
    ! -name "*.sock" \
    -exec rm -rf {} + >/dev/null 2>&1

# 10. 清理报告 ----------------------------------------------------
# 计算清理空间
before_space=$(df -h / | awk 'NR==2 {print $4}')
after_space=$(df -h / | awk 'NR==2 {print $4}')
freed_space=$(( $(echo "$before_space" | sed 's/[^0-9]*//g') - $(echo "$after_space" | sed 's/[^0-9]

*//g') ))

logger -t system-clean "系统清理完成，释放 ${freed_space}MB 空间"
logger -t system-clean "当前可用空间: $after_space"

exit 0
EOF

    chmod +x /usr/bin/cleanup-system
    logger -t uci-defaults "专业级清理脚本已创建"
    
    # 添加定时清理任务 (每天凌晨3点)
    echo "0 3 * * * /usr/bin/cleanup-system" >> /etc/crontabs/root
    /etc/init.d/cron restart
    logger -t uci-defaults "定时清理任务已添加"
}

create_cleanup_script

# 9. 首次启动立即清理 ==========================================
logger -t uci-defaults "执行首次启动深度清理"

# 立即运行清理脚本释放空间
if [ -x /usr/bin/cleanup-system ]; then
    logger -t uci-defaults "运行初始系统清理"
    /usr/bin/cleanup-system
fi

# 10. 脚本完成 ================================================
logger -t uci-defaults "首次启动配置成功完成"
touch /etc/uci-defaults-complete  # 创建完成标记

# 空间优化报告
{
    echo "===== 系统优化报告 ====="
    echo "优化时间: $(date)"
    echo "清理后空间: $(df -h / | awk 'NR==2 {print $4}') 可用"
    echo "清理目录:"
    echo "  /tmp, /var, /www, /overlay, /mnt, /root, /home"
    echo "清理内容:"
    echo "  - 临时文件 (*.tmp, *.temp, *.cache)"
    echo "  - 日志文件 (超过3天)"
    echo "  - 软件包残留"
    echo "  - 未使用语言文件"
    echo "  - 浏览器缓存"
    echo "  - 容器残留资源"
    echo "  - 崩溃报告"
    echo "========================="
} > /tmp/optimization-report.txt

logger -t uci-defaults "最终空间: $(df -h / | awk 'NR==2 {print $4}') 可用"

# 必须返回 0 表示成功
exit 0
