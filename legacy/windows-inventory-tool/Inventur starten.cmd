@echo off
setlocal
cd /d "%~dp0"
pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Get-WindowsInventory.ps1" -OpenReport
if errorlevel 1 (
    echo.
    echo Die Inventur wurde mit einem Fehler beendet.
    pause
)
endlocal
