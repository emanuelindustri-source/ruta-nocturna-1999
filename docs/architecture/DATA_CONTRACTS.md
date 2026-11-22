# Contratos de datos

**Estado:** Fase 1.1. Los contratos están escritos y validados; `SaveManager` base
se implementó en Fase 1.2. Las mecánicas se implementan después.

## 1. Archivos canónicos

| Archivo | Propósito |
|---|---|
| `data/schemas/vehicle_components.json` | Piezas, fallos, síntomas, costos, herramientas y especificaciones del Esteem |
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
