@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0rain_test.ps1" %*
exit /b %ERRORLEVEL%
