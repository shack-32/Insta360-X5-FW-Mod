# Insta360 X5 Firmware Modification & Reverse Engineering Toolkit

Reverse engineering, firmware carving, decompilation analysis, and non-invasive runtime modification harness for the **Insta360 X5** action camera.

---

## 📸 System Overview

* **SoC:** Ambarella CV5 (Dual-core ARM Cortex-A53 / ARM64 v8A + CVflow Vector NPU/DSP + RTOS Dual-Core Subsystem)
* **OS:** Linux 5.10.61 SMP PREEMPT (AArch64) + Ambarella RTOS (ThreadX)
* **Image Sensors:** Dual OmniVision OV50H 1/1.3-inch (5984 × 5984 active pixels each, profile `06C`)
* **Primary Daemons:**
  * `instaAIP`: Network management, Google Open Spherical Camera (OSC) REST engine (`libevhtp`), Wi-Fi coordinator
  * `instaAlg`: Real-time binocular stitching (`bcv::stitcher`), Multi-Grid Poisson blending, Laplacian pyramid fusion, Ceres quaternion stabilization, and MNN neural network inference
  * `amba_camctrl`: Ambarella low-level IPC hardware bridge connecting userland to RTOS / IDSP (`0x10000100`)

---

## ⚡ Zero-Risk MicroSD Test Harness (Live Tested & Verified)

The repository includes a **non-invasive, zero-risk test harness** that executes code and injects configurations directly from the MicroSD card without flashing or touching the camera's internal NAND storage.

### How It Works
At the end of Linux startup, `/etc/init.d/S99bootdone` contains a diagnostic check:
```sh
if [ -x /tmp/SD0/bootup.sh ]; then
    LOG "inject SD0 boot.sh"
    /tmp/SD0/bootup.sh
fi
```
Ambarella RTOS mounts the primary MicroSD card to `/tmp/SD0`. Placing [`bootup.sh`](sdcard_payload/bootup.sh) on the card executes custom root scripts, applies RAM VFS bind-mounts over configuration files, and launches root debugging tools.

> **Zero-Risk Guarantee:**  
> All configuration overrides exist strictly in volatile RAM. Pulling the MicroSD card instantly restores 100% factory stock behavior.

---

## 🚀 Quick Start: Deploying to MicroSD

1. Format a MicroSD card as **exFAT** or **FAT32**.
2. Copy the contents of [`sdcard_payload/`](sdcard_payload/) directly to the **root** of the card:
   ```text
   [MicroSD Card Root]
   ├── bootup.sh           # Master injection script
   ├── config.sh           # Feature toggles (ENABLE_ADB, FORCE_WIFI_5G, etc.)
   ├── custom.sh           # User custom commands
   └── camera_params.json  # Live parameter overrides (resolutions, bitrates, FOVs)
   ```
3. Insert into the camera and power on.
4. **Verification:** Inspect `TEST_HARNESS_SUCCESS.txt` and `bootup.log` created automatically on the card.
5. **Interactive Root Shell:** Connect USB-C to a PC and run:
   ```bash
   adb shell
   ```

---

## 📚 Technical Documentation & Research Reports

* [Architecture & Reverse Engineering Master Report](docs/Architecture_Report.md)
* [Option C Ghidra Decompilation Deep Dive](docs/Option_C_Ghidra_Deep_Dive.md)
  * `amba_camctrl` IPC protocol (`0xf001xxxx` to `0xf007xxxx`)
  * `instaAIP` OSC REST endpoint routing (`/osc/commands/execute`, `/osc/state`, `/osc/info`)
  * `instaAlg` 11-thread IPCC pipeline, CVflow memory pools, and image fusion algorithms
* [360 vs Single Lens Noise Reduction Analysis](docs/Architecture_Report.md#sensor-and-optical-pipeline)
  * Explains why 360 mode captures 5× more light area than Single Lens Flat mode
  * Tangential dewarping $\sec^2\theta$ noise stretching dynamics
  * 6 dB SNR boost from 8K/5.7K spherical supersampling

---

## 🛠️ Repository Contents

* `sdcard_payload/`: Complete pre-configured payload ready to copy to a MicroSD card.
* `extract_sys_sw.py`: Script to carve and unpack the `sys_sw.ubi` partition from `Insta360X5FW.bin`.
* `parse_ubi.py`: UBI partition and filesystem header parser.
* `docs/`: Technical reports, decompiled signatures, and protocol specifications.

---

## ⚖️ License & Disclaimer

This project is for educational, research, and interoperability purposes only. All product and company names are trademarks™ or registered® trademarks of their respective holders.
