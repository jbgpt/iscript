主要功能实现说明：
广告拦截
通过 geosite:category-ads-all 标签匹配广告域名，直接返回REJECT响应37。广告规则库包含常见广告联盟域名如doubleclick、googleadservices等。
智能分流机制
白名单（直连）：包含国内域名、本地网络、运营商域名14
国内域名：使用阿里DNS/DNSPod进行解析
GFW列表：通过SSR Plus代理端口7913走加密查询14
灰名单（被污染域名）：强制使用Cloudflare/Google的加密DNS解析9
抗污染措施
对 .com/.net/.org 等非中国TLD域名强制使用DoT/DoH查询
采用TCP协议传输避免DNS劫持
设置缓存TTL防止中间人攻击2
性能优化
启用内存缓存加速重复查询（1小时TTL）
使用fast_forward插件实现多DNS并行查询
记录查询日志用于故障排查12
使用前需要：
从 Loyalsoldier/geoip 和 v2fly/domain-list-community 获取最新geoip.dat/geosite.dat
修改SSR Plus代理端口与实际配置一致（默认7913）
建议配合以下防火墙规则：
 
# 强制53端口流量转到mosdns 
iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 53 
iptables -t nat -A PREROUTING -p tcp --dport 53 -j REDIRECT --to-ports 53 
 
完整配置需要根据实际网络环境调整DNS服务器地址，可通过 dig twitter.com @127.0.0.1 测试分流效果，在query.log中查看具体解析路径14。
