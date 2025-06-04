1.进入路由，编辑更新脚本
/usr/share/AdGuardHome/update_core.sh
删除main()函数下check_if_already_running函数的调用
此举是为了强制更新，屏蔽了一个运行状态检测的过程
我自己遇到的问题就是能正常访问，但状态检测总过不去，所以尝试直接屏蔽掉
--------------
2.然后在openwrt的adguardhome UI界面，把升级用的下载链接
中最前面添加一行例如，此链接是本地或着任何能访问的地址，里面包含最新的包，这个包你可以去官网下
http://192.168.1.10/openwrt/AdGuardHome_linux_${Arch}.tar.gz
#官网
https://github.com/AdguardTeam/AdGuardHome
#下载此版本
AdGuardHome_linux_amd64.tar.gz
--------
3.然后再从WEBUI界面点更新，就能正常更新了
或着直接连接路由，执行sh /usr/share/AdGuardHome/update_core.sh
--------
以上方法绝对管用。我最近刚好需要更新。才弄的
