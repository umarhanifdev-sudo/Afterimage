@echo off
cd /d "%~dp0"
if defined GODOT_EXE (
  "%GODOT_EXE%" --path "%~dp0"
  exit /b
)
where godot >nul 2>&1
if %errorlevel%==0 (
  godot --path "%~dp0"
  exit /b
)
echo Open project.godot with Godot 4.5.1 and press F5.
echo Or set GODOT_EXE to the full path of your Godot executable.
pause
