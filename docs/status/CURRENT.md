# Estado actual

**Subfase:** 4.1 — Pipeline OSM/Overpass, DEM, grafo, rutas alternativas, caché y atribución ODbL
**Versión:** `v0.4.0`
**Modelo de la subfase:** DS-R (`opencode-go/deepseek-v4.1-flash#max`)
**Fecha:** 2026-11-24
**Estado:** completada; commit y tag `v0.4.0` en este cierre.

## Enlaces

- Web: https://emanuelindustri-source.github.io/ruta-nocturna-1999/
- Repositorio: https://github.com/emanuelindustri-source/ruta-nocturna-1999
- Acciones: https://github.com/emanuelindustri-source/ruta-nocturna-1999/actions

## Validación ejecutada

| Prueba | Resultado |
|---|---|
| Contratos JSON + Schemas | **9 contratos válidos**, 0 errores, 1 advertencia conocida (202 claves de datos → F8.4); nuevo `world_routes` v1 y red derivada validados |
| Red de rutas (Python) | **329 nodos, 413 aristas, 6 principales + 12 alternativas**; conectividad desde `hub_carabobo`; ODbL y hash del manifiesto OK |
| Localización | 11 idiomas, 0 errores; `CREDITS_OSM` en 11 idiomas; `BOOT_KICKER` actualizado a Fase 4.1; fuentes CJK pendientes de F8.4 |
| Assets generados | 4 manifiestos válidos, 0 errores; F4.1 no genera ni modifica assets 3D |
| Roadmap | `ROADMAP.md` + `docs/roadmap-data.json` sincronizados (**14/45 completadas, 31,1 %**) |
| Smoke test | **270/270**, exit 0 (versión 0.4.0) |
| Tren motriz | **125/125**, exit 0 |
| Cabina y rig | **46/46**, exit 0 |
| Interacción contextual | **257/257**, exit 0 |
| Prueba de lluvia | **206/206**, exit 0 |
| Red de rutas (Godot) | **143/143**, exit 0 (`tools/dev/world_routes_test.cmd`) |
| Godot import headless | exit 0; sin `SCRIPT ERROR`/`Parse Error`/`Failed to load` |
| Presets de export | Windows y Android válidos; `0.4.0`, Android `version/code=112`; `licenses/*.txt` y `CREDITS.md` incluidos |
| Prueba de render real (ventana, Vulkan Forward+) | **RENDER_OK**; frame 16,66–16,67 ms, 0 jank; draw calls añadidos ≤2,40; overdraw ≤1,0; fill visual 0,02 %/2,51 %; capturas `build/logs/render/f35_*` |
| Build Windows exportada | `build/exports/windows/RutaNocturna1999.exe`, **103.070.208 bytes**, SHA-256 `88992CA9…B91766`; ejecutada sin errores |
| APK Android | **29.820.429 bytes**, SHA-256 `2AE80503…2C4E`; `versionName=0.4.0`, `versionCode=112` |
| Prueba ADB completa en el Redmi | **exit 0**: install Success, arranque **0,8 s**, logcat 15 s sin `FATAL EXCEPTION` ni errores Godot/Vulkan, ruta de rendimiento `done=true` |
| Presupuestos en dispositivo | PSS **428,1 / 545,9 / 630,1 MB** (boot/rebanada/cabina) ≤ 1.228,8; rebanada **15.874 triángulos** ≤ 120.000, frame **11,01 / 16,81 / 34,9 ms** (1 jank > 33 ms, 0 > 100 ms); cabina **7.342 triángulos**, frame **9,81 / 16,63 / 18,96 ms** (0 jank) |
| Carga en dispositivo | Rebanada **9.521 ms**, cabina **4.740 ms** (presupuesto QA 15.000 ms); warm-up **1.973 / 2.174 ms** antes del gameplay |
| Prueba de juego en PC (build exportado) | Boot 11/11 + atribución ODbL; rebanada; cabina; manos al volante al mantener; palanca con ratón **no** responde (H2); QA F12 con clima `Tormenta · 95 %/90 %`. Informe: `build/logs/gameplay/REPORT_F41.md` |
| Prueba manual en Android | Boot/cabina/volante con toque OK; **palanca táctil P → L1 OK** (H2 es solo ratón/teclado/gamepad de PC). Informe: `build/logs/android-smoke/REPORT_F41.md` |
| Espacio libre | **83,1 GB** en `C:` (mínimo 20 GB) |
| Dispositivo ADB | Redmi 22101316G autorizado (`obojropz89mbwgpn`) |
| Git | Rama `main`, commit y tag `v0.4.0` publicados |

Advertencias conocidas:

- **H1 (→ F4.4):** las gotas de cámara (`camera_drops`) cubren la pantalla
  completa y parecen caer **dentro** del habitáculo; visible en PC y Android.
  Recortar la máscara al parabrisas; toca el shader de F3.4 y **no se modifica
  en F4.1**.
- **H2 (→ F5.1/F9.1):** la palanca **no responde con ratón, teclado ni gamepad
  en PC** (`drag_focused()` solo escucha `InputEventScreenDrag`). En Android el
  **arrastre táctil sí funciona** (verificado P → L1). Falta decidir la ruta de
  input de PC antes de la conducción.
- **H3 (→ F9.1):** el radio ejecuta la presión pero no muestra feedback visual
  (sin clave de feedback ni LED observable en cabina).
- La red de rutas se comprime a 1:20 y se muestrea cada **500 m**; las
  horquillas locales, el viario urbano y el terreno quedan para F4.2/F4.3.
- La DEM Terrarium z10 (~150 m/píxel) no resuelve puentes/túneles; se aplica
  limpieza de picos y suavizado. No es un DEM de precisión ni sirve para
  navegación.
- `budgets.runtime_load_budget_ms` (250 ms) está **pendiente de medición** en
  F4.2; no se declara cumplido.
- La alternativa de `route.merida_llanos` con mayor solapamiento (0,828) es un
  bucle paralelo real; se conserva para rodear bloqueos.
- Los 202 claves de contenido y las fuentes CJK/cirílicas siguen pendientes de
  F8.4.
- La biblioteca externa cambió con 3 vídeos nuevos del Esteem; la próxima
  revisión completa sigue siendo obligatoria antes de F4.3 o el 2026-12-06.
- No hay pérdida de agarre, daño, vadeo ni anti-atasco (F5.1); no hay
  conducción real (chasis `VehicleBody3D`: F5) ni terreno/streaming (F4.2).
- Las builds exportadas son debug de referencia, no versionadas, en
  `build/exports/`.

## Completado

- **Contrato `world.routes` v1** (`data/schemas/world_routes.json`) y JSON
  Schemas `world_routes` / `world_route_network`; regiones, proyección 1:20,
  extracción OSM, DEM, reglas de grafo, clases de vía, seis rutas, alternativas,
  caché, presupuestos, ODbL, anti-softlock y estados.
- **Pipeline `tools/osm/build_world_routes.py`**: Overpass con caché, grafo
  nacional (17.756 ways troncales/primarias + 9.638 secundarias), snap de hubs,
  Dijkstra, alternativas penalizadas, grafo comprimido, muestreo DEM por
  distancia, validación y escritura atómica. Modos `--refresh`, `--offline` y
  `--check`.
- **Artefacto `data/content/world/route_network.json`** (1.108.711 bytes) y
  **manifiesto** (2.111 bytes): 329 nodos, 413 aristas, 6 principales y 12
  alternativas; 4.751,7 km principales / 16.265,7 km con alternativas;
  elevación 2,9–3.459,6 m; pendiente máxima 18,9 % (< 30 %).
- **`src/world/route_network.gd`** (`RouteNetwork`, `RefCounted`, no autoload):
  carga y valida contrato/red/manifiesto, SHA-256, A*, alternativas, proyección,
  elevación y polilíneas 3D.
- **Prueba `tests/world/WorldRoutesTest.tscn`** + `tools/dev/world_routes_test.cmd`
  (**143/143**).
- **Validación compartida** `tools/osm/route_graph_validation.py` integrada en
  `tools/validate_schemas.py` y `health_check.py`; CI ejecuta la prueba de rutas.
- **Atribución ODbL**: `licenses/ODbL-1.0.txt`, aviso en `CREDITS.md`, pie de la
  web y clave `CREDITS_OSM` visible en Boot (11 idiomas).
- **`docs/architecture/WORLD_ROUTES.md`** y secciones nuevas en
  `DATA_CONTRACTS.md` y `SYSTEM_ARCHITECTURE.md`.
- Versión `0.4.0` en `VERSION`, `project.godot`, `export_presets.cfg`
  (`version/code=112`), `EXPECTED_VERSION` del smoke/lluvia/rutas, `PHASE` de
  Boot y `BOOT_KICKER` en once idiomas.

## Siguiente

Fase **4.2 con DS-R**: Terrain3D, streaming de sectores de 800 m, colisión,
carga asíncrona y PSS ≤ 1,2 GB (tag `v0.4.1`). No se inicia en este chat. El
prompt completo está en `docs/status/HANDOFF.md`.
