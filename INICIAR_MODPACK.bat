@echo off
cd /d "%~dp0"
title Create y Cobblemon Extra - Minecraft 1.21.1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0ACTUALIZAR_MODPACK.ps1"
if errorlevel 1 (
  echo.
  echo La actualizacion no termino. El juego no se iniciara para evitar archivos mezclados.
  pause
  exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0INICIAR_MODPACK.ps1"
echo.
echo El juego se cerro.
pause

