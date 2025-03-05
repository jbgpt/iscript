#!/bin/sh /etc/rc.common
#加入服务配置，可选择，ttydrun.sh脚本要放在/usr/bin
START=99，
STOP=10

USE_PROCD=1

start_service() {
    procd_open_instance
    procd_set_param command /usr/bin/ttyd -t titleFixed=ash -- /bin/sh /etc/save.sh
    procd_set_param respawn
    procd_close_instance
}
