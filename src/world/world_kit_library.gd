class_name WorldKitLibrary
extends RefCounted
## Biblioteca de kits de bioma y POIs (F4.3). Servicio de datos de escena, no
## autoload. Vive en WorldDirector y lo consumen WorldSectorBuilder
## (decorado de sector) y PoiManager (POIs de ruta).
##
## - Carga `world_biomes.json` y `data/world/kits_spec.json`.
## - Carga los GLB de los kits con ResourceLoader.load_threaded_request(),
##   máximo dos solicitudes simultáneas y CERO load() síncrono.
## - Determina el bioma de cada sector por el hub de región más cercano.
## - Construye las mallas procedurales de props con BiomeDecorBuilder.

const BIOMES_CONTRACT_PATH := "res://data/schemas/world_biomes.json"
const KITS_SPEC_PATH := "res://data/world/kits_spec.json"
const KIT_DIR := "res://assets/generated/world"

var contract: Dictionary = {}
var kits_spec: Dictionary = {}
var errors: Array[String] = []
var sync_load_calls := 0
var max_concurrent_seen := 0

var _biome_by_id: Dictionary = {}
var _region_hubs: Dictionary = {}
var _prop_meshes: Dictionary = {}
var _kit_scenes: Dictionary = {}
var _kit_meshes: Dictionary = {}
var _pending: Dictionary = {}
var _queue: Array[Dictionary] = []
var _kit_states: Dictionary = {}
var _all_kits_loaded := false


func load_contract() -> bool:
	contract = _read_json(BIOMES_CONTRACT_PATH)
	kits_spec = _read_json(KITS_SPEC_PATH)
	if contract.is_empty() or kits_spec.is_empty():
		errors.append("No se pudo leer world_biomes.json o kits_spec.json")
		return false
	if str(contract.get("contract_id", "")) != "world.biomes":
		errors.append("contract_id world.biomes inválido")
		return false
	_biome_by_id.clear()
	for biome in contract.get("biomes", []):
		_biome_by_id[str(biome.get("id", ""))] = biome
	return true


func set_region_hubs(hubs: Dictionary) -> void:
	_region_hubs = hubs.duplicate()


func biome_for_position(position: Vector3) -> Dictionary:
	var best_region := ""
	var best_distance := INF
	for region in _region_hubs:
		var hub: Vector3 = _region_hubs[region]
		var distance := Vector2(position.x - hub.x, position.z - hub.z).length_squared()
		if distance < best_distance:
			best_distance = distance
			best_region = str(region)
	var biome_id := str(contract.get("region_biome_map", {}).get(best_region, ""))
	var biome: Dictionary = _biome_by_id.get(biome_id, {})
	if biome.is_empty():
		var fallback := str(contract.get("biome_selection", {}).get("fallback_biome", "biome.llanos"))
		biome = _biome_by_id.get(fallback, {})
	return biome


func biome_for_sector(data: WorldSectorData) -> Dictionary:
	return biome_for_position(Vector3(data.origin_x + data.sector_size_m * 0.5, 0.0, data.origin_z + data.sector_size_m * 0.5))


func decor_budget() -> int:
	return int(contract.get("budgets", {}).get("max_decor_triangles_per_sector", 0))


func furniture_budget() -> int:
	return int(contract.get("budgets", {}).get("max_road_furniture_triangles_per_sector", 0))


func poi_node_budget() -> int:
	return int(contract.get("budgets", {}).get("max_poi_nodes_per_route", 0))


func placement_rules() -> Dictionary:
	return contract.get("placement_rules", {})


func pois() -> Array:
	return contract.get("pois", [])


func prop_ids() -> Array:
	var ids := []
	for prop in contract.get("props", []):
		ids.append(str(prop.get("id", "")))
	return ids


## ---------------------------------------------------------------------
## Carga threaded de kits (GLB)
## ---------------------------------------------------------------------

func begin_kit_load() -> void:
	_queue.clear()
	for kit in kits_spec.get("kits", []):
		var kit_id := str(kit.get("kit_id", ""))
		for lod in kit.get("lods", []):
			var file := str(lod.get("output", ""))
			var path := "%s/%s" % [KIT_DIR, file]
			_kit_states["%s:%s" % [kit_id, lod.get("id", "")]] = "declared"
			_queue.append({"kit_id": kit_id, "lod": int(str(lod.get("id", "lod0")).trim_prefix("lod")), "path": path})
	_pump()


func poll_kit_load() -> void:
	_pump()
	_consume()
	if _queue.is_empty() and _pending.is_empty():
		_all_kits_loaded = true


func is_kit_load_complete() -> bool:
	return _all_kits_loaded


func kit_load_progress() -> Dictionary:
	var loaded := 0
	for state in _kit_states.values():
		if str(state) == "loaded":
			loaded += 1
	return {
		"loaded": loaded,
		"total": _kit_states.size(),
		"pending": _pending.size(),
		"queued": _queue.size(),
		"max_concurrent_seen": max_concurrent_seen,
		"sync_load_calls": sync_load_calls,
	}


func _pump() -> void:
	while _pending.size() < 2 and not _queue.is_empty():
		var item: Dictionary = _queue.pop_front()
		var path := str(item.get("path", ""))
		if not ResourceLoader.exists(path):
			errors.append("kit inexistente: %s" % path)
			_kit_states["%s:lod%d" % [item.get("kit_id", ""), item.get("lod", 0)]] = "failed"
			continue
		var error := ResourceLoader.load_threaded_request(path)
		if error != OK:
			errors.append("load_threaded_request falló para %s (error %d)" % [path, error])
			_kit_states["%s:lod%d" % [item.get("kit_id", ""), item.get("lod", 0)]] = "failed"
			continue
		_pending[path] = item
		max_concurrent_seen = maxi(max_concurrent_seen, _pending.size())


func _consume() -> void:
	for path in _pending.keys():
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			continue
		var item: Dictionary = _pending[path]
		_pending.erase(path)
		var state_key := "%s:lod%d" % [item.get("kit_id", ""), item.get("lod", 0)]
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var resource := ResourceLoader.load_threaded_get(path)
			if resource is PackedScene:
				_kit_scenes["%s:%d" % [item.get("kit_id", ""), item.get("lod", 0)]] = resource
				_kit_states[state_key] = "loaded"
			else:
				errors.append("kit con recurso inválido: %s" % path)
				_kit_states[state_key] = "failed"
		else:
			errors.append("carga de kit fallida: %s (estado %d)" % [path, status])
			_kit_states[state_key] = "failed"


func kit_scene(kit_id: String, lod: int) -> PackedScene:
	return _kit_scenes.get("%s:%d" % [kit_id, lod], null) as PackedScene


## Malla fusionada de un kit (para instancias de sector con MultiMesh/MeshInstance).
func kit_mesh(kit_id: String, lod: int) -> ArrayMesh:
	var key := "%s:%d" % [kit_id, lod]
	if _kit_meshes.has(key):
		return _kit_meshes[key]
	var scene := kit_scene(kit_id, lod)
	if scene == null:
		return null
	var root := scene.instantiate()
	var merged := ArrayMesh.new()
	_collect_meshes(root, Transform3D.IDENTITY, merged)
	root.free()
	_kit_meshes[key] = merged
	return merged


func _collect_meshes(node: Node, transform: Transform3D, merged: ArrayMesh) -> void:
	if node is MeshInstance3D:
		var instance := node as MeshInstance3D
		if instance.mesh != null:
			var source := instance.mesh as ArrayMesh
			if source != null:
				for surface_index in range(source.get_surface_count()):
					var arrays := source.surface_get_arrays(surface_index)
					var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
					var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays.size() > Mesh.ARRAY_NORMAL and arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
					var transformed := PackedVector3Array()
					transformed.resize(vertices.size())
					for index in range(vertices.size()):
						transformed[index] = transform * vertices[index]
					var out_arrays := []
					out_arrays.resize(Mesh.ARRAY_MAX)
					out_arrays[Mesh.ARRAY_VERTEX] = transformed
					if not normals.is_empty():
						var rotated := PackedVector3Array()
						rotated.resize(normals.size())
						for index in range(normals.size()):
							rotated[index] = transform.basis * normals[index]
						out_arrays[Mesh.ARRAY_NORMAL] = rotated
					merged.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out_arrays)
					var material := source.surface_get_material(surface_index)
					if material != null:
						merged.surface_set_material(merged.get_surface_count() - 1, material)
	for child in node.get_children():
		_collect_meshes(child, transform * (child as Node3D).transform if child is Node3D else transform, merged)


## ---------------------------------------------------------------------
## Props procedurales
## ---------------------------------------------------------------------

func prop_mesh(prop_id: String, lod: int) -> ArrayMesh:
	var key := "%s:%d" % [prop_id, lod]
	if _prop_meshes.has(key):
		return _prop_meshes[key]
	var mesh := BiomeDecorBuilder.build_prop(prop_id, lod)
	_prop_meshes[key] = mesh
	return mesh


func prop_triangle_count(prop_id: String, lod: int) -> int:
	var mesh := prop_mesh(prop_id, lod)
	return mesh.get_faces().size() / 3


func stats() -> Dictionary:
	var progress := kit_load_progress()
	progress["biomes"] = _biome_by_id.size()
	progress["kit_errors"] = errors.size()
	return progress


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
