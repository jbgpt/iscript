# OpenWRT (mipsel 架构) 安装与标准配置 AdGuardHome 图文教程
## 手动更新core
/etc/init.d/adguardhome stop
cd /tmp
wget https://github.com/AdguardTeam/AdGuardHome/releases/latest/download/AdGuardHome_linux_mipsle.tar.gz
tar -zxvf AdGuardHome_linux_mipsle.tar.gz
cp AdGuardHome/AdGuardHome /usr/bin/adguardhome
chmod +x /usr/bin/adguardhome
/etc/init.d/adguardhome start
> 本教程适用于基于 mipsel 架构的 OpenWRT 路由器，带你一步步完成 AdGuardHome 的下载、安装、初始化配置与优化设置。

---

## 一、准备工作

- 已刷写 OpenWRT（适配 mipsel 架构）。
- 路由器可正常联网。
- 路由器有足够的剩余空间（建议 8MB 以上）。
- SSH 工具（如 Xshell、putty 等）。

---

## 二、下载安装 AdGuardHome

### 1. 下载 mipsel 专用 AdGuardHome

前往 [AdGuardHome 官方发布页](https://github.com/AdguardTeam/AdGuardHome/releases) 下载对应 mipsel 架构的最新压缩包。

> 例如：`AdGuardHome_linux_mipsle_softfloat.tar.gz`

### 2. 上传到路由器

通过 WinSCP、scp 或 LuCI 界面上传至 `/tmp` 目录。

![WinSCP 上传示例](https://cdn.jsdelivr.net/gh/jbgpt/imgbed@main/uPic/scp_upload.png)

### 3. 解压 & 启动

```sh
cd /tmp
tar -xzvf AdGuardHome_linux_mipsle_softfloat.tar.gz
cd AdGuardHome
./AdGuardHome -s install
```

> 若提示权限不足，先执行 `chmod +x AdGuardHome`。

---

## 三、初始化设置

### 1. 访问管理页面

浏览器打开：`http://路由器IP:3000`  
例如：`http://192.168.1.1:3000`

![AdGuardHome 初始化页面](https://cdn.jsdelivr.net/gh/jbgpt/imgbed@main/uPic/aghome_wizard.png)

---

### 2. 配置网络端口

- **管理端口**：3000（避免与路由器 LuCI 冲突）
- **DNS 端口**：建议 53（如与 dnsmasq 冲突，可设为 5353，并在路由器 DNS 转发中指向 127.0.0.1:5353）

### 3. 设置管理员账户

![账户设置页面](https://cdn.jsdelivr.net/gh/jbgpt/imgbed@main/uPic/aghome_account.png)

---

### 4. 完成向导

- **过滤器更新间隔**：建议 3~7 天
- **浏览安全&家长控制**：按需开启
- **日志/统计保留时间**：建议 24 小时~7 天，避免空间占满
- **上游 DNS**：推荐 1~2 个，支持 DoH/DoT

---

## 四、推荐 DNS 服务器

| 提供商      | IPv4         | IPv6                | DoH 地址                                  |
| ---------   | ------------ | ------------------- | ----------------------------------------- |
| 阿里        | 223.5.5.5    | 2400:3200:baba::1   | https://dns.alidns.com/dns-query          |
| DNSPod      | 119.29.29.29 | -                   | https://doh.pub/dns-query                 |
| Google      | 8.8.8.8      | 2001:4860:4860::8888| https://dns.google/dns-query              |
| Cloudflare  | 1.1.1.1      | 2606:4700:4700::1111| https://dns.cloudflare.com/dns-query      |

---

## 五、广告过滤规则推荐

| 名称               | 简介                | 地址 |
| ------------------ | ------------------- | ---- |
| AdGuard DNS Filter | 官方维护            | https://raw.githubusercontent.com/AdguardTeam/FiltersRegistry/master/filters/filter_15_DnsFilter/filter.txt |
| EasyList China     | 中文广告规则        | https://easylist-downloads.adblockplus.org/easylistchina.txt |
| AdRules            | 国内高命中          | https://raw.githubusercontent.com/Cats-Team/AdRules/main/dns.txt |
| anti-AD            | 国内外兼容          | https://anti-ad.net/easylist.txt |

在“过滤器”→“DNS 封锁清单”中添加上述规则即可。

---

## 六、替换路由 DNS

### 1. 关闭 dnsmasq 的 53 端口监听

LuCI 后台 `网络` → `DHCP/DNS`，关闭本地端口监听或转发到 127.0.0.1:5353

### 2. 修改上游 DNS

- 路由器自身 DNS 填写 127.0.0.1
- 局域网设备网关 DNS 指向路由器 IP

---

## 七、开机自启动与后台管理

AdGuardHome 安装脚本会自动注册为系统服务，重启后自动启动。

- 查看状态：  
  `etc/init.d/AdGuardHome status`
- 启动：  
  `/etc/init.d/AdGuardHome start`
- 停止：  
  `/etc/init.d/AdGuardHome stop`

---

## 八、常见问题

- **端口冲突**：DNS 端口被占用时，调整 dnsmasq 或 AdGuardHome 端口
- **启动失败**：确认架构选择和剩余空间
- **广告过滤不生效**：检查过滤规则是否生效、缓存是否刷新

---

## 参考链接

- [知乎教程/原版OpenWrt安装AdGuard Home](https://zhuanlan.zhihu.com/p/698198829)
- [恩山无线论坛 OpenWRT 手动安装AdGuardHome](https://www.right.com.cn/forum/thread-8273723-1-1.html)
- [晓旭Blog OpenWRT安装AdGuardHome详细教程](https://blog.xiaoxu.net/archives/use-adguardhome-on-openwrt)
- [AdGuardHome 官方 GitHub](https://github.com/AdguardTeam/AdGuardHome)

---

> 本文图片可替换为实际操作截图以提升可读性。
