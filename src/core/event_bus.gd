extends Node
## Mediador oficial de señales de Ruta Nocturna: 1999.
##
## EventBus no conoce reglas de juego, no lee archivos y no llama a otros
## autoloads. Los servicios publican y escuchan señales; la UI emite comandos.
## El catálogo completo vive en docs/architecture/EVENT_BUS.md.

# --- Ciclo de vida -----------------------------------------------------------

signal application_booted(version: String)
signal application_quitting()
signal scene_change_requested(path: String, reason: String)
signal scene_changed(path: String)
signal scene_load_failed(path: String, reason: String)
signal loading_progress(path: String, progress: float)

# --- Ajustes e idioma --------------------------------------------------------

signal settings_changed(section: String, key: String, value: Variant)
signal locale_changed(locale: String)
signal accessibility_changed(settings: Dictionary)

# --- Guardado ----------------------------------------------------------------

signal save_requested(slot: int, reason: String)
signal save_completed(slot: int, path: String)
signal save_failed(slot: int, reason: String)
signal load_requested(slot: int)
signal load_completed(slot: int, snapshot: Dictionary)
signal load_failed(slot: int, reason: String)

# --- Estado de juego ---------------------------------------------------------

signal game_state_changed(key: String, value: Variant)
signal flag_changed(flag: String, enabled: bool)
signal mission_changed(mission_id: String, stage: String)
signal trust_changed(passenger_id: String, value: float)
signal humanity_changed(value: float)
signal game_state_loaded(source: String)
signal flags_cleared()
signal mode_changed(mode: String)
signal test_mode_changed(enabled: bool)

# --- Clima -------------------------------------------------------------------

signal weather_changed(preset: String, state: Dictionary)

# --- Audio y accesibilidad ---------------------------------------------------

signal audio_bus_volume_changed(bus_name: String, volume_db: float)
signal accessibility_cue(kind: String, direction: Vector3, intensity: float)

# --- Actualizaciones ---------------------------------------------------------

signal update_available(version: String, url: String)
signal update_check_finished(status: String, detail: String)

# --- Diagnóstico y caja negra ------------------------------------------------

signal diagnostics_context_requested()
signal diagnostics_context_updated(section: String, data: Dictionary)
signal diagnostics_action(action: String, details: Dictionary)
signal crash_report_requested(reason: String)
signal crash_report_written(path: String, reason: String)
signal performance_warning(metric: String, value: float, threshold: float)

# --- Panel de creador --------------------------------------------------------

signal qa_menu_toggled(is_open: bool)
signal qa_action_completed(action: String, result: Dictionary)
