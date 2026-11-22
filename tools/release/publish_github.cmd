@echo off
setlocal
chcp 65001 >nul
set PYTHONIOENCODING=utf-8
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0publish_github.ps1" %*
exit /b %ERRORLEVEL%
