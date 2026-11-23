# Contratos de datos

**Estado:** Fase 1.1. Los contratos están escritos y validados; `SaveManager` base
se implementó en Fase 1.2. Las mecánicas se implementan después.

## 1. Archivos canónicos

| Archivo | Propósito |
|---|---|
| `data/schemas/vehicle_components.json` | Piezas, fallos, síntomas, costos, herramientas y especificaciones del Esteem |
| `data/schemas/vehicle_powertrain.json` | Simulación del motor, caja automática, frenos, combustible, térmica y masa longitudinal |
| `data/schemas/rain_surface_fx.json` | Humedad, gotas, limpiaparabrisas, charcos y presupuestos de lluvia |
| `data/schemas/inventory_tools.json` | Herramientas y consumibles referenciados por el vehículo y la defensa |
| `data/schemas/folklore_entities.json` | Reglas de aparición, percepción, audio, evasión y combate |
| `data/schemas/dialogue_and_endings.json` | Pasajeros, confianza, nodos de diálogo y finales |
| `data/schemas/autoload_dependencies.json` | Grafo acíclico de autoloads y servicios de escena |
| `data/schemas/json/*.schema.json` | JSON Schemas de validación |

## 2. Reglas generales

- Cada archivo tiene `schema_version`.
- Todos los IDs son estables, únicos y en minúsculas con puntos o guiones bajos.
- No se escribe texto visible en la lógica: se usan claves de localización.
- No hay expresiones de código arbitrarias dentro de los JSON.
- Las condiciones se expresan con `all`, `any`, `not` y comparadores declarativos.
- Las referencias a herramientas, items, nodos o estados se validan.
- Los IDs de autoloads se resuelven con un grafo y un orden topológico.
- Las rutas de assets y escenas son futuras y no deben romper la validación de F1.1.

## 3. Vehículo

El vehículo tiene especificaciones y una lista de componentes reparables.

Campos centrales de cada componente:

- `id`, `name_key`, `category`, `location`.
- `repair_kind`: `replace`, `repair` o `service`.
- `part_cost_bs`, `labor_cost_bs`, `price_source`.
- `required_tools`, `required_items`, `repair_minutes`, `roadside_possible`.
- `symptoms`: condiciones que el jugador puede observar.
- `failure_modes`: causas internas, no todas visibles.
- `effects`: variables de simulación afectadas.
- `reference_notes`: referencias de la biblioteca externa, sin copiar assets.

La distinción entre **síntoma** y **causa** es deliberada: el jugador diagnostica
con síntomas; el juego no revela una causa que no se ha comprobado.

La altura de la toma de aire y los parámetros de vadeo viven en `specs.water`.
Los costos son valores de balance provisionales hasta contrastar el manual y las
fuentes de 1999.

## 4. Folclore

Cada entidad contiene:

- `regions`, `spawn_conditions`, `perception`.
- `states` con transiciones válidas.
- `audio` con modo y parámetros.
- `evasion` y `combat` con requisitos y objetos válidos.
- `despawn_conditions` y `qa_spawn_command`.
- `reference_notes`.

El Silbón usa `audio.mode = inverted_distance`. La validación exige que
`real_near_m < real_far_m`. La dirección se conserva; solo se invierte la
sensación de distancia.

## 5. Diálogo, confianza y finales

- `entry_node` debe existir.
- Todo `next` y toda elección deben apuntar a un nodo existente.
- Los nodos `end` no deben continuar.
- Los pasajeros tienen rangos de confianza y región de entrada.
- Los finales tienen prioridad, condiciones y escena.
- El evaluador garantiza exactamente un final y declara un fallback.
- Las ramas inalcanzables se revisarán con el corpus de Fase 7.

Los nodos actuales son ejemplos de contrato, no la campaña final.

## 6. Autoloads

`autoload_dependencies.json` contiene:

- `name`, `path`, `depends_on`, `responsibility`.
- Servicios de escena y sus dependencias.
- Regla de no ciclos.

`tools/validate_schemas.py` construye el grafo y detecta ciclos. El orden de
inicialización es topológico.

## 7. Localización

- CSV base: `localization/strings.csv`.
- Locales: `es_VE`, `es_ES`, `en`, `pt_PT`, `pt_BR`, `it`, `fr`, `de`, `ru`,
  `zh_CN`, `ja`.
- `validate_localization.py` comprueba claves, duplicados, vacíos, placeholders y
  glifos prohibidos.
- La cobertura visual de fuentes CJK/cirílicas se exige en F8.4.
- Las claves de contenido que aún no existen se reportan como advertencia hasta
  que la campaña se escriba.

## 8. Pipeline de contenido

1. Editar JSON canónico.
2. Validar con JSON Schema y referencias cruzadas.
3. Validar localización.
4. Generar recursos runtime tipados.
5. Ejecutar pruebas de contenido y cargar una escena de prueba.
6. Actualizar manifiesto de versión del contrato.

En F1.1 no se ha generado todavía el compilador a `.tres`; esa capa entra con los
sistemas de Fase 1.2/2.1.

## 9. Guardados

Los guardados son un contrato separado:

```json
{
  "save_version": 1,
  "game_version": "0.2.0",
  "checksum": "sha256",
  "timestamp_utc": "2026-11-22T00:00:00Z",
  "rng_seed": 123456,
  "data": {}
}
```

Reglas:

- `save_version` se incrementa con cada cambio incompatible.
- Migraciones encadenadas, nunca saltos silenciosos.
- Backup antes de migrar.
- Pruebas con fixtures desde `v0.2.0`.
- Escritura atómica y verificación de checksum.
- Una partida de versión futura se rechaza sin sobrescribirla.

La implementación real empieza en Fase 2.4/Fase 5.1 y se completa en Fase 9.4.
La Fase 1.2 dejó un `SaveManager` base con escritura atómica, checksum canónico,
rechazo de versiones futuras y backups; no incluye migraciones encadenadas.

### 9.1 Línea base v0.2.0 (Fase 2.4)

- La línea base de migraciones es `save_version: 1` con
  `game_version: "0.2.0"`: todo guardado escrito en F2.4 o antes tiene esa
  forma y es el origen de la cadena futura de F9.4.
- El fixture versionado `tests/fixtures/save_v0_2_0.json` reproduce esa forma
  con un snapshot completo; se genera y verifica con
  `tools/make_save_fixture.py` (replica exacta de `_canonical_json`) y lo carga
  una prueba real del smoke test (checksum, aplicación de estado y borrado).
- La F2.4 verificó y corrigió el respaldo previo a sobrescribir: `DirAccess.copy`
  exige rutas absolutas (`user://saves/slot_XX.json.bak`).
- El panel QA guarda y carga en la ranura QA (`user://saves/qa/`) mediante
  `SaveManager.save_slot(slot, reason, qa_mode=1)`: una acción de QA nunca
  pisa una partida real.
- Las migraciones encadenadas, los fixtures adicionales y las pruebas de
  actualización son Fase 9.4.

## 10. Comandos

```powershell
.\.venv\Scripts\python.exe tools\validate_schemas.py
.\.venv\Scripts\python.exe tools\validate_localization.py
.\.venv\Scripts\python.exe tools\release\sync_roadmap.py --check
```

Los errores de esquema, IDs duplicados, referencias rotas o ciclos bloquean la
subfase. Las advertencias se documentan y se resuelven en la fase correspondiente.

## 11. Pipeline de assets 3D (Fase 1.3)

Los assets 3D tienen su propio contrato declarativo, separado de los cinco
contratos de sistemas:

- `data/vehicle/blockout_spec.json` describe dimensiones, masas, materiales,
  niveles de LOD y anclas del rig del bloqueo del Esteem.
- Los `.glb` en `assets/generated/` se generan solo con scripts `bpy`
  reproducibles (`tools/blender/`) y nunca se editan a mano.
- `assets/manifests/*.manifest.json` registran comando, hashes de entradas y
  salidas, autor, licencia y fecha de cada compilación.
- `tools/validate_assets.py` comprueba manifiestos, hashes, política de
  LOD0/LOD1/LOD2 y coherencia del ancla de rig con el spec.

Detalle completo en `docs/architecture/ASSET_FACTORY.md`. Las cotas del bloqueo
son provisionales hasta verificarlas contra manual o medición (ver
`docs/reference/ESTEEM_MECHANICAL_NOTES.md`).

## 12. Export y localización en builds (Fase 1.4)

- `export_presets.cfg` declara los presets Windows y Android; el pipeline de build
  está documentado en `docs/architecture/BUILD_AND_RELEASE.md`.
- El CSV de localización sigue siendo la fuente de verdad. El importador genera
  `localization/strings.<locale>.translation`; esos artefactos no se versionan
  (`*.translation` está en `.gitignore`).
- En el código fuente, `LocalizationManager` lee el CSV. En una build exportada,
  carga los `.translation` importados por locale; si faltara alguno, advierte y
  conserva el fallback `es_VE`.
- Los JSON de `data/` se incluyen en el export para que el runtime pueda validar
  contratos más adelante; los tests, herramientas y documentación quedan fuera.
- Los binarios de export no son contratos: van a `build/exports/` y nunca a Git.

## 13. Tren motriz (Fase 2.1)

El contrato de simulación del vehículo es `data/schemas/vehicle_powertrain.json`
(`schema_version: 1`) y su JSON Schema vive en
`data/schemas/json/vehicle_powertrain.schema.json`.

Secciones:

| Sección | Contenido |
|---|---|
| `engine` | Cilindrada, relación de compresión, curva de par, ralentí, corte, arranque, ahogo, fricción y consumo |
| `transmission` | Relaciones, convertidor, calendario de cambios, P-R-N-D-2-L y Overdrive |
| `fuel` | Capacidad, aviso de reserva y umbral de vacío |
| `brakes` | Fuerza de servicio y estacionamiento, fade, pastillas y líquido |
| `cooling` | Termostato, radiador, electroventilador, fallos y protecciones térmicas |
| `vehicle` | Masa, radio de rueda, arrastre, rodadura y pendiente máxima |

Reglas:

- Cada sección declara `source_status` y `source_note`. Los valores del manual se
  marcan como verificados; los valores de simulación se marcan como provisionales
  y no se publican como especificación oficial.
- `tools/validate_schemas.py` comprueba la coherencia con
  `vehicle_components.json` (cilindrada, selector, marchas, Overdrive, tanque y
  componentes del ventilador) y con `data/vehicle/blockout_spec.json` (radio de
  rueda).
- El runtime no interpreta texto visible: los avisos son códigos internos
  (`fuel_low`, `overheat`, `fan_fault`, `brake_fade`, `parking_brake`,
  `safe_mode`, `brake_fluid_low`, `engine_seized`). La UI de F2.4/F9.1 los
  mapeará a claves de localización.
- Cambiar la estructura del contrato exige incrementar `schema_version` y
  documentar la migración. Cambiar un valor exige actualizar su `source_note`.
- El contrato es de simulación, no de reparación: los costos, herramientas y
  síntomas siguen en `vehicle_components.json`.

## 14. Cabina y rig de manos (Fase 2.2)

La cabina es un contrato de **assets 3D**, no de sistemas: `data/vehicle/cabin_spec.json`
(`schema_version: 1`) describe de forma declarativa el bloqueo funcional del
interior y el rig de manos. Su validación vive en `tools/validate_assets.py`
(mismo patrón que el bloqueo) y no en `validate_schemas.py`.

Secciones:

| Sección | Contenido |
|---|---|
| `components` | Volante, columna, tablero, instrumental, consola, radio cassette doble DIN, clima, guantera, paneles de puerta y guía de palanca P-R-N-D-2-L |
| `materials` | Grises/beige de greybox originales; sin texturas de fotos |
| `lods` | LOD0/LOD1/LOD2 con `max_triangles` estrictamente decrecientes |
| `rig_anchor` | Armazón `EsteemHandRig`, huesos `anchor_*`/`hand_*`/`ik_*` y `ik_poses` |

Reglas:

- Los controles se colocan según las anclas `anchor_*` de
  `data/vehicle/blockout_spec.json` (mismo espacio de coordenadas); el rig de
  manos reutiliza esas posiciones para que las poses IK sean compatibles.
- La palanca refleja `transmission.selector_modes` y `transmission.overdrive` de
  `vehicle_powertrain.json`; el freno de mano refleja `brakes.parking`. La
  manipulación real es F2.3; aquí solo existe la geometría y las poses IK.
- No hay texto visible en la malla: la señalética P-R-N-D-2-L es posicional. Las
  etiquetas y pistas de la interacción llegan con claves de localización en F2.3.
- Todas las cotas de interior son `provisional_design_value` /
  `photo_observed_provisional`: el manual disponible no incluye cotas de cabina.
  No se publican como especificación oficial. Ver `ESTEEM_MECHANICAL_NOTES.md`.
- Cambiar la estructura exige incrementar `schema_version`; cambiar un valor exige
  actualizar su `note` de fuente.

## 15. Interacción contextual de la cabina (Fase 2.3)

La interacción es un contrato de sistemas separado del asset de cabina:

- `data/schemas/cabin_interaction.json` (`schema_version: 1`) describe el
  retículo/tacto, las poses IK de 2/1/0 manos, los controles, las puertas y
  seguros, los vidrios, las luces, la radio, la antena, la guantera, la palanca
  P-R-N-D-2-L con Overdrive y el freno de mano.
- Su JSON Schema vive en `data/schemas/json/cabin_interaction.schema.json` y se
  valida en `tools/validate_schemas.py` (no en `validate_assets.py`).
- `tests/vehicle/InteractionTest.tscn` y `tools/dev/interaction_test.cmd`
  comprueban el contrato, la escena, las poses IK, el foco/tacto, los estados y
  la delegación en el tren motriz.

Secciones:

| Sección | Contenido |
|---|---|
| `interaction` | Modos `look`/`touch`, distancia, ángulo de retículo, radio táctil de 44 dp, tiempos de transición y arrastre |
| `hands` | Hombros, longitudes de brazo, ancla de reposo/volante, offsets de agarre y poses IK |
| `controls` | IDs, tipo, etiqueta/pista localizada, posición de bind, posición de interacción, pose, gesto y enlace al tren motriz |
| `doors`, `windows`, `lights`, `radio`, `antenna`, `glovebox` | Estados, animaciones, bandas/emisoras, señal y topes |
| `gear_gate` | Detentes P-R-N-D-2-L, pivote, longitud y tiempos de la palanca |
| `handbrake` | Ángulos liberado/aplicado y tiempo |
| `visual_offsets` | Desplazamiento funcional de los controles del greybox a la cara del conductor |
| `visual_proxies` | Primitivas de código para vidrios, antena, testigos, botones y manos; no son arte final |
| `feedback` | Códigos de rechazo y sus claves de localización |
| `accessibility`, `anti_softlock` | 44 dp, texto además de color, cero botones persistentes y acciones reversibles |

Reglas:

- `gear_lever.powertrain_link` es `transmission.selector`; `overdrive_button` es
  `transmission.overdrive`; `handbrake` es `brakes.parking`. La interacción no
  define relaciones, curva de par, fuerzas de freno ni física de conducción.
- El volante **no** mueve la dirección ni el chasis en esta subfase: solo cambia
  la pose IK. La conducción real es F2.4/F3.
- El estado de los controles, las puertas, los vidrios, las luces, la radio, la
  antena y la guantera vive en la cabina; no se escribe en `GameState` ni en
  `SaveManager` (guardado F2.4/F9.4).
- Las posiciones de bind siguen siendo las anclas provisionales de F2.2. Las
  posiciones de interacción y los `visual_offsets` corrigen que el greybox de
  F2.2 dejó algunos mandos dentro de las cajas sólidas. La geometría definitiva
  es F3.2; no se alteran los assets ni las anclas de F2.2.
- Los proxies de vidrio, antena, testigos, botones y manos son primitivas de
  código reproducibles; no son modelos de la fábrica ni arte final.
- No hay espejos, HUD de velocidad/combustible, gamepad ni guardado en F2.3. La
  UI se limita al retículo y al prompt contextual.
- Cambiar la estructura exige incrementar `schema_version` y documentar la
  migración; cambiar una posición o un umbral exige actualizar su nota de fuente
  o su sección de offsets.

### 15.1 Espejos, HUD y gamepad (Fase 2.4, `schema_version: 2`)

La versión 2 del contrato es **aditiva**: añade tres secciones y no modifica
controles, poses IK, gear_gate, puertas, vidrios, luces, radio, antena,
guantera, freno de mano ni los enlaces al tren motriz. La migración v1 → v2 no
requiere transformar datos; `schema_history` documenta ambos pasos en el propio
JSON y `CabinInteractionSpec` acepta 1 y 2.

| Sección | Contenido |
|---|---|
| `mirrors` | Tres espejos (`rearview`, `left`, `right`) con `position_m`, rotación de superficie, cámara, `surface_size_m`, `viewport_size_px`, `fov_deg`, `update_hz` y `budget` (`scene_passes`, `surface_max_triangles_total`, `counted_in_mobile_budget`) |
| `hud` | Fuente `VehiclePowertrain.get_telemetry`, `refresh_hz`, esquina, campos, claves `label_keys` y `warning_keys` (los ocho códigos internos), `max_persistent_buttons: 0` y `text_not_only_color` |
| `gamepad` | Acciones `ui_*` de menú, botones de foco D-Pad, A/B, ejes del stick, sensibilidad, zona muerta, `focus_wrap`, `min_target_dp` y `tv_navigation_required` |

Reglas:

- `tools/validate_schemas.py` comprueba que los espejos laterales coinciden con
  `anchor_mirror_left` / `anchor_mirror_right` de `blockout_spec.json`, que las
  superficies caben en su presupuesto, que `hud.warning_keys` cubre exactamente
  los avisos del tren motriz y que todas sus claves existen en el CSV de once
  idiomas.
- El HUD es solo lectura: no puede llamar a `set_selector`, `toggle_overdrive`
  ni a ningún comando del tren motriz (lo comprueba la prueba de interacción).
- El gamepad vive únicamente en `src/vehicle/cabin_gamepad_adapter.gd`: ningún
  otro script de `src/vehicle/` contiene `InputEventJoypad`, y el núcleo de
  F2.3 (controlador, controles, IK, UI) sigue sin eventos de gamepad.
- El guardado no entra en este contrato: su contrato es la sección 9.

## 16. Exterior definitivo (Fase 3.1)

El exterior es un contrato de **assets 3D**, no de sistemas:
`data/vehicle/exterior_spec.json` (`schema_version: 1`) describe de forma
declarativa el exterior definitivo del Esteem. Su validación vive en
`tools/validate_assets.py` (mismo patrón que bloqueo y cabina) y no en
`validate_schemas.py`.

Secciones:

| Sección | Contenido |
|---|---|
| `base_dimensions` | Cotas globales idénticas a `blockout_spec.json` (provisionales); el validador exige coincidencia |
| `body_shell` / `canopy` | Bañera de carrocería e invernadero como lofts de secciones transversales |
| `pieces` | Piezas separadas: capó, maletero, puertas, manijas, parachoques, parrilla, faros, pilotos, espejos, antena, tapa de combustible, limpiaparabrisas, molduras y matrícula |
| `glass_panels` | Parabrisas, luneta y cuatro ventanillas como paneles de grosor finito |
| `wheels` | Neumático + llanta + tapacubo, posiciones derivadas de track/batalla/radio del bloqueo |
| `materials` | Materiales PBR propios (pintura, vidrio con transmisión, plástico, goma, cromo, acero, lentes con emisión) |
| `lods` | LOD0/LOD1/LOD2 con `section_step`, `wheel_segments`, `features` y `max_triangles` estrictamente decrecientes |
| `rig_anchor` | Armazón `EsteemExteriorRigAnchor` con las 17 anclas `anchor_*` del bloqueo |

Reglas:

- Las carcasas de espejo deben **envolver** `anchor_mirror_left/right` (donde
  F2.4 monta las superficies funcionales de `mirrors.budget`); lo comprueba
  `tools/validate_assets.py`. Los espejos funcionales siguen siendo solo los de
  `cabin_mirrors.gd`; el exterior no duplica superficies reflectantes vivas.
- Las ruedas deben coincidir con `track_m`, `wheelbase_m` y
  `wheel_radius_m` del bloqueo.
- Las piezas pueden sobresalir del ancho de carrocería solo dentro del margen
  `validation_rules.pieces_overhang_m` (manijas, molduras y brazos de espejo).
- No hay marcas, emblemas ni texto visible en la malla; la parrilla y la
  matrícula son neutras. Ningún material procede de la biblioteca externa.
- Cambiar la estructura exige incrementar `schema_version`; cambiar una cota o
  un material exige actualizar su nota de fuente (`source_status` /
  `source_note`). Las cotas de carrocería siguen siendo provisionales hasta la
  verificación contra manual o medición.

## 17. Interior definitivo (Fase 3.2)

El interior es un contrato de **assets 3D**, no de sistemas:
`data/vehicle/interior_spec.json` (`schema_version: 1`) describe de forma
declarativa el interior definitivo del Esteem. Su validación vive en
`tools/validate_assets.py` (mismo patrón que bloqueo, cabina y exterior) y no
en `validate_schemas.py`.

Secciones:

| Sección | Contenido |
|---|---|
| `base_dimensions` | Cotas globales idénticas a `blockout_spec.json` (provisionales); el validador exige coincidencia |
| `controls_geometry` | Volante de tres radios, columna, palanca P-R-N-D-2-L con botón de Overdrive, freno de mano y guía de marchas: geometría idéntica a `cabin_spec.json` para conservar las poses IK de F2.2 |
| `pieces` | Piezas separadas: tablero bitono, instrumental de tres básculas, consola, radio cassette, clima con deslizadores, guantera, tarjetas de puerta con tela, alfombrado, techo/pilares/visores, maletero y herramientas |
| `hands` | Manos definitivas (`hand_left`/`hand_right`) con palma, dedos y pulgar en las posiciones de bind del rig de manos de F2.2 |
| `materials` | Vinilos, plásticos, telas de dos tonos, alfombrado, moqueta, cinturones, metal, carátulas, agujas con emisión, cristal, acero, madera, goma y piel |
| `lods` | LOD0/LOD1/LOD2 con `features` y `max_triangles` estrictamente decrecientes |
| `rig_anchor` | Armazón `EsteemInteriorRigAnchor` con 9 anclas idénticas a `blockout_spec.json` |

Reglas:

- **No se toca `cabin_interaction.json` (v2)**: el interior conserva los
  nombres de nodo que `cabin_visual_proxies.gd` reubica (`steering_hub`,
  `gear_knob`, `gear_od_button`, `handbrake_grip`, `radio_double_din`,
  `radio_double_din_slot`, `climate_controls`, `glovebox`, `glovebox_latch`,
  `door_panel_*`, …) y las piezas de mando se modelan en las posiciones de bind
  de `cabin_spec.json`; los `visual_offsets` de F2.3 siguen aplicándose igual.
  `tools/validate_assets.py` exige que todos los nodos interactivos existan.
- Las **manos definitivas** sustituyen los proxies de caja de F2.3 en tiempo de
  ejecución (`cabin_visual_proxies.gd` las reubica con la misma API), mantienen
  el rig `esteem_hand_rig` y las poses IK de F2.2 y se colocan en
  `hand_l_palm`/`hand_r_palm` de `cabin_spec.json` (lo comprueba el validador).
- Las **herramientas del maletero** declaran `inventory_id` con IDs de
  `inventory_tools.json`; el validador exige que existan gato, llave de cruz,
  tablas y repuesto (anti-atasco de F5.1). Son arte, no mecánicas.
- No hay texto visible en la malla: la guía P-R-N-D-2-L es posicional, las
  carátulas del instrumental no llevan números y los alfombrados no llevan
  logotipos. Las etiquetas siguen siendo claves de localización.
- Todas las cotas de interior son `provisional_design_value` /
  `photo_observed_provisional`: el manual disponible no incluye cotas de
  cabina. No se publican como especificación oficial. Ver
  `ESTEEM_MECHANICAL_NOTES.md`.
- Cambiar la estructura exige incrementar `schema_version`; cambiar una cota o
  un material exige actualizar su nota de fuente (`source_status` /
  `source_note`).

## 18. Lluvia, humedad y superficies (Fase 3.3)

La lluvia física es un contrato de **sistemas**, no de assets:
`data/schemas/rain_surface_fx.json` (`schema_version: 1`,
`contract_id: vehicle.esteem.rain_surface_fx`). Su JSON Schema vive en
`data/schemas/json/rain_surface_fx.schema.json`, se valida en
`tools/validate_schemas.py` y sus ecuaciones se detallan en
`docs/architecture/RAIN_AND_SURFACE_FX.md`.

Secciones:

| Sección | Contenido |
|---|---|
| `precipitation` | Conversión de intensidad normalizada a mm/h, viento máximo, humedad y paso máximo |
| `surfaces` | Clases de material (pintura, vidrio, asfalto, tierra, cromo, plástico), paneles del vehículo y superficies de vía |
| `wetness` | Ecuaciones de película, drenaje, evaporación, infiltración, umbrales e histéresis |
| `droplets` | Perfiles `glass`/`paint`, nucleación, crecimiento, radio crítico, desliz, viento, evaporación y layout de instancias |
| `wiper` | Dos escobillas derivadas de `exterior_spec.json`, barrido, modos, intermitencia, desgaste y anti-softlock |
| `puddles` | Arquetipos de charco, drenaje, infiltración, hidroplaneo y enlace con `specs.water` |
| `budgets` | Límites PC/móvil de gotas, charcos, CPU, frame y objetivos GPU pendientes |
| `states` | Estados internos de superficie, gota, limpiaparabrisas y charco |

Reglas:

- El contrato **no** implementa shaders, VFX, arte, controles de cabina ni
  pérdida de agarre. F3.4 implementa el GLSL, F4.4 conecta `WeatherManager` y
  F5.1 consume charcos y vadeo.
- `tools/validate_schemas.py` comprueba el área del parabrisas y los pivotes y
  longitudes de las escobillas contra `exterior_spec.json`, y la altura de
  admisión y profundidad segura contra `vehicle_components.json`.
- Los perfiles de gotas suman exactamente `budgets.pc.max_droplets_total`
  (4.096). El presupuesto móvil (1.536) es un subconjunto y no puede superar al
  de PC.
- La medición CPU de F3.3 se ejecuta en `tests/weather/RainFxTest.tscn`; el
  coste GPU, el warm-up y el PSS se miden en F3.4/F3.5/F10.1.
- Cambiar la estructura exige incrementar `schema_version`; cambiar un valor
  exige actualizar su `source_status`/`source_note`.
