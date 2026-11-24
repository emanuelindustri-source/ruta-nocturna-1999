# Changelog

Todas las fechas usan ISO 8601. Las versiones siguen SemVer.

## [Unreleased]

## [0.4.1] — 2026-11-24

### Añadido

- Contrato **`data/schemas/world_streaming.json`** (`world.streaming` v1) y JSON
  Schema: terreno de 800 m, rejilla 33×33, vía, relieve, materiales, streaming
  asíncrono, colisión, presupuestos, ODbL y anti-softlock. No modifica
  `world_routes` v1.
- **454 sectores** `WorldSectorData` horneados en
  `data/content/world/sectors/*.res` (4.671.964 bytes) y manifiesto con SHA-256,
  tamaño, triángulos y cobertura. 929.792 triángulos de terreno y 30.644 de vía.
- **`tools/world/bake_world_sectors.gd`** + escena y wrapper
  `tools/dev/bake_world_sectors.cmd`: horneado reproducible con vía mitrada,
  marcas discontinuas, colisión y atribución ODbL.
- **Runtime**: `WorldSectorData`, `WorldSectorBuilder`, `WorldSectorStreamer` y
  `WorldDirector` (servicio de escena, no autoload). Carga con
  `ResourceLoader.load_threaded_request()`, máximo 2 solicitudes, una
  construcción por frame, sin `load()` síncrono, descarga por ventana y
  reaparición segura sobre la red con colisión.
- **`scenes/world/WorldTerrain.tscn`**: terreno, vía, coche de presentación,
  cámara de persecución, faro, overlay de sectores/triángulos/FPS/carga y tour
  por las seis rutas. No es conducción física (F5).
- **`tests/world/WorldStreamingTest.tscn`** y wrapper: **99 comprobaciones** de
  recursos, hashes, colisión, raycast, reaparición, streaming, avance de 12 km y
  las seis rutas al 10/50/90 %.
- **`tools/world/validate_world_sectors.py`** integrado en
  `validate_schemas.py` y `health_check.py`; la CI ejecuta la prueba de
  streaming.
- **Localización**: `UI_VIEW_WORLD`, `WORLD_TITLE`, `WORLD_LOADING`,
  `WORLD_ROUTE_LINE`, `WORLD_STATS`, `WORLD_NEXT_ROUTE` y `WORLD_LOAD_FAILED` en
  los once idiomas; `BOOT_KICKER` a Fase 4.2 y `SLICE_TITLE` a v0.4.1.
- **Documentación**: `docs/architecture/WORLD_STREAMING.md` y secciones nuevas
  en `SYSTEM_ARCHITECTURE.md`, `DATA_CONTRACTS.md`, `WORLD_ROUTES.md`,
  `BUILD_AND_RELEASE.md`, `CREDITS.md` y `README.md`.

### Cambiado

- Versión `0.4.1` en `VERSION`, `project.godot`, `export_presets.cfg`
  (`version/code=113`), `EXPECTED_VERSION` del smoke/lluvia/rutas/streaming,
  `PHASE` de Boot y `BOOT_KICKER` en once idiomas.
- El Boot ofrece «Ver mundo» (`UI_VIEW_WORLD`) además de la rebanada y la cabina.
- La ruta Android de rendimiento pasa a `slice,cabin,world`; la prueba captura
  PSS y pantalla de las tres escenas y valida el bloque `world`.
- `DevicePerfProbe` mide también el mundo, espera `world_ready`, lo somete a
  1.200 m/s y registra sectores, triángulos, solicitudes, carga del grafo y
  errores.

### Medido

- **PC**: mundo con 515 ms de carga, 16,66 ms de frame medio (60 FPS), 15.952
  primitivas, 8 sectores, 24.682 triángulos, grafo 44 ms, construcción media
  3,76 ms, 2 solicitudes máximas, 0 `load()` síncrono y 0 errores.
- **Redmi 22101316G**: mundo con 2.771 ms de carga, 8,52 ms de frame medio,
  9,50 ms p95, 18.802 primitivas, 7 sectores, 24.147 triángulos, grafo 76 ms,
  PSS **630,5 MB**; rebanada 509,6 MB; cabina 646,0 MB. Límite 1.228,8 MB.
- **Android**: arranque 0,9 s, PSS 404,4 MB, sin `FATAL EXCEPTION` ni errores
  Godot/Vulkan en 15 s; toque manual Boot → «Ver mundo» OK.
- `WorldStreamingTest` **99/99**; smoke **270**, tren **125**, cabina **46**,
  interacción **257**, lluvia **206**, rutas **143**, render **RENDER_OK**.

### Corregido / decisiones

- Se descartó el addon nativo **Terrain3D**: se usa `ArrayMesh` propio (MIT) para
  evitar una GDExtension nativa por plataforma y controlar el presupuesto. La
  decisión y la licencia están en `WORLD_STREAMING.md`.
- La vía se hornea con uniones mitradas y recorte por sector para eliminar los
  abanicos y solapes de las curvas cerradas.
- La colisión del terreno usa paso 2 (512 triángulos) para reducir el coste de
  construcción; la vía conserva su malla completa.
- La ventana inicial se autolimpia: la cola se rellena si faltan sectores y un
  timeout de 20 s evita quedarse en «Cargando mundo».

### Hallazgos

- **H1 (→ F4.4):** gotas de cámara en el habitáculo; sin cambios.
- **H2 (→ F5.1/F9.1):** palanca sin ratón/teclado/gamepad en PC; el táctil
  Android funciona; sin cambios.
- **H3 (→ F9.1):** radio sin feedback visual; sin cambios.
- **H4 (→ F9.1/F10.2):** el juego corre en retrato en el Redmi y la vista
  1280×720 queda con bandas negras. Es preexistente, no rompe presupuestos ni
  toque; se revisará en menús/QA de dispositivo.
- Cuatro sectores de borde solo contienen terreno (sin centro de vía); la red
  comprimida puede solapar vías cercanas sin resolver cruces a distinto nivel.
  F4.3 podrá añadir kits de puente/cruce.
- El terreno es greybox: biomas, POIs, gasolineras, clima y agua son F4.3/F4.4.

### Licencia

- Los 454 sectores son una base derivada de OpenStreetMap y se distribuyen bajo
  **ODbL 1.0**. Se conserva © OpenStreetMap contributors, `CREDITS_OSM`,
  `licenses/ODbL-1.0.txt` y el share-alike. El generador y el terreno procedural
  son MIT del proyecto; no se copió ninguna imagen de la biblioteca externa.

## [0.4.0] — 2026-11-24

### Añadido

- Contrato **`data/schemas/world_routes.json`** (`world.routes` v1) con las seis
  regiones, proyección 1:20, extracción OSM, DEM, reglas de grafo, clases de vía,
  rutas del anillo, alternativas, caché, presupuestos, atribución ODbL,
  anti-softlock y estados. JSON Schemas en
  `data/schemas/json/world_routes.schema.json` y
  `data/schemas/json/world_route_network.schema.json`.
- Pipeline **`tools/osm/build_world_routes.py`**: descarga/caché Overpass,
  grafo nacional, snap de hubs, Dijkstra, alternativas penalizadas, grafo
  comprimido, muestreo DEM por distancia, validación y escritura atómica de la
  red y su manifiesto. Modos `--refresh`, `--offline` y `--check`.
- **`data/content/world/route_network.json`** y
  **`route_network.manifest.json`**: 329 nodos, 413 aristas, 6 caminos
  principales y 12 alternativas; **4.751,7 km** principales y **16.265,7 km**
  con alternativas; elevación 2,9–3.459,6 m; artefacto de 1.108.711 bytes.
- **`src/world/route_network.gd`** (`RouteNetwork`, `RefCounted`, no autoload):
  carga y valida contrato/red/manifiesto, verifica SHA-256, A*, alternativas,
  proyección, elevación y polilíneas 3D.
- **`tests/world/WorldRoutesTest.tscn`** y `tools/dev/world_routes_test.cmd`:
  **143 comprobaciones** de contrato, hash, grafo, rutas, DEM, proyección y
  atribución.
- **Atribución ODbL**: `licenses/ODbL-1.0.txt`, aviso en `CREDITS.md`, pie de la
  web y clave localizada `CREDITS_OSM` visible en la pantalla de arranque.
- `docs/architecture/WORLD_ROUTES.md` con pipeline, tabla de rutas, caché,
  proyección, licencia, validación y handoff a F4.2.
- Validación compartida `tools/osm/route_graph_validation.py` integrada en
  `tools/validate_schemas.py` (9 contratos) y `health_check.py`; la CI ejecuta la
  prueba de rutas.

### Cambiado

- Versión `0.4.0` en `VERSION`, `project.godot`, `export_presets.cfg`
  (`version/name`, `version/code=112`), `EXPECTED_VERSION` del smoke y de la
  lluvia, `PHASE` de Boot y `BOOT_KICKER` en once idiomas.
- `Boot.tscn`/`Boot.gd` muestran la atribución ODbL de las rutas.
- `README.md`, `AGENTS.md` (contrato nuevo), `DATA_CONTRACTS.md` y
  `SYSTEM_ARCHITECTURE.md` documentan F4.1.

### Corregido

- **CI multiplataforma (`8b9b83c`):** el manifiesto hashea el contrato sobre
  bytes normalizados **LF**, no sobre el CRLF del checkout de Windows. La CI de
  `main` pasa. El tag `v0.4.0` apunta al commit de la feature (`52f2033`); no se
  movió el tag (sin force-push). El artefacto, la build y el hash del artefacto
  no cambian.

### Datos y rendimiento (F4.1)

- OSM: extracto `2026-11-24T04:23:03Z`, 17.756 ways troncales/primarias y 9.638
  secundarias; 41,7 MB de respuestas crudas en `build/cache/osm/` (no
  versionadas).
- DEM: 155 teselas Terrarium z10 (~7,5 MB), muestreo cada 500 m de recorrido.
- Grafo: 329 nodos, 413 aristas, aristas ≤ 40 km, pendiente máxima medida
  **18,9 %** (< 30 % del contrato), red conexa desde `hub_carabobo`.
- Artefacto: 1.108.711 bytes (< 1.800.000), carga runtime pendiente de medir en
  F4.2 (`budgets.runtime_load_budget_ms` = 250 ms).
- Prueba de rutas **143/143**; las suites existentes conservan sus conteos
  (smoke 270, tren motriz 125, cabina 46, interacción 257, lluvia 206, render
  `RENDER_OK`).

### Hallazgos y límites

- La geometría se comprime a 1:20 y se muestrea cada 500 m; las horquillas y el
  viario urbano quedan para F4.2/F4.3.
- La DEM z10 no resuelve puentes/túneles; se aplica limpieza de picos y
  suavizado, y no sirve para navegación.
- H1, H2 y H3 siguen con su fase asignada (F4.4, F5.1/F9.1 y F9.1) y **no se
  tocan** en F4.1. H2 se confirmó como hueco de **PC**: el arrastre táctil de la
  palanca **sí funciona en Android** (P → L1); ratón, teclado y gamepad de PC no
  la mueven (F5.1/F9.1).

### Licencias

- Red derivada de OpenStreetMap bajo **ODbL 1.0** (© OpenStreetMap
  contributors), con share-alike, texto de licencia y atribución visible.
- Elevación: Mapzen/Tilezen, SRTM/GMTED2010 (USGS) y ETOPO1 (NOAA), atribuidos
  en `CREDITS.md` y en el manifiesto.


## [0.3.4] — 2026-11-23

### Añadido

- `src/debug/device_perf_probe.gd` (`DevicePerfProbe`): servicio de escena (no
  autoload) instanciado en Boot, Rebanada y Cabina; inerte sin
  `user://perf_route.marker`. Con el marcador navega `slice,cabin`,
  pre-simula 90 s de tormenta y mide carga, warm-up, frame pacing, triángulos
  y draw calls hacia `user://perf_report.json`.
- Sonda GPU real en `tests/render/rain_fx_render_test.gd` (`[RENDER][GPU]`):
  fill visual (diff de píxeles con materiales reales), fill de fragmentos y
  capas de overdraw (sonda aditiva de 1/255 lineal calibrada con un quad de
  1 y 2 capas), coste real de frame (vsync desactivado, FX off vs on) y delta
  exacto de draw calls, con aserciones contra `budgets.pc.gpu`.
- Tiempos de carga (`[RENDER][LOAD]`) y frame pacing (`[RENDER][PACING]`) en
  la prueba de render; capturas de referencia `f35_*.png` con evidencia
  `*_visual_off/on/diff.png`.
- `tools/dev/gameplay_input.ps1` (input sintético sobre la ventana del build
  exportado) y `tools/dev/gameplay_diff.py` (comparación y recorte de
  capturas) para la sesión de prueba de juego en PC.
- `tools/asset_compression_report.py`: banderas ETC2/ASTC/S3TC, inventario de
  texturas/mallas importadas y tamaño de artefactos
  (`build/logs/compression/latest.json`).
- `tools/test_android_adb.ps1`: **ruta de rendimiento en dispositivo**
  (marcador `perf_route.marker` con `slice,cabin`, capturas y PSS por escena,
  validación contra los presupuestos del propio reporte).

### Cambiado

- Versión `0.3.4` en `VERSION`, `project.godot`, `export_presets.cfg`
  (`version/name`, `version/code=111`, `file/product_version 0.3.4.0`),
  `EXPECTED_VERSION` del smoke y de la prueba de lluvia, `PHASE` de Boot y
  `BOOT_KICKER` en once idiomas.
- Pruebas sin cambios de conteo, todas exit 0: smoke **270**, tren motriz
  **125**, cabina **46**, interacción **257**, lluvia **206** y render
  **RENDER_OK**.

### Rendimiento medido (F3.5)

- PC (Intel UHD, Vulkan Forward+, 1280x720, vsync 60 Hz): carga boot
  140,7 ms / rebanada 77,5 ms / cabina 214,5 ms; frame 16,66–16,67 ms de
  media, p95 ≤ 17,5 ms, **0 jank** en 90 frames; warm-up 135/48/113 ms antes
  del gameplay.
- Sonda GPU en PC: draw calls añadidos **2,00** (rebanada) y **2,40** (cabina,
  ruido de monitor) ≤ 8; overdraw máximo **1,0** ≤ 5; fill visual **0,02 %**
  y **2,78 %** ≤ 6 %; coste real de los FX **+1,164 ms** y **+2,328 ms**;
  fill de fragmentos 3,64 % y **91,80 %** (el quad de gotas de cabina cubre
  pantalla completa sin `discard`: ver hallazgo H1/F10.1).
- Redmi Note 12 Pro 5G (APK `553F9128…FE59ABAF`, 29.557.514 bytes): arranque
  **0,8 s**; PSS **415,6 / 535,3 / 614,7 MB** (boot/rebanada/cabina) dentro de
  1.228,8 MB; rebanada carga 8.765 ms, warm-up 1.924 ms, frame
  **12,76 ms media / 16,96 p95**, **15.874 triángulos** ≤ 120.000, 125 draw
  calls, 1 jank > 33 ms de 300 frames; cabina carga 4.525 ms, warm-up
  2.018 ms, frame **10,14 / 16,83 ms**, 7.435 triángulos, 154,7 draw calls,
  0 jank. logcat sin `FATAL EXCEPTION` ni errores Godot/Vulkan.
- Compresión: 1 textura (19 KB) y 16 mallas (762 KB) importados;
  `import_etc2_astc` activo y S3TC en el preset de Windows; APK 29,56 MB;
  ejecutable Windows 103.070.208 bytes + pck 1.516.108 bytes.
- Build de Windows exportada ejecutada 21,5 s con exit 0 y sin stderr.

### Hallazgos (registrados en CURRENT/HANDOFF)

- **H1 → F4.4:** las gotas de cámara cubren pantalla completa y parecen caer
  dentro del habitáculo; hay que recortar la máscara al parabrisas. No se toca
  el shader en F3.5.
- **H2 → F5.1/F9.1:** la palanca de cambio no responde con ratón, teclado ni
  gamepad (`drag_focused` solo recibe `InputEventScreenDrag`); falta decidir
  la ruta de input de conducción.
- **H3 → F9.1:** el radio ejecuta la presión pero no muestra feedback visual.

### Prueba de juego en PC (F3.5)

- Boot: clic en botones, Tab con anillo de foco, Enter y F12 (panel QA con
  cambio de clima real a `Tormenta · 95 % / 90 %`). Rebanada: hover del
  botón, “Atrás” y Esc de vuelta al boot. Cabina: mirada con límites, retículo
  con tres estados y prompts por control, seguro central con LED verde →
  rojo, manos al volante al mantener pulsado, y foco en luces/radio/guantera/
  antena/freno. Evidencia en `build/logs/gameplay/` (no versionada).

## [0.3.3] — 2026-11-23

### Añadido

- `shaders/rain_fx_common.gdshaderinc`: campo procedural de gotas con fusión
  visual de vecinas, estelas de escurrido, sector de barrido y ondas de
  charco. Solo aspecto: la simulación sigue siendo la de F3.3.
- `shaders/wet_paint.gdshader`, `wet_glass.gdshader` y `wet_road.gdshader`:
  pintura/plástico/cromo mojados, cristales con gotas, refracción, zona
  barrida y estela de goma, y asfalto mojado con charcos visibles. Consumen
  `SurfaceWetnessModel`, `DropletFlowModel`, `WiperKinematics` y `PuddleModel`
  por uniforms; ningún shader contiene valores de balance.
- `shaders/rain_streaks.gdshader`, `splash_ring.gdshader` y
  `camera_drops.gdshader`: estrellas de lluvia, salpicaduras de impacto y
  gotas sobre la lente desde la cabina (billboard manual Godot 4).
- `src/weather/rain_fx_controller.gd` (`RainFxController`): servicio de escena
  que ata los modelos de F3.3 a los uniforms de los shaders, anima las
  escobillas de F3.1 sobre los pivotes del contrato, coloca charcos visibles y
  expone `set_weather()` para F4.4. No es un autoload.
- `src/weather/rain_vfx.gd` (`RainVFX`): dos `GPUParticles3D` (`draw_pass_1`)
  de estrellas y salpicaduras; `src/weather/rain_fx_warmup.gd`
  (`RainFxWarmup`): compila las pipelines de los seis shaders en un
  `SubViewport` mínimo antes del gameplay (`[RAINFX] WARMUP_*`).
- `tests/render/RainFxRenderTest.tscn` + `rain_fx_render_test.gd` +
  `tools/dev/render_test.cmd`: prueba de render real (ventana Vulkan
  Forward+) con capturas `build/logs/render/f34_*.png`, medición de frame
  time, draw calls y primitivas, comprobación de warm-up y pre-simulación de
  tormenta de 90 s. `RainFxProbe.tscn`/`rain_fx_probe.gd` son la sonda de
  diagnóstico de lookdev (no forma parte del juego).
- Ampliación de `tests/weather/rain_fx_test.gd` con las comprobaciones de
  F3.4: shaders, controlador, uniforms que siguen a los modelos, pivotes de
  escobilla, charcos visibles, VFX y presupuestos GPU proyectados.

### Cambiado

- Versión `0.3.3` en `VERSION`, `project.godot`, `export_presets.cfg`
  (`version/name`, `version/code=110` y `file/product_version 0.3.3.0`),
  `EXPECTED_VERSION` del smoke y de la prueba de lluvia, `PHASE` de Boot y
  `BOOT_KICKER` en once idiomas.
- Prueba de lluvia: **206 comprobaciones** (126 de F3.3 + 80 nuevas), exit 0.
  Smoke **270**, tren motriz **125**, cabina **46**, interacción **257**;
  todas exit 0 sin cambios de conteo.
- Medición de render real (Intel UHD Graphics, Vulkan Forward+, 1280x720,
  vsync 60 Hz): boot **16,67 ms** media / 17,1 p95 y 12 draw calls; rebanada
  con tormenta activa **16,67 / 16,9 ms**, 227 draw calls y ~15.900 primitivas;
  cabina **16,67 / 17,1 ms**, 195,5 draw calls y 9.227 primitivas. Los
  materiales mojados sustituyen a los existentes (`material_override`, 0 draw
  calls nuevos); el coste añadido son 2 llamadas (VFX) en rebanada y 1
  (gotas de cámara) en cabina, dentro de `budgets.*.gpu` (PC 8/5/6 %, móvil
  4/3/10 %): peor caso proyectado 3 draw calls / 3 capas / ~6 % de fill.
- Warm-up de shaders verificado antes del gameplay en boot, rebanada y cabina
  (marcadores `[RAINFX] WARMUP_DONE` antes de `BOOT_READY` /
  `VERTICAL_SLICE_READY`; primera compilación ~3,4 s en Intel UHD y ~0,04 s
  con caché de pipelines).
- `docs/architecture/RAIN_AND_SURFACE_FX.md` (secciones 11-12),
  `SYSTEM_ARCHITECTURE.md` (13.1), `DATA_CONTRACTS.md` (18.1),
  `STATE_MACHINES.md`, `QA_AND_RECOVERY.md` (16) documentan el GLSL, los VFX,
  el warm-up y la medición.

### Notas

- El contrato `rain_surface_fx.json` sigue en `schema_version: 1` sin cambios;
  F3.4 solo consume sus valores. F2.1–F3.2 siguen intactos.
- Pitfalls de Godot 4 resueltos y documentados en los shaders: los render
  modes `billboard*` no existen (billboard manual en `vertex()` con escritura
  explícita de `POSITION`), los doc-comments `##` rompen el tokenizer del
  lenguaje de shaders, los operadores booleanos son `&&`/`||` y la malla de
  partículas se asigna por `draw_pass_1`.
- La lluvia de las escenas es lookdev (`demo_*`); F4.4 inyecta la real con
  `RainFxController.set_weather()`. Pérdida de agarre, hidroplaneo y vadeo
  siguen reservados a F5.1. La medición GPU completa en ruta y dispositivo es
  F3.5/F10.1.

## [0.3.2] — 2026-11-23

### Añadido

- `data/schemas/rain_surface_fx.json` (`schema_version: 1`, contrato
  `vehicle.esteem.rain_surface_fx`): **matemática de lluvia física** con
  humedad de superficies, flujo de gotas, limpiaparabrisas, charcos y
  presupuestos declarativos para PC y móvil.
- `data/schemas/json/rain_surface_fx.schema.json`: JSON Schema del contrato de
  lluvia; `tools/validate_schemas.py` valida ocho contratos y comprueba el área
  del parabrisas y los pivotes/longitudes de las escobillas contra
  `exterior_spec.json`, la admisión y la profundidad segura contra
  `vehicle_components.json`, la suma de gotas y el orden de los presupuestos.
- `src/weather/rain_surface_spec.gd`: cargador runtime del contrato.
- `src/weather/surface_wetness_model.gd`: película, drenaje, evaporación,
  infiltración, histéresis y estados `dry/damp/wet/soaked`.
- `src/weather/droplet_flow_model.gd`: nucleación determinista, crecimiento,
  radio crítico, desliz por gravedad/viento, evaporación, escurrido y búfer de
  instancias de 6 floats para F3.4.
- `src/weather/wiper_kinematics.gd`: dos escobillas con barrido smoothstep,
  modos off/intermitente/lento/rápido, pausas, desgaste y limpieza de sector del
  parabrisas; sin controles nuevos de cabina.
- `src/weather/puddle_model.gd`: arquetipos de corona, hundimiento, bache,
  hombro y vado; profundidad, drenaje, hidroplaneo informativo y estados de
  vadeo enlazados con `specs.water`.
- `tests/weather/RainFxTest.tscn` + `tests/weather/rain_fx_test.gd`:
  **126 comprobaciones** headless de contrato, humedad, determinismo de gotas,
  barrido, desgaste, charcos, hidroplaneo, vadeo y presupuesto CPU.
- `tools/dev/rain_test.cmd` y `tools/dev/rain_test.ps1`: prueba de lluvia con
  log en `build/logs/rain/latest.log`; `health_check.py` la ejecuta como
  `rain_tests` y la CI la ejecuta en Linux.
- `docs/architecture/RAIN_AND_SURFACE_FX.md`: ecuaciones, integración con
  F3.4/F4.4/F5.1, presupuestos y límites.

### Cambiado

- Versión `0.3.2` en `VERSION`, `project.godot`, `export_presets.cfg`
  (`version/name` y `version/code=109`), `EXPECTED_VERSION` del smoke test,
  `PHASE` de Boot y `BOOT_KICKER` en once idiomas.
- Presupuesto CPU medido en escritorio/headless: **PC ~0,21 ms de media y
  ~0,28 ms p95** con 4.096 gotas, 24 charcos y 2 escobillas; **móvil ~0,17 ms
  de media y ~0,21 ms p95** con 1.536 gotas, 12 charcos y 30 Hz. El coste GPU,
  el overdraw y el warm-up quedan para F3.4/F3.5.
- Revisión visual completa del hito F3.3 registrada en
  `docs/reference/REFERENCE_USAGE_LOG.md`; se usaron las hojas de contacto
  existentes y una hoja de detalle nueva, sin copiar archivos externos.
- `docs/architecture/DATA_CONTRACTS.md`, `SYSTEM_ARCHITECTURE.md`,
  `STATE_MACHINES.md`, `QA_AND_RECOVERY.md` y `BUILD_AND_RELEASE.md` documentan
  el contrato y la prueba de lluvia.

### Notas

- No se añadieron assets, mallas, materiales, manifiestos ni escenas de
  vehículo. F2.1–F3.2 siguen intactos.
- No se implementaron shaders GLSL, VFX, pérdida de agarre, vadeo ni mecánicas
  de conducción; eso corresponde a F3.4/F5.1.
- Smoke test **270**, tren motriz **125**, cabina **46**, interacción **257** y
  lluvia **126**; todos exit 0.
- La build Windows de referencia y los renders reales se validaron en el cierre
  de la subfase; los binarios no se versionan.

## [0.3.1] — 2026-11-22

### Añadido

- `data/vehicle/interior_spec.json` (`schema_version: 1`, asset
  `vehicle.esteem.interior`): contrato declarativo del **interior definitivo**
  del Esteem con piezas separadas (tablero bitono, instrumental de tres
  básculas sin texto, consola central, radio cassette doble DIN, clima con
  deslizadores, guantera con cierre, palanca P-R-N-D-2-L con botón de
  Overdrive, freno de mano, butacas delanteras y banqueta trasera con telas de
  dos tonos, cuatro tarjetas de puerta con inserto de tela, alfombrado, techo,
  maletero y herramientas del inventario), materiales PBR propios y
  LOD0/LOD1/LOD2 con presupuestos decrecientes.
- **Manos definitivas** (`hand_left`/`hand_right`) con malla propia (palma,
  cuatro dedos y pulgar) en las posiciones de bind de `esteem_hand_rig`;
  sustituyen los proxies de caja de F2.3 en `cabin_visual_proxies.gd` sin tocar
  `cabin_interaction.json` v2 ni el rig ni las poses IK de F2.2.
- **Herramientas del maletero** como objetos reales enlazados con
  `inventory_tools.json` (`tool.jack`, `tool.wheel_wrench`, `tool.spare_tire`,
  `tool.boards`, `tool.flashlight`, `tool.screwdriver_set`, `tool.pliers`,
  `tool.adjustable_wrench`, `tool.socket_set`, `tool.jumper_cables`):
  referencia para el inventario de F5.1, sin mecánicas nuevas.
- `tools/blender/esteem_interior.py`: generador `bpy` reproducible del interior
  (piezas por features de LOD, básculas con agujas ámbar, manos unidas por
  mano, herramientas del maletero y anclas). Nuevo target
  `vehicle.esteem.interior` en `tools/blender/build_assets.py`.
- Salidas generadas: `esteem_interior_lod0.glb` (7.408 triángulos, máx.
  18.000), `esteem_interior_lod1.glb` (1.564, máx. 8.000),
  `esteem_interior_lod2.glb` (712, máx. 3.000) y
  `esteem_interior_rig_anchor.glb` (9 anclas idénticas al bloqueo), con
  manifiesto reproducible `assets/manifests/esteem_interior.manifest.json`.
- `tools/validate_assets.py`: validación del spec de interior (coherencia de
  cotas y anclas con `blockout_spec.json`, manos alineadas con el rig de
  `cabin_spec.json`, herramientas enlazadas con `inventory_tools.json`,
  nodos interactivos exigidos por `cabin_visual_proxies.gd`, IDs únicos,
  materiales declarados y presupuestos decrecientes).
- `scenes/vehicle/EsteemInterior.tscn`: LOD0 visible, LOD1/LOD2 ocultos,
  `HandRig` (rig de manos de F2.2 sin cambios) y `RigAnchor`. La escena de
  interacción (`CabinInteraction.tscn`) instancia ahora el interior definitivo
  en lugar del greybox de F2.2 (el greybox y sus tests de F2.2 se conservan).
- `tests/smoke/SmokeTest.tscn`: **270 comprobaciones** (eran 232) con la
  verificación del interior (manifiesto, hashes, LODs decrecientes, presupuesto
  móvil, manos definitivas, herramientas del maletero y anclas). Tren motriz
  (125), cabina (46) e interacción (257) sin cambios.

### Cambiado

- Versión `0.3.1` en `VERSION`, `project.godot`, `export_presets.cfg`
  (`version/code=108`), `EXPECTED_VERSION` del smoke test, `PHASE` de Boot y
  `BOOT_KICKER` en once idiomas.
- Revisión visual completa del hito F3.2 registrada en
  `docs/reference/REFERENCE_USAGE_LOG.md` (hojas de contacto de interior y seis
  copias de trabajo; biblioteca externa intacta).

## [0.3.0] — 2026-11-22

### Añadido

- `data/vehicle/exterior_spec.json` (`schema_version: 1`, asset
  `vehicle.esteem.exterior`): contrato declarativo del **exterior definitivo**
  del Esteem con piezas separadas (carrocería tipo bañera e invernadero por
  secciones, capó, tapa de maletero, cuatro puertas con manijas, parachoques
  delantero/trasero con boca de aire, parrilla neutra con listones, faros con
  piloto ámbar, pilotos traseros de tres franjas, carcasas de espejo, antena,
  tapa de combustible, limpiaparabrisas, molduras, vidrios y matrícula
  neutra), materiales PBR propios, llantas con tapacubo y LOD0/LOD1/LOD2 con
  presupuestos decrecientes.
- `tools/blender/esteem_exterior.py`: generador `bpy` reproducible del exterior
  (lofts de secciones, paneles de vidrio, ruedas con neumático/llanta/tapacubo
  y radios, materiales Principled PBR con transmisión y emisión para lentes).
  Nuevo target `vehicle.esteem.exterior` en `tools/blender/build_assets.py`.
- Salidas generadas: `esteem_exterior_lod0.glb` (6.024 triángulos, máx.
  20.000), `esteem_exterior_lod1.glb` (2.044, máx. 9.000),
  `esteem_exterior_lod2.glb` (408, máx. 4.000) y
  `esteem_exterior_rig_anchor.glb` (17 anclas idénticas al bloqueo), con
  manifiesto reproducible `assets/manifests/esteem_exterior.manifest.json`.
- `tools/validate_assets.py`: validación del spec de exterior (coherencia de
  cotas y ruedas con `blockout_spec.json`, carcasas de espejo que envuelven
  `anchor_mirror_left/right`, IDs únicos, materiales declarados, presupuestos
  decrecientes y margen de sobresalida de herrajes `pieces_overhang_m`).
- `scenes/vehicle/EsteemExterior.tscn`: LOD0 visible, LOD1/LOD2 ocultos y
  `RigAnchor`. La rebanada vertical (`VerticalSlice.tscn`) ahora instancia el
  exterior definitivo en lugar del bloqueo.
- `tests/smoke/SmokeTest.tscn`: **232 comprobaciones** (eran 198) con la
  verificación completa del exterior (manifiesto, hashes, LODs decrecientes,
  presupuesto móvil, anclas) y el anclaje de los espejos de F2.4 sobre el nuevo
  exterior (`mirrors.budget` respetado). Tren motriz (125), cabina (46) e
  interacción (257) sin cambios.
- Render QA del exterior en `build/reference/exterior_qa/` (no versionado) con
  cuatro vistas verificadas contra la hoja de contacto de F3.1.

### Cambiado

- Versión del proyecto a `0.3.0` (`VERSION`, `project.godot`,
  `export_presets.cfg`, `EXPECTED_VERSION` del smoke test y `PHASE` de Boot).
  Android `version/name=0.3.0`, `version/code=107`; Windows `0.3.0.0`.
- `BOOT_KICKER` a Fase 3.1 en los once idiomas.
- `health_check.py`: artefactos de F3.1 en `REQUIRED_FILES` (spec, script,
  manifiesto y escena del exterior).
- Revisión visual completa de referencias antes de modelar (hito F3.1): hojas
  de contacto de exterior generadas en `build/reference/contact_sheets/` y
  registro en `docs/reference/REFERENCE_USAGE_LOG.md`; biblioteca externa sin
  cambios y sin copiar archivos.

### Sin cambios

- F2.1–F2.4 intactos: tren motriz, cabina, interacción contextual, espejos
  `SubViewport`, HUD, gamepad/D-Pad y guardado `v0.2.0` con fixture. Los
  espejos funcionales siguen anclados a `anchor_mirror_left/right` y
  respetan `mirrors.budget` de `cabin_interaction.json` (`schema_version: 2`).
- Sin marcas ni emblemas (Chevrolet, PDV, Suzuki u otros) y sin texto visible
  en la malla. Sin texturas de la biblioteca externa.

## [0.2.3] — 2026-11-22

### Añadido

- `data/schemas/cabin_interaction.json` **`schema_version: 2`** (cambio
  aditivo): secciones `mirrors` (tres espejos con `SubViewport`, presupuesto de
  triángulos y pasos de render), `hud` (overlay mínimo con los ocho avisos del
  tren motriz) y `gamepad` (acciones `ui_*`, D-Pad, A/B y stick), con
  `schema_history` documentando la migración v1 → v2.
- `src/vehicle/cabin_mirrors.gd`: espejo interior y dos laterales anclados a
  `anchor_mirror_left` / `anchor_mirror_right`, cámaras que comparten el
  `World3D` de la escena, cadencia `update_hz` rearmada con `UPDATE_ONCE` y
  `set_viewports_enabled()` para el perfil de bajo consumo.
- `src/vehicle/cabin_hud.gd`: HUD de velocidad, marcha, combustible y avisos
  alimentado por `VehiclePowertrain.get_telemetry()` a `hud.refresh_hz`; claves
  `HUD_*` y `HUD_WARN_*` en once idiomas; cero botones táctiles y avisos con
  texto además de color.
- `src/vehicle/cabin_gamepad_adapter.gd`: D-Pad enfoca los controles
  contextuales con ciclo cerrado, A pulsa, B suelta y el stick derecho rota la
  cámara con los límites de F2.3. Los menús navegan con las acciones `ui_*`
  (D-Pad, stick y A/B declarados en `project.godot`).
- Guardado línea base `v0.2.0`: fixture `tests/fixtures/save_v0_2_0.json`
  generado y verificado con `tools/make_save_fixture.py` (replica exacta del
  JSON canónico de `SaveManager`), carga real en prueba, backup `.bak`,
  escritura sin temporales y rechazo verificado de versiones futuras.
- Panel QA: sección de vehículo (reparar motor, refrigeración y frenos,
  repostar, fijar combustible bajo y dañar el fusible del ventilador) sobre el
  `VehiclePowertrain` del grupo `vehicle_powertrain`, más guardar/cargar la
  ranura QA (`user://saves/qa/`, sin pisar partidas reales). El panel QA
  también está disponible en la escena de cabina con F12.
- Foco inicial con gamepad en Boot y en la rebanada (el D-Pad toma el foco en
  el primer evento). En el menú raíz, B del gamepad no cierra la aplicación;
  Esc sí.
- 29 claves de localización nuevas (`HUD_*`, `HUD_WARN_*`, `QA_*` de vehículo
  y guardado) en los once idiomas, provisionales hasta la revisión nativa de
  F8.4; `BOOT_KICKER` actualizado a Fase 2.4.
- `health_check.py`: nuevo chequeo `save_fixture` y archivos de F2.4 en
  `REQUIRED_FILES`.

### Cambiado

- Versión del proyecto a `0.2.3` (`VERSION`, `project.godot`,
  `export_presets.cfg`, `EXPECTED_VERSION` del smoke test y `PHASE` de Boot).
  Android `version/name=0.2.3`, `version/code=106`; Windows `0.2.3.0`.
- `CabinInteractionSpec` acepta `schema_version` 1 y 2 y exige las secciones
  `mirrors`, `hud` y `gamepad` en la versión 2.
- `CabinInteractionController` expone `focus_next_control()`,
  `focus_previous_control()` y `rotate_camera_look()`, reutilizables por el
  gamepad sin introducir eventos de gamepad en el núcleo de F2.3.
- `tests/vehicle/InteractionTest.tscn`: **257 comprobaciones** (eran 180) con
  espejos, HUD, gamepad y límites de fuentes.
- `tests/smoke/SmokeTest.tscn`: **198 comprobaciones** (eran 155) con fixture
  de guardado, backup, versión futura, QA de reparaciones y menús con gamepad.
  Tren motriz (125) y cabina (46) sin cambios.
- Documentación actualizada: `SYSTEM_ARCHITECTURE` §12, `DATA_CONTRACTS` §9.1 y
  §15.1, `STATE_MACHINES` §10, `ASSET_FACTORY` §11 y `QA_AND_RECOVERY` §14.

### Corregido

- `SaveManager._backup_file()` y la recuperación tras un rename fallido usaban
  rutas relativas en `DirAccess.copy()`, que se resuelven contra el proceso y
  fallaban al abrir el archivo: ahora usan rutas absolutas
  (`user://saves/slot_XX.json.bak`). Lo destapó la nueva prueba de backup de
  esta subfase.

## [0.2.2] — 2026-11-22

### Añadido

- Contrato declarativo `data/schemas/cabin_interaction.json` (`schema_version: 1`)
  con retículo/tacto, poses IK de 2/1/0 manos, puertas y seguros, vidrios, luces,
  antena, radio, guantera, palanca P-R-N-D-2-L con Overdrive y freno de mano. Su
  JSON Schema vive en `data/schemas/json/cabin_interaction.schema.json` y se
  valida en `tools/validate_schemas.py`.
- `src/vehicle/cabin_interaction_controller.gd`: foco por retículo y tacto (44 dp),
  gestos, arrastre de la palanca, feedback contextual y delegación en el tren
  motriz.
- `src/vehicle/cabin_controls.gd`: estado de puertas/seguros, vidrios, luces,
  antena, radio, guantera, palanca y freno de mano. La palanca y el Overdrive
  llaman a `VehiclePowertrain`; el freno de mano termina en `brakes.parking`.
- `src/vehicle/hand_ik_driver.gd`: cadena IK de dos huesos por brazo, transiciones
  y poses de 2/1/0 manos en el volante. El volante no mueve la dirección ni el
  chasis.
- `src/vehicle/radio_unit.gd`: radio procedural con bandas AM/FM, búsqueda,
  volumen y señal dependiente de la antena, usando `AudioStreamGenerator` sin
  samples de terceros.
- `src/vehicle/cabin_visual_proxies.gd`: vidrios, antena, testigos, botones y
  manos como primitivas de código; offsets funcionales para sacar los mandos de
  las cajas sólidas del greybox de F2.2. No son arte final.
- `scenes/vehicle/CabinInteraction.tscn`: escena de cabina interactiva con cámara,
  luz de presentación, tren motriz sin simulación automática, proxies y prompt.
- `src/vehicle/cabin_interaction_ui.gd` y `cabin_reticle.gd`: retículo y prompt
  contextual localizado; sin HUD de velocidad/combustible y sin botones
  persistentes.
- `tests/vehicle/InteractionTest.tscn`, `interaction_test.gd` y
  `tools/dev/interaction_test.cmd`: 180 comprobaciones headless de contrato,
  escena, poses IK, foco/tacto, puertas, vidrios, luces, antena, radio, guantera,
  palanca, Overdrive y freno de mano.
- 30 claves de localización nuevas (`CABIN_CONTROL_*`, `CABIN_HINT_*`,
  `UI_VIEW_CABIN`) en los once idiomas, con traducciones provisionales pendientes
  de revisión nativa.
- Acceso `Ver cabina` en `Boot` mediante `UI_VIEW_CABIN` y `SceneRouter`.

### Cambiado

- Versión del proyecto a `0.2.2` (`VERSION`, `project.godot`, `export_presets.cfg`,
  `EXPECTED_VERSION` del smoke test). Android `version/name=0.2.2`,
  `version/code=105`; Windows `0.2.2.0`.
- `VehiclePowertrain.set_parking_brake()` propaga el estado a `brakes.parking` en
  el mismo comando para que la cabina no duplique la mecánica ni dependa de un
  paso de simulación.
- `health_check.py` añade `interaction_tests` y exige los archivos del contrato,
  la escena y las pruebas de F2.3.
- `tools/validate_schemas.py` valida el contrato de interacción, sus referencias,
  las poses 2/1/0 manos, los detentes P-R-N-D-2-L, las claves de localización y
  los enlaces `transmission.selector`, `transmission.overdrive` y
  `brakes.parking`.
- `ROADMAP.md`, `docs/roadmap-data.json`, `CURRENT.md`, `HANDOFF.md` y la
  documentación de arquitectura y referencias reflejan el cierre de 2.3.

### Validación

- 7 contratos JSON válidos; advertencia previa de 202 claves de contenido para
  F8.4.
- Localización de 11 idiomas sin errores; fuentes CJK/cirílicas pendientes de
  F8.4; traducciones nuevas sin revisión nativa.
- Roadmap 7/45 subfases completadas (15,6%), JSON sincronizado con la web.
- Importación de Godot 4.7.2 headless con exit 0; sin marcadores críticos.
- Smoke test: 155/155, exit 0 (sin regresiones).
- Pruebas del tren motriz: 125/125, exit 0 (sin regresiones).
- Pruebas de la cabina: 46/46, exit 0 (sin regresiones).
- Pruebas de interacción: 180/180, exit 0 (nuevas).
- `health_check.py --end`: 18 OK, 3 advertencias esperadas (claves de contenido,
  fuentes y árbol previo al commit), 0 errores.
- Dispositivo ADB autorizado (Redmi 22101316G) y 79,83 GB libres en `C:`.
- Referencias: 95 archivos; escaneo rápido sin cambios y revisión de interior de
  F2.3 registrada. No se copió ningún archivo de la biblioteca externa.
- Capturas de trabajo de la cabina en `build/logs/interaction/` (no versionadas).

### Limitaciones conocidas

- Los vidrios, la antena, los testigos, los botones y las manos son primitivas de
  código; el arte final es F3.1/F3.2.
- Los `visual_offsets` corrigen la colocación del greybox de F2.2; la geometría
  definitiva y las cotas verificadas son F3.2.
- El seguro central, el mando de luces y el interruptor de antena no se
  distinguen en las fotos revisadas: son proxies provisionales.
- No hay espejos, HUD, gamepad ni guardado: son F2.4. No se creó una APK nueva.

## [0.2.1] — 2026-11-22

### Añadido

- Contrato declarativo `data/vehicle/cabin_spec.json`: cabina funcional del Esteem
  (volante de tres radios, columna, tablero, instrumental, consola central, radio
  cassette doble DIN con ranura, clima, guantera con bandeja/cierre, paneles de
  puerta con apoyabrazos/tirador/cristaleras y consola) y el rig de manos con
  poses IK. Cotas de interior provisionales derivadas de las anclas `anchor_*` del
  bloqueo y de las fotos; no son especificación oficial.
- `tools/blender/esteem_cabin.py`: script `bpy` reproducible que genera las mallas
  LOD0/LOD1/LOD2 de la cabina y el armazón `EsteemHandRig` con huesos de mano,
  huesos de control alineados con `anchor_*` y poses IK (botón de Overdrive,
  palanca tipo T, freno de mano).
- Target `vehicle.esteem.cabin` en `tools/blender/build_assets.py`.
- Assets generados `esteem_cabin_lod0/1/2.glb` y `esteem_hand_rig.glb` con
  manifiesto `assets/manifests/esteem_cabin.manifest.json` (comando, hashes,
  autor, licencia CC BY-NC-SA 4.0, fecha).
- Escena `scenes/vehicle/EsteemCabin.tscn` (LOD0 visible, LOD1/2 ocultos, rig).
- `tests/vehicle/CabinTest.tscn` y `cabin_test.gd`: 46 comprobaciones headless
  (manifiesto y hashes, LODs decrecientes y coincidentes, rig de manos con
  `anchor_root`, compatibilidad de posiciones de anclas con el bloqueo, poses IK
  y ausencia de física de conducción).
- `tools/dev/cabin_test.cmd` y `.ps1`; chequeo `cabin_tests` en `health_check.py`.
- Revisión visual completa de referencias de interior para F2.2 registrada en
  `REFERENCE_USAGE_LOG.md` (hoja de contacto + 3 fotos a tamaño real; sin copiar
  archivos de la biblioteca externa).

### Cambiado

- Versión del proyecto a `0.2.1` (`VERSION`, `project.godot`, `export_presets.cfg`,
  `EXPECTED_VERSION` del smoke test).
- `export_presets.cfg`: `version/name` de Android a `0.2.1`, `version/code` a 104
  y versiones de Windows a `0.2.1.0`.
- `validate_assets.py` cubre el nuevo manifiesto de cabina (mismo contrato de
  LOD0/1/2 y `rig_anchor`).
- `ASSET_FACTORY.md`, `DATA_CONTRACTS.md`, `ESTEEM_MECHANICAL_NOTES.md`,
  `REFERENCE_USAGE_LOG.md` y `REFERENCE_REVIEW.md` actualizados con el alcance de
  2.2.

### Validación

- 6 contratos JSON válidos; advertencia previa de claves de contenido para F8.4.
- Localización de 11 idiomas sin errores; fuentes CJK pendientes de F8.4.
- Roadmap 6/45 subfases completadas (13,3%), JSON sincronizado con la web.
- Importación de Godot 4.7.2 headless con exit 0; sin marcadores críticos.
- Smoke test: 155/155 comprobaciones, exit 0 (sin cambios).
- Pruebas del tren motriz: 125/125, exit 0 (sin cambios).
- Pruebas de la cabina: 46/46, exit 0 (nuevo).
- Assets generados: 2 manifiestos válidos, 0 errores (LOD0 1584 / LOD1 704 /
  LOD2 480 triángulos, estrictamente decrecientes y dentro de presupuesto).
- `health_check.py --end`: 17 OK, 3 advertencias esperadas, 0 errores.
- Dispositivo ADB autorizado (Redmi 22101316G) y 79,86 GB libres en `C:`.
- Referencias: 95 archivos; escaneo rápido sin cambios; revisión de interior
  completada y registrada.

### Publicación

- Commit convencional, tag `v0.2.1` y push a `origin/main`.

### Estado

- Fase 2.2 completada: cabina funcional bloqueo (volante, palanca P-R-N-D-2-L con
  Overdrive, freno de mano, radio doble DIN, guantera, paneles y consola) y rig de
  manos con poses IK compatibles con `anchor_*`. Sin interacción (F2.3), espejos,
  HUD, gamepad ni guardado (F2.4).
- Siguiente: Fase 2.3 con DS-R (interacción contextual "mirar/tocar", IK manos,
  puertas, seguros, vidrios, luces, antena y radio).

## [0.2.0] — 2026-11-22

### Añadido

- Contrato `data/schemas/vehicle_powertrain.json` y su JSON Schema
  `data/schemas/json/vehicle_powertrain.schema.json`: motor, transmisión,
  combustible, frenos, refrigeración y parámetros longitudinales del vehículo,
  con `source_status`/`source_note` por sección.
- Simulación del tren motriz en `src/vehicle/`:
  - `engine_model.gd`: arranque, ralentí, curva de par, corte de inyección,
    fricción, retención, calado, ahogo, secado, modo seguro y agarrotamiento.
  - `automatic_transmission.gd`: P-R-N-D-2-L, Overdrive, convertidor de par,
    bloqueo en crucero, calendario de cambios y rechazo de cambios inválidos.
  - `brake_system.gd`: frenos de servicio y estacionamiento, fade térmico,
    desgaste de pastillas y nivel de líquido.
  - `fuel_system.gd`: tanque de 50 L, consumo, reserva y calado por vacío.
  - `cooling_system.gd`: termostato, radiador, electroventilador de dos
    velocidades, fallos de fusible/relé/motor y protecciones térmicas.
  - `vehicle_powertrain.gd`: orquestador longitudinal con señales locales y
    telemetría; sin UI, cabina ni `VehicleBody3D`.
- `tests/vehicle/PowertrainTest.tscn` y `powertrain_test.gd`: 125 comprobaciones
  headless del contrato y de todos los subsistemas.
- `tools/dev/powertrain_test.cmd` y `.ps1`: importación headless, ejecución y
  log en `build/logs/powertrain/latest.log`.
- Chequeo `powertrain_tests` en `health_check.py` y paso nuevo en CI.
- Integración del tren motriz en el smoke test (155 comprobaciones).

### Cambiado

- Versión del proyecto a `0.2.0` (`VERSION`, `project.godot`, presets, README).
- `validate_schemas.py` valida seis contratos y comprueba la coherencia del tren
  motriz con `vehicle_components.json` y `blockout_spec.json`.
- `ESTEEM_MECHANICAL_NOTES.md` separa los datos verificados del manual de los
  valores de simulación provisionales.
- `REFERENCE_USAGE_LOG.md`, `REFERENCE_REVIEW.md`, arquitectura y QA actualizados
  con el alcance de 2.1.
- Catálogo de referencias a 95 archivos; el nuevo video conceptual queda
  catalogado sin usarse en mecánica.

### Validación

- 6 contratos JSON válidos; advertencia previa de claves de contenido para F8.4.
- Localización de 11 idiomas sin errores; fuentes CJK pendientes de F8.4.
- Roadmap 5/45 subfases completadas (11,1%), JSON sincronizado con la web.
- Importación de Godot 4.7.2 headless con exit 0.
- Pruebas del tren motriz: 125/125, exit 0.
- Smoke test: 155/155 comprobaciones, exit 0.
- `health_check.py --end`: sin errores; advertencias esperadas documentadas.
- Dispositivo ADB autorizado y espacio en disco comprobados.
- Referencias: 95 archivos; escaneo rápido sin cambios pendientes.

### Publicación

- Commit convencional, tag `v0.2.0` y push a `origin/main`.

### Estado

- Fase 2.1 completada: tren motriz data-driven con pruebas; sin cabina, IK,
  espejos ni conducción narrativa.
- Siguiente: Fase 2.2 con MiMo Pro (cabina funcional, rig de manos y poses IK).

## [0.1.3] — 2026-11-22

### Añadido

- Rebanada vertical estática `scenes/vertical_slice/VerticalSlice.tscn`: bloqueo
  gris del Esteem sobre una carretera gris con terreno, marcas de carril, cámara,
  niebla y panel informativo. Sin física, tráfico ni conducción.
- Acceso localizado desde el boot con el botón `UI_VIEW_SLICE` y retorno con
  `UI_BACK`; claves nuevas `SLICE_TITLE` y `SLICE_SUBTITLE` en los once idiomas.
- `export_presets.cfg` con presets `Windows Desktop` (x86_64) y `Android`
  (arm64-v8a, APK debug firmada, paquete
  `com.emanuelindustri.rutanoucturna1999`).
- `tools/dev/export.ps1` y `tools/dev/export.cmd`: importación headless, export
  de Windows/Android, log y manifiesto con tamaños y SHA-256 en
  `build/logs/export/`.
- `tools/test_android_adb.ps1`: instalación `adb install -r`, arranque con
  `monkey`, marcador `BOOT_READY`, 15 s de `logcat`, captura, PSS y logs en
  `build/logs/android-smoke/`.
- `tools/validate_export.py`: valida presets, rutas, arquitectura, paquete,
  versión, inclusión del CSV y ausencia de secretos; integrado en
  `health_check.py` y en CI.
- Chequeos nuevos de salud: `export_presets`, `build_toolchain`,
  `android_device` y `tracked_secrets`.
- Workflow de CI con trabajo `godot` (descarga Godot 4.7.2 Linux, import headless,
  smoke test y detección de errores de script) y validación de presets.
- `docs/architecture/BUILD_AND_RELEASE.md` con el pipeline de build, ADB y CI.

### Cambiado

- Versión del proyecto a `0.1.3`.
- `project.godot` activa `textures/vram_compression/import_etc2_astc` para que el
  export Android genere la APK.
- `LocalizationManager` carga los `.translation` importados cuando el CSV no está
  presente en una build exportada; el CSV sigue siendo la fuente de verdad.
- Boot imprime el marcador estable `[RN1999] BOOT_READY` para las pruebas ADB.
- Smoke test ampliado a 138 comprobaciones: rebanada vertical, presupuesto móvil,
  ausencia de cuerpos de física, presets de export y versión.
- README, web de Pages y documentación de arquitectura actualizados a `v0.1.3`.

### Validación

- 5 contratos JSON válidos; advertencia previa de claves de contenido para F8.4.
- Localización de 11 idiomas y 62 claves sin errores; fuentes CJK pendientes de F8.4.
- Roadmap 4/45 subfases completadas (8,9%), JSON sincronizado con la web.
- Importación de Godot 4.7.2 headless con exit 0.
- Smoke test con 138/138 comprobaciones y exit 0.
- Export Windows debug verificado; el ejecutable arranca headless con 11/11
  servicios y localización en los 11 idiomas.
- APK Android debug compilada y firmada; instalada en el Redmi 22101316G y
  arrancada por ADB. Sin errores fatales en 15 s de logcat, PSS 376,5 MB y
  captura de la rebanada vertical en `build/logs/android-smoke/`.
- En MIUI/HyperOS fue necesario conceder "Instalar vía USB" al paquete; el
  intento inicial falló con `INSTALL_FAILED_USER_RESTRICTED`.
- `health_check.py --end`: 15 OK, 3 advertencias esperadas, 0 errores.
- Escaneo rápido de 94 referencias sin cambios.

### Publicación

- Commit convencional, tag `v0.1.3` y push a `origin/main`.

### Estado

- Fase 1 completada: vertical slice gris con build PC/APK, CI y Pages, sin
  mecánicas de conducción.
- Siguiente: Fase 2.1 con DS-R (motor, caja automática y tests).

## [0.1.2] — 2026-11-22

### Añadido

- Fábrica de assets Blender 4.5.16 headless: orquestador
  `tools/blender/build_assets.py`, generador paramétrico `bpy`
  `tools/blender/esteem_blockout.py` y wrapper `tools/blender/build_assets.cmd`.
- Contrato declarativo `data/vehicle/blockout_spec.json` con cotas provisionales
  del vehículo, masas de greybox, materiales, presupuestos de LOD y anclas de rig.
- Bloqueo del Esteem generado proceduralmente en `assets/generated/vehicle/`:
  `esteem_blockout_lod0.glb` (1.192 triángulos, máx. 8.000),
  `esteem_blockout_lod1.glb` (440, máx. 4.000) y
  `esteem_blockout_lod2.glb` (184, máx. 1.500); decrecientes y sin texturas de
  terceros.
- Ancla de rig `esteem_rig_anchor.glb`: armazón `EsteemRigAnchor` con
  `Skeleton3D` de 17 huesos `anchor_*` (ruedas, asientos, volante, palanca,
  freno de mano, cámaras, capó, maletero, espejos y techo) para el rig futuro.
- Manifiesto reproducible `assets/manifests/esteem_blockout.manifest.json` con
  comando exacto de Blender, hashes SHA-256 de entradas y salidas, autor,
  licencia CC BY-NC-SA 4.0 y fecha UTC.
- Validador `tools/validate_assets.py` (manifiestos, hashes, política de
  LOD0/LOD1/LOD2 y coherencia de anclas) integrado en `health_check.py`.
- Escena `scenes/vehicle/EsteemBlockout.tscn` con los tres LODs (solo LOD0
  visible) y el ancla de rig.
- Documentación del pipeline en `docs/architecture/ASSET_FACTORY.md` y sección 11
  de `docs/architecture/DATA_CONTRACTS.md`.
- Smoke test ampliado con 31 comprobaciones del bloqueo: manifiesto, hashes
  SHA-256, LODs, conteo de triángulos y los 17 huesos del ancla.

### Cambiado

- Versión del proyecto a `0.1.2`.
- `tools/dev/smoke_test.ps1` ejecuta la importación headless de Godot antes de la
  escena; el smoke test es autosuficiente en un clon limpio.
- `docs/reference/ESTEEM_MECHANICAL_NOTES.md` registra las cotas del bloqueo como
  valores de diseño provisionales pendientes de verificación.
- `docs/reference/REFERENCE_USAGE_LOG.md` registra la revisión de referencias del
  vehículo para el bloqueo (hoja de contacto, perfil lateral y manual Mitchell).

### Validación

- 5 contratos JSON validados; 1 advertencia previa de claves de contenido (F8.4).
- Localización de 11 idiomas sin errores; fuentes CJK pendientes de F8.4.
- Manifiestos de assets válidos: 4 salidas, hashes verificados, LOD0/1/2 con
  triángulos decrecientes y 17 anclas coincidentes con el spec.
- Roadmap 3/45 subfases (6,7%), JSON sincronizado con la web.
- Importación de Godot 4.7.2 headless con exit 0 (4 GLB importados sin errores).
- Smoke test con 118/118 comprobaciones y exit 0.
- `health_check.py --end`: 11 OK, 3 advertencias esperadas, 0 errores.
- Escaneo rápido de 94 referencias sin cambios.

### Publicación

- Commit convencional, tag `v0.1.2` y push a `origin/main`.

### Estado

- Fase 1.3 completada. Sin mecánicas de conducción. Las cotas del bloqueo son
  provisionales hasta verificarlas en Fase 2/Fase 5.
- Siguiente: Fase 1.4, CI, test Android/ADB, export Windows/APK y tag de
  vertical slice.

## [0.1.1] — 2026-11-22

### Añadido

- `EventBus` con señales tipadas y catálogo en `docs/architecture/EVENT_BUS.md`.
- Once autoloads base en orden topológico: `EventBus`, `HardwareProfiler`,
  `SettingsManager`, `LocalizationManager`, `GameState`, `SaveManager`,
  `AudioDirector`, `WeatherManager`, `UpdateChecker`, `CrashReporter` y
  `SceneRouter`.
- `CrashReporter` con logger nativo, búfer de log, contexto por servicios,
  reporte local y marcador de sesión para cierres anormales.
- `SaveManager` base con snapshot versionado, checksum canónico, escritura
  atómica, backup y rechazo de versiones futuras.
- `CreatorQAMenu` inicial con F12, cinco toques, estado, clima, modo de prueba,
  reporte local y copia al portapapeles.
- Boot de Fase 1.2 con verificación de servicios y aviso de cierre anormal previo.
- Smoke test de servicios base y wrapper `tools/dev/smoke_test.cmd`.
- Validación de autoloads y ejecución del smoke test dentro de `health_check.py`.

### Cambiado

- Versión del proyecto a `0.1.1`.
- Localización ampliada a 59 claves en los once idiomas.
- Las traducciones se cargan en runtime desde `localization/strings.csv`, sin
  depender de artefactos de importación.
- El orden de autoloads coincide exactamente con
  `data/schemas/autoload_dependencies.json`.

### Validación

- 5 contratos JSON validados; 1 advertencia de claves de contenido para F8.4.
- Localización de 11 idiomas y 59 claves sin errores; fuente CJK pendiente.
- 11 autoloads declarados y verificado el orden topológico.
- Importación de Godot 4.7.2 headless con exit 0.
- Boot headless con 11/11 servicios y exit 0.
- Smoke test con 87/87 comprobaciones y exit 0.
- Reporte local, marcador de sesión y panel QA verificados.
- Un warning no genera reporte de error; un error de GDScript sí.
- Un marcador de sesión simulado produjo el reporte de cierre anormal al arrancar.
- `health_check.py --end`: 10 OK, 3 advertencias esperadas, 0 errores.
- Escaneo rápido de 94 referencias sin cambios.

### Publicación

- Commit convencional, tag `v0.1.1` y push a `origin/main`.

### Estado

- Fase 1.2 completada. Sin mecánicas de conducción.
- Siguiente: Fase 1.3, fábrica Blender headless y bloqueo del Esteem.

## [0.1.0] — 2026-11-22

### Añadido

- Estructura base de Ruta Nocturna 1999.
- Reglas de ejecución, modelos, presupuestos y protocolo de contexto en `AGENTS.md`.
- Roadmap de 45 subfases y web inicial de GitHub Pages.
- Contratos canónicos para vehículo, herramientas, folclore, diálogos y autoloads.
- Arquitectura de autoloads y máquinas de estados.
- Herramientas de validación, sincronización del roadmap y escaneo de referencias.
- Localización base para los once idiomas.
- Inventario inicial de la biblioteca externa de referencias.
- Corrección de la marca RUNASADMIN de Godot y generación del debug keystore.

### Validación

- 5 contratos JSON y sus esquemas validados sin errores.
- Localización base de 11 idiomas sin errores de claves ni placeholders.
- Roadmap de 10 fases y 45 subfases sincronizado con la web.
- Importación y boot de Godot 4.7.2 en headless correctos.
- Web validada en navegador; Lighthouse 100 en accesibilidad, buenas prácticas y SEO.
- 94 referencias inventariadas, con dos duplicados exactos detectados.
- Bootstrap sin fallos críticos; advertencias: autenticación de GitHub y Android 36.
- ADB reconoce el Redmi 22101316G.

### Publicación

- Repositorio público creado en `emanuelindustri-source/ruta-nocturna-1999`.
- `main`, workflows y tag `v0.1.0` publicados.
- GitHub Pages configurado para publicar desde GitHub Actions.
- Web: https://emanuelindustri-source.github.io/ruta-nocturna-1999/

### Estado

- Fase 1.1 completada. Sin mecánicas jugables todavía.
- Siguiente: Fase 1.2, autoloads base, CrashReporter y CreatorQAMenu inicial.
