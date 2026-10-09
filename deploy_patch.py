import os
import json
import zipfile
import shutil

PAYLOAD_DIR = r"sdcard_payload"
F_DRIVE = r"F:\\"

# 1. Update camera_params.json schema
params_path = os.path.join(PAYLOAD_DIR, "camera_params.json")
with open(params_path, "r", encoding="utf-8") as f:
    params = json.load(f)

# Patch Sphere06C (360 mode) VIDEO_NORMAL: enable i_log across all framerates and resolutions (including non-HDR and 8K)
if "Sphere06C" in params and "VIDEO_NORMAL" in params["Sphere06C"]:
    v_norm = params["Sphere06C"]["VIDEO_NORMAL"]
    if "i_log_switch" in v_norm and "list" in v_norm["i_log_switch"]:
        l = v_norm["i_log_switch"]["list"]
        for k in list(l.keys()):
            if k != "default" and l[k] == []:
                l[k] = ["true", "false"]

# Patch Fisheyes06C (Single Lens Flat & FreeFrame)
if "Fisheyes06C" in params:
    for mode_name in ["VIDEO_NORMAL", "VIDEO_SUPER"]:
        if mode_name in params["Fisheyes06C"]:
            m = params["Fisheyes06C"][mode_name]
            supp = m.get("support_attrs", [])
            for attr in ["i_log_switch", "color_mode"]:
                if attr not in supp:
                    supp.append(attr)
            m["support_attrs"] = supp
            m["i_log_switch"] = {
                "depend_on": [],
                "list": {
                    "default": ["true", "false"]
                }
            }
            m["color_mode"] = {
                "depend_on": ["i_log_switch"],
                "list": {
                    "default": [],
                    "false": ["STANDARD", "VIVID", "FLAT"],
                    "true": []
                }
            }

with open(params_path, "w", encoding="utf-8") as f:
    json.dump(params, f, indent=4)

print("Updated sdcard_payload/camera_params.json")

# Create zip version
zip_path = os.path.join(PAYLOAD_DIR, "camera_params.json.zip")
with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as z:
    z.write(params_path, arcname="camera_params.json")

print("Created sdcard_payload/camera_params.json.zip")

# 2. Write sdcard_payload/instaAIP
instaAIP_script = """#!/bin/sh
# ==============================================================================
# Insta360 X5 instaAIP Hijack Hook
# Executed by /etc/init.d/S99bootdone at Line 43
# ==============================================================================

LOGFILE="/tmp/SD0/bootup.log"

echo "========================================" >> "$LOGFILE"
echo "[$(date +'%Y-%m-%d %H:%M:%S')] [instaAIP hijack] S99bootdone hijack hook triggered!" >> "$LOGFILE"

# 1. Apply bind mounts over both camera_params.json paths BEFORE instaAIP reads them
mount --bind /tmp/SD0/camera_params.json /usr/local/share/script/camera_params.json
mount --bind /tmp/SD0/camera_params.json /pref/camera_params.json
echo "[$(date +'%Y-%m-%d %H:%M:%S')] [instaAIP hijack] camera_params.json bind-mounted to /usr/local/share/script/ and /pref/" >> "$LOGFILE"

# 2. Apply bind mounts over camera_params.json.zip if present
if [ -f /tmp/SD0/camera_params.json.zip ]; then
    mount --bind /tmp/SD0/camera_params.json.zip /usr/local/share/script/camera_params.json.zip
    mount --bind /tmp/SD0/camera_params.json.zip /pref/camera_params.json.zip
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [instaAIP hijack] camera_params.json.zip bind-mounted" >> "$LOGFILE"
fi

touch /tmp/instaAIP_hijacked
echo "[$(date +'%Y-%m-%d %H:%M:%S')] [instaAIP hijack] Executing /usr/bin/instaAIP with patched parameters..." >> "$LOGFILE"

# 3. Exec real binary
exec /usr/bin/instaAIP "$@"
""".replace("\r\n", "\n")

with open(os.path.join(PAYLOAD_DIR, "instaAIP"), "wb") as f:
    f.write(instaAIP_script.encode("utf-8"))

print("Created sdcard_payload/instaAIP")

# 3. Update sdcard_payload/bootup.sh
bootup_script = """#!/bin/sh
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
""".replace("\r\n", "\n")

with open(os.path.join(PAYLOAD_DIR, "bootup.sh"), "wb") as f:
    f.write(bootup_script.encode("utf-8"))

print("Updated sdcard_payload/bootup.sh")

# 4. Update sdcard_payload/custom.sh to dump diagnostics
custom_script = """#!/bin/sh
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

echo "[custom.sh] User script complete."
""".replace("\r\n", "\n")

with open(os.path.join(PAYLOAD_DIR, "custom.sh"), "wb") as f:
    f.write(custom_script.encode("utf-8"))

print("Updated sdcard_payload/custom.sh")

# 5. Deploy to F:\ if F:\ is mounted
if os.path.exists(F_DRIVE):
    print(f"Deploying to physical SD card at {F_DRIVE}...")
    for fname in ["camera_params.json", "camera_params.json.zip", "instaAIP", "bootup.sh", "custom.sh", "config.sh", "README.md"]:
        src = os.path.join(PAYLOAD_DIR, fname)
        dst = os.path.join(F_DRIVE, fname)
        if os.path.exists(src):
            shutil.copy2(src, dst)
            print(f"  Copied {fname} -> {dst}")
    print("Deployment to F: complete!")
else:
    print(f"Drive {F_DRIVE} not found. Skipped physical copy.")
