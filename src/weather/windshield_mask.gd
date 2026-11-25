class_name WindshieldMask
extends RefCounted
## Máscara del parabrisas para las gotas de cámara (F4.4 · hallazgo H1).
##
## Proyecta las cuatro esquinas reales del parabrisas (`exterior_spec.json`,
## panel `windshield`) con la cámara activa y devuelve un polígono convexo en
## UV de pantalla. El shader `camera_drops.gdshader` descarta todo píxel fuera de
## ese polígono, de modo que las gotas solo existen sobre el parabrisas visible
## y desaparecen al girar la vista hacia la puerta.
##
## Es geometría derivada: no añade datos OSM ni modifica contratos cerrados.

const MAX_POINTS := 8


## Convierte puntos de pantalla (px) a un casco convexo normalizado en UV.
static func convex_hull_uv(
	screen_points: PackedVector2Array, viewport_size: Vector2, max_points: int = MAX_POINTS
) -> PackedVector2Array:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return PackedVector2Array()
	var points: Array[Vector2] = []
	for point in screen_points:
		if not point.is_finite():
			continue
		points.append(Vector2(point.x / viewport_size.x, point.y / viewport_size.y))
	if points.size() < 3:
		return PackedVector2Array()
	points.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		return a.x < b.x or (is_equal_approx(a.x, b.x) and a.y < b.y)
	)
	var unique: Array[Vector2] = []
	for point in points:
		if unique.is_empty() or unique[unique.size() - 1].distance_to(point) > 0.000001:
			unique.append(point)
	if unique.size() < 3:
		return PackedVector2Array()
	var lower: Array[Vector2] = []
	for point in unique:
		while lower.size() >= 2 and _cross(lower[lower.size() - 2], lower[lower.size() - 1], point) <= 0.0:
			lower.remove_at(lower.size() - 1)
		lower.append(point)
	var upper: Array[Vector2] = []
	for index in range(unique.size() - 1, -1, -1):
		var point := unique[index]
		while upper.size() >= 2 and _cross(upper[upper.size() - 2], upper[upper.size() - 1], point) <= 0.0:
			upper.remove_at(upper.size() - 1)
		upper.append(point)
	lower.remove_at(lower.size() - 1)
	upper.remove_at(upper.size() - 1)
	var hull := PackedVector2Array()
	hull.append_array(lower)
	hull.append_array(upper)
	if hull.size() > max_points:
		hull.resize(max_points)
	return hull


## Proyecta las cuatro esquinas del panel `windshield` de exterior_spec.json.
static func project_corners(
	camera: Camera3D, frame: Node3D, corners_m: Array
) -> PackedVector2Array:
	var screen := PackedVector2Array()
	if camera == null or frame == null:
		return screen
	for corner in corners_m:
		if not (corner is Array) or corner.size() < 3:
			continue
		var local := Vector3(float(corner[0]), float(corner[1]), float(corner[2]))
		var world := frame.to_global(local)
		if camera.is_position_behind(world):
			continue
		screen.append(camera.unproject_position(world))
	return screen


## Punto dentro de un polígono convexo en UV (misma prueba que el shader).
static func contains_uv(polygon: PackedVector2Array, uv: Vector2) -> bool:
	if polygon.size() < 3:
		return false
	var inside := false
	var count := polygon.size()
	for index in range(count):
		var a := polygon[index]
		var b := polygon[(index + 1) % count]
		if (a.y > uv.y) != (b.y > uv.y):
			var x_cross := (b.x - a.x) * (uv.y - a.y) / (b.y - a.y) + a.x
			if uv.x < x_cross:
				inside = not inside
	return inside


static func _cross(a: Vector2, b: Vector2, c: Vector2) -> float:
	return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
