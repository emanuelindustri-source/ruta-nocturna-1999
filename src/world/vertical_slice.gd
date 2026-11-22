extends Node3D
## Rebanada vertical de la Fase 1.4: coche gris sobre carretera gris.
## No hay conducción, física, tráfico ni entidades. Es una escena estática de
## presentación para validar la build de Windows y Android.

const BOOT_SCENE := "res://scenes/boot/Boot.tscn"
const ROAD_HALF_LENGTH_M := 120.0
const DASH_SPACING_M := 6.0

@onready var camera: Camera3D = $Camera3D
@onready var title_label: Label = $Overlay/Panel/Margin/VBox/Title
@onready var subtitle_label: Label = $Overlay/Panel/Margin/VBox/Subtitle
@onready var back_button: Button = $Overlay/Panel/Margin/VBox/BackButton
@onready var vehicle: Node3D = $EsteemBlockout


func _ready() -> void:
	title_label.text = tr("SLICE_TITLE")
	subtitle_label.text = tr("SLICE_SUBTITLE")
	back_button.text = tr("UI_BACK")
	back_button.pressed.connect(_return_to_boot)
	_build_lane_dashes()
	camera.look_at(Vector3(0.0, 0.85, 0.0), Vector3.UP)
	print(
		"[RN1999] VERTICAL_SLICE_READY version=%s platform=%s"
		% [str(ProjectSettings.get_setting("application/config/version", "0.0.0")), OS.get_name()]
	)


func _build_lane_dashes() -> void:
	var dash_mesh := BoxMesh.new()
	dash_mesh.size = Vector3(0.14, 0.012, 1.8)
	var dash_material := StandardMaterial3D.new()
	dash_material.albedo_color = Color(0.82, 0.8, 0.72)
	dash_material.roughness = 0.9
	dash_mesh.material = dash_material
	var container := Node3D.new()
	container.name = "LaneDashes"
	add_child(container)
	var index := 0
	var z := -ROAD_HALF_LENGTH_M + DASH_SPACING_M
	while z <= ROAD_HALF_LENGTH_M:
		var dash := MeshInstance3D.new()
		dash.name = "Dash%02d" % index
		dash.mesh = dash_mesh
		dash.position = Vector3(0.0, 0.012, z)
		dash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		container.add_child(dash)
		index += 1
		z += DASH_SPACING_M


func _return_to_boot() -> void:
	SceneRouter.change_scene(BOOT_SCENE, "vertical_slice_back")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_return_to_boot()
