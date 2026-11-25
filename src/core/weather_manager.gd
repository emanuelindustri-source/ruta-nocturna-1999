extends Node
## Estado meteorológico real de Ruta Nocturna: 1999 (F1.2 base, F4.4 real).
##
## Consume `data/schemas/world_weather.json` (contrato `world.weather` v1), que a
## su vez referencia `world.biomes` (región → bioma, presets agua/polvo/nieve) y
## `rain_surface_fx` (lluvia normalizada → mm/h). Publica el estado por
## `EventBus.weather_changed` y los rayos por `EventBus.weather_lightning`.
##
## No dibuja VFX, no reproduce audio, no decide misiones ni simula agarre/vadeo
## (F5.1). `AudioDirector` y `WeatherManager` no se referencian entre sí; los
## servicios de escena (LightningDirector, RainFxController, mapa) consumen el
## bus o reciben el estado desde `WorldDirector`.

signal lightning_struck(strike: Dictionary)

const CONTRACT_PATH := "res://data/schemas/world_weather.json"
const BIOMES_PATH := "res://data/schemas/world_biomes.json"
const REGIONS := ["carabobo", "falcon", "merida", "llanos", "amazonas", "delta"]

## Respaldo mínimo si el contrato no está disponible (no es la fuente de verdad).
const FALLBACK_TRANSITION := {
	"rate_per_s": 0.55,
	"wetness_rate_per_s": 0.08,
	"min_visible_change": 0.001,
	"hysteresis": 0.02,
	"auto_advance": false,
	"auto_advance_s": [45.0, 120.0],
	"region_change_immediate": true,
	"region_change_rate_per_s": 1.2,
}

var contract: Dictionary = {}
var presets: Dictionary = {}
var biome_profiles: Dictionary = {}
var region_biome_map: Dictionary = {}
var transition: Dictionary = FALLBACK_TRANSITION.duplicate(true)
var lightning_config: Dictionary = {}
var errors: Array[String] = []

var current_preset := "clear"
var region_id := ""
var biome_id := ""
var strikes := 0
var last_strike: Dictionary = {}
var revision := 0

var _state: Dictionary = {}
var _target: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _seed := 1999
var _source_rate := 0.55
var _wetness_rate := 0.08
var _auto_advance := false
var _auto_advance_range := Vector2(45.0, 120.0)
var _auto_timer := 0.0
var _lightning_timer := 0.0
var _lightning_elapsed := 0.0
var _minute_strikes: Array[float] = []
var _last_cue_ms := -100000
var _diagnostics_requested := false


func _ready() -> void:
	_rng.seed = _seed
	load_contract()
	_state = _default_state()
	_target = _state.duplicate(true)
	EventBus.diagnostics_context_requested.connect(_on_diagnostics_context_requested)
	EventBus.diagnostics_context_updated.emit("weather", get_diagnostics_context())
	print(
		"[WEATHER] ready presets=%d biomes=%d preset=%s region=%s"
		% [presets.size(), biome_profiles.size(), current_preset, region_id]
	)


func load_contract() -> bool:
	contract = _read_json(CONTRACT_PATH)
	if contract.is_empty():
		errors.append("world_weather.json no disponible")
		return false
	if str(contract.get("contract_id", "")) != "world.weather":
		errors.append("contract_id world.weather inválido")
		return false
	if int(contract.get("schema_version", 0)) != 1:
		errors.append("schema_version de world.weather distinto de 1")
		return false
	presets = contract.get("presets", {}).duplicate(true)
	biome_profiles = contract.get("biome_profiles", {}).duplicate(true)
	transition = contract.get("transition", FALLBACK_TRANSITION).duplicate(true)
	lightning_config = contract.get("lightning", {}).duplicate(true)
	_source_rate = float(transition.get("rate_per_s", 0.55))
	_wetness_rate = float(transition.get("wetness_rate_per_s", 0.08))
	_auto_advance = bool(transition.get("auto_advance", false))
	var auto_range: Array = transition.get("auto_advance_s", [45.0, 120.0])
	_auto_advance_range = Vector2(float(auto_range[0]), float(auto_range[1]))
	var biomes := _read_json(BIOMES_PATH)
	region_biome_map = biomes.get("region_biome_map", {}).duplicate(true)
	if presets.is_empty():
		errors.append("sin presets de clima")
		return false
	_reset_auto_timer()
	_reset_lightning_timer()
	return true


## Entrada declarativa del mundo: región de la red F4.1.
func set_region(new_region: String, immediate: bool = false) -> bool:
	var region := new_region.trim_prefix("region.")
	if not REGIONS.has(region):
		push_warning("WeatherManager: región desconocida %s" % new_region)
		return false
	if region == region_id and not biome_id.is_empty():
		return true
	region_id = region
	var biome := str(region_biome_map.get(region, ""))
	if biome.is_empty() or not biome_profiles.has(biome):
		errors.append("sin perfil de clima para la región %s" % region)
		return false
	return set_biome(biome, immediate)


func set_biome(new_biome: String, immediate: bool = false) -> bool:
	if not biome_profiles.has(new_biome):
		push_warning("WeatherManager: bioma sin perfil %s" % new_biome)
		return false
	biome_id = new_biome
	var profile: Dictionary = biome_profiles[biome_id]
	region_id = str(profile.get("region", region_id))
	_rng.seed = _seed + biome_id.hash() + region_id.hash()
	_reset_auto_timer()
	var preset := _pick_preset(profile)
	return _apply_preset(preset, immediate, profile)


## Cambio explícito (QA, guion o prueba). Mantiene la compatibilidad de F1.2.
func set_preset(preset: String, immediate: bool = false) -> bool:
	if not presets.has(preset):
		push_warning("WeatherManager: preset desconocido %s" % preset)
		return false
	var profile: Dictionary = biome_profiles.get(biome_id, {})
	return _apply_preset(preset, immediate, profile)


func force_preset(preset: String) -> bool:
	return set_preset(preset, true)


## Fija una semilla determinista (pruebas y QA reproducible).
func set_seed(value: int) -> void:
	_seed = value
	_rng.seed = value + biome_id.hash() + region_id.hash()


func _apply_preset(preset: String, immediate: bool, profile: Dictionary) -> bool:
	current_preset = preset
	revision += 1
	var base: Dictionary = presets[preset]
	var bias_temp := float(profile.get("temperature_bias_c", 0.0))
	var bias_humidity := float(profile.get("humidity_bias", 0.0))
	var bias_wind := float(profile.get("wind_bias_mps", 0.0))
	_target = {
		"humidity": clampf(float(base.get("humidity", 0.5)) + bias_humidity, 0.0, 1.0),
		"rain": clampf(float(base.get("rain", 0.0)), 0.0, 1.0),
		"wind": clampf(float(base.get("wind_mps", 4.0)) + bias_wind, 0.0, 25.0),
		"fog": clampf(float(base.get("fog", 0.0)), 0.0, 1.0),
		"temperature": float(base.get("temperature_c", 24.0)) + bias_temp,
		"wetness_target": clampf(float(base.get("wetness_target", 0.0)), 0.0, 1.0),
		"lightning": bool(base.get("lightning", false)),
	}
	_reset_lightning_timer()
	_reset_auto_timer()
	if immediate:
		for key in ["humidity", "rain", "wind", "fog", "temperature"]:
			_state[key] = _target[key]
		_state["lightning"] = bool(_target["lightning"])
		_state["wetness"] = float(_target["wetness_target"])
		_source_rate = float(transition.get("rate_per_s", 0.55))
		_state["transition"] = "idle"
	else:
		_state["transition"] = "blending"
		# Al cambiar de bioma la mezcla se acelera para no arrastrar un clima
		# incoherente a través del límite regional.
		_source_rate = (
			float(transition.get("region_change_rate_per_s", 1.2))
			if biome_id != ""
			else float(transition.get("rate_per_s", 0.55))
		)
		_source_rate = maxf(_source_rate, float(transition.get("rate_per_s", 0.55)))
	EventBus.weather_changed.emit(current_preset, get_state())
	EventBus.diagnostics_action.emit(
		"weather_set", {"preset": preset, "immediate": immediate, "biome": biome_id}
	)
	return true


func _process(delta: float) -> void:
	step(delta)


## Paso público determinista: usado por `_process` y por las pruebas.
func step(delta: float) -> void:
	if delta <= 0.0:
		return
	var dt := minf(delta, 1.0)
	var weight := 1.0 - exp(-_source_rate * dt)
	var moving := false
	for key in ["humidity", "rain", "wind", "fog", "temperature"]:
		var current_value := float(_state.get(key, 0.0))
		var target_value := float(_target.get(key, current_value))
		var next_value := lerpf(current_value, target_value, weight)
		if absf(next_value - target_value) > float(transition.get("min_visible_change", 0.001)):
			moving = true
		_state[key] = next_value
	var wetness := float(_state.get("wetness", 0.0))
	var wet_target := float(_target.get("wetness_target", 0.0))
	_state["wetness"] = move_toward(wetness, wet_target, _wetness_rate * dt)
	if not moving:
		for key in ["humidity", "rain", "wind", "fog", "temperature"]:
			_state[key] = float(_target.get(key, _state.get(key, 0.0)))
	_state["transition"] = "blending" if moving else "idle"
	_state["lightning"] = bool(_target.get("lightning", false))

	_update_wind_direction(dt)
	_update_lightning(dt)
	if _auto_advance:
		_auto_timer -= dt
		if _auto_timer <= 0.0:
			advance_weather()


## Avanza al siguiente preset del perfil activo (clima automático).
func advance_weather() -> String:
	if not biome_profiles.has(biome_id):
		return current_preset
	var next := _pick_preset(biome_profiles[biome_id])
	_apply_preset(next, false, biome_profiles[biome_id])
	print("[WEATHER] advance biome=%s preset=%s" % [biome_id, next])
	return next


func _pick_preset(profile: Dictionary) -> String:
	var entries: Array = profile.get("presets", [])
	if entries.is_empty():
		return str(profile.get("base", "clear"))
	var roll := _rng.randf()
	var cumulative := 0.0
	for entry in entries:
		cumulative += float(entry.get("weight", 0.0))
		if roll <= cumulative:
			return str(entry.get("id", profile.get("base", "clear")))
	return str(entries[entries.size() - 1].get("id", profile.get("base", "clear")))


func _reset_auto_timer() -> void:
	var span := maxf(0.0, _auto_advance_range.y - _auto_advance_range.x)
	_auto_timer = _auto_advance_range.x + _rng.randf() * span


func _reset_lightning_timer() -> void:
	_lightning_timer = 0.0
	if not bool(_target.get("lightning", false)) or not bool(lightning_config.get("enabled", false)):
		return
	var interval: Array = lightning_config.get("interval_s", [4.0, 11.0])
	_lightning_timer = _rand_range(float(interval[0]), float(interval[1]))


func _update_lightning(dt: float) -> void:
	_lightning_elapsed += dt
	_prune_strike_window()
	if not bool(_target.get("lightning", false)):
		_lightning_timer = 0.0
		return
	if not bool(lightning_config.get("enabled", true)):
		return
	if _lightning_timer <= 0.0:
		_reset_lightning_timer()
	_lightning_timer -= dt
	if _lightning_timer <= 0.0:
		force_lightning()


## Rayo determinista para QA y pruebas. Devuelve el golpe publicado.
func force_lightning() -> Dictionary:
	if not bool(lightning_config.get("enabled", true)):
		return {}
	if not bool(_target.get("lightning", false)):
		return {}
	_prune_strike_window()
	if _minute_strikes.size() >= int(lightning_config.get("max_strikes_per_minute", 12)):
		_reset_lightning_timer()
		return {}
	var distance_range: Array = lightning_config.get("distance_km", [0.8, 6.0])
	var distance := _rand_range(float(distance_range[0]), float(distance_range[1]))
	var double_flash := _rng.randf() < float(lightning_config.get("double_flash_chance", 0.35))
	var strike := {
		"index": strikes + 1,
		"distance_km": snappedf(distance, 0.01),
		"delay_s": snappedf(
			distance * float(lightning_config.get("thunder_delay_s_per_km", 2.9)), 0.01
		),
		"energy": float(lightning_config.get("light_energy", 9.0)),
		"flash_duration_s": float(lightning_config.get("flash_duration_s", 0.18)),
		"double_flash": double_flash,
		"gap_s": float(lightning_config.get("double_flash_gap_s", 0.09)),
		"preset": current_preset,
		"biome": biome_id,
	}
	strikes += 1
	last_strike = strike
	_minute_strikes.append(_lightning_elapsed)
	EventBus.weather_lightning.emit(strike)
	lightning_struck.emit(strike)
	var now_ms := Time.get_ticks_msec()
	var cue_interval_ms := int(
		float(lightning_config.get("accessibility_cue", {}).get("min_interval_s", 2.0)) * 1000.0
	)
	if now_ms - _last_cue_ms >= cue_interval_ms:
		_last_cue_ms = now_ms
		EventBus.accessibility_cue.emit(
			str(lightning_config.get("accessibility_cue", {}).get("kind", "lightning")),
			Vector3.ZERO,
			clampf(1.0 - distance / 6.0, 0.0, 1.0)
		)
	EventBus.diagnostics_action.emit("weather_lightning", strike)
	_reset_lightning_timer()
	return strike


func _prune_strike_window() -> void:
	var cutoff := _lightning_elapsed - 60.0
	while not _minute_strikes.is_empty() and _minute_strikes[0] < cutoff:
		_minute_strikes.remove_at(0)


func _update_wind_direction(dt: float) -> void:
	var angle := float(_state.get("wind_direction_rad", 0.0))
	angle += dt * (0.05 + float(_state.get("wind", 0.0)) * 0.004)
	_state["wind_direction_rad"] = wrapf(angle, -PI, PI)


func get_state() -> Dictionary:
	var state := _state.duplicate(true)
	state["preset"] = current_preset
	state["region"] = region_id
	state["biome"] = biome_id
	state["wind_mps"] = float(_state.get("wind", 0.0))
	state["temperature_c"] = float(_state.get("temperature", 0.0))
	state["next_change_in_s"] = snappedf(maxf(0.0, _auto_timer), 0.1) if _auto_advance else -1.0
	state["weather_quality"] = SettingsManager.get_value("graphics", "weather_quality", "auto")
	return state


func get_preset_names() -> PackedStringArray:
	var names := PackedStringArray()
	for key in presets.keys():
		names.append(key)
	return names


func get_biome_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for key in biome_profiles.keys():
		ids.append(key)
	return ids


func get_biome_for_region(region: String) -> String:
	return str(region_biome_map.get(region.trim_prefix("region."), ""))


func get_lightning_config() -> Dictionary:
	return lightning_config.duplicate(true)


func get_transition_config() -> Dictionary:
	return transition.duplicate(true)


func get_diagnostics_context() -> Dictionary:
	return {
		"preset": current_preset,
		"region": region_id,
		"biome": biome_id,
		"state": get_state(),
		"strikes": strikes,
	}


func _default_state() -> Dictionary:
	return {
		"humidity": 0.45,
		"rain": 0.0,
		"wind": 4.0,
		"fog": 0.0,
		"temperature": 26.0,
		"wetness": 0.0,
		"lightning": false,
		"transition": "idle",
		"wind_direction_rad": 0.0,
	}


func _rand_range(low: float, high: float) -> float:
	if high <= low:
		return low
	return low + _rng.randf() * (high - low)


func _on_diagnostics_context_requested() -> void:
	EventBus.diagnostics_context_updated.emit("weather", get_diagnostics_context())


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
