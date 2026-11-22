# EventBus — catálogo de señales

**Estado:** implementado en Fase 1.2 (`src/core/event_bus.gd`).  
**Regla:** `EventBus` no conoce reglas de juego, no lee archivos y no llama a
ningún autoload. Solo transporta señales tipadas.

## 1. Principios

1. La UI emite comandos y escucha resultados; nunca muta el mundo directamente.
2. Los servicios publican cambios y consumen eventos; no se referencian entre sí
   salvo las dependencias declaradas en `autoload_dependencies.json`.
3. Toda operación asíncrona reporta éxito y error por el bus.
4. Las señales no transportan nodos de escena ni rutas absolutas de nodos.
5. Los payloads usan IDs estables, diccionarios serializables y tipos nativos.
6. `EventBus` no se conecta a sus propias señales.

## 2. Ciclo de vida

| Señal | Payload | Emisor | Consumidor |
|---|---|---|---|
| `application_booted` | `version: String` | Boot | Servicios y diagnósticos |
| `application_quitting` | — | Salida ordenada | Servicios |
| `scene_change_requested` | `path: String, reason: String` | UI / QA | `SceneRouter` |
| `scene_changed` | `path: String` | `SceneRouter` | UI, QA, diagnósticos |
| `scene_load_failed` | `path: String, reason: String` | `SceneRouter` | UI, QA |
| `loading_progress` | `path: String, progress: float` | `SceneRouter` | Pantallas de carga |

## 3. Ajustes e idioma

| Señal | Payload | Emisor |
|---|---|---|
| `settings_changed` | `section, key, value` | `SettingsManager` |
| `locale_changed` | `locale: String` | `LocalizationManager` |
| `accessibility_changed` | `settings: Dictionary` | `SettingsManager` (futuro) |

`SettingsManager` publica todas las claves al terminar el arranque para que la UI
y los servicios se sincronicen sin leer archivos.

## 4. Guardado

| Señal | Payload | Emisor |
|---|---|---|
| `save_requested` | `slot: int, reason: String` | `GameState` / UI |
| `save_completed` | `slot: int, path: String` | `SaveManager` |
| `save_failed` | `slot: int, reason: String` | `SaveManager` |
| `load_requested` | `slot: int` | UI |
| `load_completed` | `slot: int, snapshot: Dictionary` | `SaveManager` |
| `load_failed` | `slot: int, reason: String` | `SaveManager` |

`GameState` no llama a `SaveManager`; publica `save_requested`. `SaveManager`
aplica la carga sobre `GameState`, nunca sobre nodos del mundo.

## 5. Estado de juego

| Señal | Payload | Emisor |
|---|---|---|
| `game_state_changed` | `key: String, value: Variant` | `GameState` |
| `flag_changed` | `flag: String, enabled: bool` | `GameState` |
| `mission_changed` | `mission_id: String, stage: String` | `GameState` |
| `trust_changed` | `passenger_id: String, value: float` | `GameState` |
| `humanity_changed` | `value: float` | `GameState` |
| `game_state_loaded` | `source: String` | `GameState` |
| `flags_cleared` | — | `GameState` |
| `mode_changed` | `mode: String` | `GameState` |
| `test_mode_changed` | `enabled: bool` | `GameState` |

## 6. Clima, audio y accesibilidad

| Señal | Payload | Emisor |
|---|---|---|
| `weather_changed` | `preset: String, state: Dictionary` | `WeatherManager` |
| `audio_bus_volume_changed` | `bus_name: String, volume_db: float` | `AudioDirector` |
| `accessibility_cue` | `kind: String, direction: Vector3, intensity: float` | Audio/UI (futuro) |

`AudioDirector` y `WeatherManager` no se llaman entre sí. Si en el futuro el audio
reacciona al clima, lo hace escuchando `weather_changed`.

## 7. Actualizaciones

| Señal | Payload | Emisor |
|---|---|---|
| `update_available` | `version: String, url: String` | `UpdateChecker` |
| `update_check_finished` | `status: String, detail: String` | `UpdateChecker` |

Estados de `status`: `disabled`, `requesting`, `offline`, `error`, `up_to_date`,
`available`. Nunca se autoinstala un APK.

## 8. Diagnóstico y caja negra

| Señal | Payload | Emisor |
|---|---|---|
| `diagnostics_context_requested` | — | `CrashReporter` / QA |
| `diagnostics_context_updated` | `section: String, data: Dictionary` | Cada servicio |
| `diagnostics_action` | `action: String, details: Dictionary` | Servicios y UI |
| `crash_report_requested` | `reason: String` | UI / QA |
| `crash_report_written` | `path: String, reason: String` | `CrashReporter` |
| `performance_warning` | `metric: String, value: float, threshold: float` | `CrashReporter` |

El contexto se construye sin dependencias directas: `CrashReporter` emite
`diagnostics_context_requested`, cada servicio responde con su sección y
`CrashReporter` guarda una copia. Secciones actuales: `hardware`, `settings`,
`localization`, `game_state`, `save`, `audio`, `weather`, `update`, `scene`,
`crash`.

## 9. Panel de creador

| Señal | Payload | Emisor |
|---|---|---|
| `qa_menu_toggled` | `is_open: bool` | `CreatorQAMenu` |
| `qa_action_completed` | `action: String, result: Dictionary` | `CreatorQAMenu` |

Las acciones del panel usan APIs públicas (`GameState`, `WeatherManager`,
`CrashReporter`) y publican el resultado. No editan archivos ni mutan la escena.

## 10. Reglas de prueba

- El smoke test verifica el orden de los once autoloads.
- Verifica una ida y vuelta de `settings_changed`.
- Verifica las nueve secciones de diagnóstico.
- Verifica un guardado y una carga con checksum.
- Verifica el reporte local y el marcador de sesión.
- Verifica la apertura y el cierre del panel QA en build de depuración.
