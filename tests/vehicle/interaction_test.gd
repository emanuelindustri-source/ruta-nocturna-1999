extends Node
## Pruebas headless de la interaccion contextual de la cabina (Fase 2.3).
##
## Ejecutar:
##   .\tools\dev\interaction_test.cmd
## Verifica contrato, escena, poses IK de 2/1/0 manos, reticulo/tacto, puertas y
## seguros, vidrios, luces, antena, radio, guantera, palanca P-R-N-D-2-L,
## Overdrive y freno de mano. La palanca y el Overdrive se comparan contra
## VehiclePowertrain; el freno de mano contra brakes.parking. No relaja los
## tests de 2.1/2.2 ni introduce fisica de conduccion.

const SCENE_PATH := "res://scenes/vehicle/CabinInteraction.tscn"
const CONTRACT_PATH := "res://data/schemas/cabin_interaction.json"
const CABIN_SPEC_PATH := "res://data/vehicle/cabin_spec.json"
const POWERTRAIN_SPEC_PATH := "res://data/schemas/vehicle_powertrain.json"
const CSV_PATH := "res://localization/strings.csv"
const LOCALES := ["es_VE", "es_ES", "en", "pt_PT", "pt_BR", "it", "fr", "de", "ru", "zh_CN", "ja"]

var _passed := 0
var _failed: Array[String] = []
var _scene: Node
var _controller: CabinInteractionController
var _controls: CabinControls
var _hands: HandIKDriver
var _proxies: CabinVisualProxies
var _powertrain: VehiclePowertrain
var _camera: Camera3D
var _contract: Dictionary = {}
var _cabin_spec: Dictionary = {}


func _ready() -> void:
	print("[INTERACTION] Inicio de pruebas de interaccion contextual")
	await get_tree().process_frame
	await get_tree().process_frame
	_contract = _load_json(CONTRACT_PATH)
	_cabin_spec = _load_json(CABIN_SPEC_PATH)
	_test_contract()
	await _load_scene()
	if _controller == null:
		_check(false, "escena de interaccion configurada")
		_finish()
		return
	_test_scene_shape()
	_test_no_forbidden_subsystems()
	_test_localization()
	_test_hand_poses()
	_test_focus_and_touch()
	_test_gear_and_powertrain()
	_test_handbrake()
	_test_doors_and_locks()
	_test_windows()
	_test_lights_antenna_radio_glovebox()
	_test_controller_flow()
	_test_no_duplicate_mechanics()
	_finish()


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("[INTERACTION] OK   %s" % label)
	else:
		_failed.append(label)
		print("[INTERACTION] FAIL %s" % label)


func _load_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


func _load_scene() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	_check(packed != null, "escena CabinInteraction carga")
	if packed == null:
		return
	_scene = packed.instantiate()
	var interaction := _scene.get_node_or_null("Interaction") as CabinInteractionController
	if interaction != null:
		interaction.auto_update = false
		interaction.input_enabled = false
	add_child(_scene)
	await get_tree().process_frame
	await get_tree().process_frame
	_controller = _scene.get_node_or_null("Interaction") as CabinInteractionController
	_controls = _scene.get_node_or_null("Controls") as CabinControls
	_hands = _scene.get_node_or_null("Hands") as HandIKDriver
	_proxies = _scene.get_node_or_null("Proxies") as CabinVisualProxies
	_powertrain = _scene.get_node_or_null("Powertrain") as VehiclePowertrain
	_camera = _scene.get_node_or_null("Camera3D") as Camera3D
	_check(_controller != null, "controlador de interaccion presente")
	_check(_controls != null, "estado de controles presente")
	_check(_hands != null, "conductor IK de manos presente")
	if _hands != null:
		_hands.auto_advance = false
	_check(_proxies != null, "proxies visuales presentes")
	_check(_powertrain != null, "tren motriz presente")
	_check(_camera != null and _camera.current, "camara de cabina activa")


func _test_contract() -> void:
	_check(not _contract.is_empty(), "contrato cabin_interaction carga")
	_check(int(_contract.get("schema_version", 0)) == 1, "schema_version 1")
	_check(str(_contract.get("contract_id", "")) == "vehicle.esteem.cabin_interaction", "contract_id estable")
	var powertrain_spec := _load_json(POWERTRAIN_SPEC_PATH)
	_check(str(_contract.get("vehicle_id", "")) == str(powertrain_spec.get("vehicle_id", "")), "vehicle_id coincide con el tren motriz")
	var references: Dictionary = _contract.get("references", {})
	for key in ["cabin_spec", "powertrain", "blockout_spec"]:
		_check(FileAccess.file_exists("res://" + str(references.get(key, ""))), "referencia %s existe" % key)
	var controls: Array = _contract.get("controls", [])
	_check(controls.size() >= 19, "contrato con al menos 19 controles (%d)" % controls.size())
	var required := {
		"steering_wheel": true,
		"gear_lever": true,
		"overdrive_button": true,
		"handbrake": true,
		"door_driver": true,
		"door_passenger": true,
		"central_lock": true,
		"window_driver_up": true,
		"window_driver_down": true,
		"window_passenger_up": true,
		"window_passenger_down": true,
		"lights": true,
		"antenna": true,
		"radio_power": true,
		"radio_band": true,
		"radio_seek": true,
		"radio_volume_up": true,
		"radio_volume_down": true,
		"glovebox": true,
	}
	var ids := {}
	for control in controls:
		if control is Dictionary:
			ids[str(control.get("id", ""))] = true
	var missing: Array[String] = []
	for key in required.keys():
		if not ids.has(key):
			missing.append(key)
	_check(missing.is_empty(), "controles obligatorios presentes")
	_check(
		_contract.get("gear_gate", {}).get("modes", []) == powertrain_spec.get("transmission", {}).get("selector_modes", []),
		"gear_gate.modes coincide con vehicle_powertrain"
	)
	var detents: Array = _contract.get("gear_gate", {}).get("detents", [])
	var detent_modes: Array = []
	for detent in detents:
		if detent is Dictionary:
			detent_modes.append(str(detent.get("mode", "")))
	_check(detent_modes == ["P", "R", "N", "D", "2", "L"], "detentes en orden P-R-N-D-2-L")
	_check(float(_contract.get("interaction", {}).get("touch_radius_dp", 0)) >= 44.0, "radio tactil >= 44 dp")
	_check(float(_contract.get("interaction", {}).get("min_touch_radius_px", 0)) >= 44.0, "radio tactil minimo en px")
	_check(_contract.get("anti_softlock", {}).get("irreversible_actions", true) == false, "sin acciones irreversibles")
	var poses: Array = _contract.get("hands", {}).get("poses", [])
	var wheel_anchors := {
		str(_contract.get("hands", {}).get("wheel", {}).get("left_anchor", "")): true,
		str(_contract.get("hands", {}).get("wheel", {}).get("right_anchor", "")): true,
	}
	var counts := {}
	for pose in poses:
		if not (pose is Dictionary):
			continue
		var on_wheel := 0
		for side in ["left", "right"]:
			var target: Dictionary = pose.get(side, {})
			if str(target.get("kind", "")) == "anchor" and wheel_anchors.has(str(target.get("id", ""))):
				on_wheel += 1
		counts[on_wheel] = true
	_check(counts.has(2) and counts.has(1) and counts.has(0), "poses IK cubren 2/1/0 manos en el volante")
	var links := {}
	for control in controls:
		if control is Dictionary:
			links[str(control.get("id", ""))] = str(control.get("powertrain_link", ""))
	_check(links.get("gear_lever", "") == "transmission.selector", "palanca delegada en transmission.selector")
	_check(links.get("overdrive_button", "") == "transmission.overdrive", "Overdrive delegado en transmission.overdrive")
	_check(links.get("handbrake", "") == "brakes.parking", "freno de mano delegado en brakes.parking")
	_check(links.get("steering_wheel", "") == "none", "volante no duplica fisica de direccion")
	var gate: Dictionary = _cabin_spec.get("components", {}).get("gear_gate_plate", {})
	var gate_min_z := float(gate.get("min_m", [0, 0, -999])[2])
	var gate_max_z := float(gate.get("max_m", [0, 0, 999])[2])
	var inside := true
	for detent in detents:
		var z := float(detent.get("position_m", [0, 0, 0])[2])
		if z < gate_min_z or z > gate_max_z:
			inside = false
	_check(inside, "detentes dentro de la guia fisica")


func _test_scene_shape() -> void:
	_check(_powertrain.auto_simulate == false, "tren motriz no simula en la cabina")
	_check(_scene.get_node_or_null("Cabin/LOD0") != null, "LOD0 de cabina presente")
	_check(_scene.get_node_or_null("UI") is CanvasLayer, "UI contextual en CanvasLayer")
	var physics := _find_first_by_class(_scene, ["VehicleBody3D", "RigidBody3D", "CharacterBody3D", "VehicleWheel3D"])
	_check(physics == null, "sin cuerpos de fisica ni conduccion")
	var mirror := _find_name_containing(_scene, "mirror")
	_check(mirror == null, "sin espejos (F2.4)")
	var subviewport := _find_first_by_class(_scene, ["SubViewport"])
	_check(subviewport == null, "sin SubViewport de espejos")
	var buttons := _count_class(_scene.get_node_or_null("UI"), "Button")
	_check(buttons == 0, "sin botones tactiles persistentes")
	_check(_count_class(_scene.get_node_or_null("UI"), "Label") >= 1, "prompt contextual localizable")
	_check(_controller.spec != null, "controlador con contrato cargado")


func _test_no_forbidden_subsystems() -> void:
	var controller_source := FileAccess.get_file_as_string("res://src/vehicle/cabin_interaction_controller.gd")
	var controls_source := FileAccess.get_file_as_string("res://src/vehicle/cabin_controls.gd")
	var hands_source := FileAccess.get_file_as_string("res://src/vehicle/hand_ik_driver.gd")
	var ui_source := FileAccess.get_file_as_string("res://src/vehicle/cabin_interaction_ui.gd")
	var joined := controller_source + controls_source + hands_source + ui_source
	for forbidden in ["SaveManager", "SubViewport", "InputEventJoypad", "JOY_BUTTON", "VehicleBody3D"]:
		_check(joined.find(forbidden) == -1, "sin %s en la interaccion" % forbidden)
	_check(controls_source.find("gear_ratios") == -1, "sin relaciones de caja duplicadas")
	_check(controls_source.find("torque_curve_nm") == -1, "sin curva de par duplicada")
	_check(controls_source.find("max_service_force_n") == -1, "sin fuerza de freno duplicada")
	_check(hands_source.find("VehicleBody3D") == -1, "IK sin fisica de conduccion")


func _test_localization() -> void:
	var rows := _read_csv()
	_check(not rows.is_empty(), "CSV de localizacion accesible")
	var header: Array = rows[0] if not rows.is_empty() else []
	var key_column := -1
	var locale_columns := {}
	for index in range(header.size()):
		var name := str(header[index]).replace("\ufeff", "").strip_edges()
		if name == "key":
			key_column = index
		elif name in LOCALES:
			locale_columns[name] = index
	_check(key_column >= 0 and locale_columns.size() == LOCALES.size(), "CSV con clave y 11 idiomas")
	var values := {}
	for row in rows.slice(1):
		if row.size() > key_column:
			values[str(row[key_column])] = row
	var keys: Array[String] = []
	for control in _contract.get("controls", []):
		if control is Dictionary:
			keys.append(str(control.get("label_key", "")))
			keys.append(str(control.get("hint_key", "")))
	for key in _contract.get("feedback", {}).values():
		keys.append(str(key))
	var missing: Array[String] = []
	var empty: Array[String] = []
	for key in keys:
		if not values.has(key):
			missing.append(key)
			continue
		var row: Array = values[key]
		for locale in LOCALES:
			var column: int = locale_columns.get(locale, -1)
			if column < 0 or column >= row.size() or str(row[column]).strip_edges().is_empty():
				empty.append("%s/%s" % [key, locale])
	_check(missing.is_empty(), "todas las claves de interaccion existen en el CSV")
	_check(empty.is_empty(), "todas las traducciones de interaccion estan completas")
	_check(values.has("UI_VIEW_CABIN"), "clave UI_VIEW_CABIN presente")
	var loc := get_node_or_null("/root/LocalizationManager")
	_check(loc != null and bool(loc.call("has_key", "CABIN_CONTROL_GEAR_LEVER")), "LocalizationManager resuelve la clave de palanca")
	var boot_packed := load("res://scenes/boot/Boot.tscn") as PackedScene
	if boot_packed != null:
		var boot := boot_packed.instantiate()
		_check(boot.get_node_or_null("Center/VBox/ViewCabin") is Button, "Boot ofrece acceso a la cabina")
		boot.queue_free()
	else:
		_check(false, "escena Boot carga para el acceso a la cabina")


func _test_hand_poses() -> void:
	_hands.set_pose("pose_rest", true)
	_check(_hands.get_hands_on_wheel() == 0, "pose de reposo con 0 manos en el volante")
	_hands.set_pose("pose_steering")
	_hands.advance(0.12)
	_check(_hands.get_hands_on_wheel() == 2, "pose de volante con 2 manos")
	_check(not _hands.is_at_target(), "transicion IK en curso")
	_hands.advance(1.0)
	_proxies.update_from_controls()
	_check(_hands.is_at_target(), "transicion IK completada")
	var steering_left := _wheel_grip("left")
	var steering_right := _wheel_grip("right")
	_check(_hands.get_hand_position("left").distance_to(steering_left) < 0.03, "mano izquierda alcanza el volante")
	_check(_hands.get_hand_position("right").distance_to(steering_right) < 0.03, "mano derecha alcanza el volante")
	_check(_proxies.get_hand_proxy_visible("left"), "proxy de mano izquierda visible")
	_check(_proxies.get_hand_proxy_position("left").distance_to(_hands.get_hand_position("left")) < 0.01, "proxy de mano izquierda sigue la IK")
	_check(_proxies.get_hand_proxy_position("right").distance_to(_hands.get_hand_position("right")) < 0.01, "proxy de mano derecha sigue la IK")
	_check(_hands.get_pose_id() == "pose_steering", "pose activa registrada")
	var grip_bone := _find_bone("hand_l_grip")
	if grip_bone >= 0:
		_check(_bone_position(grip_bone).distance_to(_hands.get_hand_position("left")) < 0.03, "hueso de agarre sigue la IK")

	_hands.set_pose("pose_gear")
	_hands.advance(1.0)
	_check(_hands.get_hands_on_wheel() == 1, "palanca con 1 mano en el volante")
	_check(_hands.get_hand_position("left").distance_to(steering_left) < 0.03, "mano izquierda permanece en el volante")
	_check(_hands.get_hand_position("right").distance_to(_proxies.get_control_position("gear_lever")) < 0.03, "mano derecha alcanza la palanca")

	_hands.set_pose("pose_handbrake")
	_hands.advance(1.0)
	_check(_hands.get_hands_on_wheel() == 1, "freno de mano con 1 mano en el volante")
	_check(_hands.get_hand_position("right").distance_to(_proxies.get_control_position("handbrake")) < 0.04, "mano derecha alcanza el freno de mano")

	_hands.set_pose("pose_door_driver")
	_hands.advance(1.0)
	_check(_hands.get_hands_on_wheel() == 0, "puerta con 0 manos en el volante")
	_check(_hands.get_hand_position("left").distance_to(_proxies.get_control_position("door_driver")) < 0.04, "mano izquierda alcanza la puerta")

	_hands.set_pose("pose_glovebox")
	_hands.advance(1.0)
	_check(_hands.get_hands_on_wheel() == 0, "guantera con 0 manos en el volante")
	_check(_hands.get_hand_position("right").distance_to(_proxies.get_control_position("glovebox")) < 0.05, "mano derecha alcanza la guantera")

	_hands.set_pose("pose_rest")
	_hands.advance(1.0)
	_check(_hands.get_hands_on_wheel() == 0, "retorno a reposo")


func _test_focus_and_touch() -> void:
	_controller.clear_focus()
	_check(_controller.focus_control("gear_lever"), "foco directo en la palanca")
	_check(_controller.get_focused_control() == "gear_lever", "palanca enfocada")
	_check(_controller.is_focus_available(), "palanca disponible")
	var gear_position := _proxies.get_control_position("gear_lever")
	var look_target := _controller.update_look(_camera.global_position, (gear_position - _camera.global_position).normalized())
	_check(look_target == "gear_lever", "reticulo enfoca la palanca al mirarla")
	var gear_screen := _camera.unproject_position(gear_position)
	_check(_controller.touch_at(gear_screen) == "gear_lever", "tacto proyecta y enfoca la palanca")
	_check(_controller.touch_at(Vector2(4, 4)).is_empty(), "tacto fuera de radio limpia el foco")
	_controller.focus_control("radio_seek")
	_check(not _controller.is_focus_available(), "radio apagada no disponible")
	_check(_controller.get_focus_hint() == _contract.get("feedback", {}).get("radio_off", ""), "pista de radio apagada")
	_controller.clear_focus()
	_check(_controller.get_focused_control().is_empty(), "foco limpio")


func _test_gear_and_powertrain() -> void:
	_controls.set_handbrake(false)
	_controls.select_gear("P")
	_check(_controls.select_gear("D"), "D aceptada desde P")
	_check(_powertrain.selector == "D", "VehiclePowertrain recibe D")
	_check(_powertrain.transmission.selector == "D", "caja automatica en D")
	_powertrain.set_speed_kph(20.0)
	_check(not _controls.select_gear("R"), "R rechazada en movimiento")
	_check(_powertrain.last_rejection == "forward_motion", "rechazo forward_motion")
	_check(not _controls.select_gear("P"), "P rechazada en movimiento")
	_check(_powertrain.last_rejection == "moving", "rechazo moving")
	_powertrain.set_speed_kph(0.0)
	_check(_controls.select_gear("P"), "P aceptada detenido")
	_check(_powertrain.selector == "P", "tren motriz de vuelta en P")
	_check(_controls.select_gear("D"), "D de nuevo para Overdrive")
	_check(_controls.toggle_overdrive(), "Overdrive se apaga en D")
	_check(not _powertrain.overdrive_enabled, "VehiclePowertrain refleja Overdrive apagado")
	_check(not _controls.get_overdrive_enabled(), "estado local de Overdrive sincronizado")
	_check(_controls.select_gear("P"), "vuelta a P para probar rechazo de Overdrive")
	_check(not _controls.toggle_overdrive(), "Overdrive rechazado fuera de D")
	_check(_powertrain.last_rejection == "overdrive_needs_drive", "rechazo overdrive_needs_drive")
	_check(_controls.select_gear("D"), "D para probar el gate")
	_check(_controls.nudge_gear(1), "gatillo avanza a 2")
	_check(_powertrain.selector == "2", "tren motriz recibe 2")
	_check(_controls.nudge_gear(-1), "gatillo vuelve a D")
	_check(_powertrain.selector == "D", "tren motriz recibe D")
	_controls.advance(0.4)
	_proxies.update_from_controls()
	_check(absf(_proxies.get_gear_angle_deg()) > 1.0, "palanca visual gira hacia D")
	_check(_powertrain.get_telemetry().get("selector", "") == "D", "telemetria del selector en D")
	_check(_powertrain.speed_mps == 0.0, "la interaccion no mueve el vehiculo")
	_controls.select_gear("P")


func _test_handbrake() -> void:
	_controls.set_handbrake(true)
	_check(_powertrain.parking_brake, "freno de mano activa el flag del tren motriz")
	_check(_powertrain.brakes.parking, "freno de mano llega a brakes.parking")
	_powertrain.simulate(0.016)
	_check(_powertrain.get_warning("parking_brake"), "aviso de freno de mano tras simulacion")
	_controls.advance(0.5)
	_proxies.update_from_controls()
	_check(absf(_proxies.get_handbrake_angle_deg()) > 1.0, "freno de mano visual se mueve")
	_controls.set_handbrake(false)
	_check(not _powertrain.parking_brake, "freno de mano liberado en el tren motriz")
	_check(not _powertrain.brakes.parking, "brakes.parking liberado")
	_powertrain.simulate(0.016)
	_check(not _powertrain.get_warning("parking_brake"), "aviso de freno de mano retirado")
	_controls.advance(0.5)
	_proxies.update_from_controls()
	_check(absf(_proxies.get_handbrake_angle_deg()) < 2.0, "freno de mano visual vuelve")


func _test_doors_and_locks() -> void:
	_powertrain.set_speed_kph(0.0)
	_controls.set_locked(false)
	_check(_controls.toggle_door("driver"), "puerta del conductor se abre")
	_check(_controls.is_door_open("driver"), "estado de puerta abierta")
	_controls.advance(1.0)
	_proxies.update_from_controls()
	_check(_proxies.get_door_angle_deg("driver") < -10.0, "puerta del conductor gira")
	_check(_controls.toggle_door("driver"), "puerta del conductor se cierra")
	_controls.advance(1.0)
	_proxies.update_from_controls()
	_check(absf(_proxies.get_door_angle_deg("driver")) < 2.0, "puerta del conductor vuelve")
	_controls.set_locked(true)
	_controller.focus_control("door_driver")
	_check(not _controller.is_focus_available(), "puerta bloqueada no disponible")
	_check(_controller.get_focus_hint() == _contract.get("feedback", {}).get("locked", ""), "pista de puerta bloqueada")
	_check(not _controls.toggle_door("driver"), "puerta bloqueada no se abre")
	_check(_controls.last_feedback == "locked", "feedback de puerta bloqueada")
	_controls.set_locked(false)
	_powertrain.set_speed_kph(20.0)
	_check(not _controls.toggle_door("passenger"), "puerta no se abre en movimiento")
	_check(_controls.last_feedback == "moving", "feedback de vehiculo en movimiento")
	_powertrain.set_speed_kph(0.0)
	_check(_controls.toggle_door("passenger"), "puerta del acompanante se abre")
	_controls.advance(1.0)
	_proxies.update_from_controls()
	_check(_proxies.get_door_angle_deg("passenger") > 10.0, "puerta del acompanante gira")
	_controls.toggle_door("passenger")
	_controls.advance(1.0)
	_controls.set_locked(false)


func _test_windows() -> void:
	var before := _proxies.get_window_glass_position("driver")
	_check(_controls.set_window_direction("window_driver", "down"), "vidrio del conductor baja")
	_controls.advance(1.0)
	_proxies.update_from_controls()
	_check(_controls.get_window_position("window_driver") > 0.3, "posicion de vidrio aumenta")
	_check(_proxies.get_window_glass_position("driver").distance_to(before) > 0.05, "vidrio visual se desplaza")
	_controls.stop_window("window_driver")
	var stopped := _controls.get_window_position("window_driver")
	_controls.advance(0.5)
	_check(is_equal_approx(stopped, _controls.get_window_position("window_driver")), "vidrio se detiene al soltar")
	_controls.last_feedback = ""
	_check(_controls.set_window_direction("window_driver", "up"), "vidrio del conductor sube")
	_controls.advance(2.5)
	_proxies.update_from_controls()
	_check(is_zero_approx(_controls.get_window_position("window_driver")), "vidrio del conductor llega al tope")
	_check(_controls.last_feedback == "window_limit", "feedback de tope de vidrio")
	_controls.set_window_direction("window_passenger", "down")
	_controls.advance(0.6)
	_controls.stop_window("window_passenger")
	_check(_controls.get_window_position("window_passenger") > 0.1, "vidrio del acompanante baja")
	_controls.set_window_direction("window_passenger", "up")
	_controls.advance(2.5)
	_check(is_zero_approx(_controls.get_window_position("window_passenger")), "vidrio del acompanante sube")


func _test_lights_antenna_radio_glovebox() -> void:
	_check(_controls.lights_state == "off", "luces inician apagadas")
	_check(_controls.cycle_lights() == "parking", "luces pasan a posicion")
	_proxies.update_from_controls()
	_check(_proxies.get_lights_indicator_color().r > 0.5, "testigo de luces encendido")
	_check(_controls.cycle_lights() == "headlights", "luces pasan a carretera")
	_check(_controls.cycle_lights() == "off", "luces vuelven a apagadas")
	_check(_controls.toggle_antenna(), "antena se extiende")
	_controls.advance(1.0)
	_proxies.update_from_controls()
	_check(_controls.get_antenna_extension() > 0.95, "antena extendida por completo")
	_check(_proxies.get_antenna_length() > 0.5, "mastil de antena visible")
	_check(_controls.radio_toggle_power(), "radio se enciende")
	_check(_controls.radio.power_on, "estado de radio encendida")
	_check(_controls.radio.is_audio_ready(), "radio con stream procedural")
	_check(_controls.radio.signal_strength > 0.9, "antena extendida mejora la senal")
	var first_station := _controls.radio.get_station_frequency()
	var sought := _controls.radio_seek()
	_check(not is_equal_approx(first_station, sought), "busqueda cambia de emisora")
	_check(_controls.radio_cycle_band() == "FM", "banda cambia a FM")
	_check(_controls.radio.station_index == 0, "cambio de banda reinicia emisora")
	var volume_before := _controls.radio.volume_step
	_check(_controls.radio_volume(1) == volume_before + 1, "volumen sube")
	for _index in range(20):
		_controls.radio_volume(-1)
	_check(_controls.radio.volume_step == 0, "volumen llega a cero")
	_check(_controls.radio_volume(1) == 1, "volumen vuelve a subir")
	_controls.toggle_antenna()
	_controls.advance(1.0)
	_proxies.update_from_controls()
	_check(_controls.get_antenna_extension() < 0.05, "antena se recoge")
	_check(_controls.radio.signal_strength < 0.6, "antena recogida empeora la senal")
	_check(_proxies.get_antenna_length() < 0.1, "mastil de antena recogido")
	_check(_controls.toggle_glovebox(), "guantera se abre")
	_controls.advance(1.0)
	_proxies.update_from_controls()
	_check(_proxies.get_glovebox_angle_deg() < -10.0, "guantera gira")
	_check(not _controls.toggle_glovebox(), "guantera se cierra")
	_controls.advance(1.0)
	_proxies.update_from_controls()
	_check(absf(_proxies.get_glovebox_angle_deg()) < 2.0, "guantera vuelve")
	_controls.radio_toggle_power()
	_check(not _controls.radio.power_on, "radio se apaga")
	_controls.last_feedback = ""
	_check(_controls.radio_seek() == 0.0, "radio apagada no busca")
	_check(_controls.last_feedback == "radio_off", "feedback de radio apagada")


func _test_controller_flow() -> void:
	_controller.clear_focus()
	_controls.select_gear("P")
	_controls.set_handbrake(false)
	_controls.set_locked(false)
	_controller.focus_control("window_driver_down")
	var pressed := _controller.press_focused()
	_check(pressed, "pulsacion contextual de vidrio")
	_controller.advance(0.5)
	_check(_controls.get_window_position("window_driver") > 0.1, "pulsacion mueve el vidrio")
	_controller.release_focused()
	var after_release := _controls.get_window_position("window_driver")
	_controller.advance(0.3)
	_check(is_equal_approx(after_release, _controls.get_window_position("window_driver")), "soltar detiene el vidrio")

	_controller.focus_control("radio_power")
	_controller.press_focused()
	_check(_controls.radio.power_on, "pulsacion enciende la radio")
	_controller.release_focused()
	_controller.advance(0.6)
	_check(_controller.get_hands_on_wheel() == 0, "manos vuelven al reposo tras pulsar")
	_controls.radio_toggle_power()

	_controller.focus_control("gear_lever")
	_controller.press_focused()
	_check(_controller.get_hands_on_wheel() == 1, "palanca deja 1 mano en el volante")
	_controller.drag_focused(Vector2(0.0, 80.0))
	_check(_powertrain.selector == "D", "arrastre de palanca llega a D desde P")
	_controller.release_focused()
	_controller.advance(0.5)
	_controls.select_gear("P")

	_controller.focus_control("steering_wheel")
	_controller.press_focused()
	_controller.advance(0.4)
	_check(_controller.get_hands_on_wheel() == 2, "volante con dos manos IK")
	_controller.release_focused()
	_controller.advance(0.6)
	_check(_controller.get_hands_on_wheel() == 0, "soltar el volante vuelve a reposo")

	_controls.set_locked(true)
	_controller.focus_control("door_driver")
	_controller.press_focused()
	_check(_controller.get_last_feedback() == "locked", "feedback contextual de puerta bloqueada")
	_controller.release_focused()
	_controls.set_locked(false)
	_controls.set_window_direction("window_driver", "up")
	_controls.advance(2.5)
	_controls.set_handbrake(false)


func _test_no_duplicate_mechanics() -> void:
	var selector_before := _powertrain.selector
	var speed_before := _powertrain.speed_mps
	_controls.select_gear("N")
	_check(_powertrain.selector == "N", "la palanca usa el selector del contrato")
	_check(is_equal_approx(speed_before, _powertrain.speed_mps), "cambiar de marcha no altera la velocidad")
	_controls.select_gear(selector_before)
	var brake_before := _powertrain.parking_brake
	_controls.toggle_handbrake()
	_check(_powertrain.parking_brake != brake_before, "el freno de mano usa el flag del contrato")
	_controls.toggle_handbrake()
	_check(_powertrain.parking_brake == brake_before, "el freno de mano se restaura")
	_check(_powertrain.get_telemetry().get("selector", "") == _powertrain.selector, "telemetria coherente")
	_check(_powertrain.get_telemetry().get("parking_brake", null) == _powertrain.parking_brake, "telemetria de freno coherente")


func _read_csv() -> Array:
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		return []
	var rows: Array = []
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() == 0:
			continue
		rows.append(row)
	return rows


func _wheel_grip(side: String) -> Vector3:
	var offset: Array = _contract.get("hands", {}).get("wheel", {}).get("%s_grip_offset_m" % side, [])
	var center := _proxies.get_control_position("steering_wheel")
	if offset.size() != 3:
		return center
	return center + Vector3(float(offset[0]), float(offset[1]), float(offset[2]))


func _anchor(anchor_id: String) -> Vector3:
	for entry in _cabin_spec.get("rig_anchor", {}).get("anchors", []):
		if entry is Dictionary and str(entry.get("id", "")) == anchor_id:
			var position: Array = entry.get("position_m", [])
			if position.size() == 3:
				return Vector3(float(position[0]), float(position[1]), float(position[2]))
	return Vector3.ZERO


func _find_skeleton() -> Skeleton3D:
	return _find_first_by_class(_scene, ["Skeleton3D"]) as Skeleton3D


func _find_bone(bone_name: String) -> int:
	var skeleton := _find_skeleton()
	return skeleton.find_bone(bone_name) if skeleton != null else -1


func _bone_position(bone: int) -> Vector3:
	var skeleton := _find_skeleton()
	return skeleton.get_bone_pose_position(bone) if skeleton != null else Vector3.ZERO


func _find_first_by_class(node: Node, class_names: Array) -> Node:
	if node == null:
		return null
	for class_name_value in class_names:
		if node.is_class(str(class_name_value)):
			return node
	for child in node.get_children():
		var found := _find_first_by_class(child, class_names)
		if found != null:
			return found
	return null


func _find_name_containing(node: Node, fragment: String) -> Node:
	if node == null:
		return null
	if str(node.name).to_lower().contains(fragment.to_lower()):
		return node
	for child in node.get_children():
		var found := _find_name_containing(child, fragment)
		if found != null:
			return found
	return null


func _count_class(node: Node, class_name_value: String) -> int:
	if node == null:
		return 0
	var count := 1 if node.is_class(class_name_value) else 0
	for child in node.get_children():
		count += _count_class(child, class_name_value)
	return count


func _finish() -> void:
	if _controls != null and _controls.radio != null:
		_controls.radio.shutdown()
	if _scene != null:
		_scene.queue_free()
	await get_tree().process_frame
	if _failed.is_empty():
		print("[INTERACTION] OK %d comprobaciones" % _passed)
		get_tree().quit(0)
		return
	print("[INTERACTION] Fallaron %d de %d comprobaciones:" % [_failed.size(), _passed + _failed.size()])
	for failure in _failed:
		print("[INTERACTION]   - %s" % failure)
	print("[INTERACTION] FAIL")
	get_tree().quit(1)
