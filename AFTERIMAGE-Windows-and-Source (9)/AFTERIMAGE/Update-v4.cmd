@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Update-Local-Game.ps1"
set "update_result=%errorlevel%"
if not "%update_result%"=="0" echo Update could not finish. Read the message above before trying again.
pause
exit /b %update_result%
