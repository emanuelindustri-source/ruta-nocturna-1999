# Handoff — Fase 5.1

## Estado de partida

La Fase 4 quedó cerrada y publicada (`v0.4.3`): Venezuela tiene red OSM/DEM,
454 sectores de 800 m con streaming, seis biomas con kits/POIs, agua/polvo/nieve
visuales, **clima real** con transiciones, humedad, rayos/truenos y **mapa de
papel**. H1 (gotas de cámara) quedó corregido.

> **Base para F5.1:** parte de `main` en el commit de cierre de F4.4 (tag
> `v0.4.3`). Los contratos cerrados siguen intactos: `world_routes` v1,
> `world_streaming` v1, `world.biomes` v1, `world.weather` v1 y
> `rain_surface_fx` v1.

- Web: https://emanuelindustri-source.github.io/ruta-nocturna-1999/
- Repositorio: https://github.com/emanuelindustri-source/ruta-nocturna-1999
- Versión: `v0.4.3` (Android `version/code=115`, Windows `0.4.3.0`)
- Contratos: 12 validados (los 10 de F1–F4.2 + `world.biomes` + `world.weather`).
- Pruebas: smoke **270**, tren **125**, cabina **46**, interacción **257**,
  lluvia **206**, rutas **143**, streaming **99**, biomas **276**, clima **242**,
  render **RENDER_OK**.
- PC: mundo **16,56 ms** medio (60,4 FPS), 16.923 primitivas, grafo 28 ms,
  8 sectores, 2 solicitudes, 0 síncronas.
- Redmi `obojropz89mbwgpn`: PSS mundo **688,9 MB**, 16.259 primitivas, frame
  **12,78 ms** (p95 18,23), 6 sectores, 13.476 triángulos de streaming, grafo
  **52 ms**, 2 solicitudes, 0 síncronas, 21/21 kits, 19 POIs.
- Nuevas piezas de F4.4:
  - `data/schemas/world_weather.json` + JSON Schema; `docs/architecture/WORLD_WEATHER.md`.
  - `src/core/weather_manager.gd` real, `src/weather/lightning_director.gd`,
    `weather_bridge.gd`, `windshield_mask.gd`, `src/world/paper_map.gd`.
  - `tests/weather/WeatherRegionsTest.tscn` + wrapper (**242/242**).
- H1 cerrado: gotas sobre la geometría del parabrisas; fill de cabina
  90,17 % → 6,44 %.

## Qué debe hacer F5.1

Alcance exclusivo de **DS-R** (tag `v0.5.0`), según `ROADMAP.md`:
**desgaste, reparaciones, combustible, anti-atasco, grúa, vadeo, hidrobloqueo y
retorno seguro**.

1. **Consumir F4.4, no rehacerla.** `WeatherManager` ya publica `rain`,
   `humidity`, `wind`, `temperature`, `wetness` y `wetness_target`; los modelos
   `SurfaceWetnessModel`, `PuddleModel` y `DropletFlowModel` siguen siendo la
   fuente de humedad/gotas/charcos. No cambies `world.weather` v1 ni
   `rain_surface_fx` v1 sin subir `schema_version` y documentar migración.
2. **Física de vadeo y agarre**: conectar `PuddleModel`/`specs.water` de
   `vehicle_components.json` a la pérdida de agarre, hidroplaneo, profundidad de
   vadeo, oleaje, entrada de agua y calado. La altura de admisión (0,68 m) y la
   profundidad segura (0,30 m) son datos verificables del contrato.
3. **Anti-atasco real**: volcadura, falta de tracción, fuera de mundo, agua
   profunda y daño crítico; recuperación incluso sin dinero ni herramientas;
   grúa/retorno con tiempo o deuda narrativa; reaparición validada sobre la red
   y con colisión (`WorldDirector.safe_respawn_point()` ya existe); guardado
   automático tras el rescate. Nunca una partida irrecuperable.
4. **Desgaste, reparaciones y combustible**: usar `vehicle_components.json`
   (herramientas, repuestos, síntomas, costos) e `inventory_tools.json`; no
   duplicar valores de balance en GDScript. El motor `seized` ya tiene API de
   reparación para QA.
5. **QA**: añadir prueba Godot específica (p. ej. `RecoveryTest`), ampliar la
   ruta ADB a vadeo/volcadura y medir PSS/triángulos/frame. No declarar
   optimizaciones sin medición.
6. **Presupuestos**: sin cambios (≤120.000 triángulos Android, PSS ≤1,2 GB,
   60 FPS objetivo, ≥30 en Android baja/TV). La lluvia y el clima ya están
   medidos; el coste nuevo es de física y VFX.

Reglas:

- No rehacer F1–F4.4. Los contratos cerrados solo cambian de valor con nota de
  fuente; los cambios de estructura exigen `schema_version` y migración.
- No crear autoloads nuevos. `WeatherManager` sigue siendo el único de clima;
  los directores de mundo/entidades son servicios de escena.
- No corregir H4 (retrato/letterbox → F9.1/F10.2), H5 (pico de construcción →
  F10.1), H12/H14 (afinado de cabina → F5.1/F9.1) ni H2 gamepad/teclado
  (→ F5.1/F9.1) fuera del alcance de física/anti-atasco.
- Mantener la atribución ODbL visible y el texto de licencia en el build.
- El mapa de papel es presentación de la red existente; no añadir datos OSM.
- **Revisión visual completa obligatoria de referencias antes de F5.1** (manual,
  motor, herramientas, vadeo y fotos reales) o el **2026-12-08**. Registrar el
  uso en `REFERENCE_USAGE_LOG.md` y no copiar archivos.

Al iniciar:

  python tools/health_check.py --start
  python tools/scan_reference_library.py --quick

## Prompt para el siguiente chat

```text
[RN1999 · Subfase 5.1]
CWD: C:\Dev\RutaNocturna1999
Modelo asignado: DS-R (opencode-go/deepseek-v4.1-flash#max)

Lee completos:
- AGENTS.md
- ROADMAP.md
- docs/status/CURRENT.md
- docs/status/HANDOFF.md
- docs/architecture/SYSTEM_ARCHITECTURE.md
- docs/architecture/DATA_CONTRACTS.md
- docs/architecture/WORLD_WEATHER.md
- docs/architecture/RAIN_AND_SURFACE_FX.md
- docs/reference/ESTEEM_MECHANICAL_NOTES.md

Ejecuta únicamente la Subfase 5.1 (tag v0.5.0): desgaste, reparaciones,
combustible, anti-atasco, grúa, vadeo, hidrobloqueo y retorno seguro.
Consume el mundo, el clima, la humedad, los charcos y los contratos de F4.4.
No rehagas F1–F4.4, no cambies contratos cerrados y no avances a F5.2.

La Fase 4.4 ya cerró:
- v0.4.3: contrato world.weather v1, WeatherManager real, rayos/truenos
  procedurales, H1 corregido (gotas en el parabrisas) y mapa de papel
  norte-arriba con silueta y leyenda.
- Tests: smoke 270, tren 125, cabina 46, interacción 257, lluvia 206,
  rutas 143, streaming 99, biomas 276, clima 242, render RENDER_OK.
- PC: mundo 60,4 FPS, 16.923 primitivas, grafo 28 ms.
- Redmi: PSS mundo 688,9 MB, 16.259 primitivas, frame 12,78 ms, grafo 52 ms,
  6 sectores, 2 solicitudes, 0 carga síncrona, 21/21 kits, 19 POIs.
- Hallazgos abiertos: H4 retrato/letterbox → F9.1/F10.2; H5 pico de
  construcción de sector → F10.1; H12/H14 afinado de cabina → F5.1/F9.1.

Antes de implementar, haz la revisión visual completa de referencias (manual,
motor, herramientas, vadeo y fotos reales) y regístrala.

Al iniciar:
  python tools/health_check.py --start
  python tools/scan_reference_library.py --quick

Revisa solo las referencias relevantes y registra su uso en
docs/reference/REFERENCE_USAGE_LOG.md. No copies archivos de
C:\Dev\fotos de ejemplo al repositorio. Respeta presupuestos, contratos,
licencias (ODbL) y el anti-softlock.

Al cerrar: valida esquemas, localización, manifiestos, roadmap y presets;
importa en Godot headless; ejecuta smoke, tren motriz, cabina, interacción,
lluvia, rutas, streaming, biomas, clima y render; prueba el juego en PC y en el
Redmi con capturas; mide PSS/triángulos/carga; comprueba espacio;
health_check --end; actualiza ROADMAP, docs/roadmap-data.json, CHANGELOG,
CURRENT y HANDOFF; commit, tag v0.5.0 y push solo si todo pasa; entrega el
prompt de F5.2 con DS-R.

No avances a la Fase 5.2.
```

## Recordatorios

- La revisión visual completa de referencias es obligatoria antes de F5.1/F5.3
  (o el **2026-12-08**); la biblioteca externa sigue fuera del repositorio.
- La ExecutionPolicy de PowerShell está restringida: usar wrappers `.cmd`.
- El export se hace con `tools\dev\export.cmd`; los binarios van a `build/` y
  nunca a Git. `licenses/*.txt`, `CREDITS.md`, los sectores y los kits viajan
  en el build.
- Al cambiar `EXPECTED_VERSION`, actualizar `VERSION`, `project.godot`,
  `export_presets.cfg` (`version/name` y `version/code`) y `PHASE` de `Boot.gd`;
  las pruebas de rutas, lluvia, streaming, biomas, clima y el smoke tienen su
  `EXPECTED_VERSION`.
- La red y los sectores son ODbL 1.0: conservar atribución, licencia y
  share-alike. No editar `route_network.json` ni los `.res` a mano.
- El warm-up de shaders debe seguir ejecutándose antes del gameplay.
- No se sube ningún token, keystore, APK o AAB a Git.
- `WeatherManager` no conoce `AudioDirector`; los rayos se consumen por
  `EventBus.weather_lightning` y el trueno lo sintetiza `LightningDirector`.
- El mapa de papel usa solo la red de F4.1 y una silueta esquemática propia; no
  añadir datos OSM ni usarlo para navegación.
- La pérdida de agarre, el vadeo, el hidrobloqueo y el anti-atasco son F5.1; el
  clima y la humedad ya están disponibles desde F4.4.

## Seguridad

El inicio de sesión usado para publicar debe rotarse o revocarse después de la
publicación si el token fue compartido por un canal no seguro. La configuración
local de Git no contiene el token.
