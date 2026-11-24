class_name WorldSectorStreamer
extends Node3D
## Streaming asíncrono de sectores de 800 m (F4.2).
##
## - Carga con ResourceLoader.load_threaded_request(), máximo dos solicitudes.
## - Nunca usa load() durante la conducción.
## - Construye como máximo un sector por frame para repartir malla y colisión.
## - Descarga los sectores fuera del anillo de retención.
##
## Es un servicio de escena hijo de WorldDirector, no un autoload.

signal initial_ready
signal sector_ready(key: String)
signal sector_failed(key: String, message: String)

const SECTOR_PATH_PREFIX := "res://"
const LOAD_TIMEOUT_SECONDS := 30.0

var contract: Dictionary = {}
var manifest: Dictionary = {}
var sector_size_m := 800.0
var ahead_sectors := 3
var behind_sectors := 2
var unload_margin_sectors := 2
var max_concurrent_requests := 2
var max_loaded_sectors := 10
var max_builds_per_frame := 1
var collision_layer := 1
var collision_mask := 1
var terrain_collision_stride := 2
var initial_fill_timeout_ms := 20000

var state: String = "idle"
var sync_load_calls := 0
var max_concurrent_seen := 0
var peak_loaded_sectors := 0
var sector_errors: Array[String] = []
var last_build_ms := 0.0
var total_build_ms := 0.0
var build_count := 0

var _sequence: Array[Dictionary] = []
var _current_index := 0
var _manifest_by_key: Dictionary = {}
var _desired: Dictionary = {}
var _retention: Dictionary = {}
var _loaded: Dictionary = {}
var _pending: Dictionary = {}
var _queue: Array[Dictionary] = []
var _ready: Array[Dictionary] = []
var _loaded_triangles := 0
var _initial_emitted := false
var _initial_started_ms := 0
var _frame := 0
var _terrain_material: StandardMaterial3D
var _road_material: StandardMaterial3D
var _marking_material: StandardMaterial3D
var _failed_keys: Dictionary = {}


func initialize(network: RouteNetwork, streaming_contract: Dictionary, sectors_manifest: Dictionary) -> bool:
	contract = streaming_contract
	manifest = sectors_manifest
	if network == null or contract.is_empty() or manifest.is_empty():
		state = "failed"
		_errors("No hay red, contrato o manifiesto de sectores")
		return false
	sector_size_m = float(contract.get("streaming", {}).get("sector_size_m", 800.0))
	ahead_sectors = int(contract.get("streaming", {}).get("ahead_sectors", 3))
	behind_sectors = int(contract.get("streaming", {}).get("behind_sectors", 2))
	unload_margin_sectors = int(contract.get("streaming", {}).get("unload_margin_sectors", 2))
	max_concurrent_requests = int(contract.get("streaming", {}).get("max_concurrent_requests", 2))
	max_builds_per_frame = int(contract.get("streaming", {}).get("max_sector_builds_per_frame", 1))
	initial_fill_timeout_ms = int(contract.get("streaming", {}).get("initial_fill_timeout_ms", 20000))
	max_loaded_sectors = int(contract.get("budgets", {}).get("max_loaded_sectors", 10))
	collision_layer = int(contract.get("collision", {}).get("collision_layer", 1))
	collision_mask = int(contract.get("collision", {}).get("collision_mask", 1))
	terrain_collision_stride = int(contract.get("collision", {}).get("terrain_stride", 2))
	_manifest_by_key.clear()
	for entry in manifest.get("sectors", []):
		var key := str(entry.get("id", ""))
		if not key.is_empty():
			_manifest_by_key[key] = entry
	_build_materials(contract)
	state = "idle"
	return true


func set_route(sequence: Array[Dictionary], start_index: int = 0) -> void:
	reset()
	_sequence = sequence.duplicate(true)
	_current_index = clampi(start_index, 0, maxi(0, _sequence.size() - 1))
	_initial_emitted = false
	_initial_started_ms = Time.get_ticks_msec()
	state = "initial_fill"
	_update_desired()
	_ensure_desired_queued()
	_pump()
	print(
		"[WORLD] STREAM_ROUTE sectors=%d start=%d loaded_budget=%d"
		% [_sequence.size(), _current_index, max_loaded_sectors]
	)


func update_streaming(current_index: int) -> void:
	if _sequence.is_empty():
		return
	var clamped := clampi(current_index, 0, _sequence.size() - 1)
	if clamped == _current_index:
		return
	_current_index = clamped
	_update_desired()
	_ensure_desired_queued()
	_pump()
	_unload_excess()


func reset() -> void:
	for key in _loaded.keys():
		var node: Node = _loaded[key]
		if is_instance_valid(node):
			node.queue_free()
	_loaded.clear()
	_pending.clear()
	_queue.clear()
	_ready.clear()
	_desired.clear()
	_retention.clear()
	_loaded_triangles = 0
	_initial_emitted = false
	_failed_keys.clear()
	state = "idle"


func is_initial_ready() -> bool:
	return _initial_emitted


func is_idle() -> bool:
	if not _pending.is_empty() or not _ready.is_empty():
		return false
	for item in _queue:
		if _desired.has(str(item.get("key", ""))):
			return false
	return true


func loaded_sector_count() -> int:
	return _loaded.size()


func loaded_triangle_count() -> int:
	return _loaded_triangles


func loaded_keys() -> Array:
	return _loaded.keys()


func loaded_node(key: String) -> Node3D:
	return _loaded.get(key, null) as Node3D


func sector_triangle_count(key: String) -> int:
	var node: Node3D = _loaded.get(key, null)
	if node == null:
		return 0
	var total := 0
	for child in node.get_children():
		if child is MeshInstance3D and child.mesh != null:
			var mesh := child.mesh as ArrayMesh
			if mesh != null:
				for surface in range(mesh.get_surface_count()):
					var arrays := mesh.surface_get_arrays(surface)
					if arrays.size() <= Mesh.ARRAY_VERTEX:
						continue
					var indices_value: Variant = arrays[Mesh.ARRAY_INDEX] if arrays.size() > Mesh.ARRAY_INDEX else null
					if indices_value is PackedInt32Array and not (indices_value as PackedInt32Array).is_empty():
						total += (indices_value as PackedInt32Array).size() / 3
					else:
						var vertices_value: Variant = arrays[Mesh.ARRAY_VERTEX]
						if vertices_value is PackedVector3Array:
							total += (vertices_value as PackedVector3Array).size() / 3
	return total


func stats() -> Dictionary:
	return {
		"state": state,
		"loaded_sectors": _loaded.size(),
		"loaded_triangles": _loaded_triangles,
		"pending_requests": _pending.size(),
		"queued_requests": _queue.size(),
		"max_concurrent_requests_seen": max_concurrent_seen,
		"peak_loaded_sectors": peak_loaded_sectors,
		"sync_load_calls": sync_load_calls,
		"last_build_ms": snappedf(last_build_ms, 0.01),
		"avg_build_ms": snappedf(total_build_ms / maxf(1.0, float(build_count)), 0.01),
		"build_count": build_count,
		"sector_errors": sector_errors.size(),
		"current_index": _current_index,
		"sequence_length": _sequence.size(),
	}


func _process(_delta: float) -> void:
	_frame += 1
	_ensure_desired_queued()
	_pump()
	_consume_ready()
	_pump()
	_unload_excess()
	_check_initial_ready()
	_expire_pending()


func _update_desired() -> void:
	_desired.clear()
	_retention.clear()
	if _sequence.is_empty():
		return
	for offset in range(-behind_sectors - unload_margin_sectors, ahead_sectors + unload_margin_sectors + 1):
		var index := _current_index + offset
		if index < 0 or index >= _sequence.size():
			continue
		var key := str(_sequence[index].get("key", ""))
		if key.is_empty():
			continue
		_retention[key] = true
		if offset >= -behind_sectors and offset <= ahead_sectors:
			_desired[key] = true
	var priority: Array[Dictionary] = []
	var priority_keys := {}
	for offset in range(0, ahead_sectors + 1):
		for sign_value in [1, -1]:
			if offset == 0 and sign_value < 0:
				continue
			var index: int = _current_index + offset * int(sign_value)
			if index < 0 or index >= _sequence.size():
				continue
			var key := str(_sequence[index].get("key", ""))
			if key.is_empty() or not _desired.has(key) or priority_keys.has(key):
				continue
			if _loaded.has(key) or _pending_has_key(key):
				continue
			var entry: Dictionary = _manifest_by_key.get(key, {})
			if entry.is_empty():
				_report_missing(key)
				continue
			priority.append({"key": key, "path": SECTOR_PATH_PREFIX + str(entry.get("path", ""))})
			priority_keys[key] = true
	_queue = priority


func _ensure_desired_queued() -> void:
	if _sequence.is_empty():
		return
	for key in _desired:
		if _loaded.has(key) or _pending_has_key(key) or _queued_has_key(key) or _failed_keys.has(key):
			continue
		var entry: Dictionary = _manifest_by_key.get(key, {})
		if entry.is_empty():
			_report_missing(key)
			continue
		_queue.append({"key": key, "path": SECTOR_PATH_PREFIX + str(entry.get("path", ""))})


func _pump() -> void:
	if _sequence.is_empty():
		return
	while _pending.size() < max_concurrent_requests and not _queue.is_empty():
		var item: Dictionary = _queue.pop_front()
		var key := str(item.get("key", ""))
		if not _desired.has(key) or _loaded.has(key) or _pending_has_key(key):
			continue
		var path := str(item.get("path", ""))
		if path.is_empty() or not ResourceLoader.exists(path):
			_errors("sector inexistente: %s" % path)
			_failed_keys[key] = true
			continue
		var error := ResourceLoader.load_threaded_request(path)
		if error != OK:
			_errors("load_threaded_request falló para %s (error %d)" % [path, error])
			_failed_keys[key] = true
			continue
		_pending[path] = {"key": key, "started_ms": Time.get_ticks_msec()}
		max_concurrent_seen = maxi(max_concurrent_seen, _pending.size())
		state = "streaming" if _initial_emitted else "initial_fill"


func _consume_ready() -> void:
	var completed: Array[Dictionary] = []
	for path in _pending.keys():
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			continue
		var slot: Dictionary = _pending[path]
		_pending.erase(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var resource: Resource = ResourceLoader.load_threaded_get(path)
			if resource is WorldSectorData:
				completed.append({"key": str(slot.get("key", "")), "data": resource})
			else:
				_errors("recurso de sector inválido: %s" % path)
		else:
			_errors("carga de sector fallida: %s (estado %d)" % [path, status])
	var built := 0
	for item in completed:
		var key := str(item.get("key", ""))
		if not _desired.has(key):
			continue
		if _loaded.has(key):
			continue
		_ready.append(item)
	while built < max_builds_per_frame and not _ready.is_empty():
		_build_sector(_ready.pop_front())
		built += 1


func _build_sector(item: Dictionary) -> void:
	var key := str(item.get("key", ""))
	var data := item.get("data") as WorldSectorData
	if data == null or not data.is_valid():
		_errors("sector corrupto: %s" % key)
		_failed_keys[key] = true
		return
	var start := Time.get_ticks_usec()
	var node := WorldSectorBuilder.build_sector(
		data,
		_terrain_material,
		_road_material,
		_marking_material,
		collision_layer,
		collision_mask,
		terrain_collision_stride
	)
	add_child(node)
	_loaded[key] = node
	var triangles := data.terrain_triangle_count + data.road_triangle_count + data.marking_vertices.size() / 3
	_loaded_triangles += triangles
	last_build_ms = float(Time.get_ticks_usec() - start) / 1000.0
	total_build_ms += last_build_ms
	build_count += 1
	peak_loaded_sectors = maxi(peak_loaded_sectors, _loaded.size())
	sector_ready.emit(key)


func _unload_excess() -> void:
	for key in _loaded.keys():
		if not _retention.has(key):
			_unload_sector(key)
	var guard := 0
	while _loaded.size() > max_loaded_sectors and guard < 32:
		guard += 1
		var farthest := ""
		var farthest_index := -1
		for key in _loaded.keys():
			var index := _sequence_index(key)
			if index < 0:
				farthest = key
				break
			if absi(index - _current_index) > farthest_index:
				farthest_index = absi(index - _current_index)
				farthest = key
		if farthest.is_empty():
			break
		_unload_sector(farthest)


func _unload_sector(key: String) -> void:
	var node: Node = _loaded.get(key, null)
	if node != null:
		_loaded_triangles = maxi(
			0,
			_loaded_triangles - _sector_triangles_from_node(node)
		)
		node.queue_free()
	_loaded.erase(key)


func _sector_triangles_from_node(node: Node) -> int:
	var total := 0
	for child in node.get_children():
		if child is MeshInstance3D and child.mesh != null:
			var mesh := child.mesh as ArrayMesh
			if mesh != null:
				for surface in range(mesh.get_surface_count()):
					var arrays := mesh.surface_get_arrays(surface)
					if arrays.size() <= Mesh.ARRAY_VERTEX:
						continue
					var indices_value: Variant = arrays[Mesh.ARRAY_INDEX] if arrays.size() > Mesh.ARRAY_INDEX else null
					if indices_value is PackedInt32Array and not (indices_value as PackedInt32Array).is_empty():
						total += (indices_value as PackedInt32Array).size() / 3
					else:
						var vertices_value: Variant = arrays[Mesh.ARRAY_VERTEX]
						if vertices_value is PackedVector3Array:
							total += (vertices_value as PackedVector3Array).size() / 3
	return total


func _check_initial_ready() -> void:
	if _initial_emitted:
		return
	if _sequence.is_empty():
		_initial_emitted = true
		state = "failed"
		_errors("no hay secuencia de sectores para la ruta")
		initial_ready.emit()
		return
	for key in _desired:
		if not _loaded.has(key) and not _failed_keys.has(key):
			if Time.get_ticks_msec() - _initial_started_ms > initial_fill_timeout_ms:
				_initial_emitted = true
				state = "degraded"
				push_warning("[WORLD] ventana inicial incompleta tras %d ms" % initial_fill_timeout_ms)
				print("[WORLD] STREAM_DEGRADED sectors=%d triangles=%d" % [_loaded.size(), _loaded_triangles])
				initial_ready.emit()
			return
	_initial_emitted = true
	state = "streaming"
	print("[WORLD] STREAM_READY sectors=%d triangles=%d" % [_loaded.size(), _loaded_triangles])
	initial_ready.emit()


func _expire_pending() -> void:
	var now := Time.get_ticks_msec()
	for path in _pending.keys():
		var slot: Dictionary = _pending[path]
		if now - int(slot.get("started_ms", now)) > int(LOAD_TIMEOUT_SECONDS * 1000.0):
			_errors("timeout de carga de sector: %s" % path)
			_failed_keys[str(slot.get("key", ""))] = true
			_pending.erase(path)


func _pending_has_key(key: String) -> bool:
	for path in _pending:
		if str(_pending[path].get("key", "")) == key:
			return true
	return false


func _queued_has_key(key: String) -> bool:
	for item in _queue:
		if str(item.get("key", "")) == key:
			return true
	return false


func _sequence_index(key: String) -> int:
	for index in range(_sequence.size()):
		if str(_sequence[index].get("key", "")) == key:
			return index
	return -1


func _report_missing(key: String) -> void:
	if _failed_keys.has(key):
		return
	_failed_keys[key] = true
	_errors("sector sin entrada en el manifiesto: %s" % key)


func _errors(message: String) -> void:
	sector_errors.append(message)
	if sector_errors.size() <= 12:
		push_warning("[WORLD] %s" % message)
	sector_failed.emit("", message)


func _build_materials(streaming_contract: Dictionary) -> void:
	var terrain_spec: Dictionary = streaming_contract.get("terrain", {})
	var materials: Dictionary = terrain_spec.get("materials", {})
	_terrain_material = StandardMaterial3D.new()
	_terrain_material.resource_name = "WorldTerrainMaterial"
	_terrain_material.vertex_color_use_as_albedo = true
	_terrain_material.roughness = float(materials.get("terrain_roughness", 0.95))
	_terrain_material.metallic = 0.0
	_terrain_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_terrain_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL

	var road: Dictionary = terrain_spec.get("road", {})
	var asphalt: Array = road.get("asphalt_color", [0.115, 0.12, 0.13])
	var marking: Array = road.get("marking_color", [0.72, 0.68, 0.55])
	_road_material = StandardMaterial3D.new()
	_road_material.resource_name = "WorldRoadMaterial"
	_road_material.albedo_color = Color(
		maxf(0.16, float(asphalt[0])), maxf(0.165, float(asphalt[1])), maxf(0.18, float(asphalt[2]))
	)
	_road_material.roughness = float(materials.get("road_roughness", 0.86))
	_road_material.metallic = 0.05
	_road_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	_marking_material = StandardMaterial3D.new()
	_marking_material.resource_name = "WorldRoadMarkingMaterial"
	_marking_material.albedo_color = Color(float(marking[0]), float(marking[1]), float(marking[2]))
	_marking_material.roughness = 0.62
	_marking_material.metallic = 0.0
	_marking_material.emission_enabled = true
	_marking_material.emission = _marking_material.albedo_color
	_marking_material.emission_energy_multiplier = 0.22
	_marking_material.cull_mode = BaseMaterial3D.CULL_DISABLED
