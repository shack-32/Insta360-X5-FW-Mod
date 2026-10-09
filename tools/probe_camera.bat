@echo off
REM ============================================================================
REM Runs the Insta360 X5 local OSC/HTTP probe.
REM Connect the PC to the camera's Wi-Fi AP first, then double-click this file.
REM ============================================================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0probe_camera.ps1"
echo.
pause
