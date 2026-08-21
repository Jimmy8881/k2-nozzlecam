#!/bin/sh

set -e

SCRIPT_DIR="$(readlink -f $(dirname $0))"

# remove the installed file/symlink and restore original auto_uvc if backup exists
if [ -e /usr/bin/auto_uvc.sh.bak ]; then
    rm -f /usr/bin/auto_uvc.sh
    mv /usr/bin/auto_uvc.sh.bak /usr/bin/auto_uvc.sh
fi

# remove the installed file/symlink and restore original 60-v4l if backup exists
if [ -e /etc/hotplug.d/usb/60-v4l.bak ]; then
    rm -f /etc/hotplug.d/usb/60-v4l
    mv /etc/hotplug.d/usb/60-v4l.bak /etc/hotplug.d/usb/60-v4l
fi

# remove the installed file and restore original rc.local if backup exists
if [ -e /etc/rc.local.bak ]; then
    rm -f /etc/rc.local
    mv /etc/rc.local.bak /etc/rc.local
fi

# remove the old symlinks
rm -f /usr/bin/ustreamer
rm -f /usr/share/klipper/klippy/extras/gcode_shell_command.py

# remove the v4lctls.cfg file
rm -f /mnt/UDISK/printer_data/config/custom/v4lctls.cfg

# remove the init.d ustream script and config folder
rm -rf /etc/ustreamer
rm -f /etc/init.d/ustreamer

# remove the v4lctls gcode macro line from main.cfg
python "${SCRIPT_DIR}/ensure_included.py" \
    ~/printer_data/config/custom/main.cfg v4lctls.cfg --remove

echo "Uninstallation complete. reboot the system to apply changes."

