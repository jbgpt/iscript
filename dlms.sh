#!/bin/sh

# GitHub 仓库信息
REPO_OWNER="jbgpt"
REPO_NAME="mosdns-rule"
BRANCH="main"

# 目标路径
TARGET_DIR="/etc/mosdns"

# 配置文件列表
FILES="
config_custom.yaml
hosts.txt
rules/ad_domain_list.txt
rules/serverlist.txt
rules/local-ptr.txt
rules/china_domain_list.txt
rules/cdn_domain_list.txt
rules/ecs_cn_domain.txt
rules/gfw_domain_list.txt
rules/geosite_no_cn.txt
rules/china_ip_list.txt
rules/gfw_ip_list.txt
"

# 创建目标路径及其子目录
mkdir -p $TARGET_DIR/rules

# 下载文件函数
download_file() {
    local file_path=$1
    local target_path="$TARGET_DIR/$file_path"
    local url="https://ghproxy.cc/https://raw.githubusercontent.com/$REPO_OWNER/$REPO_NAME/$BRANCH/$file_path"
    local retries=3
    local success=0
    
    for i in $(seq 1 $retries); do
        echo "Downloading $file_path to $target_path (Attempt $i)"
        curl -sfL $url -o $target_path
        if [ $? -eq 0 ]; then
            echo "Successfully downloaded $file_path"
            success=1
            break
        else
            echo "Failed to download $file_path (Attempt $i)"
        fi
    done
    
    if [ $success -ne 1 ]; then
        echo "Failed to download $file_path after $retries attempts"
        exit 1
    fi
}

# 下载所有配置文件
for file in $FILES; do
    download_file $file
done

# 重启 mosdns 服务以应用新的配置
/etc/init.d/mosdns restart

echo "mosdns 配置已更新并重启"
