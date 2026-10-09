#!/bin/sh
# ==============================================================================
# Insta360 X5 Test Harness Configuration Toggles
# Sourced by: bootup.sh
# ==============================================================================

# Enable Android Debug Bridge daemon (provides 'adb shell' over USB)
# 1 = enabled, 0 = disabled
ENABLE_ADB=1

# Enable USB serial root getty console (/dev/ttyGS0 at 115200 baud)
# 1 = enabled, 0 = disabled
ENABLE_USB_SERIAL=0

# Bind-mount custom camera_params.json from SD card over system config
# 1 = enabled, 0 = disabled
ENABLE_CUSTOM_PARAMS=1

# Force high-power 5.8 GHz FCC Wi-Fi Channel 149
# 1 = enabled, 0 = disabled
FORCE_WIFI_5G=0

# Start a RAM-only root shell over the camera's Wi-Fi AP (busybox telnetd, port 2323)
# 1 = enabled, 0 = disabled. Nothing is written to NAND; reboot removes it.
ENABLE_TELNETD=1
