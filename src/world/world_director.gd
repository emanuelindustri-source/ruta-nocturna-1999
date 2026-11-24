class_name WorldDirector
extends Node3D
## Servicio de escena del mundo (F4.2), NO autoload.
##
## Carga RouteNetwork (F4.1), el contrato world.streaming, el manifiesto de
## sectores y conduce el tour de presentación. El streaming de sectores de 800 m
## vive en WorldSectorStreamer y usa ResourceLoader.load_threaded_request().

signal world_ready
signal route_changed(index: int, route_id: String)

const BOOT_SCENE := "res://scenes/boot/Boot.tscn"
const NETWORK_PATH := "res://data/content/world/route_network.json"
const SECTORS_MANIFEST_PATH := "res://data/content/world/sectors.manifest.json"
const STREAMING_CONTRACT_PATH := "res://data/schemas/world_streaming.json"
const ROUTES_CONTRACT_PATH := "res://data/schemas/world_routes.json"
const DEFAULT_ROUTE := "route.carabobo_falcon"
const DEFAULT_START_FRACTION := 0.02
const STATS_INTERVAL := 0.25
const RESPAWN_COLLISION_MASK := 1

@export var route_id: String = ""
@export var tour_speed_mps := 35.0
@export var autotour := true
@export var start_fraction := DEFAULT_START_FRACTION

var network := RouteNetwork.new()
var streaming_contract: Dictionary = {}
var routes_contract: Dictionary = {}
var sectors_manifest: Dictionary = {}
var route_ids: Array[String] = []
var route_index := 0
var network_load_ms := 0
var initial_stream_ms := 0
var world_errors: Array[String] = []

var _streamer: WorldSectorStreamer
var _route_data: Dictionary = {}
var _route_cache: Dictionary = {}
var _progress_m := 0.0
var _world_ready := false
var _loading_started_ms := 0
var _stats_elapsed := 0.0
var _paused := false
var _sample_index := 0
var _vehicle: Node3D
var _camera: Camera3D
var _title_label: Label
var _route_label: Label
var _stats_label: Label
var _loading_label: Label
var _next_button: Button
var _back_button: Button
var _credits_label: Label


func _ready() -> void:
	_streamer = get_node_or_null("SectorStreamer") as WorldSectorStreamer
	if _streamer == null:
		_streamer = WorldSectorStreamer.new()
		_streamer.name = "SectorStreamer"
		add_child(_streamer)
	_streamer.initial_ready.connect(_on_initial_ready)
	_vehicle = get_node_or_null("Vehicle") as Node3D
	_camera = get_node_or_null("Camera3D") as Camera3D
	_title_label = get_node_or_null("Overlay/Panel/Margin/VBox/Title") as Label
	_route_label = get_node_or_null("Overlay/Panel/Margin/VBox/Route") as Label
	_stats_label = get_node_or_null("Overlay/Panel/Margin/VBox/Stats") as Label
	_loading_label = get_node_or_null("Overlay/Loading") as Label
	_next_button = get_node_or_null("Overlay/Panel/Margin/VBox/Buttons/NextRoute") as Button
	_back_button = get_node_or_null("Overlay/Panel/Margin/VBox/Buttons/Back") as Button
	_credits_label = get_node_or_null("Overlay/Credits") as Label
	_configure_ui()
	if not _load_world():
		_set_loading_text("WORLD_LOAD_FAILED")
		return
	var initial := 0
	if not route_id.is_empty():
		initial = maxi(0, route_ids.find(route_id))
	_activate_route(initial, start_fraction)


func _configure_ui() -> void:
	if _title_label != null:
		_title_label.text = tr("WORLD_TITLE")
	if _loading_label != null:
		_loading_label.text = tr("WORLD_LOADING")
	if _next_button != null:
		_next_button.text = tr("WORLD_NEXT_ROUTE")
		_next_button.pressed.connect(next_route)
	if _back_button != null:
		_back_button.text = tr("UI_BACK")
		_back_button.pressed.connect(_return_to_boot)
	if _credits_label != null:
		_credits_label.text = tr("CREDITS_OSM")


func _load_world() -> bool:
	var start := Time.get_ticks_msec()
	if not network.load_all():
		for error in network.errors:
			world_errors.append(error)
			print("[WORLD] ERROR: %s" % error)
		return false
	network_load_ms = Time.get_ticks_msec() - start
	streaming_contract = _read_json(STREAMING_CONTRACT_PATH)
	routes_contract = _read_json(ROUTES_CONTRACT_PATH)
	sectors_manifest = _read_json(SECTORS_MANIFEST_PATH)
	if streaming_contract.is_empty() or routes_contract.is_empty() or sectors_manifest.is_empty():
		world_errors.append("No se pudieron leer contrato o manifiesto de streaming")
		return false
	if str(streaming_contract.get("contract_id", "")) != "world.streaming":
		world_errors.append("contract_id world.streaming inválido")
		return false
	if str(sectors_manifest.get("contract_id", "")) != "world.streaming":
		world_errors.append("manifiesto de sectores con contract_id inválido")
		return false
	if not _streamer.initialize(network, streaming_contract, sectors_manifest):
		world_errors.append("No se pudo inicializar el streaming")
		return false
	route_ids.clear()
	for requirement in routes_contract.get("routes", []):
		var id := str(requirement.get("id", ""))
		if not id.is_empty() and not network.get_main_route(id).is_empty():
			route_ids.append(id)
	if route_ids.is_empty():
		world_errors.append("No hay rutas principales disponibles")
		return false
	print(
		"[WORLD] LOADED graph_ms=%d nodes=%d edges=%d routes=%d sectors=%d sector_bytes=%d"
		% [
			network_load_ms,
			network.nodes.size(),
			network.edges.size(),
			route_ids.size(),
			int(sectors_manifest.get("sector_count", 0)),
			int(sectors_manifest.get("total_bytes", 0)),
		]
	)
	return true


func _activate_route(index: int, fraction: float = DEFAULT_START_FRACTION) -> void:
	route_index = clampi(index, 0, route_ids.size() - 1)
	var selected := route_ids[route_index]
	var data := _route_for(selected)
	if data.is_empty():
		world_errors.append("Ruta sin datos: %s" % selected)
		return
	_route_data = data
	_progress_m = clampf(fraction, 0.0, 1.0) * float(data.get("total_m", 0.0))
	_world_ready = false
	_loading_started_ms = Time.get_ticks_msec()
	_sample_index = 0
	_update_vehicle()
	var sector_index := _sector_index_for_distance(_progress_m)
	_streamer.set_route(data.get("sequence", []), sector_index)
	if _loading_label != null:
		_loading_label.visible = true
		_loading_label.text = tr("WORLD_LOADING")
	if _route_label != null:
		var km := _progress_m / 1000.0
		var total_km := float(data.get("total_m", 0.0)) / 1000.0
		_route_label.text = tr("WORLD_ROUTE_LINE").format({
			"index": route_index + 1,
			"count": route_ids.size(),
			"route": _pretty_route(selected),
			"km": "%.1f" % km,
			"total": "%.1f" % total_km,
		})
	route_changed.emit(route_index, selected)
	print("[WORLD] ROUTE index=%d id=%s km=%.1f sectors=%d" % [
		route_index, selected, float(data.get("total_m", 0.0)) / 1000.0,
		int(data.get("sequence", []).size()),
	])


func _on_initial_ready() -> void:
	_world_ready = true
	initial_stream_ms = Time.get_ticks_msec() - _loading_started_ms
	if _loading_label != null:
		_loading_label.visible = false
	var stats := _streamer.stats()
	print(
		"[WORLD] READY initial_stream_ms=%d sectors=%d triangles=%d max_requests=%d writes=%d"
		% [
			initial_stream_ms,
			int(stats.get("loaded_sectors", 0)),
			int(stats.get("loaded_triangles", 0)),
			int(stats.get("max_concurrent_requests_seen", 0)),
			int(stats.get("sync_load_calls", 0)),
		]
	)
	world_ready.emit()


func _process(delta: float) -> void:
	if _route_data.is_empty():
		return
	if _world_ready and autotour and not _paused and tour_speed_mps > 0.0:
		_progress_m += tour_speed_mps * delta
		var total := float(_route_data.get("total_m", 0.0))
		if _progress_m >= total:
			_progress_m = 0.0
			_sample_index = 0
	_update_vehicle()
	_streamer.update_streaming(_sector_index_for_distance(_progress_m))
	_stats_elapsed += delta
	if _stats_elapsed >= STATS_INTERVAL:
		_stats_elapsed = 0.0
		_update_stats()


func _update_vehicle() -> void:
	var sample := _sample_at(_progress_m)
	var position: Vector3 = sample.get("position", Vector3.ZERO)
	var tangent: Vector3 = sample.get("tangent", Vector3.FORWARD)
	if _vehicle != null:
		_vehicle.global_position = position + Vector3.UP * 0.04
		var flat := Vector3(tangent.x, 0.0, tangent.z)
		if flat.length_squared() > 0.0001:
			_vehicle.rotation.y = atan2(-flat.x, -flat.z)
			_vehicle.rotation.x = atan2(tangent.y, maxf(0.001, flat.length()))
	if _camera != null:
		var basis := Basis.looking_at(Vector3(tangent.x, 0.0, tangent.z).normalized(), Vector3.UP)
		var behind := basis.z * 9.0
		var desired := position + behind + Vector3.UP * 3.1
		_camera.global_position = _camera.global_position.lerp(desired, 0.18) if _camera.global_position.distance_to(desired) < 80.0 else desired
		var look_target := position + Vector3(tangent.x, 0.0, tangent.z).normalized() * 14.0 + Vector3.UP * 1.35
		_camera.look_at(look_target, Vector3.UP)


func _update_stats() -> void:
	if _stats_label == null:
		return
	var stats := _streamer.stats()
	var viewport := get_viewport()
	var fps := 0.0
	if viewport != null:
		fps = Engine.get_frames_per_second()
	_stats_label.text = tr("WORLD_STATS").format({
		"sectors": int(stats.get("loaded_sectors", 0)),
		"triangles": int(stats.get("loaded_triangles", 0)),
		"fps": int(fps),
		"load_ms": network_load_ms,
		"pending": int(stats.get("pending_requests", 0)),
	})
	if _route_label != null and not _route_data.is_empty():
		_route_label.text = tr("WORLD_ROUTE_LINE").format({
			"index": route_index + 1,
			"count": route_ids.size(),
			"route": _pretty_route(route_ids[route_index]),
			"km": "%.1f" % (_progress_m / 1000.0),
			"total": "%.1f" % (float(_route_data.get("total_m", 0.0)) / 1000.0),
		})


func _route_for(selected: String) -> Dictionary:
	if _route_cache.has(selected):
		return _route_cache[selected]
	var route: Dictionary = network.get_main_route(selected)
	if route.is_empty():
		return {}
	var points := PackedVector3Array()
	var edge_ids: Array = route.get("edge_ids", [])
	var node_ids: Array = route.get("node_ids", [])
	for edge_index in range(edge_ids.size()):
		var edge_id := str(edge_ids[edge_index])
		var edge_points := network.edge_world_points(edge_id)
		if edge_points.size() < 2:
			continue
		var edge: Dictionary = network.edges.get(edge_id, {})
		var expected_from := str(node_ids[edge_index]) if edge_index < node_ids.size() else ""
		if not expected_from.is_empty() and expected_from != str(edge.get("from", "")):
			edge_points.reverse()
		for point in edge_points:
			if points.is_empty() or points[points.size() - 1].distance_to(point) > 0.01:
				points.append(point)
		if points.size() < 2:
			continue
	var cumulative := PackedFloat32Array()
	cumulative.resize(points.size())
	cumulative[0] = 0.0
	for index in range(1, points.size()):
		cumulative[index] = cumulative[index - 1] + Vector2(
			points[index].x - points[index - 1].x,
			points[index].z - points[index - 1].z
		).length()
	var sequence: Array[Dictionary] = []
	var last_key := ""
	for index in range(points.size()):
		var key := _sector_key(points[index].x, points[index].z)
		if key != last_key:
			sequence.append({"key": key, "start_distance_m": cumulative[index]})
			last_key = key
	if sequence.is_empty() and not points.is_empty():
		sequence.append({"key": _sector_key(points[0].x, points[0].z), "start_distance_m": 0.0})
	var data := {
		"id": selected,
		"points": points,
		"cumulative": cumulative,
		"total_m": cumulative[cumulative.size() - 1] if cumulative.size() > 0 else 0.0,
		"sequence": sequence,
	}
	_route_cache[selected] = data
	return data


func _sample_at(distance_m: float) -> Dictionary:
	var points: PackedVector3Array = _route_data.get("points", PackedVector3Array())
	var cumulative: PackedFloat32Array = _route_data.get("cumulative", PackedFloat32Array())
	if points.size() < 2:
		return {"position": Vector3.ZERO, "tangent": Vector3.FORWARD}
	var distance := clampf(distance_m, 0.0, cumulative[cumulative.size() - 1])
	var low := 0
	var high := cumulative.size() - 2
	while low < high:
		var mid := (low + high) >> 1
		if cumulative[mid + 1] < distance:
			low = mid + 1
		else:
			high = mid
	var index := clampi(low, 0, points.size() - 2)
	var span := maxf(0.001, cumulative[index + 1] - cumulative[index])
	var t := clampf((distance - cumulative[index]) / span, 0.0, 1.0)
	var position := points[index].lerp(points[index + 1], t)
	var tangent := (points[index + 1] - points[index]).normalized()
	if tangent.length_squared() < 0.5:
		tangent = Vector3.FORWARD
	return {"position": position, "tangent": tangent}


func _sector_index_for_distance(distance_m: float) -> int:
	var sequence: Array = _route_data.get("sequence", [])
	if sequence.is_empty():
		return 0
	var index := 0
	for entry_index in range(sequence.size()):
		if float(sequence[entry_index].get("start_distance_m", 0.0)) <= distance_m:
			index = entry_index
		else:
			break
	return index


func _sector_key(x: float, z: float) -> String:
	var size := float(streaming_contract.get("terrain", {}).get("sector_size_m", 800.0))
	return "%d_%d" % [floori(x / size), floori(z / size)]


func _pretty_route(id: String) -> String:
	return id.trim_prefix("route.").replace("_", " → ").to_upper()


func next_route() -> void:
	if route_ids.is_empty():
		return
	_activate_route((route_index + 1) % route_ids.size(), start_fraction)


func seek(distance_m: float) -> void:
	if _route_data.is_empty():
		return
	var total := float(_route_data.get("total_m", 0.0))
	_progress_m = clampf(distance_m, 0.0, total)
	_sample_index = 0
	_update_vehicle()
	var sector_index := _sector_index_for_distance(_progress_m)
	_streamer.update_streaming(sector_index)


func current_route_id() -> String:
	return route_ids[route_index] if not route_ids.is_empty() else ""


func current_progress_m() -> float:
	return _progress_m


func current_sector_key() -> String:
	if _route_data.is_empty():
		return ""
	var sequence: Array = _route_data.get("sequence", [])
	if sequence.is_empty():
		return ""
	var index := _sector_index_for_distance(_progress_m)
	return str(sequence[index].get("key", ""))


func current_route_total_m() -> float:
	return float(_route_data.get("total_m", 0.0))


func set_tour_speed(speed_mps: float) -> void:
	tour_speed_mps = maxf(0.0, speed_mps)


func set_paused(value: bool) -> void:
	_paused = value


func is_world_ready() -> bool:
	return _world_ready


func streaming_snapshot() -> Dictionary:
	var snapshot := _streamer.stats()
	snapshot["network_load_ms"] = network_load_ms
	snapshot["initial_stream_ms"] = initial_stream_ms
	snapshot["world_ready"] = _world_ready
	snapshot["route_id"] = route_ids[route_index] if not route_ids.is_empty() else ""
	snapshot["progress_m"] = snappedf(_progress_m, 0.1)
	snapshot["total_m"] = float(_route_data.get("total_m", 0.0))
	snapshot["route_sectors"] = _route_data.get("sequence", []).size()
	snapshot["errors"] = world_errors.size() + int(snapshot.get("sector_errors", 0))
	return snapshot


func safe_respawn_point(selected_route: String, distance_m: float) -> Dictionary:
	var data := _route_for(selected_route)
	if data.is_empty():
		return {"found": false, "position": Vector3.ZERO, "reason": "route_missing"}
	var total := float(data.get("total_m", 0.0))
	for offset in [0.0, 50.0, -50.0, 120.0, -120.0, 250.0, -250.0]:
		var distance := clampf(distance_m + offset, 0.0, total)
		var saved_data := _route_data
		_route_data = data
		var sample := _sample_at(distance)
		_route_data = saved_data
		var position: Vector3 = sample.get("position", Vector3.ZERO)
		var hit := _raycast_down(position)
		if hit.is_empty():
			continue
		var normal: Vector3 = hit.get("normal", Vector3.UP)
		var slope := 100.0 * sqrt(maxf(0.0, 1.0 - normal.y * normal.y)) / maxf(0.001, normal.y)
		if slope <= 20.0:
			return {
				"found": true,
				"position": position + Vector3.UP * 0.12,
				"normal": normal,
				"distance_m": distance,
				"slope_pct": snappedf(slope, 0.1),
			}
	for fallback_id in [str(streaming_contract.get("anti_softlock", {}).get("fallback_hub", "")), network.region_hub("carabobo")]:
		if fallback_id.is_empty() or not network.nodes.has(fallback_id):
			continue
		var hub_position := network.node_game_position(fallback_id)
		var hub_hit := _raycast_down(hub_position)
		if not hub_hit.is_empty():
			return {
				"found": true,
				"position": hub_position + Vector3.UP * 0.12,
				"normal": hub_hit.get("normal", Vector3.UP),
				"distance_m": 0.0,
				"slope_pct": 0.0,
				"fallback": true,
			}
	return {"found": false, "position": Vector3.ZERO, "reason": "no_collision"}


func _raycast_down(position: Vector3) -> Dictionary:
	var world := get_world_3d()
	if world == null:
		return {}
	var query := PhysicsRayQueryParameters3D.create(
		position + Vector3.UP * 4.0,
		position + Vector3.DOWN * 12.0,
		RESPAWN_COLLISION_MASK
	)
	query.exclude = []
	return world.direct_space_state.intersect_ray(query)


func _set_loading_text(key: String) -> void:
	if _loading_label != null:
		_loading_label.text = tr(key)


func _return_to_boot() -> void:
	SceneRouter.change_scene(BOOT_SCENE, "world_back")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_return_to_boot()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_N:
				next_route()
			KEY_R:
				_progress_m = 0.0
			KEY_SPACE:
				_paused = not _paused
			KEY_PAGEUP:
				seek(minf(_progress_m + 2000.0, maxf(0.0, current_route_total_m() - 1.0)))
			KEY_PAGEDOWN:
				seek(maxf(_progress_m - 2000.0, 0.0))


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
