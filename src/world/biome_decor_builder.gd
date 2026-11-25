class_name BiomeDecorBuilder
extends RefCounted
## Decorado procedural de biomas (F4.3): vegetación, rocas y mobiliario menor.
##
## Los props son mallas proceduralmente reproducibles (MIT) con tres niveles de
## LOD declarados en world_biomes.json (`props[].lods`). No usan texturas
## externas: color por material sencillo. El presupuesto de triángulos por
## sector lo impone WorldSectorBuilder con `max_decor_triangles_per_sector`.


static func build_prop(prop_id: String, lod: int) -> ArrayMesh:
	match prop_id:
		"prop.palm":
			return build_palm(lod)
		"prop.tree":
			return build_tree(lod)
		"prop.bush":
			return build_bush(lod)
		"prop.grass":
			return build_grass(lod)
		"prop.rock":
			return build_rock(lod)
		"prop.frailejon":
			return build_frailejon(lod)
		"prop.km_post":
			return build_km_post(lod)
		"prop.guardrail":
			return build_guardrail(lod)
	return ArrayMesh.new()


static func build_palm(lod: int) -> ArrayMesh:
	var surface := _Surface.new()
	var trunk_height := 7.0
	var trunk_segments := 6 if lod == 0 else (5 if lod == 1 else 4)
	_append_cylinder(surface, Vector3(0, trunk_height * 0.5, 0), 0.22, trunk_height, trunk_segments, Color(0.24, 0.2, 0.15))
	var fronds := 7 if lod == 0 else (6 if lod == 1 else 4)
	var frond_length := 3.2
	for index in range(fronds):
		var angle := TAU * float(index) / float(fronds)
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var tip := Vector3(0, trunk_height, 0) + direction * frond_length + Vector3.DOWN * 0.9
		var width := 0.85 if lod == 0 else 0.65
		_append_quad(
			surface,
			Vector3(0, trunk_height, 0),
			Vector3(0, trunk_height, 0) + direction * frond_length * 0.45 + Vector3.UP * 0.35,
			tip,
			width,
			Color(0.1, 0.19, 0.09)
		)
	return surface.finish()


static func build_tree(lod: int) -> ArrayMesh:
	var surface := _Surface.new()
	var trunk_height := 4.2
	var trunk_segments := 6 if lod == 0 else (5 if lod == 1 else 4)
	_append_cylinder(surface, Vector3(0, trunk_height * 0.5, 0), 0.24, trunk_height, trunk_segments, Color(0.22, 0.18, 0.13))
	var blobs := [
		{"center": Vector3(0, 5.4, 0), "radius": 2.3},
		{"center": Vector3(1.35, 4.6, 0.6), "radius": 1.55},
		{"center": Vector3(-1.25, 4.75, -0.75), "radius": 1.65},
	]
	if lod >= 1:
		blobs = [blobs[0]]
	var segments := 6 if lod == 0 else (5 if lod == 1 else 4)
	var rings := 3 if lod == 0 else (2 if lod == 1 else 1)
	for blob in blobs:
		_append_sphere(surface, blob["center"], blob["radius"], segments, rings, Color(0.11, 0.2, 0.1))
	return surface.finish()


static func build_bush(lod: int) -> ArrayMesh:
	var surface := _Surface.new()
	var blobs := [
		{"center": Vector3(0, 0.55, 0), "radius": 0.85},
		{"center": Vector3(0.65, 0.42, 0.3), "radius": 0.55},
		{"center": Vector3(-0.55, 0.4, -0.35), "radius": 0.5},
	]
	if lod >= 1:
		blobs = [blobs[0]]
	var segments := 6 if lod == 0 else (5 if lod == 1 else 4)
	var rings := 3 if lod == 0 else (2 if lod == 1 else 1)
	for blob in blobs:
		_append_sphere(surface, blob["center"], blob["radius"], segments, rings, Color(0.12, 0.21, 0.1))
	return surface.finish()


static func build_grass(lod: int) -> ArrayMesh:
	var surface := _Surface.new()
	var blades := 3 if lod == 0 else (2 if lod == 1 else 1)
	var color := Color(0.16, 0.24, 0.1)
	for index in range(blades):
		var angle := TAU * float(index) / float(blades) + 0.7
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var base := direction * 0.12
		var tip := base + direction * 0.42 + Vector3.UP * 0.75
		_append_quad(surface, base, base + direction * 0.2 + Vector3.UP * 0.32, tip, 0.3, color)
	return surface.finish()


static func build_rock(lod: int) -> ArrayMesh:
	var surface := _Surface.new()
	var segments := 5 if lod == 0 else (4 if lod == 1 else 3)
	var rings := 2 if lod < 2 else 1
	_append_rock(surface, Vector3(0, 0.32, 0), 1.15, segments, rings, Color(0.27, 0.26, 0.24))
	if lod == 0:
		_append_rock(surface, Vector3(0.95, 0.2, 0.55), 0.62, segments, rings, Color(0.25, 0.24, 0.22))
		_append_rock(surface, Vector3(-0.8, 0.18, -0.5), 0.5, segments, rings, Color(0.29, 0.28, 0.26))
	return surface.finish()


static func build_frailejon(lod: int) -> ArrayMesh:
	var surface := _Surface.new()
	var stem_height := 1.15
	var stem_segments := 5 if lod == 0 else 4
	_append_cylinder(surface, Vector3(0, stem_height * 0.5, 0), 0.12, stem_height, stem_segments, Color(0.32, 0.28, 0.18))
	var leaves := 9 if lod == 0 else (7 if lod == 1 else 5)
	for index in range(leaves):
		var angle := TAU * float(index) / float(leaves)
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var base := Vector3(0, stem_height, 0)
		var tip := base + direction * 0.85 + Vector3.UP * 0.28
		_append_quad(surface, base, base + direction * 0.45 + Vector3.UP * 0.22, tip, 0.3, Color(0.3, 0.33, 0.2))
	return surface.finish()


static func build_km_post(lod: int) -> ArrayMesh:
	var surface := _Surface.new()
	if lod >= 2:
		_append_quad(surface, Vector3(-0.09, 0, 0), Vector3(-0.09, 0.7, 0), Vector3(0.09, 0.7, 0), 0.18, Color(0.72, 0.7, 0.64))
		return surface.finish()
	_append_box(surface, Vector3(0, 0.35, 0), Vector3(0.18, 0.7, 0.1), Color(0.72, 0.7, 0.64))
	if lod == 0:
		_append_box(surface, Vector3(0, 0.55, 0.06), Vector3(0.14, 0.16, 0.02), Color(0.3, 0.22, 0.18))
	return surface.finish()


static func build_guardrail(lod: int) -> ArrayMesh:
	var surface := _Surface.new()
	var length := 4.0
	_append_box(surface, Vector3(0, 0.62, 0), Vector3(0.08, 0.16, length * 0.5), Color(0.5, 0.52, 0.55))
	if lod <= 1:
		_append_box(surface, Vector3(0, 0.42, 0), Vector3(0.05, 0.1, length * 0.5), Color(0.46, 0.48, 0.5))
		_append_box(surface, Vector3(0, 0.31, length * 0.35), Vector3(0.09, 0.62, 0.07), Color(0.42, 0.44, 0.46))
		_append_box(surface, Vector3(0, 0.31, -length * 0.35), Vector3(0.09, 0.62, 0.07), Color(0.42, 0.44, 0.46))
	if lod == 0:
		_append_box(surface, Vector3(0, 0.31, 0), Vector3(0.09, 0.62, 0.07), Color(0.42, 0.44, 0.46))
	elif lod == 2:
		_append_box(surface, Vector3(0, 0.31, 0), Vector3(0.09, 0.62, 0.07), Color(0.42, 0.44, 0.46))
	return surface.finish()


## Acumulador de sopa de triángulos con un solo material por malla.
class _Surface:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	func triangle(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
		var normal := (b - a).cross(c - a)
		if normal.length_squared() < 0.0000001:
			return
		normal = normal.normalized()
		var start := vertices.size()
		vertices.append(a)
		vertices.append(b)
		vertices.append(c)
		normals.append(normal)
		normals.append(normal)
		normals.append(normal)
		colors.append(color)
		colors.append(color)
		colors.append(color)
		indices.append(start)
		indices.append(start + 1)
		indices.append(start + 2)

	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
		triangle(a, b, c, color)
		triangle(a, c, d, color)

	func finish() -> ArrayMesh:
		var mesh := ArrayMesh.new()
		if indices.is_empty():
			return mesh
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.roughness = 0.92
		material.metallic = 0.0
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh.surface_set_material(0, material)
		return mesh


static func _append_cylinder(surface: _Surface, center: Vector3, radius: float, height: float, segments: int, color: Color) -> void:
	var half := height * 0.5
	for index in range(segments):
		var angle_a := TAU * float(index) / float(segments)
		var angle_b := TAU * float(index + 1) / float(segments)
		var a := Vector3(cos(angle_a) * radius, -half, sin(angle_a) * radius)
		var b := Vector3(cos(angle_b) * radius, -half, sin(angle_b) * radius)
		var a_top := Vector3(a.x, half, a.z)
		var b_top := Vector3(b.x, half, b.z)
		surface.quad(a, b, b_top, a_top, color)
		surface.triangle(Vector3(0, half, 0), a_top, b_top, color)


static func _append_sphere(surface: _Surface, center: Vector3, radius: float, segments: int, rings: int, color: Color) -> void:
	for ring in range(rings):
		var phi_a := PI * (float(ring) / float(rings) - 0.5) * 0.96
		var phi_b := PI * (float(ring + 1) / float(rings) - 0.5) * 0.96
		for index in range(segments):
			var theta_a := TAU * float(index) / float(segments)
			var theta_b := TAU * float(index + 1) / float(segments)
			var p0 := center + _sphere_point(radius, phi_a, theta_a)
			var p1 := center + _sphere_point(radius, phi_a, theta_b)
			var p2 := center + _sphere_point(radius, phi_b, theta_b)
			var p3 := center + _sphere_point(radius, phi_b, theta_a)
			surface.quad(p0, p1, p2, p3, color)


static func _sphere_point(radius: float, phi: float, theta: float) -> Vector3:
	return Vector3(
		radius * cos(phi) * cos(theta),
		radius * sin(phi),
		radius * cos(phi) * sin(theta)
	)


static func _append_box(surface: _Surface, center: Vector3, half: Vector3, color: Color) -> void:
	var corners := [
		center + Vector3(-half.x, -half.y, -half.z),
		center + Vector3(half.x, -half.y, -half.z),
		center + Vector3(half.x, -half.y, half.z),
		center + Vector3(-half.x, -half.y, half.z),
		center + Vector3(-half.x, half.y, -half.z),
		center + Vector3(half.x, half.y, -half.z),
		center + Vector3(half.x, half.y, half.z),
		center + Vector3(-half.x, half.y, half.z),
	]
	surface.quad(corners[0], corners[3], corners[2], corners[1], color)
	surface.quad(corners[4], corners[5], corners[6], corners[7], color)
	surface.quad(corners[0], corners[1], corners[5], corners[4], color)
	surface.quad(corners[2], corners[3], corners[7], corners[6], color)
	surface.quad(corners[1], corners[2], corners[6], corners[5], color)
	surface.quad(corners[3], corners[0], corners[4], corners[7], color)


static func _append_rock(surface: _Surface, center: Vector3, radius: float, segments: int, rings: int, color: Color) -> void:
	for ring in range(rings):
		var phi_a := PI * (float(ring) / float(rings) - 0.5) * 0.9
		var phi_b := PI * (float(ring + 1) / float(rings) - 0.5) * 0.9
		for index in range(segments):
			var theta_a := TAU * float(index) / float(segments)
			var theta_b := TAU * float(index + 1) / float(segments)
			var wobble_a := 0.82 + 0.36 * _hash01(ring * 7 + index, segments)
			var wobble_b := 0.82 + 0.36 * _hash01(ring * 7 + index + 1, segments + 3)
			var p0 := center + _sphere_point(radius * wobble_a, phi_a, theta_a) * Vector3(1.0, 0.62, 1.0)
			var p1 := center + _sphere_point(radius * wobble_b, phi_a, theta_b) * Vector3(1.0, 0.62, 1.0)
			var p2 := center + _sphere_point(radius * wobble_b, phi_b, theta_b) * Vector3(1.0, 0.62, 1.0)
			var p3 := center + _sphere_point(radius * wobble_a, phi_b, theta_a) * Vector3(1.0, 0.62, 1.0)
			surface.quad(p0, p1, p2, p3, color)


static func _append_quad(surface: _Surface, base: Vector3, middle: Vector3, tip: Vector3, width: float, color: Color) -> void:
	var direction := (tip - base).normalized()
	var side := direction.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = Vector3.RIGHT
	side = side.normalized() * width * 0.5
	surface.quad(base - side, base + side, middle + side * 0.8, middle - side * 0.8, color)
	surface.quad(middle - side * 0.8, middle + side * 0.8, tip + side * 0.15, tip - side * 0.15, color)


static func _hash01(x: int, z: int) -> float:
	var value := sin(float(x) * 12.9898 + float(z) * 78.233) * 43758.5453
	return value - floorf(value)
