extends CanvasLayer
## Panel secreto de creador para QA.
##
## Se abre con F12 o cinco toques en la esquina superior izquierda. Todas sus
## acciones usan APIs del juego: nunca editan archivos ni mutan nodos del mundo
## directamente. En build de tienda queda desactivado salvo bandera explícita.

const REQUIRED_TAPS := 5
const TAP_WINDOW_MS := 2000
const SERVICE_NAMES := [
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
const WEATHER_BUTTONS := [
	{"preset": "clear", "key": "QA_WEATHER_CLEAR"},
	{"preset": "rain", "key": "QA_WEATHER_RAIN"},
	{"preset": "storm", "key": "QA_WEATHER_STORM"},
	{"preset": "fog", "key": "QA_WEATHER_FOG"},
]

@onready var _hotspot: Control = $Hotspot
@onready var _dimmer: ColorRect = $Dimmer
@onready var _panel: PanelContainer = $Panel
@onready var _title: Label = $Panel/Margin/VBox/Title
@onready var _warning: Label = $Panel/Margin/VBox/Warning
@onready var _body: VBoxContainer = $Panel/Margin/VBox/Scroll/Body
@onready var _status: Label = $Panel/Margin/VBox/Status
@onready var _close_button: Button = $Panel/Margin/VBox/Footer/CloseButton

var _is_open := false
var _tap_times: Array[int] = []
var _text_nodes: Array[Dictionary] = []
var _flags_value: Label = null
var _humanity_value: Label = null
var _trust_value: Label = null
var _mission_value: Label = null
var _weather_value: Label = null
var _services_value: Label = null


func _ready() -> void:
	if not is_available():
		queue_free()
		return
	_hotspot.gui_input.connect(_on_hotspot_gui_input)
	_close_button.pressed.connect(_on_close_pressed)
	EventBus.locale_changed.connect(_on_locale_changed)
	EventBus.game_state_changed.connect(_on_game_state_changed)
	EventBus.weather_changed.connect(_on_weather_changed)
	_build_body()
	_refresh_texts()
	close_menu()


func is_available() -> bool:
	if OS.is_debug_build():
		return true
	if bool(ProjectSettings.get_setting("ruta_nocturna/qa/allow_in_release", false)):
		return true
	for argument in OS.get_cmdline_args():
		if argument == "--qa" or argument == "--enable-qa":
			return true
	return false


func is_open() -> bool:
	return _is_open


func toggle_menu() -> void:
	if _is_open:
		close_menu()
	else:
		open_menu()


func open_menu() -> void:
	if _is_open or not is_available():
		return
	_is_open = true
	_dimmer.visible = true
	_panel.visible = true
	_refresh_values()
	_close_button.grab_focus()
	EventBus.qa_menu_toggled.emit(true)
	EventBus.diagnostics_action.emit("qa_menu_opened", {})


func close_menu() -> void:
	if not _is_open:
		_dimmer.visible = false
		_panel.visible = false
		return
	_is_open = false
	_dimmer.visible = false
	_panel.visible = false
	EventBus.qa_menu_toggled.emit(false)
	EventBus.diagnostics_action.emit("qa_menu_closed", {})


func get_service_count() -> int:
	var active := 0
	for service_name in SERVICE_NAMES:
		if get_node_or_null("/root/%s" % service_name) != null:
			active += 1
	return active


func _input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if (
		key_event != null
		and key_event.pressed
		and not key_event.echo
		and key_event.keycode == KEY_F12
	):
		if is_available():
			toggle_menu()
			get_viewport().set_input_as_handled()
		return
	if _is_open and event.is_action_pressed("ui_cancel"):
		close_menu()
		get_viewport().set_input_as_handled()


func _build_body() -> void:
	_add_section("QA_SECTION_STATE")
	var state_grid := GridContainer.new()
	state_grid.columns = 2
	state_grid.add_theme_constant_override("h_separation", 28)
	state_grid.add_theme_constant_override("v_separation", 5)
	_body.add_child(state_grid)
	_flags_value = _add_grid_row(state_grid, "QA_LABEL_FLAGS")
	_humanity_value = _add_grid_row(state_grid, "QA_LABEL_HUMANITY")
	_trust_value = _add_grid_row(state_grid, "QA_LABEL_TRUST")
	_mission_value = _add_grid_row(state_grid, "QA_LABEL_MISSION")

	_add_section("QA_SECTION_WORLD")
	var weather_grid := GridContainer.new()
	weather_grid.columns = 2
	weather_grid.add_theme_constant_override("h_separation", 28)
	weather_grid.add_theme_constant_override("v_separation", 5)
	_body.add_child(weather_grid)
	_weather_value = _add_grid_row(weather_grid, "QA_LABEL_WEATHER")
	var weather_row := HBoxContainer.new()
	weather_row.add_theme_constant_override("separation", 8)
	_body.add_child(weather_row)
	for entry in WEATHER_BUTTONS:
		_add_button(weather_row, entry["key"], _on_weather_pressed.bind(entry["preset"]))

	_add_section("QA_SECTION_DIAGNOSTICS")
	var diagnostics_grid := GridContainer.new()
	diagnostics_grid.columns = 2
	diagnostics_grid.add_theme_constant_override("h_separation", 28)
	diagnostics_grid.add_theme_constant_override("v_separation", 5)
	_body.add_child(diagnostics_grid)
	_services_value = _add_grid_row(diagnostics_grid, "QA_LABEL_SERVICES")
	var diagnostics_row := HFlowContainer.new()
	diagnostics_row.add_theme_constant_override("h_separation", 8)
	diagnostics_row.add_theme_constant_override("v_separation", 8)
	_body.add_child(diagnostics_row)
	_add_button(diagnostics_row, "QA_ACTION_WRITE_REPORT", _on_write_report_pressed)
	_add_button(diagnostics_row, "UI_COPY_REPORT", _on_copy_report_pressed)
	_add_button(diagnostics_row, "UI_TEST_MODE", _on_toggle_test_mode_pressed)
	_add_button(diagnostics_row, "QA_ACTION_CLEAR_FLAGS", _on_clear_flags_pressed)


func _add_section(key: String) -> Label:
	var label := Label.new()
	label.add_theme_color_override("font_color", Color(0.941, 0.788, 0.361, 1.0))
	label.add_theme_font_size_override("font_size", 16)
	label.text = tr(key)
	_body.add_child(label)
	_text_nodes.append({"node": label, "key": key})
	return label


func _add_grid_row(grid: GridContainer, key: String) -> Label:
	var label := Label.new()
	label.add_theme_color_override("font_color", Color(0.596, 0.72, 0.69, 1.0))
	label.add_theme_font_size_override("font_size", 14)
	label.text = tr(key)
	grid.add_child(label)
	_text_nodes.append({"node": label, "key": key})
	var value := Label.new()
	value.add_theme_color_override("font_color", Color(0.88, 0.91, 0.88, 1.0))
	value.add_theme_font_size_override("font_size", 14)
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.text = "—"
	grid.add_child(value)
	return value


func _add_button(container: Container, key: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = tr(key)
	button.custom_minimum_size = Vector2(0, 40)
	button.pressed.connect(callback)
	container.add_child(button)
	_text_nodes.append({"node": button, "key": key})
	return button


func _refresh_texts() -> void:
	_title.text = tr("QA_MENU_TITLE")
	_warning.text = tr("UI_QA_SAVE_WARNING")
	_close_button.text = tr("QA_ACTION_CLOSE")
	for entry in _text_nodes:
		var node = entry["node"]
		node.text = tr(entry["key"])
	_refresh_values()


func _refresh_values() -> void:
	var flag_keys := GameState.flags.keys()
	flag_keys.sort()
	if flag_keys.is_empty():
		_flags_value.text = tr("QA_NONE")
	else:
		var visible_flags: Array = flag_keys.slice(0, 8)
		_flags_value.text = ", ".join(visible_flags)
		if flag_keys.size() > visible_flags.size():
			_flags_value.text += "…"
	_humanity_value.text = "%.1f" % GameState.humanity
	var trust_keys := GameState.trust.keys()
	trust_keys.sort()
	if trust_keys.is_empty():
		_trust_value.text = tr("QA_NONE")
	else:
		var trust_parts: Array[String] = []
		for passenger_id in trust_keys.slice(0, 4):
			trust_parts.append("%s: %.1f" % [passenger_id, float(GameState.trust[passenger_id])])
		_trust_value.text = ", ".join(trust_parts)
	if GameState.mission_id.is_empty():
		_mission_value.text = tr("QA_NONE")
	else:
		_mission_value.text = "%s / %s" % [GameState.mission_id, GameState.mission_stage]
	var weather := WeatherManager.get_state()
	_weather_value.text = "%s · %.0f%% / %.0f%%" % [
		_weather_label(str(weather.get("preset", ""))),
		float(weather.get("humidity", 0.0)) * 100.0,
		float(weather.get("rain", 0.0)) * 100.0,
	]
	_services_value.text = "%d/%d" % [get_service_count(), SERVICE_NAMES.size()]
	_warning.visible = GameState.is_test_save


func _weather_label(preset: String) -> String:
	var key := "QA_WEATHER_%s" % preset.to_upper()
	var translated := tr(key)
	if translated == key:
		return preset
	return translated


func _set_status(text: String) -> void:
	_status.text = text


func _on_weather_pressed(preset: String) -> void:
	WeatherManager.force_preset(preset)
	_set_status("%s: %s" % [tr("QA_LABEL_WEATHER"), _weather_label(preset)])
	_refresh_values()
	EventBus.qa_action_completed.emit("weather", {"preset": preset})


func _on_write_report_pressed() -> void:
	var path := CrashReporter.write_report("qa_manual", {"source": "creator_qa_menu"})
	if path.is_empty():
		_set_status(tr("QA_STATUS_REPORT_MISSING"))
		return
	_set_status("%s · %s" % [tr("QA_STATUS_REPORT_WRITTEN"), path])
	EventBus.qa_action_completed.emit("write_report", {"path": path})


func _on_copy_report_pressed() -> void:
	var text := CrashReporter.get_last_report_text()
	if text.is_empty():
		_set_status(tr("QA_STATUS_REPORT_MISSING"))
		return
	if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		DisplayServer.clipboard_set(text)
		_set_status(tr("QA_STATUS_COPIED"))
		EventBus.qa_action_completed.emit("copy_report", {"length": text.length()})
	else:
		_set_status(tr("QA_STATUS_REPORT_MISSING"))


func _on_toggle_test_mode_pressed() -> void:
	var enabled := not GameState.is_test_save
	GameState.set_test_mode(enabled)
	SettingsManager.set_value("qa", "test_mode", enabled)
	_set_status(tr("QA_TEST_MODE_ON") if enabled else tr("QA_TEST_MODE_OFF"))
	_refresh_values()
	EventBus.qa_action_completed.emit("toggle_test_mode", {"enabled": enabled})


func _on_clear_flags_pressed() -> void:
	GameState.clear_flags()
	_set_status(tr("QA_ACTION_CLEAR_FLAGS"))
	_refresh_values()
	EventBus.qa_action_completed.emit("clear_flags", {})


func _on_close_pressed() -> void:
	close_menu()


func _on_hotspot_gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event != null and mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
		_register_tap()
		return
	var touch_event := event as InputEventScreenTouch
	if touch_event != null and touch_event.pressed:
		_register_tap()


func _register_tap() -> void:
	var now := Time.get_ticks_msec()
	var recent: Array[int] = []
	for stamp in _tap_times:
		if now - stamp <= TAP_WINDOW_MS:
			recent.append(stamp)
	_tap_times = recent
	_tap_times.append(now)
	if _tap_times.size() >= REQUIRED_TAPS:
		_tap_times.clear()
		open_menu()


func _on_locale_changed(_locale: String) -> void:
	_refresh_texts()


func _on_game_state_changed(_key: String, _value: Variant) -> void:
	if _is_open:
		_refresh_values()


func _on_weather_changed(_preset: String, _state: Dictionary) -> void:
	if _is_open:
		_refresh_values()
