#!/bin/sh

set -e

SCRIPT_DIR="$(readlink -f $(dirname $0))"

# remove the v4lctls.cfg file
rm -f /mnt/UDISK/printer_data/config/v4lctls.cfg

# remove the nozzle_cam.env file
rm -f /etc/ustreamer/nozzle_cam.env

# remove the camera-assignment.rules file
rm -f /etc/udev/rules.d/camera-assignment.rules

# remove the 3dov4lctls gcode macro line from overrides.cfg
python "${SCRIPT_DIR}/ensure_included.py" \
    ~/printer_data/config/overrides.cfg 3dov4lctls.cfg --remove

echo "Uninstallation complete. reboot the system to apply changes."
