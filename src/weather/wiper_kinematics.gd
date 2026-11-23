class_name WiperKinematics
extends RefCounted
## Cinemática de los dos limpiaparabrisas del Esteem (F3.3).
##
## Barrido con perfil smoothstep, modos off/intermitente/lenta/rápida, pausa de
## intermitencia y desgaste de la goma. Limpia gotas en el sector barrido del
## parabrisas. No crea controles de cabina ni toca el GLSL: F3.4 dibuja el
## barrido y F5.1 podrá reparar la goma.

const MODES := ["off", "intermittent", "low", "high"]
const STATE_OFF := "off"
const STATE_WAIT := "intermittent_wait"
const STATE_SWEEP := "sweeping"
const STATE_PARK := "parked"

var spec: RainSurfaceSpec
var errors: PackedStringArray = []

var mode := "off"
var intermittent_index := 1

var _wipers: Array[Dictionary] = []
var _phase := 0.0
var _pause_left := 0.0
var _cycle_count := 0
var _wear := 0.0
var _state := STATE_OFF
var _angles := PackedFloat32Array()
var _previous_angles := PackedFloat32Array()
var _low_cycles_per_min := 45.0
var _high_cycles_per_min := 70.0
var _delays: Array[float] = []
var _ease_smoothstep := true
var _per_1000_cycles := 0.015
var _service_limit := 0.7
var _replace_limit := 0.9
var _clearing_loss_at_full_wear := 0.38
var _streak_gain_at_full_wear := 0.22
var _max_step_s := 0.25


func configure(source_spec: RainSurfaceSpec = null) -> bool:
	errors.clear()
	_wipers.clear()
	spec = source_spec if source_spec != null else RainSurfaceSpec.new()
	if spec.data.is_empty() and not spec.load_spec():
		errors.append_array(spec.errors)
		return false
	var wiper_section := spec.section("wiper")
	var entries: Array = wiper_section.get("wipers", [])
	if entries.size() != 2:
		errors.append("wiper.wipers")
		return false
	for entry in entries:
		if not (entry is Dictionary):
			errors.append("wiper.entry")
			return false
		var pivot_values: Array = entry.get("pivot_uv", [0.5, 0.0])
		var pivot := Vector2(float(pivot_values[0]), float(pivot_values[1]))
		_wipers.append({
			"id": str(entry.get("id", "")),
			"node_hint": str(entry.get("node_hint", "")),
			"pivot_uv": pivot,
			"blade_length_m": maxf(0.01, float(entry.get("blade_length_m", 0.46))),
			"rest_angle_deg": float(entry.get("rest_angle_deg", 0.0)),
			"sweep_delta_deg": float(entry.get("sweep_delta_deg", 90.0)),
			"park_angle_deg": float(entry.get("park_angle_deg", 0.0)),
			"clearing_new": clampf(float(entry.get("clearing_efficiency_new", 0.94)), 0.0, 1.0),
			"clearing_worn": clampf(float(entry.get("clearing_efficiency_worn", 0.62)), 0.0, 1.0),
		})
	var modes: Dictionary = wiper_section.get("modes", {})
	_low_cycles_per_min = maxf(0.0, float(modes.get("low", {}).get("cycles_per_min", 45.0)))
	_high_cycles_per_min = maxf(_low_cycles_per_min, float(modes.get("high", {}).get("cycles_per_min", 70.0)))
	_delays.clear()
	for delay in modes.get("intermittent", {}).get("delays_s", []):
		_delays.append(float(delay))
	if _delays.is_empty():
		_delays.append(4.0)
	intermittent_index = clampi(int(modes.get("intermittent", {}).get("default_index", 0)), 0, _delays.size() - 1)
	_ease_smoothstep = str(wiper_section.get("ease_profile", "smoothstep")) != "linear"
	var wear_section: Dictionary = wiper_section.get("wear", {})
	_per_1000_cycles = maxf(0.0, float(wear_section.get("per_1000_cycles", 0.015)))
	_service_limit = clampf(float(wear_section.get("service_limit", 0.7)), 0.0, 1.0)
	_replace_limit = clampf(float(wear_section.get("replace_limit", 0.9)), _service_limit, 1.0)
	_clearing_loss_at_full_wear = clampf(float(wear_section.get("clearing_loss_at_full_wear", 0.38)), 0.0, 1.0)
	_streak_gain_at_full_wear = clampf(float(wear_section.get("streak_gain_at_full_wear", 0.22)), 0.0, 1.0)
	_max_step_s = maxf(0.001, float(spec.number("precipitation.max_step_s", 0.25)))
	_angles.resize(_wipers.size())
	_previous_angles.resize(_wipers.size())
	reset()
	return errors.is_empty()


func reset() -> void:
	mode = "off"
	_phase = 0.0
	_pause_left = 0.0
	_cycle_count = 0
	_wear = 0.0
	_state = STATE_OFF
	for index in range(_wipers.size()):
		_angles[index] = float(_wipers[index]["park_angle_deg"])
		_previous_angles[index] = _angles[index]


func set_mode(new_mode: String) -> bool:
	if not MODES.has(new_mode):
		return false
	if new_mode == mode:
		return true
	mode = new_mode
	_phase = 0.0
	_pause_left = 0.0
	for index in range(_wipers.size()):
		_angles[index] = float(_wipers[index]["park_angle_deg"])
		_previous_angles[index] = _angles[index]
	if mode == "off":
		_state = STATE_OFF
	elif mode == "intermittent":
		_state = STATE_WAIT
		_pause_left = _delays[intermittent_index]
	else:
		_state = STATE_PARK
	return true


func set_intermittent_index(index: int) -> bool:
	if index < 0 or index >= _delays.size():
		return false
	intermittent_index = index
	if mode == "intermittent" and _pause_left > 0.0:
		_pause_left = _delays[intermittent_index]
	return true


func step(delta: float, field: DropletFlowModel = null) -> void:
	if delta <= 0.0:
		return
	var dt := minf(delta, _max_step_s)
	if mode == "off":
		_phase = 0.0
		_pause_left = 0.0
		_state = STATE_OFF
		_park_all()
		_apply_field(field, 0.0)
		return
	if mode == "intermittent" and _pause_left > 0.0:
		_pause_left = maxf(0.0, _pause_left - dt)
		_state = STATE_WAIT
		_park_all()
		_apply_field(field, 0.0)
		if _pause_left > 0.0:
			return
	var cycles_per_min := _high_cycles_per_min if mode == "high" else _low_cycles_per_min
	if cycles_per_min <= 0.0:
		_state = STATE_PARK
		return
	_phase += cycles_per_min * dt / 60.0
	var completed := false
	while _phase >= 1.0:
		_phase -= 1.0
		completed = true
	if completed:
		_cycle_count += 1
		_wear = minf(1.0, _wear + _per_1000_cycles / 1000.0)
		if mode == "intermittent":
			_pause_left = _delays[intermittent_index]
	_state = STATE_SWEEP if _phase > 0.0 else (STATE_WAIT if mode == "intermittent" else STATE_PARK)
	_update_angles()
	_apply_field(field, dt)


func _park_all() -> void:
	for index in range(_wipers.size()):
		_angles[index] = float(_wipers[index]["park_angle_deg"])
		_previous_angles[index] = _angles[index]


func _update_angles() -> void:
	var u := _phase * 2.0 if _phase < 0.5 else (1.0 - _phase) * 2.0
	u = clampf(u, 0.0, 1.0)
	var eased := u * u * (3.0 - 2.0 * u) if _ease_smoothstep else u
	for index in range(_wipers.size()):
		var entry: Dictionary = _wipers[index]
		_previous_angles[index] = _angles[index]
		_angles[index] = float(entry["rest_angle_deg"]) + float(entry["sweep_delta_deg"]) * eased


func _apply_field(field: DropletFlowModel, dt: float) -> void:
	if field == null:
		return
	var bounds := field.get_bounds_mm()
	var efficiency := get_clearing_efficiency()
	for index in range(_wipers.size()):
		var entry: Dictionary = _wipers[index]
		var pivot_uv: Vector2 = entry["pivot_uv"]
		var pivot := Vector2(pivot_uv.x * bounds.x, pivot_uv.y * bounds.y)
		var radius_mm := float(entry["blade_length_m"]) * 1000.0
		var start := deg_to_rad(float(_previous_angles[index]))
		var end := deg_to_rad(float(_angles[index]))
		if absf(end - start) > 0.00001:
			field.clear_sector(pivot, radius_mm, start, end, efficiency)


func get_angle(index: int) -> float:
	if index < 0 or index >= _angles.size():
		return 0.0
	return _angles[index]


func get_state() -> String:
	return _state


func get_mode() -> String:
	return mode


func get_cycle_count() -> int:
	return _cycle_count


func get_wear() -> float:
	return _wear


func set_wear(value: float) -> void:
	_wear = clampf(value, 0.0, 1.0)


func get_clearing_efficiency() -> float:
	var base_new := 0.94
	var base_worn := 0.62
	if not _wipers.is_empty():
		base_new = float(_wipers[0]["clearing_new"])
		base_worn = float(_wipers[0]["clearing_worn"])
	return lerpf(base_new, base_worn, _wear)


func get_streak_factor() -> float:
	return _streak_gain_at_full_wear * _wear


func is_service_limit() -> bool:
	return _wear >= _service_limit


func is_replace_limit() -> bool:
	return _wear >= _replace_limit


func get_wiper_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for entry in _wipers:
		ids.append(str(entry["id"]))
	return ids


func get_wiper_count() -> int:
	return _wipers.size()
