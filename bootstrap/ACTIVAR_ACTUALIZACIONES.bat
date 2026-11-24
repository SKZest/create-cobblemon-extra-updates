@echo off
cd /d "%~dp0"
if not exist "INICIAR_MODPACK.ps1" (
  echo Extrae esta actualizacion dentro de la carpeta portatil del modpack.
  pause
  exit /b 1
)
if not exist ".minecraft\mods\Cobblemon-neoforge-1.8.4+1.21.1.jar" (
  echo Esta actualizacion requiere Cobblemon 1.8.4 para Minecraft 1.21.1.
  pause
  exit /b 1
)
if not exist ".minecraft\mods\cobblemon-journey-mounts-1.7.2.jar" (
  echo Esta actualizacion requiere Journey Mounts 1.7.2.
  pause
  exit /b 1
)
robocopy "archivos\.minecraft" ".minecraft" /E /R:1 /W:1 /NFL /NDL /NJH /NJS
if errorlevel 8 goto :error
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0CORREGIR_FICHA.ps1" "%~dp0.minecraft"
if errorlevel 1 goto :error
copy /Y "archivos\INICIAR_MODPACK.bat" "INICIAR_MODPACK.bat" >nul
if errorlevel 1 goto :error
copy /Y "archivos\ACTUALIZAR_MODPACK.ps1" "ACTUALIZAR_MODPACK.ps1" >nul
if errorlevel 1 goto :error
copy /Y "archivos\actualizaciones.config.json" "actualizaciones.config.json" >nul
if errorlevel 1 goto :error
if not exist "actualizaciones.estado.json" (
  copy /Y "archivos\actualizaciones.estado.json" "actualizaciones.estado.json" >nul
  if errorlevel 1 goto :error
)
echo Correcciones visuales y actualizaciones automaticas instaladas.
echo Usa INICIAR_MODPACK.bat para jugar. Al abrirlo descargara la version mas reciente.
pause
exit /b 0
:error
echo No se pudieron instalar todos los archivos. Revisa los permisos de la carpeta.
pause
exit /b 1

