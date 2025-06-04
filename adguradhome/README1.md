###初次访问会要求初始设置：

##网页管理端口设为3000，DNS监听端口设为3001。（端口号任意，不冲突即可。）
核心功能在【设置】-【DNS设置】中：
DNS设置
上游DNS服务器

由于我们之前配置了SmartDNS，那么这边填写SmartDNS的DNS监听地址： 127.0.0.1:5053（国内）以及 127.0.0.1:5054（国外），处理方式选择【并行请求】。（论坛的各位大神都说并行请求速度最快）

        负载均衡：

        一次查询一台服务器。 AdGuard Home将使用加权随机算法来选择服务器，以便更频繁地使用最快的服务器。

        本模式为本次更新最新的功能，意思未知。具体使用感受是，去视频app广告迅速，微博国际版登陆5秒广告可以去除，图片加载速度较快。存在的问题是，仪表盘平均处理时间较长，80-120ms之间。
        并行请求：

        通过同时查询所有上游服务器，使用并行请求以加速解析。

        最老的模式，在添加本地DNS地址的情况下，去视频app广告迅速，微博国际版登陆5秒广告可以去除，仪表盘平均处理时间较短，可以保持在5-8ms之间。存在问题是，图片加载速度受影响，偶尔会加载慢，存在些许不稳定因素。
        最快的IP地址：

        查询所有DNS服务器并返回所有响应中速度最快的IP地址。因必须等待全部DNS服务器均有所回应，因而会降低DNS查询的速度，但同时此举将会改善总体的连接。

        本模式据说是Smart DNS的功能一样。对比上述模式没有区别，和并行模式并无态度啊去吧。


1.上游DNS服务器显得尤为重要，在这里我推荐几个我使用比较多的DNS服务器：
#https://dns10.quad9.net/dns-query	# AdGuard Home官方维护
#https://dns.google/dns-query	# Google DoH服务器
#https://1dot1dot1dot1.cloudflare-dns.com/	# CloudFlare DoH服务器
#dns.google	# Google DoT服务器
#cloudflare-dns.com # CloudFlare DoT服务器
#dns.alidns.com	# 阿里云 DoT服务器
#dot.pub	# DNSpub DoT服务器
#https://dns.alidns.com/dns-query # 阿里云 DoH服务器
#https://223.5.5.5/dns-query	# 阿里云 DoH服务器
#https://223.6.6.6/dns-query	# 阿里云 DoH服务器

在这里我选取了较多的上游服务器，其中需要注意的是阿里云公共DNS对于请求数量进行了限制（QPS 20），而腾讯的公共DNS有污染的传言，所以并不完全可靠
这里我推荐你使用并行请求，加上乐观缓存，这样的话可以在尽可能保证请求质量的基础上加快本地的DNS请求速度
Bootstrap DNS 服务器

Bootstrap DNS 服务器就如描述的字面意思，因为DOH DNS也需要被解析成IP才能通讯，所以需要设置一组去解析上述DOH DNS的DNS来解析。一般设置为自己运营商的DNS，因为理论上离自己最近的DNS响应速度是最快的，尽管运营商DNS存在劫持和污染等问题，但这里它只负责解析DOH DNS，并不负责解析日常上网，所以这些都没所谓。
私人反向 DNS 服务器

AdGuard Home 用于本地 PTR 查询的 DNS 服务器。这些服务器将使用反向 DNS 解析具有私人 IP 地址的客户机的主机名，比如 “192.168.12.34”。如果没有设置，除非是 AdGuard Home 里设置的地址，AdGuard Home 都将自动使用您的操作系统的默认 DNS 解析器。

这个我们用不到，直接默认即可。

以上三项设置完成后，点击【测试上游DNS】以及【应用
DNS 服务配置

【速度限制】填 0（不限制）；

【EDNS客户端子网】和【DNSSEC】看情况勾选，上游DNS如果支持EDNS的话，EDNS会把你的IP一并发送到权威DNS进行查询，DNS服务器根据你的IP所在地，给你返回离你最近的IP结果，从而加速访问速度。

【拦截模式】一般【默认】即可。
DNS缓存配置

这边全部保持为【空】

这是因为我们在SmartDNS中已经配置了缓存，不必造成重复缓存造成冲突。
2.DNS 黑名单
AdGuard Home的DNS 黑名单是整个的核心，它决定了最终对抗广告和追踪器的质量，在这里我推荐一个效果比较好，误伤比较小的DNS黑名单，以下加速链接为CDN加速后的链接：
AdGuard DNS filter：原始链接 | 加速链接
https://mirror.ghproxy.com/https://raw.githubusercontent.com/217heidai/adblockfilters/main/rules/adblockdns.txt
AdAway Default Blocklist：原始链接 | 加速链接
https://mirror.ghproxy.com/https://raw.githubusercontent.com/217heidai/adblockfilters/main/rules/AdGuard_DNS_filter.txt
AdGuard Base filter：原始链接 | 加速链接
https://link.juejin.cn/?target=https%3A%2F%2Fmirror.ghproxy.com%2Fhttps%3A%2F%2Fraw.githubusercontent.com%2F217heidai%2Fadblockfilters%2Fmain%2Frules%2FAdGuard_Base_filter.txt
AdGuard Chinese filter：原始链接 | 加速链接
https://raw.githubusercontent.com/217heidai/adblockfilters/main/rules/AdGuard_Chinese_filter.txt
CJX's Annoyance List：原始链接 | 加速链接
乘风MV：原始链接 |  加速链接
(https://raw.githubusercontent.com/xinggsf/Adblock-Plus-Rule/master/mv.txt)
乘风Rules：原始链接 | 加速链接
https://raw.githubusercontent.com/xinggsf/Adblock-Plus-Rule/master/rule.txt

jiekouAD： 原始链接 | 加速链接
EasyList：原始链接 | 加速链接
EasyList China：原始链接 | 加速链接
https://raw.githubusercontent.com/217heidai/adblockfilters/main/rules/EasyList_China.txt
EasyPrivacy：原始链接 | 加速链接
BlueSkyXN：原始链接 | 加速链接

总体来说效果还是很不错的，一些常见的广告都可以过滤，你还可以添加一些特殊的规则，比如说针对“电子书”、“电视剧”等等

作者：Liueic
链接：https://juejin.cn/post/7397025359525052416
来源：稀土掘金
著作权归作者所有。商业转载请联系作者获得授权，非商业转载请注明出处。
