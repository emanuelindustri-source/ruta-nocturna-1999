class_name CabinMirrors
extends Node3D
## Espejos retrovisores con SubViewport (Fase 2.4).
##
## Cada espejo se declara en data/schemas/cabin_interaction.json (seccion
## `mirrors`): superficie quad, viewport de resolucion limitada, camara propia
## y cadencia de actualizacion. Los viewports comparten el World3D de la
## escena, de modo que la camara del espejo renderiza la misma cabina desde el
## angulo del espejo. Las superficies son primitivas de codigo (no mallas de la
## fabrica) y los tres pasos de render cuentan dentro del presupuesto movil de
## triangulos (AGENTS.md, seccion 9). El arte definitivo del espejo es F3.1.

const SPEC_PATH := "res://data/schemas/cabin_interaction.json"

var spec: CabinInteractionSpec
var configured := false

var _mirrors: Dictionary = {}
var _timers: Dictionary = {}
var _enabled := true


func _ready() -> void:
	spec = CabinInteractionSpec.new()
	if not spec.load_spec(SPEC_PATH):
		push_error("[CABIN_MIRRORS] Contrato invalido: %s" % ", ".join(spec.errors))
		return
	_build()


func _build() -> void:
	for entry in spec.array("mirrors.entries"):
		if not (entry is Dictionary):
			continue
		var mirror_id := str(entry.get("id", ""))
		var root := Node3D.new()
		root.name = "Mirror%s" % mirror_id.capitalize()
		root.position = _vector3(entry.get("position_m"))
		root.rotation_degrees = _vector3(entry.get("surface_rotation_deg"))
		add_child(root)

		var surface := MeshInstance3D.new()
		surface.name = "Surface"
		var quad := QuadMesh.new()
		var size: Array = entry.get("surface_size_m", [0.2, 0.1])
		if size.size() == 2:
			quad.size = Vector2(float(size[0]), float(size[1]))
		surface.mesh = quad
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(0.72, 0.78, 0.84, 1.0)
		surface.material_override = material
		root.add_child(surface)

		var viewport := SubViewport.new()
		viewport.name = "Viewport"
		var viewport_size: Array = entry.get("viewport_size_px", [128, 96])
		if viewport_size.size() == 2:
			viewport.size = Vector2i(int(viewport_size[0]), int(viewport_size[1]))
		viewport.transparent_bg = false
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		add_child(viewport)

		var camera := Camera3D.new()
		camera.name = "Camera"
		camera.fov = float(entry.get("fov_deg", 55.0))
		camera.near = 0.05
		# La camara es hija directa de Mirrors: su posicion y rotacion son del
		# contrato en coordenadas de mundo, sin heredar la rotacion de la
		# superficie del espejo.
		camera.position = _vector3(entry.get("position_m")) + _vector3(entry.get("camera_offset_m"))
		camera.rotation_degrees = _vector3(entry.get("camera_rotation_deg"))
		viewport.add_child(camera)

		material.albedo_texture = viewport.get_texture()
		_mirrors[mirror_id] = {
			"root": root,
			"surface": surface,
			"viewport": viewport,
			"camera": camera,
			"update_hz": float(entry.get("update_hz", 30.0)),
		}
		_timers[mirror_id] = 0.0
	configured = not _mirrors.is_empty()


func _process(delta: float) -> void:
	if not configured or not _enabled:
		return
	for mirror_id in _mirrors.keys():
		var mirror: Dictionary = _mirrors[mirror_id]
		var update_hz: float = maxf(1.0, float(mirror.get("update_hz", 30.0)))
		var period := 1.0 / update_hz
		var timer: float = float(_timers.get(mirror_id, 0.0)) + delta
		if timer >= period:
			timer = fmod(timer, period)
			_rearm(mirror)
		_timers[mirror_id] = timer


func _rearm(mirror: Dictionary) -> void:
	var viewport := mirror.get("viewport") as SubViewport
	if viewport == null:
		return
	# UPDATE_ONCE renderiza un frame y se desactiva solo: es la cadencia
	# declarada en mirrors.entries[].update_hz sin renderizar en cada frame.
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func get_mirror(mirror_id: String) -> Dictionary:
	return _mirrors.get(mirror_id, {})


func get_mirror_ids() -> Array:
	var ids := _mirrors.keys()
	ids.sort()
	return ids


func get_viewport_count() -> int:
	return _mirrors.size()


func get_camera(mirror_id: String) -> Camera3D:
	var mirror: Dictionary = _mirrors.get(mirror_id, {})
	return mirror.get("camera") as Camera3D


func get_surface(mirror_id: String) -> MeshInstance3D:
	var mirror: Dictionary = _mirrors.get(mirror_id, {})
	return mirror.get("surface") as MeshInstance3D


func get_surface_triangles() -> int:
	var total := 0
	for mirror_id in _mirrors.keys():
		var surface := get_surface(mirror_id)
		if surface != null and surface.mesh != null:
			total += surface.mesh.get_faces().size() / 3
	return total


func set_viewports_enabled(enabled: bool) -> void:
	_enabled = enabled
	for mirror_id in _mirrors.keys():
		var mirror: Dictionary = _mirrors[mirror_id]
		var viewport := mirror.get("viewport") as SubViewport
		if viewport == null:
			continue
		viewport.render_target_update_mode = (
			SubViewport.UPDATE_ONCE if enabled else SubViewport.UPDATE_DISABLED
		)


func _vector3(value: Variant) -> Vector3:
	if value is Array and (value as Array).size() == 3:
		var parts: Array = value
		return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
	return Vector3.ZERO
