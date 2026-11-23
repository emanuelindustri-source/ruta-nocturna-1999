extends Node
## Smoke test de servicios base, del bloqueo y del exterior del Esteem (F3.1).
## Sin mecánicas de conducción.
##
## Ejecutar:
##   .\tools\dev\smoke_test.cmd
## El proceso devuelve 0 solo si todos los servicios base responden y el
## bloqueo (F1.3) y el exterior definitivo (F3.1) conservan LOD0/LOD1/LOD2,
## manifiesto y ancla de rig.

const EXPECTED_VERSION := "0.3.0"
const AUTOLOADS := [
	"EventBus",
	"HardwareProfiler",
	"SettingsManager",
	"LocalizationManager",
	"GameState",
	"SaveManager",
	"AudioDirector",
	"WeatherManager",
	"UpdateChecker",
	"CrashReporter",
	"SceneRouter",
]
const TEST_SLOT := 98

var _passed := 0
var _failed: Array[String] = []


func _ready() -> void:
	print("[SMOKE] Inicio del smoke test de servicios base")
	await get_tree().process_frame
	await get_tree().process_frame
	_test_autoloads()
	_test_version()
	_test_hardware()
	_test_settings()
	_test_localization()
	_test_event_bus()
	_test_game_state()
	_test_save_manager()
	_test_weather()
	_test_audio()
	_test_update_checker()
	_test_diagnostics_context()
	_test_crash_reporter()
	await _test_creator_qa_menu()
	_test_scene_router()
	await _test_vehicle_blockout()
	await _test_vehicle_exterior()
	await _test_vertical_slice()
	await _test_powertrain()
	_test_gamepad_menu_input()
	_test_export_presets()
	_finish()


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("[SMOKE] OK   %s" % label)
	else:
		_failed.append(label)
		print("[SMOKE] FAIL %s" % label)


func _test_autoloads() -> void:
	for autoload_name in AUTOLOADS:
		_check(get_node_or_null("/root/%s" % autoload_name) != null, "autoload %s" % autoload_name)
	var order: Array[String] = []
	for child in get_tree().root.get_children():
		if AUTOLOADS.has(child.name):
			order.append(str(child.name))
	_check(order == AUTOLOADS, "orden topológico de autoloads")


func _test_version() -> void:
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	_check(version == EXPECTED_VERSION, "versión del proyecto %s" % EXPECTED_VERSION)
	var file_version := FileAccess.get_file_as_string("res://VERSION").strip_edges()
	_check(file_version == EXPECTED_VERSION, "VERSION coincide con project.godot")


func _test_hardware() -> void:
	var info := HardwareProfiler.get_info()
	_check(not info.is_empty(), "perfil de hardware disponible")
	_check(int(info.get("cpu_count", 0)) > 0, "conteo de CPU")
	var profile := HardwareProfiler.get_recommended_profile()
	_check(
		profile in [
			HardwareProfiler.PROFILE_DESKTOP_HIGH,
			HardwareProfiler.PROFILE_DESKTOP_BALANCED,
			HardwareProfiler.PROFILE_MOBILE_HIGH,
			HardwareProfiler.PROFILE_MOBILE_LOW,
		],
		"perfil recomendado válido (%s)" % profile
	)


func _test_settings() -> void:
	_check(typeof(SettingsManager.get_value("audio", "master_volume")) == TYPE_FLOAT, "volumen maestro")
	_check(
		SettingsManager.get_active_quality_profile() in ["low", "medium", "high"],
		"perfil gráfico resuelto (%s)" % SettingsManager.get_active_quality_profile()
	)
	var original := bool(SettingsManager.get_value("qa", "test_mode", false))
	_check(SettingsManager.set_value("qa", "test_mode", true), "escritura de ajustes")
	SettingsManager.load_settings()
	_check(bool(SettingsManager.get_value("qa", "test_mode", false)), "persistencia de ajustes")
	SettingsManager.set_value("qa", "test_mode", original)
	SettingsManager.load_settings()
	_check(
		bool(SettingsManager.get_value("qa", "test_mode", true)) == original,
		"restauración de ajustes"
	)


func _test_localization() -> void:
	var locales := LocalizationManager.get_available_locales()
	_check(locales.size() == 11, "once locales cargados")
	_check(LocalizationManager.has_key("APP_TITLE"), "clave APP_TITLE disponible")
	var original_locale := LocalizationManager.get_locale()
	_check(LocalizationManager.set_locale("en", false), "cambio a inglés")
	_check(tr("UI_CONTINUE") == "Continue", "traducción inglesa de UI_CONTINUE")
	LocalizationManager.set_locale(original_locale, false)
	_check(LocalizationManager.get_locale() == original_locale, "restauración de locale")


func _test_event_bus() -> void:
	var received := {"value": ""}
	var callback := func(section, key, value) -> void:
		received["value"] = "%s/%s/%s" % [section, key, str(value)]
	EventBus.settings_changed.connect(callback, CONNECT_ONE_SHOT)
	EventBus.settings_changed.emit("smoke", "ping", "ok")
	_check(received["value"] == "smoke/ping/ok", "EventBus entrega señales")


func _test_game_state() -> void:
	GameState.start_new_game(false)
	GameState.set_flag("smoke_flag", true)
	GameState.set_humanity(73.5)
	GameState.set_trust("smoke_passenger", 42.0)
	GameState.set_mission("smoke_mission", "stage_a")
	var snapshot := GameState.snapshot()
	_check(int(snapshot.get("snapshot_version", 0)) == 1, "snapshot versionado")
	var snapshot_flags: Dictionary = snapshot.get("flags", {})
	_check(bool(snapshot_flags.get("smoke_flag", false)), "bandera en snapshot")
	_check(absf(float(snapshot.get("humanity", 0.0)) - 73.5) < 0.01, "humanidad en snapshot")
	_check(GameState.has_flag("smoke_flag"), "consulta de bandera")
	GameState.clear_flags()
	_check(not GameState.has_flag("smoke_flag"), "limpieza de banderas")
	GameState.start_new_game(false)


func _test_save_manager() -> void:
	GameState.start_new_game(false)
	GameState.set_flag("smoke_saved_flag", true)
	GameState.set_humanity(61.0)
	var completed := {"slot": -1}
	var save_callback := func(slot, _path) -> void:
		completed["slot"] = slot
	EventBus.save_completed.connect(save_callback, CONNECT_ONE_SHOT)
	_check(SaveManager.save_slot(TEST_SLOT, "smoke"), "guardado base")
	_check(completed["slot"] == TEST_SLOT, "señal save_completed")
	var path := SaveManager.get_slot_path(TEST_SLOT, false)
	_check(FileAccess.file_exists(path), "archivo de guardado creado")
	var envelope: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(envelope is Dictionary, "guardado es JSON")
	if envelope is Dictionary:
		_check(int(envelope.get("save_version", 0)) == 1, "save_version 1")
		_check(not str(envelope.get("checksum", "")).is_empty(), "checksum presente")
		_check(str(envelope.get("game_version", "")) == EXPECTED_VERSION, "game_version en guardado")
	GameState.set_flag("smoke_saved_flag", false)
	GameState.set_humanity(1.0)
	_check(SaveManager.load_slot(TEST_SLOT), "carga base")
	_check(GameState.has_flag("smoke_saved_flag"), "bandera restaurada")
	_check(absf(GameState.humanity - 61.0) < 0.01, "humanidad restaurada")
	_check(SaveManager.delete_slot(TEST_SLOT), "borrado de guardado de prueba")

	# F2.4: fixture de la linea base v0.2.0 (mismas reglas de checksum que
	# SaveManager) cargado en una ranura real.
	var fixture_text := FileAccess.get_file_as_string("res://tests/fixtures/save_v0_2_0.json")
	_check(not fixture_text.is_empty(), "fixture v0.2.0 presente")
	var fixture: Variant = JSON.parse_string(fixture_text)
	_check(fixture is Dictionary, "fixture v0.2.0 es JSON")
	if fixture is Dictionary:
		_check(int(fixture.get("save_version", 0)) == 1, "fixture con save_version 1")
		_check(str(fixture.get("game_version", "")) == "0.2.0", "fixture con game_version 0.2.0")
		var fixture_slot := 97
		var fixture_path := SaveManager.get_slot_path(fixture_slot, false)
		var fixture_file := FileAccess.open(fixture_path, FileAccess.WRITE)
		_check(fixture_file != null, "ranura del fixture escribible")
		if fixture_file != null:
			fixture_file.store_string(fixture_text)
			fixture_file.close()
		GameState.start_new_game(false)
		_check(SaveManager.load_slot(fixture_slot), "carga del fixture v0.2.0 con checksum verificado")
		_check(GameState.chapter == 1 and GameState.region == "carabobo", "estado del fixture aplicado")
		_check(GameState.has_flag("tutorial_done"), "bandera del fixture restaurada")
		_check(absf(GameState.humanity - 61.0) < 0.01, "humanidad del fixture restaurada")
		SaveManager.delete_slot(fixture_slot)

	# F2.4: backup antes de sobrescribir y escritura atomica sin temporales.
	GameState.start_new_game(false)
	GameState.set_flag("smoke_backup_flag", true)
	_check(SaveManager.save_slot(TEST_SLOT, "smoke_backup"), "primer guardado de la linea base")
	_check(SaveManager.save_slot(TEST_SLOT, "smoke_backup_2"), "segundo guardado sobrescribe")
	var backup_path := SaveManager.get_slot_path(TEST_SLOT, false) + ".bak"
	_check(FileAccess.file_exists(backup_path), "backup .bak creado antes de sobrescribir")
	_check(
		not FileAccess.file_exists(SaveManager.get_slot_path(TEST_SLOT, false) + ".tmp"),
		"sin temporal .tmp tras guardar"
	)
	SaveManager.delete_slot(TEST_SLOT)

	# F2.4: una version futura se rechaza sin sobrescribir el archivo.
	var future_slot := 96
	_check(SaveManager.save_slot(future_slot, "smoke_future"), "guardado previo para la prueba")
	var future_path := SaveManager.get_slot_path(future_slot, false)
	var future_envelope: Variant = JSON.parse_string(FileAccess.get_file_as_string(future_path))
	_check(future_envelope is Dictionary, "guardado previo legible")
	if future_envelope is Dictionary:
		future_envelope["save_version"] = 99
		var future_file := FileAccess.open(future_path, FileAccess.WRITE)
		if future_file != null:
			future_file.store_string(JSON.stringify(future_envelope, "\t", true, true) + "\n")
			future_file.close()
		_check(not SaveManager.load_slot(future_slot), "guardado de version futura rechazado")
		_check(not SaveManager.save_slot(future_slot, "smoke_future_overwrite"), "no se sobrescribe version futura")
		var after_attempt: Variant = JSON.parse_string(FileAccess.get_file_as_string(future_path))
		_check(
			after_attempt is Dictionary and int(after_attempt.get("save_version", 0)) == 99,
			"el archivo futuro queda intacto"
		)
	SaveManager.delete_slot(future_slot)
	GameState.start_new_game(false)


func _test_weather() -> void:
	_check(WeatherManager.set_preset("storm", true), "preset de tormenta")
	var storm := WeatherManager.get_state()
	_check(float(storm.get("rain", 0.0)) >= 0.8, "lluvia de tormenta")
	_check(bool(storm.get("lightning", false)), "rayos de tormenta")
	_check(WeatherManager.set_preset("clear", true), "retorno a despejado")
	_check(absf(float(WeatherManager.get_state().get("rain", 1.0))) < 0.01, "lluvia despejada")


func _test_audio() -> void:
	for bus_name in ["Master", "Music", "SFX", "Ambience", "Voice", "UI", "Engine"]:
		_check(AudioDirector.has_bus(bus_name), "bus de audio %s" % bus_name)
	_check(AudioDirector.get_bus_volume("Music") > 0.0, "volumen de música aplicado")


func _test_update_checker() -> void:
	_check(UpdateChecker.is_newer_version("v0.1.1", "v0.1.0"), "comparación de versión mayor")
	_check(not UpdateChecker.is_newer_version("v0.1.0", "v0.1.0"), "misma versión no es nueva")
	_check(UpdateChecker.is_newer_version("v0.2.0", "v0.1.9"), "comparación de minor")
	_check(not UpdateChecker.is_newer_version("basura", "v0.1.0"), "versión inválida rechazada")


func _test_diagnostics_context() -> void:
	EventBus.diagnostics_context_requested.emit()
	var status := CrashReporter.get_status()
	var sections: Array = status.get("context_sections", [])
	for section in [
		"hardware", "settings", "localization", "game_state", "save", "audio", "weather", "update", "scene"
	]:
		_check(sections.has(section), "contexto de diagnóstico: %s" % section)


func _test_crash_reporter() -> void:
	_check(CrashReporter.has_session_marker(), "marcador de sesión activo")
	var previous_report := CrashReporter.get_last_report_text()
	var written := {"path": ""}
	var report_callback := func(path, _reason) -> void:
		written["path"] = path
	EventBus.crash_report_written.connect(report_callback, CONNECT_ONE_SHOT)
	var path := CrashReporter.write_report("smoke_test", {"stack": "no disponible"})
	_check(not path.is_empty(), "reporte de error escrito")
	var report := CrashReporter.get_last_report_text()
	_check(report.begins_with("RUTA NOCTURNA 1999 - REPORTE"), "cabecera del reporte")
	_check(report.contains("smoke_test"), "motivo en el reporte")
	_check(report.contains(EXPECTED_VERSION), "versión en el reporte")
	_check(written["path"] == path, "señal crash_report_written")
	if previous_report.is_empty():
		var directory := DirAccess.open("user://")
		if directory != null:
			directory.remove("ultimo_reporte_error.txt")
	else:
		var file := FileAccess.open(CrashReporter.REPORT_PATH, FileAccess.WRITE)
		if file != null:
			file.store_string(previous_report)
			file.close()


func _test_creator_qa_menu() -> void:
	var packed := load("res://scenes/ui/CreatorQAMenu.tscn") as PackedScene
	_check(packed != null, "escena CreatorQAMenu carga")
	if packed == null:
		return
	var qa_menu := packed.instantiate()
	add_child(qa_menu)
	_check(qa_menu.is_available(), "panel QA disponible en debug")
	_check(not qa_menu.is_open(), "panel QA inicia cerrado")
	_check(qa_menu.get_service_count() == AUTOLOADS.size(), "panel QA detecta once servicios")
	qa_menu.open_menu()
	_check(qa_menu.is_open(), "panel QA se abre")
	qa_menu.close_menu()
	_check(not qa_menu.is_open(), "panel QA se cierra")
	var f12_event := InputEventKey.new()
	f12_event.keycode = KEY_F12
	f12_event.pressed = true
	qa_menu._input(f12_event)
	_check(qa_menu.is_open(), "panel QA se abre con F12")
	qa_menu.close_menu()
	for _tap in range(5):
		qa_menu._register_tap()
	_check(qa_menu.is_open(), "panel QA se abre con cinco toques")
	qa_menu.close_menu()

	# F2.4: QA de reparaciones sobre un tren motriz registrado en su grupo.
	qa_menu.open_menu()
	_check(qa_menu._vehicle_buttons.size() == 6, "seccion de vehiculo con seis acciones")
	_check(qa_menu._vehicle_buttons[0].disabled, "acciones de vehiculo sin tren motriz")
	_check(qa_menu._vehicle_value.text == tr("QA_STATUS_NO_VEHICLE"), "estado sin vehiculo localizado")
	var powertrain := VehiclePowertrain.new()
	powertrain.auto_simulate = false
	add_child(powertrain)
	powertrain.add_to_group("vehicle_powertrain")
	qa_menu._refresh_values()
	_check(not qa_menu._vehicle_buttons[0].disabled, "acciones habilitadas con tren motriz")
	powertrain.set_fan_fault("cooling.fan_fuse", true)
	powertrain.simulate(0.016)
	_check(powertrain.get_warning("fan_fault"), "fallo de ventilador aplicado")
	qa_menu._on_vehicle_action("repair_cooling")
	_check(not powertrain.get_warning("fan_fault"), "reparacion de refrigeracion retira el aviso")
	powertrain.set_fuel_level(4.0)
	qa_menu._on_vehicle_action("low_fuel")
	_check(absf(powertrain.fuel.level_l - 4.0) < 0.01, "combustible bajo fijado por QA")
	qa_menu._on_vehicle_action("refuel")
	_check(powertrain.fuel.level_l > 49.0, "repostaje completo por QA")
	qa_menu._on_vehicle_action("fan_fuse_fault")
	powertrain.simulate(0.016)
	_check(powertrain.get_warning("fan_fault"), "fallo recreado por QA")
	_check(qa_menu._status.text == tr("QA_STATUS_REPAIRED") or qa_menu._status.text.contains("fan_fault"), "estado de QA informado")

	# F2.4: guardado y carga desde el panel QA en la ranura QA (nunca una
	# partida real).
	qa_menu._on_save_slot_pressed()
	_check(FileAccess.file_exists(SaveManager.get_slot_path(0, true)), "guardado QA en la ranura qa/00")
	_check(qa_menu._status.text == tr("QA_STATUS_SAVED"), "estado de guardado localizado")
	qa_menu._on_load_slot_pressed()
	_check(qa_menu._status.text == tr("QA_STATUS_LOADED"), "carga QA exitosa")
	SaveManager.delete_slot(0, true)

	qa_menu.close_menu()
	qa_menu.queue_free()
	powertrain.queue_free()
	await get_tree().process_frame


func _test_scene_router() -> void:
	var current := SceneRouter.get_current_scene_path()
	_check(current.ends_with("SmokeTest.tscn"), "SceneRouter detecta la escena actual")
	_check(not SceneRouter.is_loading(), "SceneRouter sin carga pendiente")
	_check(SceneRouter.can_route_to("res://scenes/boot/Boot.tscn"), "ruta a Boot disponible")


func _count_triangles(node: Node) -> int:
	var total := 0
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		total += (node as MeshInstance3D).mesh.get_faces().size() / 3
	for child in node.get_children():
		total += _count_triangles(child)
	return total


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null


func _test_vehicle_blockout() -> void:
	var manifest_text := FileAccess.get_file_as_string("res://assets/manifests/esteem_blockout.manifest.json")
	_check(not manifest_text.is_empty(), "manifiesto del bloqueo presente")
	var manifest: Variant = JSON.parse_string(manifest_text)
	_check(manifest is Dictionary, "manifiesto del bloqueo es JSON")
	var lod_triangles := {}
	if manifest is Dictionary:
		var outputs: Array = manifest.get("outputs", [])
		_check(outputs.size() == 4, "manifiesto con cuatro salidas generadas")
		for output in outputs:
			if not (output is Dictionary):
				continue
			var relative := str(output.get("file", ""))
			var path := "res://" + relative
			_check(FileAccess.file_exists(path), "salida generada %s" % relative)
			var expected_hash := str(output.get("sha256", ""))
			if not expected_hash.is_empty() and FileAccess.file_exists(path):
				_check(FileAccess.get_sha256(path) == expected_hash, "hash SHA-256 verificado en %s" % relative)
			if str(output.get("kind", "")) == "mesh_lod":
				lod_triangles[int(output.get("lod", -1))] = int(output.get("triangles", 0))
		_check(lod_triangles.has(0) and lod_triangles.has(1) and lod_triangles.has(2), "LOD0/LOD1/LOD2 declarados")
		_check(
			int(lod_triangles.get(0, 0)) > int(lod_triangles.get(1, 0))
				and int(lod_triangles.get(1, 0)) > int(lod_triangles.get(2, 0)),
			"triángulos decrecientes entre LODs en el manifiesto"
		)
	var spec_text := FileAccess.get_file_as_string("res://data/vehicle/blockout_spec.json")
	var spec: Variant = JSON.parse_string(spec_text)
	_check(spec is Dictionary, "spec del bloqueo accesible")
	var packed := load("res://scenes/vehicle/EsteemBlockout.tscn") as PackedScene
	_check(packed != null, "escena EsteemBlockout carga")
	if packed == null:
		return
	var blockout := packed.instantiate()
	add_child(blockout)
	var previous_triangles := 1 << 30
	for lod_index in range(3):
		var lod_node := blockout.get_node_or_null("LOD%d" % lod_index)
		_check(lod_node != null, "nodo LOD%d en la escena" % lod_index)
		if lod_node == null:
			continue
		var triangles := _count_triangles(lod_node)
		_check(triangles > 0, "mallas del LOD%d con triángulos" % lod_index)
		_check(triangles == int(lod_triangles.get(lod_index, -1)), "triángulos del LOD%d coinciden con el manifiesto" % lod_index)
		_check(triangles < previous_triangles, "LOD%d menor que el nivel anterior" % lod_index)
		previous_triangles = triangles
	var anchor := blockout.get_node_or_null("RigAnchor")
	_check(anchor != null, "ancla de rig presente en la escena")
	if anchor != null and spec is Dictionary:
		var skeleton := _find_skeleton(anchor)
		_check(skeleton != null, "Skeleton3D del ancla de rig")
		if skeleton != null:
			var anchors: Array = spec.get("rig_anchor", {}).get("anchors", [])
			var all_found := true
			for entry in anchors:
				if not (entry is Dictionary):
					continue
				var bone_name := str(entry.get("id", ""))
				if skeleton.find_bone(bone_name) == -1:
					all_found = false
					print("[SMOKE]     hueso ausente: %s" % bone_name)
			_check(all_found, "los %d huesos del ancla existen" % anchors.size())
			_check(skeleton.find_bone("anchor_root") != -1, "hueso raíz anchor_root")
	blockout.queue_free()
	await get_tree().process_frame


func _test_vehicle_exterior() -> void:
	var manifest_text := FileAccess.get_file_as_string("res://assets/manifests/esteem_exterior.manifest.json")
	_check(not manifest_text.is_empty(), "manifiesto del exterior presente")
	var manifest: Variant = JSON.parse_string(manifest_text)
	_check(manifest is Dictionary, "manifiesto del exterior es JSON")
	var lod_triangles := {}
	if manifest is Dictionary:
		var outputs: Array = manifest.get("outputs", [])
		_check(outputs.size() == 4, "manifiesto del exterior con cuatro salidas generadas")
		for output in outputs:
			if not (output is Dictionary):
				continue
			var relative := str(output.get("file", ""))
			var path := "res://" + relative
			_check(FileAccess.file_exists(path), "salida generada %s" % relative)
			var expected_hash := str(output.get("sha256", ""))
			if not expected_hash.is_empty() and FileAccess.file_exists(path):
				_check(FileAccess.get_sha256(path) == expected_hash, "hash SHA-256 verificado en %s" % relative)
			if str(output.get("kind", "")) == "mesh_lod":
				lod_triangles[int(output.get("lod", -1))] = int(output.get("triangles", 0))
		_check(lod_triangles.has(0) and lod_triangles.has(1) and lod_triangles.has(2), "exterior con LOD0/LOD1/LOD2 declarados")
		_check(
			int(lod_triangles.get(0, 0)) > int(lod_triangles.get(1, 0))
				and int(lod_triangles.get(1, 0)) > int(lod_triangles.get(2, 0)),
			"triángulos decrecientes entre LODs del exterior"
		)
	var spec_text := FileAccess.get_file_as_string("res://data/vehicle/exterior_spec.json")
	var spec: Variant = JSON.parse_string(spec_text)
	_check(spec is Dictionary, "spec del exterior accesible")
	var packed := load("res://scenes/vehicle/EsteemExterior.tscn") as PackedScene
	_check(packed != null, "escena EsteemExterior carga")
	if packed == null:
		return
	var exterior := packed.instantiate()
	add_child(exterior)
	var previous_triangles := 1 << 30
	for lod_index in range(3):
		var lod_node := exterior.get_node_or_null("LOD%d" % lod_index)
		_check(lod_node != null, "nodo LOD%d en la escena del exterior" % lod_index)
		if lod_node == null:
			continue
		var triangles := _count_triangles(lod_node)
		_check(triangles > 0, "mallas del LOD%d del exterior con triángulos" % lod_index)
		_check(triangles == int(lod_triangles.get(lod_index, -1)), "triángulos del LOD%d del exterior coinciden con el manifiesto" % lod_index)
		_check(triangles < previous_triangles, "LOD%d del exterior menor que el nivel anterior" % lod_index)
		previous_triangles = triangles
		if lod_index == 0:
			_check(triangles <= 120000, "exterior LOD0 dentro del presupuesto móvil (%d)" % triangles)
	var anchor := exterior.get_node_or_null("RigAnchor")
	_check(anchor != null, "ancla de rig presente en la escena del exterior")
	if anchor != null and spec is Dictionary:
		var skeleton := _find_skeleton(anchor)
		_check(skeleton != null, "Skeleton3D del ancla de rig del exterior")
		if skeleton != null:
			var anchors: Array = spec.get("rig_anchor", {}).get("anchors", [])
			var all_found := true
			for entry in anchors:
				if not (entry is Dictionary):
					continue
				var bone_name := str(entry.get("id", ""))
				if skeleton.find_bone(bone_name) == -1:
					all_found = false
					print("[SMOKE]     hueso ausente: %s" % bone_name)
			_check(all_found, "los %d huesos del ancla del exterior existen" % anchors.size())
			_check(skeleton.find_bone("anchor_root") != -1, "hueso raíz anchor_root en el exterior")
	# Los espejos funcionales de F2.4 siguen anclados al nuevo exterior.
	var interaction_text := FileAccess.get_file_as_string("res://data/schemas/cabin_interaction.json")
	var interaction: Variant = JSON.parse_string(interaction_text)
	if interaction is Dictionary and spec is Dictionary:
		var mirror_entries: Array = interaction.get("mirrors", {}).get("entries", [])
		var exterior_anchors: Dictionary = {}
		for entry in spec.get("rig_anchor", {}).get("anchors", []):
			exterior_anchors[str(entry.get("id", ""))] = entry.get("position_m", [])
		var mirrors_anchored := mirror_entries.size() == 3
		for mirror_entry in mirror_entries:
			if not (mirror_entry is Dictionary):
				mirrors_anchored = false
				continue
			if str(mirror_entry.get("kind", "")) != "side":
				continue
			var anchor_id := str(mirror_entry.get("anchor", ""))
			var anchor_position: Array = exterior_anchors.get(anchor_id, [])
			var mirror_position: Array = mirror_entry.get("position_m", [])
			if anchor_position.size() != 3 or mirror_position.size() != 3:
				mirrors_anchored = false
				continue
			for axis in range(3):
				if absf(float(anchor_position[axis]) - float(mirror_position[axis])) > 0.01:
					mirrors_anchored = false
		_check(mirrors_anchored, "espejos laterales de F2.4 anclados sobre el exterior")
		var budget: Dictionary = interaction.get("mirrors", {}).get("budget", {})
		_check(
			int(budget.get("scene_passes", 0)) == 3 and budget.get("counted_in_mobile_budget", false) == true,
			"mirrors.budget respetado por el exterior (3 pasos, dentro del presupuesto móvil)"
		)
	exterior.queue_free()
	await get_tree().process_frame


func _test_vertical_slice() -> void:
	var packed := load("res://scenes/vertical_slice/VerticalSlice.tscn") as PackedScene
	_check(packed != null, "escena VerticalSlice carga")
	if packed == null:
		return
	var slice := packed.instantiate()
	add_child(slice)
	await get_tree().process_frame
	_check(slice.get_node_or_null("Road") != null, "rebanada con carretera gris")
	_check(slice.get_node_or_null("Ground") != null, "rebanada con terreno")
	_check(slice.get_node_or_null("Camera3D") != null, "rebanada con cámara")
	_check(slice.get_node_or_null("EsteemExterior") != null, "rebanada con el exterior del Esteem")
	var dashes := slice.get_node_or_null("LaneDashes")
	_check(dashes != null and dashes.get_child_count() >= 20, "marcas de carril generadas")
	var back_button := slice.get_node_or_null("Overlay/Panel/Margin/VBox/BackButton") as Button
	_check(back_button != null and not back_button.text.is_empty(), "botón de retorno localizado")
	var triangles := _count_triangles(slice)
	_check(triangles > 0 and triangles <= 120000, "triángulos de la rebanada dentro del presupuesto móvil (%d)" % triangles)
	var lod0 := slice.get_node_or_null("EsteemExterior/LOD0") as Node3D
	var lod1 := slice.get_node_or_null("EsteemExterior/LOD1") as Node3D
	var lod2 := slice.get_node_or_null("EsteemExterior/LOD2") as Node3D
	_check(
		lod0 != null and lod0.visible and lod1 != null and not lod1.visible and lod2 != null and not lod2.visible,
		"solo LOD0 visible en la rebanada"
	)
	var has_vehicle_body := _find_first(slice, ["VehicleBody3D", "RigidBody3D", "CharacterBody3D"]) != null
	_check(not has_vehicle_body, "rebanada sin cuerpos de física ni conducción")
	slice.queue_free()
	await get_tree().process_frame

	var boot := load("res://scenes/boot/Boot.tscn") as PackedScene
	_check(boot != null, "escena Boot carga")
	if boot != null:
		var boot_scene := boot.instantiate()
		add_child(boot_scene)
		await get_tree().process_frame
		_check(boot_scene.get_node_or_null("Center/VBox/ViewSlice") is Button, "Boot ofrece acceso a la rebanada")
		boot_scene.queue_free()
		await get_tree().process_frame


func _find_first(node: Node, type_names: Array) -> Node:
	for child in node.get_children():
		for type_name in type_names:
			if child.is_class(type_name):
				return child
		var found := _find_first(child, type_names)
		if found != null:
			return found
	return null


func _test_powertrain() -> void:
	var vp := VehiclePowertrain.new()
	vp.auto_simulate = false
	add_child(vp)
	_check(vp.spec != null and vp.spec.errors.is_empty(), "contrato del tren motriz carga")
	_check(int(vp.spec.integer("engine.displacement_cc")) == 1590, "cilindrada 1590 cc")
	_check(vp.spec.array("transmission.selector_modes") == ["P", "R", "N", "D", "2", "L"], "selector P-R-N-D-2-L")
	_check(vp.start_engine(), "motor arranca en P")
	for _index in range(120):
		vp.simulate(1.0 / 60.0)
	_check(vp.engine.get_state_name() == "idle", "motor en ralentí")
	_check(vp.set_selector("D"), "D engranada")
	vp.set_throttle(0.7)
	for _index in range(900):
		vp.simulate(1.0 / 60.0)
	_check(vp.transmission.gear >= 3, "caja sube a tercera o cuarta")
	_check(vp.speed_mps * 3.6 > 40.0, "vehículo avanza con el motor")
	_check(vp.toggle_overdrive(), "botón O/D conmuta")
	for _index in range(60):
		vp.simulate(1.0 / 60.0)
	_check(not vp.overdrive_enabled and vp.transmission.gear <= 3, "O/D off limita a tercera")
	vp.set_throttle(0.0)
	_check(vp.set_selector("N"), "N seleccionada para prueba de frenos")
	vp.set_speed_kph(100.0)
	vp.set_brake_pedal(1.0)
	var distance := 0.0
	for _index in range(300):
		vp.simulate(1.0 / 60.0)
		distance += absf(vp.speed_mps) / 60.0
	_check(absf(vp.speed_mps) < 0.1 and distance < 60.0, "frenada de 100 km/h controlada")
	vp.set_brake_pedal(0.0)
	vp.set_fuel_level(5.0)
	for _index in range(6):
		vp.simulate(1.0 / 60.0)
	_check(vp.fuel.low_warning, "aviso de combustible bajo")
	_check(vp.set_fan_fault("cooling.fan_fuse", true), "fallo de fusible del ventilador")
	vp.simulate(1.0 / 60.0)
	_check(vp.get_warning("fan_fault"), "aviso de fallo del ventilador")
	_check(vp.repair_component("cooling.fan_fuse"), "reparación del ventilador")
	vp.simulate(1.0 / 60.0)
	_check(not vp.get_warning("fan_fault"), "aviso de fallo se apaga")
	vp.queue_free()
	await get_tree().process_frame


func _test_gamepad_menu_input() -> void:
	# F2.4: los menus (Boot, rebanada, panel QA) navegan con D-Pad/gamepad.
	for action in ["ui_accept", "ui_cancel", "ui_up", "ui_down", "ui_left", "ui_right"]:
		_check(InputMap.has_action(action), "accion de menu %s declarada" % action)
		var gamepad_bound := false
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				gamepad_bound = true
		_check(gamepad_bound, "%s responde a gamepad/D-Pad" % action)


func _test_export_presets() -> void:
	var text := FileAccess.get_file_as_string("res://export_presets.cfg")
	_check(not text.is_empty(), "export_presets.cfg presente")
	_check(text.contains('platform="Windows Desktop"'), "preset de Windows Desktop")
	_check(text.contains('platform="Android"'), "preset de Android")
	_check(text.contains("include_filter=\"localization/*.csv"), "CSV de localización incluido en el export")
	_check(text.contains("build/exports/windows/"), "ruta de export de Windows declarada")
	_check(text.contains("build/exports/android/"), "ruta de export de Android declarada")
	_check(not text.contains("keystore_password"), "sin contraseñas de keystore en los presets")
	_check(str(ProjectSettings.get_setting("application/config/version", "")) == EXPECTED_VERSION, "versión de export %s" % EXPECTED_VERSION)


func _finish() -> void:
	if _failed.is_empty():
		print("[SMOKE] OK %d comprobaciones" % _passed)
		get_tree().quit(0)
		return
	print("[SMOKE] Fallaron %d de %d comprobaciones:" % [_failed.size(), _passed + _failed.size()])
	for failure in _failed:
		print("[SMOKE]   - %s" % failure)
	print("[SMOKE] FAIL")
	get_tree().quit(1)
