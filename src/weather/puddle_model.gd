class_name PuddleModel
extends RefCounted
## Charcos por arquetipos de superficie (F3.3).
##
## Formación por lluvia directa y escorrentía, drenaje, infiltración y
## evaporación. Expone profundidad, estado, riesgo informativo de hidroplaneo y
## estado de vadeo. F5.1 conectará la pérdida de agarre, el daño y el
## anti-atasco; F3.3 no implementa esas mecánicas.

var spec: RainSurfaceSpec
var errors: PackedStringArray = []

var zones: Dictionary = {}
var archetypes: Dictionary = {}

var _zone_order: PackedStringArray = []
var _rain_to_mm_h := 45.0
var _max_step_s := 0.25
var _humidity_exponent := 1.35
var _max_wind_mps := 25.0
var _drying_reference_c := 10.0
var _wind_drying_gain := 0.01
var _temperature_drying_gain := 0.0008
var _hydroplane_min_kph := 45.0
var _hydroplane_full_kph := 90.0
var _state_thresholds: Dictionary = {}
var _air_intake_m := 0.68
var _safe_wading_m := 0.3


func configure(source_spec: RainSurfaceSpec = null, instantiate_defaults: bool = false) -> bool:
	errors.clear()
	zones.clear()
	archetypes.clear()
	_zone_order.clear()
	spec = source_spec if source_spec != null else RainSurfaceSpec.new()
	if spec.data.is_empty() and not spec.load_spec():
		errors.append_array(spec.errors)
		return false
	var precipitation := spec.section("precipitation")
	_rain_to_mm_h = maxf(0.01, float(precipitation.get("rain_intensity_to_mm_h", 45.0)))
	_max_step_s = maxf(0.001, float(precipitation.get("max_step_s", 0.25)))
	_humidity_exponent = maxf(0.01, float(precipitation.get("humidity_drying_exponent", 1.35)))
	_max_wind_mps = maxf(0.01, float(precipitation.get("max_wind_mps", 25.0)))
	var wetness := spec.section("wetness")
	_drying_reference_c = float(wetness.get("drying_temperature_reference_c", 10.0))
	var puddles := spec.section("puddles")
	var drying: Dictionary = puddles.get("drying", {})
	_wind_drying_gain = maxf(0.0, float(drying.get("wind_gain_per_mps", 0.01)))
	_temperature_drying_gain = maxf(0.0, float(drying.get("temperature_gain_per_c", 0.0008)))
	var hydroplane: Dictionary = puddles.get("hydroplane", {})
	_hydroplane_min_kph = maxf(0.0, float(hydroplane.get("min_speed_kph", 45.0)))
	_hydroplane_full_kph = maxf(_hydroplane_min_kph + 0.1, float(hydroplane.get("full_speed_kph", 90.0)))
	_state_thresholds = puddles.get("state_thresholds", {})
	var water_link: Dictionary = puddles.get("vehicle_water_link", {})
	_air_intake_m = maxf(0.0, float(water_link.get("air_intake_height_m", 0.68)))
	_safe_wading_m = maxf(0.0, float(water_link.get("safe_wading_depth_m", 0.3)))
	for entry in puddles.get("zone_archetypes", []):
		if not (entry is Dictionary):
			continue
		var archetype_id := str(entry.get("id", ""))
		if archetype_id.is_empty():
			continue
		archetypes[archetype_id] = entry
		if instantiate_defaults:
			add_zone(archetype_id, archetype_id)
	if archetypes.is_empty():
		errors.append("puddles.zone_archetypes")
	return errors.is_empty()


func add_zone(zone_id: String, archetype_id: String, area_scale: float = 1.0, upstream_scale: float = 1.0) -> bool:
	if not archetypes.has(archetype_id) or zone_id.is_empty():
		return false
	var archetype: Dictionary = archetypes[archetype_id]
	if not zones.has(zone_id):
		_zone_order.append(zone_id)
	zones[zone_id] = {
		"id": zone_id,
		"archetype_id": archetype_id,
		"archetype": archetype,
		"area_m2": maxf(0.01, float(archetype.get("area_m2", 1.0)) * maxf(0.01, area_scale)),
		"upstream_scale": maxf(0.0, upstream_scale),
		"depth_mm": 0.0,
		"state": "dry",
		"visible": false,
		"direct_inflow_mm_s": 0.0,
		"runoff_inflow_mm_s": 0.0,
		"outflow_mm_s": 0.0,
	}
	return true


func reset() -> void:
	for zone_id in zones:
		var zone: Dictionary = zones[zone_id]
		zone["depth_mm"] = 0.0
		zone["state"] = "dry"
		zone["visible"] = false
		zone["direct_inflow_mm_s"] = 0.0
		zone["runoff_inflow_mm_s"] = 0.0
		zone["outflow_mm_s"] = 0.0


func step(
	delta: float,
	rain_intensity: float,
	humidity: float,
	wind_mps: float,
	temperature_c: float,
	runoff_mm_s: float = 0.0
) -> void:
	if delta <= 0.0:
		return
	var dt := minf(delta, _max_step_s)
	var rain := clampf(rain_intensity, 0.0, 1.0)
	var humid := clampf(humidity, 0.0, 1.0)
	var wind := clampf(wind_mps, 0.0, _max_wind_mps)
	var rain_mm_s := rain * _rain_to_mm_h / 3600.0
	var humidity_factor := pow(maxf(0.05, 1.0 - humid), _humidity_exponent)
	var wind_factor := 1.0 + wind * _wind_drying_gain
	var temperature_factor := 1.0 + maxf(0.0, temperature_c - _drying_reference_c) * _temperature_drying_gain
	var drying_factor := humidity_factor * wind_factor * temperature_factor
	for zone_id in zones:
		var zone: Dictionary = zones[zone_id]
		var archetype: Dictionary = zone["archetype"]
		var depth := float(zone["depth_mm"])
		var capacity := maxf(0.001, float(archetype.get("capacity_mm", 1.0)))
		var direct := rain_mm_s * clampf(float(archetype.get("rain_capture", 1.0)), 0.0, 1.0) * clampf(
			float(archetype.get("exposure", 1.0)), 0.0, 1.0
		)
		var runoff := maxf(0.0, runoff_mm_s) * float(archetype.get("upstream_runoff_gain", 0.0)) * float(
			zone["upstream_scale"]
		)
		var outflow := (
			float(archetype.get("drainage_rate_per_s", 0.0))
			+ float(archetype.get("infiltration_rate_per_s", 0.0))
			+ float(archetype.get("evaporation_rate_per_s", 0.0)) * drying_factor
		) * depth
		depth = clampf(depth + (direct + runoff - outflow) * dt, 0.0, capacity)
		zone["depth_mm"] = depth
		zone["direct_inflow_mm_s"] = direct
		zone["runoff_inflow_mm_s"] = runoff
		zone["outflow_mm_s"] = outflow
		zone["visible"] = depth >= float(archetype.get("visible_depth_mm", 0.0))
		zone["state"] = _classify(depth / capacity)


func _classify(normalized_depth: float) -> String:
	if normalized_depth >= float(_state_thresholds.get("deep", 0.8)):
		return "deep"
	if normalized_depth >= float(_state_thresholds.get("standing", 0.5)):
		return "standing"
	if normalized_depth >= float(_state_thresholds.get("damp", 0.05)):
		return "damp"
	return "dry"


func set_depth(zone_id: String, depth_mm: float) -> bool:
	if not zones.has(zone_id):
		return false
	var zone: Dictionary = zones[zone_id]
	var capacity := maxf(0.001, float(zone["archetype"].get("capacity_mm", 1.0)))
	var depth := clampf(depth_mm, 0.0, capacity)
	zone["depth_mm"] = depth
	zone["visible"] = depth >= float(zone["archetype"].get("visible_depth_mm", 0.0))
	zone["state"] = _classify(depth / capacity)
	return true


func get_zone(zone_id: String) -> Dictionary:
	return zones.get(zone_id, {})


func get_depth_mm(zone_id: String) -> float:
	var zone: Dictionary = zones.get(zone_id, {})
	return float(zone.get("depth_mm", 0.0))


func get_state(zone_id: String) -> String:
	var zone: Dictionary = zones.get(zone_id, {})
	return str(zone.get("state", "dry"))


func get_hydroplane_risk(zone_id: String, speed_kph: float) -> float:
	if not zones.has(zone_id):
		return 0.0
	var zone: Dictionary = zones[zone_id]
	var archetype: Dictionary = zone["archetype"]
	var depth := float(zone["depth_mm"])
	var capacity := maxf(0.001, float(archetype.get("capacity_mm", 1.0)))
	var hydroplane_depth := float(archetype.get("hydroplane_depth_mm", 0.0))
	var depth_factor := clampf((depth - hydroplane_depth) / maxf(0.001, capacity - hydroplane_depth), 0.0, 1.0)
	var speed_factor := clampf(
		(speed_kph - _hydroplane_min_kph) / maxf(0.1, _hydroplane_full_kph - _hydroplane_min_kph),
		0.0,
		1.0
	)
	return depth_factor * speed_factor


func get_wading_state(zone_id: String) -> String:
	var depth_m := get_depth_mm(zone_id) / 1000.0
	if depth_m <= _safe_wading_m:
		return "safe"
	if depth_m < _air_intake_m:
		return "caution"
	return "danger"


func get_total_water_l() -> float:
	var total := 0.0
	for zone_id in zones:
		var zone: Dictionary = zones[zone_id]
		total += float(zone["depth_mm"]) * float(zone["area_m2"])
	return total


func get_zone_ids() -> PackedStringArray:
	return _zone_order


func get_archetype_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for key in archetypes:
		ids.append(key)
	return ids
