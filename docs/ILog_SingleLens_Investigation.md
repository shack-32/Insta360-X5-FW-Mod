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

## 3. Hypotheses (ranked)

| # | Hypothesis | How to confirm |
| :- | :--- | :--- |
| **H1** | `camera_params.json` is a **client/app capability manifest**; the physical touchscreen UI is RTOS-side and hardcoded/compiled, so the JSON patch can never change it. | Compare touchscreen behaviour vs app behaviour. Query `camera.getOptions` over OSC and see if it reports I-Log for single lens. |
| **H2** | The JSON **is** consumed on-camera, but by the RTOS via a precomputed/shared structure populated **before** our bind-mount (RTOS boots first). | Check whether `/pref/camera_params.json` content differs from `/usr/local/share/script/...`; inspect RTOS logs; try a late `instaAIP` restart / option re-push. |
| **H3** | I-Log is **pipeline-gated** for single lens (ISP/encoder only wires 10-bit log for sphere+HDR). Even if exposed, the option would be rejected/ignored. | `camera.setOptions` with the I-Log option in single lens and watch for errors; verify recorded file transfer characteristics. |

## 4. Instrumentation added this session

- `sdcard_payload/diag.sh` — deep diagnostic collector, safe to run manually via
  `sh /tmp/SD0/diag.sh` or automatically from `custom.sh`. Captures:
  - md5sum/inode/size of all three live `camera_params.json` paths + `.zip`s
  - `grep -c i_log_switch` against each live path
  - `/pref` + `/tmp/FL0` + `/tmp/FL1` listings
  - `ps`, `/proc/mounts`, per-daemon `/proc/<pid>/fd` and `maps` (camera_params lines)
  - `dmesg`, `logread`, `/dev/rpmsg*`
  - byte-exact copies of the live `/usr/local/share/script` and `/pref` JSONs
- `sdcard_payload/custom.sh` now invokes `diag.sh` on every boot.

## 5. Next actions (requires live camera / ADB)

1. `adb devices` → `adb shell`.
2. `md5sum` all live JSON paths; confirm the patched MD5 is what the daemon sees.
3. `ls -l /proc/$(pidof instaAIP)/fd` and `/maps` for `camera_params` — did it ever open it?
4. Query the running daemon's understanding of available options for single lens
   (`camera.getOptions` over OSC / app protocol).
5. Attempt `camera.setOptions` to set the I-Log option in single lens; observe
   success/error and then test-record.
6. Inspect RTOS-side logs / `SendToRTOS` for option rejection messages.
