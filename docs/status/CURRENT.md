# Estado actual

**Subfase:** 4.4 — WeatherManager real, transiciones, rayos/truenos, humedad, QA de regiones y mapa de papel
**Versión:** `v0.4.3`
**Modelo de la subfase:** DS-S (`opencode-go/deepseek-v4.1-flash#low`)
**Fecha:** 2026-11-25
**Estado:** completada; commit y tag `v0.4.3` en este cierre.

## Enlaces

- Web: https://emanuelindustri-source.github.io/ruta-nocturna-1999/
- Repositorio: https://github.com/emanuelindustri-source/ruta-nocturna-1999
- Acciones: https://github.com/emanuelindustri-source/ruta-nocturna-1999/actions

## Validación ejecutada

| Prueba | Resultado |
|---|---|
| Contratos JSON + Schemas | **12 contratos válidos**, 0 errores, 1 advertencia conocida (202 claves → F8.4); nuevo `world.weather` v1 con validaciones cruzadas (biomas, presets, pesos, humedad, lluvia mm/h, rayos, máscara y localización) |
| Assets generados | **11 manifiestos válidos** (sin cambios de F4.3) |
| Localización | 11 idiomas, 0 errores; **18 claves nuevas** (`WEATHER_PRESET_*`, `WORLD_WEATHER_LINE`, `WORLD_MAP_*`, `MAP_*`); `BOOT_KICKER` Fase 4.4 y `SLICE_TITLE` v0.4.3 |
| Roadmap | `ROADMAP.md` + `docs/roadmap-data.json` sincronizados (**17/45 completadas, 37,8 %**) |
| Smoke test | **270/270**, exit 0 (versión 0.4.3) |
| Tren motriz | **125/125**, exit 0 |
| Cabina y rig | **46/46**, exit 0 |
| Interacción contextual | **257/257**, exit 0 |
| Prueba de lluvia | **206/206**, exit 0 |
| Red de rutas (Godot) | **143/143**, exit 0 |
| Terreno y streaming (Godot) | **99/99**, exit 0 (sin cambios de F4.2) |
| Biomas y POIs (Godot) | **276/276**, exit 0 (sin cambios de F4.3) |
| **Clima, regiones y mapa (Godot, nueva)** | **242/242**, exit 0 (`tools/dev/weather_regions_test.cmd`) |
| Godot import headless | exit 0; sin `SCRIPT ERROR`/`Parse Error`/`Failed to load` |
| Prueba de render real | **RENDER_OK** (Vulkan Forward+, ventana 1280×720) |
| Build Windows exportada | `build/exports/windows/RutaNocturna1999.exe`, 103.070.208 bytes, SHA-256 `19C4B07A…0F965B`; ejecutada sin errores |
| APK Android | **33.502.554 bytes**, SHA-256 `EC974799…84161`; `versionName=0.4.3`, `versionCode=115` |
| Prueba ADB completa en el Redmi | **superada**: install Success, arranque **1,3 s**, logcat sin `FATAL EXCEPTION`, ruta `slice,cabin,world` con `done=true` y `fatal_patterns=[]` |
| Presupuestos en dispositivo | PSS **543,5 / 636,6 / 688,9 MB** (rebanada/cabina/mundo) ≤ 1.228,8; mundo **16.259 primitivas** ≤ 120.000; frame **12,78 ms** medio (p95 18,23), 0 jank >100 ms |
| Streaming en dispositivo | **6 sectores**, **13.476 triángulos** de streaming + 3.654 de decorado; grafo **52 ms** ≤ 250; **2** solicitudes máximas; **0** `load()` síncrono; **0** errores; 21/21 kits; 19 POIs |
| Carga en dispositivo | Mundo **5.177 ms** ≤ 20.000; rebanada 9.273 ms; cabina 5.555 ms (presupuesto QA 15.000) |
| Mapa de papel en dispositivo | **413 aristas**, **6 rutas**, **6 hubs**, **58 puntos** de silueta; atribución ODbL presente; `open=false` en la sonda |
| Prueba de juego en PC (build exportado) | Mundo con clima y bioma en overlay, 60 FPS; mapa norte-arriba con silueta, leyenda y rosa de los vientos; cabina con gotas solo en el parabrisas; rayo con destello y trueno; capturas `f44_*`; informe `build/logs/gameplay/REPORT_F44.md` |
| Rendimiento PC | Mundo **16,56 ms** medio (60,4 FPS), p95 17,17, máx 43,15; **16.923 primitivas**; 8 sectores; 4.867 triángulos de decorado; grafo **28 ms**; 2 solicitudes; 0 síncronas |
| Render H1 | Fill de fragmentos de cabina **90,17 % → 6,44 %**; fill visual **0,25 %**; +1,5 draw calls |
| Espacio libre | **70,86 GB** en `C:` (mínimo 20 GB) |
| Dispositivo ADB | Redmi 22101316G autorizado (`obojropz89mbwgpn`) |
| Git | Rama `main`, tag `v0.4.3` y push de este cierre; CI de la rama en verde |

Advertencias conocidas:

- **H1 (cerrado en F4.4):** las gotas de cámara ya no cubren la pantalla; viven en
  la malla del parabrisas y el salpicadero las ocluye. El caso «mirando a la
  puerta» quedó verificado en PC (`f44_pc_qa_cabin.png`).
- **H4 (→ F9.1/F10.2):** el juego corre en retrato en el Redmi con bandas negras
  (letterbox). Preexistente (`window/handheld/orientation=1`); no afecta a los
  presupuestos ni al toque.
- **H5 (→ F10.1):** la construcción de sector sube a **20,06 ms** (PC) y
  **46,28 ms** (Android, frames sueltos por encima de 33 ms); no hay jank >100 ms
  y el frame medio es 12,78 ms, pero sigue siendo candidata a optimización.
- **H12/H14 (→ F5.1/F9.1):** palanca/freno de mano desproporcionados y manos en
  reposo flotando entre los radios; requieren ajuste visual junto al asiento.
- H3 (→ F9.1): la radio ya muestra su LED de encendido (mitigado); el feedback
  completo (banda/emisora en pantalla) es de F9.1.
- La red comprimida puede solapar vías cercanas; los cruces a distinto nivel
  siguen sin estructura (F4.1 conocido).
- El mapa de papel es una **presentación esquemática**: la silueta de Venezuela
  es un contorno propio de ~58 puntos para dar contexto, no un límite oficial ni
  una base para navegación.
- Los 202 claves de contenido y las fuentes CJK/cirílicas siguen pendientes de
  F8.4.
- Las builds exportadas son debug de referencia, no versionadas, en
  `build/exports/`.

## Completado

- **Contrato `world.weather` v1** (`data/schemas/world_weather.json` + JSON
  Schema): nueve presets, seis perfiles de bioma/región, transiciones, humedad,
  rayos/truenos, máscara de parabrisas, presupuestos, atribución ODbL y QA.
  Aditivo: no modifica `world.biomes`, `world_routes`, `world_streaming` ni
  `rain_surface_fx`.
- **`WeatherManager` real**: consumo de `region_biome_map` y de los presets de
  F4.3, selección ponderada determinista, autoavance 45–120 s, humedad de
  superficie, temperatura, viento y rayos solo en tormenta con tope por minuto.
- **`LightningDirector`**: destello de luz, flash de pantalla accesible, rayo
  visible procedural (cinta + ramas) y **trueno sintetizado en runtime** (PCM 16
  bits, sin samples) con retardo por distancia.
- **`WeatherBridge`**: lluvia/humedad/viento/temperatura reales hacia
  `RainFxController`; conserva el lookdev de F3.4 hasta que el clima cambia.
- **`PaperMap`**: red de F4.1 norte-arriba, silueta esquemática de Venezuela,
  rutas, hubs, ruta activa, leyenda, rosa de los vientos y atribución ODbL.
  Sin datos OSM nuevos ni `load()` en runtime; se abre con `M` o el botón.
- **H1 corregido**: malla de gotas sobre las cuatro esquinas reales del
  parabrisas con `depth_test`; el salpicadero, el volante y los pilares la
  ocluyen. El shader conserva la máscara de pantalla como respaldo.
- **Prueba `WeatherRegionsTest`** (242 comprobaciones) de contrato, seis
  regiones, transiciones, humedad, rayos/truenos, H1, orientación del mapa,
  silueta, localización y presupuestos.
- **Documentación**: `docs/architecture/WORLD_WEATHER.md` y secciones en
  `DATA_CONTRACTS.md`, `SYSTEM_ARCHITECTURE.md`, `RAIN_AND_SURFACE_FX.md`,
  `WORLD_BIOMES.md`, `EVENT_BUS.md` y `README.md`.
- **Referencias**: revisión de clima, lluvia, atmósferas y mapas en las hojas de
  contacto y catálogo; registrada en `REFERENCE_USAGE_LOG.md` sin copiar archivos.

## Siguiente

Fase **5.1 con DS-R** (`opencode-go/deepseek-v4.1-flash#max`):
desgaste, reparaciones, combustible, anti-atasco, grúa, vadeo, hidrobloqueo y
retorno seguro (tag `v0.5.0`). No se inicia en este chat. El prompt completo está
en `docs/status/HANDOFF.md`.
