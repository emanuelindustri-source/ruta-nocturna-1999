extends Control
## Pantalla de arranque desde la Fase 1.2 y acceso a la rebanada vertical de 1.4.
## Verifica los servicios base y abre el panel QA, sin mecánicas de conducción.

const PHASE := "4.4"
const VERTICAL_SLICE_SCENE := "res://scenes/vertical_slice/VerticalSlice.tscn"
const CABIN_SCENE := "res://scenes/vehicle/CabinInteraction.tscn"
const WORLD_SCENE := "res://scenes/world/WorldTerrain.tscn"
const REPOSITORY := "emanuelindustri-source/ruta-nocturna-1999"
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

@onready var kicker_label: Label = $Center/VBox/Kicker
@onready var status_label: Label = $Center/VBox/StatusLabel
@onready var version_label: Label = $Center/VBox/VersionLabel
@onready var qa_hint_label: Label = $Center/VBox/QaHint
@onready var credits_label: Label = $Center/VBox/CreditsLabel
@onready var crash_warning_label: Label = $Center/VBox/CrashWarning
@onready var view_slice_button: Button = $Center/VBox/ViewSlice
@onready var view_world_button: Button = $Center/VBox/ViewWorld
@onready var view_cabin_button: Button = $Center/VBox/ViewCabin


func _ready() -> void:
	# Warm-up de shaders de lluvia (F3.4) antes de abrir cualquier gameplay.
	RainFxWarmup.run(self)
	var version: String = str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	var active := _count_services()
	kicker_label.text = tr("BOOT_KICKER")
	status_label.text = "%s\n%s" % [
		tr("BOOT_STATUS_READY"),
		tr("BOOT_SERVICES_LINE").format({"active": active, "total": SERVICE_NAMES.size()}),
	]
	version_label.text = tr("BOOT_VERSION_LINE").format(
		{"version": version, "phase": PHASE, "platform": OS.get_name()}
	)
	qa_hint_label.text = tr("BOOT_QA_HINT")
	credits_label.text = tr("CREDITS_OSM")
	view_slice_button.text = tr("UI_VIEW_SLICE")
	view_slice_button.pressed.connect(_open_vertical_slice)
	view_world_button.text = tr("UI_VIEW_WORLD")
	view_world_button.pressed.connect(_open_world)
	view_cabin_button.text = tr("UI_VIEW_CABIN")
	view_cabin_button.pressed.connect(_open_cabin)
	crash_warning_label.visible = CrashReporter.previous_session_detected
	if crash_warning_label.visible:
		crash_warning_label.text = tr("BOOT_CRASH_WARNING")
	print(
		"[RN1999] Boot v%s, fase %s, %d/%d servicios, repo %s"
		% [version, PHASE, active, SERVICE_NAMES.size(), REPOSITORY]
	)
	print("[RN1999] BOOT_READY version=%s platform=%s services=%d" % [version, OS.get_name(), active])
	EventBus.application_booted.emit(version)


func _open_vertical_slice() -> void:
	SceneRouter.change_scene(VERTICAL_SLICE_SCENE, "vertical_slice")


func _open_world() -> void:
	SceneRouter.change_scene(WORLD_SCENE, "world_terrain")


func _open_cabin() -> void:
	SceneRouter.change_scene(CABIN_SCENE, "cabin_interaction")


func _count_services() -> int:
	var active := 0
	for service_name in SERVICE_NAMES:
		if get_node_or_null("/root/%s" % service_name) != null:
			active += 1
	return active


func _unhandled_input(event: InputEvent) -> void:
	var from_gamepad := event is InputEventJoypadButton or event is InputEventJoypadMotion
	if from_gamepad and get_viewport().gui_get_focus_owner() == null and _gamepad_wakes_focus(event):
		# El D-Pad de Android TV/PC necesita un foco inicial para navegar.
		view_slice_button.grab_focus()
	if event.is_action_pressed("ui_cancel"):
		if from_gamepad:
			# B del gamepad no cierra la aplicacion en el menu raiz; Esc si.
			return
		var qa_menu := get_node_or_null("CreatorQAMenu")
		if qa_menu != null and qa_menu.is_open():
			return
		get_tree().quit()


func _gamepad_wakes_focus(event: InputEvent) -> bool:
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).pressed
	if event is InputEventJoypadMotion:
		return absf((event as InputEventJoypadMotion).axis_value) >= 0.5
	return false
