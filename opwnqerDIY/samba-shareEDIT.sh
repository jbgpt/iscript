#!/bin/sh
# OpenWrt uci-defaults: 99-hc5962-samba-mt-init
# 适用于极路由4 HC5962，自动配置无线、内核优化、MT76、Samba和U盘共享

# 基础参数
wlan_name0="openwrt_2.4G"
wlan_name1="openwrt_5G"
wlan_password="aa12345678"
root_password="root"
lan_ip_address="192.168.2.1"
hostname="openwrt-samba"
log_file="/tmp/uci-defaults-hc5962.log"

exec >"$log_file" 2>&1

# 1. 设置 root 密码
if [ -n "$root_password" ]; then
  (echo "$root_password"; sleep 1; echo "$root_password") | passwd > /dev/null
fi

# 2. 配置 LAN
if [ -n "$lan_ip_address" ]; then
  uci set network.lan.ipaddr="$lan_ip_address"
  uci set network.lan.netmask="255.255.255.0"
  uci commit network
fi

# 3. 配置 WLAN
for idx in 0 1; do
  name_var="wlan_name${idx}"
  ssid=$(eval echo \$$name_var)
  if [ -n "$ssid" ] && [ -n "$wlan_password" ] && [ "${#wlan_password}" -ge 8 ]; then
    [ "$idx" -eq 0 ] && radio="radio0" && mode="HT40" || radio="radio1" && mode="VHT80"
    uci set wireless.${radio}.disabled='0'
    uci set wireless.${radio}.htmode="$mode"
    uci set wireless.${radio}.channel='auto'
    uci set wireless.${radio}.cell_density='0'
    uci set wireless.default_${radio}.ssid="$ssid"
    uci set wireless.default_${radio}.encryption='sae-mixed'
    uci set wireless.default_${radio}.key="$wlan_password"
  fi
done
uci commit wireless

# 4. 设置主机名和时区
uci set system.@system[0].hostname="$hostname"
uci set system.@system[0].zonename='Asia/Shanghai'
uci set system.@system[0].timezone='CST-8'
uci commit system

# 5. 内核网络优化参数
sysctl_conf="/etc/sysctl.conf"
if ! grep -q "net.core.rmem_max" $sysctl_conf 2>/dev/null; then
cat << EOF >> $sysctl_conf
# 优化参数
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
fi

# 6. MT76 优化脚本
mt76_script="/etc/hotplug.d/ieee80211/10-mt76-optimize"
if [ ! -f $mt76_script ]; then
  mkdir -p /etc/hotplug.d/ieee80211
  cat << 'EOF' > $mt76_script
#!/bin/sh
[ "$ACTION" = "add" ] || exit 0
sleep 1
for phy in /sys/kernel/debug/ieee80211/phy*; do
    phy_name=$(basename "$phy")
    if ! iw phy "$phy_name" info | grep -q "mt76"; then
        continue
    fi
    [ -f "$phy/mt76/tx_queues" ] && echo 4 > "$phy/mt76/tx_queues"
    [ -f "$phy/mt76/tx_queues/ac0/qlen" ] && echo 1024 > "$phy/mt76/tx_queues/ac0/qlen"
    [ -f "$phy/mt76/tx_queues/ac1/qlen" ] && echo 1024 > "$phy/mt76/tx_queues/ac1/qlen"
    [ -f "$phy/mt76/tx_queues/ac2/qlen" ] && echo 2048 > "$phy/mt76/tx_queues/ac2/qlen"
    [ -f "$phy/mt76/agc" ] && echo 1 > "$phy/mt76/agc"
    [ -f "$phy/mt76/retries" ] && echo 16 > "$phy/mt76/retries"
    [ -f "$phy/mt76/ampdu_density" ] && echo 8 > "$phy/mt76/ampdu_density"
    freq_range=$(iw phy "$phy_name" info | grep -E 'MHz' | awk '{print $2}' | head -1)
    if [ -n "$freq_range" ] && [ "$freq_range" -gt 5000 ]; then
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
  chmod +x $mt76_script
fi

# 7. 防火墙规则（兼容ipv4/ipv6）
uci -q add firewall rule
uci set firewall.@rule[-1].name='Allow_Local'
uci set firewall.@rule[-1].family='any'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].dest_port='22 18080 18443'
uci set firewall.@rule[-1].target='ACCEPT'

uci -q add firewall rule
uci set firewall.@rule[-1].name='Allow_VPN'
uci set firewall.@rule[-1].family='any'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].dest_port='52080'
uci set firewall.@rule[-1].target='ACCEPT'

uci -q add firewall rule
uci set firewall.@rule[-1].name='Allow_LAN'
uci set firewall.@rule[-1].family='any'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].dest='lan'
uci set firewall.@rule[-1].dest_port='22 8006 8069 9090 18080 18443'
uci set firewall.@rule[-1].target='ACCEPT'
# 仅允许内网访问SMB（Samba）服务，禁止WAN等非LAN访问
uci -q add firewall rule
uci set firewall.@rule[-1].name='Allow-LAN-Samba'
uci set firewall.@rule[-1].src='lan'
uci set firewall.@rule[-1].dest_port='137 138 139 445'
uci set firewall.@rule[-1].proto='tcp udp'
uci set firewall.@rule[-1].target='ACCEPT'

uci -q add firewall rule
uci set firewall.@rule[-1].name='Deny-WAN-Samba'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].dest_port='137 138 139 445'
uci set firewall.@rule[-1].proto='tcp udp'
uci set firewall.@rule[-1].target='REJECT'


uci commit firewall

# 8. uhttpd 监听端口
uci add_list uhttpd.main.listen_http='[::]:18080'
uci add_list uhttpd.main.listen_https='[::]:18443'
uci commit uhttpd

# 9. 换源
[ -f /etc/opkg/distfeeds.conf ] && sed -i 's_https\?://downloads.openwrt.org_https://mirrors.tuna.tsinghua.edu.cn/openwrt_g' /etc/opkg/distfeeds.conf

# 10. 启用挂载点自动挂载（自动挂载未知设备，挂载到/mnt/sda*）
uci set fstab.@global[0].auto_mount='1'
uci set fstab.@global[0].auto_swap='1'
uci set luci.main.automount='1'

# 启用所有已配置挂载点
mount_count=$(uci show fstab | grep "=mount" | wc -l)
if [ "$mount_count" -gt 0 ]; then
  for idx in $(seq 0 $((mount_count - 1))); do
    uci set fstab.@mount[$idx].enabled='1'
  done
  uci commit fstab
fi

# 针对所有U盘插入自动挂载到/mnt/sda*，利用hotplug机制
usb_hotplug_script="/etc/hotplug.d/block/99-auto-mount-sda"
if [ ! -f $usb_hotplug_script ]; then
  mkdir -p /etc/hotplug.d/block
  cat << 'EOF' > $usb_hotplug_script
#!/bin/sh
# 自动挂载U盘到/mnt/sda*，移除时卸载，并确保fstab挂载点启用

DEVNAME="/dev/${DEVNAME##*/}"
MOUNT_BASE="/mnt"

if echo "$DEVNAME" | grep -Eq "^/dev/sd[a-z][0-9]*$"; then
    MOUNT_POINT="$MOUNT_BASE/$(basename $DEVNAME)"
    if [ "$ACTION" = "add" ]; then
        [ ! -d "$MOUNT_POINT" ] && mkdir -p "$MOUNT_POINT"
        mount | grep -q "on $MOUNT_POINT " || {
            for fstype in vfat ntfs exfat ext4; do
                mount -t $fstype "$DEVNAME" "$MOUNT_POINT" 2>/dev/null && break
            done
        }
        # 检查fstab是否有该挂载点，有则确保启用
        fstab_idx=$(uci show fstab 2>/dev/null | grep "path='$MOUNT_POINT'" | awk -F'[][]' '{print $2}')
        if [ -n "$fstab_idx" ]; then
            uci set fstab.@mount[$fstab_idx].enabled='1'
            uci commit fstab
        fi
        # 自动添加samba共享
        if [ -d "$MOUNT_POINT" ] && [ "$(ls -A $MOUNT_POINT 2>/dev/null)" ]; then
            if ! uci show samba4 2>/dev/null | grep -q "path='$MOUNT_POINT'"; then
                uci add samba4 share
                uci set samba4.@share[-1].name="$(basename $DEVNAME)"
                uci set samba4.@share[-1].path="$MOUNT_POINT"
                uci set samba4.@share[-1].read_only='no'
                uci set samba4.@share[-1].guest_ok='yes'
                uci set samba4.@share[-1].users='root'
                uci set samba4.@share[-1].comment='Ushare'
                uci set samba4.@share[-1].browseable='yes'
                uci set samba4.@share[-1].hosts_allow='192.168.2.0/24'
                uci commit samba4
                /etc/init.d/samba4 reload
            fi
        fi
    elif [ "$ACTION" = "remove" ]; then
        # 移除samba共享
        share_idx=$(uci show samba4 2>/dev/null | grep "path='$MOUNT_POINT'" | awk -F'[][]' '{print $2}')
        if [ -n "$share_idx" ]; then
            uci delete samba4.@share[$share_idx]
            uci commit samba4
            /etc/init.d/samba4 reload
        fi
        umount "$MOUNT_POINT" 2>/dev/null
        rmdir "$MOUNT_POINT" 2>/dev/null
    fi
fi
exit 0
EOF
  chmod +x $usb_hotplug_script
fi

/etc/init.d/fstab enable
/etc/init.d/fstab restart

# 11. Samba 配置（添加用户并共享U盘）
if command -v smbpasswd >/dev/null 2>&1; then
  [ -d /etc/samba ] || mkdir -p /etc/samba
  if ! grep -q "^root:" /etc/samba/smbpasswd 2>/dev/null; then
    (echo "$root_password"; echo "$root_password") | smbpasswd -a root || echo "smbpasswd 添加 root 用户失败，请检查"
  else
    echo "root samba 用户已存在，跳过添加"
  fi
else
  echo "smbpasswd 未安装或不可用，跳过 Samba 用户添加"
fi

# 检查所有 /mnt/sd* 挂载点，自动Samba共享（确保fstab启用已在前面全局做过）
for mp in /mnt/sd*; do
  if [ -d "$mp" ] && [ "$(ls -A "$mp" 2>/dev/null)" ]; then
    if ! uci show samba4 2>/dev/null | grep -q "path='$mp'"; then
      uci add samba4 share
      uci set samba4.@share[-1].name="$(basename "$mp")"
      uci set samba4.@share[-1].path="$mp"
      uci set samba4.@share[-1].read_only='no'
      uci set samba4.@share[-1].guest_ok='yes'
      uci set samba4.@share[-1].custom='valid users = root'
      uci set samba4.@share[-1].create_mask='0777'
      uci set samba4.@share[-1].dir_mask='0777'
      uci set samba4.@share[-1].users='root'
      uci set samba4.@share[-1].comment='Ushare'
      uci set samba4.@share[-1].browseable='yes'
      uci commit samba4
      echo "已添加 samba4 共享 $mp"
    else
      echo "samba4 配置已存在 $mp 共享，跳过添加"
    fi
    /etc/init.d/samba4 reload
  else
    echo "跳过空或不存在的挂载点 $mp"
  fi
done

# 12. 重载服务（部分服务需重启或reload才能生效）
/etc/init.d/network restart
wifi up
/etc/init.d/samba4 restart

echo "All done! See $log_file for details."

# 13. uci-defaults自删
case "$0" in /etc/uci-defaults/*) rm -f "$0";; esac
