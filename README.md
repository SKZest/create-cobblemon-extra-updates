# Actualizaciones de Create & Cobblemon Extra

Este proyecto prepara parches para el portátil de Minecraft 1.21.1 NeoForge.
El ZIP completo de juego se entrega por separado. GitHub Releases publica solo
el manifiesto y los parches cuya distribución esté permitida.

## Estado inicial

- Repositorio previsto: `SKZest/create-cobblemon-extra-updates`, público.
- Primera versión: `v1`, con `updates.json` y sin parche. El ZIP portátil
  `AUTOUPDATE_2026-11-23` ya representa esa versión.
- Dirección estable que consulta el lanzador:
  `https://github.com/SKZest/create-cobblemon-extra-updates/releases/latest/download/updates.json`
- Los amigos con copias anteriores reciben una instalación única del
  actualizador y deben partir de la corrección visual más reciente.

## Publicar una actualización

1. Preparar y comprobar los cambios en el cliente y, si cambian mods comunes,
   actualizar y reiniciar primero el servidor.
2. Crear el parche con `PREPARAR_PARCHE.ps1`, indicando archivos concretos y
   los nombres de los mods viejos que deben eliminarse. La carpeta fuente debe
   contener exactamente los archivos que se distribuirán.
3. Probar el parche en una copia del portátil y comprobar que el juego abre.
4. Crear una versión estable de GitHub con etiqueta `v2`, `v3`, etc. y adjuntar
   `patch-1-2.zip` y `updates.json` generados. Cada nueva versión adjunta un
   `updates.json` con la lista acumulada de parches.
5. Los amigos recibirán la actualización al abrir el `.bat`.

Ejemplo de creación de `v2`:

```powershell
& .\PREPARAR_PARCHE.ps1 `
  -PortableRoot 'C:\ruta\Create_Cobblemon_Extra_Portatil' `
  -From 1 -To 2 `
  -Files @('.minecraft/global_packs/required_resources/traduccion_es_es/pack.mcmeta') `
  -PreviousManifest '.\updates-inicial.json' `
  -OutputDirectory '.\salida-v2'
```

Para `v3`, usar el `updates.json` de `v2` como `PreviousManifest`.

## Archivos protegidos

El actualizador acepta únicamente mods, ajustes seleccionados, paquetes de
recursos y datos. Nunca reemplaza `options.txt`, mundos, mapas, capturas,
`MEMORIA_GB.txt`, el nombre de jugador, Java ni archivos del sistema. Conserva
una copia de cada archivo reemplazado en `actualizaciones/respaldo-*`.

Si no hay internet, el lanzador abre la versión ya instalada. Si una descarga
falla la comprobación o un parche no se puede instalar, detiene el arranque
para evitar una mezcla de versiones.

