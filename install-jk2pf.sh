#!/bin/sh

set -e

SCRIPT_DIR="$(readlink -f $(dirname $0))"

# copy the nozzle_cam.env file to /etc/ustreamer/nozzle_cam.env
cp -f "${SCRIPT_DIR}/nozzle_cam.env" /etc/ustreamer/nozzle_cam.env

# Start the camera service immediately
systemctl start ustreamer@nozzle_cam

# Enable the service to start automatically on system boot
systemctl enable ustreamer@nozzle_cam

# copy the 3dov4lctls.cfg to /mnt/UDISK/printer_data/config/3dov4lctrls.cfg
cp -f "${SCRIPT_DIR}/3dov4lctls.cfg" /mnt/UDISK/printer_data/config/3dov4lctls.cfg

# add the macro 3dov4lctls.cfg into the printer.cfg file
python "${SCRIPT_DIR}/ensure_included.py" \
    ~/printer_data/config/overrides.cfg 3dov4lctls.cfg

# copy camera-assignment.rules to /etc/udev/rules.d/camera-assignment.rules
cp -f "${SCRIPT_DIR}/camera-assignment.rules" /etc/udev/rules.d/camera-assignment.rules
chmod 755 /etc/udev/rules.d/camera-assignment.rules

echo "Installation complete. reboot klipper to load the new 3DO camera control macros."
