class_name FuelSystem
extends RefCounted
## Tanque, consumo y reserva. La capacidad y los umbrales vienen del contrato.

var capacity_l := 50.0
var level_l := 50.0
var low_warning_l := 8.0
var empty_threshold_l := 0.5
var reserve_l := 5.0
var consumed_l := 0.0
var low_warning := false
var empty := false


func configure(spec: Dictionary) -> void:
	capacity_l = maxf(1.0, float(spec.get("tank_capacity_l", 50.0)))
	low_warning_l = float(spec.get("low_warning_l", 8.0))
	empty_threshold_l = float(spec.get("empty_threshold_l", 0.5))
	reserve_l = float(spec.get("reserve_l", 5.0))
	level_l = capacity_l
	consumed_l = 0.0
	_update_flags()


func consume(liters_per_hour: float, delta: float) -> float:
	if delta <= 0.0 or liters_per_hour <= 0.0:
		_update_flags()
		return 0.0
	var requested := liters_per_hour / 3600.0 * delta
	var consumed := minf(level_l, requested)
	level_l = maxf(0.0, level_l - consumed)
	consumed_l += consumed
	_update_flags()
	return consumed


func refuel(liters: float) -> float:
	if liters <= 0.0:
		return 0.0
	var added := minf(liters, capacity_l - level_l)
	level_l += added
	_update_flags()
	return added


func set_level(liters: float) -> void:
	level_l = clampf(liters, 0.0, capacity_l)
	_update_flags()


func has_fuel() -> bool:
	return level_l > empty_threshold_l


func get_ratio() -> float:
	return clampf(level_l / maxf(0.001, capacity_l), 0.0, 1.0)


func _update_flags() -> void:
	low_warning = level_l <= low_warning_l
	empty = level_l <= empty_threshold_l
