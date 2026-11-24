extends Node3D
## Prueba del terreno, streaming de 800 m, colisión y carga asíncrona (F4.2).
##
## Ejecutar:
##   .\tools\dev\world_streaming_test.cmd
##
## Carga los 454 recursos horneados, valida sus campos, instancia la escena real
## del mundo, comprueba el streaming con ResourceLoader.load_threaded_request(),
## el límite de dos solicitudes, la ausencia de load() síncrono, la colisión y
## el punto de reaparición seguro.

const EXPECTED_VERSION := "0.4.1"
const CONTRACT_PATH := "res://data/schemas/world_streaming.json"
const ROUTES_CONTRACT_PATH := "res://data/schemas/world_routes.json"
const NETWORK_PATH := "res://data/content/world/route_network.json"
const MANIFEST_PATH := "res://data/content/world/sectors.manifest.json"
const SCENE_PATH := "res://scenes/world/WorldTerrain.tscn"
const ODBL_PATH := "res://licenses/ODbL-1.0.txt"
const LOCALIZATION_PATH := "res://localization/strings.csv"

var _passed := 0
var _failed: Array[String] = []
var _contract: Dictionary = {}
var _routes_contract: Dictionary = {}
var _manifest: Dictionary = {}


func _ready() -> void:
	print("[STREAM] Inicio de la prueba de terreno y streaming F4.2")
	await get_tree().process_frame
	_test_version()
	_contract = _read_json(CONTRACT_PATH)
	_routes_contract = _read_json(ROUTES_CONTRACT_PATH)
	_manifest = _read_json(MANIFEST_PATH)
	_test_files()
	_test_contract()
	_test_manifest()
	_test_sector_resources()
	await _test_runtime()
	_finish()


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("[STREAM] OK   %s" % label)
	else:
		_failed.append(label)
		print("[STREAM] FAIL %s" % label)


func _test_version() -> void:
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	_check(version == EXPECTED_VERSION, "versión del proyecto %s" % EXPECTED_VERSION)
	_check(FileAccess.get_file_as_string("res://VERSION").strip_edges() == EXPECTED_VERSION, "VERSION coincide")


func _test_files() -> void:
	for path in [
		CONTRACT_PATH,
		ROUTES_CONTRACT_PATH,
		NETWORK_PATH,
		MANIFEST_PATH,
		SCENE_PATH,
		ODBL_PATH,
		LOCALIZATION_PATH,
	]:
		_check(FileAccess.file_exists(path), "archivo presente %s" % path)
	_check(FileAccess.get_file_as_string(ODBL_PATH).to_lower().contains("odbl"), "texto ODbL presente")
	var csv := FileAccess.get_file_as_string(LOCALIZATION_PATH)
	_check(csv.contains("CREDITS_OSM,"), "CREDITS_OSM en localización")
	_check(csv.contains("WORLD_STATS,"), "WORLD_STATS en localización")
	_check(csv.contains("UI_VIEW_WORLD,"), "UI_VIEW_WORLD en localización")


func _test_contract() -> void:
	_check(int(_contract.get("schema_version", 0)) == 1, "contrato schema_version 1")
	_check(str(_contract.get("contract_id", "")) == "world.streaming", "contract_id world.streaming")
	_check(str(_contract.get("world_id", "")) == "venezuela.1999", "world_id venezuela.1999")
	_check(str(_contract.get("status", "")) == "active", "contrato activo")
	var terrain: Dictionary = _contract.get("terrain", {})
	var streaming: Dictionary = _contract.get("streaming", {})
	var road: Dictionary = terrain.get("road", {})
	var collision: Dictionary = _contract.get("collision", {})
	var budgets: Dictionary = _contract.get("budgets", {})
	var attribution: Dictionary = _contract.get("attribution", {})
	var qa: Dictionary = _contract.get("qa", {})
	_check(float(terrain.get("sector_size_m", 0.0)) == 800.0, "sector de terreno de 800 m")
	_check(int(terrain.get("grid_resolution", 0)) == 33, "rejilla de 33×33")
	_check(absf(float(terrain.get("grid_spacing_m", 0.0)) - 25.0) < 0.01, "espaciado de 25 m")
	_check(absf(float(road.get("width_m", 0.0)) - 7.2) < 0.01, "ancho de vía 7,2 m")
	_check(float(streaming.get("sector_size_m", 0.0)) == 800.0, "sector de streaming de 800 m")
	_check(int(streaming.get("max_concurrent_requests", 0)) == 2, "máximo dos solicitudes")
	_check(str(streaming.get("loader_api", "")) == "ResourceLoader.load_threaded_request", "API threaded")
	_check(bool(streaming.get("sync_load_forbidden", false)), "load() síncrono prohibido")
	_check(int(streaming.get("ahead_sectors", 0)) >= 1, "ventana por delante")
	_check(int(streaming.get("behind_sectors", 0)) >= 1, "ventana por detrás")
	_check(str(collision.get("terrain_shape", "")) == "ConcavePolygonShape3D", "colisión de terreno")
	_check(int(collision.get("terrain_stride", 0)) == 2, "colisión de terreno a 50 m")
	_check(str(collision.get("road_shape", "")) == "ConcavePolygonShape3D", "colisión de vía")
	_check(int(budgets.get("max_total_visible_triangles_mobile", 0)) == 120000, "presupuesto móvil 120k")
	_check(int(budgets.get("max_total_visible_triangles_pc", 0)) == 450000, "presupuesto PC 450k")
	_check(absf(float(budgets.get("max_pss_mb", 0.0)) - 1228.8) < 0.01, "presupuesto PSS 1,2 GB")
	_check(float(budgets.get("runtime_load_budget_ms", 0.0)) == 250.0, "presupuesto de carga 250 ms")
	_check(str(attribution.get("license", "")) == "ODbL 1.0", "atribución ODbL 1.0")
	_check(str(attribution.get("in_game_key", "")) == "CREDITS_OSM", "clave CREDITS_OSM")
	_check(str(qa.get("android_route", "")) == "slice,cabin,world", "ruta Android con world")
	_check(FileAccess.file_exists(str(qa.get("test_scene", ""))), "escena de prueba declarada existe")
	_check(FileAccess.file_exists(str(qa.get("test_command", ""))), "comando de prueba declarado existe")
	_check(FileAccess.file_exists(str(qa.get("bake_command", ""))), "comando de horneado declarado existe")


func _test_manifest() -> void:
	_check(str(_manifest.get("contract_id", "")) == "world.streaming", "manifiesto contract_id")
	var sectors: Array = _manifest.get("sectors", [])
	_check(int(_manifest.get("sector_count", 0)) == sectors.size(), "sector_count coherente")
	_check(sectors.size() == int(_contract.get("qa", {}).get("expected_sector_count", -1)), "sectores esperados")
	_check(int(_manifest.get("grid_resolution", 0)) == 33, "manifiesto con rejilla 33")
	_check(absf(float(_manifest.get("sector_size_m", 0.0)) - 800.0) < 0.01, "manifiesto con sector 800")
	_check(int(_manifest.get("total_bytes", 0)) > 1_000_000, "manifiesto con recursos suficientes")
	_check(
		int(_manifest.get("total_bytes", 0)) <= int(_contract.get("budgets", {}).get("max_sector_bytes", 0)),
		"manifiesto dentro del presupuesto de bytes"
	)
	_check(int(_manifest.get("total_terrain_triangles", 0)) == sectors.size() * 2048, "triángulos de terreno")
	var source: Dictionary = _manifest.get("source", {})
	_check(str(source.get("license", "")) == "ODbL 1.0", "manifiesto ODbL 1.0")
	_check(str(source.get("copyright", "")).contains("OpenStreetMap"), "manifiesto con copyright OSM")
	_check(
		str(source.get("route_network_sha256", "")) == _sha256_file(NETWORK_PATH),
		"hash de la red coincide con el manifiesto"
	)
	var ids := {}
	var duplicate := 0
	var paths_ok := true
	for entry in sectors:
		var id := str(entry.get("id", ""))
		if ids.has(id):
			duplicate += 1
		ids[id] = true
		if not str(entry.get("path", "")).begins_with("data/content/world/sectors/"):
			paths_ok = false
	_check(duplicate == 0, "IDs de sector únicos")
	_check(paths_ok, "rutas de sector bajo data/content/world/sectors")
	_check(float(_manifest.get("height_min_m", 0.0)) < float(_manifest.get("height_max_m", 0.0)), "rango de altura válido")


func _test_sector_resources() -> void:
	var sectors: Array = _manifest.get("sectors", [])
	var failures := 0
	var road_sectors := 0
	var total_bytes := 0
	var max_road_triangles := 0
	var min_height := INF
	var max_height := -INF
	var localization_ok := 0
	for entry in sectors:
		var path := "res://" + str(entry.get("path", ""))
		var resource: Resource = ResourceLoader.load(path)
		total_bytes += FileAccess.get_file_as_bytes(path).size()
		if not (resource is WorldSectorData):
			failures += 1
			continue
		var data := resource as WorldSectorData
		if not data.is_valid():
			failures += 1
			continue
		if data.key() != str(entry.get("id", "")):
			failures += 1
		if data.sector_size_m != 800.0 or data.grid_resolution != 33:
			failures += 1
		if data.heights.size() != 1089 or data.terrain_triangle_count != 2048:
			failures += 1
		if data.road_vertices.size() % 3 != 0 or data.marking_vertices.size() % 3 != 0:
			failures += 1
		if data.road_triangle_count > int(_contract.get("budgets", {}).get("max_road_triangles_per_sector", 0)):
			failures += 1
		if data.road_triangle_count > 0:
			road_sectors += 1
			if data.road_edge_ids.is_empty():
				failures += 1
		max_road_triangles = maxi(max_road_triangles, data.road_triangle_count)
		min_height = minf(min_height, data.height_min_m)
		max_height = maxf(max_height, data.height_max_m)
		if data.source_attribution.contains("OpenStreetMap") and data.source_attribution.contains("ODbL"):
			localization_ok += 1
		for height in data.heights:
			if not is_finite(height):
				failures += 1
				break
		for vertex in data.road_vertices:
			if not vertex.is_finite():
				failures += 1
				break
	_check(failures == 0, "todos los recursos de sector son válidos")
	_check(road_sectors >= 400, "sectores con vía horneada")
	_check(localization_ok == sectors.size(), "atribución ODbL en todos los sectores")
	_check(max_road_triangles <= 800, "triángulos de vía por sector dentro del presupuesto")
	_check(total_bytes == int(_manifest.get("total_bytes", -1)), "bytes reales coinciden con el manifiesto")
	_check(min_height > -100.0 and max_height < 5000.0, "alturas de sector en rango")
	print(
		"[STREAM] Sectores verificados: %d, con vía %d, bytes %d, vía máx %d, altura %.1f..%.1f"
		% [sectors.size(), road_sectors, total_bytes, max_road_triangles, min_height, max_height]
	)


func _test_runtime() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	_check(packed != null, "escena WorldTerrain carga")
	if packed == null:
		return
	var scene := packed.instantiate() as WorldDirector
	_check(scene != null, "escena instancia WorldDirector")
	if scene == null:
		return
	scene.autotour = false
	add_child(scene)
	var ready := await _wait_until(func() -> bool: return scene.is_world_ready(), 20000)
	_check(ready, "mundo listo tras la carga inicial")
	if not ready:
		scene.queue_free()
		return
	var streamer := scene.get_node("SectorStreamer") as WorldSectorStreamer
	_check(streamer != null, "SectorStreamer presente")
	if streamer == null:
		scene.queue_free()
		return
	await get_tree().physics_frame
	await get_tree().physics_frame
	var snapshot := scene.streaming_snapshot()
	_check(int(snapshot.get("network_load_ms", 9999)) <= 250, "carga del grafo ≤ 250 ms")
	_check(int(snapshot.get("initial_stream_ms", 99999)) <= 20000, "carga inicial ≤ 20 s")
	_check(int(snapshot.get("loaded_sectors", 0)) >= 4, "ventana inicial cargada")
	_check(int(snapshot.get("loaded_triangles", 0)) <= 10 * 3000, "triángulos iniciales dentro del presupuesto")
	_check(int(snapshot.get("sync_load_calls", -1)) == 0, "cero load() síncrono")
	_check(int(snapshot.get("max_concurrent_requests_seen", 99)) <= 2, "nunca más de dos solicitudes")
	_check(int(snapshot.get("peak_loaded_sectors", 99)) <= 10, "nunca más de diez sectores cargados")
	_check(int(snapshot.get("sector_errors", -1)) == 0, "sin errores de sector")
	_check(scene.world_errors.is_empty(), "sin errores del director")
	_check(scene.route_ids.size() == 6, "seis rutas principales")
	_check(streamer.loaded_sector_count() == streamer.loaded_keys().size(), "contador de sectores cargados")
	var keys := streamer.loaded_keys()
	var current_key := scene.current_sector_key()
	_check(streamer.loaded_node(current_key) != null, "sector actual cargado")
	var collision_ok := true
	for key in keys:
		var node := streamer.loaded_node(key)
		if node == null or node.get_node_or_null("Body") == null or node.get_node_or_null("Body/TerrainShape") == null or node.get_node_or_null("Body/RoadShape") == null:
			collision_ok = false
	_check(collision_ok, "cada sector tiene cuerpo y colisión")

	var vehicle := scene.get_node_or_null("Vehicle") as Node3D
	_check(vehicle != null, "vehículo de presentación presente")
	if vehicle != null:
		var hit := _raycast_down(vehicle.global_position + Vector3.UP * 2.0)
		_check(not hit.is_empty(), "raycast sobre la vía del vehículo")
		if not hit.is_empty():
			_check(absf(float(hit.get("position", Vector3.ZERO).y) - vehicle.global_position.y) < 1.5, "colisión a la altura de la vía")

	var respawn := scene.safe_respawn_point(scene.current_route_id(), scene.current_progress_m() + 5000.0)
	_check(bool(respawn.get("found", false)), "punto de reaparición con colisión")
	if bool(respawn.get("found", false)):
		_check(float(respawn.get("slope_pct", 99.0)) <= 20.0, "reaparición en pendiente segura")
		var respawn_position: Vector3 = respawn.get("position", Vector3.ZERO)
		_check(respawn_position.is_finite(), "posición de reaparición finita")

	var old_keys := streamer.loaded_keys().duplicate()
	scene.seek(minf(12000.0, scene.current_route_total_m() - 100.0))
	var target_key := scene.current_sector_key()
	var moved := await _wait_until(
		func() -> bool:
			return (
				streamer.is_idle()
				and streamer.loaded_sector_count() >= 3
				and streamer.loaded_node(target_key) != null
			),
		20000
	)
	_check(moved, "streaming tras avanzar 12 km")
	var new_keys := streamer.loaded_keys()
	var removed := false
	for key in old_keys:
		if not new_keys.has(key):
			removed = true
			break
	_check(removed, "sectores lejanos descargados")
	_check(int(streamer.stats().get("sync_load_calls", -1)) == 0, "cero load() síncrono tras avanzar")
	_check(int(streamer.stats().get("max_concurrent_requests_seen", 99)) <= 2, "dos solicitudes máximas tras avanzar")
	_check(int(streamer.stats().get("peak_loaded_sectors", 99)) <= 10, "límite de residentes tras avanzar")
	_check(int(streamer.stats().get("loaded_sectors", 0)) >= 3, "nueva ventana cargada")
	_check(int(streamer.stats().get("loaded_sectors", 0)) <= 10, "ventana dentro del presupuesto")
	_check(absf(scene.current_progress_m() - 12000.0) < 1.0 or scene.current_route_total_m() < 12000.0, "progreso del tour aplicado")

	var previous_route := scene.current_route_id()
	scene.next_route()
	var route_ready := await _wait_until(func() -> bool: return scene.is_world_ready(), 20000)
	_check(route_ready, "siguiente ruta lista")
	_check(scene.current_route_id() != previous_route, "cambio de ruta efectivo")
	_check(streamer.loaded_sector_count() >= 4, "sectores de la nueva ruta cargados")
	_check(int(streamer.stats().get("sector_errors", -1)) == 0, "sin errores al cambiar de ruta")
	_check(int(streamer.stats().get("sync_load_calls", -1)) == 0, "cero load() síncrono al cambiar de ruta")

	# Cobertura de las seis rutas en tres posiciones cada una: la ventana debe
	# recuperarse también cuando la ruta cruza sectores repetidos o de borde.
	var route_failures := 0
	for route_target in range(scene.route_ids.size()):
		if scene.route_index != route_target:
			scene.next_route()
			var route_ready_loop := await _wait_until(func() -> bool: return scene.is_world_ready(), 20000)
			if not route_ready_loop:
				route_failures += 1
				continue
		var total := scene.current_route_total_m()
		for fraction in [0.1, 0.5, 0.9]:
			scene.seek(total * fraction)
			var target := scene.current_sector_key()
			var sector_ok := await _wait_until(
				func() -> bool:
					return (
						streamer.is_idle()
						and streamer.loaded_node(target) != null
						and streamer.loaded_sector_count() > 0
					),
				20000
			)
			if not sector_ok:
				route_failures += 1
			if int(streamer.stats().get("sync_load_calls", 1)) != 0:
				route_failures += 1
			if int(streamer.stats().get("max_concurrent_requests_seen", 99)) > 2:
				route_failures += 1
	_check(route_failures == 0, "las seis rutas cargan sectores al 10/50/90 %")
	_check(int(streamer.stats().get("sector_errors", -1)) == 0, "sin errores tras recorrer las seis rutas")
	_check(int(streamer.stats().get("sync_load_calls", -1)) == 0, "cero load() síncrono tras las seis rutas")

	scene.queue_free()
	await get_tree().process_frame


func _raycast_down(position: Vector3) -> Dictionary:
	var world := get_world_3d()
	if world == null:
		return {}
	var query := PhysicsRayQueryParameters3D.create(position + Vector3.UP * 50.0, position + Vector3.DOWN * 50.0, 1)
	var result := world.direct_space_state.intersect_ray(query)
	return result if result is Dictionary else {}


func _wait_until(condition: Callable, timeout_ms: int) -> bool:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < timeout_ms:
		if bool(condition.call()):
			return true
		await get_tree().process_frame
	return bool(condition.call())


func _sha256_file(path: String) -> String:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return ""
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	context.update(bytes)
	return context.finish().hex_encode()


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _finish() -> void:
	var total := _passed + _failed.size()
	if _failed.is_empty():
		print("[STREAM] OK %d comprobaciones de terreno y streaming" % _passed)
		get_tree().quit(0)
	else:
		print("[STREAM] FAIL %d de %d comprobaciones" % [_failed.size(), total])
		for label in _failed:
			print("[STREAM] FALLO %s" % label)
		get_tree().quit(1)
