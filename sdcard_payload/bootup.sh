#!/bin/sh
# ==============================================================================
# Insta360 X5 MicroSD Boot Injection Script
# Invoked by: /etc/init.d/S99bootdone (line 65)
# Target Environment: Ambarella CV5 AArch64 Linux 5.10
# ==============================================================================

LOGFILE="/tmp/SD0/bootup.log"

log_msg() {
    local msg="[$(date +'%Y-%m-%d %H:%M:%S')] [bootup.sh] $1"
    logger -t "bootup.sh" "$1"
    echo "$msg" >> "$LOGFILE"
    echo "$msg"
}

echo "========================================" >> "$LOGFILE"
log_msg "Insta360 X5 test harness starting..."

# ------------------------------------------------------------------------------
# 1. Load Optional Config Overrides
# ------------------------------------------------------------------------------
ENABLE_ADB=1
ENABLE_USB_SERIAL=0
ENABLE_CUSTOM_PARAMS=1
FORCE_WIFI_5G=0

if [ -f "/tmp/SD0/config.sh" ]; then
    log_msg "Sourcing user configuration from /tmp/SD0/config.sh..."
    source "/tmp/SD0/config.sh"
fi

# ------------------------------------------------------------------------------
# 2. Dynamic Configuration Bind-Mounting
# ------------------------------------------------------------------------------
if [ "$ENABLE_CUSTOM_PARAMS" -eq 1 ]; then
    if [ -f "/tmp/SD0/camera_params.json" ]; then
        log_msg "Verifying camera_params.json bind-mounts..."
        
        mount --bind /tmp/SD0/camera_params.json /usr/local/share/script/camera_params.json 2>/dev/null
        mount --bind /tmp/SD0/camera_params.json /pref/camera_params.json 2>/dev/null
        
        if [ -f "/tmp/SD0/camera_params.json.zip" ]; then
            mount --bind /tmp/SD0/camera_params.json.zip /usr/local/share/script/camera_params.json.zip 2>/dev/null
            mount --bind /tmp/SD0/camera_params.json.zip /pref/camera_params.json.zip 2>/dev/null
        fi
        
        # Verify if instaAIP was started before mounts
        if [ ! -f "/tmp/instaAIP_hijacked" ]; then
            log_msg "instaAIP was started prior to mounts! Reloading daemon..."
            killall -9 instaAIP 2>/dev/null
            sleep 1
            /usr/bin/instaAIP &
            log_msg "instaAIP reloaded with custom parameters (PID: $!)"
        else
            log_msg "instaAIP was cleanly intercepted via hijack hook."
        fi
    fi
fi

# ------------------------------------------------------------------------------
# 3. Android Debug Bridge (ADB) Daemon Activation
# ------------------------------------------------------------------------------
if [ "$ENABLE_ADB" -eq 1 ]; then
    if [ -x "/usr/bin/adbd" ]; then
        log_msg "Starting adbd daemon in background..."
        /usr/bin/adbd &
        log_msg "adbd spawned (PID: $!)"
    else
        log_msg "Warning: /usr/bin/adbd not found or not executable."
    fi
fi

# ------------------------------------------------------------------------------
# 4. USB Root Serial Console (Getty on /dev/ttyGS0)
# ------------------------------------------------------------------------------
if [ "$ENABLE_USB_SERIAL" -eq 1 ]; then
    if [ -x "/usr/local/share/script/usb_console.sh" ]; then
        log_msg "Activating USB serial console via usb_console.sh..."
        /usr/local/share/script/usb_console.sh &
        log_msg "usb_console.sh spawned"
    fi
fi

# ------------------------------------------------------------------------------
# 5. Force 5.8 GHz FCC Wi-Fi Regulatory Domain
# ------------------------------------------------------------------------------
if [ "$FORCE_WIFI_5G" -eq 1 ]; then
    if [ -x "/usr/local/share/script/wifi_setfreq.sh" ]; then
        log_msg "Forcing Wi-Fi regulatory domain US Channel 149..."
        /usr/local/share/script/wifi_setfreq.sh US 149 &
    fi
fi

# ------------------------------------------------------------------------------
# 6. Execute Optional Custom User Script
# ------------------------------------------------------------------------------
if [ -f "/tmp/SD0/custom.sh" ]; then
    log_msg "Executing user custom script /tmp/SD0/custom.sh..."
    chmod +x /tmp/SD0/custom.sh 2>/dev/null
    /bin/sh /tmp/SD0/custom.sh >> "$LOGFILE" 2>&1
    log_msg "custom.sh finished (exit: $?)"
fi

log_msg "Insta360 X5 test harness initialization complete."
echo "========================================" >> "$LOGFILE"
exit 0
