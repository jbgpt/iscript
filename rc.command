#!/bin/sh /etc/rc.common
#加入服务配置，sh脚本放在/usr/bin
START=99，
STOP=10

USE_PROCD=1

start_service() {
    procd_open_instance
    procd_set_param command /usr/bin/ttyd -t titleFixed=ash -- /bin/sh /etc/save_path.sh
    procd_set_param respawn
    procd_close_instance
}
