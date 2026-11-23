@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0interaction_test.ps1" %*
exit /b %ERRORLEVEL%
