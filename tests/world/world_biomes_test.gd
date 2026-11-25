extends Node3D
## Prueba de kits de biomas, POIs, mobiliario vial y presets de superficie (F4.3).
##
## Ejecutar:
##   .\tools\dev\world_biomes_test.cmd
##
## Valida el contrato world.biomes, la especificación y los manifiestos de los
## kits bpy (LOD0/1/2 con triángulos decrecientes y hashes correctos), las
## mallas procedurales de props, el decorado por sector con su presupuesto, la
## colocación de POIs fuera de la vía, el agua visual, la nieve de altura, la
## carga threaded de kits (máx. 2 solicitudes, 0 load() síncrono) y que la
## reaparición segura de F4.2 sigue operativa.

const EXPECTED_VERSION := "0.4.2"
const BIOMES_PATH := "res://data/schemas/world_biomes.json"
const KITS_SPEC_PATH := "res://data/world/kits_spec.json"
const STREAMING_PATH := "res://data/schemas/world_streaming.json"
const ROUTES_PATH := "res://data/schemas/world_routes.json"
const MANIFEST_DIR := "res://assets/manifests"
const KIT_DIR := "res://assets/generated/world"
const ODBL_PATH := "res://licenses/ODbL-1.0.txt"
const LOCALIZATION_PATH := "res://localization/strings.csv"
const SCENE_PATH := "res://scenes/world/WorldTerrain.tscn"
const WATER_SHADER_PATH := "res://shaders/world_water.gdshader"

var _passed := 0
var _failed: Array[String] = []
var _biomes: Dictionary = {}
var _kits_spec: Dictionary = {}
var _streaming: Dictionary = {}


func _ready() -> void:
	print("[BIOMES] Inicio de la prueba de kits de biomas y POIs F4.3")
	await get_tree().process_frame
	_test_version()
	_biomes = _read_json(BIOMES_PATH)
	_kits_spec = _read_json(KITS_SPEC_PATH)
	_streaming = _read_json(STREAMING_PATH)
	_test_files()
	_test_contract()
	_test_kits_spec()
	_test_manifests()
	_test_prop_meshes()
	await _test_runtime()
	await _test_decor_and_water()
	_finish()


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("[BIOMES] OK   %s" % label)
	else:
		_failed.append(label)
		print("[BIOMES] FAIL %s" % label)


func _test_version() -> void:
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	_check(version == EXPECTED_VERSION, "versión del proyecto %s" % EXPECTED_VERSION)
	_check(FileAccess.get_file_as_string("res://VERSION").strip_edges() == EXPECTED_VERSION, "VERSION coincide")


func _test_files() -> void:
	for path in [
		BIOMES_PATH, KITS_SPEC_PATH, STREAMING_PATH, ROUTES_PATH,
		ODBL_PATH, LOCALIZATION_PATH, WATER_SHADER_PATH, SCENE_PATH,
	]:
		_check(FileAccess.file_exists(path), "archivo presente %s" % path)
	_check(FileAccess.get_file_as_string(ODBL_PATH).to_lower().contains("odbl"), "texto ODbL presente")
	var csv := FileAccess.get_file_as_string(LOCALIZATION_PATH)
	for key in [
		"BIOME_COSTA_NAME", "BIOME_MONTANA_NAME", "BIOME_LLANOS_NAME", "BIOME_SELVA_NAME",
		"BIOME_DELTA_NAME", "BIOME_INDUSTRIAL_NAME", "POI_GASOLINERA_NAME", "POI_MOTEL_NAME",
		"POI_PEAJE_NAME", "POI_CRUCE_NAME", "ROAD_SIGN_NAME", "ROAD_POLE_NAME", "ROAD_BILLBOARD_NAME",
	]:
		_check(csv.contains("%s," % key), "clave de localización %s" % key)
	for kit_file in [
		"kit_gasolinera", "kit_motel", "kit_peaje", "kit_cruce", "kit_sign", "kit_pole", "kit_billboard",
	]:
		_check(FileAccess.file_exists("%s/%s_lod0.glb" % [KIT_DIR, kit_file]), "kit generado %s_lod0" % kit_file)
		_check(FileAccess.file_exists("%s/%s_lod1.glb" % [KIT_DIR, kit_file]), "kit generado %s_lod1" % kit_file)
		_check(FileAccess.file_exists("%s/%s_lod2.glb" % [KIT_DIR, kit_file]), "kit generado %s_lod2" % kit_file)
		_check(FileAccess.file_exists("%s/%s_anchor.glb" % [KIT_DIR, kit_file]), "ancla generada %s" % kit_file)
		_check(FileAccess.file_exists("%s/%s.manifest.json" % [MANIFEST_DIR, kit_file]), "manifiesto %s" % kit_file)


func _test_contract() -> void:
	_check(int(_biomes.get("schema_version", 0)) == 1, "contrato schema_version 1")
	_check(str(_biomes.get("contract_id", "")) == "world.biomes", "contract_id world.biomes")
	_check(str(_biomes.get("world_id", "")) == "venezuela.1999", "world_id venezuela.1999")
	_check(str(_biomes.get("status", "")) == "active", "contrato activo")
	var biome_list: Array = _biomes.get("biomes", [])
	_check(biome_list.size() == 6, "seis biomas declarados")
	var ids := {}
	for biome in biome_list:
		ids[str(biome.get("id", ""))] = true
		var presets: Dictionary = biome.get("surface_presets", {})
		_check(presets.has("water") and presets.has("dust") and presets.has("snow"), "presets agua/polvo/nieve en %s" % biome.get("id", ""))
		for decor_entry in biome.get("decor", []):
			_check(float(decor_entry.get("min_lateral_m", 0.0)) >= 5.6, "decor de %s fuera de la vía" % biome.get("id", ""))
		for roadside_entry in biome.get("roadside", []):
			_check(float(roadside_entry.get("min_lateral_m", 0.0)) >= 5.6, "mobiliario de %s fuera de la vía" % biome.get("id", ""))
	_check(ids.size() == 6, "IDs de bioma únicos")
	var region_map: Dictionary = _biomes.get("region_biome_map", {})
	_check(region_map.size() == 6, "mapa región→bioma completo")
	var map_ok := true
	for region in region_map:
		if not ids.has(str(region_map[region])):
			map_ok = false
	_check(map_ok, "region_biome_map apunta a biomas válidos")
	var selection: Dictionary = _biomes.get("biome_selection", {})
	_check(str(selection.get("method", "")) == "nearest_region_hub", "selección por hub más cercano")
	_check(bool(selection.get("deterministic", false)), "selección determinista")

	var snow_biomes := 0
	var water_biomes := 0
	for biome in biome_list:
		var presets: Dictionary = biome.get("surface_presets", {})
		if bool(presets.get("snow", {}).get("enabled", false)):
			snow_biomes += 1
		if bool(presets.get("water", {}).get("enabled", false)):
			water_biomes += 1
	_check(snow_biomes == 1, "solo la montaña declara nieve de altura")
	_check(water_biomes >= 4, "agua visual en la mayoría de biomas")

	var props: Array = _biomes.get("props", [])
	_check(props.size() == 8, "ocho props procedurales")
	for prop in props:
		var chain: Array = prop.get("lods", [])
		var ok := chain.size() == 3
		if ok:
			var budgets := []
			for lod in chain:
				budgets.append(int(lod.get("max_triangles", 0)))
			ok = budgets[0] > budgets[1] and budgets[1] > budgets[2]
		_check(ok, "cadena LOD decreciente en %s" % prop.get("id", ""))

	var pois: Array = _biomes.get("pois", [])
	_check(pois.size() >= 7, "POIs y mobiliario declarados")
	for poi in pois:
		var chain: Array = poi.get("lods", [])
		var ok := chain.size() == 3
		if ok:
			var budgets := []
			for lod in chain:
				budgets.append(int(lod.get("max_triangles", 0)))
			ok = budgets[0] > budgets[1] and budgets[1] > budgets[2]
		_check(ok, "cadena LOD decreciente en %s" % poi.get("id", ""))
		_check(bool(poi.get("brands_forbidden", false)), "sin marcas reales en %s" % poi.get("id", ""))
		_check(float(poi.get("placement", {}).get("min_clear_road_m", 0.0)) >= 5.6, "%s respeta la vía" % poi.get("id", ""))
		var biomes_ok := true
		for biome_id in poi.get("biomes", []):
			if not ids.has(str(biome_id)):
				biomes_ok = false
		_check(biomes_ok, "biomas válidos en %s" % poi.get("id", ""))

	var budgets: Dictionary = _biomes.get("budgets", {})
	_check(int(budgets.get("max_sector_triangles_total", 0)) == 3000, "3.000 triángulos por sector")
	_check(int(budgets.get("terrain_triangles_per_sector", 0)) == 2048, "2.048 de terreno por sector")
	_check(int(budgets.get("max_decor_triangles_per_sector", 0)) <= 952, "decor dentro del margen de F4.2")
	_check(
		int(budgets.get("terrain_triangles_per_sector", 0))
		+ int(budgets.get("road_triangles_per_sector_observed_f42", 0))
		+ int(budgets.get("max_decor_triangles_per_sector", 0))
		<= int(budgets.get("max_sector_triangles_total", 0)),
		"terreno + vía + decor ≤ 3.000"
	)
	_check(int(budgets.get("max_kit_concurrent_load_requests", 0)) == 2, "2 solicitudes máximas de kits")
	_check(bool(budgets.get("kit_sync_load_forbidden", false)), "load() síncrono prohibido en kits")
	_check(int(budgets.get("max_sector_builds_per_frame", 0)) == 1, "una construcción de sector por frame")
	_check(absf(float(budgets.get("pss_budget_mb", 0.0)) - 1228.8) < 0.1, "PSS 1.228,8 MB")
	_check(
		int(budgets.get("max_poi_nodes_per_route", 0)) * 3 * 3200 <= int(budgets.get("max_visible_poi_triangles_pc", 1)) * 10,
		"presupuesto de POIs coherente"
	)

	var rules: Dictionary = _biomes.get("placement_rules", {})
	_check(bool(rules.get("never_on_road", false)), "los kits nunca invaden la vía")
	_check(float(rules.get("min_clear_road_m", 0.0)) >= 5.6, "despeje mínimo de vía")
	_check(float(rules.get("respawn_corridor_protected_m", 0.0)) > 0.0, "corredor de reaparición protegido")

	var attribution: Dictionary = _biomes.get("attribution", {})
	_check(str(attribution.get("license", "")) == "ODbL 1.0", "licencia ODbL 1.0")
	_check(str(attribution.get("in_game_key", "")) == "CREDITS_OSM", "atribución CREDITS_OSM")
	_check(bool(attribution.get("share_alike", false)), "share-alike conservado")
	_check(str(attribution.get("kits_license", "")).contains("CC BY-NC-SA"), "licencia de kits declarada")
	var softlock: Dictionary = _biomes.get("anti_softlock", {})
	_check(bool(softlock.get("respawn_on_network", false)), "reaparición sobre la red")
	_check(not bool(softlock.get("props_block_road", true)), "el decorado no bloquea la vía")
	var qa: Dictionary = _biomes.get("qa", {})
	_check(int(qa.get("expected_kit_families", 0)) == 7, "siete familias de kit esperadas")
	_check(int(qa.get("expected_biomes", 0)) == 6, "seis biomas esperados")
	_check(str(qa.get("android_route", "")) == "slice,cabin,world", "ruta Android de QA")


func _test_kits_spec() -> void:
	_check(_kits_spec.get("asset_id", "") != "", "kits_spec con asset_id")
	var materials: Dictionary = _kits_spec.get("materials", {})
	_check(materials.size() >= 6, "materiales de kit declarados")
	var anchor_names := []
	for anchor in _kits_spec.get("rig_anchor", {}).get("anchors", []):
		anchor_names.append(str(anchor.get("id", "")))
	_check(anchor_names.has("anchor_root"), "ancla anchor_root declarada")
	var kits: Array = _kits_spec.get("kits", [])
	_check(kits.size() == 7, "siete familias de kit en kits_spec")
	for kit in kits:
		var chain: Array = kit.get("lods", [])
		var ok := chain.size() == 3
		if ok:
			var budgets := []
			for lod in chain:
				budgets.append(int(lod.get("max_triangles", 0)))
			ok = budgets[0] > budgets[1] and budgets[1] > budgets[2]
		_check(ok, "LOD decreciente en kits_spec %s" % kit.get("kit_id", ""))
		var materials_ok := true
		var lod_names := []
		for lod in chain:
			lod_names.append(str(lod.get("id", "")))
		if lod_names != ["lod0", "lod1", "lod2"]:
			materials_ok = false
		for part in kit.get("parts", []):
			if not materials.has(str(part.get("material", ""))):
				materials_ok = false
		_check(materials_ok, "piezas y materiales válidos en %s" % kit.get("kit_id", ""))


func _test_manifests() -> void:
	for kit_file in ["kit_gasolinera", "kit_motel", "kit_peaje", "kit_cruce", "kit_sign", "kit_pole", "kit_billboard"]:
		var manifest := _read_json("%s/%s.manifest.json" % [MANIFEST_DIR, kit_file])
		_check(not manifest.is_empty(), "manifiesto legible %s" % kit_file)
		if manifest.is_empty():
			continue
		_check(str(manifest.get("license", "")).contains("CC BY-NC-SA"), "licencia en manifiesto %s" % kit_file)
		var generator: Dictionary = manifest.get("generator", {})
		var script_path := str(generator.get("script", ""))
		_check(
			FileAccess.file_exists("res://%s" % script_path)
			and _sha256_file("res://%s" % script_path) == str(generator.get("script_sha256", "")),
			"hash del script reproducible en %s" % kit_file
		)
		var lods_seen := []
		var decreasing := true
		var previous := 1 << 30
		var integrity := true
		for output in manifest.get("outputs", []):
			var file := str(output.get("file", ""))
			if not FileAccess.file_exists("res://%s" % file):
				integrity = false
				continue
			if _sha256_file("res://%s" % file) != str(output.get("sha256", "")):
				integrity = false
			if str(output.get("kind", "")) == "mesh_lod":
				lods_seen.append(int(output.get("lod", -1)))
				var triangles := int(output.get("triangles", 0))
				if triangles >= previous or triangles > int(output.get("max_triangles", 0)):
					decreasing = false
				previous = triangles
		_check(integrity, "hashes de salidas correctos en %s" % kit_file)
		_check(lods_seen == [0, 1, 2], "LOD0/1/2 en %s" % kit_file)
		_check(decreasing, "triángulos decrecientes en %s" % kit_file)


func _test_prop_meshes() -> void:
	var library := WorldKitLibrary.new()
	_check(library.load_contract(), "contrato world.biomes carga en runtime")
	if not library.load_contract():
		return
	var all_ok := true
	var within := true
	for prop in _biomes.get("props", []):
		var prop_id := str(prop.get("id", ""))
		var budgets := []
		for lod in prop.get("lods", []):
			budgets.append(int(lod.get("max_triangles", 0)))
		var counts := []
		for lod_index in range(3):
			var mesh := library.prop_mesh(prop_id, lod_index)
			if mesh == null or mesh.get_surface_count() == 0:
				all_ok = false
				counts.append(-1)
				continue
			counts.append(mesh.get_faces().size() / 3)
		if not (counts[0] > counts[1] and counts[1] > counts[2] and counts[2] > 0):
			all_ok = false
			print("[BIOMES] PROP_COUNTS %s -> %s budgets %s" % [prop_id, counts, budgets])
		for lod_index in range(3):
			if counts[lod_index] > budgets[lod_index]:
				within = false
	_check(all_ok, "props procedurales con tres LODs decrecientes")
	_check(within, "props dentro de sus presupuestos de triángulos")


func _test_runtime() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	_check(packed != null, "escena WorldTerrain carga")
	if packed == null:
		return
	var scene := packed.instantiate() as WorldDirector
	_check(scene != null, "escena instancia WorldDirector")
	if scene == null:
		return
	scene.autotour = false
	add_child(scene)
	var ready := await _wait_until(func() -> bool: return scene.is_world_ready(), 30000)
	_check(ready, "mundo listo con kits cargados")
	if not ready:
		scene.queue_free()
		return
	var streamer := scene.get_node("SectorStreamer") as WorldSectorStreamer
	_check(streamer != null, "SectorStreamer presente")
	if streamer == null:
		scene.queue_free()
		return
	var library := scene.kit_library
	var kit_stats: Dictionary = library.stats()
	_check(int(kit_stats.get("loaded", 0)) == int(kit_stats.get("total", 0)), "los 21 kits GLB cargan")
	_check(int(kit_stats.get("sync_load_calls", -1)) == 0, "cero load() síncrono de kits")
	_check(int(kit_stats.get("max_concurrent_seen", 99)) <= 2, "máximo dos solicitudes de kits")
	_check(int(kit_stats.get("kit_errors", -1)) == 0, "sin errores de carga de kits")
	var snapshot := scene.streaming_snapshot()
	_check(int(snapshot.get("sync_load_calls", -1)) == 0, "cero load() síncrono de sectores")
	_check(int(snapshot.get("max_concurrent_requests_seen", 99)) <= 2, "dos solicitudes máximas de sectores")
	_check(int(snapshot.get("sector_errors", -1)) == 0, "sin errores de sector")

	var poi_stats: Dictionary = snapshot.get("pois", {})
	_check(int(poi_stats.get("poi_nodes", 0)) > 0, "POIs colocados en la ruta activa")
	_check(int(poi_stats.get("poi_nodes", 0)) <= 72, "POIs dentro del tope por ruta")
	_check(int(poi_stats.get("errors", -1)) == 0, "sin errores de POI")

	# Colocación de POIs fuera de la vía y con tres variantes de LOD.
	var poi_manager := scene.get_node_or_null("PoiManager") as PoiManager
	_check(poi_manager != null, "PoiManager presente")
	var pois_clear := true
	var lods_ok := true
	var min_clear := INF
	if poi_manager != null:
		for child in poi_manager.get_children():
			var variants := 0
			for sub in child.get_children():
				if sub is Node3D and _has_mesh(sub):
					variants += 1
			if variants < 3:
				lods_ok = false
			var clearance := _distance_to_route(scene, child.position)
			min_clear = minf(min_clear, clearance)
			if clearance < 5.0:
				pois_clear = false
	_check(lods_ok, "cada POI tiene tres variantes de LOD")
	_check(pois_clear, "POIs despejados de la vía (≥ 5 m)")
	_check(min_clear == INF or min_clear >= 5.0, "despeje mínimo medido %.1f m" % min_clear)

	var respawn := scene.safe_respawn_point(scene.current_route_id(), scene.current_progress_m() + 3000.0)
	_check(bool(respawn.get("found", false)), "reaparición segura sigue operativa con POIs")

	# Auditoría del presupuesto de decorado por sector cargado (tras churn de
	# streaming para ejercitar descargas).
	scene.seek(minf(scene.current_progress_m() + 8000.0, scene.current_route_total_m() - 100.0))
	var churn_deadline := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < churn_deadline and not (streamer.is_idle() and streamer.loaded_sector_count() >= 3):
		await get_tree().process_frame
	var churned := streamer.is_idle() and streamer.loaded_sector_count() >= 3
	_check(churned, "ventana estable tras avanzar con decorado")
	var decor_cap := int(_biomes.get("budgets", {}).get("max_decor_triangles_per_sector", 0))
	var decor_ok := true
	var total_decor := 0
	var audited := 0
	for key in streamer.loaded_keys():
		var node := streamer.loaded_node(key)
		if node == null:
			continue
		var decor := node.get_node_or_null("Decor")
		if decor == null:
			continue
		audited += 1
		var tris := _decor_triangles(decor)
		total_decor += tris
		if tris > decor_cap + 2:
			decor_ok = false
			print("[BIOMES] DECOR_OVER %s -> %d (cap %d)" % [key, tris, decor_cap])
	_check(decor_ok, "decor por sector dentro de %d triángulos" % decor_cap)
	_check(audited > 0, "sectores con decorado auditados")
	_check(
		total_decor <= (decor_cap + 2) * streamer.loaded_sector_count(),
		"decor total %d coherente con %d sectores" % [total_decor, streamer.loaded_sector_count()]
	)
	_check(
		int(streamer.stats().get("loaded_decor_triangles", 0)) <= (decor_cap + 2) * streamer.loaded_sector_count(),
		"contador de decor del streamer coherente"
	)

	scene.queue_free()
	await get_tree().process_frame


func _decor_triangles(node: Node) -> int:
	var total := 0
	if node is MultiMeshInstance3D:
		var multi := (node as MultiMeshInstance3D).multimesh
		if multi != null and multi.mesh != null:
			var mesh := multi.mesh as ArrayMesh
			if mesh != null:
				var per_instance := 0
				for surface in range(mesh.get_surface_count()):
					var arrays := mesh.surface_get_arrays(surface)
					var indices_value: Variant = arrays[Mesh.ARRAY_INDEX] if arrays.size() > Mesh.ARRAY_INDEX else null
					if indices_value is PackedInt32Array and not (indices_value as PackedInt32Array).is_empty():
						per_instance += (indices_value as PackedInt32Array).size() / 3
					else:
						var vertices_value: Variant = arrays[Mesh.ARRAY_VERTEX]
						if vertices_value is PackedVector3Array:
							per_instance += (vertices_value as PackedVector3Array).size() / 3
				total += per_instance * multi.instance_count
	elif node is MeshInstance3D:
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
		total += _decor_triangles(child)
	return total


func _test_decor_and_water() -> void:
	var library := WorldKitLibrary.new()
	if not library.load_contract():
		_check(false, "contrato cargable para el decorado sintético")
		return
	var hubs := {}
	var routes := _read_json(ROUTES_PATH)
	for region in routes.get("regions", []):
		hubs[str(region.get("id", ""))] = Vector3.ZERO
	library.set_region_hubs(hubs)
	var biome: Dictionary = {}
	for entry in _biomes.get("biomes", []):
		if str(entry.get("id", "")) == "biome.llanos":
			biome = entry
	_check(not biome.is_empty(), "bioma de llanos disponible para la prueba")

	var data := _synthetic_sector()
	var root := Node3D.new()
	add_child(root)
	var start := Time.get_ticks_usec()
	var report := WorldSectorBuilder.build_sector_decor(root, data, biome, library, 0, library.decor_budget())
	var elapsed_ms := float(Time.get_ticks_usec() - start) / 1000.0
	_check(int(report.get("instances", 0)) > 0, "decorado sintético genera instancias")
	_check(int(report.get("decor_triangles", 0)) <= library.decor_budget(), "decor dentro de 620 triángulos")
	_check(bool(report.get("water", false)), "agua visual generada en el bioma que la declara")
	_check(elapsed_ms < 12.0, "construcción de decorado < 12 ms (%.2f ms)" % elapsed_ms)

	var decor := root.get_node_or_null("Decor")
	_check(decor != null, "nodo Decor presente")
	if decor != null:
		var water := decor.get_node_or_null("Water")
		_check(water != null, "quad de agua presente")
		if water is MeshInstance3D:
			var mesh := (water as MeshInstance3D).mesh as ArrayMesh
			_check(mesh != null and mesh.get_faces().size() / 3 == 2, "quad de agua con dos triángulos")
			_check((water as MeshInstance3D).material_override is ShaderMaterial, "material de agua con shader propio")

		# El decorado nunca invade la cinta de vía (anti-softlock).
		var clear := true
		for child in decor.get_children():
			if child is MultiMeshInstance3D:
				var multi := (child as MultiMeshInstance3D).multimesh
				if multi == null:
					continue
				for index in range(multi.instance_count):
					var position := multi.get_instance_transform(index).origin
					if absf(position.z - (data.origin_z + 400.0)) < 5.6:
						clear = false
		_check(clear, "decorado fuera de la cinta de vía")
	root.queue_free()

	# Nieve de altura: el terreno de montaña aclara por encima de la línea de nieve.
	var montana := {}
	for entry in _biomes.get("biomes", []):
		if str(entry.get("id", "")) == "biome.montana":
			montana = entry
	var snowy := _synthetic_sector()
	var plain := _synthetic_sector()
	for index in range(snowy.heights.size()):
		snowy.heights[index] = 200.0
		plain.heights[index] = 200.0
	snowy.height_min_m = 190.0
	snowy.height_max_m = 210.0
	plain.height_min_m = 190.0
	plain.height_max_m = 210.0
	var snowy_mesh := WorldSectorBuilder.build_terrain_mesh(snowy, StandardMaterial3D.new(), montana)
	var plain_mesh := WorldSectorBuilder.build_terrain_mesh(plain, StandardMaterial3D.new(), {})
	var snowy_colors := _first_vertex_colors(snowy_mesh)
	var plain_colors := _first_vertex_colors(plain_mesh)
	var brighter := true
	if snowy_colors.size() > 0 and plain_colors.size() > 0:
		for index in range(mini(snowy_colors.size(), plain_colors.size())):
			if snowy_colors[index].get_luminance() <= plain_colors[index].get_luminance():
				brighter = false
				break
	_check(brighter, "la nieve de altura aclara el terreno alto")


func _synthetic_sector() -> WorldSectorData:
	var data := WorldSectorData.new()
	data.format_version = 1
	data.sector_x = 4
	data.sector_z = -2
	data.sector_size_m = 800.0
	data.grid_resolution = 33
	data.grid_spacing_m = 25.0
	data.origin_x = 3200.0
	data.origin_z = -1600.0
	data.heights.resize(33 * 33)
	for z_index in range(33):
		for x_index in range(33):
			data.heights[z_index * 33 + x_index] = float(z_index) * 0.6 + float(x_index) * 0.12
	data.height_min_m = 0.0
	data.height_max_m = 24.0
	data.terrain_triangle_count = 2048
	data.road_length_m = 800.0
	var vertices := PackedVector3Array()
	var z_center := data.origin_z + 400.0
	for step in range(8):
		var x0 := data.origin_x + float(step) * 100.0
		var x1 := x0 + 100.0
		vertices.append(Vector3(x0, 0.4, z_center - 5.8))
		vertices.append(Vector3(x0, 0.4, z_center + 5.8))
		vertices.append(Vector3(x1, 0.4, z_center - 5.8))
		vertices.append(Vector3(x1, 0.4, z_center - 5.8))
		vertices.append(Vector3(x0, 0.4, z_center + 5.8))
		vertices.append(Vector3(x1, 0.4, z_center + 5.8))
	data.road_vertices = vertices
	data.road_triangle_count = 16
	return data


func _first_vertex_colors(mesh: ArrayMesh) -> PackedColorArray:
	if mesh == null or mesh.get_surface_count() == 0:
		return PackedColorArray()
	var arrays := mesh.surface_get_arrays(0)
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays.size() > Mesh.ARRAY_COLOR and arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
	return colors


func _distance_to_route(scene: WorldDirector, position: Vector3) -> float:
	var best := INF
	var data: Dictionary = scene._route_for(scene.current_route_id())
	var points: PackedVector3Array = data.get("points", PackedVector3Array())
	for point in points:
		best = minf(best, Vector2(position.x - point.x, position.z - point.z).length())
	return best


func _has_mesh(node: Node) -> bool:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		return true
	for child in node.get_children():
		if _has_mesh(child):
			return true
	return false


func _raycast_down(position: Vector3) -> Dictionary:
	var world := get_world_3d()
	if world == null:
		return {}
	var query := PhysicsRayQueryParameters3D.create(position + Vector3.UP * 50.0, position + Vector3.DOWN * 50.0, 1)
	var result := world.direct_space_state.intersect_ray(query)
	return result if result is Dictionary else {}


func _wait_until(condition: Callable, timeout_ms: int) -> bool:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < timeout_ms:
		if bool(condition.call()):
			return true
		await get_tree().process_frame
	return bool(condition.call())


func _sha256_file(path: String) -> String:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return ""
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _finish() -> void:
	print("[BIOMES] RESULTADO %d/%d comprobaciones OK" % [_passed, _passed + _failed.size()])
	for label in _failed:
		print("[BIOMES] FALLO %s" % label)
	if _failed.is_empty():
		print("[BIOMES] SUPERADO kits de biomas y POIs")
		get_tree().quit(0)
	else:
		print("[BIOMES] FALLIDO %d comprobaciones" % _failed.size())
		get_tree().quit(1)
