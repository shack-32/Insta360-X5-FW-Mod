#!/bin/sh
# ==============================================================================
# Insta360 X5 Custom User Execution Script
# Called by bootup.sh at end of boot
# ==============================================================================

echo "[custom.sh] Running user customizations..."

# 1. Proof of execution
echo "==================================================" > /tmp/SD0/TEST_HARNESS_SUCCESS.txt
echo "Insta360 X5 Test Harness executed successfully!" >> /tmp/SD0/TEST_HARNESS_SUCCESS.txt
echo "Boot timestamp: $(date)" >> /tmp/SD0/TEST_HARNESS_SUCCESS.txt
echo "Kernel: $(uname -a)" >> /tmp/SD0/TEST_HARNESS_SUCCESS.txt
echo "Uptime: $(uptime)" >> /tmp/SD0/TEST_HARNESS_SUCCESS.txt
echo "==================================================" >> /tmp/SD0/TEST_HARNESS_SUCCESS.txt

# 2. Dump active running processes
ps > /tmp/SD0/camera_running_processes.txt 2>/dev/null

# 3. Dump active mounts (proves bind mounts are live)
cat /proc/mounts > /tmp/SD0/mounts_dump.txt 2>/dev/null

# 4. Dump system log (syslog)
logread > /tmp/SD0/syslog_dump.txt 2>/dev/null

# 5. Deep diagnostics (verifies what the bind-mounts actually serve)
if [ -f "/tmp/SD0/diag.sh" ]; then
    /bin/sh /tmp/SD0/diag.sh
fi

echo "[custom.sh] User script complete."
