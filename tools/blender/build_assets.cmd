@echo off
rem Fabrica de assets Blender headless (Ruta Nocturna: 1999).
rem Uso: tools\blender\build_assets.cmd [--target asset_id] [--blender ruta]
"%~dp0..\..\.venv\Scripts\python.exe" "%~dp0build_assets.py" %*
exit /b %ERRORLEVEL%
