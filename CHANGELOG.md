# Changelog

Todas las fechas usan ISO 8601. Las versiones siguen SemVer.

## [Unreleased]

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
