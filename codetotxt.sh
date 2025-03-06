#!/bin/bash

# 解码 base64 编码的 gfwlist.txt
base64 -d gfwlist.txt > decoded_gfwlist.txt

# 解析域名和 IP 地址,sh文件放在与gwflist.txt,gfw_domain_list.txt,gfw_ip_list.txt一起
grep -oP '(?<=^|[\s,])[^,\s]+(?=[\s,]|$)' decoded_gfwlist.txt | while read -r entry; do
    if [[ $entry =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo $entry >> gfw_ip_list.txt
    else
        echo $entry >> gfw_domain_list.txt
    fi
done

# 清理临时文件
rm decoded_gfwlist.txt

echo "域名和 IP 地址已成功解析并分别添加到 gfw_domain_list.txt 和 gfw_ip_list.txt 中。"
