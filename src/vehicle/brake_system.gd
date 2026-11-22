class_name BrakeSystem
extends RefCounted
## Frenos de servicio y de estacionamiento con fade térmico, desgaste de
## pastillas y nivel de líquido. El reparto delantero/trasero se declara en el
## contrato, pero el modelo longitudinal usa la fuerza total.

var pedal := 0.0
var parking := false
var temp_c := 25.0
var pad_wear := 0.0
var fluid_level := 1.0
var fade_factor := 1.0
var force_n := 0.0
var service_force_n := 0.0
var parking_force_n := 0.0
var low_fluid_warning := false

var _max_service_force_n := 9000.0
var _max_parking_force_n := 3500.0
var _front_bias := 0.65
var _pad_wear_force_loss := 0.5
var _fluid_min_factor := 0.35
var _fluid_low_warning := 0.35
var _fade_start_c := 300.0
var _fade_full_c := 700.0
var _fade_min_factor := 0.55
var _heat_capacity_kj_per_c := 14.0
var _cooling_kw_per_c := 0.02
var _parking_speed_limit_kph := 15.0


func configure(spec: Dictionary) -> void:
	_max_service_force_n = float(spec.get("max_service_force_n", 9000.0))
	_max_parking_force_n = float(spec.get("parking_force_n", 3500.0))
	_front_bias = float(spec.get("front_bias", 0.65))
	_pad_wear_force_loss = float(spec.get("pad_wear_force_loss", 0.5))
	_fluid_min_factor = float(spec.get("fluid_min_factor", 0.35))
	_fluid_low_warning = float(spec.get("fluid_low_warning", 0.35))
	_fade_start_c = float(spec.get("fade_start_c", 300.0))
	_fade_full_c = float(spec.get("fade_full_c", 700.0))
	_fade_min_factor = float(spec.get("fade_min_factor", 0.55))
	_heat_capacity_kj_per_c = maxf(1.0, float(spec.get("heat_capacity_kj_per_c", 14.0)))
	_cooling_kw_per_c = float(spec.get("cooling_kw_per_c", 0.02))
	_parking_speed_limit_kph = float(spec.get("parking_brake_speed_limit_kph", 15.0))
	pedal = 0.0
	parking = false
	temp_c = 25.0
	pad_wear = 0.0
	fluid_level = 1.0
	fade_factor = 1.0
	force_n = 0.0


func update(delta: float, speed_mps: float, ambient_c: float) -> float:
	var step := maxf(delta, 0.0)
	pad_wear = clampf(pad_wear, 0.0, 1.0)
	fluid_level = clampf(fluid_level, 0.0, 1.0)
	low_fluid_warning = fluid_level < _fluid_low_warning
	fade_factor = _fade_at(temp_c)
	var pad_factor := clampf(1.0 - pad_wear * _pad_wear_force_loss, 0.15, 1.0)
	var fluid_factor := lerpf(_fluid_min_factor, 1.0, fluid_level)
	service_force_n = clampf(pedal, 0.0, 1.0) * _max_service_force_n * pad_factor * fluid_factor * fade_factor
	parking_force_n = _max_parking_force_n if parking else 0.0
	if parking and absf(speed_mps) * 3.6 > _parking_speed_limit_kph:
		# A alta velocidad el freno de mano no debe comportarse como un ancla
		# perfecta; se reduce su efecto para no fingir un ABS trasero.
		parking_force_n *= 0.25
	force_n = service_force_n + parking_force_n

	var speed := absf(speed_mps)
	var heat_kw := force_n * speed / 1000.0
	if heat_kw > 0.0:
		temp_c += heat_kw / _heat_capacity_kj_per_c * step
	var airflow := 0.3 + 0.7 * clampf(speed / 30.0, 0.0, 1.0)
	var cooling_kw := _cooling_kw_per_c * airflow * maxf(0.0, temp_c - ambient_c)
	temp_c = maxf(ambient_c, temp_c - cooling_kw / _heat_capacity_kj_per_c * step)
	fade_factor = _fade_at(temp_c)
	return force_n


func set_pad_wear(value: float) -> void:
	pad_wear = clampf(value, 0.0, 1.0)


func set_fluid_level(value: float) -> void:
	fluid_level = clampf(value, 0.0, 1.0)


func reset_temperature(ambient_c: float) -> void:
	temp_c = ambient_c
	fade_factor = _fade_at(temp_c)


func get_front_bias() -> float:
	return _front_bias


func _fade_at(temperature: float) -> float:
	if temperature <= _fade_start_c:
		return 1.0
	if temperature >= _fade_full_c:
		return _fade_min_factor
	var blend := (temperature - _fade_start_c) / maxf(1.0, _fade_full_c - _fade_start_c)
	return lerpf(1.0, _fade_min_factor, blend)
