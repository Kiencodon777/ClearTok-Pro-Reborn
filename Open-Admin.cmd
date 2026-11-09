@echo off
cd /d "%~dp0"
python scripts/start_admin.py
if errorlevel 1 pause
