extends Node
## Prueba de la red de rutas del mundo (F4.1).
##
## Verifica el contrato, el artefacto OSM, el manifiesto ODbL, la conectividad,
## las rutas principales y alternativas, la elevación y el grafo runtime.
##
## Ejecutar:
##   .\tools\dev\world_routes_test.cmd

const EXPECTED_VERSION := "0.4.1"
const NETWORK_SCRIPT := "res://src/world/route_network.gd"
const CONTRACT_PATH := "res://data/schemas/world_routes.json"
const NETWORK_PATH := "res://data/content/world/route_network.json"
const MANIFEST_PATH := "res://data/content/world/route_network.manifest.json"
const CREDITS_PATH := "res://CREDITS.md"
const LICENSE_PATH := "res://licenses/ODbL-1.0.txt"
const LOCALIZATION_PATH := "res://localization/strings.csv"

var _passed := 0
var _failed: Array[String] = []
var _network


func _ready() -> void:
	print("[WORLD] Inicio de la prueba de red de rutas")
	await get_tree().process_frame
	_test_version()
	_test_files()
	_test_contract_and_manifest()
	_network = load(NETWORK_SCRIPT).new()
	var loaded: bool = _network.load_all()
	_check(loaded, "carga y validación de la red")
	if not loaded:
		for error in _network.errors:
			print("[WORLD] ERROR DE CARGA: %s" % error)
		_finish()
		return
	_test_graph()
	_test_edges()
	_test_routes_contract()
	_test_runtime_routing()
	_test_projection()
	_test_attribution()
	_finish()


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("[WORLD] OK   %s" % label)
	else:
		_failed.append(label)
		print("[WORLD] FAIL %s" % label)


func _test_version() -> void:
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	_check(version == EXPECTED_VERSION, "versión del proyecto %s" % EXPECTED_VERSION)
	_check(
		FileAccess.get_file_as_string("res://VERSION").strip_edges() == EXPECTED_VERSION,
		"VERSION coincide"
	)


func _test_files() -> void:
	for path in [CONTRACT_PATH, NETWORK_PATH, MANIFEST_PATH, CREDITS_PATH, LICENSE_PATH, LOCALIZATION_PATH]:
		_check(FileAccess.file_exists(path), "archivo presente %s" % path)
	_check(FileAccess.get_file_as_bytes(NETWORK_PATH).size() > 10_000, "red con contenido suficiente")
	var license := FileAccess.get_file_as_string(LICENSE_PATH)
	_check(license.contains("Open Database License") or license.contains("ODbL"), "texto ODbL presente")


func _test_contract_and_manifest() -> void:
	var contract := _read_json(CONTRACT_PATH)
	var manifest := _read_json(MANIFEST_PATH)
	_check(int(contract.get("schema_version", 0)) == 1, "contrato schema_version 1")
	_check(str(contract.get("contract_id", "")) == "world.routes", "contract_id world.routes")
	_check(str(contract.get("world_id", "")) == "venezuela.1999", "world_id venezuela.1999")
	_check(str(contract.get("status", "")) == "active", "contrato activo")
	_check(contract.get("regions", []).size() == 6, "seis regiones")
	_check(contract.get("routes", []).size() == 6, "seis rutas obligatorias")
	_check(contract.get("highway_classes", {}).size() == 4, "cuatro clases de vía")
	_check(str(manifest.get("license", "")) == "ODbL-1.0", "manifiesto ODbL-1.0")
	_check(str(manifest.get("contract_id", "")) == "world.routes", "manifiesto contract_id")
	_check(not manifest.get("sources", []).is_empty(), "manifiesto con fuentes OSM")
	_check(int(manifest.get("dem", {}).get("tile_count", 0)) > 0, "manifiesto con teselas DEM")
	var network := _read_json(NETWORK_PATH)
	var artifacts: Array = manifest.get("artifacts", [])
	_check(artifacts.size() == 1, "manifiesto con un artefacto")
	if artifacts.size() == 1:
		_check(str(artifacts[0].get("path", "")) == "data/content/world/route_network.json", "ruta del artefacto")
		_check(int(artifacts[0].get("bytes", 0)) == FileAccess.get_file_as_bytes(NETWORK_PATH).size(), "tamaño del artefacto")
	_check(str(network.get("source", {}).get("license", "")) == "ODbL 1.0", "red bajo ODbL 1.0")
	_check(str(network.get("source", {}).get("copyright", "")).contains("OpenStreetMap"), "copyright OSM")
	_check(not str(network.get("source", {}).get("osm_base_timestamp", "")).is_empty(), "timestamp OSM")
	_check(int(network.get("stats", {}).get("hub_count", 0)) == 6, "seis hubs en la red")
	_check(int(network.get("stats", {}).get("main_route_count", 0)) == 6, "seis caminos principales")
	_check(int(network.get("stats", {}).get("alternative_count", 0)) >= 6, "alternativas presentes")


func _test_graph() -> void:
	var contract := _read_json(CONTRACT_PATH)
	var budgets: Dictionary = contract.get("budgets", {})
	_check(_network.nodes.size() <= int(budgets.get("max_nodes", 0)), "presupuesto de nodos")
	_check(_network.edges.size() <= int(budgets.get("max_edges", 0)), "presupuesto de aristas")
	_check(_network.nodes.size() > 10 and _network.edges.size() > 10, "grafo no trivial")
	var hubs: Dictionary = _network.region_hubs
	_check(hubs.size() == 6, "seis hubs cargados")
	for region_id in ["carabobo", "falcon", "merida", "llanos", "amazonas", "delta"]:
		_check(hubs.has(region_id) and _network.nodes.has(_network.region_hub(region_id)), "hub de %s" % region_id)
	var fallback := str(contract.get("anti_softlock", {}).get("fallback_hub", ""))
	_check(_network.nodes.has(fallback), "hub de recuperación existe")
	_check(_network.state_name() == "loaded", "estado loaded")
	_check(_network.total_main_distance_m() > 1_000_000.0, "distancia principal total")
	var stats: Dictionary = _network.network.get("stats", {})
	_check(
		absf(_network.total_main_distance_m() / 1000.0 - float(stats.get("total_main_distance_km", 0.0))) < 1.0,
		"distancia total coincide con stats"
	)


func _test_edges() -> void:
	var contract := _read_json(CONTRACT_PATH)
	var max_grade := float(contract.get("graph_rules", {}).get("max_grade_pct", 100.0))
	var max_length := float(contract.get("graph_rules", {}).get("max_edge_length_m", 1e9))
	var bad_distance := 0
	var bad_shape := 0
	var bad_grade := 0
	var bad_length := 0
	for edge_id in _network.edges:
		var edge: Dictionary = _network.edges[edge_id]
		var shape: Array = edge.get("shape", [])
		if shape.size() < 2:
			bad_shape += 1
			continue
		var measured := 0.0
		for index in range(shape.size() - 1):
			measured += _hav(Vector2(shape[index][0], shape[index][1]), Vector2(shape[index + 1][0], shape[index + 1][1]))
		var declared := float(edge.get("distance_m", 0.0))
		if absf(measured - declared) > maxf(2.0, declared * 0.02):
			bad_distance += 1
		if declared > max_length:
			bad_length += 1
		if float(edge.get("max_grade_pct", 0.0)) > max_grade + 0.5:
			bad_grade += 1
		var from_geo: Vector2 = _network.node_geo(str(edge["from"]))
		var to_geo: Vector2 = _network.node_geo(str(edge["to"]))
		var first := Vector2(shape[0][0], shape[0][1])
		var last := Vector2(shape[-1][0], shape[-1][1])
		if _hav(from_geo, first) > 10.0 or _hav(to_geo, last) > 10.0:
			bad_shape += 1
	_check(bad_shape == 0, "todas las aristas tienen forma coherente")
	_check(bad_distance == 0, "distancias de arista coinciden con la forma")
	_check(bad_grade == 0, "pendientes dentro del contrato")
	_check(bad_length == 0, "longitudes dentro del contrato")


func _test_routes_contract() -> void:
	var contract := _read_json(CONTRACT_PATH)
	for requirement in contract.get("routes", []):
		var route_id := str(requirement.get("id", ""))
		var routes: Array = _network.get_route(route_id)
		var main: Dictionary = _network.get_main_route(route_id)
		var alternatives: Array = _network.get_route_alternatives(route_id)
		_check(not routes.is_empty(), "ruta %s presente" % route_id)
		_check(not main.is_empty(), "ruta %s con principal" % route_id)
		_check(alternatives.size() >= int(requirement.get("min_alternatives", 0)), "ruta %s con alternativas" % route_id)
		_check(alternatives.size() <= int(requirement.get("max_alternatives", 0)), "ruta %s sin exceso de alternativas" % route_id)
		if main.is_empty():
			continue
		_check(
			absf(_route_distance(main) - float(main.get("distance_m", 0.0))) < maxf(2.0, float(main.get("distance_m", 1.0)) * 0.02),
			"ruta %s: distancia del principal" % route_id
		)
		for alternative in alternatives:
			var index := int(alternative.get("alternative_index", -1))
			_check(index > 0, "ruta %s alternativa con índice" % route_id)
			_check(
				float(alternative.get("overlap_ratio_vs_main", 1.0)) <= float(requirement.get("max_overlap_ratio", 1.0)) + 0.02,
				"ruta %s alternativa %d: solape" % [route_id, index]
			)
			var detour := float(alternative.get("distance_m", 0.0)) / maxf(1.0, float(main.get("distance_m", 1.0)))
			_check(
				detour <= float(requirement.get("max_detour_ratio", 1.0)) + 0.02,
				"ruta %s alternativa %d: desvío" % [route_id, index]
			)


func _test_runtime_routing() -> void:
	var from_hub: String = _network.region_hub("carabobo")
	var to_hub: String = _network.region_hub("falcon")
	var path: Dictionary = _network.find_path(from_hub, to_hub)
	_check(bool(path.get("found", false)), "A* carabobo → falcon")
	if bool(path.get("found", false)):
		_check(path.get("node_ids", []).size() == path.get("edge_ids", []).size() + 1, "A* devuelve cadena coherente")
		_check(float(path.get("distance_m", 0.0)) > 100_000.0, "A* devuelve una ruta larga")
		_check(_path_is_continuous(path), "A* con aristas continuas")
	var main: Dictionary = _network.get_main_route("route.carabobo_falcon")
	_check(
		absf(float(path.get("distance_m", 0.0)) - float(main.get("distance_m", 0.0))) < float(main.get("distance_m", 1.0)) * 0.05,
		"A* coincide con el principal dentro del 5 %"
	)
	var alternatives: Array = _network.find_alternatives(from_hub, _network.region_hub("merida"), 2)
	_check(alternatives.size() >= 1, "A* con alternativas")
	for alternative in alternatives:
		_check(bool(alternative.get("found", false)), "alternativa encontrada")
		_check(float(alternative.get("overlap_ratio_vs_main", 1.0)) < 1.0, "alternativa no idéntica")
		_check(_path_is_continuous(alternative), "alternativa continua")
	var blocked_edges: Array = []
	if not path.get("edge_ids", []).is_empty():
		blocked_edges.append(str(path["edge_ids"][0]))
	var blocked: Dictionary = _network.find_path(from_hub, to_hub, blocked_edges)
	_check(blocked.has("found"), "bloqueo de arista evaluado")
	if bool(blocked.get("found", false)):
		_check(not blocked.get("edge_ids", []).has(blocked_edges[0]) or blocked_edges.is_empty(), "bloqueo evita la arista")


func _test_projection() -> void:
	var geo: Vector2 = _network.node_geo("hub_carabobo")
	var game: Vector2 = _network.project_geo(geo)
	var roundtrip: Vector2 = _network.unproject_game(game)
	_check(roundtrip.distance_to(geo) < 0.0002, "proyección de ida y vuelta")
	_check(
		absf(game.x - float(_network.nodes["hub_carabobo"]["game_m"][0])) < 2.0
		and absf(game.y - float(_network.nodes["hub_carabobo"]["game_m"][1])) < 2.0,
		"proyección coincide con game_m"
	)
	var position: Vector3 = _network.node_game_position("hub_carabobo")
	_check(position.is_finite(), "posición 3D finita")
	var edge_id := str(_network.get_main_route("route.carabobo_falcon").get("edge_ids", [""])[0])
	var points: PackedVector3Array = _network.edge_world_points(edge_id)
	_check(points.size() == _network.edges[edge_id]["shape"].size(), "arista proyectada a 3D")
	_check(_network.nearest_node(geo) == "hub_carabobo", "nodo más cercano al hub")


func _test_attribution() -> void:
	var attribution: Dictionary = _network.attribution()
	_check(str(attribution.get("license", "")) == "ODbL 1.0", "atribución ODbL")
	_check(str(attribution.get("notice_es", "")).contains("OpenStreetMap"), "aviso es")
	_check(str(attribution.get("notice_en", "")).contains("OpenStreetMap"), "aviso en")
	_check(str(attribution.get("in_game_key", "")) == "CREDITS_OSM", "clave de atribución")
	var csv := FileAccess.get_file_as_string(LOCALIZATION_PATH)
	var lines := csv.split("\n")
	var header := lines[0].split(",")
	var credits_line := ""
	for line in lines:
		if line.begins_with("CREDITS_OSM,"):
			credits_line = line
			break
	_check(not credits_line.is_empty(), "CREDITS_OSM en CSV")
	if not credits_line.is_empty():
		var values := credits_line.split(",")
		_check(values.size() == 12, "CREDITS_OSM con 11 idiomas")
		var empty := 0
		for index in range(1, values.size()):
			if values[index].strip_edges().is_empty():
				empty += 1
		_check(empty == 0, "CREDITS_OSM sin traducciones vacías")
	var credits := FileAccess.get_file_as_string(CREDITS_PATH)
	_check(credits.contains("OpenStreetMap") and credits.contains("ODbL"), "CREDITS.md con ODbL")
	var contract := _read_json(CONTRACT_PATH)
	_check(FileAccess.file_exists(str(contract.get("qa", {}).get("test_scene", ""))), "escena QA declarada existe")
	_check(FileAccess.file_exists(str(contract.get("qa", {}).get("test_command", ""))), "comando QA declarado existe")


func _route_distance(route: Dictionary) -> float:
	var distance := 0.0
	for edge_id in route.get("edge_ids", []):
		distance += float(_network.edges[str(edge_id)].get("distance_m", 0.0))
	return distance


func _path_is_continuous(path: Dictionary) -> bool:
	var node_ids: Array = path.get("node_ids", [])
	var edge_ids: Array = path.get("edge_ids", [])
	if node_ids.size() != edge_ids.size() + 1:
		return false
	for index in range(edge_ids.size()):
		var edge: Dictionary = _network.edges.get(str(edge_ids[index]), {})
		if edge.is_empty():
			return false
		var expected := [str(edge["from"]), str(edge["to"])]
		if not (expected.has(str(node_ids[index])) and expected.has(str(node_ids[index + 1]))):
			return false
	return true


func _hav(a: Vector2, b: Vector2) -> float:
	var lat1 := deg_to_rad(a.x)
	var lat2 := deg_to_rad(b.x)
	var delta_lat := lat2 - lat1
	var delta_lon := deg_to_rad(b.y - a.y)
	var h := sin(delta_lat / 2.0) ** 2 + cos(lat1) * cos(lat2) * sin(delta_lon / 2.0) ** 2
	return 6_371_000.0 * 2.0 * asin(minf(1.0, sqrt(h)))


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _finish() -> void:
	var total := _passed + _failed.size()
	if _failed.is_empty():
		print("[WORLD] OK %d comprobaciones de red de rutas" % _passed)
		get_tree().quit(0)
	else:
		print("[WORLD] FAIL %d de %d comprobaciones" % [_failed.size(), total])
		for label in _failed:
			print("[WORLD] FALLO %s" % label)
		get_tree().quit(1)
