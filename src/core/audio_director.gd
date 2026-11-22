extends Node
## Mezcla base. Crea los buses oficiales y aplica volúmenes persistidos.
##
## No ejecuta reglas de entidades ni conoce WeatherManager. Los ambientes y la
## música se conectarán por eventos en fases posteriores.

const BUS_TARGETS := {
	"Music": "music_volume",
	"SFX": "sfx_volume",
	"Ambience": "ambience_volume",
	"Voice": "voice_volume",
	"UI": "ui_volume",
	"Engine": "engine_volume",
}
const BUS_PARENTS := {
	"Music": "Master",
	"SFX": "Master",
	"Ambience": "Master",
	"Voice": "Master",
	"UI": "Master",
	"Engine": "SFX",
}


func _ready() -> void:
	_ensure_buses()
	apply_settings()
	EventBus.settings_changed.connect(_on_settings_changed)
	EventBus.diagnostics_context_requested.connect(_on_diagnostics_context_requested)
	EventBus.diagnostics_context_updated.emit("audio", get_diagnostics_context())


func apply_settings() -> void:
	var muted := bool(SettingsManager.get_value("audio", "muted", false))
	_apply_bus_volume("Master", float(SettingsManager.get_value("audio", "master_volume", 0.8)), muted)
	for bus_name in BUS_TARGETS.keys():
		var key: String = BUS_TARGETS[bus_name]
		var value := float(SettingsManager.get_value("audio", key, 0.8))
		_apply_bus_volume(bus_name, value, muted)


func set_bus_volume(bus_name: String, linear_volume: float) -> bool:
	if not BUS_TARGETS.has(bus_name):
		push_warning("AudioDirector: bus desconocido %s" % bus_name)
		return false
	var key: String = BUS_TARGETS[bus_name]
	return SettingsManager.set_value("audio", key, clampf(linear_volume, 0.0, 1.0))


func get_bus_volume(bus_name: String) -> float:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(index))


func has_bus(bus_name: String) -> bool:
	return AudioServer.get_bus_index(bus_name) >= 0


func get_diagnostics_context() -> Dictionary:
	var buses: Array = []
	for index in range(AudioServer.bus_count):
		buses.append(
			{
				"name": AudioServer.get_bus_name(index),
				"volume_db": AudioServer.get_bus_volume_db(index),
				"mute": AudioServer.is_bus_mute(index),
			}
		)
	return {"bus_count": AudioServer.bus_count, "buses": buses}


func _ensure_buses() -> void:
	for bus_name in BUS_PARENTS.keys():
		if AudioServer.get_bus_index(bus_name) >= 0:
			continue
		var index := AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, bus_name)
		var parent: String = BUS_PARENTS[bus_name]
		AudioServer.set_bus_send(index, parent)


func _apply_bus_volume(bus_name: String, linear_volume: float, master_muted: bool) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		push_warning("AudioDirector: falta el bus %s" % bus_name)
		return
	var clamped := clampf(linear_volume, 0.0, 1.0)
	var volume_db := linear_to_db(maxf(clamped, 0.0001))
	AudioServer.set_bus_volume_db(index, volume_db)
	var muted := master_muted or clamped <= 0.0001
	AudioServer.set_bus_mute(index, muted)
	EventBus.audio_bus_volume_changed.emit(bus_name, volume_db)


func _on_settings_changed(section: String, _key: String, _value: Variant) -> void:
	if section == "audio":
		apply_settings()


func _on_diagnostics_context_requested() -> void:
	EventBus.diagnostics_context_updated.emit("audio", get_diagnostics_context())
