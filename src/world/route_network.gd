class_name RouteNetwork
extends RefCounted
## Red de rutas del mundo (F4.1): carga el contrato y la red derivada de OSM,
## valida el grafo y ofrece rutas, alternativas, proyección y elevación.
##
## Es un objeto de datos, no un autoload. F4.2 lo usará desde el WorldDirector
## para construir terreno y sectores; F4.1 no crea streaming ni colisión.

const CONTRACT_PATH := "res://data/schemas/world_routes.json"
const NETWORK_PATH := "res://data/content/world/route_network.json"
const MANIFEST_PATH := "res://data/content/world/route_network.manifest.json"
const CREDITS_PATH := "res://CREDITS.md"
const LOCALIZATION_PATH := "res://localization/strings.csv"

enum LoadState { UNLOADED, LOADING, LOADED, DEGRADED, FAILED }

var state: int = LoadState.UNLOADED
var contract: Dictionary = {}
var network: Dictionary = {}
var manifest: Dictionary = {}
var nodes: Dictionary = {}
var edges: Dictionary = {}
var routes: Dictionary = {}
var adjacency: Dictionary = {}
var region_hubs: Dictionary = {}
var errors: Array[String] = []
var warnings: Array[String] = []

var _max_speed_kph := 100.0


func load_all() -> bool:
	state = LoadState.LOADING
	errors.clear()
	warnings.clear()
	contract = _read_json(CONTRACT_PATH)
	network = _read_json(NETWORK_PATH)
	manifest = _read_json(MANIFEST_PATH)
	if contract.is_empty() or network.is_empty() or manifest.is_empty():
		_fail("No se pudieron leer contrato, red o manifiesto")
		return false

	if str(contract.get("contract_id", "")) != "world.routes":
		_fail("contract_id inválido")
		return false
	if str(network.get("contract_id", "")) != "world.routes":
		_fail("la red no pertenece al contrato world.routes")
		return false
	if str(network.get("world_id", "")) != str(contract.get("world_id", "")):
		_fail("world_id distinto entre contrato y red")
		return false
	if not _verify_manifest_hash():
		_fail("sha256 del artefacto no coincide con el manifiesto")
		return false

	for node in network.get("nodes", []):
		var node_id := str(node.get("id", ""))
		if node_id.is_empty() or nodes.has(node_id):
			_fail("nodo duplicado o sin ID: %s" % node_id)
			return false
		nodes[node_id] = node
		adjacency[node_id] = []
	for edge in network.get("edges", []):
		var edge_id := str(edge.get("id", ""))
		if edge_id.is_empty() or edges.has(edge_id):
			_fail("arista duplicada o sin ID: %s" % edge_id)
			return false
		var from_id := str(edge.get("from", ""))
		var to_id := str(edge.get("to", ""))
		if not nodes.has(from_id) or not nodes.has(to_id) or from_id == to_id:
			_fail("arista %s con extremos inválidos" % edge_id)
			return false
		edges[edge_id] = edge
		var cost := float(edge.get("cost", 0.0))
		var distance := float(edge.get("distance_m", 0.0))
		adjacency[from_id].append({"to": to_id, "edge_id": edge_id, "cost": cost, "distance": distance})
		adjacency[to_id].append({"to": from_id, "edge_id": edge_id, "cost": cost, "distance": distance})
		if not _validate_edge_shape(edge):
			_fail("geometría inválida en %s" % edge_id)
			return false

	if not _validate_degrees():
		_fail("grado de nodo incoherente")
		return false
	if not _validate_connectivity():
		_fail("la red no es conexa")
		return false

	for region in network.get("regions", []):
		var hub := str(region.get("hub_node", ""))
		if not nodes.has(hub):
			_fail("hub inexistente %s" % hub)
			return false
		region_hubs[str(region.get("id", ""))] = hub

	for route in network.get("routes", []):
		var route_id := str(route.get("id", ""))
		if route_id.is_empty():
			_fail("ruta sin ID")
			return false
		if not routes.has(route_id):
			routes[route_id] = []
		routes[route_id].append(route)
	for route_id in routes:
		routes[route_id].sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.get("alternative_index", 0)) < int(b.get("alternative_index", 0))
		)
	if not _validate_routes():
		_fail("ruta o alternativa inválida")
		return false
	if not _validate_attribution():
		_fail("atribución ODbL incompleta")
		return false

	var budgets: Dictionary = contract.get("budgets", {})
	if nodes.size() > int(budgets.get("max_nodes", 0)):
		_fail("la red excede max_nodes")
		return false
	if edges.size() > int(budgets.get("max_edges", 0)):
		_fail("la red excede max_edges")
		return false

	var speed := 100.0
	var classes: Dictionary = contract.get("highway_classes", {})
	for class_name_key in classes:
		speed = maxf(speed, float(classes[class_name_key].get("design_speed_kph", 0.0)))
	_max_speed_kph = speed
	state = LoadState.LOADED
	return true


func state_name() -> String:
	return ["unloaded", "loading", "loaded", "degraded", "failed"][state]


func attribution() -> Dictionary:
	return network.get("attribution", {})


func region_hub(region_id: String) -> String:
	return str(region_hubs.get(region_id, ""))


func project_geo(geo: Vector2) -> Vector2:
	## geo = Vector2(latitud, longitud). Devuelve Vector2(x, z) en metros de juego.
	var projection: Dictionary = contract.get("projection", {})
	var origin: Array = projection.get("origin", [0.0, 0.0])
	var scale := float(projection.get("world_scale", 1.0))
	var x := (geo.y - float(origin[1])) * float(projection.get("meters_per_degree_lon", 1.0)) * scale
	var z := -(geo.x - float(origin[0])) * float(projection.get("meters_per_degree_lat", 1.0)) * scale
	return Vector2(x, z)


func unproject_game(game: Vector2) -> Vector2:
	var projection: Dictionary = contract.get("projection", {})
	var origin: Array = projection.get("origin", [0.0, 0.0])
	var scale := float(projection.get("world_scale", 1.0))
	var lon := game.x / (float(projection.get("meters_per_degree_lon", 1.0)) * scale) + float(origin[1])
	var lat := -game.y / (float(projection.get("meters_per_degree_lat", 1.0)) * scale) + float(origin[0])
	return Vector2(lat, lon)


func node_geo(node_id: String) -> Vector2:
	var node: Dictionary = nodes.get(node_id, {})
	var geo: Array = node.get("geo", [0.0, 0.0])
	return Vector2(float(geo[0]), float(geo[1]))


func node_game_position(node_id: String) -> Vector3:
	var node: Dictionary = nodes.get(node_id, {})
	var game: Array = node.get("game_m", [0.0, 0.0])
	var elevation := float(node.get("elevation_m", 0.0)) * float(contract.get("projection", {}).get("vertical_scale", 1.0))
	return Vector3(float(game[0]), elevation, float(game[1]))


func nearest_node(geo: Vector2) -> String:
	var best := ""
	var best_distance := INF
	for node_id in nodes:
		var candidate := node_geo(node_id)
		var distance := candidate.distance_squared_to(geo)
		if distance < best_distance:
			best_distance = distance
			best = node_id
	return best


func find_path(from_id: String, to_id: String, blocked_edges: Array = []) -> Dictionary:
	if not nodes.has(from_id) or not nodes.has(to_id):
		return {"found": false}
	var blocked := {}
	for edge_id in blocked_edges:
		blocked[str(edge_id)] = true
	var open: Array = [{"id": from_id, "f": 0.0}]
	var best: Dictionary = {from_id: 0.0}
	var previous: Dictionary = {}
	var visited: Dictionary = {}
	while not open.is_empty():
		open.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["f"]) < float(b["f"]))
		var current: Dictionary = open.pop_front()
		var current_id := str(current["id"])
		if visited.has(current_id):
			continue
		visited[current_id] = true
		if current_id == to_id:
			break
		for link in adjacency.get(current_id, []):
			var edge_id := str(link["edge_id"])
			if blocked.has(edge_id):
				continue
			var next_id := str(link["to"])
			var cost := float(link["cost"])
			var candidate := float(best.get(current_id, INF)) + cost
			if candidate < float(best.get(next_id, INF)):
				best[next_id] = candidate
				previous[next_id] = {"from": current_id, "edge": edge_id}
				var heuristic := _heuristic_seconds(next_id, to_id)
				open.append({"id": next_id, "f": candidate + heuristic})
	if not previous.has(to_id) and from_id != to_id:
		return {"found": false}
	var node_ids: Array[String] = [to_id]
	var edge_ids: Array[String] = []
	var cursor := to_id
	while cursor != from_id:
		var step: Dictionary = previous.get(cursor, {})
		if step.is_empty():
			return {"found": false}
		edge_ids.push_front(str(step["edge"]))
		cursor = str(step["from"])
		node_ids.push_front(cursor)
	return _path_summary(node_ids, edge_ids)


func find_alternatives(from_id: String, to_id: String, max_routes: int = 2) -> Array:
	var main := find_path(from_id, to_id)
	if not bool(main.get("found", false)):
		return []
	var alternatives: Array = []
	var main_edges: Array = main.get("edge_ids", [])
	var penalty := {}
	for edge_id in main_edges:
		penalty[str(edge_id)] = 3.0
	var seen := {}
	seen[_path_key(main)] = true
	for _attempt in range(max_routes * 3):
		var candidate := _find_path_with_penalty(from_id, to_id, penalty)
		if not bool(candidate.get("found", false)):
			break
		var key := _path_key(candidate)
		if seen.has(key):
			for edge_id in candidate.get("edge_ids", []):
				penalty[str(edge_id)] = float(penalty.get(str(edge_id), 1.0)) * 3.0
			continue
		seen[key] = true
		var overlap := _overlap_ratio(candidate.get("edge_ids", []), main_edges)
		var detour := float(candidate.get("distance_m", 0.0)) / maxf(1.0, float(main.get("distance_m", 0.0)))
		candidate["overlap_ratio_vs_main"] = overlap
		candidate["detour_ratio_vs_main"] = detour
		alternatives.append(candidate)
		for edge_id in candidate.get("edge_ids", []):
			penalty[str(edge_id)] = float(penalty.get(str(edge_id), 1.0)) * 3.0
		if alternatives.size() >= max_routes:
			break
	alternatives.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["detour_ratio_vs_main"]) < float(b["detour_ratio_vs_main"])
	)
	return alternatives


func get_route(route_id: String) -> Array:
	return routes.get(route_id, [])


func get_main_route(route_id: String) -> Dictionary:
	for route in routes.get(route_id, []):
		if str(route.get("kind", "")) == "main":
			return route
	return {}


func get_route_alternatives(route_id: String) -> Array:
	var result: Array = []
	for route in routes.get(route_id, []):
		if str(route.get("kind", "")) == "alternative":
			result.append(route)
	return result


func edge_world_points(edge_id: String) -> PackedVector3Array:
	var edge: Dictionary = edges.get(edge_id, {})
	var points := PackedVector3Array()
	if edge.is_empty():
		return points
	var vertical_scale := float(contract.get("projection", {}).get("vertical_scale", 1.0))
	for point in edge.get("shape", []):
		var game := project_geo(Vector2(float(point[0]), float(point[1])))
		points.append(Vector3(game.x, float(point[2]) * vertical_scale, game.y))
	return points


func total_main_distance_m() -> float:
	var total := 0.0
	for route_id in routes:
		var main := get_main_route(route_id)
		total += float(main.get("distance_m", 0.0))
	return total


func _find_path_with_penalty(from_id: String, to_id: String, penalty: Dictionary) -> Dictionary:
	if not nodes.has(from_id) or not nodes.has(to_id):
		return {"found": false}
	var open: Array = [{"id": from_id, "f": 0.0}]
	var best: Dictionary = {from_id: 0.0}
	var previous: Dictionary = {}
	var visited: Dictionary = {}
	while not open.is_empty():
		open.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["f"]) < float(b["f"]))
		var current: Dictionary = open.pop_front()
		var current_id := str(current["id"])
		if visited.has(current_id):
			continue
		visited[current_id] = true
		if current_id == to_id:
			break
		for link in adjacency.get(current_id, []):
			var edge_id := str(link["edge_id"])
			var multiplier := float(penalty.get(edge_id, 1.0))
			var next_id := str(link["to"])
			var candidate := float(best.get(current_id, INF)) + float(link["cost"]) * multiplier
			if candidate < float(best.get(next_id, INF)):
				best[next_id] = candidate
				previous[next_id] = {"from": current_id, "edge": edge_id}
				open.append({"id": next_id, "f": candidate + _heuristic_seconds(next_id, to_id)})
	if not previous.has(to_id) and from_id != to_id:
		return {"found": false}
	var node_ids: Array[String] = [to_id]
	var edge_ids: Array[String] = []
	var cursor := to_id
	while cursor != from_id:
		var step: Dictionary = previous.get(cursor, {})
		if step.is_empty():
			return {"found": false}
		edge_ids.push_front(str(step["edge"]))
		cursor = str(step["from"])
		node_ids.push_front(cursor)
	return _path_summary(node_ids, edge_ids)


func _path_summary(node_ids: Array[String], edge_ids: Array[String]) -> Dictionary:
	var distance := 0.0
	var travel_time := 0.0
	var ascent := 0.0
	var descent := 0.0
	for edge_id in edge_ids:
		var edge: Dictionary = edges.get(edge_id, {})
		distance += float(edge.get("distance_m", 0.0))
		travel_time += float(edge.get("travel_time_s", 0.0))
		ascent += float(edge.get("ascent_m", 0.0))
		descent += float(edge.get("descent_m", 0.0))
	return {
		"found": true,
		"node_ids": node_ids,
		"edge_ids": edge_ids,
		"distance_m": distance,
		"travel_time_s": travel_time,
		"ascent_m": ascent,
		"descent_m": descent,
	}


func _overlap_ratio(candidate_edges: Array, reference_edges: Array) -> float:
	var reference := {}
	for edge_id in reference_edges:
		reference[str(edge_id)] = true
	var shared := 0.0
	var total := 0.0
	for edge_id in candidate_edges:
		var edge: Dictionary = edges.get(str(edge_id), {})
		var distance := float(edge.get("distance_m", 0.0))
		total += distance
		if reference.has(str(edge_id)):
			shared += distance
	return shared / total if total > 0.0 else 1.0


func _path_key(path: Dictionary) -> String:
	return "|".join(path.get("edge_ids", []))


func _heuristic_seconds(node_id: String, goal_id: String) -> float:
	var from_geo := node_geo(node_id)
	var goal_geo := node_geo(goal_id)
	var distance := from_geo.distance_to(goal_geo) * 111_000.0
	return distance / (_max_speed_kph / 3.6)


func _validate_edge_shape(edge: Dictionary) -> bool:
	var shape: Array = edge.get("shape", [])
	if shape.size() < 2:
		return false
	var distance := float(edge.get("distance_m", 0.0))
	if distance <= 0.0:
		return false
	for point in shape:
		if point.size() < 3:
			return false
		if float(point[2]) < -50.0 or float(point[2]) > 5000.0:
			return false
	return true


func _validate_degrees() -> bool:
	var degree := {}
	for node_id in nodes:
		degree[node_id] = 0
	for edge in edges.values():
		degree[str(edge["from"])] = int(degree[str(edge["from"])]) + 1
		degree[str(edge["to"])] = int(degree[str(edge["to"])]) + 1
	for node_id in nodes:
		if int(nodes[node_id].get("degree", -1)) != int(degree[node_id]):
			return false
		if int(degree[node_id]) < 1:
			return false
	return true


func _validate_connectivity() -> bool:
	var fallback := str(contract.get("anti_softlock", {}).get("fallback_hub", ""))
	if not nodes.has(fallback):
		return false
	var seen := {fallback: true}
	var stack: Array[String] = [fallback]
	while not stack.is_empty():
		var current: String = stack.pop_back()
		for link in adjacency.get(current, []):
			var next_id := str(link["to"])
			if not seen.has(next_id):
				seen[next_id] = true
				stack.append(next_id)
	return seen.size() == nodes.size()


func _validate_routes() -> bool:
	var requirements: Dictionary = {}
	for requirement in contract.get("routes", []):
		requirements[str(requirement.get("id", ""))] = requirement
	for route_id in requirements:
		if not routes.has(route_id):
			return false
		var main := get_main_route(route_id)
		if main.is_empty():
			return false
		var alternatives := get_route_alternatives(route_id)
		var requirement: Dictionary = requirements[route_id]
		if alternatives.size() < int(requirement.get("min_alternatives", 0)):
			return false
		if alternatives.size() > int(requirement.get("max_alternatives", 0)):
			return false
		for route in [main] + alternatives:
			var node_ids: Array = route.get("node_ids", [])
			var edge_ids: Array = route.get("edge_ids", [])
			if edge_ids.is_empty() or node_ids.size() != edge_ids.size() + 1:
				return false
			var distance := 0.0
			for edge_id in edge_ids:
				var edge: Dictionary = edges.get(str(edge_id), {})
				if edge.is_empty():
					return false
				distance += float(edge.get("distance_m", 0.0))
			if absf(distance - float(route.get("distance_m", 0.0))) > maxf(2.0, distance * 0.02):
				return false
			if str(route.get("from", "")) != str(node_ids[0]) or str(route.get("to", "")) != str(node_ids[-1]):
				return false
		for alternative in alternatives:
			var overlap := float(alternative.get("overlap_ratio_vs_main", 1.0))
			if overlap > float(requirement.get("max_overlap_ratio", 1.0)) + 0.02:
				return false
			var detour := float(alternative.get("distance_m", 0.0)) / maxf(1.0, float(main.get("distance_m", 0.0)))
			if detour > float(requirement.get("max_detour_ratio", 1.0)) + 0.02:
				return false
	return true


func _validate_attribution() -> bool:
	var attribution: Dictionary = network.get("attribution", {})
	if str(attribution.get("license", "")) != "ODbL 1.0":
		return false
	if str(attribution.get("dataset", "")) != "OpenStreetMap":
		return false
	if not str(attribution.get("copyright_url", "")).contains("openstreetmap.org"):
		return false
	var key := str(attribution.get("in_game_key", ""))
	if key.is_empty():
		return false
	if FileAccess.file_exists(CREDITS_PATH):
		var credits := FileAccess.get_file_as_string(CREDITS_PATH)
		if not credits.contains("OpenStreetMap") or not credits.contains("ODbL"):
			return false
	if FileAccess.file_exists(LOCALIZATION_PATH):
		var csv := FileAccess.get_file_as_string(LOCALIZATION_PATH)
		if not csv.contains("%s," % key):
			return false
	return true


func _verify_manifest_hash() -> bool:
	var bytes := FileAccess.get_file_as_bytes(NETWORK_PATH)
	if bytes.is_empty():
		return false
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return false
	context.update(bytes)
	var digest := context.finish().hex_encode()
	var artifacts: Array = manifest.get("artifacts", [])
	if artifacts.is_empty():
		return false
	return str(artifacts[0].get("sha256", "")) == digest


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


func _fail(message: String) -> void:
	errors.append(message)
	state = LoadState.FAILED
