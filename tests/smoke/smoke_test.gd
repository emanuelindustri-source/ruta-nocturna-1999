extends Node
## Smoke test de la Fase 1.2. Sin mecánicas de conducción.
##
## Ejecutar:
##   .\tools\dev\smoke_test.cmd
## El proceso devuelve 0 solo si todos los servicios base responden.

const EXPECTED_VERSION := "0.1.1"
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
	qa_menu.queue_free()
	await get_tree().process_frame


func _test_scene_router() -> void:
	var current := SceneRouter.get_current_scene_path()
	_check(current.ends_with("SmokeTest.tscn"), "SceneRouter detecta la escena actual")
	_check(not SceneRouter.is_loading(), "SceneRouter sin carga pendiente")
	_check(SceneRouter.can_route_to("res://scenes/boot/Boot.tscn"), "ruta a Boot disponible")


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
