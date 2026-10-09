# I-Log in Single Lens: Investigation Log

> **Status:** OPEN — JSON-only approach did not surface I-Log in Single Lens mode.
> **Last updated:** 2026-10-09
> **Related:** [ILog_Mod_and_Architecture_Guide.md](ILog_Mod_and_Architecture_Guide.md), [MASTER_HANDOFF_DOSSIER.md](MASTER_HANDOFF_DOSSIER.md)

---

## 1. Symptom

- I-Log still appears **only in 360 mode and only with HDR enabled**.
- After patching `Fisheyes06C.VIDEO_NORMAL` / `VIDEO_SUPER` `support_attrs` and adding
  `i_log_switch` + `color_mode`, the option did **not** appear in Single Lens mode
  (Flat or FreeFrame).
- Note: stock 360 behavior (I-Log gated behind HDR) is *exactly* what the JSON rule
  `i_log_switch` produces (its `list` only returns values for `true|...` HDR keys), which
  means **the JSON rules are being honoured by *something*** — the question is *what*.

## 2. What has been proven so far

### 2.1 The SD harness and bind-mounts are live and working
`F:\mounts_dump.txt` (from a real camera boot) shows:

```
tmpfs /pref tmpfs rw,relatime 0 0
c: /usr/local/share/script/camera_params.json      ambafs rw
c: /usr/local/share/script/camera_params.json.zip  ambafs rw
c: /usr/local/share/script/camera_params.json      ambafs rw   <- re-applied by bootup.sh
c: /pref/camera_params.json                        ambafs rw
c: /usr/local/share/script/camera_params.json.zip  ambafs rw
c: /pref/camera_params.json.zip                    ambafs rw
```

`bootup.log` confirms the `instaAIP` hijack fired *before* the daemon started:
`[instaAIP hijack] camera_params.json bind-mounted ...` then
`[instaAIP hijack] Executing /usr/bin/instaAIP with patched parameters...`.

MD5 of the staged file matches the payload exactly:
`fe4340d7097be99db51f19c15db15123  camera_params.json`.

### 2.2 **No Linux binary parses the JSON rule keys**
Exhaustive string search across the entire extracted Linux rootfs
(`extracted_sys_sw/.../linux/`):

| Search term        | Only hit(s) |
| :----------------- | :---------- |
| `support_attrs`    | `camera_params.json` |
| `depend_on`        | `camera_params.json`, `common_camera_setting_proto.json` |
| `record_resolution`| `camera_params.json` |
| `filter_mode`      | `camera_params.json` (+ unrelated `libavcodec`/`bcmdhd` false positives) |
| `i_log_switch`     | `camera_params.json` |
| `SI_LOG` / `i_log` | **BOOTSTRAP/RTOS region only** (protobuf descriptors) |

`instaAIP` references the *filename* `camera_params.json` only for:
1. Copying it into volatile `/pref` on heartbeat:
   `cp /usr/local/share/script/camera_params.json pref/camera_params.json` (and `.7z`, `.zip`, `common_camera_setting_proto.json`).
2. Serving it over HTTP (`/pref/camera_params.json` string sits beside the
   `InsApp_HttpServer_Evhtp_Conf_Callback` code path).
3. Computing a config version reported over Bluetooth
   (`InsApp_BtRemote_Config_Version_Send conf_version %d`).

It does **not** contain the rule keys, any JSON-parser library symbol
(`cJSON`, `rapidjson`, `jsmn`, `jansson`, `yyjson`), nor any protobuf symbol.

### 2.3 The I-Log enum lives in the RTOS/protobuf layer
The whole-firmware scan found:

```
0x00FC1725  insta360.messages.PhotographyOptionType
0x00FC22B1  i_log                    (field name)
0x00FC2026  SI_LOG                   (enum value)
0x00FC29C2  LOG / 0x00FC29D1 VIVID   (enum values)
```

These are inside the **BOOTSTRAP partition** (`0x000005b0 – 0x013a3cd7`), i.e. the
Ambarella RTOS image / compiled protobuf descriptors — *not* the Linux rootfs.

## 3. Session 2 findings (live camera + consumer hunt)

### 3.1 Touchscreen tests performed by the operator

| Test | Result |
| :--- | :--- |
| 360 Video, **HDR OFF** | **I-Log not available** (still gated). Our `Sphere06C` "HDR decouple" patch had **no effect** on the touchscreen. |
| 360 Video, HDR ON | I-Log available (stock behaviour). |
| Single Lens colour/filter menu | **Standard, Vivid, Flat, NC, CC** — no I-Log entry. |
| USB "Control with Android" on a PC | Not supported. |

### 3.2 The actual consumer of `camera_params.json` is Insta360 *software*, not the camera

The rule keys are **absent from every on-device binary** (Linux rootfs *and* the
firmware/RTOS partitions), in ASCII and UTF-16, compressed or not:

* `i_log_switch`, `support_attrs`, `record_resolution` → only inside `camera_params.json`.
* `depend_on` → only `camera_params.json` + `common_camera_setting_proto.json`.

They **are** present in the Insta360 Studio desktop software:

```
Insta360 Studio_stock.exe / studio_worker_stock.dll
  filter_mode, color_mode, COLOR_MODE_ILOG, COLOR_MODE_STANDARD, COLOR_MODE_DOLBY,
  "X5_I-Log_To_Rec.709_V1.0.cube", "AcePro2_I-Log_To_Rec.709_V1.0.cube" ...
```

Combined with the fact that `instaAIP` merely **stores, copies and serves** the file
(`/pref/camera_params.json` via the `/CONF` HTTP route) and hashes it for a Bluetooth
`conf_version`, the architecture is now clear:

> `camera_params.json` is a **remote UI/capability manifest for the Insta360 app/software**.
> The camera owns and serves it; it does **not** interpret the rules.

The **physical touchscreen menu is compiled into the RTOS** (the `i_log`, `SI_LOG`,
`LOG`, `VIVID` enum values live in the Ambarella RTOS protobuf descriptors in the
BOOTSTRAP partition, alongside the compiled `Webcam`/`Reverse`/`Android` USB-mode strings).

### 3.3 The I-Log pipeline data already exists for the same sensor

Part 2 ROMFS (ISP tuning) contains per-sensor log colour-correction sets:

```
VideoCc0_IMX06C_LOG … VideoCc4_IMX06C_LOG
StillCc0_IMX06C_LOG … StillCc4_IMX06C_LOG
```

`IMX06C` is the single OV50H sensor profile used by **both** 360 and Single Lens, so the
I-Log rendering data is not sphere-specific. The gate is the RTOS UI/control logic, not
missing ISP data.

### 3.4 Conclusion

* The SD/JSON approach **cannot** add I-Log to the camera's own touchscreen. There is no
  longer any plausible on-device consumer of the patched keys.
* Changing the touchscreen menu requires modifying the RTOS image (**requires flashing** —
  explicitly out of scope for this project).
* Two safe paths remain:
  1. **Insta360 app** (the actual consumer of `camera_params.json`): with the patched SD
     card the app *should* offer I-Log in Single Lens capture.
  2. **Runtime option injection** over the camera's OSC/HTTP or UCD/IPC interface
     (RAM only) if the RTOS accepts an I-Log setting in Single Lens.

## 4. Hypotheses (ranked)

| # | Hypothesis | How to confirm |
| :- | :--- | :--- |
| **H1** | `camera_params.json` is a **client/app capability manifest**; the physical touchscreen UI is RTOS-side and hardcoded/compiled, so the JSON patch can never change it. | Compare touchscreen behaviour vs app behaviour. Query `camera.getOptions` over OSC and see if it reports I-Log for single lens. |
| **H2** | The JSON **is** consumed on-camera, but by the RTOS via a precomputed/shared structure populated **before** our bind-mount (RTOS boots first). | Check whether `/pref/camera_params.json` content differs from `/usr/local/share/script/...`; inspect RTOS logs; try a late `instaAIP` restart / option re-push. |
| **H3** | I-Log is **pipeline-gated** for single lens (ISP/encoder only wires 10-bit log for sphere+HDR). Even if exposed, the option would be rejected/ignored. | `camera.setOptions` with the I-Log option in single lens and watch for errors; verify recorded file transfer characteristics. |

## 5. Instrumentation added this session

- `sdcard_payload/diag.sh` — deep diagnostic collector, safe to run manually via
  `sh /tmp/SD0/diag.sh` or automatically from `custom.sh`. Captures:
  - md5sum/inode/size of all three live `camera_params.json` paths + `.zip`s
  - `grep -c i_log_switch` against each live path
  - `/pref` + `/tmp/FL0` + `/tmp/FL1` listings
  - `ps`, `/proc/mounts`, per-daemon `/proc/<pid>/fd` and `maps` (camera_params lines)
  - `dmesg`, `logread`, `/dev/rpmsg*`
  - byte-exact copies of the live `/usr/local/share/script` and `/pref` JSONs
- `sdcard_payload/custom.sh` now invokes `diag.sh` on every boot.

## 6. Next actions

## 7. Session 3 findings (live root shell)

### 7.1 RAM-only root shell established
The SD payload now starts busybox `telnetd -l /bin/sh -p 2323` from `bootup.sh`
(`ENABLE_TELNETD=1`). Confirmed root over the camera's WPA2 AP (`uid=0`). No NAND writes;
reboot removes it. Client: `tools/cam_shell.py`.

### 7.2 The HTTP auth is IP/socket based — and can be satisfied from the PC
The proprietary endpoints (`/CONF`, `/RICONF`, `/MISC`, `/algorithm`, `/LOG`) return 401
unless the request comes from the app. Key strings:
```
[HttpServer] check: req_ip[%s] allow_osc[%d] osc_dl[%d] usb_state[0x%02X] app_socket[%d]
[HttpServer] authorized: online app ip[%s].
[HttpServer] unauthorized: osc not granted ... app_online_ip[%s] req_ip[%s]
```
**Simply opening a TCP connection to the camera's port 6666 from the PC registers the PC
as the "online app"** and makes `/CONF` return 200. (See `tools/probe_camera.ps1`.)

### 7.3 `/CONF` == `camera_params.json`; OSC only exposes standard options
* `/CONF` returned exactly 231669 bytes = our patched `camera_params.json`.
* `camera.getOptions` accepts only standard OSC names (`captureMode`, `exposureProgram`,
  `iso`, `shutterSpeed`, `whiteBalance`, `exposureCompensation`, `fileDelay`, `fileFormat`,
  `exposureDelay`). Insta360 names (`colorMode`, `iLogSwitch`, `i_log`, `i_log_switch`,
  `color_mode`, `filter_mode`) return `invalidParameterName`.
* `camera.setOptions` silently returns `state:"done"` for **any** option (no validation), so
  it cannot be used to confirm whether I-Log was applied.

### 7.4 The app controls capture over **Bluetooth**, not HTTP/OSC
* Listening TCP ports: `80` (HTTP), `5555` (adbd), `6666` (keepalive channel), `12345`
  (instaAlg debug), `11009` (camctrlserver), `53` (dnsmasq), `111` (rpcbind).
* `app_dg` = *Bluetooth Data Gateway* (SPP/BLE data), `app_manager` = BT message manager,
  `app_hogp` = BLE GATT. None contain any colour/I-Log string.
* The settings path is therefore: **App → BLE/SPP (`app_dg`) → instaAIP (`ins_proto_dispatcher`,
  ~193 handlers for `0x6xxx` UCD message codes) → RPMsg `/dev/rpmsg_insta360_scull` → RTOS**.
* The RTOS owns the option availability (the `i_log`/`SI_LOG`/`LOG` enums live in the
  BOOTSTRAP/RTOS image, not in any file).

### 7.5 RTOS factory mode exists but is not a colour switch
RTOS strings `set factory mode %d`, `Push] factory_mode %d invalid`, and Linux
`/dev/rpmsg_insta360_scull_factory` / `InsApp_Status_FactoryMode_Set` show a manufacturing
factory mode (IMU cal, ageing, uploads). It is not a documented way to unlock I-Log.

### 7.6 Conclusion (updated)
1. I-Log in Single Lens is **RTOS-firmware-gated**. No file/SD/JSON/config change can alter
   it. Changing it requires modifying the RTOS image (**flashing — out of scope**).
2. The **only** non-flash route is to inject the app's own UCD message (`0x6xxx`) that sets the
   photography/colour option, via BLE or by writing the RPMsg channel. That is a substantial
   RE task (framing + protobuf `PhotographyOptionType`) and the RTOS may still reject I-Log in
   Single Lens.
3. The I-Log ISP data for the sensor (`VideoCc*_IMX06C_LOG`) is present, so the pipeline is
   capable; the block is purely control logic.

### 7.7 Available safe levers right now
* RAM-only root shell over Wi-Fi (`tools/cam_shell.py`).
* Authorized HTTP access from the PC by holding port 6666 (`tools/probe_camera.ps1`).

### 7.8 CORRECTION: `amba_camctrl` does NOT work on this firmware
The earlier docs (Option C) proposed `amba_camctrl enc set_bitrate` / `img set_*` for runtime
tuning. **Tested on hardware and it fails:**
```
$ /usr/bin/amba_camctrl enc set_bitrate 200000000
can not find svc for program 268435712! Client needs to bind again next time!
ambaipc_clnt_call Can not find svc for program id 268435712.
exit=255
```
`268435712 = 0x10000100` is the Ambarella camctrl RTOS service. The string `camctrl` exists
only in the Linux rootfs — **not in the RTOS image** — so this product's RTOS never registers
it. Insta360 replaced it with their own RPMsg/UCD protocol. Therefore the runtime
encoder/ISP knob path is **not available**; bitrate, HDR, colour and NR are all RTOS-owned.

### 7.9 Which tweaks are actually viable (three tiers)
| Tier | Owner | Examples | Non-flash viable? |
| :--- | :--- | :--- | :--- |
| **A** | Linux daemons/scripts | Wi-Fi region/channel/Tx power, adb/serial, network, file/SD features, boot harness | **Yes** — RAM-only, already working |
| **B** | App value-lists from `camera_params.json` | bitrate tiers / value pickers (if the app uses our patched values and refreshes) | **Maybe** — needs a cache/conf_version test |
| **C** | RTOS firmware | I-Log availability, HDR gating, colour profiles, resolution/mode menus, NR/ISP tuning | **No** — needs UCD injection or flashing |

### 7.10 Flashing risk / recovery
The firmware partitions are signed/encrypted (RSA-signed thermal XMLs, `cmdctr.cipher.sh`).
Insta360's recovery path is normally "official firmware on SD + button combo at power-on",
which works **only if the bootloader/recovery chain is intact**. Corrupting the
BOOTSTRAP/bootloader or failing a secure-boot check can leave the device needing vendor/JTAG
recovery. Flashing is therefore not recommended for this project.



1. `adb devices` → `adb shell`.
2. `md5sum` all live JSON paths; confirm the patched MD5 is what the daemon sees.
3. `ls -l /proc/$(pidof instaAIP)/fd` and `/maps` for `camera_params` — did it ever open it?
4. Query the running daemon's understanding of available options for single lens
   (`camera.getOptions` over OSC / app protocol).
5. Attempt `camera.setOptions` to set the I-Log option in single lens; observe
   success/error and then test-record.
6. Inspect RTOS-side logs / `SendToRTOS` for option rejection messages.
