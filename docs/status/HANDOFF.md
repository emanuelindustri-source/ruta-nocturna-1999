# Handoff — Fase 4.4

## Estado de partida

La Fase 4.3 quedó cerrada y publicada (`v0.4.2`): el mundo de F4.2 ahora tiene
**seis biomas**, **kits de POIs y mobiliario vial** (gasolineras, moteles,
peajes, cruces, señalización, postes, vallas), **agua/polvo/nieve visuales** y
todo integrado con el streaming asíncrono sin romper sus invariantes.

> **Base para F4.4:** parte de `main` en el commit de cierre de F4.3 (tag
> `v0.4.2`). Los contratos `world_routes` v1 y `world_streaming` v1 siguen
> **sin cambios**; el contrato nuevo es `world.biomes` v1, aditivo.

- Web: https://emanuelindustri-source.github.io/ruta-nocturna-1999/
- Repositorio: https://github.com/emanuelindustri-source/ruta-nocturna-1999
- Versión: `v0.4.2` (Android `version/code=114`, Windows `0.4.2.0`)
- Contratos: los diez de F1–F4.2 + `world.biomes` v1 (11 en total, validados).
- Nuevas piezas de F4.3:
  - `data/schemas/world_biomes.json` + JSON Schema; `data/world/kits_spec.json`.
  - `tools/blender/world_kits.py` (7 familias bpy con LOD0/1/2 + manifiestos);
    `assets/generated/world/kit_*.glb` (28 GLB).
  - `src/world/world_kit_library.gd`, `biome_decor_builder.gd`, `poi_manager.gd`;
    `shaders/world_water.gdshader`.
  - `tests/world/WorldBiomesTest.tscn` + wrapper (**276/276**).
  - `docs/architecture/WORLD_BIOMES.md`.
- Pruebas (todas exit 0): smoke **270**, tren **125**, cabina **46**,
  interacción **257**, lluvia **206**, rutas **143**, streaming **99**,
  biomas **276**, render **RENDER_OK**.
- ADB completo en el Redmi `obojropz89mbwgpn`: arranque **1 s**; PSS
  **525,4/650,4/669,3 MB** (rebanada/cabina/mundo); mundo frame **9,14 ms**
  medio y **12.894 primitivas**; 7 sectores, 4.272 tris de decorado; grafo
  **71 ms**; 2 solicitudes; 0 síncronas; 0 errores; 21/21 kits; 19 POIs.
- PC (build exportado): mundo **16,57 ms** medio (60,3 FPS), 16.582 primitivas,
  8 sectores, grafo 42 ms; capturas `f43_pc_*`; informe
  `build/logs/gameplay/REPORT_F43.md`.
- Arreglos de cabina incluidos (autorización del director): volante completo
  (H7), clics por posición (H8), palanca con ratón (H2-PC), salida con `Esc`
  (H13), radio visible (H10), testigos reubicados (H11) y deduplicación del
  streamer de F4.2.

## Qué debe hacer F4.4

Alcance exclusivo de **DS-S** (tag `v0.4.3`), según `ROADMAP.md`:
**WeatherManager, transiciones, rayos/truenos, humedad, QA de regiones/clima y
mapa de papel**.

1. **Consumir F4.3, no rehacerla.** `WorldDirector`, `WorldKitLibrary`,
   `PoiManager` y los presets `water`/`dust`/`snow` de `world.biomes` son la
   entrada de datos del clima. No cambiar `world_routes` v1, `world_streaming`
   v1 ni `world.biomes` v1 sin subir `schema_version` y documentar migración.
2. **WeatherManager real**: conectar el autoload (ya existe en F1.2 como servicio
   de clima) al estado del mundo: presets por bioma, transiciones suaves,
   humedad, temperatura ambiente y viento; publicar por `EventBus` sin romper
   las reglas de dependencias (AudioDirector y WeatherManager no se referencian).
3. **H1 (aprobado por el director):** recortar la máscara de gotas de cámara al
   parabrisas en coordinación con la lluvia real; hoy las gotas cubren toda la
   pantalla y caen «dentro» de la cabina (ver `REPORT_F43.md`).
4. **Rayos/truenos**: VFX + audio procedimental consumiendo el estado de
   tormenta (el efecto visual de tormenta del panel QA ya funciona como demo).
5. **QA de regiones/clima**: prueba por bioma/región con las seis regiones,
   transiciones y humedad; ampliar `WorldBiomesTest` o crear
   `tests/weather/WeatherRegionsTest`.
6. **Mapa de papel**: presentación del mapa con la red de rutas (uso de la red
   comprimida existente; sin datos nuevos de OSM).
7. **Presupuestos**: sin cambios (≤120.000 triángulos Android, PSS ≤1,2 GB,
   60 FPS objetivo, ≥30 en Android baja/TV); el presupuesto de lluvia está en
   `rain_surface_fx.json` (`budgets.*`).

Reglas:

- No rehacer F1–F4.3. Los contratos cerrados solo cambian de valor con nota de
  fuente (mecanismo ya usado en F4.3).
- No crear autoloads nuevos: `WeatherManager` ya existe; `WorldDirector` sigue
  siendo servicio de escena.
- No corregir H4 (retrato/letterbox → F9.1/F10.2), H5 (pico de construcción →
  F10.1), H12/H14 (afinado de cabina → F5.1/F9.1) ni H2 gamepad/teclado
  (→ F5.1/F9.1).
- La lluvia/humedad real es de este alcance; la pérdida de agarre, el vadeo y
  el anti-atasco siguen siendo F5.1 (no adelantar física).
- Mantener la atribución ODbL visible y el texto de licencia en el build.
- No versionar respuestas OSM, teselas DEM, cachés ni binarios de build.

Al iniciar:

  python tools/health_check.py --start
  python tools/scan_reference_library.py --quick

## Prompt para el siguiente chat

```text
[RN1999 · Subfase 4.4]
CWD: C:\Dev\RutaNocturna1999
Modelo asignado: DS-S (opencode-go/deepseek-v4.1-flash#low)

Lee completos:
- AGENTS.md
- ROADMAP.md
- docs/status/CURRENT.md
- docs/status/HANDOFF.md
- docs/architecture/SYSTEM_ARCHITECTURE.md
- docs/architecture/DATA_CONTRACTS.md
- docs/architecture/RAIN_AND_SURFACE_FX.md
- docs/architecture/WORLD_BIOMES.md
- docs/architecture/WORLD_STREAMING.md

Ejecuta únicamente la Subfase 4.4 (tag v0.4.3): WeatherManager real con
transiciones, rayos/truenos, humedad, QA de regiones/clima y mapa de papel.
Consume el mundo, los seis biomas, los presets agua/polvo/nieve y los
contratos de F4.3. No rehagas F1–F4.3, no cambies contratos cerrados y no
avances a F5.

La Fase 4.3 ya cerró:
- v0.4.2: contrato world.biomes v1, 7 familias de kits (LOD0/1/2), 8 props
  procedurales, POIs (gasolineras, moteles, peajes, cruces), mobiliario vial,
  agua/polvo/nieve visuales y streaming intacto (2 solicitudes, 0 síncronas).
- Tests: smoke 270, tren 125, cabina 46, interacción 257, lluvia 206,
  rutas 143, streaming 99, biomas 276, render RENDER_OK.
- PC: mundo 60,3 FPS, 16.582 primitivas, grafo 42 ms.
- Redmi: PSS mundo 669,3 MB, 12.894 primitivas, frame 9,14 ms, grafo 71 ms,
  7 sectores, 2 solicitudes, 0 carga síncrona, 21/21 kits, 19 POIs.
- Aprobado por el director: arreglar H1 (gotas de cámara) en esta fase,
  recortando la máscara al parabrisas junto a la lluvia real.
- Hallazgos abiertos: H4 retrato/letterbox → F9.1/F10.2; H5 pico de
  construcción de sector → F10.1; H12/H14 afinado de cabina → F5.1/F9.1.

Al iniciar:
  python tools/health_check.py --start
  python tools/scan_reference_library.py --quick

Revisa solo las referencias relevantes (clima, lluvia, mapas, atmósferas) y
registra su uso en docs/reference/REFERENCE_USAGE_LOG.md. No copies archivos de
C:\Dev\fotos de ejemplo al repositorio. Respeta presupuestos, contratos,
licencias (ODbL) y el anti-softlock.

Al cerrar: valida esquemas, localización, manifiestos, roadmap y presets;
importa en Godot headless; ejecuta smoke, tren motriz, cabina, interacción,
lluvia, rutas, streaming, biomas y render; prueba el juego en PC y en el Redmi
con capturas; mide PSS/triángulos/carga; comprueba espacio; health_check --end;
actualiza ROADMAP, docs/roadmap-data.json, CHANGELOG, CURRENT y HANDOFF; commit,
tag v0.4.3 y push solo si todo pasa; entrega el prompt de F4.5 con DS-R.

No avances a la Fase 5.
```

## Recordatorios

- La revisión visual completa de referencias es obligatoria antes de F5.1/F5.3
  (o el **2026-12-08**); la biblioteca externa sigue fuera del repositorio.
- La ExecutionPolicy de PowerShell está restringida: usar wrappers `.cmd`.
- El export se hace con `tools\dev\export.cmd`; los binarios van a `build/` y
  nunca a Git. `licenses/*.txt`, `CREDITS.md`, los sectores y los kits viajan
  en el build.
- Los presupuestos móviles siguen vigentes: ≤120.000 triángulos visibles
  (incluidos los tres viewports de espejo), RAM ≤1,2 GB PSS.
- Al cambiar `EXPECTED_VERSION`, actualizar `VERSION`, `project.godot`,
  `export_presets.cfg` (`version/name` y `version/code`) y `PHASE` de `Boot.gd`;
  las pruebas de rutas, lluvia, streaming, biomas y el smoke tienen su
  `EXPECTED_VERSION`.
- La red y los sectores son ODbL 1.0: conservar atribución, licencia y
  share-alike. No editar `route_network.json` ni los `.res` a mano.
- El warm-up de shaders debe seguir ejecutándose antes del gameplay.
- No se sube ningún token, keystore, APK o AAB a Git.
- La pérdida de agarre, el vadeo y el anti-atasco son F5.1; el mapa de papel es
  de F4.4 pero solo como presentación de la red existente (sin nuevos datos OSM).
- Los contratos de F4.3 (`world.biomes`, `kits_spec`) son la fuente de datos de
  clima superficial: `surface_presets.water/dust/snow` ya declaran los enlaces
  `weather_link` y `vadeo` para F4.4/F5.1.

## Seguridad

El inicio de sesión usado para publicar debe rotarse o revocarse después de la
publicación si el token fue compartido por un canal no seguro. La configuración
local de Git no contiene el token.
