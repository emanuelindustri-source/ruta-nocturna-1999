class_name VehiclePowertrain
extends Node
## Orquestador longitudinal del tren motriz del Esteem 1999.
##
## Reúne motor, caja automática, frenos, combustible y refrigeración. No crea
## cuerpos físicos ni cabina: en F2.2/F2.4 se conectará al `VehicleBody3D` y a la
## UI. La simulación se puede avanzar manualmente con `simulate()` para pruebas
## headless deterministas.

signal powertrain_ready
signal engine_state_changed(state_name: String)
signal gear_changed(gear_label: String)
signal selector_changed(mode: String)
signal overdrive_changed(enabled: bool)
signal warning_changed(code: String, active: bool)
signal stalled
signal overheated
signal seized

const SPEC_PATH := "res://data/schemas/vehicle_powertrain.json"
const GRAVITY := 9.81

@export var auto_simulate := true
@export var spec_path := SPEC_PATH

var spec: VehiclePowertrainSpec
var engine: EngineModel
var transmission: AutomaticTransmission
var fuel: FuelSystem
var brakes: BrakeSystem
var cooling: CoolingSystem

var throttle := 0.0
var brake_pedal := 0.0
var parking_brake := false
var ignition_on := false
var starter := false
var selector := "P"
var overdrive_enabled := true
var speed_mps := 0.0
var grade_percent := 0.0
var ambient_c := 26.0
var last_rejection := ""

var _configured := false
var _mass_kg := 1080.0
var _wheel_radius_m := 0.3
var _drag_cda_m2 := 0.64
var _rolling_coefficient := 0.015
var _air_density := 1.225
var _max_grade_percent := 30.0
var _max_speed_mps := 70.0
var _idle_rpm := 800.0
var _redline_rpm := 6500.0
var _converter_stall_rpm := 2200.0
var _converter_coupling_rpm := 1900.0
var _heat_kw_per_lph := 2.4
var _warnings: Dictionary = {}
var _last_gear_label := ""
var _last_selector := ""
var _last_overdrive := true


func _ready() -> void:
	if not _configured:
		configure(spec_path)


func configure(path: String = SPEC_PATH) -> bool:
	spec = VehiclePowertrainSpec.new()
	if not spec.load_spec(path):
		push_error("[POWERTRAIN] Contrato inválido: %s" % ", ".join(spec.errors))
		return false
	_mass_kg = spec.number("vehicle.curb_mass_kg", 1080.0)
	_wheel_radius_m = maxf(0.05, spec.number("vehicle.wheel_radius_m", 0.3))
	_drag_cda_m2 = spec.number("vehicle.drag_cda_m2", 0.64)
	_rolling_coefficient = spec.number("vehicle.rolling_resistance_coefficient", 0.015)
	_air_density = spec.number("vehicle.air_density_kg_m3", 1.225)
	_max_grade_percent = spec.number("vehicle.max_grade_percent", 30.0)
	_max_speed_mps = spec.number("vehicle.max_speed_mps", 70.0)
	_idle_rpm = spec.number("engine.idle_rpm", 800.0)
	_redline_rpm = spec.number("engine.redline_rpm", 6500.0)
	_converter_stall_rpm = spec.number("transmission.torque_converter.stall_rpm", 2200.0)
	_converter_coupling_rpm = spec.number("transmission.torque_converter.coupling_rpm", 1900.0)
	_heat_kw_per_lph = spec.number("cooling.heat_kw_per_lph", 2.4)

	engine = EngineModel.new()
	engine.configure(spec.section("engine"))
	engine.state_changed.connect(_on_engine_state_changed)

	transmission = AutomaticTransmission.new()
	transmission.configure(spec.section("transmission"), _wheel_radius_m)

	fuel = FuelSystem.new()
	fuel.configure(spec.section("fuel"))

	brakes = BrakeSystem.new()
	brakes.configure(spec.section("brakes"))
	brakes.reset_temperature(ambient_c)

	cooling = CoolingSystem.new()
	cooling.configure(spec.section("cooling"))
	cooling.set_ambient_temperature(ambient_c)
	cooling.coolant_c = ambient_c

	engine.set_coolant_temperature(ambient_c)
	engine.set_fuel_available(fuel.has_fuel())
	selector = "P"
	overdrive_enabled = true
	speed_mps = 0.0
	throttle = 0.0
	brake_pedal = 0.0
	parking_brake = false
	ignition_on = false
	starter = false
	last_rejection = ""
	_warnings.clear()
	_last_gear_label = transmission.get_gear_label()
	_last_selector = selector
	_last_overdrive = overdrive_enabled
	_configured = true
	powertrain_ready.emit()
	return true


func _physics_process(delta: float) -> void:
	if auto_simulate and _configured:
		simulate(delta)


func simulate(delta: float) -> void:
	if not _configured:
		return
	var step := clampf(delta, 0.0, 0.1)
	if step <= 0.0:
		return
	_simulate_step(step)
	_refresh_warnings()
	_emit_changes()


func start_engine() -> bool:
	if not _configured:
		return false
	if selector not in ["P", "N"]:
		last_rejection = "start_requires_park_or_neutral"
		return false
	if not fuel.has_fuel():
		last_rejection = "no_fuel"
		return false
	# Cada comando de arranque representa un giro nuevo de la llave; si el
	# intento anterior dejó la marcha retenida, se libera antes de reintentar.
	starter = false
	engine.set_starter(false)
	ignition_on = true
	starter = true
	engine.set_ignition(true)
	engine.set_starter(true)
	if engine.state != EngineModel.State.CRANKING:
		starter = false
		last_rejection = "engine_not_crankable"
		return false
	last_rejection = ""
	return true


func stop_engine() -> void:
	ignition_on = false
	starter = false
	engine.set_ignition(false)
	engine.set_starter(false)


func set_throttle(value: float) -> void:
	throttle = clampf(value, 0.0, 1.0)


func set_brake_pedal(value: float) -> void:
	brake_pedal = clampf(value, 0.0, 1.0)


func set_parking_brake(value: bool) -> void:
	parking_brake = value


func set_selector(mode: String) -> bool:
	if not _configured:
		return false
	if transmission.set_selector(mode, speed_mps):
		selector = mode
		if mode == "P":
			speed_mps = 0.0
		last_rejection = ""
		return true
	last_rejection = transmission.last_rejection
	return false


func toggle_overdrive() -> bool:
	if not _configured:
		return false
	if transmission.toggle_overdrive(speed_mps):
		overdrive_enabled = transmission.overdrive_enabled
		last_rejection = ""
		return true
	last_rejection = transmission.last_rejection
	return false


func set_grade_percent(value: float) -> void:
	grade_percent = clampf(value, -_max_grade_percent, _max_grade_percent)


func set_speed_kph(value: float) -> void:
	speed_mps = clampf(value / 3.6, -_max_speed_mps, _max_speed_mps)


func set_ambient_temperature(value: float) -> void:
	ambient_c = value
	if cooling != null:
		cooling.set_ambient_temperature(value)


func refuel(liters: float) -> float:
	if not _configured:
		return 0.0
	return fuel.refuel(liters)


func set_fuel_level(liters: float) -> void:
	if _configured:
		fuel.set_level(liters)


func set_brake_pad_wear(value: float) -> void:
	if _configured:
		brakes.set_pad_wear(value)


func set_brake_fluid_level(value: float) -> void:
	if _configured:
		brakes.set_fluid_level(value)


func set_spark_plugs_wet(value: bool) -> void:
	if _configured:
		engine.set_spark_plugs_wet(value)


func dry_engine() -> bool:
	if not _configured:
		return false
	return engine.dry_engine()


func set_thermostat_fault(fault: String) -> bool:
	if not _configured:
		return false
	return cooling.set_thermostat_fault(fault)


func set_fan_fault(component_id: String, faulty: bool) -> bool:
	if not _configured:
		return false
	var role := _fan_role(component_id)
	if role.is_empty():
		return false
	return cooling.set_fan_fault(role, faulty)


func set_fan_relay_intermittent(value: bool) -> void:
	if _configured:
		cooling.set_relay_intermittent(value)


func repair_component(component_id: String) -> bool:
	if not _configured:
		return false
	var fan_role := _fan_role(component_id)
	if not fan_role.is_empty():
		return cooling.repair_fan(fan_role)
	match component_id:
		"engine.seized", "engine":
			starter = false
			engine.set_starter(false)
			engine.repair_seized()
			cooling.repair_seized(ambient_c)
			last_rejection = ""
			return true
		"brakes.front_pads":
			brakes.set_pad_wear(0.0)
			return true
		"brakes.master_cylinder":
			brakes.set_fluid_level(1.0)
			return true
		"cooling.thermostat":
			cooling.set_thermostat_fault("")
			return true
	return false


func get_telemetry() -> Dictionary:
	if not _configured:
		return {}
	return {
		"speed_mps": speed_mps,
		"speed_kph": speed_mps * 3.6,
		"rpm": engine.rpm,
		"engine_state": engine.get_state_name(),
		"engine_derate": engine.derate,
		"engine_torque_nm": engine.torque_nm,
		"engine_braking_nm": engine.braking_torque_nm,
		"engine_power_kw": engine.power_kw,
		"fuel_lph": engine.fuel_lph,
		"selector": selector,
		"gear": transmission.get_gear_label(),
		"gear_number": transmission.gear,
		"overdrive": overdrive_enabled,
		"shifting": transmission.is_shifting(),
		"converter_multiplication": transmission.converter_multiplication,
		"converter_locked": transmission.converter_locked,
		"input_rpm": transmission.input_rpm,
		"wheel_torque_nm": transmission.wheel_torque_nm,
		"fuel_l": fuel.level_l,
		"fuel_ratio": fuel.get_ratio(),
		"fuel_low": fuel.low_warning,
		"coolant_c": cooling.coolant_c,
		"coolant_capacity_l": cooling.get_coolant_capacity_l(),
		"fan_mode": cooling.fan_mode,
		"fan_running": cooling.fan_running,
		"fan_airflow_mps": cooling.fan_airflow_mps,
		"thermostat_opening": cooling.thermostat_opening,
		"heat_input_kw": cooling.heat_input_kw,
		"heat_rejection_kw": cooling.heat_rejection_kw,
		"overheat_warning": cooling.overheat_warning,
		"safe_mode": cooling.safe_mode,
		"brake_force_n": brakes.force_n,
		"brake_front_bias": brakes.get_front_bias(),
		"brake_temp_c": brakes.temp_c,
		"brake_fade": brakes.fade_factor,
		"brake_pad_wear": brakes.pad_wear,
		"brake_fluid": brakes.fluid_level,
		"parking_brake": parking_brake,
		"grade_percent": grade_percent,
		"warnings": _warnings.duplicate(true),
		"last_rejection": last_rejection,
	}


func get_warning(code: String) -> bool:
	return bool(_warnings.get(code, false))


func _simulate_step(step: float) -> void:
	engine.set_throttle(throttle)
	engine.set_ignition(ignition_on)
	engine.set_fuel_available(fuel.has_fuel())
	engine.set_coolant_temperature(cooling.coolant_c)
	engine.set_derate(cooling.get_derate())
	if cooling.seized:
		engine.force_seize()

	transmission.update_shift(step, speed_mps, throttle)
	var converter := transmission.update_converter(speed_mps, throttle)
	var target_rpm := _target_engine_rpm(converter)
	engine.update(step, target_rpm, transmission.gear != 0)

	if starter and engine.is_running():
		starter = false
		engine.set_starter(false)
	elif starter and engine.state in [EngineModel.State.FLOODED, EngineModel.State.STALLED, EngineModel.State.SEIZED, EngineModel.State.OFF]:
		starter = false
		engine.set_starter(false)

	var wheel_torque := transmission.compute_wheel_torque(
		engine.torque_nm,
		engine.braking_torque_nm,
		speed_mps,
		throttle
	)
	brakes.pedal = brake_pedal
	brakes.parking = parking_brake
	var brake_force := brakes.update(step, speed_mps, ambient_c)
	_integrate_speed(step, wheel_torque, brake_force)

	var engine_heat_kw := engine.fuel_lph * _heat_kw_per_lph
	cooling.update(step, engine_heat_kw, engine.is_running(), speed_mps, ambient_c)
	engine.set_coolant_temperature(cooling.coolant_c)
	if cooling.seized:
		engine.force_seize()

	fuel.consume(engine.fuel_lph, step)
	engine.set_fuel_available(fuel.has_fuel())


func _target_engine_rpm(converter: Dictionary) -> float:
	if transmission.gear == 0:
		return _idle_rpm + throttle * (_redline_rpm - _idle_rpm)
	var input_rpm := float(converter.get("input_rpm", 0.0))
	var target := maxf(_idle_rpm, input_rpm)
	if not bool(converter.get("locked", false)):
		var slip_factor := clampf(1.0 - input_rpm / maxf(1.0, _converter_coupling_rpm), 0.0, 1.0)
		target += throttle * (_converter_stall_rpm - _idle_rpm) * slip_factor
	return target


func _integrate_speed(step: float, wheel_torque_nm: float, brake_force_n: float) -> void:
	var tractive_force := wheel_torque_nm / _wheel_radius_m
	var drag := 0.5 * _air_density * _drag_cda_m2 * speed_mps * absf(speed_mps)
	var rolling := 0.0
	if absf(speed_mps) > 0.05:
		rolling = _rolling_coefficient * _mass_kg * GRAVITY * signf(speed_mps)
	var grade_rad := atan(grade_percent / 100.0)
	var grade_force := _mass_kg * GRAVITY * sin(grade_rad)
	var brake_opposing := 0.0
	if absf(speed_mps) > 0.05:
		brake_opposing = brake_force_n * signf(speed_mps)
	var net_force := tractive_force - drag - rolling - brake_opposing - grade_force
	var new_speed := speed_mps + net_force / _mass_kg * step
	if absf(speed_mps) > 0.03 and signf(new_speed) != signf(speed_mps):
		if absf(tractive_force) < absf(brake_opposing) + absf(grade_force) + absf(rolling) + 1.0:
			new_speed = 0.0
	if absf(new_speed) < 0.05 and absf(tractive_force) < 10.0 and (brake_force_n > 0.0 or parking_brake or transmission.is_park_pawl_engaged()):
		new_speed = 0.0
	if transmission.is_park_pawl_engaged():
		new_speed = 0.0
	speed_mps = clampf(new_speed, -_max_speed_mps, _max_speed_mps)


func _refresh_warnings() -> void:
	_set_warning("fuel_low", fuel.low_warning)
	_set_warning("overheat", cooling.overheat_warning)
	_set_warning("fan_fault", not cooling.is_fan_electrically_available())
	_set_warning("brake_fade", brakes.fade_factor < 0.99)
	_set_warning("parking_brake", parking_brake)
	_set_warning("safe_mode", cooling.safe_mode)
	_set_warning("brake_fluid_low", brakes.low_fluid_warning)
	_set_warning("engine_seized", engine.state == EngineModel.State.SEIZED)


func _set_warning(code: String, active: bool) -> void:
	var previous := bool(_warnings.get(code, false))
	if previous == active:
		return
	_warnings[code] = active
	warning_changed.emit(code, active)


func _emit_changes() -> void:
	if transmission.get_gear_label() != _last_gear_label:
		_last_gear_label = transmission.get_gear_label()
		gear_changed.emit(_last_gear_label)
	if selector != _last_selector:
		_last_selector = selector
		selector_changed.emit(selector)
	if overdrive_enabled != _last_overdrive:
		_last_overdrive = overdrive_enabled
		overdrive_changed.emit(overdrive_enabled)


func _on_engine_state_changed(previous: int, current: int) -> void:
	var state_name: String = EngineModel.STATE_NAMES[current] if current >= 0 and current < EngineModel.STATE_NAMES.size() else "unknown"
	engine_state_changed.emit(state_name)
	if current == EngineModel.State.STALLED:
		stalled.emit()
	elif current == EngineModel.State.SEIZED:
		seized.emit()
	elif current == EngineModel.State.OVERHEATED_SAFE:
		overheated.emit()


func _fan_role(component_id: String) -> String:
	var components := spec.dictionary("cooling.fan_components")
	for role in components.keys():
		if str(components[role]) == component_id:
			return str(role)
	return ""
