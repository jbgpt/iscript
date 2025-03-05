#结合ttydrun 一起使用于openwrt路由的ttyd
#!/bin/sh
LAST_DIR_FILE="/etc/last_dir"
save_dir() {
    echo "$(pwd)" > $LAST_DIR_FILE
}
restore_dir() {
    if [ -f $LAST_DIR_FILE ]; then
        cd "$(cat $LAST_DIR_FILE)"
    fi
}
trap save_dir EXIT
restore_dir
exec "$SHELL"
