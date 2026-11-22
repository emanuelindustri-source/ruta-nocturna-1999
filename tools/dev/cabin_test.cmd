@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0cabin_test.ps1" %*
exit /b %ERRORLEVEL%
