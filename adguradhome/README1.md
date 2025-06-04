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
