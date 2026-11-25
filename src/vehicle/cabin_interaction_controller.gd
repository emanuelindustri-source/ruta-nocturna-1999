class_name CabinInteractionController
extends Node
## Interaccion contextual "mirar/tocar" de la cabina.
##
## El reticulo enfoca por angulo desde la camara y el tacto proyecta los
## controles a pantalla con un radio minimo de 44 dp. Al pulsar, la mano IK
## alcanza el control y se delega la accion en CabinControls. La palanca y el
## Overdrive terminan en VehiclePowertrain; el freno de mano en brakes.parking.
## No hay fisica de conduccion ni guardado: el gamepad/D-Pad de F2.4 lo adapta
## CabinGamepadAdapter reutilizando estas mismas señales (foco, pulsar, soltar,
## girar cámara), sin duplicar el tacto ni el raton.

signal focus_changed(control_id: String, available: bool, label_key: String, hint_key: String)
signal interaction_feedback(control_id: String, code: String)
signal control_activated(control_id: String, accepted: bool)

@export var auto_update := true
@export var input_enabled := true
@export var camera_path: NodePath
@export var cabin_path: NodePath
@export var controls_path: NodePath
@export var hands_path: NodePath
@export var proxies_path: NodePath
@export var powertrain_path: NodePath

var spec: CabinInteractionSpec
var camera: Camera3D
var cabin: Node3D
var controls: CabinControls
var hands: HandIKDriver
var proxies: CabinVisualProxies
var powertrain: VehiclePowertrain

var focused_control_id := ""
var focused_available := false
var focused_label_key := ""
var focused_hint_key := ""
var last_feedback := ""
var last_feedback_control := ""

var _configured := false
var _held_control_id := ""
var _hold_time := 0.0
var _volume_timer := 0.0
var _drag_accum := 0.0
var _return_timer := 0.0
var _look_dragging := false
var _press_failed := false


func _ready() -> void:
	spec = CabinInteractionSpec.new()
	if not spec.load_spec():
		push_error("[CABIN_INTERACTION] Contrato invalido: %s" % ", ".join(spec.errors))
		return
	camera = _resolve(camera_path) as Camera3D
	cabin = _resolve(cabin_path) as Node3D
	controls = _resolve(controls_path) as CabinControls
	hands = _resolve(hands_path) as HandIKDriver
	proxies = _resolve(proxies_path) as CabinVisualProxies
	powertrain = _resolve(powertrain_path) as VehiclePowertrain
	if cabin == null or controls == null or hands == null or proxies == null or powertrain == null:
		push_error("[CABIN_INTERACTION] Faltan nodos de la escena de cabina")
		return
	var cabin_spec := _load_cabin_spec()
	controls.configure(spec, powertrain)
	proxies.configure(cabin, spec, controls, cabin_spec)
	controls.position_provider = Callable(proxies, "get_control_position")
	hands.configure(spec, cabin_spec, controls, _find_skeleton(cabin))
	proxies.bind_hands(hands)
	controls.feedback.connect(_on_controls_feedback)
	_configured = true
	call_deferred("_update_look_focus")


func _process(delta: float) -> void:
	if auto_update and _configured:
		advance(delta)


func advance(delta: float) -> void:
	if not _configured:
		return
	controls.advance(delta)
	hands.advance(delta)
	_tick_hold(delta)
	_tick_return(delta)
	proxies.update_from_controls()


func get_focused_control() -> String:
	return focused_control_id


func is_focus_available() -> bool:
	return focused_available


func get_focus_hint() -> String:
	return focused_hint_key


func get_last_feedback() -> String:
	return last_feedback


func get_hands_on_wheel() -> int:
	return hands.get_hands_on_wheel() if hands != null else 0


func update_look(origin: Vector3, forward: Vector3) -> String:
	if spec == null:
		return ""
	var direction := forward.normalized()
	var max_angle := spec.number("interaction.reticle_max_angle_deg", 7.0)
	var max_distance := spec.number("interaction.look_distance_m", 1.2)
	var best_id := ""
	var best_angle := INF
	for control_id in spec.control_ids():
		var position := controls.get_control_position(control_id)
		var offset := position - origin
		var distance := offset.length()
		if distance <= 0.001 or distance > max_distance:
			continue
		var angle := rad_to_deg(acos(clampf(offset.normalized().dot(direction), -1.0, 1.0)))
		if angle <= max_angle and angle < best_angle:
			best_angle = angle
			best_id = control_id
	if best_id.is_empty():
		clear_focus()
	else:
		focus_control(best_id)
	return best_id


func focus_control(control_id: String) -> bool:
	if spec == null:
		return false
	var control := spec.control(control_id)
	if control.is_empty():
		clear_focus()
		return false
	var availability := _availability(control)
	focused_control_id = control_id
	focused_available = bool(availability.get("available", true))
	focused_label_key = str(control.get("label_key", ""))
	focused_hint_key = str(availability.get("hint_key", control.get("hint_key", "")))
	focus_changed.emit(focused_control_id, focused_available, focused_label_key, focused_hint_key)
	return true


func clear_focus() -> void:
	if focused_control_id.is_empty():
		return
	focused_control_id = ""
	focused_available = false
	focused_label_key = ""
	focused_hint_key = ""
	focus_changed.emit("", false, "", "")


func focus_next_control() -> String:
	return _cycle_focus(1)


func focus_previous_control() -> String:
	return _cycle_focus(-1)


func rotate_camera_look(relative: Vector2) -> void:
	# Entrada del gamepad (F2.4): mismos limites de yaw/pitch y mismo foco de
	# reticulo que el arrastre de raton de F2.3.
	_rotate_camera(relative)
	_update_look_focus()


func touch_at(screen_position: Vector2) -> String:
	if camera == null or spec == null:
		return ""
	var radius := _touch_radius_px()
	var best_id := ""
	var best_distance := INF
	for control_id in spec.control_ids():
		var world := controls.get_control_position(control_id)
		if camera.is_position_behind(world):
			continue
		var screen := camera.unproject_position(world)
		var distance := screen.distance_to(screen_position)
		if distance <= radius and distance < best_distance:
			best_distance = distance
			best_id = control_id
	if best_id.is_empty():
		clear_focus()
	else:
		focus_control(best_id)
	return best_id


func press_focused() -> bool:
	return press_control(focused_control_id)


func press_control(control_id: String) -> bool:
	if spec == null:
		return false
	var control := spec.control(control_id)
	if control.is_empty():
		return false
	_held_control_id = control_id
	_hold_time = 0.0
	_volume_timer = 0.0
	_drag_accum = 0.0
	_return_timer = 0.0
	hands.set_pose(str(control.get("pose", "pose_rest")))
	var interaction := str(control.get("interaction", "tap"))
	if interaction in ["tap", "cycle"]:
		_press_failed = false
		_perform(control_id)
		control_activated.emit(control_id, not _press_failed)
		_schedule_return()
	elif interaction == "hold":
		_start_hold(control)
	return true


func release_focused() -> void:
	release_control()


func release_control() -> void:
	if _held_control_id.is_empty():
		return
	var control := spec.control(_held_control_id)
	if str(control.get("interaction", "")) == "hold":
		if _held_control_id.begins_with("window_"):
			controls.stop_window(str(control.get("group", "")))
	_held_control_id = ""
	_schedule_return()


func drag_focused(relative: Vector2) -> void:
	if focused_control_id != "gear_lever" or _held_control_id != "gear_lever":
		return
	_drag_accum += relative.y
	var threshold := spec.number("interaction.drag_threshold_px", 24.0)
	while absf(_drag_accum) >= threshold:
		var direction := 1 if _drag_accum > 0.0 else -1
		controls.nudge_gear(direction)
		_drag_accum -= float(direction) * threshold


func _perform(control_id: String) -> void:
	match control_id:
		"steering_wheel":
			pass
		"gear_lever":
			pass
		"overdrive_button":
			controls.toggle_overdrive()
		"handbrake":
			controls.toggle_handbrake()
		"door_driver":
			controls.toggle_door("driver")
		"door_passenger":
			controls.toggle_door("passenger")
		"central_lock":
			controls.toggle_locked()
		"lights":
			controls.cycle_lights()
		"antenna":
			controls.toggle_antenna()
		"radio_power":
			controls.radio_toggle_power()
		"radio_band":
			controls.radio_cycle_band()
		"radio_seek":
			controls.radio_seek()
		"glovebox":
			controls.toggle_glovebox()


func _start_hold(control: Dictionary) -> void:
	var control_id := str(control.get("id", ""))
	if control_id.begins_with("window_"):
		controls.set_window_direction(
			str(control.get("group", "")),
			str(control.get("direction", ""))
		)
	elif control_id.begins_with("radio_volume_"):
		var direction := 1 if str(control.get("direction", "")) == "up" else -1
		controls.radio_volume(direction)
		_volume_timer = spec.number("interaction.volume_repeat_s", 0.18)


func _tick_hold(delta: float) -> void:
	if _held_control_id.is_empty():
		return
	var control := spec.control(_held_control_id)
	if str(control.get("interaction", "")) != "hold":
		return
	_hold_time += delta
	if _held_control_id.begins_with("radio_volume_"):
		_volume_timer -= delta
		var repeat := maxf(0.05, spec.number("interaction.volume_repeat_s", 0.18))
		while _volume_timer <= 0.0:
			var direction := 1 if str(control.get("direction", "")) == "up" else -1
			controls.radio_volume(direction)
			_volume_timer += repeat


func _tick_return(delta: float) -> void:
	if _return_timer <= 0.0:
		return
	_return_timer = maxf(0.0, _return_timer - delta)
	if _return_timer <= 0.0 and _held_control_id.is_empty() and hands != null:
		hands.set_pose("pose_rest")


func _schedule_return() -> void:
	_return_timer = spec.number("interaction.hand_return_delay_s", 0.35)


func _availability(control: Dictionary) -> Dictionary:
	var hint := str(control.get("hint_key", ""))
	if bool(control.get("requires_unlocked", false)) and controls.is_locked():
		return {"available": false, "hint_key": spec.feedback_key("locked")}
	if bool(control.get("requires_stationary", false)) and not controls.is_stationary():
		return {"available": false, "hint_key": spec.feedback_key("moving")}
	var required_selector := str(control.get("requires_selector", ""))
	if not required_selector.is_empty() and powertrain != null and str(powertrain.selector) != required_selector:
		return {"available": false, "hint_key": spec.feedback_key("overdrive_needs_drive")}
	if bool(control.get("requires_radio_on", false)):
		if controls.radio == null or not controls.radio.power_on:
			return {"available": false, "hint_key": spec.feedback_key("radio_off")}
	return {"available": true, "hint_key": hint}


func _cycle_focus(step: int) -> String:
	if spec == null:
		return ""
	var ids := spec.control_ids()
	if ids.is_empty():
		return ""
	var index := ids.find(focused_control_id)
	if index < 0:
		focus_control(str(ids[0] if step > 0 else ids[ids.size() - 1]))
		return focused_control_id
	var wrap := spec.boolean("gamepad.cabin.focus_wrap", true)
	var next_index := index + step
	if wrap:
		next_index = ((next_index % ids.size()) + ids.size()) % ids.size()
	else:
		next_index = clampi(next_index, 0, ids.size() - 1)
	focus_control(str(ids[next_index]))
	return focused_control_id


func _update_look_focus() -> void:
	if camera == null or not _configured:
		return
	update_look(camera.global_position, -camera.global_transform.basis.z)


func _touch_radius_px() -> float:
	var dpi := float(DisplayServer.screen_get_dpi())
	if dpi <= 0.0:
		dpi = spec.number("interaction.reference_dpi", 160.0)
	var radius := spec.number("interaction.touch_radius_dp", 44.0) * dpi / 160.0
	return maxf(spec.number("interaction.min_touch_radius_px", 44.0), radius)


func _on_controls_feedback(code: String) -> void:
	last_feedback = code
	last_feedback_control = focused_control_id
	_press_failed = true
	interaction_feedback.emit(focused_control_id, code)
	control_activated.emit(focused_control_id, false)


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or not _configured:
		return
	if event.is_action_pressed("ui_cancel"):
		# F4.3 (H13): la cabina no tenia salida por teclado y dejaba al jugador
		# atrapado hasta cerrar el juego. Se usa el patron de WorldDirector.
		SceneRouter.change_scene("res://scenes/boot/Boot.tscn", "cabin_back")
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			var touched := touch_at(touch.position)
			if not touched.is_empty():
				press_control(touched)
		else:
			release_control()
		return
	if event is InputEventScreenDrag:
		if not _held_control_id.is_empty():
			drag_focused((event as InputEventScreenDrag).relative)
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_RIGHT:
			_look_dragging = mouse.pressed
			return
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			if mouse.pressed:
				# PC: el clic se resuelve por POSICION, igual que el tacto en
				# Android (F4.3/H8). Antes se pulsaba siempre el control del
				# retículo, con lo que cualquier clic acababa en el volante.
				var touched := touch_at(mouse.position)
				if not touched.is_empty():
					press_control(touched)
				elif focused_control_id.is_empty():
					clear_focus()
			else:
				release_control()
			return
	if event is InputEventMouseMotion:
		if _look_dragging:
			_rotate_camera((event as InputEventMouseMotion).relative)
			_update_look_focus()
		elif not _held_control_id.is_empty():
			# PC: el arrastre con boton izquierdo alimenta al gesto de la palanca
			# (F4.3/H2 preliminar); en Android sigue mandando InputEventScreenDrag.
			drag_focused((event as InputEventMouseMotion).relative)
		return


func _rotate_camera(relative: Vector2) -> void:
	if camera == null:
		return
	var yaw_limit := deg_to_rad(spec.number("interaction.look_drag_yaw_deg", 70.0))
	var pitch_limit := deg_to_rad(spec.number("interaction.look_drag_pitch_deg", 45.0))
	camera.rotation.y = clampf(camera.rotation.y - relative.x * 0.003, -yaw_limit, yaw_limit)
	camera.rotation.x = clampf(camera.rotation.x - relative.y * 0.003, -pitch_limit, pitch_limit)


func _resolve(path: NodePath) -> Node:
	if path.is_empty():
		return null
	return get_node_or_null(path)


func _load_cabin_spec() -> Dictionary:
	var text := FileAccess.get_file_as_string("res://data/vehicle/cabin_spec.json")
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null
