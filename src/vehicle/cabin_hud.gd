class_name CabinHUD
extends CanvasLayer
## HUD minimo de cabina (Fase 2.4): velocidad, marcha, combustible y avisos.
##
## Lee `VehiclePowertrain.get_telemetry()` a la cadencia declarada en
## `data/schemas/cabin_interaction.json` (seccion `hud`). Nunca escribe en el
## tren motriz ni duplica sus relaciones, curvas o umbrales: los avisos son los
## codigos internos del contrato de simulacion traducidos a claves de
## localizacion. No declara botones tactiles; el estado se informa con texto,
## no solo con color. El arte del instrumental final es F3.2.

@export var powertrain_path: NodePath

var spec: CabinInteractionSpec
var powertrain: VehiclePowertrain
var speed_label: Label
var gear_label: Label
var fuel_label: Label
var warnings_label: Label
var hint_label: Label
var last_readout: Dictionary = {}

var _refresh_timer := 0.0
var _refresh_hz := 10.0
var _texts: Dictionary = {}


func _ready() -> void:
	layer = 15
	spec = CabinInteractionSpec.new()
	if not spec.load_spec():
		push_error("[CABIN_HUD] Contrato invalido: %s" % ", ".join(spec.errors))
		return
	_refresh_hz = clampf(spec.number("hud.refresh_hz", 10.0), 1.0, 30.0)
	_build()
	if not powertrain_path.is_empty():
		powertrain = get_node_or_null(powertrain_path) as VehiclePowertrain
	refresh()


func _build() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var panel := VBoxContainer.new()
	panel.name = "Readout"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.anchor_left = 1.0
	panel.anchor_top = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -260.0
	panel.offset_top = -190.0
	panel.offset_right = -24.0
	panel.offset_bottom = -110.0
	panel.alignment = BoxContainer.ALIGNMENT_END
	panel.add_theme_constant_override("separation", 2)
	root.add_child(panel)

	speed_label = _make_label(panel, "Speed", 34, Color(0.95, 0.92, 0.84))
	gear_label = _make_label(panel, "Gear", 20, Color(0.596, 0.72, 0.69))
	fuel_label = _make_label(panel, "Fuel", 16, Color(0.74, 0.8, 0.78))
	warnings_label = _make_label(panel, "Warnings", 15, Color(1.0, 0.72, 0.2))
	warnings_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warnings_label.visible = false

	hint_label = _make_label(panel, "GamepadHint", 12, Color(0.31, 0.55, 0.54))
	hint_label.visible = false


func _make_label(parent: Node, label_name: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = label_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.04))
	label.add_theme_constant_override("outline_size", 5)
	parent.add_child(label)
	return label


func _process(delta: float) -> void:
	_refresh_timer += delta
	if _refresh_timer >= 1.0 / _refresh_hz:
		_refresh_timer = 0.0
		refresh()


func refresh() -> void:
	if powertrain == null or speed_label == null:
		return
	var telemetry := powertrain.get_telemetry()
	if telemetry.is_empty():
		return
	var selector := str(telemetry.get("selector", "P"))
	var gear_number := str(telemetry.get("gear", ""))
	var gear_value := selector if selector in ["P", "R", "N"] else "%s %s" % [selector, gear_number]
	var speed_value := str(int(round(float(telemetry.get("speed_kph", 0.0)))))
	var fuel_value := "%.1f" % float(telemetry.get("fuel_l", 0.0))
	var warnings: Array[String] = []
	var warning_keys: Dictionary = spec.section("hud.warning_keys")
	for code in warning_keys.keys():
		if bool(telemetry.get("warnings", {}).get(code, false)):
			warnings.append(_translate(str(warning_keys[code])))
	_set_text(speed_label, "speed", _translate(str(spec.section("hud.label_keys").get("speed", "HUD_SPEED"))).format({"speed": speed_value}))
	_set_text(gear_label, "gear", _translate(str(spec.section("hud.label_keys").get("gear", "HUD_GEAR"))).format({"gear": gear_value}))
	_set_text(fuel_label, "fuel", _translate(str(spec.section("hud.label_keys").get("fuel", "HUD_FUEL"))).format({"liters": fuel_value}))
	# Texto + simbolo: el aviso no depende solo del color (accesibilidad).
	_set_text(warnings_label, "warnings", " · ".join(warnings) if not warnings.is_empty() else "")
	last_readout = {
		"speed_kph": speed_value,
		"selector": selector,
		"gear": gear_value,
		"fuel_l": fuel_value,
		"warnings": warnings.duplicate(),
	}


func _set_text(label: Label, cache_key: String, value: String) -> void:
	if label == null or str(_texts.get(cache_key, "")) == value:
		return
	_texts[cache_key] = value
	label.text = value
	if cache_key == "warnings":
		label.visible = not value.is_empty()


func set_gamepad_hint_visible(visible: bool) -> void:
	if hint_label == null:
		return
	if visible and hint_label.text.is_empty():
		hint_label.text = _translate(str(spec.section("hud.label_keys").get("gamepad_hint", "HUD_GAMEPAD_HINT")))
	hint_label.visible = visible


func get_readout() -> Dictionary:
	return last_readout.duplicate(true)


func _translate(key: String) -> String:
	var loc := get_node_or_null("/root/LocalizationManager")
	if loc != null and loc.has_method("translate_key"):
		return str(loc.call("translate_key", key, key))
	return key
