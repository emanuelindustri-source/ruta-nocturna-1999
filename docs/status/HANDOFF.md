# Handoff — Fase 4.1

## Estado de partida

La Fase 3.5 quedó cerrada, validada y publicada: la **Fase 3 está completa**
(arte definitivo + shaders de lluvia + integración/medición). El Esteem
conserva intactos tren motriz, cabina, interacción, espejos, HUD, gamepad,
guardado, exterior (F3.1), interior (F3.2) y los shaders de F3.4.

- Web: https://emanuelindustri-source.github.io/ruta-nocturna-1999/
- Repositorio: https://github.com/emanuelindustri-source/ruta-nocturna-1999
- Versión: `v0.3.4` (Android `version/code=111`, Windows `0.3.4.0`)
- Contratos: los ocho existentes **sin cambios en F3.5**
  (`rain_surface_fx.json` v1 sigue en `pending_f34_f35` para F10.1).
- Nuevas piezas de F3.5:
  - `src/debug/device_perf_probe.gd` (`DevicePerfProbe`, servicio de escena;
    inerte sin `user://perf_route.marker`).
  - Sonda GPU + pacing + carga en `tests/render/rain_fx_render_test.gd`.
  - `tools/test_android_adb.ps1` con **ruta de rendimiento** en el Redmi.
  - `tools/asset_compression_report.py`, `tools/dev/gameplay_input.ps1`,
    `tools/dev/gameplay_diff.py`.
- Pruebas (todas exit 0): smoke **270**, tren motriz **125**, cabina **46**,
  interacción **257**, lluvia **206**, render **RENDER_OK**; ADB completo
  **exit 0** en el Redmi (`obojropz89mbwgpn`).
- Medición F3.5 (resumen):
  - PC: frame 16,66–16,67 ms, **0 jank**; draw calls añadidos ≤ 2,40 ≤ 8;
    overdraw ≤ 1,0 ≤ 5; fill visual 0,02 %/2,78 % ≤ 6 %; coste FX real
    +1,164/+2,328 ms; cargas 140,7/77,5/214,5 ms.
  - Redmi: PSS **415,6/535,3/614,7 MB** ≤ 1.228,8; rebanada **15.874
    triángulos** ≤ 120.000, frame **12,76/16,96 ms**; cabina 7.435 triángulos,
    **10,14/16,83 ms**; cargas 8.765/4.525 ms; warm-up antes del gameplay
    (1.924/2.018 ms); logcat sin errores.
  - Compresión: ETC2/ASTC + S3TC OK; APK 29.557.514 bytes
    (`553F9128…FE59ABAF`); exe 103.070.208 bytes + pck 1.516.108 bytes.
- Health de F3.4 (cierre anterior): 21 OK, 2 advertencias esperadas, 0
  errores; el cierre de F3.5 se ejecuta con este mismo patrón.
- Hallazgos abiertos con fase asignada (aprobados por el director):
  - **H1 → F4.4:** las gotas de cámara cubren pantalla completa y parecen
    caer dentro del habitáculo (en el exterior la lluvia cae bien). Recortar
    la máscara al parabrisas; toca `camera_drops.gdshader` (F3.4), prohibido
    hasta entonces.
  - **H2 → F5.1/F9.1:** la palanca de cambio no responde con ratón, teclado
    ni gamepad (`drag_focused` solo recibe táctil). Requiere decisión de
    diseño de input antes de la conducción.
  - **H3 → F9.1:** el radio no muestra feedback visual pese a ejecutar la
    presión.
- Revisión de referencias: F3.5 solo hizo escaneo rápido (95 archivos, sin
  cambios); la siguiente revisión completa es **obligatoria antes de F4.3**.

## Qué debe hacer F4.1

Alcance exclusivo de **DS-R** (tag `v0.4.0`), según `ROADMAP.md`:
**pipeline OSM/Overpass, DEM, grafo, rutas alternativas, caché y atribución
ODbL.**

1. **Datos primero**: definir el contrato del mundo/rutas (p. ej.
   `data/schemas/world_routes.json` o el que DS-R decida) con JSON Schema en
   `data/schemas/json/`, validación en `tools/validate_schemas.py` y nota en
   `docs/architecture/`. Cambiar un contrato existente exige subir
   `schema_version` y documentar migración; **los contratos de F1–F3.5 no se
   tocan**.
2. **Pipeline OSM**: descarga/consulta Overpass, transformación a nodos/aristas
   con IDs estables, red vial del área de juego y **atribución ODbL** visible
   en `CREDITS.md`/web (licencia de datos abiertos obligatoria).
3. **DEM**: elevación para la red (suficiente para pendientes y referencia de
   F4.2), con procedencia documentada.
4. **Grafo y rutas**: rutas principales + alternativas, costes, conectividad
   validada (sin ciclos imposibles, sin nodos huérfanos en lo usado).
5. **Caché**: artefactos derivados regenerables por pipeline validado (JSON es
   la fuente de verdad; nada de binarios pesados en Git).
6. **Pruebas**: ampliar `tools/validate_schemas.py`/tests para cubrir grafo y
   rutas (IDs únicos, referencias cruzadas, validación de ODbL) sin relajar
   las270/125/46/257/206 actuales.

Reglas:

- No rehacer F1–F3.5. `rain_surface_fx.json`, `cabin_interaction.json`,
  `vehicle_powertrain.json`, `exterior_spec.json` e `interior_spec.json`
  quedan intactos.
- No crear autoloads nuevos (WorldDirector será servicio de escena en F4.2).
- **No corregir H1/H2/H3 en F4.1**: tienen fase propia asignada.
- No avanzar a F4.2 (streaming de sectores800 m) en este chat.
- Presupuestos vigentes: sectores800 m, RAM ≤1.2 GB PSS, triángulos ≤120.000
  en Android; las pruebas de rendimiento siguen en la ruta de referencia.

Al iniciar:

  python tools/health_check.py --start
  python tools/scan_reference_library.py --quick

## Prompt para el siguiente chat

```text
[RN1999 · Subfase 4.1]
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

Ejecuta únicamente la Subfase 4.1 (tag v0.4.0): pipeline OSM/Overpass, DEM,
grafo, rutas alternativas, caché y atribución ODbL. No rehagas F1–F3.5 ni
cambies contratos cerrados. No avances a F4.2 ni a ninguna otra subfase.

La Fase 3.5 ya cerró:
- v0.3.4 publicada: DevicePerfProbe + ruta ADB en el Redmi (PSS
  415,6/535,3/614,7 MB, rebanada 15.874 triángulos y 12,76 ms de media,
  cabina 10,14 ms, warm-up antes del gameplay), sonda GPU real en PC
  (draw calls ≤8, overdraw ≤5, fill visual ≤6 %, coste FX +1,2/+2,3 ms),
  compresión ETC2/ASTC OK, capturas f35_*, build Windows ejecutada y prueba
  de juego en PC.
- Hallazgos con fase asignada (no tocar en4.1): H1 gotas de cámara sobre el
  habitáculo → F4.4; H2 palanca sin input PC/gamepad → F5.1/F9.1; H3 radio
  sin feedback → F9.1.
- Tests: smoke 270, tren motriz 125, cabina 46, interacción 257, lluvia 206,
  render RENDER_OK; ADB completo exit 0 en el Redmi.

Al iniciar:
  python tools/health_check.py --start
  python tools/scan_reference_library.py --quick

Revisa solo las referencias del catálogo relevantes para esta subfase y
registra su uso. No copies archivos de C:\Dev\fotos de ejemplo al
repositorio. Respeta presupuestos, contratos, licencias (ODbL) y el
anti-softlock.

Al cerrar: valida esquemas (incluido el nuevo contrato de rutas si crea),
localización, manifiestos, roadmap y presets de export; importa el proyecto en
Godot headless; ejecuta tools/dev/smoke_test.cmd, tools/dev/powertrain_test.cmd,
tools/dev/cabin_test.cmd, tools/dev/interaction_test.cmd, tools/dev/rain_test.cmd
y tools/dev/render_test.cmd; comprueba espacio en disco; ejecuta
health_check --end; actualiza ROADMAP.md, docs/roadmap-data.json,
CHANGELOG.md, CURRENT.md y HANDOFF; haz commit, tag v0.4.0 y push solo si todo
pasa; entrega el prompt del siguiente /new (Fase 4.2 con DS-R).

No avances a la Fase 4.2.
```

## Recordatorios

- La biblioteca de referencias externa sigue fuera del repositorio; la
  revisión completa siguiente es **obligatoria antes de F4.3** (o a los14
  días).
- La ExecutionPolicy de PowerShell está restringida: usar wrappers `.cmd`.
- El export se hace con `tools\dev\export.cmd`; los binarios van a `build/`
  y nunca a Git.
- Los presupuestos móviles siguen vigentes: ≤120.000 triángulos visibles
  (incluidos los tres viewports de espejo), RAM ≤1.2 GB PSS.
- Los tests deben seguir pasando sin relajarse: smoke (270), tren motriz
  (125), cabina (46), interacción (257), lluvia (206) y render
  (`RENDER_OK`). Al cambiar `EXPECTED_VERSION`, actualizar también `VERSION`,
  `project.godot`, `export_presets.cfg` (`version/name` y `version/code`) y
  `PHASE` de `Boot.gd`.
- El contrato de F3.3 es la fuente de verdad: no mover valores de humedad,
  gotas, barrido o charcos al shader ni a la UI.
- El warm-up de shaders debe seguir ejecutándose antes del gameplay.
- No se sube ningún token, keystore, APK o AAB a Git.
- Las cotas de carrocería/interior siguen siendo provisionales hasta verificar
  el manual o medir el vehículo real.
- La pérdida de agarre, el vadeo y el anti-atasco son F5.1; la lluvia real
  con `WeatherManager` es F4.4 (junto con H1); la medición GPU fina es
  F10.1/F10.2.

## Seguridad

El inicio de sesión usado para publicar debe rotarse o revocarse después de
la publicación si el token fue compartido por un canal no seguro. La
configuración local de Git no contiene el token.
