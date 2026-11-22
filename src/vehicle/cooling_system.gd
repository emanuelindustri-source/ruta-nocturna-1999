class_name CoolingSystem
extends RefCounted
## Sistema de refrigeración: termostato, radiador, electroventilador de dos
## velocidades y protecciones térmicas. Los fallos de fusible, relé y motor
## siguen los IDs del contrato de componentes.

var coolant_c := 25.0
var ambient_c := 25.0
var fan_mode := "off"
var fan_running := false
var fan_airflow_mps := 0.0
var thermostat_opening := 0.0
var heat_input_kw := 0.0
var heat_rejection_kw := 0.0
var overheat_warning := false
var safe_mode := false
var seized := false

var fuse_ok := true
var relay_ok := true
var motor_ok := true
var relay_intermittent := false
var thermostat_fault := ""

var _coolant_capacity_l := 5.5
var _heat_capacity_kj_per_c := 18.0
var _thermostat_open_c := 82.0
var _thermostat_full_open_c := 88.0
var _fan_low_on_c := 98.0
var _fan_low_off_c := 94.0
var _fan_high_on_c := 104.0
var _fan_high_off_c := 100.0
var _fan_low_airflow_mps := 4.0
var _fan_high_airflow_mps := 8.0
var _radiator_kw_per_c := 0.8
var _block_loss_kw_per_c := 0.025
var _overheat_warning_c := 110.0
var _safe_mode_c := 115.0
var _safe_mode_exit_c := 108.0
var _safe_mode_derate := 0.35
var _seize_c := 125.0
var _seize_grace_s := 8.0
var _relay_period_s := 2.0
var _relay_on_fraction := 0.3
var _seize_timer := 0.0
var _relay_timer := 0.0


func configure(spec: Dictionary) -> void:
	_coolant_capacity_l = float(spec.get("coolant_capacity_l", 5.5))
	_heat_capacity_kj_per_c = maxf(1.0, float(spec.get("coolant_heat_capacity_kj_per_c", 18.0)))
	_thermostat_open_c = float(spec.get("thermostat_open_c", 82.0))
	_thermostat_full_open_c = float(spec.get("thermostat_full_open_c", 88.0))
	_fan_low_on_c = float(spec.get("fan_low_on_c", 98.0))
	_fan_low_off_c = float(spec.get("fan_low_off_c", 94.0))
	_fan_high_on_c = float(spec.get("fan_high_on_c", 104.0))
	_fan_high_off_c = float(spec.get("fan_high_off_c", 100.0))
	_fan_low_airflow_mps = float(spec.get("fan_low_airflow_mps", 4.0))
	_fan_high_airflow_mps = float(spec.get("fan_high_airflow_mps", 8.0))
	_radiator_kw_per_c = float(spec.get("radiator_kw_per_c", 0.8))
	_block_loss_kw_per_c = float(spec.get("block_loss_kw_per_c", 0.025))
	_overheat_warning_c = float(spec.get("overheat_warning_c", 110.0))
	_safe_mode_c = float(spec.get("safe_mode_c", 115.0))
	_safe_mode_exit_c = float(spec.get("safe_mode_exit_c", 108.0))
	_safe_mode_derate = clampf(float(spec.get("safe_mode_derate", 0.35)), 0.0, 1.0)
	_seize_c = float(spec.get("seize_c", 125.0))
	_seize_grace_s = float(spec.get("seize_grace_s", 8.0))
	_relay_period_s = maxf(0.1, float(spec.get("relay_intermittent_period_s", 2.0)))
	_relay_on_fraction = clampf(float(spec.get("relay_intermittent_on_fraction", 0.3)), 0.0, 1.0)
	coolant_c = ambient_c
	fan_mode = "off"
	fan_running = false
	fan_airflow_mps = 0.0
	thermostat_opening = 0.0
	overheat_warning = false
	safe_mode = false
	seized = false
	fuse_ok = true
	relay_ok = true
	motor_ok = true
	relay_intermittent = false
	thermostat_fault = ""
	_seize_timer = 0.0
	_relay_timer = 0.0


func update(delta: float, engine_heat_kw: float, engine_running: bool, speed_mps: float, ambient_temperature: float) -> void:
	var step := maxf(delta, 0.0)
	ambient_c = ambient_temperature
	heat_input_kw = maxf(0.0, engine_heat_kw)
	_update_fan(step)
	thermostat_opening = _thermostat_factor()
	var airflow := absf(speed_mps) + fan_airflow_mps
	var airflow_factor := clampf(airflow / 30.0, 0.0, 1.0)
	var radiator_effectiveness := 0.05 + 0.95 * airflow_factor
	var radiator_rejection := _radiator_kw_per_c * thermostat_opening * radiator_effectiveness * maxf(0.0, coolant_c - ambient_c)
	var block_loss := _block_loss_kw_per_c * maxf(0.0, coolant_c - ambient_c)
	heat_rejection_kw = radiator_rejection + block_loss
	coolant_c += (heat_input_kw - heat_rejection_kw) / _heat_capacity_kj_per_c * step
	coolant_c = maxf(ambient_c, coolant_c)

	overheat_warning = coolant_c >= _overheat_warning_c
	if coolant_c >= _safe_mode_c:
		safe_mode = true
	elif coolant_c <= _safe_mode_exit_c:
		safe_mode = false
	if coolant_c >= _seize_c:
		_seize_timer += step
		if _seize_timer >= _seize_grace_s:
			seized = true
	else:
		_seize_timer = 0.0
	if not engine_running and coolant_c < _fan_low_off_c:
		fan_mode = "off"
		fan_running = false
		fan_airflow_mps = 0.0


func get_derate() -> float:
	return _safe_mode_derate if safe_mode else 1.0


func set_ambient_temperature(value: float) -> void:
	ambient_c = value


func set_fan_fault(role: String, faulty: bool) -> bool:
	match role:
		"fuse":
			fuse_ok = not faulty
		"relay":
			relay_ok = not faulty
		"motor":
			motor_ok = not faulty
		_:
			return false
	if faulty:
		fan_mode = "fault"
		fan_running = false
		fan_airflow_mps = 0.0
	return true


func set_relay_intermittent(value: bool) -> void:
	relay_intermittent = value
	if value:
		_relay_timer = 0.0


func set_thermostat_fault(fault: String) -> bool:
	if not (fault in ["", "stuck_closed", "stuck_open"]):
		return false
	thermostat_fault = fault
	return true


func repair_fan(role: String) -> bool:
	if not set_fan_fault(role, false):
		return false
	if fuse_ok and relay_ok and motor_ok:
		fan_mode = "off"
		relay_intermittent = false
	return true


func repair_seized(ambient_temperature: float) -> void:
	seized = false
	safe_mode = false
	_seize_timer = 0.0
	coolant_c = maxf(ambient_temperature, minf(coolant_c, ambient_temperature + 40.0))
	fan_mode = "off"
	fan_running = false
	fan_airflow_mps = 0.0


func is_fan_electrically_available() -> bool:
	return fuse_ok and relay_ok and motor_ok


func get_coolant_capacity_l() -> float:
	return _coolant_capacity_l


func _update_fan(delta: float) -> void:
	if not is_fan_electrically_available():
		fan_mode = "fault"
		fan_running = false
		fan_airflow_mps = 0.0
		return
	if fan_mode == "fault":
		fan_mode = "off"
	if fan_mode == "high":
		if coolant_c < _fan_high_off_c:
			fan_mode = "low"
	elif fan_mode == "low":
		if coolant_c >= _fan_high_on_c:
			fan_mode = "high"
		elif coolant_c < _fan_low_off_c:
			fan_mode = "off"
	else:
		if coolant_c >= _fan_high_on_c:
			fan_mode = "high"
		elif coolant_c >= _fan_low_on_c:
			fan_mode = "low"
	if not (fan_mode in ["low", "high"]):
		fan_running = false
		fan_airflow_mps = 0.0
		return
	var relay_on := true
	if relay_intermittent:
		_relay_timer += delta
		var phase := fmod(_relay_timer, _relay_period_s) / _relay_period_s
		relay_on = phase < _relay_on_fraction
	fan_running = relay_on
	fan_airflow_mps = 0.0
	if fan_running:
		fan_airflow_mps = _fan_high_airflow_mps if fan_mode == "high" else _fan_low_airflow_mps


func _thermostat_factor() -> float:
	if thermostat_fault == "stuck_closed":
		return 0.0
	if thermostat_fault == "stuck_open":
		return 1.0
	return clampf((coolant_c - _thermostat_open_c) / maxf(0.1, _thermostat_full_open_c - _thermostat_open_c), 0.0, 1.0)
