@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0weather_regions_test.ps1" %*
exit /b %ERRORLEVEL%
