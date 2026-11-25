class_name PoiManager
extends Node3D
## POIs de ruta de F4.3 (gasolineras, moteles, peajes y cruces). Servicio de
## escena hijo de WorldDirector, no autoload.
##
## - Colocación determinista por intervalo de distancia sobre la ruta activa.
## - Los kits se instancian desde WorldKitLibrary (cargados por hilo antes).
## - LOD por distancia con visibility_range en cada variante.
## - Colisión opcional (StaticBody3D) fuera de la vía; nunca bloquea el
##   corredor de reaparición de F4.2 (anti-softlock de F5.1 sigue operativo).

const COLLISION_LAYER := 1
const COLLISION_MASK := 1

var library: WorldKitLibrary
## Metros de juego por kilómetro real (proyección 1:20 de F4.1 = 0,05).
var game_meters_per_km := 50.0
var errors: Array[String] = []

var _placed: Array[Dictionary] = []
var _placed_by_kind: Dictionary = {}


func place_route(route_id: String, points: PackedVector3Array, cumulative: PackedFloat32Array) -> int:
	_clear()
	if library == null or points.size() < 2 or cumulative.size() != points.size():
		return 0
	var budget := library.poi_node_budget()
	var rules := library.placement_rules()
	var min_clear := float(rules.get("min_clear_road_m", 5.6))
	var total_m := float(cumulative[cumulative.size() - 1])
	var placed := 0
	for poi in library.pois():
		var placement: Dictionary = poi.get("placement", {})
		if str(placement.get("mode", "")) != "route_interval":
			continue
		var interval := float(placement.get("every_n_km", 100.0)) * game_meters_per_km
		if interval < 100.0:
			continue
		var jitter := float(placement.get("jitter_km", 0.0)) * game_meters_per_km
		var lateral := maxf(float(placement.get("lateral_m", min_clear)), min_clear)
		var side_mode := str(placement.get("side", "alternate"))
		var kind := str(poi.get("id", ""))
		var index := 0
		var distance := interval * 0.5
		while distance < total_m and placed < budget:
			var seed_value := "%s|%s|%d" % [route_id, kind, index]
			var jittered := distance + (_hash01_string(seed_value, 1) - 0.5) * 2.0 * jitter
			var clamped := clampf(jittered, 10.0, total_m - 10.0)
			var sample := _sample_at(points, cumulative, clamped)
			var side := 1.0
			if side_mode == "alternate":
				side = 1.0 if index % 2 == 0 else -1.0
			elif side_mode == "left":
				side = -1.0
			var forward: Vector3 = sample.get("tangent", Vector3.FORWARD)
			var flat := Vector3(forward.x, 0.0, forward.z).normalized()
			var lateral_dir := Vector3(flat.z, 0.0, -flat.x) * side
			var position: Vector3 = sample.get("position", Vector3.ZERO) + lateral_dir * lateral
			var biome := library.biome_for_position(position)
			var allowed: Array = poi.get("biomes", [])
			if allowed.is_empty() or allowed.has(str(biome.get("id", ""))):
				if _spawn_poi(poi, position, flat, seed_value):
					placed += 1
					_placed_by_kind[kind] = int(_placed_by_kind.get(kind, 0)) + 1
			index += 1
			distance += interval
	print("[WORLD] POIS placed=%d route=%s kinds=%s errors=%d" % [placed, route_id, _placed_by_kind, errors.size()])
	for message in errors.slice(0, 6):
		print("[WORLD] POI_ERROR %s" % message)
	return placed


func stats() -> Dictionary:
	var lod0_triangles := 0
	for entry in _placed:
		lod0_triangles += int(entry.get("lod0_triangles", 0))
	return {
		"poi_nodes": _placed.size(),
		"poi_by_kind": _placed_by_kind.duplicate(),
		"poi_lod0_triangles": lod0_triangles,
		"errors": errors.size(),
	}


func _spawn_poi(poi: Dictionary, position: Vector3, forward: Vector3, seed_value: String) -> bool:
	var kit_id := str(poi.get("kit_id", ""))
	var lods: Array = poi.get("lods", [])
	if lods.size() != 3:
		errors.append("POI sin cadena LOD: %s" % poi.get("id", ""))
		return false
	var node := Node3D.new()
	node.name = "POI_%s" % seed_value.replace("|", "_")
	node.position = position
	if forward.length_squared() > 0.001:
		node.rotation.y = atan2(-forward.x, -forward.z)
	var lod0_triangles := 0
	for lod_index in range(3):
		var scene := library.kit_scene(kit_id, lod_index)
		if scene == null:
			errors.append("kit %s lod%d no cargado" % [kit_id, lod_index])
			node.free()
			return false
		var variant := scene.instantiate() as Node3D
		if variant == null:
			errors.append("kit %s lod%d inválido" % [kit_id, lod_index])
			node.free()
			return false
		_apply_lod_variant(variant, lods, lod_index)
		node.add_child(variant)
		if lod_index == 0:
			lod0_triangles = _triangle_count(variant)
	add_child(node)
	if bool(poi.get("collision", true)):
		var body := StaticBody3D.new()
		body.name = "Body"
		body.collision_layer = COLLISION_LAYER
		body.collision_mask = COLLISION_MASK
		var shape_node := CollisionShape3D.new()
		var box := BoxShape3D.new()
		var bounds := _bounds_of(node)
		box.size = Vector3(maxf(1.0, bounds.size.x), maxf(1.0, bounds.size.y), maxf(1.0, bounds.size.z))
		shape_node.shape = box
		shape_node.position = bounds.get_center()
		body.add_child(shape_node)
		node.add_child(body)
	_placed.append({
		"id": str(poi.get("id", "")),
		"kit_id": kit_id,
		"position": position,
		"lod0_triangles": lod0_triangles,
	})
	return true


func _apply_lod_variant(variant: Node3D, lods: Array, lod_index: int) -> void:
	var begin := 0.0
	var end := 0.0
	match lod_index:
		0:
			begin = 0.0
			end = float(lods[0].get("range_m", 90.0))
		1:
			begin = float(lods[0].get("range_m", 90.0))
			end = float(lods[1].get("range_m", 260.0))
		2:
			begin = float(lods[1].get("range_m", 260.0))
			end = 0.0
	_apply_ranges(variant, begin, end)


func _apply_ranges(node: Node, begin: float, end: float) -> void:
	if node is MeshInstance3D:
		var instance := node as MeshInstance3D
		instance.visibility_range_begin = begin
		instance.visibility_range_begin_margin = 4.0
		instance.visibility_range_end = end
		instance.visibility_range_end_margin = 8.0
	for child in node.get_children():
		_apply_ranges(child, begin, end)


func _triangle_count(node: Node) -> int:
	var total := 0
	if node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh as ArrayMesh
		if mesh != null:
			for surface in range(mesh.get_surface_count()):
				var arrays := mesh.surface_get_arrays(surface)
				var indices_value: Variant = arrays[Mesh.ARRAY_INDEX] if arrays.size() > Mesh.ARRAY_INDEX else null
				if indices_value is PackedInt32Array and not (indices_value as PackedInt32Array).is_empty():
					total += (indices_value as PackedInt32Array).size() / 3
				else:
					var vertices_value: Variant = arrays[Mesh.ARRAY_VERTEX]
					if vertices_value is PackedVector3Array:
						total += (vertices_value as PackedVector3Array).size() / 3
	for child in node.get_children():
		total += _triangle_count(child)
	return total


func _bounds_of(node: Node) -> AABB:
	var bounds := AABB()
	var first := true
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is MeshInstance3D:
			var mesh := (current as MeshInstance3D).mesh as ArrayMesh
			if mesh != null:
				var local := (current as MeshInstance3D).transform * mesh.get_aabb()
				if first:
					bounds = local
					first = false
				else:
					bounds = bounds.merge(local)
		for child in current.get_children():
			stack.append(child)
	if first:
		bounds = AABB(Vector3(-1.0, 0.0, -1.0), Vector3(2.0, 3.0, 2.0))
	return bounds


func _sample_at(points: PackedVector3Array, cumulative: PackedFloat32Array, distance_m: float) -> Dictionary:
	if points.size() < 2:
		return {"position": Vector3.ZERO, "tangent": Vector3.FORWARD}
	var distance := clampf(distance_m, 0.0, float(cumulative[cumulative.size() - 1]))
	var low := 0
	var high := cumulative.size() - 2
	while low < high:
		var mid := (low + high) >> 1
		if cumulative[mid + 1] < distance:
			low = mid + 1
		else:
			high = mid
	var index := clampi(low, 0, points.size() - 2)
	var span := maxf(0.001, float(cumulative[index + 1]) - float(cumulative[index]))
	var t := clampf((distance - float(cumulative[index])) / span, 0.0, 1.0)
	var position := points[index].lerp(points[index + 1], t)
	var tangent := (points[index + 1] - points[index]).normalized()
	if tangent.length_squared() < 0.5:
		tangent = Vector3.FORWARD
	return {"position": position, "tangent": tangent}


func _clear() -> void:
	for child in get_children():
		child.queue_free()
	_placed.clear()
	_placed_by_kind.clear()


static func _hash01_string(text: String, salt: int) -> float:
	var hash_value := 5381
	for index in range(text.length()):
		hash_value = ((hash_value << 5) + hash_value + text.unicode_at(index)) & 0x7FFFFFFF
	hash_value = ((hash_value << 5) + hash_value + salt) & 0x7FFFFFFF
	return float(hash_value % 100000) / 100000.0
