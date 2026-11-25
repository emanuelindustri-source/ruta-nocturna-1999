# Estado actual

**Subfase:** 4.3 — Kits de biomas, gasolineras, moteles, peajes, señalización, agua, polvo y nieve
**Versión:** `v0.4.2`
**Modelo de la subfase:** MiMo Pro (`opencode-go/mimo-v2.6-pro`)
**Fecha:** 2026-11-24
**Estado:** completada; commit y tag `v0.4.2` en este cierre.

## Enlaces

- Web: https://emanuelindustri-source.github.io/ruta-nocturna-1999/
- Repositorio: https://github.com/emanuelindustri-source/ruta-nocturna-1999
- Acciones: https://github.com/emanuelindustri-source/ruta-nocturna-1999/actions

## Validación ejecutada

| Prueba | Resultado |
|---|---|
| Contratos JSON + Schemas | **11 contratos válidos**, 0 errores, 1 advertencia conocida (202 claves → F8.4); nuevo `world.biomes` v1 con validaciones cruzadas (regiones, LODs, presupuestos, despejes, ODbL) |
| Assets generados | **11 manifiestos válidos** (4 vehículo + 7 kits de F4.3); kits con LOD0/1/2 estrictamente decrecientes y hashes reproducibles |
| Localización | 11 idiomas, 0 errores; 26 claves nuevas (`BIOME_*`, `POI_*`, `ROAD_*`); `BOOT_KICKER` Fase 4.3 y `SLICE_TITLE` v0.4.2 |
| Low/high de altura de sector | −15,8 / 201,7 m (sin cambios; sectores de F4.2 intactos: 454 recursos, 4.671.964 bytes) |
| Roadmap | `ROADMAP.md` + `docs/roadmap-data.json` sincronizados (**16/45 completadas, 35,6 %**) |
| Smoke test | **270/270**, exit 0 (versión 0.4.2) |
| Tren motriz | **125/125**, exit 0 |
| Cabina y rig | **46/46**, exit 0 |
| Interacción contextual | **257/257**, exit 0 |
| Prueba de lluvia | **206/206**, exit 0 |
| Red de rutas (Godot) | **143/143**, exit 0 |
| Terreno y streaming (Godot) | **99/99**, exit 0 (F4.2 intacta tras la corrección del streamer) |
| **Biomas y POIs (Godot, nueva)** | **276/276**, exit 0 (`tools/dev/world_biomes_test.cmd`) |
| Godot import headless | exit 0; sin `SCRIPT ERROR`/`Parse Error`/`Failed to load` |
| Prueba de render real | **RENDER_OK** (Vulkan Forward+, ventana 1280×720) |
| Build Windows exportada | `build/exports/windows/RutaNocturna1999.exe`, 103.070.208 bytes, SHA-256 `37D8F6C5…540011`; ejecutada sin errores |
| APK Android | 33.452.542 bytes, SHA-256 `98F9CCB1…70461`; `versionName=0.4.2`, `versionCode=114` |
| Prueba ADB completa en el Redmi | **superada**: install Success, arranque **1 s**, logcat sin `FATAL EXCEPTION`, ruta `slice,cabin,world` con `done=true` y `errors: []` |
| Presupuestos en dispositivo | PSS **525,4 / 650,4 / 669,3 MB** (rebanada/cabina/mundo) ≤ 1.228,8; mundo **12.894 primitivas** ≤ 120.000; frame **9,14 ms** medio (p95 16,37), 0 jank >100 ms |
| Streaming en dispositivo | **7 sectores**, 15.661 triángulos + **4.272 decorado** (≤ 7×622); grafo **71 ms** ≤ 250; **2** solicitudes máximas; **0** `load()` síncrono; **0** errores |
| Kits y POIs en dispositivo | **21/21 kits** GLB cargados (0 errores, 2 solicitudes máx., 0 síncronas); **19 POIs** por ruta (4 gasolineras, 3 moteles, 5 peajes, 7 cruces) |
| Carga en dispositivo | Mundo **3.734 ms** ≤ 20.000; rebanada 9.220 ms; cabina 4.749 ms (presupuesto QA 15.000) |
| Prueba de juego en PC (build exportado) | Boot `v0.4.2 · Fase 4.3` 11/11 + ODbL; mundo con bioma en overlay, 60 FPS, POIs y mobiliario visibles; capturas `f43_pc_*`; informe `build/logs/gameplay/REPORT_F43.md` |
| Rendimiento PC | Mundo **16,57 ms** medio (60,3 FPS), p95 17,09, máx 27,64; **16.582 primitivas**; 8 sectores; 4.867 triángulos de decorado (≤ 8×622); grafo 42 ms; 2 solicitudes; 0 síncronas |
| Prueba manual Android | Cabina en el Redmi con **volante completo** y radio visibles (arreglos confirmados en dispositivo); capturas `build/logs/android-smoke/screenshot_*.png` |
| Espacio libre | **76,4 GB** en `C:` (mínimo 20 GB) |
| Dispositivo ADB | Redmi 22101316G autorizado (`obojropz89mbwgpn`) |
| Git | Rama `main`, tag `v0.4.2` y push de este cierre; CI de la rama en verde |

Advertencias conocidas:

- **H1 (→ F4.4):** las gotas de cámara cubren toda la pantalla y parecen caer
  dentro del habitáculo (visibles también mirando hacia la puerta). Aprobado por
  el director su arreglo en **F4.4** junto a la máscara de parabrisas y el clima.
- **H4 (→ F9.1/F10.2):** el juego corre en retrato en el Redmi con bandas
  negras (letterbox). Preexistente (`window/handheld/orientation=1`); no afecta
  a los presupuestos ni al toque.
- **H5 (→ F10.1):** la construcción de sector con decorado sube a 22,7 ms (PC)
  y 49,1 ms (Android, un frame suelto de 34,89 ms); sin jank >100 ms y con
  frame medio de 9,14 ms, pero es candidata a optimización de refilón.
- **H12 (→ F5.1/F9.1):** la palanca y el freno de mano se ven desproporcionados
  (proxies cercanos a la cámara); requiere ajuste visual junto al asiento/cámara.
- **H14 (→ F9.1):** las manos en reposo flotan un poco entre los radios bajos
  (posiciones `hand_*_grip` de `cabin_spec`).
- H3 (→ F9.1): la radio ya muestra su LED de encendido (mitigado), pero el
  feedback completo (banda/emisora en pantalla) es de F9.1.
- La red comprimida puede solapar vías cercanas; los cruces a distinto nivel
  siguen sin estructura (F4.1 conocido).
- Los 202 claves de contenido y las fuentes CJK/cirílicas siguen pendientes de
  F8.4.
- Las builds exportadas son debug de referencia, no versionadas, en
  `build/exports/`.

## Completado

- **Contrato `world.biomes` v1** (`data/schemas/world_biomes.json` + JSON
  Schema): seis biomas, ocho props procedurales, siete familias de POI/mobiliario,
  presets agua/polvo/nieve, presupuestos (3.000 tris/sector), colocación
  determinista, atribución ODbL y anti-softlock. Aditivo: `world_routes` v1 y
  `world_streaming` v1 intactos.
- **Kits bpy** (`tools/blender/world_kits.py` + `data/world/kits_spec.json`):
  gasolinera, motel, peaje, cruce, señal, poste y valla — cada uno con
  LOD0/LOD1/LOD2 + ancla `anchor_root`, materiales PBR propios, sin marcas
  reales y sin texto en las mallas. 28 GLB + 7 manifiestos reproducibles.
- **Runtime**: `WorldKitLibrary` (carga threaded de kits: máx. 2 solicitudes, 0
  `load()` síncrono, antes de la ventana de sectores), `BiomeDecorBuilder`
  (props procedurales con tres LODs validados), `PoiManager` (POIs por intervalo
  determinista con `visibility_range` y colisión) y `build_sector_decor`
  (mobiliario + vegetación MultiMesh + agua con presupuesto de 620 tris/sector).
- **Presets de superficie**: `shaders/world_water.gdshader`, nieve de altura
  (montaña) y tinte de polvo (llanos/industrial/costa). Visuales: clima real →
  F4.4; física (vadeo/agarre) → F5.1.
- **Prueba `WorldBiomesTest`** (270+6 comprobaciones) con auditoría de decorado
  por sector, POIs fuera de la vía, agua, nieve y carga threaded de kits;
  integrada en `health_check.py` y en la CI.
- **Arreglos autorizados por el director** (diagnóstico jugando el build real):
  volante enterrado por el salpicadero (H7), radio invisible (H10), clics de
  ratón sin resolver por posición (H8), palanca inerte al ratón (H2 PC),
  cabina sin salida por `Esc` (H13, nuevo) y testigos mal ubicados (H11).
- **Corrección del streamer (F4.2):** deduplicación de sectores en cola/ready
  (evitaba doble construcción y fuga de nodos).
- **Localización**: 26 claves nuevas en once idiomas; fase y versión actualizadas.
- **Documentación**: `docs/architecture/WORLD_BIOMES.md` y secciones en
  `DATA_CONTRACTS.md`, `SYSTEM_ARCHITECTURE.md`, `WORLD_STREAMING.md`,
  `BUILD_AND_RELEASE.md` y `CREDITS.md`.
- **Referencias**: revisión visual completa obligatoria (98 archivos, 3 vídeos
  del Esteem con fotogramas extraídos, conceptos de paisajes/biomas) registrada
  en `REFERENCE_USAGE_LOG.md`; ninguna imagen copiada al repositorio.

## Siguiente

Fase **4.4 con DS-S** (`opencode-go/deepseek-v4.1-flash#low`):
WeatherManager, transiciones, rayos/truenos, humedad, QA de regiones/clima y
mapa de papel (tag `v0.4.3`). No se inicia en este chat. El prompt completo está
en `docs/status/HANDOFF.md`.
