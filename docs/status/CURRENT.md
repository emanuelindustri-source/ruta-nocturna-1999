# Estado actual

**Subfase:** 4.2 — Terreno, sectores de 800 m, colisión y streaming asíncrono
**Versión:** `v0.4.1`
**Modelo de la subfase:** DS-R (`opencode-go/deepseek-v4.1-flash#max`)
**Fecha:** 2026-11-24
**Estado:** completada; commit y tag `v0.4.1` en este cierre.

## Enlaces

- Web: https://emanuelindustri-source.github.io/ruta-nocturna-1999/
- Repositorio: https://github.com/emanuelindustri-source/ruta-nocturna-1999
- Acciones: https://github.com/emanuelindustri-source/ruta-nocturna-1999/actions

## Validación ejecutada

| Prueba | Resultado |
|---|---|
| Contratos JSON + Schemas | **10 contratos válidos**, 0 errores, 1 advertencia conocida (202 claves → F8.4); nuevo `world_streaming` v1 y sus 454 sectores validados |
| Sectores de 800 m | **454 recursos**, 4.671.964 bytes, 929.792 triángulos de terreno, 30.644 de vía; cobertura completa de las seis rutas; SHA-256 contra manifiesto |
| Low/high de altura de sector | **−15,8 / 201,7 m** en espacio de juego; DEM de referencia, no topográfica |
| Localización | 11 idiomas, 0 errores; 7 claves nuevas del mundo; `BOOT_KICKER` F4.2; `SLICE_TITLE` v0.4.1; fuentes CJK pendientes de F8.4 |
| Assets generados | 4 manifiestos válidos, 0 errores; F4.2 no genera ni modifica assets 3D |
| Roadmap | `ROADMAP.md` + `docs/roadmap-data.json` sincronizados (**15/45 completadas, 33,3 %**) |
| Smoke test | **270/270**, exit 0 (versión 0.4.1) |
| Tren motriz | **125/125**, exit 0 |
| Cabina y rig | **46/46**, exit 0 |
| Interacción contextual | **257/257**, exit 0 |
| Prueba de lluvia | **206/206**, exit 0 |
| Red de rutas (Godot) | **143/143**, exit 0 |
| Terreno y streaming (Godot) | **99/99**, exit 0 (`tools/dev/world_streaming_test.cmd`) |
| Godot import headless | exit 0; sin `SCRIPT ERROR`/`Parse Error`/`Failed to load` |
| Presets de export | Windows y Android válidos; `0.4.1`, Android `version/code=113`; `data/content/world/sectors/*.res`, `licenses/*.txt` y `CREDITS.md` incluidos |
| Prueba de render real (ventana, Vulkan Forward+) | **RENDER_OK**; frame 16,66–16,67 ms, 0 jank; draw calls añadidos ≤2,40; overdraw ≤1,0; fill visual 0,02 %/2,51 %; capturas `build/logs/render/f35_*` |
| Build Windows exportada | `build/exports/windows/RutaNocturna1999.exe`, **103.070.208 bytes**, SHA-256 `E3AB317…8F7E9`; PCK 7.684.676 bytes; ejecutada sin errores |
| APK Android | **33.018.668 bytes**, SHA-256 `10871F1…C57CC`; `versionName=0.4.1`, `versionCode=113` |
| Prueba ADB completa en el Redmi | **exit 0**: install Success, arranque **0,9 s**, logcat 15 s sin `FATAL EXCEPTION` ni errores Godot/Vulkan, ruta de rendimiento `done=true` |
| Presupuestos en dispositivo | PSS **404,4 / 509,6 / 646,0 / 630,5 MB** (boot/rebanada/cabina/mundo) ≤ 1.228,8; mundo **18.802 primitivas** ≤ 120.000; frame **8,52 / 9,50 / 24,5 ms** (medio/p95/máx), 0 jank > 33 ms |
| Streaming en dispositivo | **7 sectores** y **24.147 triángulos** de streaming; grafo **76 ms** ≤ 250; **2** solicitudes máximas; **0** `load()` síncrono; **0** errores de sector |
| Carga en dispositivo | Mundo **2.771 ms** ≤ 20.000; rebanada **9.151 ms**; cabina **4.541 ms** (presupuesto QA 15.000 ms); warm-up **2.029 / 1.937 ms** antes del gameplay |
| Prueba de juego en PC (build exportado) | Boot 11/11 + ODbL; mundo con 6–8 sectores; `Siguiente ruta`; `Esc` vuelve al Boot; faro, vía, marcas y colisión; capturas `f42_pc_*`. Informe: `build/logs/gameplay/REPORT_F42.md` |
| Rendimiento PC | Mundo **515 ms** de carga; frame **16,66 ms** medio (60 FPS), p95 17,15, máx 20,01; **15.952 primitivas**; **8 sectores** y 24.682 triángulos; grafo **44 ms**; construcción media **3,76 ms**; 2 solicitudes, 0 síncronas |
| Prueba manual en Android | Boot → **Ver mundo** con toque real OK; captura `f42_android_world_touch2.png`. Informe: `build/logs/android-smoke/REPORT_F42.md` |
| Espacio libre | **77,4 GB** en `C:` (mínimo 20 GB) |
| Dispositivo ADB | Redmi 22101316G autorizado (`obojropz89mbwgpn`) |
| Git | Rama `main`, tag `v0.4.1` y push de este cierre; CI de la rama en verde |

Advertencias conocidas:

- **H1 (→ F4.4):** las gotas de cámara (`camera_drops`) cubren la pantalla
  completa y parecen caer **dentro** del habitáculo; visible en PC y Android.
  Recortar la máscara al parabrisas; toca el shader de F3.4 y **no se modifica
  en F4.2**.
- **H2 (→ F5.1/F9.1):** la palanca **no responde con ratón, teclado ni gamepad
  en PC** (`drag_focused()` solo escucha `InputEventScreenDrag`). En Android el
  **arrastre táctil sí funciona** (verificado P → L1 en F4.1). Falta decidir la
  ruta de input de PC antes de la conducción.
- **H3 (→ F9.1):** el radio ejecuta la presión pero no muestra feedback visual
  (sin clave de feedback ni LED observable en cabina).
- **H4 (→ F9.1/F10.2):** el juego corre en **retrato** en el Redmi y la vista
  1280×720 queda con bandas negras arriba/abajo. Es una configuración
  preexistente (`window/handheld/orientation=1`), no un fallo de F4.2; el toque
  y los presupuestos funcionan. Se revisará la orientación/letterbox en menús y
  QA de dispositivo.
- La red de rutas se comprime a 1:20 y se muestrea cada **500 m**; las
  horquillas locales, el viario urbano y los cruces a distinto nivel quedan para
  F4.3. Dos vías cercanas pueden dibujarse como cintas solapadas.
- La DEM Terrarium z10 (~150 m/píxel) no resuelve puentes/túneles; se aplica
  limpieza de picos y suavizado. No es un DEM de precisión ni sirve para
  navegación. El terreno es greybox: biomas, POIs, agua y clima son F4.3/F4.4.
- Cuatro sectores de borde solo contienen terreno (sin centro de vía); no son un
  error de cobertura y están declarados en el manifiesto.
- La construcción de sector mide 3,76 ms en PC y 10,45 ms en Android; se hace
  una por frame y el frame medio del mundo queda en 8,52 ms. No hay picos >33 ms
  en la ruta medida.
- La lluvia real, la humedad conectada y el clima son F4.4; la conducción,
  pérdida de agarre, vadeo y anti-atasco completo son F5.1.
- Los 202 claves de contenido y las fuentes CJK/cirílicas siguen pendientes de
  F8.4.
- La biblioteca externa cambió con 3 vídeos nuevos del Esteem; la próxima
  revisión visual completa sigue siendo obligatoria antes de F4.3 o el
  2026-12-06.
- Las builds exportadas son debug de referencia, no versionadas, en
  `build/exports/`.

## Completado

- **Contrato `world.streaming` v1** (`data/schemas/world_streaming.json`) y JSON
  Schema: terreno de 800 m, rejilla 33×33, vía de 7,2 m, relieve, materiales,
  streaming por secuencia, máximo 2 solicitudes, prohibición de `load()` síncrono,
  colisión `StaticBody3D` + `ConcavePolygonShape3D`, reaparición segura,
  presupuestos, ODbL y QA.
- **Horneado reproducible** `tools/world/bake_world_sectors.gd` + wrapper:
  454 sectores `WorldSectorData` en `data/content/world/sectors/*.res` y
  `sectors.manifest.json`; vía mitrada, marcas discontinuas, colisión de vía y
  terreno a paso 2, atribución ODbL.
- **Runtime**: `src/world/world_sector_data.gd`,
  `world_sector_builder.gd`, `sector_streamer.gd` y `world_director.gd`
  (servicio de escena, no autoload). Carga threaded con cola priorizada,
  autolimpieza, timeout de ventana inicial, una construcción por frame y descarga
  por margen.
- **`scenes/world/WorldTerrain.tscn`**: cielo procedural, ambiente de color,
  luna, faro, coche de presentación, cámara de persecución, overlay y tour por
  las seis rutas; controles `N/R/Espacio/RePág/AvPág/Esc` y botones de 48 px.
- **`tests/world/WorldStreamingTest.tscn`** y
  `tools/dev/world_streaming_test.cmd`: **99 comprobaciones** de contrato,
  manifiesto, recursos, alturas, colisión, raycast, reaparición, ventana inicial,
  avance de 12 km, cambio de ruta y las seis rutas al 10/50/90 %.
- **Validación compartida** `tools/world/validate_world_sectors.py` integrada en
  `validate_schemas.py` (10 contratos) y `health_check.py`; CI ejecuta la prueba
  de streaming.
- **Localización**: 7 claves nuevas en once idiomas; `BOOT_KICKER` F4.2;
  `SLICE_TITLE` v0.4.1; `CREDITS_OSM` visible en el mundo.
- **Atribución ODbL**: los sectores son base derivada de OSM; se conservan
  `licenses/ODbL-1.0.txt`, `CREDITS.md`, la clave `CREDITS_OSM`, la web y el
  share-alike. No se usa el addon Terrain3D (decisión y licencia MIT en
  `WORLD_STREAMING.md`).
- Versión `0.4.1` en `VERSION`, `project.godot`, `export_presets.cfg`
  (`version/code=113`), `EXPECTED_VERSION` del smoke/lluvia/rutas/streaming,
  `PHASE` de Boot y `BOOT_KICKER` en once idiomas.
- **Documentación**: `docs/architecture/WORLD_STREAMING.md` y secciones nuevas
  en `SYSTEM_ARCHITECTURE.md`, `DATA_CONTRACTS.md`, `WORLD_ROUTES.md`,
  `BUILD_AND_RELEASE.md`, `CREDITS.md` y `README.md`.

## Siguiente

Fase **4.3 con MiMo Pro**: kits de biomas, gasolineras, moteles, peajes,
señalización, agua, polvo y nieve (tag `v0.4.2`). No se inicia en este chat. El
prompt completo está en `docs/status/HANDOFF.md`.
