#!/bin/sh

# 下载 geoip.dat 文件
curl -o /ver/mosdns/geoip.dat https://cdn.jsdelivr.net/gh/Loyalsoldier/geoip@release/geoip.dat

# 下载 geosite.dat 文件
curl -o /path/to/local/geosite.dat https://example.com/geosite.dat
# 下载 private.dat 文件
curl -o /var/mosdns/geo_private.dat https://cdn.jsdelivr.net/gh/Loyalsoldier/geoip@release/private.dat

# 重新加载 mosdns 配置
systemctl restart mosdns
