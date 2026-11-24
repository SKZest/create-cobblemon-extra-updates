# Actualizaciones de Create & Cobblemon Extra

Este proyecto prepara parches para el portátil de Minecraft 1.21.1 NeoForge.
El ZIP completo de juego se entrega por separado. GitHub Releases publica solo
el manifiesto y los parches cuya distribución esté permitida.

## Estado inicial

- Repositorio previsto: `SKZest/create-cobblemon-extra-updates`, público.
- `v1`: base del ZIP portátil `AUTOUPDATE_2026-11-23`.
- `v2`: parche de prueba que añade un archivo informativo y comprueba la
  descarga automática. No modifica partidas ni mods.
- Dirección estable que consulta el lanzador:
  `https://github.com/SKZest/create-cobblemon-extra-updates/releases/latest/download/updates.json`
- Los amigos con copias anteriores reciben una instalación única que añade el
  actualizador y las correcciones visuales.

## Publicar una actualización

1. Preparar y comprobar los cambios en el cliente y, si cambian mods comunes,
   actualizar y reiniciar primero el servidor.
2. Crear el parche con `PREPARAR_PARCHE.ps1`, indicando archivos concretos y
   los nombres de los mods viejos que deben eliminarse. La carpeta fuente debe
   contener exactamente los archivos que se distribuirán.
3. Probar el parche en una copia del portátil y comprobar que el juego abre.
4. Crear una versión estable de GitHub con etiqueta `v3`, `v4`, etc. y adjuntar
   el parche y `updates.json` generados. Cada nueva versión adjunta un
   `updates.json` con la lista acumulada de parches.
5. Los amigos recibirán la actualización al abrir el `.bat`.

Ejemplo de creación de `v3`:

```powershell
& .\PREPARAR_PARCHE.ps1 `
  -PortableRoot 'C:\ruta\Create_Cobblemon_Extra_Portatil' `
  -From 2 -To 3 `
  -Files @('.minecraft/global_packs/required_resources/traduccion_es_es/pack.mcmeta') `
  -PreviousManifest '.\salida\v2\updates.json' `
  -OutputDirectory '.\salida-v3'
```

Para versiones posteriores, usar el `updates.json` de la versión anterior
como `PreviousManifest`.

## Archivos protegidos

El actualizador acepta únicamente mods, ajustes seleccionados, paquetes de
recursos y datos. Nunca reemplaza `options.txt`, mundos, mapas, capturas,
`MEMORIA_GB.txt`, el nombre de jugador, Java ni archivos del sistema. Conserva
una copia de cada archivo reemplazado en `actualizaciones/respaldo-*`.

Si no hay internet, el lanzador abre la versión ya instalada. Si una descarga
falla la comprobación o un parche no se puede instalar, detiene el arranque
para evitar una mezcla de versiones.

