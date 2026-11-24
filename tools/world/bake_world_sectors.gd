extends Node
## Horneado reproducible de sectores de 800 m (F4.2).
##
## Ejecutar:
##   .\tools\dev\bake_world_sectors.cmd
##
## Genera data/content/world/sectors/*.res y sectors.manifest.json a partir de
## la red OSM/DEM de F4.1. No usa el addon Terrain3D ni texturas externas.

const NETWORK_PATH := "res://data/content/world/route_network.json"
const ROUTES_CONTRACT_PATH := "res://data/schemas/world_routes.json"
const STREAMING_CONTRACT_PATH := "res://data/schemas/world_streaming.json"
const SECTORS_DIR := "res://data/content/world/sectors"
const MANIFEST_PATH := "res://data/content/world/sectors.manifest.json"

const POINT_CELL_M := 100.0
const MAX_RING := 14

var _network: RouteNetwork
var _routes_contract: Dictionary = {}
var _streaming_contract: Dictionary = {}
var _point_cells: Dictionary = {}
var _sector_keys: Dictionary = {}
var _edge_points: Dictionary = {}
var _edge_offsets: Dictionary = {}
var _sector_records: Array[Dictionary] = []
var _projection: Dictionary = {}

var _terrain_grid := 33
var _sector_size := 800.0
var _grid_spacing := 25.0
var _road_half_width := 3.6
var _road_offset := 0.06
var _marking_width := 0.14
var _marking_period := 25.0
var _marking_length := 5.0
var _flat_radius := 12.0
var _blend_end := 80.0
var _noise_amplitude := 18.0
var _noise_wavelength := 420.0
var _max_offset := 28.0
var _octaves := 2
var _vertical_offset := -0.18
var _asphalt_color := Color(0.115, 0.12, 0.13)
var _marking_color := Color(0.72, 0.68, 0.55)


func _ready() -> void:
	print("[BAKE] Inicio del horneado de sectores F4.2")
	_load_inputs()
	if _network == null:
		_fail("No se pudo cargar RouteNetwork")
		return
	_apply_contract_values()
	_build_point_index()
	_build_road_offsets()
	_collect_sectors()
	print("[BAKE] Sectores detectados: %d" % _sector_keys.size())
	_clean_output_dir()
	var index := 0
	var total := _sector_keys.size()
	for key in _sector_keys:
		index += 1
		var sector_x := int(_sector_keys[key][0])
		var sector_z := int(_sector_keys[key][1])
		_bake_sector(sector_x, sector_z)
		if index % 25 == 0 or index == total:
			print("[BAKE] Progreso %d/%d (%s)" % [index, total, key])
	_write_manifest()
	print("[BAKE] OK %d sectores" % _sector_records.size())
	get_tree().quit(0)


func _load_inputs() -> void:
	_network = RouteNetwork.new()
	if not _network.load_all():
		for error in _network.errors:
			print("[BAKE] ERROR: %s" % error)
		return
	_routes_contract = _read_json(ROUTES_CONTRACT_PATH)
	_streaming_contract = _read_json(STREAMING_CONTRACT_PATH)
	if _routes_contract.is_empty() or _streaming_contract.is_empty():
		_network = null


func _apply_contract_values() -> void:
	_projection = _routes_contract.get("projection", {})
	var terrain: Dictionary = _streaming_contract.get("terrain", {})
	_terrain_grid = int(terrain.get("grid_resolution", 33))
	_sector_size = float(terrain.get("sector_size_m", 800.0))
	_grid_spacing = float(terrain.get("grid_spacing_m", _sector_size / maxf(1.0, float(_terrain_grid - 1))))
	_vertical_offset = float(terrain.get("vertical_offset_m", -0.18))
	var road: Dictionary = terrain.get("road", {})
	_road_half_width = float(road.get("width_m", 7.2)) * 0.5
	_road_offset = float(road.get("surface_offset_m", 0.06))
	_marking_width = float(road.get("marking_width_m", 0.14))
	_marking_period = float(road.get("marking_period_m", 25.0))
	_marking_length = float(road.get("marking_length_m", 5.0))
	var asphalt: Array = road.get("asphalt_color", [0.115, 0.12, 0.13])
	var marking: Array = road.get("marking_color", [0.72, 0.68, 0.55])
	_asphalt_color = Color(float(asphalt[0]), float(asphalt[1]), float(asphalt[2]))
	_marking_color = Color(float(marking[0]), float(marking[1]), float(marking[2]))
	var relief: Dictionary = terrain.get("relief", {})
	_flat_radius = float(relief.get("flat_radius_m", 12.0))
	_blend_end = maxf(_flat_radius + 1.0, float(relief.get("blend_end_m", 80.0)))
	_noise_amplitude = float(relief.get("noise_amplitude_m", 18.0))
	_noise_wavelength = maxf(1.0, float(relief.get("noise_wavelength_m", 420.0)))
	_max_offset = float(relief.get("max_offset_m", 28.0))
	_octaves = int(relief.get("octaves", 2))


func _build_point_index() -> void:
	for edge_id in _network.edges:
		var points := _network.edge_world_points(edge_id)
		_edge_points[edge_id] = points
		for point in points:
			var cell := Vector2i(floori(point.x / POINT_CELL_M), floori(point.z / POINT_CELL_M))
			if not _point_cells.has(cell):
				_point_cells[cell] = []
			_point_cells[cell].append(point)


func _build_road_offsets() -> void:
	for edge_id in _edge_points:
		var points: PackedVector3Array = _edge_points[edge_id]
		var left := PackedVector3Array()
		var right := PackedVector3Array()
		if points.size() < 2:
			_edge_offsets[edge_id] = {"left": left, "right": right}
			continue
		left.resize(points.size())
		right.resize(points.size())
		for index in range(points.size()):
			var normal := _vertex_normal(points, index)
			left[index] = points[index] + Vector3(normal.x, 0.0, normal.y)
			right[index] = points[index] - Vector3(normal.x, 0.0, normal.y)
		_edge_offsets[edge_id] = {"left": left, "right": right}


func _vertex_normal(points: PackedVector3Array, index: int) -> Vector2:
	var count := points.size()
	if count < 2:
		return Vector2.ZERO
	var incoming := Vector2.ZERO
	var outgoing := Vector2.ZERO
	if index > 0:
		incoming = _perp2d(points[index].x - points[index - 1].x, points[index].z - points[index - 1].z)
	if index < count - 1:
		outgoing = _perp2d(points[index + 1].x - points[index].x, points[index + 1].z - points[index].z)
	if index == 0:
		return outgoing * _road_half_width
	if index == count - 1:
		return incoming * _road_half_width
	var miter := incoming + outgoing
	if miter.length_squared() < 0.0001:
		return incoming * _road_half_width
	miter = miter.normalized()
	var denominator := maxf(0.35, miter.dot(incoming))
	var length := minf(_road_half_width / denominator, _road_half_width * 1.8)
	return miter * length


func _perp2d(dx: float, dz: float) -> Vector2:
	var length := sqrt(dx * dx + dz * dz)
	if length < 0.0001:
		return Vector2.ZERO
	return Vector2(-dz / length, dx / length)


func _collect_sectors() -> void:
	for edge_id in _network.edges:
		var points: PackedVector3Array = _edge_points[edge_id]
		for point in points:
			_add_sector_for_point(point)
		for index in range(points.size() - 1):
			var p0 := points[index]
			var p1 := points[index + 1]
			var min_x := minf(p0.x, p1.x) - _road_half_width
			var max_x := maxf(p0.x, p1.x) + _road_half_width
			var min_z := minf(p0.z, p1.z) - _road_half_width
			var max_z := maxf(p0.z, p1.z) + _road_half_width
			for sx in range(floori(min_x / _sector_size), floori(max_x / _sector_size) + 1):
				for sz in range(floori(min_z / _sector_size), floori(max_z / _sector_size) + 1):
					_sector_keys["%d_%d" % [sx, sz]] = [sx, sz]


func _add_sector_for_point(point: Vector3) -> void:
	var sx := floori(point.x / _sector_size)
	var sz := floori(point.z / _sector_size)
	_sector_keys["%d_%d" % [sx, sz]] = [sx, sz]


func _clean_output_dir() -> void:
	DirAccess.make_dir_recursive_absolute(SECTORS_DIR)
	var dir := DirAccess.open(SECTORS_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.ends_with(".res"):
			dir.remove(name)
		name = dir.get_next()
	dir.list_dir_end()


func _bake_sector(sector_x: int, sector_z: int) -> void:
	var origin_x := float(sector_x) * _sector_size
	var origin_z := float(sector_z) * _sector_size
	var heights := PackedFloat32Array()
	heights.resize(_terrain_grid * _terrain_grid)
	var height_min := INF
	var height_max := -INF
	for z_index in range(_terrain_grid):
		var world_z := origin_z + float(z_index) * _grid_spacing
		for x_index in range(_terrain_grid):
			var world_x := origin_x + float(x_index) * _grid_spacing
			var height := _terrain_height(world_x, world_z)
			heights[z_index * _terrain_grid + x_index] = height
			height_min = minf(height_min, height)
			height_max = maxf(height_max, height)

	var road_vertices := PackedVector3Array()
	var marking_vertices := PackedVector3Array()
	var edge_ids := {}
	var road_length := 0.0
	var rect := Rect2(origin_x, origin_z, _sector_size, _sector_size)
	for edge_id in _network.edges:
		var points: PackedVector3Array = _edge_points[edge_id]
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
		var offsets: Dictionary = _edge_offsets.get(edge_id, {})
		if offsets.is_empty():
			continue
		var left: PackedVector3Array = offsets["left"]
		var right: PackedVector3Array = offsets["right"]
		for index in range(points.size() - 1):
			var p0 := points[index]
			var p1 := points[index + 1]
			var left_a := left[index] + Vector3(0.0, _road_offset, 0.0)
			var right_a := right[index] + Vector3(0.0, _road_offset, 0.0)
			var left_b := left[index + 1] + Vector3(0.0, _road_offset, 0.0)
			var right_b := right[index + 1] + Vector3(0.0, _road_offset, 0.0)
			var quad := PackedVector3Array([left_a, right_a, right_b, left_b])
			var min_x := minf(minf(left_a.x, right_a.x), minf(left_b.x, right_b.x))
			var max_x := maxf(maxf(left_a.x, right_a.x), maxf(left_b.x, right_b.x))
			var min_z := minf(minf(left_a.z, right_a.z), minf(left_b.z, right_b.z))
			var max_z := maxf(maxf(left_a.z, right_a.z), maxf(left_b.z, right_b.z))
			if max_x < rect.position.x or min_x > rect.end.x or max_z < rect.position.y or min_z > rect.end.y:
				continue
			var polygon := _clip_polygon_to_rect(quad, rect)
			if polygon.size() >= 3:
				_append_polygon_fan(road_vertices, polygon)
				edge_ids[edge_id] = true
			var clipped := _clip_to_rect(p0, p1, rect)
			if clipped.is_empty():
				continue
			var t0 := float(clipped[0])
			var t1 := float(clipped[1])
			if t1 - t0 < 0.00001:
				continue
			var a := p0.lerp(p1, t0)
			var b := p0.lerp(p1, t1)
			road_length += Vector2(b.x - a.x, b.z - a.z).length()
			var seg_start := cumulative[index]
			var seg_length := maxf(0.001, cumulative[index + 1] - cumulative[index])
			_add_markings(
				marking_vertices,
				p0,
				p1,
				seg_start,
				seg_length,
				seg_start + t0 * seg_length,
				seg_start + t1 * seg_length
			)

	var data := WorldSectorData.new()
	data.sector_x = sector_x
	data.sector_z = sector_z
	data.sector_size_m = _sector_size
	data.grid_resolution = _terrain_grid
	data.grid_spacing_m = _grid_spacing
	data.origin_x = origin_x
	data.origin_z = origin_z
	data.heights = heights
	data.road_vertices = road_vertices
	data.marking_vertices = marking_vertices
	data.road_edge_ids = PackedStringArray(edge_ids.keys())
	data.road_length_m = road_length
	data.height_min_m = height_min
	data.height_max_m = height_max
	data.terrain_triangle_count = (_terrain_grid - 1) * (_terrain_grid - 1) * 2
	data.road_triangle_count = road_vertices.size() / 3

	var path := "%s/%s" % [SECTORS_DIR, _sector_file_name(sector_x, sector_z)]
	var save_error := ResourceSaver.save(data, path)
	if save_error != OK:
		_fail("No se pudo guardar %s (error %d)" % [path, save_error])
		return
	var bytes := FileAccess.get_file_as_bytes(path)
	var record := {
		"id": "%d_%d" % [sector_x, sector_z],
		"path": path.trim_prefix("res://"),
		"sector_x": sector_x,
		"sector_z": sector_z,
		"bytes": bytes.size(),
		"sha256": _sha256(bytes),
		"terrain_triangles": data.terrain_triangle_count,
		"road_triangles": data.road_triangle_count,
		"marking_triangles": marking_vertices.size() / 3,
		"road_length_m": snappedf(road_length, 0.1),
		"height_min_m": snappedf(height_min, 0.1),
		"height_max_m": snappedf(height_max, 0.1),
		"road_edges": data.road_edge_ids.size(),
	}
	_sector_records.append(record)


func _terrain_height(world_x: float, world_z: float) -> float:
	var nearest := _nearest_sample(world_x, world_z)
	var road_y := 0.0
	var distance := 0.0
	if not nearest.is_empty():
		var point: Vector3 = nearest["point"]
		road_y = point.y
		distance = nearest["distance"]
	var flat := _flat_radius
	var t := smoothstep(flat, _blend_end, distance)
	var noise := _fbm(world_x / _noise_wavelength, world_z / _noise_wavelength)
	var relief := clampf(noise * _noise_amplitude * t, -_max_offset, _max_offset)
	var height := road_y + _vertical_offset + relief
	return height


func _nearest_sample(world_x: float, world_z: float) -> Dictionary:
	var cell := Vector2i(floori(world_x / POINT_CELL_M), floori(world_z / POINT_CELL_M))
	var best_distance := INF
	var best_point := Vector3.ZERO
	var found_ring := -1
	for ring in range(0, MAX_RING + 1):
		var found_in_ring := false
		if ring == 0:
			found_in_ring = _scan_cell(cell.x, cell.y, world_x, world_z, best_distance, best_point)
			if found_in_ring:
				best_distance = _last_scan_distance
				best_point = _last_scan_point
		else:
			for gx in range(cell.x - ring, cell.x + ring + 1):
				if _scan_cell(gx, cell.y - ring, world_x, world_z, best_distance, best_point):
					found_in_ring = true
					best_distance = _last_scan_distance
					best_point = _last_scan_point
				if _scan_cell(gx, cell.y + ring, world_x, world_z, best_distance, best_point):
					found_in_ring = true
					best_distance = _last_scan_distance
					best_point = _last_scan_point
			for gz in range(cell.y - ring + 1, cell.y + ring):
				if _scan_cell(cell.x - ring, gz, world_x, world_z, best_distance, best_point):
					found_in_ring = true
					best_distance = _last_scan_distance
					best_point = _last_scan_point
				if _scan_cell(cell.x + ring, gz, world_x, world_z, best_distance, best_point):
					found_in_ring = true
					best_distance = _last_scan_distance
					best_point = _last_scan_point
		if found_in_ring and found_ring < 0:
			found_ring = ring
		if found_ring >= 0 and ring > found_ring:
			break
	if is_inf(best_distance):
		return {}
	return {"point": best_point, "distance": sqrt(best_distance)}


var _last_scan_distance := INF
var _last_scan_point := Vector3.ZERO


func _scan_cell(
	cell_x: int,
	cell_z: int,
	world_x: float,
	world_z: float,
	best_distance: float,
	best_point: Vector3
) -> bool:
	var key := Vector2i(cell_x, cell_z)
	if not _point_cells.has(key):
		return false
	var found := false
	for point in _point_cells[key]:
		var dx := float(point.x) - world_x
		var dz := float(point.z) - world_z
		var distance := dx * dx + dz * dz
		if distance < best_distance:
			best_distance = distance
			best_point = point
			found = true
	_last_scan_distance = best_distance
	_last_scan_point = best_point
	return found


func _clip_to_rect(p0: Vector3, p1: Vector3, rect: Rect2) -> Array:
	var t0 := 0.0
	var t1 := 1.0
	var dx := p1.x - p0.x
	var dz := p1.z - p0.z
	var checks := [
		[-dx, p0.x - rect.position.x],
		[dx, rect.position.x + rect.size.x - p0.x],
		[-dz, p0.z - rect.position.y],
		[dz, rect.position.y + rect.size.y - p0.z],
	]
	for check in checks:
		var p := float(check[0])
		var q := float(check[1])
		if absf(p) < 0.0000001:
			if q < 0.0:
				return []
			continue
		var r := q / p
		if p < 0.0:
			t0 = maxf(t0, r)
		else:
			t1 = minf(t1, r)
		if t0 > t1:
			return []
	return [t0, t1]


func _clip_polygon_to_rect(polygon: PackedVector3Array, rect: Rect2) -> PackedVector3Array:
	var result := polygon
	for boundary in range(4):
		if result.is_empty():
			break
		var output := PackedVector3Array()
		for index in range(result.size()):
			var a := result[index]
			var b := result[(index + 1) % result.size()]
			var a_inside := _point_inside_rect(a, rect, boundary)
			var b_inside := _point_inside_rect(b, rect, boundary)
			if a_inside:
				output.append(a)
			if a_inside != b_inside:
				output.append(_boundary_intersection(a, b, rect, boundary))
		result = output
	return result


func _point_inside_rect(point: Vector3, rect: Rect2, boundary: int) -> bool:
	match boundary:
		0:
			return point.x >= rect.position.x
		1:
			return point.x <= rect.end.x
		2:
			return point.z >= rect.position.y
		_:
			return point.z <= rect.end.y


func _boundary_intersection(a: Vector3, b: Vector3, rect: Rect2, boundary: int) -> Vector3:
	var t := 0.0
	if boundary == 0 or boundary == 1:
		var x_boundary := rect.position.x if boundary == 0 else rect.end.x
		var denominator := b.x - a.x
		t = 0.0 if absf(denominator) < 0.0000001 else (x_boundary - a.x) / denominator
	else:
		var z_boundary := rect.position.y if boundary == 2 else rect.end.y
		var denominator_z := b.z - a.z
		t = 0.0 if absf(denominator_z) < 0.0000001 else (z_boundary - a.z) / denominator_z
	t = clampf(t, 0.0, 1.0)
	return a.lerp(b, t)


func _append_polygon_fan(vertices: PackedVector3Array, polygon: PackedVector3Array) -> void:
	if polygon.size() < 3:
		return
	for index in range(1, polygon.size() - 1):
		vertices.append(polygon[0])
		vertices.append(polygon[index])
		vertices.append(polygon[index + 1])


func _add_markings(
	vertices: PackedVector3Array,
	p0: Vector3,
	p1: Vector3,
	seg_start: float,
	seg_length: float,
	d0: float,
	d1: float
) -> void:
	if _marking_period <= 0.0 or _marking_length <= 0.0:
		return
	var first := floori(d0 / _marking_period)
	var last := floori(d1 / _marking_period)
	for dash in range(first, last + 1):
		var dash_start := float(dash) * _marking_period
		var dash_end := dash_start + _marking_length
		var start := maxf(d0, dash_start)
		var end := minf(d1, dash_end)
		if end <= start:
			continue
		var t0 := clampf((start - seg_start) / seg_length, 0.0, 1.0)
		var t1 := clampf((end - seg_start) / seg_length, 0.0, 1.0)
		var a := p0.lerp(p1, t0)
		var b := p0.lerp(p1, t1)
		_add_marking_quad(vertices, a, b)


func _add_marking_quad(vertices: PackedVector3Array, a: Vector3, b: Vector3) -> void:
	var dx := b.x - a.x
	var dz := b.z - a.z
	var length := sqrt(dx * dx + dz * dz)
	if length < 0.001:
		return
	var perp_x := -dz / length * _marking_width * 0.5
	var perp_z := dx / length * _marking_width * 0.5
	var ay := a.y + _road_offset + 0.012
	var by := b.y + _road_offset + 0.012
	vertices.append(Vector3(a.x + perp_x, ay, a.z + perp_z))
	vertices.append(Vector3(a.x - perp_x, ay, a.z - perp_z))
	vertices.append(Vector3(b.x + perp_x, by, b.z + perp_z))
	vertices.append(Vector3(a.x - perp_x, ay, a.z - perp_z))
	vertices.append(Vector3(b.x - perp_x, by, b.z - perp_z))
	vertices.append(Vector3(b.x + perp_x, by, b.z + perp_z))


func _fbm(u: float, v: float) -> float:
	var value := 0.0
	var amplitude := 1.0
	var frequency := 1.0
	var total_amplitude := 0.0
	for octave in range(_octaves):
		value += _value_noise(u * frequency, v * frequency) * amplitude
		total_amplitude += amplitude
		amplitude *= 0.5
		frequency *= 2.0
	return value / maxf(0.0001, total_amplitude)


func _value_noise(u: float, v: float) -> float:
	var x0 := floori(u)
	var z0 := floori(v)
	var fx := u - float(x0)
	var fz := v - float(z0)
	var sx := fx * fx * (3.0 - 2.0 * fx)
	var sz := fz * fz * (3.0 - 2.0 * fz)
	var n00 := _hash_noise(x0, z0)
	var n10 := _hash_noise(x0 + 1, z0)
	var n01 := _hash_noise(x0, z0 + 1)
	var n11 := _hash_noise(x0 + 1, z0 + 1)
	var nx0 := lerpf(n00, n10, sx)
	var nx1 := lerpf(n01, n11, sx)
	return lerpf(nx0, nx1, sz) * 2.0 - 1.0


func _hash_noise(x: int, z: int) -> float:
	var value := sin(float(x) * 12.9898 + float(z) * 78.233) * 43758.5453
	return value - floorf(value)


func _sector_file_name(sector_x: int, sector_z: int) -> String:
	return "s_%s_%s.res" % [_coord_tag(sector_x), _coord_tag(sector_z)]


func _coord_tag(value: int) -> String:
	if value < 0:
		return "m%03d" % abs(value)
	return "p%03d" % value


func _write_manifest() -> void:
	var total_bytes := 0
	var total_terrain := 0
	var total_road := 0
	var total_marking := 0
	var min_height := INF
	var max_height := -INF
	var paths: Array[String] = []
	for record in _sector_records:
		total_bytes += int(record["bytes"])
		total_terrain += int(record["terrain_triangles"])
		total_road += int(record["road_triangles"])
		total_marking += int(record["marking_triangles"])
		min_height = minf(min_height, float(record["height_min_m"]))
		max_height = maxf(max_height, float(record["height_max_m"]))
		var path := "%s/%s" % [SECTORS_DIR, _sector_file_name(int(record["sector_x"]), int(record["sector_z"]))]
		paths.append(path)
	_sector_records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["sector_x"]) == int(b["sector_x"]):
			return int(a["sector_z"]) < int(b["sector_z"])
		return int(a["sector_x"]) < int(b["sector_x"])
	)
	var network_bytes := FileAccess.get_file_as_bytes(NETWORK_PATH)
	var contract_bytes := FileAccess.get_file_as_bytes(STREAMING_CONTRACT_PATH)
	var manifest := {
		"schema_version": 1,
		"contract_id": "world.streaming",
		"world_id": "venezuela.1999",
		"generated_utc": Time.get_datetime_string_from_system(true),
		"generator": "tools/world/bake_world_sectors.gd",
		"generator_version": 1,
		"sector_size_m": _sector_size,
		"grid_resolution": _terrain_grid,
		"grid_spacing_m": _grid_spacing,
		"sector_count": _sector_records.size(),
		"total_bytes": total_bytes,
		"total_terrain_triangles": total_terrain,
		"total_road_triangles": total_road,
		"total_marking_triangles": total_marking,
		"height_min_m": snappedf(min_height, 0.1),
		"height_max_m": snappedf(max_height, 0.1),
		"source": {
			"route_network": NETWORK_PATH.trim_prefix("res://"),
			"route_network_sha256": _sha256(network_bytes),
			"streaming_contract": STREAMING_CONTRACT_PATH.trim_prefix("res://"),
			"streaming_contract_sha256": _sha256(contract_bytes),
			"license": "ODbL 1.0",
			"copyright": "© OpenStreetMap contributors",
			"copyright_url": "https://www.openstreetmap.org/copyright",
		},
		"sectors": _sector_records,
	}
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if file == null:
		_fail("No se pudo escribir el manifiesto")
		return
	file.store_string(JSON.stringify(manifest, "  "))
	file.close()
	print(
		"[BAKE] Manifiesto %d sectores, %.2f MB, %d triángulos de terreno, %d de vía"
		% [_sector_records.size(), total_bytes / 1048576.0, total_terrain, total_road]
	)


func _sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _fail(message: String) -> void:
	print("[BAKE] FAIL %s" % message)
	get_tree().quit(1)
