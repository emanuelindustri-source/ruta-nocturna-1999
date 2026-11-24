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
	terrain_collision_stride: int = 2
) -> Node3D:
	var root := Node3D.new()
	root.name = "Sector_%d_%d" % [data.sector_x, data.sector_z]

	var terrain_instance := MeshInstance3D.new()
	terrain_instance.name = "Terrain"
	terrain_instance.mesh = build_terrain_mesh(data, terrain_material)
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


static func build_terrain_mesh(data: WorldSectorData, material: Material) -> ArrayMesh:
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
	var low_color := Color(0.12, 0.155, 0.1)
	var high_color := Color(0.2, 0.21, 0.18)
	var rock_color := Color(0.26, 0.25, 0.22)

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
			var slope := clampf((1.0 - normals[index].y) * 2.5, 0.0, 1.0)
			color = color.lerp(rock_color, slope)
			var variation := 0.92 + 0.16 * _hash01(x_index + data.sector_x * 17, z_index + data.sector_z * 31)
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
