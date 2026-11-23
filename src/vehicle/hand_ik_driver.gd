class_name HandIKDriver
extends Node
## IK determinista de manos para la cabina.
##
## Resuelve una cadena hombro-codo-muneca-palma-agarre con dos huesos por brazo
## y escribe las posiciones en el Skeleton3D del rig EsteemHandRig. Soporta poses
## de 2, 1 y 0 manos en el volante. No hay piel ni animacion de conduccion: las
## mallas de manos son F3.2. La solucion es reproducible y se puede avanzar con
## `advance()` en pruebas headless.

signal pose_changed(pose_id: String, hands_on_wheel: int)
signal target_reached(pose_id: String)

@export var auto_advance := true
@export var transition_s := 0.24

var skeleton: Skeleton3D
var spec: CabinInteractionSpec
var cabin_spec: Dictionary = {}
var controls: CabinControls

var target_pose := "pose_rest"
var hands_on_wheel := 0
var progress := 1.0
var last_clamped := {"left": false, "right": false}

var _shoulder := {"left": Vector3.ZERO, "right": Vector3.ZERO}
var _rest := {"left": Vector3.ZERO, "right": Vector3.ZERO}
var _wheel := {"left": Vector3.ZERO, "right": Vector3.ZERO}
var _current := {"left": Vector3.ZERO, "right": Vector3.ZERO}
var _from := {"left": Vector3.ZERO, "right": Vector3.ZERO}
var _target := {"left": Vector3.ZERO, "right": Vector3.ZERO}
var _solved := {"left": Vector3.ZERO, "right": Vector3.ZERO}
var _directions := {"left": Vector3.FORWARD, "right": Vector3.FORWARD}
var _anchors: Dictionary = {}
var _upper_length := 0.36
var _forearm_length := 0.36
var _hand_length := 0.1
var _lean_max := 0.15
var _elbow_pole := Vector3(0.35, -1.0, 0.15)
var _configured := false
var _reached_emitted := true


func _ready() -> void:
	set_process(auto_advance)


func _process(delta: float) -> void:
	if auto_advance and _configured:
		advance(delta)


func configure(spec_in: CabinInteractionSpec, cabin_spec_in: Dictionary, controls_in: CabinControls, skeleton_in: Skeleton3D) -> void:
	spec = spec_in
	cabin_spec = cabin_spec_in
	controls = controls_in
	skeleton = skeleton_in
	transition_s = maxf(0.02, spec.number("interaction.hand_transition_s", 0.24))
	_upper_length = maxf(0.05, spec.number("hands.arm.upper_length_m", 0.36))
	_forearm_length = maxf(0.05, spec.number("hands.arm.forearm_length_m", 0.36))
	_hand_length = maxf(0.02, spec.number("hands.arm.hand_length_m", 0.1))
	_lean_max = maxf(0.0, spec.number("hands.arm.lean_max_m", 0.15))
	var pole: Array = spec.array("hands.arm.elbow_pole")
	if pole.size() == 3:
		_elbow_pole = Vector3(float(pole[0]), float(pole[1]), float(pole[2]))
	_anchors.clear()
	for entry in cabin_spec.get("rig_anchor", {}).get("anchors", []):
		if entry is Dictionary:
			_anchors[str(entry.get("id", ""))] = _to_vector3(entry.get("position_m", []))
	var seat := _anchor_position("anchor_driver_seat")
	var left_offset: Array = spec.array("hands.shoulders.left.offset_from_driver_seat_m")
	var right_offset: Array = spec.array("hands.shoulders.right.offset_from_driver_seat_m")
	_shoulder["left"] = seat + _array_vector3(left_offset)
	_shoulder["right"] = seat + _array_vector3(right_offset)
	_rest["left"] = _anchor_position(spec.string("hands.rest.left_anchor", "hand_l_grip"))
	_rest["right"] = _anchor_position(spec.string("hands.rest.right_anchor", "hand_r_grip"))
	var wheel_center := _anchor_position("anchor_steering_wheel")
	if controls != null:
		wheel_center = controls.get_control_position("steering_wheel")
	_wheel["left"] = wheel_center + _array_vector3(spec.array("hands.wheel.left_grip_offset_m"))
	_wheel["right"] = wheel_center + _array_vector3(spec.array("hands.wheel.right_grip_offset_m"))
	_current["left"] = _rest["left"]
	_current["right"] = _rest["right"]
	_target["left"] = _rest["left"]
	_target["right"] = _rest["right"]
	_configured = true
	set_pose("pose_rest", true)
	set_process(auto_advance)


func set_pose(pose_id: String, immediate: bool = false) -> bool:
	if not _configured:
		return false
	var pose := spec.pose(pose_id)
	if pose.is_empty():
		push_warning("[HAND_IK] pose inexistente: %s" % pose_id)
		return false
	target_pose = pose_id
	hands_on_wheel = _count_wheel_hands(pose)
	_from["left"] = _current["left"]
	_from["right"] = _current["right"]
	_recompute_targets(pose)
	if immediate:
		_current["left"] = _target["left"]
		_current["right"] = _target["right"]
		progress = 1.0
		_apply_current()
		_reached_emitted = true
	else:
		progress = 0.0
		_reached_emitted = false
	pose_changed.emit(target_pose, hands_on_wheel)
	return true


func advance(delta: float) -> void:
	if not _configured:
		return
	var pose := spec.pose(target_pose)
	if pose.is_empty():
		return
	_recompute_targets(pose)
	var step := maxf(delta, 0.0)
	if progress < 1.0:
		progress = minf(1.0, progress + step / transition_s)
		var eased := smoothstep(0.0, 1.0, progress)
		var from_left: Vector3 = _from["left"]
		var from_right: Vector3 = _from["right"]
		var target_left: Vector3 = _target["left"]
		var target_right: Vector3 = _target["right"]
		_current["left"] = from_left.lerp(target_left, eased)
		_current["right"] = from_right.lerp(target_right, eased)
	else:
		_current["left"] = _target["left"]
		_current["right"] = _target["right"]
	_apply_current()
	if progress >= 1.0 and not _reached_emitted:
		_reached_emitted = true
		target_reached.emit(target_pose)


func get_hand_position(side: String) -> Vector3:
	return _solved.get(side, Vector3.ZERO)


func get_target_position(side: String) -> Vector3:
	return _target.get(side, Vector3.ZERO)


func get_hand_direction(side: String) -> Vector3:
	return _directions.get(side, Vector3.FORWARD)


func get_hands_on_wheel() -> int:
	return hands_on_wheel


func get_pose_id() -> String:
	return target_pose


func is_at_target() -> bool:
	return progress >= 1.0


func is_clamped(side: String) -> bool:
	return bool(last_clamped.get(side, false))


func _recompute_targets(pose: Dictionary) -> void:
	_target["left"] = _resolve_target("left", pose.get("left", {}))
	_target["right"] = _resolve_target("right", pose.get("right", {}))


func _resolve_target(side: String, target: Dictionary) -> Vector3:
	var kind := str(target.get("kind", "rest"))
	if kind == "anchor":
		var anchor_id := str(target.get("id", ""))
		if anchor_id == spec.string("hands.wheel.left_anchor", "ik_steering_l"):
			return _wheel["left"]
		if anchor_id == spec.string("hands.wheel.right_anchor", "ik_steering_r"):
			return _wheel["right"]
		return _anchor_position(anchor_id)
	if kind == "control":
		var control_id := str(target.get("id", ""))
		if controls != null:
			return controls.get_control_position(control_id)
		var control := spec.control(control_id)
		return _array_vector3(control.get("position_m", []))
	return _rest.get(side, Vector3.ZERO)


func _apply_current() -> void:
	_solved["left"] = _solve_hand("left", _current["left"])
	_solved["right"] = _solve_hand("right", _current["right"])


func _solve_hand(side: String, grip_target: Vector3) -> Vector3:
	var shoulder: Vector3 = _shoulder.get(side, Vector3.ZERO)
	var target := grip_target
	var delta := target - shoulder
	var distance := delta.length()
	var reach := _upper_length + _forearm_length
	last_clamped[side] = false
	if distance > reach:
		var lean := minf(_lean_max, distance - reach + 0.001)
		shoulder += delta.normalized() * lean
		delta = target - shoulder
		distance = delta.length()
	if distance > reach:
		last_clamped[side] = true
		target = shoulder + delta.normalized() * (reach - 0.002)
		distance = reach - 0.002
	if distance <= 0.001:
		return target
	var wrist_offset := minf(_hand_length, distance * 0.5)
	var wrist := target + (shoulder - target).normalized() * wrist_offset
	var chain := wrist - shoulder
	var chain_length := clampf(
		chain.length(),
		absf(_upper_length - _forearm_length) + 0.001,
		_upper_length + _forearm_length - 0.001
	)
	var direction := chain.normalized()
	var along := (
		_upper_length * _upper_length - _forearm_length * _forearm_length + chain_length * chain_length
	) / (2.0 * chain_length)
	var height := sqrt(maxf(0.0, _upper_length * _upper_length - along * along))
	var base := shoulder + direction * along
	var pole := Vector3(_elbow_pole.x * (1.0 if side == "right" else -1.0), _elbow_pole.y, _elbow_pole.z)
	pole = pole.normalized()
	pole -= direction * pole.dot(direction)
	if pole.length_squared() < 0.0001:
		pole = Vector3.DOWN - direction * direction.dot(Vector3.DOWN)
		pole = pole.normalized() if pole.length_squared() > 0.0001 else Vector3.BACK
	var elbow := base + pole * height
	var palm := wrist.lerp(target, 0.55)
	var hand_direction := target - wrist
	if hand_direction.length_squared() > 0.0001:
		_directions[side] = hand_direction.normalized()
	var letter := "l" if side == "left" else "r"
	_apply_bone("hand_%s_wrist" % letter, wrist, wrist - elbow)
	_apply_bone("hand_%s_palm" % letter, palm, palm - wrist)
	_apply_bone("hand_%s_grip" % letter, target, target - palm)
	return target


func _apply_bone(bone_name: String, position: Vector3, direction: Vector3) -> void:
	if skeleton == null:
		return
	var bone := skeleton.find_bone(bone_name)
	if bone < 0:
		return
	skeleton.set_bone_pose_position(bone, position)
	if direction.length_squared() > 0.0001:
		var forward := direction.normalized()
		var up_dot := forward.dot(Vector3.UP)
		if up_dot > 0.999:
			skeleton.set_bone_pose_rotation(bone, Quaternion.IDENTITY)
		elif up_dot < -0.999:
			skeleton.set_bone_pose_rotation(bone, Quaternion(Vector3.RIGHT, PI))
		else:
			skeleton.set_bone_pose_rotation(bone, Quaternion(Vector3.UP, forward))


func _count_wheel_hands(pose: Dictionary) -> int:
	var wheel_anchors := {
		spec.string("hands.wheel.left_anchor", "ik_steering_l"): true,
		spec.string("hands.wheel.right_anchor", "ik_steering_r"): true,
	}
	var count := 0
	for side in ["left", "right"]:
		var target: Dictionary = pose.get(side, {})
		if str(target.get("kind", "")) == "anchor" and wheel_anchors.has(str(target.get("id", ""))):
			count += 1
	return count


func _anchor_position(anchor_id: String) -> Vector3:
	return _anchors.get(anchor_id, Vector3.ZERO)


func _array_vector3(value: Array) -> Vector3:
	if value.size() != 3:
		return Vector3.ZERO
	return Vector3(float(value[0]), float(value[1]), float(value[2]))


func _to_vector3(value: Variant) -> Vector3:
	if value is Array:
		return _array_vector3(value)
	return Vector3.ZERO
