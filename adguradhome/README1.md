###初次访问会要求初始设置：

##网页管理端口设为3000，DNS监听端口设为3001。（端口号任意，不冲突即可。）

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
