extends Node
## Estado base de clima: presets, humedad, viento, lluvia y niebla.
##
## No decide misiones ni dibuja VFX. En Fase 4.4 se conectarán las transiciones
## completas, los rayos y los shaders. WeatherManager y AudioDirector no se
## referencian entre sí; ambos consumen EventBus.

const PRESETS := {
	"clear": {"humidity": 0.45, "rain": 0.0, "wind": 4.0, "fog": 0.0, "temperature": 26.0, "lightning": false},
	"overcast": {"humidity": 0.65, "rain": 0.0, "wind": 6.0, "fog": 0.05, "temperature": 23.0, "lightning": false},
	"drizzle": {"humidity": 0.8, "rain": 0.25, "wind": 7.0, "fog": 0.1, "temperature": 21.0, "lightning": false},
	"rain": {"humidity": 0.9, "rain": 0.6, "wind": 10.0, "fog": 0.15, "temperature": 19.0, "lightning": false},
	"storm": {"humidity": 0.95, "rain": 0.9, "wind": 18.0, "fog": 0.2, "temperature": 18.0, "lightning": true},
	"fog": {"humidity": 0.92, "rain": 0.0, "wind": 2.0, "fog": 0.85, "temperature": 16.0, "lightning": false},
	"sandstorm": {"humidity": 0.2, "rain": 0.0, "wind": 22.0, "fog": 0.35, "temperature": 31.0, "lightning": false},
	"snow": {"humidity": 0.7, "rain": 0.0, "wind": 8.0, "fog": 0.25, "temperature": -2.0, "lightning": false},
	"swamp_mist": {"humidity": 0.98, "rain": 0.1, "wind": 1.0, "fog": 0.7, "temperature": 27.0, "lightning": false},
}

const TRANSITION_RATE := 0.55
const WETNESS_RATE := 0.08

var current_preset := "clear"
var _state: Dictionary = {}
var _target: Dictionary = {}


func _ready() -> void:
	_state = PRESETS["clear"].duplicate(true)
	_state["wetness"] = 0.0
	_target = _state.duplicate(true)
	set_process(false)
	EventBus.diagnostics_context_requested.connect(_on_diagnostics_context_requested)
	EventBus.diagnostics_context_updated.emit("weather", get_diagnostics_context())
	print("[WEATHER] preset inicial %s" % current_preset)


func _process(delta: float) -> void:
	var weight := clampf(delta * TRANSITION_RATE, 0.0, 1.0)
	var moving := false
	for key in ["humidity", "rain", "wind", "fog", "temperature"]:
		var current_value := float(_state.get(key, 0.0))
		var target_value := float(_target.get(key, current_value))
		var next_value := lerpf(current_value, target_value, weight)
		if absf(next_value - target_value) > 0.001:
			moving = true
		_state[key] = next_value
	var rain := float(_state.get("rain", 0.0))
	var wetness := float(_state.get("wetness", 0.0))
	_state["wetness"] = move_toward(wetness, rain, WETNESS_RATE * delta)
	_state["lightning"] = bool(_target.get("lightning", false))
	if not moving:
		for key in ["humidity", "rain", "wind", "fog", "temperature"]:
			_state[key] = float(_target.get(key, _state.get(key, 0.0)))
		set_process(false)
		EventBus.weather_changed.emit(current_preset, get_state())


func set_preset(preset: String, immediate: bool = false) -> bool:
	if not PRESETS.has(preset):
		push_warning("WeatherManager: preset desconocido %s" % preset)
		return false
	current_preset = preset
	_target = PRESETS[preset].duplicate(true)
	if immediate:
		_state = _target.duplicate(true)
		_state["wetness"] = float(_target.get("rain", 0.0))
		set_process(false)
		EventBus.weather_changed.emit(current_preset, get_state())
		EventBus.diagnostics_action.emit("weather_set", {"preset": preset, "immediate": true})
	else:
		set_process(true)
		EventBus.weather_changed.emit(current_preset, get_state())
		EventBus.diagnostics_action.emit("weather_set", {"preset": preset, "immediate": false})
	return true


func force_preset(preset: String) -> bool:
	return set_preset(preset, true)


func get_state() -> Dictionary:
	var state := _state.duplicate(true)
	state["preset"] = current_preset
	state["weather_quality"] = SettingsManager.get_value("graphics", "weather_quality", "auto")
	return state


func get_preset_names() -> PackedStringArray:
	var names := PackedStringArray()
	for key in PRESETS.keys():
		names.append(key)
	return names


func get_diagnostics_context() -> Dictionary:
	return {"preset": current_preset, "state": get_state()}


func _on_diagnostics_context_requested() -> void:
	EventBus.diagnostics_context_updated.emit("weather", get_diagnostics_context())
