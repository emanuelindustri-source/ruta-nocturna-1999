@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0world_routes_test.ps1" %*
exit /b %ERRORLEVEL%
