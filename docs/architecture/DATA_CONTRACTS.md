# Contratos de datos

**Estado:** Fase 1.1. Los contratos están escritos y validados; `SaveManager` base
se implementó en Fase 1.2. Las mecánicas se implementan después.

## 1. Archivos canónicos

| Archivo | Propósito |
|---|---|
| `data/schemas/vehicle_components.json` | Piezas, fallos, síntomas, costos, herramientas y especificaciones del Esteem |
| `data/schemas/vehicle_powertrain.json` | Simulación del motor, caja automática, frenos, combustible, térmica y masa longitudinal |
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
- No hay texto visible: la señalética P-R-N-D-2-L es posicional. La localización
  de etiquetas llega en F2.4/F9.1.
- Todas las cotas de interior son `provisional_design_value` /
  `photo_observed_provisional`: el manual disponible no incluye cotas de cabina.
  No se publican como especificación oficial. Ver `ESTEEM_MECHANICAL_NOTES.md`.
- Cambiar la estructura exige incrementar `schema_version`; cambiar un valor exige
  actualizar su `note` de fuente.
