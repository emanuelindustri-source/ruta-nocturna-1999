@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0powertrain_test.ps1" %*
exit /b %ERRORLEVEL%
