#!/bin/sh

set -e

SCRIPT_DIR="$(readlink -f $(dirname $0))"

# backup original auto_uvc if present
if [ -e /usr/bin/auto_uvc.sh ] || [ -L /usr/bin/auto_uvc.sh ]; then
    cp -p /usr/bin/auto_uvc.sh /usr/bin/auto_uvc.sh.bak
fi

# symlink the new script into place
ln -sf "${SCRIPT_DIR}/auto_uvc.sh" /usr/bin/auto_uvc.sh

# backup original 60-v4l if present
if [ -e /etc/hotplug.d/usb/60-v4l ] || [ -L /etc/hotplug.d/usb/60-v4l ]; then
    cp -p /etc/hotplug.d/usb/60-v4l /etc/hotplug.d/usb/60-v4l.bak
fi

# symlink the udev rule into place
ln -sf "${SCRIPT_DIR}/60-v4l" /etc/hotplug.d/usb/60-v4l

# backup original rc.local if present
if [ -e /etc/rc.local ] || [ -L /etc/rc.local ]; then
    cp -p /etc/rc.local /etc/rc.local.bak
fi

#copy the rc.local script to /etc/
cp -f "${SCRIPT_DIR}/etc/rc.local" /etc/rc.local

# symlink the ustreamer binary into /usr/bin
ln -sf "${SCRIPT_DIR}/ustreamer" /usr/bin/ustreamer

# adds gcode_shell_command to klipper
ln -sf "${SCRIPT_DIR}/gcode_shell_command.py" /usr/share/klipper/klippy/extras/gcode_shell_command.py

# copy the v4lctls.cfg to /mnt/UDISK/printer_data/config/custom/
cp -f "${SCRIPT_DIR}/v4lctls.cfg" /mnt/UDISK/printer_data/config/custom/v4lctls.cfg

#copy the ustreamer script to /etc/init.d/
cp -f "${SCRIPT_DIR}/etc/init.d/ustreamer" /etc/init.d/ustreamer

#create the folder /etc/ustreamer
mkdir -p /etc/ustreamer

#copy the cameras config file to /etc/ustreamer/
cp -f "${SCRIPT_DIR}/etc/ustreamer/cameras.conf" /etc/ustreamer/cameras.conf

# make the new files executable
chmod 755 /etc/hotplug.d/usb/60-v4l
chmod 755 /usr/bin/auto_uvc.sh
chmod 755 /etc/init.d/ustreamer
chmod 755 /etc/ustreamer/cameras.conf
chmod 755 /usr/bin/ustreamer
chmod 775 /etc/rc.local

# add the macro into the printer.cfg file
python "${SCRIPT_DIR}/ensure_included.py" \
    ~/printer_data/config/custom/main.cfg v4lctls.cfg

# Enable and start the ustreamer service automatically
/etc/init.d/ustreamer enable
/etc/init.d/ustreamer start

# sort the camera Macros by category and colors  
python "${SCRIPT_DIR}/macro_sorting.py"

# Auto-detect printer IP on BusyBox/Creality OS environments
PRINTER_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7}')

# Fallback in case ip route fails
if [ -z "$PRINTER_IP" ]; then
    PRINTER_IP=$(ifconfig wlan0 2>/dev/null | awk '/inet / {print $2}' | sed 's/addr://')
fi

# Final fallback for Ethernet connection
if [ -z "$PRINTER_IP" ]; then
    PRINTER_IP=$(ifconfig eth0 2>/dev/null | awk '/inet / {print $2}' | sed 's/addr://')
fi

echo "Detected current printer IP: ${PRINTER_IP}"

echo "Registering 3DO Nozzle Camera with Moonraker..."
curl -s -X POST http://localhost:7125/server/webcams/item \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"3DO Nozzle Camera\",
    \"enabled\": true,
    \"icon\": \"mdiPrinter3dNozzle\",
    \"location\": \"nozzle\",
    \"service\": \"uv4l-mjpeg\",
    \"stream_url\": \"http://${PRINTER_IP}:8081/?action=stream\",
    \"snapshot_url\": \"http://${PRINTER_IP}:8081/?action=snapshot\"
  }"

echo "Installation complete. reboot the system to apply changes."
