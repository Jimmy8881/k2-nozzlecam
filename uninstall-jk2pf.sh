#!/bin/sh

set -e

SCRIPT_DIR="$(readlink -f $(dirname $0))"

echo "Removing 3DO Nozzle Camera from Moonraker database..."

# Safely extract the UID using Python's native JSON module
WEBCAM_UID=$(curl -s http://localhost:7125/server/webcams/list | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    webcams = data.get('result', {}).get('webcams', data.get('webcams', []))
    for cam in webcams:
        if cam.get('name') == '3DO Nozzle Camera':
            print(cam.get('uid', ''))
            break
except Exception:
    pass
")

# If a matching entry is found in the database, delete it
if [ -n "$WEBCAM_UID" ]; then
    echo "Found registration with UID: ${WEBCAM_UID}. Deleting..."
    curl -s -X DELETE "http://localhost:7125/server/webcams/item?uid=${WEBCAM_UID}" || true
else
    echo "No matching Moonraker webcam registration found. Skipping database removal."
fi

# disable and stop the ustreamer service (|| true ensures it won't crash if already stopped)
systemctl disable ustreamer@nozzle_cam || true
systemctl stop ustreamer@nozzle_cam || true

# remove the 3dov4lctrls.cfg file
rm -f /mnt/UDISK/printer_data/config/3dov4lctrls.cfg

# remove the nozzle_cam.env file
rm -f /etc/ustreamer/nozzle_cam.env

# remove the installed file/symlink and restore original stockcam.env if backup exists
if [ -e /etc/ustreamer/stockcam.bak ]; then
    rm -f /etc/ustreamer/stockcam.env
    mv /etc/ustreamer/stockcam.bak /etc/ustreamer/stockcam.env
fi

# remove the camera-assignment.rules file
rm -f /etc/udev/rules.d/camera-assignment.rules

# remove the camera Macro configurations  
python "${SCRIPT_DIR}/undo_macro_sorting.py"

# remove the 3dov4lctls gcode macro line from overrides.cfg
python "${SCRIPT_DIR}/ensure_included.py" \
    ~/printer_data/config/overrides.cfg 3dov4lctls.cfg --remove

echo "Uninstallation complete. reboot the system to apply changes."
