extends Node
## Prueba de clima, regiones y mapa de papel (F4.4).
##
## Ejecutar:
##   .\tools\dev\weather_regions_test.cmd
##
## Valida el contrato world.weather, los seis perfiles de bioma/región, las
## transiciones y la humedad de WeatherManager, los rayos/truenos procedurales,
## la máscara de gotas del parabrisas (H1), el mapa de papel sobre la red
## comprimida de F4.1 y la localización de las claves nuevas. No simula agarre ni
## vadeo: eso es F5.1.

const EXPECTED_VERSION := "0.4.3"
const WEATHER_PATH := "res://data/schemas/world_weather.json"
const BIOMES_PATH := "res://data/schemas/world_biomes.json"
const RAIN_PATH := "res://data/schemas/rain_surface_fx.json"
const EXTERIOR_PATH := "res://data/vehicle/exterior_spec.json"
const LOCALIZATION_PATH := "res://localization/strings.csv"
const SHADER_PATH := "res://shaders/camera_drops.gdshader"
const CABIN_SCENE := "res://scenes/vehicle/CabinInteraction.tscn"
const REGIONS := ["carabobo", "falcon", "merida", "llanos", "amazonas", "delta"]

var _passed := 0
var _failed: Array[String] = []
var _weather: Dictionary = {}
var _biomes: Dictionary = {}
var _rain: Dictionary = {}
var _signal_strikes := 0
var _last_signal: Dictionary = {}


func _ready() -> void:
	print("[WEATHER-QA] Inicio de la prueba de clima, regiones y mapa F4.4")
	await get_tree().process_frame
	_test_version_and_files()
	_weather = _read_json(WEATHER_PATH)
	_biomes = _read_json(BIOMES_PATH)
	_rain = _read_json(RAIN_PATH)
	_test_contract()
	_test_weather_manager()
	_test_transitions()
	_test_lightning_manager()
	await _test_lightning_director()
	_test_camera_mask()
	await _test_cabin_mask()
	await _test_paper_map()
	_test_localization()
	_finish()


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("[WEATHER-QA] OK   %s" % label)
	else:
		_failed.append(label)
		print("[WEATHER-QA] FAIL %s" % label)


func _check_near(value: float, expected: float, tolerance: float, label: String) -> void:
	_check(absf(value - expected) <= tolerance, "%s (%.4f ≈ %.4f)" % [label, value, expected])


func _test_version_and_files() -> void:
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	_check(version == EXPECTED_VERSION, "versión del proyecto %s" % EXPECTED_VERSION)
	_check(FileAccess.get_file_as_string("res://VERSION").strip_edges() == EXPECTED_VERSION, "VERSION coincide")
	for path in [
		WEATHER_PATH, BIOMES_PATH, RAIN_PATH, EXTERIOR_PATH, LOCALIZATION_PATH,
		SHADER_PATH, CABIN_SCENE,
		"res://src/core/weather_manager.gd",
		"res://src/weather/lightning_director.gd",
		"res://src/weather/weather_bridge.gd",
		"res://src/weather/windshield_mask.gd",
		"res://src/world/paper_map.gd",
		"res://tests/weather/WeatherRegionsTest.tscn",
	]:
		_check(FileAccess.file_exists(path), "archivo presente %s" % path)
	var shader := FileAccess.get_file_as_string(SHADER_PATH)
	_check(shader.contains("mask_points"), "shader declara mask_points (H1)")
	_check(shader.contains("discard"), "shader descarta fuera del parabrisas (H1)")
	_check(shader.contains("mask_enabled"), "shader permite desactivar la máscara")


func _test_contract() -> void:
	_check(int(_weather.get("schema_version", 0)) == 1, "world.weather schema_version 1")
	_check(str(_weather.get("contract_id", "")) == "world.weather", "contract_id world.weather")
	_check(str(_weather.get("world_id", "")) == "venezuela.1999", "world_id venezuela.1999")
	_check(str(_weather.get("status", "")) == "active", "contrato activo")
	var presets: Dictionary = _weather.get("presets", {})
	_check(presets.size() == int(_weather.get("qa", {}).get("expected_presets", 0)), "presets declarados = expected_presets")
	_check(presets.size() == 9, "nueve presets de clima")
	var profiles: Dictionary = _weather.get("biome_profiles", {})
	_check(profiles.size() == 6, "seis perfiles de bioma")
	_check(profiles.size() == int(_weather.get("qa", {}).get("expected_biomes", 0)), "perfiles = expected_biomes")
	var biome_ids := {}
	for biome in _biomes.get("biomes", []):
		biome_ids[str(biome.get("id", ""))] = true
	for biome_id in profiles:
		_check(biome_ids.has(str(biome_id)), "perfil de clima para bioma existente %s" % biome_id)
	var region_map: Dictionary = _biomes.get("region_biome_map", {})
	for region in REGIONS:
		_check(region_map.has(region), "región %s en world.biomes" % region)
	var presets_ok := true
	var weights_ok := true
	var temperature_ok := true
	for biome_id in profiles:
		var profile: Dictionary = profiles[biome_id]
		var region := str(profile.get("region", ""))
		_check(str(region_map.get(region, "")) == str(biome_id), "región %s → %s" % [region, biome_id])
		var total := 0.0
		for entry in profile.get("presets", []):
			var preset_id := str(entry.get("id", ""))
			if not presets.has(preset_id):
				presets_ok = false
			total += float(entry.get("weight", 0.0))
			var base: Dictionary = presets.get(preset_id, {})
			var temperature := float(base.get("temperature_c", 0.0)) + float(profile.get("temperature_bias_c", 0.0))
			if temperature < -10.0 or temperature > 45.0:
				temperature_ok = false
		if absf(total - 1.0) > 0.001:
			weights_ok = false
	_check(presets_ok, "todos los perfiles referencian presets existentes")
	_check(weights_ok, "los pesos de cada perfil suman 1.0")
	_check(temperature_ok, "temperaturas de bioma dentro de rango")
	for preset_id in presets:
		var preset: Dictionary = presets[preset_id]
		_check(float(preset.get("humidity", -1.0)) >= 0.0 and float(preset.get("humidity", 2.0)) <= 1.0, "humedad válida %s" % preset_id)
		_check(float(preset.get("rain", -1.0)) >= 0.0 and float(preset.get("rain", 2.0)) <= 1.0, "lluvia válida %s" % preset_id)
		_check(float(preset.get("wind_mps", -1.0)) >= 0.0 and float(preset.get("wind_mps", 30.0)) <= 25.0, "viento válido %s" % preset_id)
		_check(str(preset.get("name_key", "")).begins_with("WEATHER_PRESET_"), "clave de nombre %s" % preset_id)
	var rain_contract := float(_rain.get("precipitation", {}).get("rain_intensity_to_mm_h", 0.0))
	_check_near(float(_weather.get("rain_coupling", {}).get("rain_intensity_to_mm_h", 0.0)), rain_contract, 0.001, "lluvia normalizada → mm/h coincide con rain_surface_fx")
	var lightning: Dictionary = _weather.get("lightning", {})
	_check(bool(lightning.get("enabled", false)), "rayos habilitados")
	_check(str(lightning.get("requires_preset", "")) == "storm", "los rayos requieren tormenta")
	_check(int(lightning.get("max_strikes_per_minute", 0)) <= 12, "tope de rayos por minuto")
	var distance: Array = lightning.get("distance_km", [0.0, 0.0])
	_check(float(distance[0]) <= float(distance[1]), "rango de distancia de rayos coherente")
	var thunder: Dictionary = lightning.get("thunder", {})
	_check(int(thunder.get("sample_rate", 0)) >= 8000, "trueno con frecuencia de muestreo válida")
	_check(str(thunder.get("note", "")).to_lower().contains("sin samples"), "trueno sintetizado, sin samples")
	var camera_mask: Dictionary = _weather.get("camera_mask", {})
	_check(bool(camera_mask.get("enabled", false)), "máscara de parabrisas habilitada")
	_check(int(camera_mask.get("max_points", 99)) <= 8, "máscara dentro de los 8 puntos del shader")
	_check(bool(_weather.get("anti_softlock", {}).get("weather_never_blocks", false)), "el clima no bloquea la partida")
	_check(bool(_weather.get("anti_softlock", {}).get("lightning_no_damage", false)), "los rayos no dañan el vehículo")
	_check(str(_weather.get("attribution", {}).get("network_license", "")) == "ODbL-1.0", "atribución ODbL conservada")
	_check(bool(_weather.get("attribution", {}).get("no_new_osm_data", false)), "el mapa no introduce datos OSM nuevos")


func _test_weather_manager() -> void:
	_check(WeatherManager.presets.size() == 9, "WeatherManager carga los nueve presets")
	_check(WeatherManager.biome_profiles.size() == 6, "WeatherManager carga los seis perfiles")
	_check(not WeatherManager.set_preset("tornado", true), "rechaza un preset inexistente")
	_check(not WeatherManager.set_region("marte", true), "rechaza una región inexistente")
	for region in REGIONS:
		_check(WeatherManager.set_region(region, true), "activa la región %s" % region)
		var state := WeatherManager.get_state()
		var expected_biome := str(WeatherManager.get_biome_for_region(region))
		_check(str(state.get("biome", "")) == expected_biome, "bioma correcto en %s" % region)
		_check(str(state.get("region", "")) == region, "región publicada en %s" % region)
		var profile: Dictionary = WeatherManager.biome_profiles.get(expected_biome, {})
		var allowed := {}
		for entry in profile.get("presets", []):
			allowed[str(entry.get("id", ""))] = true
		_check(allowed.has(str(state.get("preset", ""))), "preset dentro del perfil de %s" % region)
		_check(float(state.get("humidity", -1.0)) >= 0.0 and float(state.get("humidity", 2.0)) <= 1.0, "humedad 0..1 en %s" % region)
		_check(float(state.get("wind", -1.0)) >= 0.0 and float(state.get("wind", 30.0)) <= 25.0, "viento 0..25 en %s" % region)
		_check(float(state.get("temperature", -99.0)) >= -10.0 and float(state.get("temperature", 99.0)) <= 45.0, "temperatura dentro de rango en %s" % region)
		_check(bool(state.has("wetness")), "humedad de superficie declarada en %s" % region)
	_check(WeatherManager.set_biome("biome.montana", true), "fija un bioma directamente")
	_check(str(WeatherManager.get_state().get("region", "")) == "merida", "el bioma deriva su región")
	WeatherManager.set_seed(4242)
	var first := WeatherManager.advance_weather()
	var second := WeatherManager.advance_weather()
	_check(not first.is_empty() and not second.is_empty(), "avance automático devuelve presets")
	_check(WeatherManager.get_preset_names().size() == 9, "API de presets conserva tamaño")


func _test_transitions() -> void:
	WeatherManager.set_region("carabobo", true)
	WeatherManager.set_preset("clear", true)
	var clear_state := WeatherManager.get_state()
	_check_near(float(clear_state.get("rain", 1.0)), 0.0, 0.001, "despejado sin lluvia")
	WeatherManager.set_preset("storm", false)
	_check(WeatherManager.get_state().get("transition", "") == "blending", "la transición comienza en blending")
	WeatherManager.step(0.2)
	var mid := WeatherManager.get_state()
	var mid_rain := float(mid.get("rain", 0.0))
	_check(mid_rain > 0.0 and mid_rain < 0.9, "lluvia interpolada a mitad de transición (%.3f)" % mid_rain)
	for _index in range(30):
		WeatherManager.step(1.0)
	var settled := WeatherManager.get_state()
	_check_near(float(settled.get("rain", 0.0)), 0.9, 0.02, "lluvia converge a tormenta")
	_check(settled.get("transition", "") == "idle", "la transición termina en idle")
	_check(float(settled.get("wetness", 0.0)) > 0.7, "la humedad de superficie sube con la tormenta")
	WeatherManager.set_preset("clear", false)
	for _index in range(40):
		WeatherManager.step(1.0)
	_check(float(WeatherManager.get_state().get("wetness", 1.0)) < 0.05, "la humedad baja al despejarse")
	var steps := 1000
	var start := Time.get_ticks_usec()
	for _index in range(steps):
		WeatherManager.step(1.0 / 60.0)
	var elapsed_ms := float(Time.get_ticks_usec() - start) / 1000.0 / float(steps)
	var budget := float(_weather.get("budgets", {}).get("pc", {}).get("weather_cpu_budget_ms", 0.25))
	_check(elapsed_ms < budget, "paso de clima %.4f ms < %.2f ms" % [elapsed_ms, budget])
	var state := WeatherManager.get_state()
	_check(float(state.get("next_change_in_s", -2.0)) >= 0.0, "autoavance programado")
	_check(not state.has("nan"), "estado sin NaN")


func _test_lightning_manager() -> void:
	_signal_strikes = 0
	_last_signal = {}
	if not EventBus.weather_lightning.is_connected(_on_weather_lightning):
		EventBus.weather_lightning.connect(_on_weather_lightning)
	WeatherManager.set_region("llanos", true)
	WeatherManager.set_preset("clear", true)
	_check(WeatherManager.force_lightning().is_empty(), "sin rayos en clima despejado")
	WeatherManager.set_preset("storm", true)
	var strike := WeatherManager.force_lightning()
	_check(not strike.is_empty(), "rayo forzado en tormenta")
	_check(int(strike.get("index", 0)) > 0, "el rayo tiene índice")
	_check(float(strike.get("distance_km", 0.0)) >= 0.8 and float(strike.get("distance_km", 0.0)) <= 6.0, "distancia de rayo dentro del contrato")
	_check_near(float(strike.get("delay_s", 0.0)), float(strike.get("distance_km", 0.0)) * 2.9, 0.05, "retardo de trueno por distancia")
	_check(strike.has("double_flash"), "doble destello declarado")
	_check(_signal_strikes == 1, "EventBus.weather_lightning emitido")
	_check(str(_last_signal.get("biome", "")) == "biome.llanos", "el rayo publica el bioma")
	_check(WeatherManager.strikes >= 1, "contador de rayos incrementado")
	WeatherManager.set_seed(99)
	for _index in range(20):
		WeatherManager.force_lightning()
	_check(WeatherManager.strikes <= 14, "tope de rayos por minuto respetado")
	WeatherManager.set_preset("storm", true)
	var before := WeatherManager.strikes
	for _index in range(60):
		WeatherManager.step(1.0)
	_check(WeatherManager.strikes > before, "la tormenta programa rayos automáticos")


func _test_lightning_director() -> void:
	var director := LightningDirector.new()
	director.name = "TestLightning"
	add_child(director)
	await get_tree().process_frame
	var stats := director.get_stats()
	_check(int(stats.get("errors", -1)) == 0, "LightningDirector sin errores")
	_check(int(stats.get("thunder_bytes", 0)) > 10000, "trueno sintetizado con datos PCM")
	_check(director.thunder_stream != null, "stream de trueno creado")
	_check(director.flash_light != null, "luz de rayo creada")
	_check(director.flash_overlay != null, "flash de pantalla creado")
	var sample := director.thunder_stream.data.slice(0, 400)
	_check(sample.size() == 400, "datos PCM accesibles")
	var second := LightningDirector.new()
	add_child(second)
	second._load_config()
	second._build_nodes()
	_check(director.thunder_stream.data == second.thunder_stream.data, "trueno determinista")
	director.trigger({
		"index": 1, "distance_km": 2.0, "delay_s": 0.0,
		"energy": 9.0, "flash_duration_s": 0.18, "double_flash": false, "gap_s": 0.09,
	})
	_check(int(director.get_stats().get("pending_thunder", 0)) == 1, "trueno pendiente programado")
	_check(bool(director.get_stats().get("bolt_built", false)), "rayo visible construido")
	_check(bool(director.get_stats().get("bolt_visible", false)), "rayo visible durante el destello")
	director.apply_flash(9.0)
	_check_near(director.flash_light.light_energy, 9.0, 0.01, "destello aplicado a la luz")
	_check(director.flash_overlay.color.a > 0.0, "flash de pantalla visible")
	director._process(0.01)
	_check(int(director.get_stats().get("thunder_played", 0)) == 1, "trueno reproducido tras el retardo")
	director.queue_free()
	second.queue_free()
	await get_tree().process_frame


func _test_camera_mask() -> void:
	var square := PackedVector2Array([
		Vector2(0, 0), Vector2(200, 0), Vector2(200, 100), Vector2(0, 100),
	])
	var hull := WindshieldMask.convex_hull_uv(square, Vector2(200, 100))
	_check(hull.size() == 4, "casco convexo de un rectángulo")
	_check(WindshieldMask.contains_uv(hull, Vector2(0.5, 0.5)), "centro dentro del parabrisas")
	_check(not WindshieldMask.contains_uv(hull, Vector2(1.2, 0.5)), "fuera del parabrisas descartado")
	_check(WindshieldMask.convex_hull_uv(square, Vector2.ZERO).is_empty(), "viewport inválido sin máscara")
	_check(WindshieldMask.convex_hull_uv(PackedVector2Array([Vector2.ZERO, Vector2.ONE]), Vector2(10, 10)).is_empty(), "menos de tres puntos sin máscara")
	var eight := PackedVector2Array([
		Vector2(0, 0), Vector2(50, 0), Vector2(100, 0), Vector2(100, 50),
		Vector2(100, 100), Vector2(50, 100), Vector2(0, 100), Vector2(0, 50),
	])
	_check(WindshieldMask.convex_hull_uv(eight, Vector2(100, 100)).size() <= 8, "casco limitado a ocho puntos")
	var exterior := _read_json(EXTERIOR_PATH)
	var corners: Array = []
	for panel in exterior.get("glass_panels", []):
		if str(panel.get("id", "")) == "windshield":
			corners = panel.get("corners_m", [])
	_check(corners.size() == 4, "exterior_spec declara cuatro esquinas del parabrisas")
	_check(not _weather.get("camera_mask", {}).is_empty(), "contrato declara la máscara de cámara")


func _test_cabin_mask() -> void:
	var packed := load(CABIN_SCENE) as PackedScene
	if packed == null:
		_check(false, "escena de cabina cargable")
		return
	var scene := packed.instantiate()
	add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var rain := scene.get_node_or_null("RainFx") as RainFxController
	_check(rain != null, "RainFx presente en la cabina")
	if rain != null:
		rain.refresh_uniforms()
		var mask := rain.get_camera_mask()
		_check(int(mask.get("corners", 0)) == 4, "la cabina usa las cuatro esquinas del parabrisas")
		_check(str(mask.get("mode", "")) == "windshield_mesh", "las gotas usan la malla real del parabrisas (H1)")
		_check(int(mask.get("mesh_vertices", 0)) == 4, "malla de gotas con cuatro vértices")
		_check(bool(mask.get("overlay_visible", false)), "gotas visibles dentro del parabrisas")
	_check(scene.get_node_or_null("LightningDirector") != null, "la cabina tiene rayos")
	_check(scene.get_node_or_null("WeatherBridge") != null, "la cabina tiene puente de clima")
	scene.queue_free()
	await get_tree().process_frame


func _test_paper_map() -> void:
	var network := RouteNetwork.new()
	_check(network.load_all(), "red de F4.1 carga con hash válido")
	var map := PaperMap.new()
	map.name = "TestPaperMap"
	map.size = Vector2(960, 640)
	add_child(map)
	var routes_contract := _read_json("res://data/schemas/world_routes.json")
	_check(map.setup(network, routes_contract), "mapa de papel construido desde la red existente")
	var stats := map.get_map_stats()
	_check(int(stats.get("routes", 0)) == network.routes.size(), "una polilínea por ruta principal")
	_check(int(stats.get("routes", 0)) >= 6, "al menos seis rutas en el mapa")
	_check(int(stats.get("edges", 0)) == network.edges.size(), "todas las aristas comprimidas en el mapa")
	_check(int(stats.get("hubs", 0)) == 6, "seis hubs de región en el mapa")
	_check(int(stats.get("country_points", 0)) >= 20, "silueta de Venezuela con puntos suficientes")
	_check(
		Geometry2D.triangulate_polygon(map.country_outline()).size() > 0,
		"silueta del país triangulable para el mapa"
	)
	var bounds: Rect2 = stats.get("bounds", Rect2())
	_check(bounds.size.x > 1000.0 and bounds.size.y > 1000.0, "extensión del mapa calculada")
	var falcon_pos: Vector2 = map.project_world(network.node_game_position("hub_falcon"))
	var amazonas_pos: Vector2 = map.project_world(network.node_game_position("hub_amazonas"))
	var delta_pos: Vector2 = map.project_world(network.node_game_position("hub_delta"))
	var merida_pos: Vector2 = map.project_world(network.node_game_position("hub_merida"))
	_check(falcon_pos.y < amazonas_pos.y, "norte arriba: Falcón sobre Amazonas")
	_check(delta_pos.x > merida_pos.x, "este a la derecha: Delta al este de Mérida")
	_check(falcon_pos.y < merida_pos.y or falcon_pos.x > merida_pos.x, "Falcón al norte del eje andino")
	_check(not map.is_open(), "mapa cerrado al iniciar")
	_check(map.toggle(), "mapa se abre")
	_check(map.is_open(), "mapa abierto")
	map.set_progress("route.carabobo_falcon", Vector3(1200.0, 40.0, -800.0))
	_check(str(map.get_map_stats().get("active_route", "")) == "route.carabobo_falcon", "ruta activa reflejada")
	_check(map.toggle() == false, "mapa se cierra")
	_check(str(stats.get("credit", "")).contains("OpenStreetMap"), "atribución OSM en el mapa")
	var map_source := FileAccess.get_file_as_string("res://src/world/paper_map.gd")
	_check(not map_source.contains("load("), "el mapa no carga recursos en runtime")
	_check(not map_source.contains("Overpass"), "el mapa no consulta Overpass")
	map.queue_free()
	await get_tree().process_frame


func _test_localization() -> void:
	var csv := FileAccess.get_file_as_string(LOCALIZATION_PATH)
	var keys := [
		"WEATHER_PRESET_CLEAR", "WEATHER_PRESET_OVERCAST", "WEATHER_PRESET_DRIZZLE",
		"WEATHER_PRESET_RAIN", "WEATHER_PRESET_STORM", "WEATHER_PRESET_FOG",
		"WEATHER_PRESET_SANDSTORM", "WEATHER_PRESET_SNOW", "WEATHER_PRESET_SWAMP_MIST",
		"WORLD_WEATHER_LINE", "WORLD_MAP_BUTTON", "WORLD_MAP_BUTTON_CLOSE",
		"MAP_TITLE", "MAP_SUBTITLE", "MAP_ACTIVE_ROUTE",
		"MAP_LEGEND_ACTIVE", "MAP_LEGEND_MAIN", "MAP_LEGEND_SECONDARY",
	]
	for key in keys:
		_check(csv.contains("%s," % key), "clave de localización %s" % key)
	_check(csv.contains("FASE 4.4") or csv.contains("PHASE 4.4"), "BOOT_KICKER en fase 4.4")
	_check(csv.contains("v0.4.3"), "SLICE_TITLE en v0.4.3")
	var preset_keys := 0
	for preset in _weather.get("presets", {}).values():
		if csv.contains("%s," % str(preset.get("name_key", ""))):
			preset_keys += 1
	_check(preset_keys == 9, "las nueve claves de preset están en el CSV")


func _on_weather_lightning(strike: Dictionary) -> void:
	_signal_strikes += 1
	_last_signal = strike


func _finish() -> void:
	if _failed.is_empty():
		print("[WEATHER-QA] SUPERADO %d comprobaciones" % _passed)
		print("[WEATHER] SUPERADO %d/%d" % [_passed, _passed])
		get_tree().quit(0)
	else:
		for failure in _failed:
			print("[WEATHER-QA] FALLO: %s" % failure)
		print("[WEATHER-QA] FALLIDO %d de %d" % [_failed.size(), _passed + _failed.size()])
		get_tree().quit(1)


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
