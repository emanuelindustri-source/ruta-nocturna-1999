class_name CabinInteractionUI
extends CanvasLayer
## Prompt contextual y reticulo de la cabina.
##
## Es la unica UI de F2.3: no hay HUD de velocidad, combustible ni botones
## persistentes. El texto usa claves de localizacion y el reticulo cambia de
## color y de leyenda, de modo que el estado no depende solo del color.

var controller: CabinInteractionController
var reticle: CabinReticle
var label: Label
var feedback_label: Label

var _feedback_timer := 0.0


func _ready() -> void:
	layer = 20
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	reticle = CabinReticle.new()
	reticle.name = "Reticle"
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reticle.anchor_left = 0.5
	reticle.anchor_top = 0.5
	reticle.anchor_right = 0.5
	reticle.anchor_bottom = 0.5
	reticle.offset_left = -14.0
	reticle.offset_top = -14.0
	reticle.offset_right = 14.0
	reticle.offset_bottom = 14.0
	root.add_child(reticle)

	label = Label.new()
	label.name = "ContextLabel"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.anchor_left = 0.0
	label.anchor_top = 1.0
	label.anchor_right = 1.0
	label.anchor_bottom = 1.0
	label.offset_left = 24.0
	label.offset_top = -104.0
	label.offset_right = -24.0
	label.offset_bottom = -66.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.84))
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.04))
	label.add_theme_constant_override("outline_size", 5)
	root.add_child(label)

	feedback_label = Label.new()
	feedback_label.name = "FeedbackLabel"
	feedback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feedback_label.anchor_left = 0.0
	feedback_label.anchor_top = 1.0
	feedback_label.anchor_right = 1.0
	feedback_label.anchor_bottom = 1.0
	feedback_label.offset_left = 24.0
	feedback_label.offset_top = -64.0
	feedback_label.offset_right = -24.0
	feedback_label.offset_bottom = -30.0
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	feedback_label.add_theme_font_size_override("font_size", 16)
	feedback_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.2))
	feedback_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.04))
	feedback_label.add_theme_constant_override("outline_size", 5)
	feedback_label.visible = false
	root.add_child(feedback_label)

	controller = get_parent().get_node_or_null("Interaction") as CabinInteractionController
	if controller != null:
		controller.focus_changed.connect(_on_focus_changed)
		controller.interaction_feedback.connect(_on_feedback)
	_apply_focus("", false, "", "")


func _process(delta: float) -> void:
	if _feedback_timer <= 0.0:
		return
	_feedback_timer = maxf(0.0, _feedback_timer - delta)
	if _feedback_timer <= 0.0:
		feedback_label.visible = false


func _on_focus_changed(control_id: String, available: bool, label_key: String, hint_key: String) -> void:
	_apply_focus(control_id, available, label_key, hint_key)


func _apply_focus(control_id: String, available: bool, label_key: String, hint_key: String) -> void:
	if reticle != null:
		reticle.set_state(not control_id.is_empty(), available)
	if label == null:
		return
	if control_id.is_empty():
		label.text = ""
		return
	var control_text := _translate(label_key)
	var hint_text := _translate(hint_key)
	label.text = "%s — %s" % [control_text, hint_text]


func _on_feedback(_control_id: String, code: String) -> void:
	if controller == null or controller.spec == null:
		return
	var key := controller.spec.feedback_key(code)
	if key.is_empty():
		return
	feedback_label.text = _translate(key)
	feedback_label.visible = true
	_feedback_timer = 1.4


func _translate(key: String) -> String:
	var loc := get_node_or_null("/root/LocalizationManager")
	if loc != null and loc.has_method("translate_key"):
		return str(loc.call("translate_key", key, key))
	return key
