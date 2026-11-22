extends Control
## Foundation boot screen for Phase 1.1.
## This scene intentionally contains no gameplay mechanics.

const PHASE := "1.1"
const REPOSITORY := "emanuelindustri-source/ruta-nocturna-1999"

@onready var status_label: Label = $Center/VBox/StatusLabel
@onready var version_label: Label = $Center/VBox/VersionLabel


func _ready() -> void:
	var version: String = str(ProjectSettings.get_setting("application/config/version", "0.1.0"))
	version_label.text = "v%s · Fase %s · base local" % [version, PHASE]
	status_label.text = "Contratos, arquitectura, web y validación preparados.\nLa carretera todavía no es jugable."
	print("[RN1999] Boot de fundación v%s, fase %s, repo %s" % [version, PHASE, REPOSITORY])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
