class_name EngineModel
extends RefCounted
## Motor 1.6L SOHC 16V del Esteem: arranque, ralentí, carga, corte de inyección,
## calado, ahogo, secado y protección térmica.
##
## No conoce la caja ni el chasis. Recibe una velocidad objetivo de giro y una
## carga desde el orquestador; devuelve par, consumo y estado. Todos los umbrales
## vienen de `data/schemas/vehicle_powertrain.json`.

enum State {
	OFF,
	CRANKING,
	IDLE,
	RUNNING,
	STALLED,
	FLOODED,
	DRYING,
	OVERHEATED_SAFE,
	SEIZED,
}

const STATE_NAMES := [
	"off",
	"cranking",
	"idle",
	"running",
	"stalled",
	"flooded",
	"drying",
	"overheated_safe",
	"seized",
]

signal state_changed(previous: int, current: int)

var state: int = State.OFF
var rpm := 0.0
var throttle := 0.0
var ignition_on := false
var starter := false
var fuel_available := true
var spark_plugs_wet := false
var coolant_c := 25.0
var derate := 1.0
var torque_nm := 0.0
var braking_torque_nm := 0.0
var fuel_lph := 0.0
var power_kw := 0.0
var run_time := 0.0
var cranking_time := 0.0
var start_attempts := 0

var _idle_rpm := 800.0
var _redline_rpm := 6500.0
var _fuel_cut_rpm := 6800.0
var _cranking_rpm := 220.0
var _stall_rpm := 450.0
var _stall_grace_s := 0.5
var _start_delay_s := 0.9
var _max_crank_s := 3.0
var _flood_after_attempts := 3
var _drying_s := 20.0
var _rpm_slew_rate := 3000.0
var _friction_torque_nm := 8.0
var _friction_per_1000rpm_nm := 4.0
var _idle_governor_torque_nm := 18.0
var _engine_braking_base_nm := 5.0
var _engine_braking_per_1000rpm_nm := 4.0
var _overrun_fuel_cut_rpm := 1200.0
var _idle_lph := 0.7
var _bsfc_g_per_kwh := 280.0
var _gasoline_density_kg_per_l := 0.745
var _torque_curve: Array = []

var _drying_time := 0.0
var _stall_timer := 0.0
var _fuel_starve_timer := 0.0


func configure(spec: Dictionary) -> void:
	_idle_rpm = float(spec.get("idle_rpm", 800.0))
	_redline_rpm = float(spec.get("redline_rpm", 6500.0))
	_fuel_cut_rpm = float(spec.get("fuel_cut_rpm", 6800.0))
	_cranking_rpm = float(spec.get("cranking_rpm", 220.0))
	_stall_rpm = float(spec.get("stall_rpm", 450.0))
	_stall_grace_s = float(spec.get("stall_grace_s", 0.5))
	_start_delay_s = float(spec.get("start_delay_s", 0.9))
	_max_crank_s = float(spec.get("max_crank_s", 3.0))
	_flood_after_attempts = int(spec.get("flood_after_attempts", 3))
	_drying_s = float(spec.get("drying_s", 20.0))
	_rpm_slew_rate = float(spec.get("rpm_slew_rate", 3000.0))
	_friction_torque_nm = float(spec.get("friction_torque_nm", 8.0))
	_friction_per_1000rpm_nm = float(spec.get("friction_per_1000rpm_nm", 4.0))
	_idle_governor_torque_nm = float(spec.get("idle_governor_torque_nm", 18.0))
	_engine_braking_base_nm = float(spec.get("engine_braking_base_nm", 5.0))
	_engine_braking_per_1000rpm_nm = float(spec.get("engine_braking_per_1000rpm_nm", 4.0))
	var fuel_spec: Dictionary = spec.get("fuel", {})
	_idle_lph = float(fuel_spec.get("idle_lph", 0.7))
	_bsfc_g_per_kwh = float(fuel_spec.get("bsfc_g_per_kwh", 280.0))
	_gasoline_density_kg_per_l = maxf(0.1, float(fuel_spec.get("gasoline_density_kg_per_l", 0.745)))
	_overrun_fuel_cut_rpm = float(fuel_spec.get("overrun_fuel_cut_rpm", 1200.0))
	_torque_curve = spec.get("torque_curve_nm", [])
	rpm = 0.0
	state = State.OFF


func set_ignition(value: bool) -> void:
	ignition_on = value
	if not value:
		if state in [State.CRANKING, State.IDLE, State.RUNNING, State.OVERHEATED_SAFE]:
			_set_state(State.OFF)


func set_starter(value: bool) -> void:
	if value and not starter:
		_begin_crank()
	if not value and state == State.CRANKING:
		_set_state(State.OFF)
	starter = value


func set_throttle(value: float) -> void:
	throttle = clampf(value, 0.0, 1.0)


func set_fuel_available(value: bool) -> void:
	fuel_available = value
	if value:
		_fuel_starve_timer = 0.0


func set_spark_plugs_wet(value: bool) -> void:
	spark_plugs_wet = value


func set_coolant_temperature(value: float) -> void:
	coolant_c = value


func set_derate(value: float) -> void:
	derate = clampf(value, 0.0, 1.0)
	if derate < 0.99 and state in [State.IDLE, State.RUNNING]:
		_set_state(State.OVERHEATED_SAFE)
	elif derate >= 0.99 and state == State.OVERHEATED_SAFE:
		_set_state(State.RUNNING)


func dry_engine() -> bool:
	if state != State.FLOODED:
		return false
	_drying_time = 0.0
	_set_state(State.DRYING)
	return true


func force_seize() -> void:
	if state == State.SEIZED:
		return
	rpm = 0.0
	torque_nm = 0.0
	fuel_lph = 0.0
	braking_torque_nm = 0.0
	_set_state(State.SEIZED)


func repair_seized() -> void:
	spark_plugs_wet = false
	_drying_time = 0.0
	_stall_timer = 0.0
	_fuel_starve_timer = 0.0
	start_attempts = 0
	rpm = 0.0
	torque_nm = 0.0
	fuel_lph = 0.0
	braking_torque_nm = 0.0
	derate = 1.0
	_set_state(State.OFF)


func update(delta: float, target_rpm: float, in_gear: bool) -> void:
	var step := maxf(delta, 0.0)
	if step <= 0.0:
		return

	if state in [State.OFF, State.STALLED, State.FLOODED, State.SEIZED, State.DRYING]:
		rpm = move_toward(rpm, 0.0, _rpm_slew_rate * step)
		torque_nm = 0.0
		braking_torque_nm = 0.0
		fuel_lph = 0.0
		power_kw = 0.0
		if state == State.DRYING:
			_drying_time += step
			if _drying_time >= _drying_s:
				spark_plugs_wet = false
				start_attempts = 0
				_set_state(State.OFF)
		return

	if state == State.CRANKING:
		rpm = move_toward(rpm, _cranking_rpm, _rpm_slew_rate * step)
		cranking_time += step
		torque_nm = 0.0
		braking_torque_nm = 0.0
		fuel_lph = 0.0
		power_kw = 0.0
		if cranking_time >= _start_delay_s:
			if spark_plugs_wet:
				start_attempts += 1
				_set_state(State.FLOODED)
			elif not fuel_available:
				if cranking_time >= _max_crank_s:
					start_attempts += 1
					_set_state(State.STALLED)
			else:
				rpm = maxf(rpm, _idle_rpm)
				run_time = 0.0
				_set_state(State.IDLE)
		return

	# Motor en marcha o en protección térmica.
	run_time += step
	var target := clampf(target_rpm, _idle_rpm * 0.8, _fuel_cut_rpm)
	rpm = move_toward(rpm, target, _rpm_slew_rate * step)
	rpm = clampf(rpm, 0.0, _fuel_cut_rpm)

	var effective_throttle := throttle * derate
	var indicated := _torque_at_rpm(rpm) * effective_throttle
	if throttle <= 0.02 and rpm <= _idle_rpm + 120.0:
		indicated = maxf(indicated, _idle_governor_torque_nm)
	var friction := _friction_torque_nm + _friction_per_1000rpm_nm * rpm / 1000.0
	torque_nm = maxf(0.0, indicated - friction)

	if throttle <= 0.02 and rpm > _overrun_fuel_cut_rpm:
		braking_torque_nm = _engine_braking_base_nm + _engine_braking_per_1000rpm_nm * rpm / 1000.0
	else:
		braking_torque_nm = 0.0

	power_kw = torque_nm * rpm * TAU / 60.0 / 1000.0
	if not fuel_available:
		fuel_lph = 0.0
	elif throttle <= 0.02 and rpm > _overrun_fuel_cut_rpm and in_gear:
		fuel_lph = 0.0
	else:
		fuel_lph = _idle_lph + maxf(0.0, power_kw) * _bsfc_g_per_kwh / (1000.0 * _gasoline_density_kg_per_l)

	if not fuel_available:
		_fuel_starve_timer += step
		if _fuel_starve_timer >= 0.25:
			_set_state(State.STALLED)
			return
	else:
		_fuel_starve_timer = 0.0

	if state == State.OVERHEATED_SAFE:
		return

	if in_gear and rpm < _stall_rpm:
		_stall_timer += step
		if _stall_timer >= _stall_grace_s:
			_set_state(State.STALLED)
			return
	else:
		_stall_timer = 0.0

	if throttle > 0.05 or rpm > _idle_rpm + 120.0:
		_set_state(State.RUNNING)
	else:
		_set_state(State.IDLE)


func is_running() -> bool:
	return state in [State.IDLE, State.RUNNING, State.OVERHEATED_SAFE]


func get_state_name() -> String:
	if state >= 0 and state < STATE_NAMES.size():
		return STATE_NAMES[state]
	return "unknown"


func _begin_crank() -> bool:
	if not ignition_on:
		return false
	if state in [State.SEIZED, State.FLOODED, State.DRYING, State.CRANKING]:
		return false
	if state in [State.IDLE, State.RUNNING, State.OVERHEATED_SAFE]:
		return false
	if start_attempts >= _flood_after_attempts:
		_set_state(State.FLOODED)
		return false
	cranking_time = 0.0
	rpm = 0.0
	_set_state(State.CRANKING)
	return true


func _set_state(new_state: int) -> void:
	if state == new_state:
		return
	var previous := state
	state = new_state
	state_changed.emit(previous, new_state)


func _torque_at_rpm(value: float) -> float:
	if _torque_curve.is_empty():
		return 0.0
	var first: Variant = _torque_curve[0]
	if not (first is Array) or first.size() < 2:
		return 0.0
	if value <= float(first[0]):
		return float(first[1])
	for index in range(1, _torque_curve.size()):
		var point: Variant = _torque_curve[index]
		var previous: Variant = _torque_curve[index - 1]
		if not (point is Array) or point.size() < 2 or not (previous is Array) or previous.size() < 2:
			continue
		var point_rpm := float(point[0])
		if value <= point_rpm:
			var previous_rpm := float(previous[0])
			var span := maxf(1.0, point_rpm - previous_rpm)
			var blend := (value - previous_rpm) / span
			return lerpf(float(previous[1]), float(point[1]), blend)
	var last: Variant = _torque_curve[_torque_curve.size() - 1]
	if last is Array and last.size() >= 2:
		return float(last[1])
	return 0.0
