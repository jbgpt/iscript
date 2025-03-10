#!/bin/sh

# 下载 geoip.dat 文件
curl -o /path/to/local/geoip.dat https://example.com/geoip.dat

# 下载 geosite.dat 文件
curl -o /path/to/local/geosite.dat https://example.com/geosite.dat

# 重新加载 mosdns 配置
systemctl restart mosdns
