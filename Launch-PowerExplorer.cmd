@echo off
setlocal
powershell.exe -NoLogo -NoProfile -STA -File "%~dp0PowerExplorer.ps1"
if errorlevel 1 (
    echo.
    echo Power Explorer exited with an error. See messages above.
    pause
)
