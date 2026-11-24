# Handoff — Fase 4.2

## Estado de partida

La Fase 4.1 quedó cerrada y publicada (`v0.4.0`): la base vial real de Venezuela
está integrada como contrato y artefacto reproducible, con DEM, grafo, rutas
principales y alternativas, caché y atribución ODbL. **No hay terreno,
streaming, colisión ni biomas todavía**: eso es F4.2/F4.3/F4.4.

> **Base para F4.2:** parte de `main` en `8b9b83c` (incluye el fix de CI
> CRLF→LF). El tag `v0.4.0` apunta a `52f2033`; no se movió (sin force-push).
> El artefacto y las builds son los mismos.

- Web: https://emanuelindustri-source.github.io/ruta-nocturna-1999/
- Repositorio: https://github.com/emanuelindustri-source/ruta-nocturna-1999
- Versión: `v0.4.0` (Android `version/code=112`, Windows `0.4.0.0`)
- Contratos existentes: los ocho de F1–F3.5 **sin cambios** + `world_routes` v1
  nuevo (`data/schemas/world_routes.json`).
- Nuevas piezas de F4.1:
  - `data/content/world/route_network.json` (1.108.711 bytes) y
    `route_network.manifest.json` (2.111 bytes).
  - `tools/osm/build_world_routes.py` y `tools/osm/route_graph_validation.py`.
  - `src/world/route_network.gd` (`RouteNetwork`, `RefCounted`; **no autoload**).
  - `tests/world/WorldRoutesTest.tscn` +
    `tools/dev/world_routes_test.cmd` (**143/143**).
  - `licenses/ODbL-1.0.txt`, atribución `CREDITS_OSM` en Boot/CREDITS/web.
  - `docs/architecture/WORLD_ROUTES.md`.
- Pruebas (todas exit 0): smoke **270**, tren motriz **125**, cabina **46**,
  interacción **257**, lluvia **206**, rutas **143**, render **RENDER_OK**.
- ADB completo en el Redmi `obojropz89mbwgpn`: **exit 0**; PSS
  428,1/545,9/630,1 MB; rebanada 11,01 ms media y 15.874 triángulos; cabina
  9,81 ms y 7.342 triángulos; cargas 9.521/4.740 ms; warm-up 1.973/2.174 ms.
- PC: build Windows ejecutada; manos al volante OK; QA `Tormenta 95 %/90 %` OK;
  palanca con ratón sigue sin responder (H2); capturas `f41_pc_*`.
- Android: además del ADB, se probó a mano el volante y la **palanca táctil
  P → L1**, que **sí funciona**; H2 es un hueco de PC.
- Health de F4.1: validado con 9 contratos, 1 advertencia de localización
  (202 claves → F8.4), 0 errores.

## Qué debe hacer F4.2

Alcance exclusivo de **DS-R** (tag `v0.4.1`), según `ROADMAP.md`:
**Terrain3D, streaming de sectores de 800 m, colisión, carga asíncrona y PSS
≤ 1,2 GB**.

1. **Consumir F4.1, no rehacerla.** Instanciar `RouteNetwork` desde el
   `WorldDirector` de escena (servicio de escena, **no autoload**), cargar
   `data/content/world/route_network.json` y usar `edge_world_points()`,
   `node_game_position()`, `project_geo()` y las rutas/alternativas.
2. **Terrain3D** sobre la red: terreno, carretera y colisión. Puede usar
   Terrain3D (MIT, verificar compatibilidad) o una malla propia; documentar la
   decisión y el manifiesto/licencia.
3. **Sectores de 800 m** con `ResourceLoader.load_threaded_request()`, máximo
   dos solicitudes simultáneas y sin `load()` síncrono durante la conducción.
4. **Colisión** de carretera/terreno y reaparición segura sobre la red; el
   anti-atasco completo (grúa, deuda, vadeo) es F5.1.
5. **Medir** la carga del grafo contra `budgets.runtime_load_budget_ms` (250 ms,
   pendiente F4.2) y el PSS en el Redmi; actualizar el contrato solo si cambia
   la estructura (subir `schema_version` y documentar migración).
6. **Pruebas**: ampliar la prueba de rutas o crear una prueba de terreno/
   streaming; mantener smoke 270, tren 125, cabina 46, interacción 257, lluvia
   206, rutas 143 y render RENDER_OK. Añadir la ruta al wrapper/CI.
7. **Presupuestos**: ≥30 FPS Android baja/TV, 60 objetivo Redmi/PC, ≤120.000
   triángulos visibles Android (incluidos espejos), ≤450.000 PC, RAM ≤1,2 GB PSS,
   sector 800 m, warm-up antes del gameplay.

Reglas:

- No rehacer F1–F4.1. `world_routes` v1 se consume sin cambios; si hace falta
  cambiar la estructura, subir versión y migrar.
- No crear autoloads nuevos. `WorldDirector` es servicio de escena.
- No corregir H1/H2/H3: H1 → F4.4; H2 → F5.1/F9.1; H3 → F9.1.
- No empezar F4.3 (biomas/POIs) ni F4.4 (clima/mapa de papel) en el mismo chat.
- Mantener la atribución ODbL visible y el texto de licencia en el build.
- No versionar respuestas OSM, teselas DEM, cachés ni binarios de build.

Al iniciar:

  python tools/health_check.py --start
  python tools/scan_reference_library.py --quick

## Prompt para el siguiente chat

```text
[RN1999 · Subfase 4.2]
CWD: C:\Dev\RutaNocturna1999
Modelo asignado: DS-R (opencode-go/deepseek-v4.1-flash#max)

Lee completos:
- AGENTS.md
- ROADMAP.md
- docs/status/CURRENT.md
- docs/status/HANDOFF.md
- docs/architecture/SYSTEM_ARCHITECTURE.md
- docs/architecture/DATA_CONTRACTS.md
- docs/architecture/BUILD_AND_RELEASE.md
- docs/architecture/WORLD_ROUTES.md

Ejecuta únicamente la Subfase 4.2 (tag v0.4.1): Terrain3D, streaming de
sectores de 800 m, colisión, carga asíncrona y PSS ≤ 1,2 GB. No rehagas
F1–F4.1 ni cambies contratos cerrados. No avances a F4.3/F4.4.

La Fase 4.1 ya cerró:
- v0.4.0: contrato world.routes v1, red OSM comprimida (329 nodos, 413 aristas,
  6 principales + 12 alternativas, 4.751,7 km principales), DEM Terrarium,
  caché, ODbL y RouteNetwork; tests rutas 143.
- Hallazgos: H1 gotas en cabina → F4.4; H2 palanca PC sin ratón/teclado/gamepad
  (el táctil Android sí funciona) → F5.1/F9.1; H3 radio sin feedback → F9.1.
- Tests: smoke 270, tren 125, cabina 46, interacción 257, lluvia 206, rutas 143,
  render RENDER_OK; ADB exit 0 en el Redmi.

Al iniciar:
  python tools/health_check.py --start
  python tools/scan_reference_library.py --quick

Revisa solo las referencias del catálogo relevantes para esta subfase y registra
su uso. No copies archivos de C:\Dev\fotos de ejemplo al repositorio. Respeta
presupuestos, contratos, licencias (ODbL) y el anti-softlock.

Al cerrar: valida esquemas, localización, manifiestos, roadmap y presets;
importa en Godot headless; ejecuta smoke, tren motriz, cabina, interacción,
lluvia, rutas y render; prueba el juego en PC y en el Redmi con capturas; mide
PSS/triángulos/carga; comprueba espacio; health_check --end; actualiza ROADMAP,
docs/roadmap-data.json, CHANGELOG, CURRENT y HANDOFF; commit, tag v0.4.1 y push
solo si todo pasa; entrega el prompt de F4.3 con MiMo Pro.

No avances a la Fase 4.3.
```

## Recordatorios

- La biblioteca de referencias externa sigue fuera del repositorio; la revisión
  completa siguiente es **obligatoria antes de F4.3** o el **2026-12-06**.
- La ExecutionPolicy de PowerShell está restringida: usar wrappers `.cmd`.
- El export se hace con `tools\dev\export.cmd`; los binarios van a `build/` y
  nunca a Git. `licenses/*.txt` y `CREDITS.md` viajan en el export.
- Los presupuestos móviles siguen vigentes: ≤120.000 triángulos visibles
  (incluidos los tres viewports de espejo), RAM ≤1,2 GB PSS.
- Al cambiar `EXPECTED_VERSION`, actualizar `VERSION`, `project.godot`,
  `export_presets.cfg` (`version/name` y `version/code`) y `PHASE` de `Boot.gd`;
  la prueba de rutas también tiene su `EXPECTED_VERSION`.
- La red de rutas es ODbL 1.0: conservar atribución, licencia y share-alike.
  No editar `route_network.json` a mano: regenerar con el pipeline.
- El warm-up de shaders debe seguir ejecutándose antes del gameplay.
- No se sube ningún token, keystore, APK o AAB a Git.
- La pérdida de agarre, el vadeo y el anti-atasco son F5.1; la lluvia real de
  `WeatherManager` es F4.4; el mapa de papel es F4.4; los biomas/POIs son F4.3.
- F4.2 debe medir, no “optimizar sin medición”: la carga del grafo y el PSS se
  contrastan con `budgets` y el Redmi.

## Seguridad

El inicio de sesión usado para publicar debe rotarse o revocarse después de la
publicación si el token fue compartido por un canal no seguro. La configuración
local de Git no contiene el token.
