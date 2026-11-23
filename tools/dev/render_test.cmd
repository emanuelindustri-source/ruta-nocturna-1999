@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0render_test.ps1" %*
exit /b %ERRORLEVEL%
