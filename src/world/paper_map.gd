class_name PaperMap
extends Control
## Mapa de papel de Ruta Nocturna 1999 (F4.4).
##
## Presenta la red comprimida de F4.1 ya cargada por `RouteNetwork`; no descarga,
## no hornea ni versiona datos OSM nuevos. Dibuja la red, las seis rutas
## principales, los hubs de región y la posición actual del tour. La atribución
## ODbL se conserva visible.
##
## Es un Control de escena (no autoload). `WorldDirector` lo crea y lo actualiza.

const PARCHMENT := Color(0.84, 0.78, 0.62, 1.0)
const PARCHMENT_DARK := Color(0.62, 0.55, 0.4, 1.0)
const INK := Color(0.16, 0.12, 0.08, 1.0)
const INK_SOFT := Color(0.32, 0.26, 0.17, 1.0)
const ROUTE_COLOR := Color(0.45, 0.3, 0.16, 0.85)
const ACTIVE_COLOR := Color(0.72, 0.22, 0.12, 1.0)
const GRID_COLOR := Color(0.56, 0.49, 0.35, 0.25)
const LAND_COLOR := Color(0.90, 0.84, 0.68, 1.0)
const COAST_COLOR := Color(0.38, 0.30, 0.18, 0.85)
const MARGIN := 28.0
const HEADER := 46.0
const FOOTER := 54.0

## Silueta esquemática y original de Venezuela (lat, lon) para dar contexto al
## mapa. No es un dato OSM: es un contorno de presentación de ~27 puntos que se
## proyecta con la misma transformación 1:20 de la red. No sustituye a la base
## ODbL ni se usa para navegación.
const COUNTRY_OUTLINE := [
	Vector2(11.85, -71.35), Vector2(11.75, -71.05), Vector2(11.60, -70.60),
	Vector2(11.45, -70.30), Vector2(11.40, -69.90), Vector2(11.10, -69.30),
	Vector2(10.80, -68.60), Vector2(10.60, -68.00), Vector2(10.55, -67.30),
	Vector2(10.60, -66.60), Vector2(10.65, -65.80), Vector2(10.60, -65.00),
	Vector2(10.55, -64.30), Vector2(10.60, -63.60), Vector2(10.70, -62.90),
	Vector2(10.60, -62.30), Vector2(10.20, -61.90), Vector2(10.00, -61.50),
	Vector2(9.60, -61.20), Vector2(9.20, -60.90), Vector2(8.80, -60.70),
	Vector2(8.40, -60.40), Vector2(7.80, -60.20), Vector2(7.20, -60.50),
	Vector2(6.60, -61.00), Vector2(6.00, -61.40), Vector2(5.40, -61.60),
	Vector2(4.80, -61.80), Vector2(4.20, -62.20), Vector2(3.60, -62.80),
	Vector2(3.00, -63.40), Vector2(2.40, -64.00), Vector2(1.80, -64.70),
	Vector2(1.30, -65.40), Vector2(1.10, -66.20), Vector2(1.30, -67.00),
	Vector2(1.80, -67.40), Vector2(2.50, -67.60), Vector2(3.20, -67.80),
	Vector2(3.90, -67.90), Vector2(4.60, -67.80), Vector2(5.30, -67.60),
	Vector2(6.00, -67.50), Vector2(6.20, -68.40), Vector2(6.30, -69.20),
	Vector2(6.20, -70.00), Vector2(7.00, -70.60), Vector2(7.40, -71.20),
	Vector2(7.80, -71.80), Vector2(8.20, -72.30), Vector2(8.60, -72.60),
	Vector2(9.00, -72.80), Vector2(9.50, -73.00), Vector2(10.00, -72.80),
	Vector2(10.50, -72.50), Vector2(11.00, -72.20), Vector2(11.40, -71.80),
	Vector2(11.80, -71.50),
]

var network: RouteNetwork
var routes_contract: Dictionary = {}
var route_id := ""
var world_position := Vector3.ZERO

var _routes: Dictionary = {}
var _edges: Dictionary = {}
var _country := PackedVector2Array()
var _bounds := Rect2()
var _hubs: Dictionary = {}
var _map_rect := Rect2()
var _open := false
var _ready_to_draw := false


func setup(route_network: RouteNetwork, contract: Dictionary) -> bool:
	network = route_network
	routes_contract = contract
	if network == null or network.nodes.is_empty():
		return false
	_routes.clear()
	_edges.clear()
	_hubs.clear()
	var all_points := PackedVector2Array()
	for edge_id in network.edges:
		var points := network.edge_world_points(edge_id)
		if points.size() < 2:
			continue
		var polyline := PackedVector2Array()
		for point in points:
			var flat := Vector2(point.x, point.z)
			polyline.append(flat)
			all_points.append(flat)
		_edges[edge_id] = polyline
	for route_key in network.routes:
		var route := network.get_main_route(str(route_key))
		if route.is_empty():
			continue
		var route_points := _route_polyline(route)
		if route_points.size() >= 2:
			_routes[str(route_key)] = route_points
	for region in network.region_hubs:
		var hub_id := str(network.region_hubs[region])
		if network.nodes.has(hub_id):
			var node: Dictionary = network.nodes[hub_id]
			var game: Array = node.get("game_m", [0.0, 0.0])
			_hubs[region] = Vector2(float(game[0]), float(game[1]))
	if all_points.is_empty():
		return false
	_country = PackedVector2Array()
	for geo in COUNTRY_OUTLINE:
		var game := network.project_geo(geo)
		_country.append(game)
		all_points.append(game)
	_bounds = Rect2(all_points[0], Vector2.ZERO)
	for point in all_points:
		_bounds = _bounds.expand(point)
	_bounds = _bounds.grow(200.0)
	_update_map_rect()
	_ready_to_draw = true
	queue_redraw()
	return true


func _update_map_rect() -> void:
	_map_rect = Rect2(
		Vector2(MARGIN, HEADER),
		Vector2(maxf(1.0, size.x - MARGIN * 2.0), maxf(1.0, size.y - HEADER - FOOTER))
	)


func _route_polyline(route: Dictionary) -> PackedVector2Array:
	var points := PackedVector2Array()
	var edge_ids: Array = route.get("edge_ids", [])
	var node_ids: Array = route.get("node_ids", [])
	for index in range(edge_ids.size()):
		var edge_id := str(edge_ids[index])
		if not _edges.has(edge_id):
			continue
		var segment: PackedVector2Array = _edges[edge_id]
		var expected_from := str(node_ids[index]) if index < node_ids.size() else ""
		if not expected_from.is_empty():
			var edge: Dictionary = network.edges.get(edge_id, {})
			if expected_from != str(edge.get("from", "")):
				var reversed_points := PackedVector2Array()
				for point_index in range(segment.size() - 1, -1, -1):
					reversed_points.append(segment[point_index])
				segment = reversed_points
		for point in segment:
			if points.is_empty() or points[points.size() - 1].distance_to(point) > 0.01:
				points.append(point)
	return points


func set_progress(active_route: String, position: Vector3) -> void:
	route_id = active_route
	world_position = position
	if _open:
		queue_redraw()


func toggle() -> bool:
	if _open:
		close()
	else:
		open()
	return _open


func open() -> void:
	_open = true
	visible = true
	queue_redraw()


func close() -> void:
	_open = false
	visible = false


func is_open() -> bool:
	return _open


func _ready() -> void:
	visible = _open
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if not _ready_to_draw:
		return
	_update_map_rect()
	draw_rect(Rect2(Vector2.ZERO, size), PARCHMENT, true)
	draw_rect(Rect2(Vector2(2.0, 2.0), size - Vector2(4.0, 4.0)), PARCHMENT_DARK, false, 3.0)
	draw_rect(_map_rect, Color(0.45, 0.38, 0.25, 0.45), false, 1.0)
	_draw_grid()
	_draw_country()
	for edge_id in _edges:
		var polyline: PackedVector2Array = _edges[edge_id]
		if polyline.size() < 2:
			continue
		var screen := _project_polyline(polyline)
		draw_polyline(screen, GRID_COLOR if not _edges.has(edge_id) else Color(0.52, 0.42, 0.28, 0.55), 1.0)
	for current_id in _routes:
		var route_points: PackedVector2Array = _routes[current_id]
		var screen := _project_polyline(route_points)
		var active: bool = current_id == route_id
		draw_polyline(screen, ACTIVE_COLOR if active else ROUTE_COLOR, 4.0 if active else 2.0, true)
	for region in _hubs:
		var hub: Vector2 = _to_map(_hubs[region])
		draw_circle(hub, 4.5, INK)
		var label := str(region).to_upper()
		var label_x := hub.x + 6.0
		if label_x > _map_rect.end.x - 64.0:
			label_x = hub.x - 6.0 - float(label.length()) * 7.0
		draw_string(
			ThemeDB.fallback_font, Vector2(label_x, hub.y + 4.0), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, INK_SOFT
		)
	if route_id != "":
		var marker := _to_map(Vector2(world_position.x, world_position.z))
		draw_circle(marker, 6.0, ACTIVE_COLOR)
		draw_circle(marker, 2.5, PARCHMENT)
	_draw_text()


func _draw_grid() -> void:
	for index in range(1, 6):
		var x := _map_rect.position.x + _map_rect.size.x * float(index) / 6.0
		var y := _map_rect.position.y + _map_rect.size.y * float(index) / 6.0
		draw_line(Vector2(x, _map_rect.position.y), Vector2(x, _map_rect.end.y), GRID_COLOR, 1.0)
		draw_line(Vector2(_map_rect.position.x, y), Vector2(_map_rect.end.x, y), GRID_COLOR, 1.0)


func _draw_country() -> void:
	if _country.size() < 3:
		return
	var projected := _project_polyline(_country)
	var indices := Geometry2D.triangulate_polygon(projected)
	for index in range(0, indices.size(), 3):
		draw_colored_polygon(
			PackedVector2Array([
				projected[indices[index]],
				projected[indices[index + 1]],
				projected[indices[index + 2]],
			]),
			LAND_COLOR
		)
	var outline := projected.duplicate()
	outline.append(projected[0])
	draw_polyline(outline, COAST_COLOR, 2.0, true)


func _draw_text() -> void:
	var font := ThemeDB.fallback_font
	var title := tr("MAP_TITLE")
	var subtitle := tr("MAP_SUBTITLE")
	draw_string(font, Vector2(MARGIN, 30.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, INK)
	draw_string(font, Vector2(MARGIN, size.y - 32.0), subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, INK_SOFT)
	draw_string(
		font, Vector2(MARGIN, size.y - 14.0), tr("CREDITS_OSM"),
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, INK_SOFT
	)
	var route_label := tr("MAP_ACTIVE_ROUTE").format({
		"route": route_id.trim_prefix("route.").replace("_", " → ").to_upper()
	})
	draw_string(
		font, Vector2(size.x - MARGIN - 260.0, 30.0), route_label,
		HORIZONTAL_ALIGNMENT_RIGHT, 260.0, 13, INK
	)
	# Rosa de los vientos mínima: norte siempre arriba (z negativo = norte).
	var north := _map_rect.position + Vector2(18.0, 42.0)
	draw_line(north, north + Vector2(0.0, -22.0), INK, 2.0)
	draw_line(north + Vector2(0.0, -22.0), north + Vector2(-5.0, -14.0), INK, 2.0)
	draw_line(north + Vector2(0.0, -22.0), north + Vector2(5.0, -14.0), INK, 2.0)
	draw_string(
		font, north + Vector2(-5.0, -26.0), "N",
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, INK
	)
	# Leyenda mínima: ruta activa, ruta principal y red secundaria.
	var legend := Vector2(size.x - MARGIN - 214.0, size.y - FOOTER - 78.0)
	draw_rect(Rect2(legend - Vector2(12.0, 18.0), Vector2(214.0, 70.0)), Color(PARCHMENT, 0.94), true)
	draw_rect(Rect2(legend - Vector2(12.0, 18.0), Vector2(214.0, 70.0)), Color(0.45, 0.38, 0.25, 0.5), false, 1.0)
	draw_line(legend, legend + Vector2(28.0, 0.0), ACTIVE_COLOR, 4.0)
	draw_string(font, legend + Vector2(36.0, 4.0), tr("MAP_LEGEND_ACTIVE"), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, INK)
	draw_line(legend + Vector2(0.0, 20.0), legend + Vector2(28.0, 20.0), ROUTE_COLOR, 2.0, true)
	draw_string(font, legend + Vector2(36.0, 24.0), tr("MAP_LEGEND_MAIN"), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, INK)
	draw_line(legend + Vector2(0.0, 40.0), legend + Vector2(28.0, 40.0), Color(0.52, 0.42, 0.28, 0.55), 1.0)
	draw_string(font, legend + Vector2(36.0, 44.0), tr("MAP_LEGEND_SECONDARY"), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, INK)


func _project_polyline(points: PackedVector2Array) -> PackedVector2Array:
	var projected := PackedVector2Array()
	for point in points:
		projected.append(_to_map(point))
	return projected


## Proyección pública mundo→papel (pruebas de orientación norte/este).
func project_world(position: Vector3) -> Vector2:
	return _to_map(Vector2(position.x, position.z))


func country_outline() -> PackedVector2Array:
	return _country.duplicate()


func _to_map(point: Vector2) -> Vector2:
	var norm := Vector2(
		(point.x - _bounds.position.x) / maxf(1.0, _bounds.size.x),
		(point.y - _bounds.position.y) / maxf(1.0, _bounds.size.y)
	)
	return Vector2(
		_map_rect.position.x + norm.x * _map_rect.size.x,
		_map_rect.position.y + norm.y * _map_rect.size.y
	)


func get_map_stats() -> Dictionary:
	return {
		"routes": _routes.size(),
		"edges": _edges.size(),
		"hubs": _hubs.size(),
		"country_points": _country.size(),
		"open": _open,
		"bounds": _bounds,
		"active_route": route_id,
		"credit": tr("CREDITS_OSM"),
	}
