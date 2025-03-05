#!/bin/sh

# Ensure the save_path.sh script is executable
chmod +x /etc/save.sh

# Launch ttyd with the save_path.sh script
ttyd -t titleFixed=ash -- /bin/sh /etc/save.sh
