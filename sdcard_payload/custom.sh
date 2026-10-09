#!/bin/sh
# ==============================================================================
# Insta360 X5 Custom User Execution Script
# Called by bootup.sh at end of boot
# ==============================================================================

echo "[custom.sh] Running user customizations..."

# 1. Create a clear proof-of-execution file on the SD card root
echo "==================================================" > /tmp/SD0/TEST_HARNESS_SUCCESS.txt
echo "Insta360 X5 Test Harness executed successfully!" >> /tmp/SD0/TEST_HARNESS_SUCCESS.txt
echo "Boot timestamp: $(date)" >> /tmp/SD0/TEST_HARNESS_SUCCESS.txt
echo "Kernel: $(uname -a)" >> /tmp/SD0/TEST_HARNESS_SUCCESS.txt
echo "Uptime: $(uptime)" >> /tmp/SD0/TEST_HARNESS_SUCCESS.txt
echo "==================================================" >> /tmp/SD0/TEST_HARNESS_SUCCESS.txt

# 2. Dump active running processes so you can inspect what is running
ps > /tmp/SD0/camera_running_processes.txt 2>/dev/null

echo "[custom.sh] User script complete."
