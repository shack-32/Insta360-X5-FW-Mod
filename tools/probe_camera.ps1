# =============================================================================
# Insta360 X5 local OSC/HTTP probe
# Run this WHILE the PC is connected to the camera's Wi-Fi AP.
# It only issues read-only requests and saves all responses to .\camera_probe\
# Safe: no files are written to the camera.
# =============================================================================
$ErrorActionPreference = "Continue"
$out  = Join-Path $PSScriptRoot "camera_probe"
New-Item -ItemType Directory -Force -Path $out | Out-Null

# --- auto-detect the camera address -----------------------------------------
# Preferred: the Insta360 AP address. Fallback: the default gateway while
# connected to the camera AP (which is the camera itself).
$candidates = @("192.168.42.1")
try {
    $gw = (Get-NetRoute -DestinationPrefix "0.0.0.0/0" |
           Sort-Object RouteMetric | Select-Object -First 1).NextHop
    if ($gw -and $candidates -notcontains $gw) { $candidates += $gw }
} catch {}

$base = $null
foreach ($ip in $candidates) {
    try {
        Invoke-WebRequest -Uri "http://$ip/osc/info" -UseBasicParsing -TimeoutSec 5 | Out-Null
        $base = "http://$ip"
        break
    } catch {
        if ($_.Exception.Response) { $base = "http://$ip"; break }   # reachable, non-200
    }
}
if (-not $base) { $base = "http://192.168.42.1" }
Write-Host "Using camera base URL: $base"

$UA = "Insta360 App"   # osc_handler records the User-Agent; keep it app-like

function Probe {
    param(
        [string]$Name,
        [string]$Method,
        [string]$Path,
        [string]$Body = $null,
        [string]$ContentType = "application/json"
    )
    $file = Join-Path $out ($Name + ".txt")
    try {
        $headers = @{ "User-Agent" = $UA }
        if ($Body -ne $null) {
            $r = Invoke-WebRequest -Uri ($base + $Path) -Method $Method `
                 -Headers $headers -Body $Body -ContentType $ContentType `
                 -UseBasicParsing -TimeoutSec 12
        } else {
            $r = Invoke-WebRequest -Uri ($base + $Path) -Method $Method `
                 -Headers $headers -UseBasicParsing -TimeoutSec 12
        }
        "URL: $Method $base$Path" | Out-File $file -Encoding utf8
        "STATUS: $([int]$r.StatusCode) $($r.StatusDescription)" | Out-File $file -Append -Encoding utf8
        "---- BODY ----" | Out-File $file -Append -Encoding utf8
        $r.Content | Out-File $file -Append -Encoding utf8
        Write-Host "[OK]   $Name  ($([int]$r.StatusCode))"
    } catch {
        "URL: $Method $base$Path" | Out-File $file -Encoding utf8
        "ERROR: $($_.Exception.Message)" | Out-File $file -Append -Encoding utf8
        Write-Host "[FAIL] $Name  $($_.Exception.Message)"
    }
}

Write-Host "Probing $base ..."
Probe "00_osc_info"          "GET"  "/osc/info"
Probe "01_osc_state"         "POST" "/osc/state" "{}"
Probe "02_getOptions_all"    "POST" "/osc/commands/execute" '{"name":"camera.getOptions","parameters":{"optionNames":["all"]}}'
Probe "03_getOptions_known"  "POST" "/osc/commands/execute" '{"name":"camera.getOptions","parameters":{"optionNames":["captureMode","fileFormat","exposureProgram","iso","shutterSpeed","whiteBalance","colorMode","color_mode","iLogSwitch","i_log_switch","i_log"]}}'
Probe "04_root"              "GET"  "/"
Probe "05_CONF"              "GET"  "/CONF"
Probe "06_CONF_params"       "GET"  "/CONF?path=/pref/camera_params.json"
Probe "07_MISC"              "GET"  "/MISC"
Probe "08_LOG"               "GET"  "/LOG"

# Summary of what came back
Write-Host ""
Write-Host "Results written to: $out"
Get-ChildItem $out | Select-Object Name,Length | Format-Table -AutoSize
