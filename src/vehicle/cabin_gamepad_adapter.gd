class_name CabinGamepadAdapter
extends Node
## Adaptador de gamepad y D-Pad para la cabina (Fase 2.4).
##
## Maneja unicamente eventos de gamepad: el D-Pad enfoca los controles
## contextuales en el orden del contrato, A pulsa, B suelta y el stick derecho
## rota la camara con los limites del reticulo de F2.3. Teclado, raton y tacto
## siguen siendo responsabilidad del controlador de F2.3 y no se tocan.
##
## Los menus (Boot, rebanada, panel QA) navegan con las acciones estandar
## `ui_*` de Godot, que ya incluyen D-Pad y stick; aqui no se duplica esa
## navegacion. La configuracion vive en cabin_interaction.json (seccion
## `gamepad`).

@export var controller_path: NodePath
@export var hud_path: NodePath

var controller: CabinInteractionController
var hud: CabinHUD
var look_vector := Vector2.ZERO

var _deadzone := 0.25
var _look_sensitivity := 2.6
var _look_axes := [2, 3]
var _focus_next: Array = []
var _focus_previous: Array = []
var _accept_button := 0
var _release_button := 1
var _mouse_look_factor := 0.003


func _ready() -> void:
	controller = get_node_or_null(controller_path) as CabinInteractionController
	hud = get_node_or_null(hud_path) as CabinHUD
	var spec: CabinInteractionSpec = null
	if controller != null:
		spec = controller.spec
	if spec == null:
		spec = CabinInteractionSpec.new()
		if not spec.load_spec():
			push_error("[CABIN_GAMEPAD] Contrato invalido: %s" % ", ".join(spec.errors))
			return
	_deadzone = clampf(spec.number("gamepad.cabin.deadzone", 0.25), 0.0, 0.9)
	_look_sensitivity = clampf(spec.number("gamepad.cabin.look_sensitivity", 2.6), 0.1, 10.0)
	_look_axes = _to_int_array(spec.array("gamepad.cabin.look_axis"))
	_focus_next = _to_int_array(spec.array("gamepad.cabin.focus_next_buttons"))
	_focus_previous = _to_int_array(spec.array("gamepad.cabin.focus_previous_buttons"))
	_accept_button = int(spec.number("gamepad.cabin.accept_button", 0.0))
	_release_button = int(spec.number("gamepad.cabin.release_button", 1.0))
	if hud != null:
		hud.set_gamepad_hint_visible(not Input.get_connected_joypads().is_empty())


func _to_int_array(values: Array) -> Array:
	# JSON.parse convierte todos los numeros a float; aqui se normalizan a int
	# para que la comparacion de botones sea exacta.
	var result: Array = []
	for value in values:
		result.append(int(value))
	return result


func _input(event: InputEvent) -> void:
	if controller == null or not controller.input_enabled:
		return
	if _qa_menu_open():
		return
	if event is InputEventJoypadMotion:
		_on_joy_motion(event as InputEventJoypadMotion)
		return
	if event is InputEventJoypadButton:
		_on_joy_button(event as InputEventJoypadButton)


func _process(delta: float) -> void:
	if look_vector == Vector2.ZERO or controller == null:
		return
	# _rotate_camera trabaja en unidades de raton (relativo * 0.003 rad); aqui
	# se convierte la velocidad angular declarada a esas unidades.
	var scale_factor := _look_sensitivity * delta / _mouse_look_factor
	controller.rotate_camera_look(look_vector * scale_factor)


func _on_joy_motion(event: InputEventJoypadMotion) -> void:
	var axis_index := int(event.axis)
	if _look_axes.size() == 2 and axis_index == int(_look_axes[0]):
		look_vector.x = _apply_deadzone(event.axis_value)
	elif _look_axes.size() == 2 and axis_index == int(_look_axes[1]):
		look_vector.y = _apply_deadzone(event.axis_value)
	else:
		return
	if hud != null and look_vector != Vector2.ZERO:
		hud.set_gamepad_hint_visible(true)


func _on_joy_button(event: InputEventJoypadButton) -> void:
	if not event.pressed:
		return
	var button := int(event.button_index)
	if button in _focus_next:
		controller.focus_next_control()
	elif button in _focus_previous:
		controller.focus_previous_control()
	elif button == _accept_button:
		controller.press_focused()
	elif button == _release_button:
		controller.release_control()
		controller.clear_focus()
	if hud != null:
		hud.set_gamepad_hint_visible(true)


func _apply_deadzone(value: float) -> float:
	return 0.0 if absf(value) < _deadzone else value


func _qa_menu_open() -> bool:
	var menu := get_tree().get_first_node_in_group("creator_qa_menu")
	return menu != null and menu.has_method("is_open") and bool(menu.call("is_open"))
