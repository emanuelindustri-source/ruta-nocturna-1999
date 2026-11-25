class_name WorldSectorBuilder
extends RefCounted
## Construye la malla de terreno, la vía y la colisión de un sector de 800 m a
## partir de WorldSectorData. Se ejecuta en el hilo principal con presupuesto
## por frame; los datos ya llegaron por ResourceLoader.load_threaded_request().


static func build_sector(
	data: WorldSectorData,
	terrain_material: Material,
	road_material: Material,
	marking_material: Material,
	collision_layer: int,
	collision_mask: int,
	terrain_collision_stride: int = 2,
	biome: Dictionary = {}
) -> Node3D:
	var root := Node3D.new()
	root.name = "Sector_%d_%d" % [data.sector_x, data.sector_z]

	var terrain_instance := MeshInstance3D.new()
	terrain_instance.name = "Terrain"
	terrain_instance.mesh = build_terrain_mesh(data, terrain_material, biome)
	terrain_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	terrain_instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	root.add_child(terrain_instance)

	var road_instance := MeshInstance3D.new()
	road_instance.name = "Road"
	road_instance.mesh = build_road_mesh(data, road_material, marking_material)
	road_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	road_instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	root.add_child(road_instance)

	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = collision_layer
	body.collision_mask = collision_mask
	root.add_child(body)

	var terrain_shape := CollisionShape3D.new()
	terrain_shape.name = "TerrainShape"
	var terrain_collision := ConcavePolygonShape3D.new()
	terrain_collision.set_faces(build_terrain_faces(data, terrain_collision_stride))
	terrain_shape.shape = terrain_collision
	body.add_child(terrain_shape)

	var road_shape := CollisionShape3D.new()
	road_shape.name = "RoadShape"
	var road_collision := ConcavePolygonShape3D.new()
	road_collision.set_faces(data.road_vertices)
	road_shape.shape = road_collision
	body.add_child(road_shape)

	return root


static func build_terrain_mesh(data: WorldSectorData, material: Material, biome: Dictionary = {}) -> ArrayMesh:
	var resolution := data.grid_resolution
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var count := resolution * resolution
	vertices.resize(count)
	normals.resize(count)
	colors.resize(count)
	var spacing := data.grid_spacing_m
	var height_range := maxf(0.5, data.height_max_m - data.height_min_m)
	var terrain_spec: Dictionary = biome.get("terrain", {})
	var low_array: Array = terrain_spec.get("low_color", [0.12, 0.155, 0.1])
	var high_array: Array = terrain_spec.get("high_color", [0.2, 0.21, 0.18])
	var rock_array: Array = terrain_spec.get("rock_color", [0.26, 0.25, 0.22])
	var slope_blend := float(terrain_spec.get("slope_rock_blend", 2.5))
	var color_noise := float(biome.get("relief_variation", {}).get("color_noise", 0.16))
	var low_color := Color(float(low_array[0]), float(low_array[1]), float(low_array[2]))
	var high_color := Color(float(high_array[0]), float(high_array[1]), float(high_array[2]))
	var rock_color := Color(float(rock_array[0]), float(rock_array[1]), float(rock_array[2]))
	var snow: Dictionary = biome.get("surface_presets", {}).get("snow", {})
	var snow_enabled := bool(snow.get("enabled", false))
	var snow_line := float(snow.get("snow_line_m", 9999.0))
	var snow_blend := maxf(1.0, float(snow.get("blend_m", 10.0)))
	var snow_array: Array = snow.get("tint", [0.9, 0.92, 0.95])
	var snow_color := Color(float(snow_array[0]), float(snow_array[1]), float(snow_array[2]))
	var dust: Dictionary = biome.get("surface_presets", {}).get("dust", {})
	var dust_enabled := bool(dust.get("enabled", false))
	var dust_density := float(dust.get("particle_density", 0.0))
	var dust_array: Array = dust.get("tint", [0.62, 0.55, 0.42])
	var dust_color := Color(float(dust_array[0]), float(dust_array[1]), float(dust_array[2]))

	for z_index in range(resolution):
		for x_index in range(resolution):
			var index := z_index * resolution + x_index
			var height := data.heights[index]
			vertices[index] = Vector3(
				data.origin_x + float(x_index) * spacing,
				height,
				data.origin_z + float(z_index) * spacing
			)
			var left := data.heights[z_index * resolution + maxi(0, x_index - 1)]
			var right := data.heights[z_index * resolution + mini(resolution - 1, x_index + 1)]
			var up := data.heights[maxi(0, z_index - 1) * resolution + x_index]
			var down := data.heights[mini(resolution - 1, z_index + 1) * resolution + x_index]
			normals[index] = Vector3(left - right, 2.0 * spacing, up - down).normalized()
			var height_t := clampf((height - data.height_min_m) / height_range, 0.0, 1.0)
			var color := low_color.lerp(high_color, height_t)
			var slope := clampf((1.0 - normals[index].y) * slope_blend, 0.0, 1.0)
			color = color.lerp(rock_color, slope)
			if snow_enabled:
				var snow_t := clampf((height - snow_line) / snow_blend, 0.0, 1.0)
				color = color.lerp(snow_color, snow_t * 0.85)
			if dust_enabled and dust_density > 0.0:
				color = color.lerp(dust_color, clampf(dust_density, 0.0, 1.0) * 0.12)
			var variation := 0.92 + color_noise * _hash01(x_index + data.sector_x * 17, z_index + data.sector_z * 31)
			colors[index] = Color(color.r * variation, color.g * variation, color.b * variation, 1.0)

	for z_index in range(resolution - 1):
		for x_index in range(resolution - 1):
			var i0 := z_index * resolution + x_index
			var i1 := i0 + 1
			var i2 := i0 + resolution
			var i3 := i2 + 1
			indices.append(i0)
			indices.append(i2)
			indices.append(i1)
			indices.append(i1)
			indices.append(i2)
			indices.append(i3)

	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	return mesh


static func build_road_mesh(
	data: WorldSectorData,
	road_material: Material,
	marking_material: Material
) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if data.road_vertices.size() >= 3:
		var road_normals := PackedVector3Array()
		road_normals.resize(data.road_vertices.size())
		for index in range(road_normals.size()):
			road_normals[index] = Vector3.UP
		var road_arrays := []
		road_arrays.resize(Mesh.ARRAY_MAX)
		road_arrays[Mesh.ARRAY_VERTEX] = data.road_vertices
		road_arrays[Mesh.ARRAY_NORMAL] = road_normals
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, road_arrays)
		mesh.surface_set_material(0, road_material)
	if data.marking_vertices.size() >= 3:
		var marking_normals := PackedVector3Array()
		marking_normals.resize(data.marking_vertices.size())
		for index in range(marking_normals.size()):
			marking_normals[index] = Vector3.UP
		var marking_arrays := []
		marking_arrays.resize(Mesh.ARRAY_MAX)
		marking_arrays[Mesh.ARRAY_VERTEX] = data.marking_vertices
		marking_arrays[Mesh.ARRAY_NORMAL] = marking_normals
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, marking_arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, marking_material)
	return mesh


static func build_terrain_faces(data: WorldSectorData, stride: int = 1) -> PackedVector3Array:
	var faces := PackedVector3Array()
	var resolution := data.grid_resolution
	var spacing := data.grid_spacing_m
	var step := maxi(1, stride)
	for z_index in range(0, resolution - 1, step):
		var z_next := mini(z_index + step, resolution - 1)
		for x_index in range(0, resolution - 1, step):
			var x_next := mini(x_index + step, resolution - 1)
			var x0 := data.origin_x + float(x_index) * spacing
			var x1 := data.origin_x + float(x_next) * spacing
			var z0 := data.origin_z + float(z_index) * spacing
			var z1 := data.origin_z + float(z_next) * spacing
			var h00 := data.heights[z_index * resolution + x_index]
			var h10 := data.heights[z_index * resolution + x_next]
			var h01 := data.heights[z_next * resolution + x_index]
			var h11 := data.heights[z_next * resolution + x_next]
			faces.append(Vector3(x0, h00, z0))
			faces.append(Vector3(x0, h01, z1))
			faces.append(Vector3(x1, h10, z0))
			faces.append(Vector3(x1, h10, z0))
			faces.append(Vector3(x0, h01, z1))
			faces.append(Vector3(x1, h11, z1))
	return faces


static func _hash01(x: int, z: int) -> float:
	var value := sin(float(x) * 12.9898 + float(z) * 78.233) * 43758.5453
	return value - floorf(value)


const WATER_SHADER: Shader = preload("res://shaders/world_water.gdshader")


## Añade decorado de bioma, mobiliario vial y agua visual a un sector ya
## construido (F4.3). Todo es determinista por coordenadas de sector y respeta
## el presupuesto de triángulos declarado en world_biomes.json. No toca la
## geometría ni la colisión de terreno/vía de F4.2.
static func build_sector_decor(
	root: Node3D,
	data: WorldSectorData,
	biome: Dictionary,
	library: WorldKitLibrary,
	lod_level: int,
	budget: int
) -> Dictionary:
	var report := {"decor_triangles": 0, "furniture_triangles": 0, "instances": 0, "water": false}
	if biome.is_empty() or library == null or budget <= 0:
		return report
	var samples := _road_samples(data)
	if samples.is_empty():
		return report
	var decor_root := Node3D.new()
	decor_root.name = "Decor"
	root.add_child(decor_root)

	var half_ribbon := _road_half_width(data)
	var used := 0
	var furniture_budget := mini(library.furniture_budget(), budget)
	var furniture_used := 0
	var seed_base := data.sector_x * 73856093 ^ data.sector_z * 19349663
	var max_lateral := data.sector_size_m * 0.5

	# 1) Mobiliario vial (kits bpy + props procedurales de borde).
	var road_km := data.road_length_m / 1000.0
	var roadside_index := 0
	for entry in biome.get("roadside", []):
		var kit_id := str(entry.get("kit", ""))
		# every_n_km está en km reales; el espacio de juego es 1:20 (0,05).
		var every_km := maxf(0.005, float(entry.get("every_n_km", 1.0)) * 0.05)
		var expected := road_km / every_km
		var count := int(floor(expected))
		if _rand01(seed_base + roadside_index, 11) < expected - float(count):
			count += 1
		count = mini(count, int(entry.get("max_instances", 0)))
		var mesh := _roadside_mesh(kit_id, library, lod_level)
		if mesh == null:
			roadside_index += 1
			continue
		var triangles := _mesh_triangles(mesh)
		var material_tris := triangles
		for instance_index in range(count):
			if used + material_tris > budget or furniture_used + material_tris > furniture_budget:
				break
			var placement := _roadside_placement(
				data, samples, entry, half_ribbon, max_lateral,
				seed_base + roadside_index * 131 + instance_index
			)
			if placement.is_empty():
				continue
			var node := MeshInstance3D.new()
			node.name = "Roadside_%s_%d" % [kit_id.get_slice(".", kit_id.get_slice_count(".") - 1), instance_index]
			node.mesh = mesh
			node.position = placement["position"]
			node.rotation.y = placement["yaw"]
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
			decor_root.add_child(node)
			used += material_tris
			furniture_used += material_tris
			report["furniture_triangles"] = furniture_used
			report["instances"] = int(report["instances"]) + 1
		roadside_index += 1

	# 2) Vegetación y rocas (MultiMesh por prop).
	var decor_index := 0
	for entry in biome.get("decor", []):
		var prop_id := str(entry.get("prop", ""))
		var mesh := library.prop_mesh(prop_id, lod_level)
		if mesh == null or mesh.get_surface_count() == 0:
			decor_index += 1
			continue
		var triangles := _mesh_triangles(mesh)
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = mesh
		var transforms := []
		var max_instances := int(entry.get("max_instances", 0))
		for instance_index in range(max_instances):
			if used + triangles > budget:
				break
			var placement := _roadside_placement(
				data, samples, entry, half_ribbon, max_lateral,
				seed_base + decor_index * 977 + instance_index * 17
			)
			if placement.is_empty():
				continue
			var basis := Basis(Vector3.UP, placement["yaw"]).scaled(
				Vector3.ONE * (0.85 + 0.4 * _rand01(seed_base + decor_index, instance_index))
			)
			transforms.append(Transform3D(basis, placement["position"]))
			used += triangles
		if transforms.is_empty():
			decor_index += 1
			continue
		multi.instance_count = transforms.size()
		for index in range(transforms.size()):
			multi.set_instance_transform(index, transforms[index])
		var instance := MultiMeshInstance3D.new()
		instance.name = "Decor_%s" % prop_id.get_slice(".", 1)
		instance.multimesh = multi
		instance.cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			if prop_id in ["prop.palm", "prop.tree", "prop.rock", "prop.guardrail"]
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		)
		instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		decor_root.add_child(instance)
		report["instances"] = int(report["instances"]) + transforms.size()
		decor_index += 1

	# 3) Agua visual (preset por bioma; sin física: vadeo F5.1 / clima F4.4).
	var water: Dictionary = biome.get("surface_presets", {}).get("water", {})
	if bool(water.get("enabled", false)) and str(water.get("level_mode", "")) == "sector_low_fill":
		var water_y := data.height_min_m + float(water.get("level_bias_m", 0.0))
		if water_y < data.height_max_m - 0.5 and used + 2 <= budget:
			var water_instance := MeshInstance3D.new()
			water_instance.name = "Water"
			water_instance.mesh = _water_quad(data, water_y)
			water_instance.material_override = _water_material(water)
			water_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			water_instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
			decor_root.add_child(water_instance)
			used += 2
			report["water"] = true

	report["decor_triangles"] = used
	return report


static func _roadside_mesh(kit_id: String, library: WorldKitLibrary, lod_level: int) -> ArrayMesh:
	if kit_id.begins_with("road.kit_"):
		return library.kit_mesh(kit_id, lod_level)
	return library.prop_mesh(kit_id, lod_level)


static func _roadside_placement(
	data: WorldSectorData,
	samples: Array,
	entry: Dictionary,
	half_ribbon: float,
	max_lateral: float,
	seed: int
) -> Dictionary:
	if samples.is_empty():
		return {}
	var sample: Dictionary = samples[int(_rand01(seed, 3) * samples.size()) % samples.size()]
	var min_lateral := maxf(0.5, float(entry.get("min_lateral_m", 6.0)))
	var max_entry := maxf(min_lateral, float(entry.get("max_lateral_m", 60.0)))
	max_entry = minf(max_entry, max_lateral - half_ribbon)
	if max_entry <= min_lateral:
		return {}
	var lateral := half_ribbon + min_lateral + _rand01(seed, 5) * (max_entry - min_lateral)
	var side := 1.0 if _rand01(seed, 7) < 0.5 else -1.0
	var normal: Vector3 = sample["normal"]
	var center: Vector3 = sample["center"]
	var position := center + normal * (lateral * side)
	position.x = clampf(position.x, data.origin_x + 2.0, data.origin_x + data.sector_size_m - 2.0)
	position.z = clampf(position.z, data.origin_z + 2.0, data.origin_z + data.sector_size_m - 2.0)
	var ground := _terrain_height_slope(data, position.x, position.z)
	position.y = float(ground.get("height", 0.0))
	if float(ground.get("slope_pct", 0.0)) > float(entry.get("max_slope_pct", 90.0)):
		return {}
	var yaw := _rand01(seed, 13) * TAU
	return {"position": position, "yaw": yaw}


static func _terrain_height_slope(data: WorldSectorData, x: float, z: float) -> Dictionary:
	var resolution := data.grid_resolution
	var spacing := data.grid_spacing_m
	var gx := clampf((x - data.origin_x) / spacing, 0.0, float(resolution - 1))
	var gz := clampf((z - data.origin_z) / spacing, 0.0, float(resolution - 1))
	var x0 := int(floor(gx))
	var z0 := int(floor(gz))
	var x1 := mini(x0 + 1, resolution - 1)
	var z1 := mini(z0 + 1, resolution - 1)
	var fx := gx - float(x0)
	var fz := gz - float(z0)
	var h00 := data.heights[z0 * resolution + x0]
	var h10 := data.heights[z0 * resolution + x1]
	var h01 := data.heights[z1 * resolution + x0]
	var h11 := data.heights[z1 * resolution + x1]
	var height := (h00 * (1.0 - fx) + h10 * fx) * (1.0 - fz) + (h01 * (1.0 - fx) + h11 * fx) * fz
	var dx := ((h10 - h00) + (h11 - h01)) * 0.5 / spacing
	var dz := ((h01 - h00) + (h11 - h10)) * 0.5 / spacing
	var slope_pct := 100.0 * sqrt(dx * dx + dz * dz)
	return {"height": height, "slope_pct": slope_pct}


static func _road_samples(data: WorldSectorData) -> Array:
	var samples := []
	var vertices := data.road_vertices
	var index := 0
	while index + 2 < vertices.size():
		var a := vertices[index]
		var b := vertices[index + 1]
		var c := vertices[index + 2]
		var center := (a + b + c) / 3.0
		var edge := b - a
		var normal := Vector3(edge.z, 0.0, -edge.x)
		if normal.length_squared() < 0.0001:
			normal = Vector3(1, 0, 0)
		normal = normal.normalized()
		samples.append({"center": center, "normal": normal})
		index += 3
	return samples


static func _road_half_width(data: WorldSectorData) -> float:
	var vertices := data.road_vertices
	var widest := 3.6
	var index := 0
	while index + 2 < vertices.size():
		var a := vertices[index]
		var b := vertices[index + 1]
		var c := vertices[index + 2]
		var center := (a + b + c) / 3.0
		for point in [a, b, c]:
			var delta := Vector3(point.x - center.x, 0.0, point.z - center.z).length()
			widest = maxf(widest, delta)
		index += 3
	return minf(widest, 8.0)


static func _mesh_triangles(mesh: ArrayMesh) -> int:
	var total := 0
	for surface in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface)
		var indices_value: Variant = arrays[Mesh.ARRAY_INDEX] if arrays.size() > Mesh.ARRAY_INDEX else null
		if indices_value is PackedInt32Array and not (indices_value as PackedInt32Array).is_empty():
			total += (indices_value as PackedInt32Array).size() / 3
		else:
			var vertices_value: Variant = arrays[Mesh.ARRAY_VERTEX]
			if vertices_value is PackedVector3Array:
				total += (vertices_value as PackedVector3Array).size() / 3
	return total


static func _water_quad(data: WorldSectorData, height: float) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var x0 := data.origin_x
	var z0 := data.origin_z
	var x1 := x0 + data.sector_size_m
	var z1 := z0 + data.sector_size_m
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(x0, height, z0), Vector3(x0, height, z1), Vector3(x1, height, z0),
		Vector3(x1, height, z0), Vector3(x0, height, z1), Vector3(x1, height, z1),
	])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([
		Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP,
	])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _water_material(water: Dictionary) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = WATER_SHADER
	var color: Array = water.get("color", [0.05, 0.11, 0.13])
	material.set_shader_parameter("water_color", Vector3(float(color[0]), float(color[1]), float(color[2])))
	material.set_shader_parameter("water_roughness", float(water.get("roughness", 0.12)))
	material.set_shader_parameter("water_metallic", float(water.get("metallic", 0.25)))
	material.set_shader_parameter("wave_amplitude", float(water.get("wave_amplitude_m", 0.1)))
	material.set_shader_parameter("wave_speed", float(water.get("wave_speed_mps", 0.35)))
	return material


static func _rand01(seed_value: int, salt: int) -> float:
	var value := sin(float(seed_value % 100000) * 12.9898 + float(salt) * 78.233) * 43758.5453
	return value - floorf(value)
