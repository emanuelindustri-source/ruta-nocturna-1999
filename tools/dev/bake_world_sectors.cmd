@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0bake_world_sectors.ps1" %*
exit /b %ERRORLEVEL%
