#!/bin/ash

set -e

SCRIPT_DIR="$(readlink -f $(dirname $0))"

# backup original auto_uvc if present
if [ -e /usr/bin/auto_uvc.sh ] || [ -L /usr/bin/auto_uvc.sh ]; then
    cp -p /usr/bin/auto_uvc.sh /usr/bin/auto_uvc.sh.bak
fi

# symlink the new script into place
ln -sf "${SCRIPT_DIR}/auto_uvc.sh" /usr/bin/auto_uvc.sh

# make the new script executable
chmod 755 /usr/bin/auto_uvc.sh

# backup original 60-v4l if present
if [ -e /etc/hotplug.d/usb/60-v4l ] || [ -L /etc/hotplug.d/usb/60-v4l ]; then
    cp -p /etc/hotplug.d/usb/60-v4l /etc/hotplug.d/usb/60-v4l.bak
fi

# symlink the udev rule into place
ln -sf "${SCRIPT_DIR}/60-v4l" /etc/hotplug.d/usb/60-v4l

# symlink the ustreamer binary into /usr/bin
ln -sf "${SCRIPT_DIR}/ustreamer_static_arm32" /usr/bin/ustreamer
chmod 755 /usr/bin/ustreamer

# adds gcode_shell_command to klipper
ln -sf "${SCRIPT_DIR}/gcode_shell_command.py" /usr/share/klipper/klippy/extras/gcode_shell_command.py

# copy the v4lctls.cfg to /mnt/UDISK/printer_data/config/custom/v4lctls.cfg
cp -f "${SCRIPT_DIR}/v4lctls.cfg" /mnt/UDISK/printer_data/config/custom/v4lctls.cfg
# add the macro into the printer.cfg file
python ${SCRIPT_DIR}/ensure_included.py \
    ~/printer_data/config/custom/main.cfg v4lctls.cfg

echo "Installation complete. reboot the system to apply changes."
