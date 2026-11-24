# Handoff — Fase 4.3

## Estado de partida

La Fase 4.2 quedó cerrada y publicada (`v0.4.1`): la red OSM/DEM de F4.1 ya se
convierte en terreno de presentación con **454 sectores de 800 m**, vía, colisión
y streaming asíncrono. El mundo se puede abrir desde Boot («Ver mundo»), recorre
las seis rutas con un coche de presentación y respeta los presupuestos móviles.

> **Base para F4.3:** parte de `main` en el commit de cierre de F4.2 (tag
> `v0.4.1`). El artefacto de rutas y el contrato `world_routes` v1 **no
> cambiaron**; el streaming vive en el contrato aditivo `world.streaming` v1.

- Web: https://emanuelindustri-source.github.io/ruta-nocturna-1999/
- Repositorio: https://github.com/emanuelindustri-source/ruta-nocturna-1999
- Versión: `v0.4.1` (Android `version/code=113`, Windows `0.4.1.0`)
- Contratos existentes: los ocho de F1–F3.5 + `world_routes` v1 + `world_streaming`
  v1, **sin cambios** en los cerrados.
- Nuevas piezas de F4.2:
  - `data/schemas/world_streaming.json` y su JSON Schema.
  - `data/content/world/sectors/*.res` (454) y `sectors.manifest.json`
    (4.671.964 bytes; 929.792 triángulos de terreno, 30.644 de vía).
  - `tools/world/bake_world_sectors.gd`,
    `tools/world/validate_world_sectors.py`, `tools/dev/bake_world_sectors.cmd`.
  - `src/world/world_sector_data.gd`, `world_sector_builder.gd`,
    `sector_streamer.gd` y `world_director.gd` (`WorldDirector`, no autoload).
  - `scenes/world/WorldTerrain.tscn`.
  - `tests/world/WorldStreamingTest.tscn` + wrapper (**99/99**).
  - `docs/architecture/WORLD_STREAMING.md`.
- Pruebas (todas exit 0): smoke **270**, tren **125**, cabina **46**,
  interacción **257**, lluvia **206**, rutas **143**, streaming **99**, render
  **RENDER_OK**.
- ADB completo en el Redmi `obojropz89mbwgpn`: **exit 0**; PSS
  404,4/509,6/646,0/630,5 MB (boot/rebanada/cabina/mundo); mundo frame
  **8,52 ms** medio y **18.802 primitivas**; 7 sectores y 24.147 triángulos;
  grafo **76 ms**; 2 solicitudes; 0 síncronas; 0 errores.
- PC: build Windows ejecutada; mundo con **16,66 ms** medio, 15.952 primitivas,
  8 sectores, grafo **44 ms**, construcción media **3,76 ms**; `Siguiente ruta`
  y `Esc` → Boot; capturas `f42_pc_*`.
- Android manual: Boot → **Ver mundo** con toque real OK
  (`f42_android_world_touch2.png`).
- Health de F4.2: 10 contratos, 1 advertencia de localización (202 claves →
  F8.4), 0 errores.

## Qué debe hacer F4.3

Alcance exclusivo de **MiMo Pro** (tag `v0.4.2`), según `ROADMAP.md`:
**kits de biomas, gasolineras, moteles, peajes, señalización, agua, polvo y
nieve**.

1. **Consumir F4.2, no rehacerla.** Usar `WorldDirector`, `WorldSectorStreamer`
   y `WorldSectorData` como base. No cambiar `world_routes` v1 ni el artefacto
   OSM. Si se amplía la estructura de `world.streaming`, subir `schema_version`
   y documentar la migración; los campos actuales (800 m, 33×33, 2 solicitudes,
   `load_threaded_request`, colisión, ODbL) se conservan.
2. **Kits de bioma** para las seis regiones (costa, montaña, llanos, selva,
   delta y eje industrial): materiales, vegetación, rocas, suelo, detalles de
   borde de vía y variaciones de relieve, respetando el presupuesto de
   **≤ 3.000 triángulos por sector** (2.048 son terreno) y el PSS.
3. **POIs y mobiliario vial**: gasolineras, moteles, peajes, señalización,
   postes, vallas y cruces. Deben ser assets reproducibles (`bpy` o procedurales)
   con LOD0/LOD1/LOD2, manifiesto, licencia y sin marcas reales.
4. **Agua, polvo y nieve**: presets visuales/materiales por bioma y clima;
   la simulación de lluvia/humedad real y `WeatherManager` es F4.4. No duplicar
   `rain_surface_fx` ni adelantar el clima.
5. **Integración de escena**: cargar los kits desde `WorldDirector`/sectores sin
   romper la carga threaded, el máximo de 2 solicitudes, la construcción de una
   malla por frame ni el `load()` síncrono prohibido.
6. **Pruebas**: ampliar `WorldStreamingTest` o crear una prueba de biomas/POIs;
   mantener smoke 270, tren 125, cabina 46, interacción 257, lluvia 206, rutas
   143 y render `RENDER_OK`. Añadir la ruta a health/CI.
7. **Presupuestos**: ≥30 FPS Android baja/TV, 60 objetivo Redmi/PC,
   ≤120.000 triángulos visibles Android (incluidos espejos), ≤450.000 PC,
   PSS ≤ 1,2 GB, sector 800 m, warm-up antes del gameplay.
8. **Referencias**: la revisión visual completa es **obligatoria antes de F4.3**
   (o el 2026-12-06). Revisar los 3 vídeos nuevos del Esteem y los conceptos de
   paisajes/biomas; no copiar imágenes al repositorio. Registrar el uso en
   `docs/reference/REFERENCE_USAGE_LOG.md`.

Reglas:

- No rehacer F1–F4.2. `world_routes` y `world.streaming` se consumen sin cambios
  cerrados; si hace falta cambiar estructura, subir versión y migrar.
- No crear autoloads nuevos. `WorldDirector` es servicio de escena.
- No corregir H1/H2/H3/H4: H1 → F4.4; H2 → F5.1/F9.1; H3 → F9.1; H4 → F9.1/F10.2.
- No empezar F4.4 (clima/mapa de papel) ni F5 (conducción/vadeo/anti-atasco).
- Mantener la atribución ODbL visible y el texto de licencia en el build.
- No versionar respuestas OSM, teselas DEM, cachés ni binarios de build.
- Los kits deben tener manifiesto, LOD0/1/2, licencia verificable y no usar
  imágenes de `C:\Dev\fotos de ejemplo` como textura.
- La red comprimida no resuelve cruces a distinto nivel; F4.3 puede añadir kits de
  puente/cruce, pero no reabrir el pipeline OSM de F4.1 sin justificación.

Al iniciar:

  python tools/health_check.py --start
  python tools/scan_reference_library.py --quick

## Prompt para el siguiente chat

```text
[RN1999 · Subfase 4.3]
CWD: C:\Dev\RutaNocturna1999
Modelo asignado: MiMo Pro (opencode-go/mimo-v2.6-pro)

Lee completos:
- AGENTS.md
- ROADMAP.md
- docs/status/CURRENT.md
- docs/status/HANDOFF.md
- docs/architecture/SYSTEM_ARCHITECTURE.md
- docs/architecture/DATA_CONTRACTS.md
- docs/architecture/BUILD_AND_RELEASE.md
- docs/architecture/WORLD_ROUTES.md
- docs/architecture/WORLD_STREAMING.md

Ejecuta únicamente la Subfase 4.3 (tag v0.4.2): kits de biomas, gasolineras,
moteles, peajes, señalización, agua, polvo y nieve. Consume el terreno, los 454
sectores de 800 m, el streaming asíncrono y la colisión de F4.2. No rehagas
F1–F4.2, no cambies contratos cerrados y no avances a F4.4/F5.

La Fase 4.2 ya cerró:
- v0.4.1: contrato world.streaming v1, 454 sectores de 800 m (4.671.964 bytes;
  929.792 triángulos de terreno), vía, colisión, carga threaded (máx. 2),
  reaparición segura y ODbL.
- Tests: smoke 270, tren 125, cabina 46, interacción 257, lluvia 206, rutas 143,
  streaming 99, render RENDER_OK.
- PC: mundo 60 FPS, 15.952 primitivas, grafo 44 ms, 3,76 ms por sector.
- Redmi: PSS mundo 630,5 MB, 18.802 primitivas, frame 8,52 ms, grafo 76 ms,
  7 sectores, 2 solicitudes, 0 carga síncrona.
- Hallazgos: H1 gotas en cabina → F4.4; H2 palanca PC sin ratón/teclado/gamepad
  (el táctil Android sí funciona) → F5.1/F9.1; H3 radio sin feedback → F9.1;
  H4 retrato/letterbox Android → F9.1/F10.2.

Al iniciar:
  python tools/health_check.py --start
  python tools/scan_reference_library.py --quick

La revisión visual completa de referencias es obligatoria antes de F4.3.
Revisa solo las referencias relevantes (biomas, paisajes, vehículo, vía) y
registra su uso en docs/reference/REFERENCE_USAGE_LOG.md. No copies archivos de
C:\Dev\fotos de ejemplo al repositorio. Respeta presupuestos, contratos,
licencias (ODbL) y el anti-softlock.

Al cerrar: valida esquemas, localización, manifiestos, roadmap y presets;
importa en Godot headless; ejecuta smoke, tren motriz, cabina, interacción,
lluvia, rutas, streaming y render; prueba el juego en PC y en el Redmi con
capturas; mide PSS/triángulos/carga; comprueba espacio; health_check --end;
actualiza ROADMAP, docs/roadmap-data.json, CHANGELOG, CURRENT y HANDOFF; commit,
tag v0.4.2 y push solo si todo pasa; entrega el prompt de F4.4 con DS-S.

No avances a la Fase 4.4.
```

## Recordatorios

- La biblioteca de referencias externa sigue fuera del repositorio; la revisión
  completa siguiente es **obligatoria antes de F4.3** o el **2026-12-06**.
- La ExecutionPolicy de PowerShell está restringida: usar wrappers `.cmd`.
- El export se hace con `tools\dev\export.cmd`; los binarios van a `build/` y
  nunca a Git. `licenses/*.txt`, `CREDITS.md` y los sectores viajan en el build.
- Los presupuestos móviles siguen vigentes: ≤120.000 triángulos visibles
  (incluidos los tres viewports de espejo), RAM ≤1,2 GB PSS.
- Al cambiar `EXPECTED_VERSION`, actualizar `VERSION`, `project.godot`,
  `export_presets.cfg` (`version/name` y `version/code`) y `PHASE` de `Boot.gd`;
  la prueba de rutas, la de lluvia, la de streaming y el smoke tienen su
  `EXPECTED_VERSION`.
- La red y los sectores son ODbL 1.0: conservar atribución, licencia y
  share-alike. No editar `route_network.json` ni los `.res` a mano: regenerar con
  el pipeline/horneado.
- El warm-up de shaders debe seguir ejecutándose antes del gameplay.
- No se sube ningún token, keystore, APK o AAB a Git.
- La pérdida de agarre, el vadeo y el anti-atasco son F5.1; la lluvia real de
  `WeatherManager` es F4.4; el mapa de papel es F4.4.
- El terreno de F4.2 es greybox: no se declara “arte final” ni se usan las fotos
  como textura. F4.3 añade los kits con manifiesto y LODs.
- H4 (retrato/letterbox) es preexistente; no se corrigió en F4.2. Si F4.3 toca
  menús/UI, no cambiar la orientación sin una prueba completa de todas las
  escenas y del Redmi.

## Seguridad

El inicio de sesión usado para publicar debe rotarse o revocarse después de la
publicación si el token fue compartido por un canal no seguro. La configuración
local de Git no contiene el token.
