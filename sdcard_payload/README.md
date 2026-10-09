# Insta360 X5 MicroSD Test Harness (Track 1)

This package contains the pre-configured files for the **non-invasive, zero-risk microSD test harness** for the Insta360 X5.

> **Zero Risk Notice:**  
> These files run exclusively from RAM and the microSD card. Nothing is permanently written to the camera's internal NAND flash. Removing the microSD card instantly returns the camera to 100% stock factory behavior.

---

## 1. File Manifest

* [`bootup.sh`](file:///c:/Users/shane/Documents/Ghidra/X5_FW/sdcard_payload/bootup.sh): The master injection script automatically called by `/etc/init.d/S99bootdone` (line 65) with root permissions.
* [`config.sh`](file:///c:/Users/shane/Documents/Ghidra/X5_FW/sdcard_payload/config.sh): Configuration toggles (`ENABLE_ADB`, `ENABLE_USB_SERIAL`, `ENABLE_CUSTOM_PARAMS`, `FORCE_WIFI_5G`).
* [`custom.sh`](file:///c:/Users/shane/Documents/Ghidra/X5_FW/sdcard_payload/custom.sh): Optional user script for arbitrary shell commands.
* [`camera_params.json`](file:///c:/Users/shane/Documents/Ghidra/X5_FW/sdcard_payload/camera_params.json): Complete stock configuration extracted from the firmware, ready for editing.

---

## 2. Deployment Instructions (When Ready to Test on Hardware)

1. Format a microSD card as **exFAT** or **FAT32** in the camera or on a computer.
2. Copy the files from `sdcard_payload/` directly to the **root** of the microSD card:
   ```
   [MicroSD Root Directory]
   ├── bootup.sh
   ├── config.sh
   ├── custom.sh
   └── camera_params.json
   ```
3. Insert the card into the camera and power it on.

---

## 3. How to Connect & Verify

### A. Verify Execution via Log File
After boot, `bootup.sh` automatically writes progress and diagnostics to:
```
[MicroSD Root Directory]/bootup.log
```
Open `bootup.log` on your computer or through a shell to confirm that each module was initialized properly.

### B. Accessing Root Shell via ADB (`ENABLE_ADB=1`)
1. Connect the camera to your PC with a USB-C cable.
2. Open a terminal / command prompt and run:
   ```sh
   adb devices
   adb shell
   ```
3. You will immediately have an interactive root shell (`#`) on the camera's Linux 5.10 environment.

### C. Accessing via USB Serial Console (`ENABLE_USB_SERIAL=1`)
1. In `config.sh`, set `ENABLE_USB_SERIAL=1`.
2. Connect via USB-C. Windows will enumerate a COM port (`/dev/ttyGS0`).
3. Open PuTTY / TeraTerm connected to that COM port at **115200 baud, 8N1** for a passwordless root getty login.

---

## 4. How to Test Parameter Modifications

To test new camera parameters (bitrates, resolutions, modes):
1. Edit `camera_params.json` on the microSD card.
2. Boot the camera with `ENABLE_CUSTOM_PARAMS=1` in `config.sh`.
3. `bootup.sh` will dynamically bind-mount the file over `/usr/local/share/script/camera_params.json` and `/pref/camera_params.json`.
4. The camera app / UI will immediately reflect your modified resolution, framerate, or bitrate options.
