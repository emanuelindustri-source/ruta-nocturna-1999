# Build, CI y release

**Estado:** Fase 1.4. Define cómo se compila, prueba y publica la rebanada vertical
sin versionar binarios intermedios.

## 1. Presets de exportación

`export_presets.cfg` es la fuente de verdad de los dos artefactos de referencia:

| Preset | Plataforma | Salida | Notas |
|---|---|---|---|
| `Windows Desktop` | Windows x86_64 | `build/exports/windows/RutaNocturna1999.exe` + `.pck` | Debug con consola; sin firma comercial |
| `Android` | Android arm64-v8a | `build/exports/android/RutaNocturna1999.apk` | Debug firmada con el keystore local; sin Gradle |

Reglas:

- `include_filter` incluye `localization/*.csv`; el importador genera además los
  `.translation` por locale que usa el runtime en los exports.
- `exclude_filter` excluye `tests/*`, `tools/*`, `docs/*` y `build/*`.
- Ningún preset contiene contraseñas, rutas de keystore ni credenciales.
- `tools/validate_export.py` comprueba presets, rutas, arquitectura, paquete,
  versión y la política de no secretos. Se ejecuta en `health_check.py` y en CI.
- `project.godot` activa `textures/vram_compression/import_etc2_astc` porque el
  export Android exige compresión ETC2/ASTC.

## 2. Export local

```powershell
# Windows y Android a build/exports/
.\tools\dev\export.cmd -Target all

# Solo uno de los dos
.\tools\dev\export.cmd -Target windows
.\tools\dev\export.cmd -Target android
```

Los kits de bioma/POIs de F4.3 se generan con la fábrica Blender
(`tools/blender/build_assets.py --target world.<familia>`) y sus GLB viajan en el
export como recursos normales; los manifiestos se validan con
`tools/validate_assets.py`.

El script importa el proyecto en headless antes de exportar, escribe el log en
`build/logs/export/` y genera `build/logs/export/latest.json` con rutas, tamaños y
SHA-256. Un artefacto menor de 1 MB se considera fallo.

## 3. Prueba Android/ADB

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\test_android_adb.ps1
```

Pasos obligatorios, alineados con `QA_AND_RECOVERY.md`:

1. Verifica que hay un dispositivo ADB autorizado (o usa `-Serial`).
2. Compila la APK debug (o usa `-SkipBuild`).
3. Instala con `adb install -r`.
4. Abre la app con `monkey` y espera el marcador de sesión local
   (`files/sesion_activa.json`) o `BOOT_READY` hasta 90 s.
5. Monitoriza `logcat` 15 s y busca `FATAL EXCEPTION`, `E/AndroidRuntime` y errores
   de Godot/Vulkan.
6. Captura la pantalla con `screencap`.
7. Recoge el PSS con `dumpsys meminfo` y lo compara con 1,2 GB.
8. **Ruta de rendimiento (F3.5/F4.2):** fuerza el cierre, escribe
   `files/perf_route.marker` con `run-as` (contenido `slice,cabin,world`), reabre
   la app y espera `files/perf_report.json` con `done=true` (hasta 300 s). El
   servicio de escena `DevicePerfProbe` (`src/debug/device_perf_probe.gd`)
   navega a la rebanada, la cabina y el mundo, pre-simula 90 s de tormenta donde
   aplica, somete el mundo a streaming a 1.200 m/s durante la medición, mide
   frame pacing, triángulos, draw calls, tiempos de carga, warm-up y el bloque
   `world` (sectores, solicitudes máximas, carga del grafo y errores), y borra
   el marcador al terminar. Sin marcador la sonda es inerte.
9. Durante la medición captura una pantalla y un PSS por escena:
   `screenshot_slice.png`, `screenshot_cabin.png`, `screenshot_world.png` y sus
   `meminfo_*.txt`; al terminar captura `screenshot_world_final.png`.
10. Valida contra los presupuestos del propio reporte: frame medio
    ≤ 33,333 ms, triángulos ≤ 120.000, carga de escena ≤ 15 s, warm-up
    completado, PSS ≤ 1.228,8 MB en las tres escenas y, en mundo, carga del
    grafo ≤ 250 ms, ≤ 2 solicitudes, cero `load()` síncrono y cero errores de
    sector.
11. Guarda `logcat.txt`, `logcat-godot.txt`, `screenshot.png`,
     `screenshot_slice.png`, `screenshot_cabin.png`, `screenshot_world.png`,
     `screenshot_world_final.png`, `meminfo*.txt`, `perf_report.json` y
     `latest.json` en `build/logs/android-smoke/`.

La APK no se etiqueta como válida si falta el arranque, hay un error fatal o
el PSS supera el presupuesto. Los logs y capturas no se commitean.

Notas de dispositivo:

- En MIUI/HyperOS hay que conceder "Instalar vía USB" para el paquete; de lo
  contrario `adb install` devuelve `INSTALL_FAILED_USER_RESTRICTED`.
- El script hace `pm clear` antes de abrir para que el marcador de sesión y el
  reporte de cierre anormal no contaminen la prueba.
- Godot no publica `print()` en `logcat` en esta build; por eso el arranque se
  confirma con el marcador de sesión local y el proceso vivo, además de la captura.

## 4. Integración continua

`.github/workflows/ci.yml` tiene dos trabajos:

- **contracts:** instala Python, valida los ocho contratos, la localización, los
  presets de export, la sincronización del roadmap y rechaza binarios/secretos
  versionados.
- **godot:** descarga Godot 4.7.2 stable para Linux, importa el proyecto en
  headless, ejecuta el smoke test, el tren motriz, la lluvia, las rutas y el
  streaming de sectores, y falla si aparecen `SCRIPT ERROR`, `Parse Error` o
  `Failed to load`.

La CI no publica binarios. Los artefactos de release se generan localmente y, si se
decide publicarlos, van a GitHub Releases, nunca al repositorio.

## 5. Pages

`.github/workflows/pages.yml` publica `docs/` cuando cambian la web, el roadmap o
el propio workflow. `docs/roadmap-data.json` se genera con
`tools/release/sync_roadmap.py` y debe coincidir con `ROADMAP.md`.

## 6. Seguridad y licencias

- Sin keystores, tokens, `.apk`, `.aab`, `.exe` ni `.pck` en Git.
- `.gitignore` cubre `build/`, `dist/` y los formatos de paquete.
- `health_check.py` comprueba binarios prohibidos y archivos sensibles en el índice.
- La build Android de referencia usa el keystore de depuración local; una build de
  tienda requerirá firma y credenciales fuera del repositorio.
