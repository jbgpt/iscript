#!/bin/sh
log_file="/tmp/uci-defaults-hc5962.log"
exec >"$log_file" 2>&1
root_password="root"

# 添加 root samba 用户
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

# 检查 U 盘目录
if [ -d /mnt/sda1 ] && [ "$(ls -A /mnt/sda1 2>/dev/null)" ]; then
  # 检查是否已存在共享
  if ! uci show samba4 2>/dev/null | grep -q "path='/mnt/sda1'"; then
    uci add samba4 share
    uci set samba4.@share[-1].name='sda1'
    uci set samba4.@share[-1].path='/mnt/sda1'
    uci set samba4.@share[-1].read_only='no'
    uci set samba4.@share[-1].guest_ok='yes'
    uci set samba4.@share[-1].custom='valid users = root'
    uci set samba4.@share[-1].create_mask='0666'
    uci set samba4.@share[-1].dir_mask='0777'
    uci set samba4.@share[-1].users='root'
    uci set samba4.@share[-1].comment='U盘共享'
    uci set samba4.@share[-1].browseable='yes'
    uci commit samba4
    echo "已添加 samba4 共享 /mnt/sda1"
  else
    echo "samba4 配置已存在 /mnt/sda1 共享，跳过添加"
  fi
  # 强制重载 samba4 配置
  /etc/init.d/samba4 reload
else
  echo "添加失败，共享目录 /mnt/sda1 为空或不存在"
fi
