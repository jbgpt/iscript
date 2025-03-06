#!/bin/bash

# 下载 gfwlist.txt 文件到 /tmp
curl -o /tmp/gfwlist.txt https://gh-proxy.com///https://raw.githubusercontent.com/gfwlist/gfwlist/refs/heads/master/gfwlist.txt

# 解码 base64 编码的 gfwlist.txt
base64 -d /tmp/gfwlist.txt > /tmp/decoded_gfwlist.txt

# 初始化临时文件
touch /tmp/new_gfw_domain_list.txt /tmp/new_gfw_ip_list.txt

# 解析域名和 IP 地址
grep -oP '(?<=^|[\s,])[^,\s]+(?=[\s,]|$)' /tmp/decoded_gfwlist.txt | while read -r entry; do
    if [[ $entry =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo $entry >> /tmp/new_gfw_ip_list.txt
    else
        echo $entry >> /tmp/new_gfw_domain_list.txt
    fi
done

# 比较并写入不同内容到 /etc/mosdns/rule/gfw_domain_list.txt
if [ -f /etc/mosdns/rule/gfw_domain_list.txt ]; then
    grep -Fxvf /etc/mosdns/rule/gfw_domain_list.txt /tmp/new_gfw_domain_list.txt >> /tmp/filtered_gfw_domain_list.txt
    cat /tmp/filtered_gfw_domain_list.txt >> /etc/mosdns/rule/gfw_domain_list.txt
else
    mv /tmp/new_gfw_domain_list.txt /etc/mosdns/rule/gfw_domain_list.txt
fi

# 比较并写入不同内容到 /etc/mosdns/rule/gfw_ip_list.txt
if [ -f /etc/mosdns/rule/gfw_ip_list.txt ]; then
    grep -Fxvf /etc/mosdns/rule/gfw_ip_list.txt /tmp/new_gfw_ip_list.txt >> /tmp/filtered_gfw_ip_list.txt
    cat /tmp/filtered_gfw_ip_list.txt >> /etc/mosdns/rule/gfw_ip_list.txt
else
    mv /tmp/new_gfw_ip_list.txt /etc/mosdns/rule/gfw_ip_list.txt
fi

# 清理临时文件
rm /tmp/gfwlist.txt /tmp/decoded_gfwlist.txt /tmp/new_gfw_domain_list.txt /tmp/new_gfw_ip_list.txt /tmp/filtered_gfw_domain_list.txt /tmp/filtered_gfw_ip_list.txt

echo "域名和 IP 地址已成功解析并分别添加到 /etc/mosdns/rule/gfw_domain_list.txt 和 /etc/mosdns/rule/gfw_ip_list.txt 中。"
