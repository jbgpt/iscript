初始化设置
进入安装向导

在浏览器中打开 AdGuard Home 的后台，进入安装向导，点击 “开始配置”。默认后台地址为：​http://IP:3000/​
安装向导
设置网络接口

将后台的访问端口更改为 3000，避免与 NAS 后台的 80 端口发生冲突，DNS 端口保持为 53 即可。
网络接口
设置管理员账户
设置管理员账户
完成初始化设置
    过滤器更新间隔：DNS 过滤清单默认更新间隔，一般为 3 天 - 7 天；
    使用 AdGuard 「浏览安全」网页服务：作用与 Chrome 网页安全性检查类似，开启后，当用户访问存在潜在威胁的网站时，AdGuard 会主动拦截并弹出提示；
    使用 AdGuard 「家长控制」 服务：如果家中有尚未成年的孩子，建议开启，避免访问不良网站；
    强制安全搜索：隐藏 Bing、Google、Yandex、YouTube 网站上 NSFW 等不适宜的内容；
    查询记录保留时间：AdGuard Home 服务端采用 Sqlite 文件数据库存储日志，长时间保留可能会降低运行速度，同时占用大量的储存空间，家庭用户一般保留 24 小时 - 7 天即可；
    统计数据保留时间：用于仪表盘的数据展示，一般保留 24 小时 - 7 天即可。
        上游 DNS 服务器：AdGuard Home 的上游 DNS 服务器，可参考下方推荐列表，一般保留 1 - 2 个即可。AdGuard Home 除了可以作为广告过滤网关，如果设置了纯净 DNS 后，还可以避免运营商的 DNS 劫持。
    BootStrap DNS 服务器地址：作为 DoH / DoT DNS 的前置 DNS 解析器，可参考下方推荐列表。
    查询方式、速度限制、EDNS、DNSSEC、拦截模式、DNS 缓存设置、访问设置可根据需要进行调整，一般保持默认设置即可。

DNS 服务器推荐

不同地区连接至 DNS 服务器的速度各有差异，各位可以通过 Ping 测速的方式寻找当地连接延迟最低的 DNS 服务器。更多 DNS 服务器可以在 AdGuard 文档中找到。
DNS 提供商	类别	地址
阿里	IPv4 DNS	223.5.5.5
IPv6 DNS	2400:3200:baba::1
DNS-over-Https	https://dns.alidns.com/dns-query
DNSPod	IPv4 DNS	119.29.29.29
DNS-over-Https	https://doh.pub/dns-query
114	IPv4 DNS	114.114.114.114
Google	IPv4 DNS	8.8.8.8
IPv6 DNS	2001:4860:4860::8888
DNS-over-Https	https://dns.google/dns-query
Cloudflare	IPv4 DNS	1.1.1.1
IPv6 DNS	2606:4700:4700::1111
DNS-over-Https	https://dns.cloudflare.com/dns-query
DNS 封锁清单

为了更好地发挥 AdGuard Home 去广告的功能，仅依靠默认的过滤规则是不够的，但也不宜过多，过多的过滤规则会影响解析的速度，各位可以根据需要添加过滤规则。
名称	简介	地址
AdGuard DNS Filter	AdGuard 官方维护的广告规则，涵盖多种过滤规则	https://raw.githubusercontent.com/AdguardTeam/FiltersRegistry/master/filters/filter_15_DnsFilter/filter.txt
EasyList	Adblock Plus 官方维护的广告规则	https://easylist-downloads.adblockplus.org/easylist.txt
EasyList China	面向中文用户的 EasyList 去广告规则	https://easylist-downloads.adblockplus.org/easylistchina.txt
EasyPrivacy	反隐私跟踪、挖矿规则	https://easylist-downloads.adblockplus.org/easyprivacy.txt
AdRules	主要屏蔽国内广告	https://raw.githubusercontent.com/Cats-Team/AdRules/main/dns.txt
Xinggsf 乘风过滤	国内网站广告过滤规则	https://gitee.com/xinggsf/Adblock-Rule/raw/master/rule.txt
Xinggsf 乘风视频过滤	视频网站广告过滤规则	https://gitee.com/xinggsf/Adblock-Rule/raw/master/mv.txt
MalwareDomainList	恶意软件过滤规则	https://www.malwaredomainlist.com/hostslist/hosts.txt
Adblock Warning Removal List	去除禁止广告拦截提示规则	https://easylist-downloads.adblockplus.org/antiadblockfilters.txt
Anti-AD	命中率高、兼容性强	https://anti-ad.net/easylist.txt
Fanboy’s Annoyances List	去除页面弹窗广告规则	https://easylist-downloads.adblockplus.org/fanboy-annoyance.txt

以浏览国内网站为主的用户可以使用 anti-AD + AdRules 过滤规则，如有浏览国外网站的需要，可以根据需要添加 AdGuard DNS Filter、EasyList 等规则。不同规则之间会存在重叠的情况，可以通过 AdGuard Home 的拦截日志分析哪些规则的使用频率最高，哪些规则拦截频率最低，再加以取舍。
替换设备 DNS

完成 AdGuard Home 的设置后，便可将 AdGuard Home 的 DNS 地址部署到局域网设备上。
更改路由器 DNS 地址

不同品牌路由器修改的方法各有差异，具体步骤可参照说明书或网上的教程（路由器型号 + 更改 DNS），下方以 Redmi AC2100 路由器为例。

打开并登录路由器的后台管理页面。
局域网设置中找到 DNS 设置，将首选 DNS 服务器更改为 AdGuard Home 的 DNS 地址，可设置为其它的 DNS 服务商，避免因 AdGuard Home 服务器宕机而导致局域网无法访问互联网。更改完成后点击保存即可。在路由器更改 DNS 后，局域网内的所有设备的 DNS 解析都会通过 AdGuard Home DNS 完成，实现过滤广告与反隐私跟踪。
https://sspai.com/post/63088
