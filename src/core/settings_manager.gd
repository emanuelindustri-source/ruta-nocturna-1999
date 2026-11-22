extends Node
## Persistencia de opciones, accesibilidad e input.
##
## No guarda partidas. Las claves visibles para el juego viven en secciones
## estables; los valores por defecto están aquí y no dispersos en la UI.

const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_BACKUP_PATH := "user://settings.cfg.bak"
const SETTINGS_TEMP_PATH := "user://settings.cfg.tmp"

const DEFAULTS := {
	"audio": {
		"master_volume": 0.8,
		"music_volume": 0.7,
		"sfx_volume": 0.8,
		"ambience_volume": 0.7,
		"voice_volume": 0.9,
		"ui_volume": 0.8,
		"engine_volume": 0.8,
		"muted": false,
	},
	"graphics": {
		"quality": "auto",
		"vsync": true,
		"fps_limit": 60,
		"weather_quality": "auto",
	},
	"accessibility": {
		"subtitles": true,
		"subtitle_size": 1.0,
		"high_contrast": false,
		"reduce_motion": false,
		"reduce_flashes": false,
		"colorblind_mode": "none",
	},
	"gameplay": {
		"language": "es_VE",
		"camera_shake": 1.0,
	},
	"network": {
		"check_updates": false,
	},
	"qa": {
		"test_mode": false,
	},
}

var _settings: Dictionary = {}
var _active_quality_profile := "desktop_balanced"


func _ready() -> void:
	_settings = _clone_defaults()
	load_settings()
	_active_quality_profile = _resolve_quality_profile()
	call_deferred("_announce_ready")


func get_value(section: String, key: String, fallback: Variant = null) -> Variant:
	if _settings.has(section) and _settings[section].has(key):
		return _settings[section][key]
	if fallback != null:
		return fallback
	if DEFAULTS.has(section) and DEFAULTS[section].has(key):
		return DEFAULTS[section][key]
	return null


func set_value(section: String, key: String, value: Variant, save_immediately: bool = true) -> bool:
	if not DEFAULTS.has(section) or not DEFAULTS[section].has(key):
		push_warning("SettingsManager: clave desconocida %s/%s" % [section, key])
		return false
	if typeof(value) != typeof(DEFAULTS[section][key]):
		push_warning(
			"SettingsManager: tipo inválido para %s/%s (%s)"
			% [section, key, type_string(typeof(value))]
		)
		return false
	if _settings[section].get(key) == value:
		return true
	_settings[section][key] = value
	if section == "graphics" and key == "quality":
		_active_quality_profile = _resolve_quality_profile()
	EventBus.settings_changed.emit(section, key, value)
	if save_immediately:
		save_settings()
	return true


func get_section(section: String) -> Dictionary:
	if not _settings.has(section):
		return {}
	return _settings[section].duplicate(true)


func get_active_quality_profile() -> String:
	return _active_quality_profile


func load_settings() -> bool:
	var config := ConfigFile.new()
	var error := config.load(SETTINGS_PATH)
	if error != OK:
		if error != ERR_FILE_NOT_FOUND:
			push_warning("SettingsManager: no se pudo leer %s (%s)" % [SETTINGS_PATH, error])
		_settings = _clone_defaults()
		return false
	for section in DEFAULTS.keys():
		for key in DEFAULTS[section].keys():
			if not config.has_section_key(section, key):
				continue
			var value: Variant = config.get_value(section, key)
			if typeof(value) != typeof(DEFAULTS[section][key]):
				push_warning("SettingsManager: se ignora %s/%s por tipo inválido" % [section, key])
				continue
			_settings[section][key] = value
	return true


func save_settings() -> bool:
	var config := ConfigFile.new()
	for section in _settings.keys():
		for key in _settings[section].keys():
			config.set_value(section, key, _settings[section][key])
	var temp_error := config.save(SETTINGS_TEMP_PATH)
	if temp_error != OK:
		push_error("SettingsManager: no se pudo escribir el temporal (%s)" % temp_error)
		return false
	var directory := DirAccess.open("user://")
	if directory == null:
		push_error("SettingsManager: no se pudo abrir user://")
		return false
	if directory.file_exists("settings.cfg.bak"):
		directory.remove("settings.cfg.bak")
	if directory.file_exists("settings.cfg"):
		var backup_error := directory.rename("settings.cfg", "settings.cfg.bak")
		if backup_error != OK:
			push_warning("SettingsManager: no se pudo respaldar settings.cfg (%s)" % backup_error)
	var rename_error := directory.rename("settings.cfg.tmp", "settings.cfg")
	if rename_error != OK:
		push_error("SettingsManager: no se pudo activar settings.cfg (%s)" % rename_error)
		return false
	return true


func reset_to_defaults() -> void:
	_settings = _clone_defaults()
	_active_quality_profile = _resolve_quality_profile()
	for section in _settings.keys():
		for key in _settings[section].keys():
			EventBus.settings_changed.emit(section, key, _settings[section][key])
	save_settings()


func get_diagnostics_context() -> Dictionary:
	return {
		"quality": get_value("graphics", "quality", "auto"),
		"active_quality_profile": _active_quality_profile,
		"language": get_value("gameplay", "language", "es_VE"),
		"test_mode": bool(get_value("qa", "test_mode", false)),
	}


func _announce_ready() -> void:
	for section in _settings.keys():
		for key in _settings[section].keys():
			EventBus.settings_changed.emit(section, key, _settings[section][key])
	EventBus.diagnostics_context_requested.connect(_on_diagnostics_context_requested)
	EventBus.diagnostics_context_updated.emit("settings", get_diagnostics_context())


func _resolve_quality_profile() -> String:
	var quality := str(get_value("graphics", "quality", "auto"))
	if quality != "auto":
		return quality
	var recommended := HardwareProfiler.get_recommended_profile()
	match recommended:
		HardwareProfiler.PROFILE_MOBILE_HIGH:
			return "high"
		HardwareProfiler.PROFILE_MOBILE_LOW:
			return "low"
		HardwareProfiler.PROFILE_DESKTOP_HIGH:
			return "high"
		_:
			return "medium"


func _clone_defaults() -> Dictionary:
	return DEFAULTS.duplicate(true)


func _on_diagnostics_context_requested() -> void:
	EventBus.diagnostics_context_updated.emit("settings", get_diagnostics_context())
