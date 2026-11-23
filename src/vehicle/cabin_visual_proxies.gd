class_name CabinVisualProxies
extends Node3D
## Retorno visual de la interaccion sobre el bloqueo de cabina.
##
## El bloqueo de F2.2 coloco algunos controles dentro de las cajas solidas del
## tablero y la consola. F2.3 aplica un desplazamiento funcional a la cara del
## conductor y genera primitivas reproducibles para vidrios, antena, testigos y
## botones que el greybox no modela. No son arte final ni assets de la fabrica:
## el vidrio y la antena definitivos son F3.1/F3.2. Solo se anima LOD0.

var spec: CabinInteractionSpec
var controls: CabinControls
var hands: HandIKDriver
var cabin_spec: Dictionary = {}
var cabin: Node3D
var lod0: Node3D

var _pivots: Dictionary = {}
var _control_nodes: Dictionary = {}
var _glass: Dictionary = {}
var _indicator_materials: Dictionary = {}
var _hand_proxies: Dictionary = {}
var _antenna_mast: MeshInstance3D
var _lights_indicator: MeshInstance3D
var _radio_indicator: MeshInstance3D
var _lock_indicator: MeshInstance3D
var _configured := false


func _ready() -> void:
	set_process(true)


func configure(cabin_in: Node3D, spec_in: CabinInteractionSpec, controls_in: CabinControls, cabin_spec_in: Dictionary) -> void:
	cabin = cabin_in
	spec = spec_in
	controls = controls_in
	cabin_spec = cabin_spec_in
	lod0 = cabin.get_node_or_null("LOD0") as Node3D
	if lod0 == null:
		lod0 = cabin.find_child("LOD0", true, false) as Node3D
	if lod0 == null:
		push_error("[CABIN_PROXIES] No se encontro el nodo LOD0")
		return
	_build_steering_group()
	_build_gear_group()
	_build_handbrake_pivot()
	_build_center_stack_group()
	_build_glovebox_group()
	_build_door_pivots()
	_build_glass()
	_build_antenna()
	_build_control_proxies()
	_build_indicators()
	_map_existing_controls()
	_configured = true
	update_from_controls()


func bind_hands(hands_in: HandIKDriver) -> void:
	hands = hands_in
	_build_hand_proxies()
	_update_hand_proxies()


func _process(_delta: float) -> void:
	if _configured:
		update_from_controls()


func update_from_controls() -> void:
	if not _configured or controls == null:
		return
	_update_doors()
	_update_gear()
	_update_handbrake()
	_update_glovebox()
	_update_glass()
	_update_antenna()
	_update_indicators()
	_update_hand_proxies()


func get_control_position(control_id: String) -> Vector3:
	if _control_nodes.has(control_id):
		var node: Node = _control_nodes[control_id]
		if is_instance_valid(node) and node is Node3D:
			return (node as Node3D).global_position
	var control := spec.control(control_id) if spec != null else {}
	return _array_vector3(control.get("interaction_position_m", control.get("position_m", [])))


func get_door_angle_deg(door_id: String) -> float:
	var pivot: Node3D = _pivots.get("door_" + door_id, null)
	return rad_to_deg(pivot.rotation.y) if pivot != null else 0.0


func get_window_glass_position(side: String) -> Vector3:
	if not _glass.has(side):
		return Vector3.ZERO
	var entry: Dictionary = _glass[side]
	var mesh: MeshInstance3D = entry.get("node", null)
	return mesh.global_position if mesh != null else Vector3.ZERO


func get_antenna_length() -> float:
	return _antenna_mast.scale.y if _antenna_mast != null else 0.0


func get_gear_angle_deg() -> float:
	var pivot: Node3D = _pivots.get("gear", null)
	return rad_to_deg(pivot.rotation.x) if pivot != null else 0.0


func get_handbrake_angle_deg() -> float:
	var pivot: Node3D = _pivots.get("handbrake", null)
	return rad_to_deg(pivot.rotation.x) if pivot != null else 0.0


func get_glovebox_angle_deg() -> float:
	var pivot: Node3D = _pivots.get("glovebox", null)
	return rad_to_deg(pivot.rotation.x) if pivot != null else 0.0


func get_lights_indicator_color() -> Color:
	return _indicator_color(_lights_indicator)


func get_radio_indicator_color() -> Color:
	return _indicator_color(_radio_indicator)


func get_lock_indicator_color() -> Color:
	return _indicator_color(_lock_indicator)


func get_control_node(control_id: String) -> Node:
	return _control_nodes.get(control_id, null)


func get_hand_proxy_position(side: String) -> Vector3:
	var mesh: MeshInstance3D = _hand_proxies.get(side, null)
	return mesh.global_position if mesh != null else Vector3.ZERO


func get_hand_proxy_visible(side: String) -> bool:
	var mesh: MeshInstance3D = _hand_proxies.get(side, null)
	return mesh.visible if mesh != null else false


func _build_hand_proxies() -> void:
	if not _hand_proxies.is_empty():
		return
	var size := _array_vector3(spec.section("visual_proxies").get("hand_proxy_size_m", [0.055, 0.03, 0.12]))
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.62, 0.58, 0.52)
	material.roughness = 0.86
	for side in ["left", "right"]:
		# F3.2: manos definitivas con malla propia (interior_spec.json, objetos
		# hand_left/hand_right del LOD0). Se reubican con la IK de F2.2 igual que
		# los proxies; si la malla no existe (greybox de F2.2) se conserva el
		# proxy de caja. El contrato de interaccion no cambia.
		var hand := lod0.find_child("hand_%s" % side, true, false) as MeshInstance3D
		if hand != null:
			hand.reparent(self, true)
			_hand_proxies[side] = hand
		else:
			var mesh := _make_box("HandProxy%s" % side.capitalize(), Vector3.ZERO, size, material, self)
			_hand_proxies[side] = mesh


func _update_hand_proxies() -> void:
	if hands == null or _hand_proxies.is_empty():
		return
	for side in _hand_proxies.keys():
		var mesh: MeshInstance3D = _hand_proxies[side]
		if mesh == null:
			continue
		var position := hands.get_hand_position(str(side))
		var direction := hands.get_hand_direction(str(side))
		mesh.visible = position.length_squared() > 0.0001
		mesh.global_position = position
		if direction.length_squared() > 0.0001:
			var up := Vector3.UP
			if absf(direction.normalized().dot(up)) > 0.99:
				up = Vector3.FORWARD
			mesh.look_at(position + direction.normalized(), up)


func _build_steering_group() -> void:
	var offset := _offset("steering_wheel_m")
	var group := _make_group("SteeringGroup", offset)
	for node_name in ["steering_rim", "steering_hub", "steering_spoke_0", "steering_spoke_1", "steering_spoke_2", "steering_column"]:
		_reparent_to_group(node_name, group)


func _build_gear_group() -> void:
	var offset := _offset("gear_gate_m")
	var group := _make_group("GearGateGroup", offset)
	for index in range(6):
		_reparent_to_group("gear_gate_plate_notch_%d" % index, group)
	_reparent_to_group("gear_gate_plate", group)
	var pivot_position := _array_vector3(spec.section("gear_gate").get("pivot_m", []))
	var pivot := Node3D.new()
	pivot.name = "GearLeverPivot"
	pivot.position = pivot_position
	group.add_child(pivot)
	for node_name in ["gear_knob", "gear_shaft", "gear_od_button"]:
		_reparent_to_pivot(node_name, pivot)
	_pivots["gear"] = pivot


func _build_handbrake_pivot() -> void:
	var anchor := _anchor_position("anchor_handbrake")
	var pivot := Node3D.new()
	pivot.name = "HandbrakePivot"
	pivot.position = anchor
	lod0.add_child(pivot)
	for node_name in ["handbrake_lever", "handbrake_grip"]:
		_reparent_to_pivot(node_name, pivot)
	_pivots["handbrake"] = pivot


func _build_center_stack_group() -> void:
	var offset := _offset("center_stack_controls_m")
	var group := _make_group("CenterStackControlsGroup", offset)
	for node_name in ["radio_double_din", "radio_double_din_slot", "climate_controls"]:
		_reparent_to_group(node_name, group)


func _build_glovebox_group() -> void:
	var offset := _offset("glovebox_m")
	var group := _make_group("GloveboxGroup", offset)
	var component: Dictionary = cabin_spec.get("components", {}).get("glovebox", {})
	var bounds_min := _array_vector3(component.get("min_m", []))
	var bounds_max := _array_vector3(component.get("max_m", []))
	var hinge := Vector3(
		(bounds_min.x + bounds_max.x) * 0.5,
		bounds_max.y,
		bounds_max.z
	)
	var pivot := Node3D.new()
	pivot.name = "GloveboxPivot"
	pivot.position = hinge
	group.add_child(pivot)
	for node_name in ["glovebox", "glovebox_latch"]:
		_reparent_to_pivot(node_name, pivot)
	_pivots["glovebox"] = pivot


func _build_door_pivots() -> void:
	var doors: Dictionary = spec.section("doors")
	var proxy_size := _array_vector3(spec.section("visual_proxies").get("control_proxy_size_m", [0.024, 0.012, 0.012]))
	for door_id in ["driver", "passenger"]:
		var hinge := _array_vector3(doors.get("hinge_m", {}).get(door_id, []))
		var pivot := Node3D.new()
		pivot.name = "DoorPivot%s" % door_id.capitalize()
		pivot.position = hinge
		lod0.add_child(pivot)
		_pivots["door_" + door_id] = pivot
		_reparent_prefix("door_panel_%s" % door_id, pivot)
		var handle_position := _interaction_position("door_" + door_id) - hinge
		var handle := _make_box(
			"proxy_door_%s_handle" % door_id,
			handle_position,
			Vector3(0.012, 0.05, 0.08),
			_plastic_material(),
			pivot
		)
		_control_nodes["door_" + door_id] = handle
		for direction in ["up", "down"]:
			var control_id := "window_%s_%s" % [door_id, direction]
			var window_position := _interaction_position(control_id) - hinge
			var switch_node := _make_box(
				"proxy_" + control_id,
				window_position,
				proxy_size,
				_plastic_material(),
				pivot
			)
			_control_nodes[control_id] = switch_node
	var driver_hinge := _array_vector3(doors.get("hinge_m", {}).get("driver", []))
	var lock_node := _make_box(
		"proxy_central_lock",
		_interaction_position("central_lock") - driver_hinge,
		proxy_size,
		_plastic_material(),
		_pivots["door_driver"]
	)
	_control_nodes["central_lock"] = lock_node


func _build_glass() -> void:
	var glass_spec: Dictionary = spec.section("windows").get("glass", {})
	var size := _array_vector3(glass_spec.get("size_m", [0.006, 0.28, 0.72]))
	var open_offset := _array_vector3(glass_spec.get("open_offset_m", [0.0, -0.22, 0.0]))
	for side in ["driver", "passenger"]:
		var hinge := _array_vector3(spec.section("doors").get("hinge_m", {}).get(side, []))
		var closed_center := _array_vector3(glass_spec.get("closed_center_m", {}).get(side, []))
		var mesh := MeshInstance3D.new()
		mesh.name = "WindowGlass%s" % side.capitalize()
		var box := BoxMesh.new()
		box.size = size
		mesh.mesh = box
		mesh.material_override = _glass_material()
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var pivot: Node3D = _pivots["door_" + side]
		pivot.add_child(mesh)
		mesh.position = closed_center - hinge
		_glass[side] = {
			"node": mesh,
			"base": closed_center - hinge,
			"offset": open_offset,
		}


func _build_antenna() -> void:
	var antenna: Dictionary = spec.section("antenna")
	var base := _array_vector3(antenna.get("base_m", []))
	var mesh := MeshInstance3D.new()
	mesh.name = "antenna_mast"
	var cylinder := CylinderMesh.new()
	cylinder.height = 1.0
	cylinder.top_radius = 0.004
	cylinder.bottom_radius = 0.008
	cylinder.radial_segments = 6
	mesh.mesh = cylinder
	mesh.material_override = _plastic_material()
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lod0.add_child(mesh)
	mesh.position = base + Vector3(0.0, 0.5, 0.0)
	mesh.scale = Vector3(1.0, float(antenna.get("retracted_length_m", 0.06)), 1.0)
	_antenna_mast = mesh


func _build_control_proxies() -> void:
	var proxy_size := _array_vector3(spec.section("visual_proxies").get("control_proxy_size_m", [0.024, 0.012, 0.012]))
	for control_id in ["lights", "antenna", "radio_power", "radio_band", "radio_seek", "radio_volume_up", "radio_volume_down"]:
		var position := _interaction_position(control_id)
		var size := proxy_size
		if control_id == "lights":
			size = Vector3(0.012, 0.012, 0.08)
		var node := _make_box("proxy_" + control_id, position, size, _plastic_material(), lod0)
		_control_nodes[control_id] = node
	var glovebox_node := _make_box(
		"proxy_glovebox_latch",
		_interaction_position("glovebox"),
		Vector3(0.04, 0.02, 0.012),
		_plastic_material(),
		lod0
	)
	_control_nodes["glovebox"] = glovebox_node


func _build_indicators() -> void:
	var visual: Dictionary = spec.section("visual_proxies")
	_lights_indicator = _make_indicator(
		"LightsIndicator",
		_array_vector3(visual.get("lights_indicator_m", [])),
		0.012,
		lod0
	)
	_radio_indicator = _make_indicator(
		"RadioIndicator",
		_array_vector3(visual.get("radio_indicator_m", [])),
		0.01,
		lod0
	)
	var lock_position := _array_vector3(visual.get("lock_indicator_m", []))
	var driver_hinge := _array_vector3(spec.section("doors").get("hinge_m", {}).get("driver", []))
	_lock_indicator = _make_indicator(
		"LockIndicator",
		lock_position - driver_hinge,
		0.01,
		_pivots["door_driver"]
	)


func _map_existing_controls() -> void:
	var map := {
		"steering_wheel": "steering_hub",
		"gear_lever": "gear_knob",
		"overdrive_button": "gear_od_button",
		"handbrake": "handbrake_grip",
	}
	for control_id in map.keys():
		var node := lod0.find_child(str(map[control_id]), true, false)
		if node != null:
			_control_nodes[control_id] = node


func _update_doors() -> void:
	var doors: Dictionary = spec.section("doors")
	var angles: Dictionary = doors.get("open_angle_deg", {})
	for door_id in ["driver", "passenger"]:
		var pivot: Node3D = _pivots.get("door_" + door_id, null)
		if pivot != null:
			var angle := float(angles.get(door_id, 0.0))
			pivot.rotation.y = deg_to_rad(angle * controls.get_door_openness(door_id))


func _update_gear() -> void:
	var pivot: Node3D = _pivots.get("gear", null)
	if pivot == null:
		return
	var detents: Array = spec.array("gear_gate.detents")
	if detents.is_empty():
		return
	var index := clampf(controls.get_gear_visual_index(), 0.0, float(detents.size() - 1))
	var lower := floori(index)
	var upper := mini(lower + 1, detents.size() - 1)
	var blend := index - float(lower)
	var detent_lower: Dictionary = detents[lower]
	var detent_upper: Dictionary = detents[upper]
	var z0 := float(detent_lower.get("position_m", [0, 0, 0])[2])
	var z1 := float(detent_upper.get("position_m", [0, 0, 0])[2])
	var target_z := lerpf(z0, z1, blend)
	var pivot_z := float(spec.section("gear_gate").get("pivot_m", [0, 0, 0])[2])
	var lever_length := maxf(0.01, spec.number("gear_gate.lever_length_m", 0.16))
	pivot.rotation.x = atan2(target_z - pivot_z, lever_length)


func _update_handbrake() -> void:
	var pivot: Node3D = _pivots.get("handbrake", null)
	if pivot == null:
		return
	var spec_handbrake: Dictionary = spec.section("handbrake")
	var released := float(spec_handbrake.get("released_angle_deg", 0.0))
	var engaged := float(spec_handbrake.get("engaged_angle_deg", 0.0))
	pivot.rotation.x = deg_to_rad(lerpf(released, engaged, controls.get_handbrake_amount()))


func _update_glovebox() -> void:
	var pivot: Node3D = _pivots.get("glovebox", null)
	if pivot == null:
		return
	var angle := spec.number("glovebox.open_angle_deg", -38.0)
	pivot.rotation.x = deg_to_rad(angle * controls.get_glovebox_openness())


func _update_glass() -> void:
	for side in _glass.keys():
		var entry: Dictionary = _glass[side]
		var mesh: MeshInstance3D = entry.get("node", null)
		if mesh == null:
			continue
		var base: Vector3 = entry.get("base", Vector3.ZERO)
		var offset: Vector3 = entry.get("offset", Vector3.ZERO)
		mesh.position = base + offset * controls.get_window_position(str(side))


func _update_antenna() -> void:
	if _antenna_mast == null:
		return
	var antenna: Dictionary = spec.section("antenna")
	var base := _array_vector3(antenna.get("base_m", []))
	var retracted := float(antenna.get("retracted_length_m", 0.06))
	var extended := float(antenna.get("extended_length_m", 0.55))
	var length := lerpf(retracted, extended, controls.get_antenna_extension())
	_antenna_mast.scale = Vector3(1.0, maxf(0.01, length), 1.0)
	_antenna_mast.position = base + Vector3(0.0, length * 0.5, 0.0)
	_antenna_mast.visible = length > 0.02


func _update_indicators() -> void:
	var lights := controls.lights_state
	var lights_color := Color(0.15, 0.15, 0.14)
	if lights == "parking":
		lights_color = Color(1.0, 0.62, 0.12)
	elif lights == "headlights":
		lights_color = Color(0.85, 0.95, 1.0)
	_set_indicator(_lights_indicator, lights_color, lights != "off")
	var radio_on := controls.radio != null and controls.radio.power_on
	_set_indicator(_radio_indicator, Color(1.0, 0.72, 0.2), radio_on)
	_set_indicator(
		_lock_indicator,
		Color(0.95, 0.25, 0.2) if controls.is_locked() else Color(0.25, 0.9, 0.45),
		true
	)


func _make_group(node_name: String, offset: Vector3) -> Node3D:
	var group := Node3D.new()
	group.name = node_name
	group.position = offset
	lod0.add_child(group)
	return group


func _make_box(node_name: String, position: Vector3, size: Vector3, material: Material, parent: Node3D) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	mesh.position = position
	return mesh


func _make_indicator(node_name: String, position: Vector3, radius: float, parent: Node3D) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 8
	sphere.rings = 4
	mesh.mesh = sphere
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.15, 0.15, 0.14)
	material.emission_enabled = false
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	mesh.position = position
	_indicator_materials[mesh] = material
	return mesh


func _set_indicator(mesh: MeshInstance3D, color: Color, on: bool) -> void:
	if mesh == null:
		return
	var material: StandardMaterial3D = _indicator_materials.get(mesh, null)
	if material == null:
		return
	material.albedo_color = color if on else Color(0.12, 0.12, 0.11)
	material.emission_enabled = on
	material.emission = color
	material.emission_energy_multiplier = 1.8 if on else 0.0


func _indicator_color(mesh: MeshInstance3D) -> Color:
	if mesh == null:
		return Color.BLACK
	var material: StandardMaterial3D = _indicator_materials.get(mesh, null)
	return material.emission if material != null else Color.BLACK


func _reparent_prefix(prefix: String, pivot: Node3D) -> void:
	var to_move: Array[Node] = []
	for child in lod0.get_children():
		if child is Node3D and str(child.name).begins_with(prefix):
			to_move.append(child)
	for node in to_move:
		node.reparent(pivot, true)


func _reparent_to_group(node_name: String, group: Node3D) -> void:
	var node := lod0.find_child(node_name, true, false)
	if node != null:
		node.reparent(group, false)


func _reparent_to_pivot(node_name: String, pivot: Node3D) -> void:
	var node := lod0.find_child(node_name, true, false)
	if node == null:
		return
	node.reparent(pivot, false)
	node.position -= pivot.position


func _offset(field: String) -> Vector3:
	return _array_vector3(spec.section("visual_offsets").get(field, []))


func _interaction_position(control_id: String) -> Vector3:
	var control := spec.control(control_id)
	return _array_vector3(control.get("interaction_position_m", control.get("position_m", [])))


func _anchor_position(anchor_id: String) -> Vector3:
	for entry in cabin_spec.get("rig_anchor", {}).get("anchors", []):
		if entry is Dictionary and str(entry.get("id", "")) == anchor_id:
			return _array_vector3(entry.get("position_m", []))
	return Vector3.ZERO


func _array_vector3(value: Variant) -> Vector3:
	if value is Array and value.size() == 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO


func _plastic_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.21, 0.23)
	material.roughness = 0.72
	material.metallic = 0.15
	return material


func _glass_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	var values: Array = spec.section("visual_proxies").get("window_glass_material", {}).get("albedo", [0.35, 0.45, 0.5, 0.35])
	if values.size() == 4:
		material.albedo_color = Color(float(values[0]), float(values[1]), float(values[2]), float(values[3]))
	material.roughness = float(spec.section("visual_proxies").get("window_glass_material", {}).get("roughness", 0.12))
	material.metallic = 0.2
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
