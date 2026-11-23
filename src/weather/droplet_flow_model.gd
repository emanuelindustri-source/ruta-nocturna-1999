class_name DropletFlowModel
extends RefCounted
## Gotas de lluvia sobre una superficie 2D (F3.3).
##
## Nucleación determinista, crecimiento por película, desliz por gravedad y
## viento, evaporación y escurrido. No dibuja gotas: expone un búfer plano para
## que F3.4 lo convierta en uniforms del shader. La fusión visual de gotas
## vecinas queda para el GLSL de F3.4; aquí cada gota es independiente para que
## el coste CPU sea medible.

const STATE_NUCLEATED := 0
const STATE_GROWING := 1
const STATE_SLIDING := 2
const STATE_EVAPORATING := 3
const STATE_NAMES := ["nucleated", "growing", "sliding", "evaporating"]

var spec: RainSurfaceSpec
var profile: Dictionary = {}
var panel: Dictionary = {}
var errors: PackedStringArray = []

var count := 0
var max_droplets := 0

var _x := PackedFloat32Array()
var _y := PackedFloat32Array()
var _r := PackedFloat32Array()
var _vx := PackedFloat32Array()
var _vy := PackedFloat32Array()
var _age := PackedFloat32Array()
var _state := PackedByteArray()

var _seed := 1999
var _rng_state := 1999
var _spawn_budget := 0.0
var _runoff_ml := 0.0
var _flow := Vector2(0.0, -1.0)
var _lateral := Vector2(1.0, 0.0)
var _bounds := Vector2(1000.0, 1000.0)
var _max_step_s := 0.25
var _area_m2 := 1.0
var _initial_radius_mm := 0.1
var _min_radius_mm := 0.05
var _max_radius_mm := 3.0
var _growth_wetness := 0.2
var _nucleation_wetness := 0.1
var _nucleation_per_m2_s := 60.0
var _growth_mm_per_s := 0.4
var _critical_radius_mm := 1.8
var _slide_wetness_gain := 0.5
var _terminal_speed_mps := 0.35
var _accel_mps2 := 0.8
var _evaporation_shrink_mm_per_s := 0.06
var _wind_drift_per_mps := 0.01
var _max_wind_mps := 25.0


func configure(
	source_spec: RainSurfaceSpec = null,
	profile_id: String = "glass",
	panel_id: String = "windshield",
	capacity_override: int = 0
) -> bool:
	errors.clear()
	profile.clear()
	panel.clear()
	count = 0
	spec = source_spec if source_spec != null else RainSurfaceSpec.new()
	if spec.data.is_empty() and not spec.load_spec():
		errors.append_array(spec.errors)
		return false
	profile = spec.droplet_profile(profile_id)
	if profile.is_empty():
		errors.append("profile:%s" % profile_id)
		return false
	panel = spec.panel_spec(panel_id)
	_area_m2 = maxf(0.0001, float(panel.get("area_m2", profile.get("area_m2", 1.0))))
	var bounds_value: Array = profile.get("bounds_m", [1.0, 1.0])
	_bounds = Vector2(float(bounds_value[0]), float(bounds_value[1])) if bounds_value.size() == 2 else Vector2.ONE
	var flow_value: Array = panel.get("flow_dir", [0.0, -1.0])
	_flow = Vector2(float(flow_value[0]), float(flow_value[1])) if flow_value.size() == 2 else Vector2(0.0, -1.0)
	if _flow.length_squared() < 0.0001:
		_flow = Vector2(0.0, -1.0)
	_flow = _flow.normalized()
	_lateral = Vector2(-_flow.y, _flow.x)
	_max_step_s = maxf(0.001, float(spec.number("precipitation.max_step_s", 0.25)))
	_max_wind_mps = maxf(0.001, float(spec.number("precipitation.max_wind_mps", 25.0)))
	_initial_radius_mm = maxf(0.001, float(profile.get("initial_radius_mm", 0.12)))
	_min_radius_mm = maxf(0.001, float(profile.get("min_radius_mm", 0.05)))
	_max_radius_mm = maxf(_initial_radius_mm, float(profile.get("max_radius_mm", 3.0)))
	_growth_wetness = clampf(float(profile.get("growth_wetness", 0.2)), 0.0, 1.0)
	_nucleation_wetness = clampf(float(profile.get("nucleation_wetness", 0.1)), 0.0, 1.0)
	_nucleation_per_m2_s = maxf(0.0, float(profile.get("nucleation_per_m2_s", 60.0)))
	_growth_mm_per_s = maxf(0.0, float(profile.get("growth_mm_per_s", 0.4)))
	_critical_radius_mm = maxf(0.001, float(profile.get("critical_radius_mm", 1.8)))
	_slide_wetness_gain = clampf(float(profile.get("slide_wetness_gain", 0.5)), 0.0, 1.0)
	_terminal_speed_mps = maxf(0.001, float(profile.get("terminal_speed_mps", 0.35)))
	_accel_mps2 = maxf(0.001, float(profile.get("accel_mps2", 0.8)))
	_evaporation_shrink_mm_per_s = maxf(0.0, float(profile.get("evaporation_shrink_mm_per_s", 0.06)))
	_wind_drift_per_mps = maxf(0.0, float(profile.get("wind_drift_per_mps", 0.01)))
	_seed = int(profile.get("seed", 1999))
	max_droplets = capacity_override if capacity_override > 0 else int(profile.get("max_droplets", 1))
	max_droplets = maxi(1, max_droplets)
	_x.resize(max_droplets)
	_y.resize(max_droplets)
	_r.resize(max_droplets)
	_vx.resize(max_droplets)
	_vy.resize(max_droplets)
	_age.resize(max_droplets)
	_state.resize(max_droplets)
	reset(_seed)
	return errors.is_empty()


func reset(seed_value: int = -1) -> void:
	count = 0
	_spawn_budget = 0.0
	_runoff_ml = 0.0
	_rng_state = (seed_value if seed_value >= 0 else _seed) & 0x7FFFFFFF
	if _rng_state == 0:
		_rng_state = 1999


func _randf() -> float:
	# LCG determinista: no depende de RandomNumberGenerator ni del sistema.
	_rng_state = int((_rng_state * 1664525 + 1013904223) & 0x7FFFFFFF)
	return float(_rng_state) / float(0x7FFFFFFF)


func step(delta: float, wetness_value: float, rain_intensity: float, wind_mps: float) -> void:
	if delta <= 0.0:
		return
	var dt := minf(delta, _max_step_s)
	var wetness := clampf(wetness_value, 0.0, 1.0)
	var rain := clampf(rain_intensity, 0.0, 1.0)
	var wind := clampf(wind_mps, 0.0, _max_wind_mps)
	if wetness > _nucleation_wetness and rain > 0.0 and count < max_droplets:
		var wet_excess := clampf(
			(wetness - _nucleation_wetness) / maxf(0.001, 1.0 - _nucleation_wetness),
			0.0,
			1.0
		)
		var rate := _nucleation_per_m2_s * _area_m2 * rain * wet_excess
		_spawn_budget += rate * dt
		var spawns := 0
		while _spawn_budget >= 1.0 and count < max_droplets and spawns < 128:
			_spawn_budget -= 1.0
			_spawn_one()
			spawns += 1
	else:
		_spawn_budget = minf(_spawn_budget, 0.99)

	var flow_speed := _flow
	var wind_drift := _lateral * (wind * _wind_drift_per_mps)
	var direction := (flow_speed + wind_drift)
	if direction.length_squared() < 0.0001:
		direction = _flow
	else:
		direction = direction.normalized()
	var terminal_x := direction.x * _terminal_speed_mps
	var terminal_y := direction.y * _terminal_speed_mps
	var critical := _critical_radius_mm * (1.0 - _slide_wetness_gain * wetness)
	var growth_factor := 0.0
	if wetness > _growth_wetness:
		growth_factor = clampf(
			(wetness - _growth_wetness) / maxf(0.001, 1.0 - _growth_wetness),
			0.0,
			1.0
		)
	var evaporation_factor := 0.0
	if wetness < _nucleation_wetness:
		evaporation_factor = clampf(1.0 - wetness / maxf(0.001, _nucleation_wetness), 0.0, 1.0)

	var index := 0
	while index < count:
		var radius := _r[index]
		var state := int(_state[index])
		if state != STATE_SLIDING:
			if growth_factor > 0.0:
				radius += _growth_mm_per_s * growth_factor * dt
				state = STATE_GROWING if state != STATE_EVAPORATING else state
			if radius >= critical and wetness >= _nucleation_wetness:
				state = STATE_SLIDING
				_age[index] = 0.0
			elif evaporation_factor > 0.0:
				radius -= _evaporation_shrink_mm_per_s * evaporation_factor * dt
				state = STATE_EVAPORATING
			if radius > _max_radius_mm:
				radius = _max_radius_mm
			if radius < _min_radius_mm:
				_remove_at(index)
				continue
			_r[index] = radius
			_state[index] = state
		if int(_state[index]) == STATE_SLIDING:
			var vx := move_toward(float(_vx[index]), terminal_x, _accel_mps2 * dt)
			var vy := move_toward(float(_vy[index]), terminal_y, _accel_mps2 * dt)
			_vx[index] = vx
			_vy[index] = vy
			var x := float(_x[index]) + vx * 1000.0 * dt
			var y := float(_y[index]) + vy * 1000.0 * dt
			if x < 0.0 or x > _bounds.x or y < 0.0 or y > _bounds.y:
				var volume_ml := (4.0 / 3.0) * PI * radius * radius * radius / 1000.0
				_runoff_ml += volume_ml
				_remove_at(index)
				continue
			_x[index] = x
			_y[index] = y
			_age[index] = float(_age[index]) + dt
		else:
			_age[index] = float(_age[index]) + dt
		index += 1


func _spawn_one() -> void:
	if count >= max_droplets:
		return
	var index := count
	_x[index] = _randf() * _bounds.x
	_y[index] = _randf() * _bounds.y
	_r[index] = _initial_radius_mm
	_vx[index] = 0.0
	_vy[index] = 0.0
	_age[index] = 0.0
	_state[index] = STATE_NUCLEATED
	count += 1


func _remove_at(index: int) -> void:
	var last := count - 1
	if index != last:
		_x[index] = _x[last]
		_y[index] = _y[last]
		_r[index] = _r[last]
		_vx[index] = _vx[last]
		_vy[index] = _vy[last]
		_age[index] = _age[last]
		_state[index] = _state[last]
	count -= 1


func add_droplet(x_mm: float, y_mm: float, radius_mm: float, sliding: bool = false) -> int:
	if count >= max_droplets:
		return -1
	var index := count
	_x[index] = x_mm
	_y[index] = y_mm
	_r[index] = maxf(_min_radius_mm, radius_mm)
	_vx[index] = 0.0
	_vy[index] = 0.0
	_age[index] = 0.0
	_state[index] = STATE_SLIDING if sliding else STATE_GROWING
	count += 1
	return index


func clear_sector(
	pivot_mm: Vector2,
	radius_mm: float,
	start_rad: float,
	end_rad: float,
	efficiency: float
) -> int:
	var sweep_start := fposmod(start_rad, TAU)
	var sweep_end := fposmod(end_rad, TAU)
	var span := sweep_end - sweep_start
	if span > PI:
		span -= TAU
	elif span < -PI:
		span += TAU
	if absf(span) < 0.0001 or radius_mm <= 0.0:
		return 0
	var clear_fraction := clampf(efficiency, 0.0, 1.0)
	var removed := 0
	var index := 0
	while index < count:
		var dx := float(_x[index]) - pivot_mm.x
		var dy := float(_y[index]) - pivot_mm.y
		if dx * dx + dy * dy > radius_mm * radius_mm:
			index += 1
			continue
		var relative := fposmod(atan2(dy, dx) - sweep_start, TAU)
		var inside := relative <= span if span >= 0.0 else relative >= TAU + span
		if inside:
			var hash_value := int((index + 1) * 2654435761) & 0xFFFF
			if float(hash_value) / 65535.0 <= clear_fraction:
				_remove_at(index)
				removed += 1
				continue
		index += 1
	return removed


func get_instances() -> PackedFloat32Array:
	var result := PackedFloat32Array()
	result.resize(count * 6)
	var cursor := 0
	for index in range(count):
		result[cursor] = _x[index]
		result[cursor + 1] = _y[index]
		result[cursor + 2] = _r[index]
		result[cursor + 3] = _vx[index]
		result[cursor + 4] = _vy[index]
		result[cursor + 5] = float(_state[index])
		cursor += 6
	return result


func get_state_name(index: int) -> String:
	if index < 0 or index >= count:
		return "removed"
	return STATE_NAMES[int(_state[index])]


func get_runoff_ml() -> float:
	return _runoff_ml


func get_bounds_mm() -> Vector2:
	return _bounds


func get_critical_radius_mm(wetness_value: float) -> float:
	return _critical_radius_mm * (1.0 - _slide_wetness_gain * clampf(wetness_value, 0.0, 1.0))
