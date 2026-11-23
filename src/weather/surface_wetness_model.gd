class_name SurfaceWetnessModel
extends RefCounted
## Humedad de superficies del vehículo y de la vía (F3.3).
##
## Implementa las ecuaciones declaradas en `rain_surface_fx.json`: entrada de
## lluvia, drenaje, evaporación, infiltración y estado con histéresis. No dibuja
## nada, no modifica materiales y no conoce la UI. WeatherManager inyecta lluvia,
## humedad, viento y temperatura en F4.4.

const LEVELS := ["dry", "damp", "wet", "soaked"]

var spec: RainSurfaceSpec
var panels: Dictionary = {}
var errors: PackedStringArray = []

var _panel_order: PackedStringArray = []
var _road_order: PackedStringArray = []
var _max_step_s := 0.25
var _humidity_exponent := 1.35
var _max_wind_mps := 25.0
var _rain_to_mm_h := 45.0
var _drying_reference_c := 10.0
var _thresholds: Dictionary = {}
var _hysteresis := 0.03


func configure(source_spec: RainSurfaceSpec = null) -> bool:
	errors.clear()
	panels.clear()
	_panel_order.clear()
	_road_order.clear()
	spec = source_spec if source_spec != null else RainSurfaceSpec.new()
	if spec.data.is_empty() and not spec.load_spec():
		errors.append_array(spec.errors)
		return false
	if not spec.errors.is_empty() and spec.data.is_empty():
		errors.append_array(spec.errors)
		return false
	var precipitation := spec.section("precipitation")
	_max_step_s = maxf(0.001, float(precipitation.get("max_step_s", 0.25)))
	_humidity_exponent = maxf(0.01, float(precipitation.get("humidity_drying_exponent", 1.35)))
	_max_wind_mps = maxf(0.01, float(precipitation.get("max_wind_mps", 25.0)))
	_rain_to_mm_h = maxf(0.01, float(precipitation.get("rain_intensity_to_mm_h", 45.0)))
	var wetness_section := spec.section("wetness")
	_drying_reference_c = float(wetness_section.get("drying_temperature_reference_c", 10.0))
	_hysteresis = maxf(0.0, float(wetness_section.get("state_hysteresis", 0.03)))
	_thresholds = wetness_section.get("state_thresholds", {})
	if _thresholds.is_empty():
		errors.append("wetness.state_thresholds")
	var surfaces := spec.section("surfaces")
	for entry in surfaces.get("vehicle_panels", []):
		if not _add_panel(entry, "vehicle"):
			continue
	for entry in surfaces.get("road_surfaces", []):
		if not _add_panel(entry, "road"):
			continue
	if panels.is_empty():
		errors.append("surfaces.empty")
	return errors.is_empty()


func _add_panel(entry: Variant, kind: String) -> bool:
	if not (entry is Dictionary):
		errors.append("surface.invalid")
		return false
	var panel_id := str(entry.get("id", ""))
	var class_id := str(entry.get("surface_class", ""))
	if panel_id.is_empty() or class_id.is_empty():
		errors.append("surface.id")
		return false
	var class_spec := spec.class_spec(class_id)
	if class_spec.is_empty():
		errors.append("surface.class:%s" % class_id)
		return false
	var size_value: Array = entry.get("surface_size_m", [1.0, 1.0])
	var size := Vector2(float(size_value[0]), float(size_value[1])) if size_value.size() == 2 else Vector2.ONE
	var flow_value: Array = entry.get("flow_dir", [0.0, -1.0])
	var flow := Vector2(float(flow_value[0]), float(flow_value[1])) if flow_value.size() == 2 else Vector2(0.0, -1.0)
	var max_film := maxf(0.0001, float(class_spec.get("max_film_mm", 0.1)))
	panels[panel_id] = {
		"id": panel_id,
		"kind": kind,
		"class_id": class_id,
		"class": class_spec,
		"profile_id": str(entry.get("droplet_profile", "")),
		"area_m2": maxf(0.0, float(entry.get("area_m2", 0.0))),
		"surface_size_m": size,
		"flow_dir": flow,
		"slope_deg": float(entry.get("slope_deg", 0.0)),
		"exposure": clampf(float(entry.get("exposure", 1.0)), 0.0, 1.0),
		"rain_capture": clampf(float(entry.get("rain_capture", class_spec.get("rain_capture", 1.0))), 0.0, 1.0),
		"wiper_zone": str(entry.get("wiper_zone", "none")),
		"max_film_mm": max_film,
		"film_mm": 0.0,
		"wetness": 0.0,
		"state": "dry",
		"input_mm_s": 0.0,
		"drainage_mm_s": 0.0,
		"evaporation_mm_s": 0.0,
		"infiltration_mm_s": 0.0,
		"runoff_mm_s": 0.0,
	}
	if kind == "road":
		_road_order.append(panel_id)
	else:
		_panel_order.append(panel_id)
	return true


func reset() -> void:
	for panel_id in panels:
		var panel: Dictionary = panels[panel_id]
		panel["film_mm"] = 0.0
		panel["wetness"] = 0.0
		panel["state"] = "dry"
		panel["input_mm_s"] = 0.0
		panel["drainage_mm_s"] = 0.0
		panel["evaporation_mm_s"] = 0.0
		panel["infiltration_mm_s"] = 0.0
		panel["runoff_mm_s"] = 0.0


func step(delta: float, rain_intensity: float, humidity: float, wind_mps: float, temperature_c: float) -> void:
	if delta <= 0.0:
		return
	var dt := minf(delta, _max_step_s)
	var rain := clampf(rain_intensity, 0.0, 1.0)
	var humid := clampf(humidity, 0.0, 1.0)
	var wind := clampf(wind_mps, 0.0, _max_wind_mps)
	var rain_mm_h := rain * _rain_to_mm_h
	var rain_mm_s := rain_mm_h / 3600.0
	var humidity_factor := pow(maxf(0.05, 1.0 - humid), _humidity_exponent)
	for panel_id in panels:
		var panel: Dictionary = panels[panel_id]
		var class_spec: Dictionary = panel["class"]
		var film := float(panel["film_mm"])
		var max_film := float(panel["max_film_mm"])
		var capture := float(panel["rain_capture"])
		var exposure := float(panel["exposure"])
		var input_mm_s := rain_mm_s * capture * exposure
		var retention := float(class_spec.get("retention_mm", 0.0))
		var drainage_rate := float(class_spec.get("drainage_rate_per_s", 0.0))
		var evaporation_rate := float(class_spec.get("evaporation_rate_per_s", 0.0))
		var infiltration_rate := float(class_spec.get("infiltration_rate_per_s", 0.0))
		var wind_gain := float(class_spec.get("wind_drying_gain", 0.0))
		var temperature_gain := float(class_spec.get("temperature_drying_gain", 0.0))
		var wind_factor := 1.0 + wind * wind_gain
		var temperature_factor := 1.0 + maxf(0.0, temperature_c - _drying_reference_c) * temperature_gain
		var drainage_mm_s := drainage_rate * maxf(0.0, film - retention)
		var evaporation_mm_s := evaporation_rate * film * humidity_factor * wind_factor * temperature_factor
		var infiltration_mm_s := infiltration_rate * film
		film = clampf(
			film + (input_mm_s - drainage_mm_s - evaporation_mm_s - infiltration_mm_s) * dt,
			0.0,
			max_film
		)
		panel["film_mm"] = film
		panel["wetness"] = film / max_film
		panel["input_mm_s"] = input_mm_s
		panel["drainage_mm_s"] = drainage_mm_s
		panel["evaporation_mm_s"] = evaporation_mm_s
		panel["infiltration_mm_s"] = infiltration_mm_s
		panel["runoff_mm_s"] = (drainage_mm_s + infiltration_mm_s) * float(class_spec.get("runoff_to_puddle", 0.0))
		panel["state"] = _classify(float(panel["wetness"]), str(panel["state"]))


func _classify(wetness_value: float, current: String) -> String:
	var dry_threshold := float(_thresholds.get("dry", 0.05))
	var damp_threshold := float(_thresholds.get("damp", 0.18))
	var wet_threshold := float(_thresholds.get("wet", 0.65))
	var soaked_threshold := float(_thresholds.get("soaked", 0.9))
	var index := 0
	if wetness_value >= soaked_threshold:
		index = 3
	elif wetness_value >= wet_threshold:
		index = 2
	elif wetness_value >= damp_threshold:
		index = 1
	elif wetness_value >= dry_threshold:
		index = 0
	var current_index := LEVELS.find(current)
	if current_index == -1 or absi(index - current_index) != 1:
		return LEVELS[index]
	if index > current_index:
		var boundary := damp_threshold if index == 1 else (wet_threshold if index == 2 else soaked_threshold)
		if wetness_value < boundary + _hysteresis:
			index = current_index
	elif index < current_index:
		var boundary_down := dry_threshold if current_index == 1 else (damp_threshold if current_index == 2 else wet_threshold)
		if wetness_value > boundary_down - _hysteresis:
			index = current_index
	return LEVELS[index]


func set_wetness(panel_id: String, wetness_value: float) -> bool:
	if not panels.has(panel_id):
		return false
	var panel: Dictionary = panels[panel_id]
	var value := clampf(wetness_value, 0.0, 1.0)
	panel["wetness"] = value
	panel["film_mm"] = value * float(panel["max_film_mm"])
	panel["state"] = _classify(value, "dry")
	return true


func get_panel(panel_id: String) -> Dictionary:
	return panels.get(panel_id, {})


func get_wetness(panel_id: String) -> float:
	var panel: Dictionary = panels.get(panel_id, {})
	return float(panel.get("wetness", 0.0))


func get_film_mm(panel_id: String) -> float:
	var panel: Dictionary = panels.get(panel_id, {})
	return float(panel.get("film_mm", 0.0))


func get_state(panel_id: String) -> String:
	var panel: Dictionary = panels.get(panel_id, {})
	return str(panel.get("state", "dry"))


func get_runoff(panel_id: String) -> float:
	var panel: Dictionary = panels.get(panel_id, {})
	return float(panel.get("runoff_mm_s", 0.0))


func get_panel_ids() -> PackedStringArray:
	return _panel_order


func get_road_ids() -> PackedStringArray:
	return _road_order


func get_absorber_runoff() -> float:
	var total := 0.0
	for panel_id in _road_order:
		var panel: Dictionary = panels[panel_id]
		total += float(panel.get("runoff_mm_s", 0.0)) * float(panel.get("area_m2", 0.0))
	return total
