extends SceneTree
## Diagnóstico temporal de posiciones de cabina (se elimina tras la medición).

var _done := false


func _initialize() -> void:
	var packed := load("res://scenes/vehicle/CabinInteraction.tscn") as PackedScene
	if packed == null:
		print("DIAG no se pudo cargar la escena")
		quit(1)
		return
	root.add_child(packed.instantiate())


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	var scene := root.get_child(root.get_child_count() - 1)
	var names := [
		"steering_rim", "steering_hub", "steering_spoke_0", "steering_spoke_1",
		"steering_spoke_2", "instrument_cluster", "radio_double_din",
		"gear_knob", "gear_shaft", "handbrake_lever",
	]
	for node_name in names:
		var node := scene.find_child(node_name, true, false) as Node3D
		if node == null:
			print("DIAG %-20s NO ENCONTRADO" % node_name)
			continue
		var aabb := _aabb_of(node)
		print(
			"DIAG %-20s global=%s aabb_pos=%s aabb_size=%s"
			% [node_name, node.global_position, aabb.position, aabb.size]
		)
	var camera := _find_camera(scene)
	if camera != null:
		print("DIAG camera global=%s rot_deg=%s fov=%s near=%s" % [camera.global_position, camera.global_rotation_degrees, camera.fov, camera.near])
		var controller := scene.find_child("Interaction", true, false)
		var controls := scene.find_child("Controls", true, false)
		if controller != null and controls != null and controls.has_method("get_control_position"):
			var ids: Array = controller.get("spec").control_ids() if controller.get("spec") != null else []
			for control_id in ids:
				var world: Vector3 = controls.call("get_control_position", control_id)
				var behind := camera.is_position_behind(world)
				var screen := camera.unproject_position(world)
				print("DIAG ctrl %-18s world=%s screen=(%d,%d) behind=%s" % [control_id, world, int(screen.x), int(screen.y), behind])
	for group_name in ["SteeringGroup", "GearGateGroup", "CenterStackControlsGroup", "GloveboxGroup"]:
		var group := scene.find_child(group_name, true, false) as Node3D
		if group != null:
			print("DIAG group %-24s global=%s rot_deg=%s" % [group_name, group.global_position, group.global_rotation_degrees])
	var rim := scene.find_child("steering_rim", true, false) as Node3D
	if rim != null:
		var parent := rim.get_parent()
		print("DIAG rim parent=%s parent_rot=%s parent_pos=%s" % [parent.name, (parent as Node3D).global_rotation_degrees if parent is Node3D else "-", (parent as Node3D).global_position if parent is Node3D else "-"])
		print("DIAG rim visible=%s" % rim.is_visible_in_tree())
	quit(0)
	return true


func _find_camera(node: Node) -> Camera3D:
	if node is Camera3D:
		return node
	for child in node.get_children():
		var found := _find_camera(child)
		if found != null:
			return found
	return null


func _aabb_of(node: Node3D) -> AABB:
	var aabb := AABB()
	var first := true
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is MeshInstance3D:
			var mesh := (current as MeshInstance3D).mesh as ArrayMesh
			if mesh != null:
				var local: AABB = (current as Node3D).global_transform * mesh.get_aabb()
				aabb = local if first else aabb.merge(local)
				first = false
		for child in current.get_children():
			stack.append(child)
	return aabb
