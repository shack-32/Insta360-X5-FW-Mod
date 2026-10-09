#!/bin/sh
# ==============================================================================
# Insta360 X5 Deep Diagnostic Collector
# Can be run at boot (from custom.sh) or manually over ADB:
#     sh /tmp/SD0/diag.sh
# Writes everything to /tmp/SD0/diag_<timestamp>/
# ==============================================================================

OUT="/tmp/SD0/diag"
mkdir -p "$OUT"

log() { echo "[diag] $1"; }

# ------------------------------------------------------------------------------
# 1. Prove what content the bind-mounts actually serve
# ------------------------------------------------------------------------------
{
    echo "=== md5sums ==="
    md5sum /tmp/SD0/camera_params.json \
           /usr/local/share/script/camera_params.json \
           /pref/camera_params.json \
           /tmp/SD0/camera_params.json.zip \
           /usr/local/share/script/camera_params.json.zip \
           /pref/camera_params.json.zip 2>&1
    echo
    echo "=== ls -li (inode/dev proves bind source) ==="
    ls -li /tmp/SD0/camera_params.json \
           /usr/local/share/script/camera_params.json \
           /pref/camera_params.json 2>&1
    echo
    echo "=== sizes ==="
    wc -c /tmp/SD0/camera_params.json \
          /usr/local/share/script/camera_params.json \
          /pref/camera_params.json 2>&1
    echo
    echo "=== i_log_switch occurrences in each live path ==="
    for f in /tmp/SD0/camera_params.json /usr/local/share/script/camera_params.json /pref/camera_params.json; do
        printf '%s : ' "$f"
        grep -c i_log_switch "$f" 2>&1
    done
} > "$OUT/live_params_check.txt" 2>&1

# ------------------------------------------------------------------------------
# 2. Extract the exact single-lens + 360 capability blocks from the LIVE file
#    (python may not exist; busybox sed/awk fallback). We dump the region.
# ------------------------------------------------------------------------------
{
    echo "=== Fisheyes06C VIDEO_NORMAL region (first i_log_switch) ==="
    awk '/"VIDEO_NORMAL"/{f=1} f{print NR": "$0} f&&/^        },/{exit}' \
        /usr/local/share/script/camera_params.json 2>&1 | head -200
} > "$OUT/fisheyes_region.txt" 2>&1

# ------------------------------------------------------------------------------
# 3. Config files present in the system
# ------------------------------------------------------------------------------
{
    echo "=== /usr/local/share/script/*.json / *.zip / *.7z ==="
    ls -la /usr/local/share/script/*.json* /usr/local/share/script/*.7z 2>&1
    echo
    echo "=== /pref contents ==="
    ls -la /pref 2>&1
    echo
    echo "=== /tmp/FL0 top-level ==="
    ls -la /tmp/FL0 2>&1 | head -40
    echo
    echo "=== /tmp/FL1 top-level ==="
    ls -la /tmp/FL1 2>&1 | head -40
} > "$OUT/config_files.txt" 2>&1

# ------------------------------------------------------------------------------
# 4. Live process table, mounts, open fds of daemons
# ------------------------------------------------------------------------------
ps > "$OUT/ps.txt" 2>&1
cat /proc/mounts > "$OUT/mounts.txt" 2>&1
for p in instaAIP instaAlg instaMonitor; do
    pid=$(pidof "$p" 2>/dev/null)
    if [ -n "$pid" ]; then
        echo "=== $p pid=$pid fd ===" > "$OUT/fd_$p.txt"
        ls -l /proc/$pid/fd >> "$OUT/fd_$p.txt" 2>&1
        echo "=== $p maps (camera_params lines) ===" >> "$OUT/fd_$p.txt"
        grep -i camera_params /proc/$pid/maps >> "$OUT/fd_$p.txt" 2>&1
        echo "=== $p cmdline ===" >> "$OUT/fd_$p.txt"
        cat /proc/$pid/cmdline >> "$OUT/fd_$p.txt" 2>&1
        echo >> "$OUT/fd_$p.txt"
    fi
done

# ------------------------------------------------------------------------------
# 5. Kernel + app logs
# ------------------------------------------------------------------------------
dmesg > "$OUT/dmesg.txt" 2>&1
logread > "$OUT/logread.txt" 2>&1
cat /proc/rpmsg_insta360_scull 2>/dev/null > "$OUT/rpmsg_scull.txt"
ls -la /dev/rpmsg* > "$OUT/rpmsg_devs.txt" 2>&1

# ------------------------------------------------------------------------------
# 6. Copy the raw live JSONs off-device for byte comparison
# ------------------------------------------------------------------------------
cp /usr/local/share/script/camera_params.json "$OUT/live_usr_local_camera_params.json" 2>/dev/null
cp /pref/camera_params.json "$OUT/live_pref_camera_params.json" 2>/dev/null

echo "[diag] complete -> $OUT" 
