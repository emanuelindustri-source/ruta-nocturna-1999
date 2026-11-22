class_name AutomaticTransmission
extends RefCounted
## Caja automática de cuatro marchas con convertidor de par, Overdrive y
## selección P-R-N-D-2-L. El modelo es longitudinal y data-driven.
##
## La palanca no se manipula desde UI: en F2.3 la mano IK llamará a
## `set_selector()`. Los cambios inválidos se rechazan y se informan por
## `last_rejection`.

const SELECTOR_MODES := ["P", "R", "N", "D", "2", "L"]

var selector := "P"
var overdrive_enabled := true
var gear := 0
var ratio := 0.0
var shift_timer := 0.0
var converter_multiplication := 1.0
var converter_locked := false
var input_rpm := 0.0
var wheel_torque_nm := 0.0
var last_rejection := ""
var last_shift_reason := ""

var _gear_ratios: Array = []
var _reverse_ratio := 2.3
var _final_drive_ratio := 4.1
var _driveline_efficiency := 0.9
var _shift_time_s := 0.35
var _second_max_gear := 2
var _low_max_gear := 1
var _upshift_kph: Dictionary = {}
var _downshift_kph: Dictionary = {}
var _wheel_radius_m := 0.3
var _stall_torque_ratio := 2.0
var _coupling_rpm := 1900.0
var _lockup_kph := 65.0
var _lockup_max_throttle := 0.35


func configure(spec: Dictionary, wheel_radius_m: float) -> void:
	_gear_ratios = spec.get("gear_ratios", [])
	_reverse_ratio = float(spec.get("reverse_ratio", 2.3))
	_final_drive_ratio = float(spec.get("final_drive_ratio", 4.1))
	_driveline_efficiency = float(spec.get("driveline_efficiency", 0.9))
	_shift_time_s = float(spec.get("shift_time_s", 0.35))
	_second_max_gear = int(spec.get("second_max_gear", 2))
	_low_max_gear = int(spec.get("low_max_gear", 1))
	_upshift_kph = spec.get("upshift_kph", {})
	_downshift_kph = spec.get("downshift_kph", {})
	_wheel_radius_m = maxf(0.05, wheel_radius_m)
	var converter: Dictionary = spec.get("torque_converter", {})
	_stall_torque_ratio = float(converter.get("stall_torque_ratio", 2.0))
	_coupling_rpm = float(converter.get("coupling_rpm", 1900.0))
	_lockup_kph = float(converter.get("lockup_kph", 65.0))
	_lockup_max_throttle = float(converter.get("lockup_max_throttle", 0.35))
	selector = "P"
	overdrive_enabled = true
	gear = 0
	ratio = 0.0


func set_selector(mode: String, speed_mps: float) -> bool:
	last_rejection = ""
	if not SELECTOR_MODES.has(mode):
		last_rejection = "invalid_mode"
		return false
	var speed_kph := absf(speed_mps) * 3.6
	if mode == "P" and speed_kph > 3.0:
		last_rejection = "moving"
		return false
	if mode == "R" and speed_mps > 1.0 / 3.6:
		last_rejection = "forward_motion"
		return false
	if mode in ["D", "2", "L"] and speed_mps < -1.0 / 3.6:
		last_rejection = "reverse_motion"
		return false
	if mode == "R" and gear == -1:
		selector = mode
		return true
	if mode in ["P", "N"]:
		selector = mode
		gear = 0
		ratio = 0.0
		shift_timer = 0.0
		return true
	if mode == "R":
		selector = mode
		gear = -1
		ratio = -_reverse_ratio
		shift_timer = 0.0
		return true
	# D, 2 y L comparten la marcha actual si ya se circula; el rango se aplica
	# en `update_shift()` para no sobregirar el motor.
	selector = mode
	if gear <= 0:
		gear = 1
		ratio = _gear_ratio(1)
		shift_timer = _shift_time_s
	return true


func set_overdrive(enabled: bool, _speed_mps: float) -> bool:
	last_rejection = ""
	if selector != "D":
		last_rejection = "overdrive_needs_drive"
		return false
	if enabled == overdrive_enabled:
		return true
	overdrive_enabled = enabled
	if not enabled and gear == 4:
		gear = 3
		ratio = _gear_ratio(3)
		shift_timer = _shift_time_s
		last_shift_reason = "overdrive_off"
	return true


func toggle_overdrive(speed_mps: float) -> bool:
	return set_overdrive(not overdrive_enabled, speed_mps)


func update_shift(delta: float, speed_mps: float, throttle: float) -> void:
	last_shift_reason = ""
	shift_timer = maxf(0.0, shift_timer - maxf(delta, 0.0))
	if selector in ["P", "N", "R"]:
		return
	if gear <= 0:
		gear = 1
		ratio = _gear_ratio(1)
		shift_timer = _shift_time_s
		last_shift_reason = "engage"
		return
	var range_max := _range_max_gear()
	var speed_kph := absf(speed_mps) * 3.6
	var target := gear
	if selector == "D" and not overdrive_enabled and gear == 4:
		target = 3
	elif gear > range_max:
		if speed_kph <= _downshift_threshold(gear, throttle):
			target = gear - 1
	else:
		if gear < range_max and speed_kph >= _upshift_threshold(gear, throttle):
			target = gear + 1
		elif gear > 1 and speed_kph <= _downshift_threshold(gear, throttle):
			target = gear - 1
	if target != gear and shift_timer <= 0.0:
		last_shift_reason = "upshift" if target > gear else "downshift"
		gear = target
		ratio = _gear_ratio(gear)
		shift_timer = _shift_time_s


func update_converter(speed_mps: float, throttle: float) -> Dictionary:
	converter_locked = false
	input_rpm = get_input_rpm(speed_mps)
	converter_multiplication = 1.0
	if gear == 0 or is_zero_approx(ratio):
		return {"multiplication": 1.0, "locked": false, "input_rpm": 0.0}
	var coupling := clampf(1.0 - input_rpm / maxf(1.0, _coupling_rpm), 0.0, 1.0)
	converter_multiplication = 1.0 + (_stall_torque_ratio - 1.0) * coupling
	var speed_kph := absf(speed_mps) * 3.6
	if gear >= 3 and speed_kph >= _lockup_kph and throttle <= _lockup_max_throttle and shift_timer <= 0.0:
		converter_locked = true
		converter_multiplication = 1.0
		input_rpm = get_input_rpm(speed_mps)
	return {
		"multiplication": converter_multiplication,
		"locked": converter_locked,
		"input_rpm": input_rpm,
	}


func compute_wheel_torque(engine_torque_nm: float, engine_braking_nm: float, speed_mps: float, throttle: float) -> float:
	if gear == 0 or is_zero_approx(ratio):
		wheel_torque_nm = 0.0
		return 0.0
	var direction := 1.0 if gear > 0 else -1.0
	var drive_torque := engine_torque_nm * converter_multiplication * absf(ratio) * _final_drive_ratio * _driveline_efficiency
	var braking_torque := engine_braking_nm * absf(ratio) * _final_drive_ratio * _driveline_efficiency
	if throttle <= 0.05 and absf(speed_mps) > 0.5:
		wheel_torque_nm = -signf(speed_mps) * braking_torque
	else:
		wheel_torque_nm = direction * drive_torque
	if shift_timer > 0.0:
		wheel_torque_nm *= 1.0 - 0.85 * clampf(shift_timer / maxf(0.001, _shift_time_s), 0.0, 1.0)
	return wheel_torque_nm


func get_input_rpm(speed_mps: float) -> float:
	if gear == 0 or is_zero_approx(ratio):
		return 0.0
	var wheel_rpm := absf(speed_mps) / (TAU * _wheel_radius_m) * 60.0
	return wheel_rpm * _final_drive_ratio * absf(ratio)


func get_gear_label() -> String:
	if selector == "P":
		return "P"
	if selector == "N":
		return "N"
	if selector == "R":
		return "R"
	return str(gear)


func get_range_max_gear() -> int:
	return _range_max_gear()


func is_shifting() -> bool:
	return shift_timer > 0.0


func is_park_pawl_engaged() -> bool:
	return selector == "P"


func _range_max_gear() -> int:
	if selector == "D":
		return 4 if overdrive_enabled else 3
	if selector == "2":
		return _second_max_gear
	if selector == "L":
		return _low_max_gear
	return 0


func _gear_ratio(index: int) -> float:
	if index < 1 or index > _gear_ratios.size():
		return 0.0
	return float(_gear_ratios[index - 1])


func _upshift_threshold(index: int, throttle: float) -> float:
	var points: Variant = _upshift_kph.get(str(index), null)
	if not (points is Array) or points.size() < 2:
		return INF
	return lerpf(float(points[0]), float(points[1]), clampf(throttle, 0.0, 1.0))


func _downshift_threshold(index: int, throttle: float) -> float:
	var points: Variant = _downshift_kph.get(str(index), null)
	if not (points is Array) or points.size() < 2:
		return -INF
	return lerpf(float(points[0]), float(points[1]), clampf(throttle, 0.0, 1.0))
