extends Node
## Pruebas headless de la cabina funcional y del rig de manos (Fase 2.2).
##
## Ejecutar:
##   .\tools\dev\cabin_test.cmd
## El proceso devuelve 0 solo si el manifiesto de la cabina carga, los LOD0/1/2
## decrecen y coinciden con el manifiesto, el rig de manos contiene las anclas
## anchor_* del bloqueo (compatibilidad), las poses IK existen y la escena no
## introduce fisica de conduccion.

const MANIFEST_PATH := "res://assets/manifests/esteem_cabin.manifest.json"
const SPEC_PATH := "res://data/vehicle/cabin_spec.json"
const BLOCKOUT_SPEC_PATH := "res://data/vehicle/blockout_spec.json"
const SCENE_PATH := "res://scenes/vehicle/EsteemCabin.tscn"

var _passed := 0
var _failed: Array[String] = []


func _ready() -> void:
	print("[CABIN] Inicio de pruebas de la cabina y el rig de manos")
	await get_tree().process_frame
	await get_tree().process_frame
	_test_manifest()
	await _test_scene_lods()
	await _test_hand_rig_and_anchors()
	_test_ik_poses()
	await _test_no_physics()
	_finish()


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("[CABIN] OK   %s" % label)
	else:
		_failed.append(label)
		print("[CABIN] FAIL %s" % label)


func _load_json(path: String) -> Variant:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return null
	return JSON.parse_string(text)


func _count_triangles(node: Node) -> int:
	var total := 0
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		total += (node as MeshInstance3D).mesh.get_faces().size() / 3
	for child in node.get_children():
		total += _count_triangles(child)
	return total


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null


func _find_first(node: Node, type_names: Array) -> Node:
	for child in node.get_children():
		for type_name in type_names:
			if child.is_class(type_name):
				return child
		var found := _find_first(child, type_names)
		if found != null:
			return found
	return null


func _test_manifest() -> void:
	var manifest: Variant = _load_json(MANIFEST_PATH)
	_check(manifest is Dictionary, "manifiesto de la cabina presente")
	if not (manifest is Dictionary):
		return
	var outputs: Array = manifest.get("outputs", [])
	_check(outputs.size() == 4, "manifiesto con cuatro salidas (LOD0/1/2 + rig)")
	var lod_triangles := {}
	for output in outputs:
		if not (output is Dictionary):
			continue
		var relative := str(output.get("file", ""))
		var path := "res://" + relative
		_check(FileAccess.file_exists(path), "salida generada %s" % relative)
		var expected_hash := str(output.get("sha256", ""))
		if not expected_hash.is_empty() and FileAccess.file_exists(path):
			_check(FileAccess.get_sha256(path) == expected_hash, "hash SHA-256 verificado en %s" % relative)
		if str(output.get("kind", "")) == "mesh_lod":
			lod_triangles[int(output.get("lod", -1))] = int(output.get("triangles", 0))
	_check(lod_triangles.has(0) and lod_triangles.has(1) and lod_triangles.has(2), "LOD0/LOD1/LOD2 declarados")
	_check(
		int(lod_triangles.get(0, 0)) > int(lod_triangles.get(1, 0))
			and int(lod_triangles.get(1, 0)) > int(lod_triangles.get(2, 0)),
		"triangulos decrecientes entre LODs en el manifiesto"
	)
	_check(int(lod_triangles.get(0, 0)) <= 12000, "LOD0 dentro de su presupuesto de 12000 triangulos")
	_check(int(lod_triangles.get(0, 0)) <= 120000, "LOD0 dentro del presupuesto movil global")


func _test_scene_lods() -> void:
	var manifest: Variant = _load_json(MANIFEST_PATH)
	var spec: Variant = _load_json(SPEC_PATH)
	_check(spec is Dictionary, "spec de la cabina accesible")
	var packed := load(SCENE_PATH) as PackedScene
	_check(packed != null, "escena EsteemCabin carga")
	if packed == null:
		return
	var cabin := packed.instantiate()
	add_child(cabin)
	var manifest_tris := {}
	if manifest is Dictionary:
		for output in manifest.get("outputs", []):
			if output is Dictionary and str(output.get("kind", "")) == "mesh_lod":
				manifest_tris[int(output.get("lod", -1))] = int(output.get("triangles", 0))
	var previous_triangles := 1 << 30
	for lod_index in range(3):
		var lod_node := cabin.get_node_or_null("LOD%d" % lod_index)
		_check(lod_node != null, "nodo LOD%d en la escena" % lod_index)
		if lod_node == null:
			continue
		var triangles := _count_triangles(lod_node)
		_check(triangles > 0, "mallas del LOD%d con triangulos" % lod_index)
		_check(triangles == int(manifest_tris.get(lod_index, -1)), "triangulos del LOD%d coinciden con el manifiesto" % lod_index)
		_check(triangles < previous_triangles, "LOD%d menor que el nivel anterior" % lod_index)
		previous_triangles = triangles
	var lod0 := cabin.get_node_or_null("LOD0") as Node3D
	var lod1 := cabin.get_node_or_null("LOD1") as Node3D
	var lod2 := cabin.get_node_or_null("LOD2") as Node3D
	_check(
		lod0 != null and lod0.visible and lod1 != null and not lod1.visible and lod2 != null and not lod2.visible,
		"solo LOD0 visible en la escena"
	)
	cabin.queue_free()
	await get_tree().process_frame


func _test_hand_rig_and_anchors() -> void:
	var spec: Variant = _load_json(SPEC_PATH)
	var blockout: Variant = _load_json(BLOCKOUT_SPEC_PATH)
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		_check(false, "no se puede evaluar el rig sin la escena")
		return
	var cabin := packed.instantiate()
	add_child(cabin)
	await get_tree().process_frame
	var hand_rig := cabin.get_node_or_null("HandRig")
	_check(hand_rig != null, "rig de manos presente en la escena")
	var skeleton := _find_skeleton(hand_rig) if hand_rig != null else null
	_check(skeleton != null, "Skeleton3D del rig de manos")
	if skeleton != null and spec is Dictionary:
		var anchors: Array = spec.get("rig_anchor", {}).get("anchors", [])
		var all_found := true
		for entry in anchors:
			if not (entry is Dictionary):
				continue
			var bone_name := str(entry.get("id", ""))
			if skeleton.find_bone(bone_name) == -1:
				all_found = false
				print("[CABIN]     hueso ausente: %s" % bone_name)
		_check(all_found, "los %d huesos del rig existen" % anchors.size())
		_check(skeleton.find_bone("anchor_root") != -1, "hueso raiz anchor_root")

		# Compatibilidad: las anclas de control del rig deben coincidir con las
		# anclas anchor_* del bloqueo (mismas posiciones en el espacio del contrato).
		if blockout is Dictionary:
			var blockout_anchors := {}
			for entry in blockout.get("rig_anchor", {}).get("anchors", []):
				if entry is Dictionary:
					blockout_anchors[str(entry.get("id", ""))] = entry.get("position_m", [])
			var cabin_anchors := {}
			for entry in anchors:
				if entry is Dictionary:
					cabin_anchors[str(entry.get("id", ""))] = entry.get("position_m", [])
			for control in ["anchor_driver_seat", "anchor_steering_wheel", "anchor_gear_lever", "anchor_handbrake"]:
				_check(cabin_anchors.has(control) and blockout_anchors.has(control), "ancla de control %s en rig y bloqueo" % control)
				if cabin_anchors.has(control) and blockout_anchors.has(control):
					var a: Array = cabin_anchors[control]
					var b: Array = blockout_anchors[control]
					var near := a.size() == 3 and b.size() == 3 and absf(float(a[0]) - float(b[0])) < 0.001 \
						and absf(float(a[1]) - float(b[1])) < 0.001 and absf(float(a[2]) - float(b[2])) < 0.001
					_check(near, "posicion de %s coincide con el bloqueo" % control)
	cabin.queue_free()
	await get_tree().process_frame


func _test_ik_poses() -> void:
	var spec: Variant = _load_json(SPEC_PATH)
	if not (spec is Dictionary):
		_check(false, "no se pueden evaluar las poses IK sin el spec")
		return
	var poses: Array = spec.get("rig_anchor", {}).get("ik_poses", [])
	_check(poses.size() >= 3, "al menos tres poses IK definidas (%d)" % poses.size())
	var anchors: Array = spec.get("rig_anchor", {}).get("anchors", [])
	var bone_ids := {}
	for entry in anchors:
		if entry is Dictionary:
			bone_ids[str(entry.get("id", ""))] = true
	var control_ids := {
		"anchor_steering_wheel": true,
		"anchor_gear_lever": true,
		"anchor_handbrake": true,
	}
	# Toda pose apunta a un ancla del bloqueo (controles + asiento para pose_rest).
	var valid_targets := {
		"anchor_driver_seat": true,
		"anchor_steering_wheel": true,
		"anchor_gear_lever": true,
		"anchor_handbrake": true,
	}
	var targets_valid := true
	var hands_valid := true
	var reached_controls := {}
	for pose in poses:
		if not (pose is Dictionary):
			continue
		var target := str(pose.get("target_anchor", ""))
		if control_ids.has(target):
			reached_controls[target] = true
		if not valid_targets.has(target):
			targets_valid = false
		for bone_id in pose.get("hand_targets_m", {}).keys():
			if not bone_ids.has(str(bone_id)):
				hands_valid = false
	_check(targets_valid, "toda pose IK apunta a un ancla del bloqueo")
	_check(hands_valid, "los objetivos de mano de las poses IK son huesos del rig")
	_check(reached_controls.size() >= 3, "las poses IK alcanzan volante, palanca y freno de mano")


func _test_no_physics() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		_check(false, "no se puede evaluar la fisica sin la escena")
		return
	var cabin := packed.instantiate()
	add_child(cabin)
	await get_tree().process_frame
	var has_body := _find_first(cabin, ["VehicleBody3D", "RigidBody3D", "CharacterBody3D", "VehicleWheel3D"]) != null
	_check(not has_body, "cabina sin cuerpos de fisica ni conduccion (F2.2 no simula conduccion)")
	cabin.queue_free()
	await get_tree().process_frame


func _finish() -> void:
	if _failed.is_empty():
		print("[CABIN] OK %d comprobaciones" % _passed)
		get_tree().quit(0)
		return
	print("[CABIN] Fallaron %d de %d comprobaciones:" % [_failed.size(), _passed + _failed.size()])
	for failure in _failed:
		print("[CABIN]   - %s" % failure)
	print("[CABIN] FAIL")
	get_tree().quit(1)
