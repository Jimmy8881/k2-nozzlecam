#!/bin/sh

set -e

SCRIPT_DIR="$(readlink -f $(dirname $0))"

# copy the nozzle_cam.env file to /etc/ustreamer/nozzle_cam.env
cp -f "${SCRIPT_DIR}/nozzle_cam.env" /etc/ustreamer/nozzle_cam.env

# backup original stockcam.env if present
if [ -e /etc/ustreamer/stockcam.env ] || [ -L /etc/ustreamer/stockcam.env ]; then
    cp -p /etc/ustreamer/stockcam.env /etc/ustreamer/stockcam.bak
fi

# copy the stockcam.env file to /etc/ustreamer/stockcam.env
cp -f "${SCRIPT_DIR}/stockcam.env" /etc/ustreamer/stockcam.env
    
# copy camera-assignment.rules to /etc/udev/rules.d/camera-assignment.rules
cp -f "${SCRIPT_DIR}/camera-assignment.rules" /etc/udev/rules.d/camera-assignment.rules
chmod 755 /etc/udev/rules.d/camera-assignment.rules

# Enable the service to start automatically on system boot
systemctl enable ustreamer@nozzle_cam

# copy the 3dov4lctls.cfg to /mnt/UDISK/printer_data/config/3dov4lctrls.cfg
cp -f "${SCRIPT_DIR}/3dov4lctls.cfg" /mnt/UDISK/printer_data/config/3dov4lctls.cfg

# add the macro 3dov4lctls.cfg into the printer.cfg file
python "${SCRIPT_DIR}/ensure_included.py" \
    ~/printer_data/config/overrides.cfg 3dov4lctls.cfg

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
    \"aspect_ratio\": \"4:3\",
    \"location\": \"nozzle\",
    \"service\": \"uv4l-mjpeg\",
    \"stream_url\": \"http://${PRINTER_IP}:8081/?action=stream\",
    \"snapshot_url\": \"http://${PRINTER_IP}:8081/?action=snapshot\"
  }"


echo "Installation complete. reboot klipper to load the new 3DO camera service and load the control macros."
