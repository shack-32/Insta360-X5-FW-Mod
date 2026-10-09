# Insta360 X5 Firmware Modification & Reverse Engineering Toolkit

Reverse engineering, firmware carving, decompilation analysis, and non-invasive runtime modification harness for the **Insta360 X5** action camera.

---

## 📸 System Overview

* **SoC:** Ambarella CV5 (Dual-core ARM Cortex-A53 / ARM64 v8A + CVflow Vector NPU/DSP + RTOS Dual-Core Subsystem)
* **OS:** Linux 5.10.61 SMP PREEMPT (AArch64) + Ambarella RTOS (ThreadX)
* **Image Sensors:** Dual OmniVision OV50H 1/1.3-inch (5984 × 5984 active pixels each, profile `06C`)
* **Primary Daemons:**
  * `instaAIP`: Network management, Google Open Spherical Camera (OSC) REST engine (`libevhtp`), parameter coordinator
  * `instaAlg`: Real-time binocular stitching (`bcv::stitcher`), Multi-Grid Poisson blending, Laplacian pyramid fusion, Ceres quaternion stabilization, and MNN neural network inference
  * `amba_camctrl`: Ambarella low-level IPC hardware bridge connecting userland to RTOS / IDSP (`0x10000100`)

---

## ⚡ Zero-Risk MicroSD Test Harness (Live Tested & Verified)

The repository includes a **non-invasive, zero-risk test harness** that executes code and injects configurations directly from the MicroSD card without flashing or touching the camera's internal NAND storage.

### How It Works
Ambarella RTOS mounts the primary MicroSD card to `/tmp/SD0`. `/etc/init.d/S99bootdone` provides two diagnostic execution hooks:
1. **Daemon Hijack Hook (Lines 43–46):** Runs `/tmp/SD0/instaAIP` before the factory daemon starts, allowing bind-mounts to be established in memory before parameters are parsed.
2. **Synchronous Script Injection (Lines 63–71):** Runs `/tmp/SD0/bootup.sh` as root, enabling ADB daemon, serial console, and diagnostic telemetry.

> **Zero-Risk Guarantee:**  
> All configuration overrides exist strictly in volatile RAM. Removing the MicroSD card instantly restores 100% factory stock behavior.

---

## 🚀 Quick Start: Deploying to MicroSD

1. Format a MicroSD card as **exFAT** or **FAT32**.
2. Copy the contents of [`sdcard_payload/`](sdcard_payload/) directly to the **root** of the card:
   ```text
   [MicroSD Card Root]
   ├── instaAIP                     # S99bootdone line 43 early-boot hijack hook
   ├── camera_params.json           # Patched parameters (iLog decoupled & Single Lens enabled)
   ├── camera_params.json.zip       # Compressed mirror of patched parameters
   ├── bootup.sh                    # Line 65 master script (ADB, USB serial, watchdog reload)
   ├── config.sh                    # User toggles (ENABLE_ADB=1, FORCE_WIFI_5G=0, etc.)
   ├── custom.sh                    # Diagnostic dumper (/proc/mounts, logread, ps)
   └── README.md                    # Payload documentation
   ```
3. Insert into the camera and power on.
4. **Verification:** Inspect `TEST_HARNESS_SUCCESS.txt`, `bootup.log`, and `mounts_dump.txt` created automatically on the card.
5. **Interactive Root Shell:** Connect USB-C to a PC and run:
   ```bash
   adb shell
   ```

---

## 📚 Technical Documentation & Research Reports

* [🎯 Master Handoff Dossier & System Architecture](docs/MASTER_HANDOFF_DOSSIER.md) — Complete all-in-one technical reference for the project and future sessions.
* [🔬 360 vs Single Lens Noise Reduction Technical Analysis](docs/Noise_Reduction_Disparity_Analysis.md) — 5-factor mathematical analysis of the 5× active silicon disparity, tangential dewarping stretch, spherical supersampling, and MCTF dynamics.
* [🎨 I-Log Architecture & Runtime Modification Guide](docs/ILog_Mod_and_Architecture_Guide.md) — Reverse engineering of stock HDR gating, the boot timing race condition, and the Line 43 hijack engine.
* [⚙️ Option C Ghidra Decompilation Deep Dive](docs/Option_C_Ghidra_Deep_Dive.md) — Decompiled protocols for `amba_camctrl`, `instaAIP` OSC endpoints, and `instaAlg` 11-thread IPCC pipeline.
* [📋 Full System Architecture & Container Carving Report](docs/Architecture_Report.md) — Partition offsets, ROMFS layout, and UBI container specs.

---

## 🛠️ Repository Contents

* `sdcard_payload/`: Complete pre-configured payload ready to copy to a MicroSD card.
* `deploy_patch.py`: Deployment and sync script for physical SD cards.
* `extract_sys_sw.py`: Script to carve and unpack the `sys_sw.ubi` partition from `Insta360X5FW.bin`.
* `parse_ubi.py`: UBI partition and filesystem header parser.
* `docs/`: Technical reports, decompiled signatures, and protocol specifications.

---

## ⚖️ License & Disclaimer

This project is for educational, research, and interoperability purposes only. All product and company names are trademarks™ or registered® trademarks of their respective holders.
