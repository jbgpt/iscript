#!/bin/sh
touch /var/mosdns/query.log
# 下载 geoip.dat 文件
curl -o /var/mosdns/geoip.dat https://cdn.jsdelivr.net/gh/Loyalsoldier/geoip@release/geoip.dat

# 下载 geosite.dat 文件
curl -o /var/mosdns/geosite.dat https://gh-proxy.com///https://github.com/Loyalsoldier/domain-list-custom/releases/latest/download/geosite.dat
# 下载 private.dat 文件
curl -o /var/mosdns/geo_private.dat https://cdn.jsdelivr.net/gh/Loyalsoldier/geoip@release/private.dat
# 下载gfw.txt
# 下载!cn
# 重新加载 mosdns 配置
systemctl restart mosdns
