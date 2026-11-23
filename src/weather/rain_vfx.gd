class_name RainVFX
extends Node3D
## VFX de lluvia (F3.4): estrellas de caída y salpicaduras de impacto.
##
## Dos sistemas GPUParticles3D = dos llamadas de dibujo. La malla de cada
## partícula se asigna por `draw_pass_1` (API de Godot 4) con
## `shaders/rain_streaks.gdshader` o `shaders/splash_ring.gdshader`; no hay
## simulación de humedad aquí: la intensidad la dicta RainFxController desde
## los modelos de F3.3.

const STREAK_SHADER := "res://shaders/rain_streaks.gdshader"
const SPLASH_SHADER := "res://shaders/splash_ring.gdshader"

var _streaks: GPUParticles3D
var _splashes: GPUParticles3D


func build(camera: Camera3D = null) -> void:
	_streaks = _make_streaks()
	add_child(_streaks)
	_splashes = _make_splashes()
	add_child(_splashes)
	update_fx(0.0, 0.0, camera)


func _make_particle_mesh(quad_size: Vector2, shader_path: String) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = quad_size
	var material := ShaderMaterial.new()
	material.shader = load(shader_path) as Shader
	quad.material = material
	return quad


func _make_streaks() -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = "RainStreaks"
	particles.amount = 600
	particles.lifetime = 1.1
	particles.randomness = 0.4
	particles.local_coords = false
	particles.visibility_aabb = AABB(Vector3(-20, -20, -20), Vector3(40, 40, 40))
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0.0, -1.0, 0.0)
	process.spread = 6.0
	process.gravity = Vector3(0.0, -3.5, 0.0)
	process.initial_velocity_min = 8.0
	process.initial_velocity_max = 12.0
	process.scale_min = 0.8
	process.scale_max = 1.6
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_shape_scale = Vector3(11.0, 7.0, 11.0)
	process.emission_box_extents = Vector3(11.0, 7.0, 11.0)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.75, 1.0])
	gradient.colors = PackedColorArray([
		Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.0),
	])
	var ramp := GradientTexture2D.new()
	ramp.gradient = gradient
	process.color_ramp = ramp
	particles.process_material = process
	particles.draw_pass_1 = _make_particle_mesh(Vector2(0.035, 0.55), STREAK_SHADER)
	return particles


func _make_splashes() -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = "RoadSplashes"
	particles.amount = 120
	particles.lifetime = 0.42
	particles.randomness = 0.6
	particles.local_coords = false
	particles.visibility_aabb = AABB(Vector3(-20, -4, -20), Vector3(40, 8, 40))
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0.0, 1.0, 0.0)
	process.spread = 35.0
	process.gravity = Vector3(0.0, -6.0, 0.0)
	process.initial_velocity_min = 0.8
	process.initial_velocity_max = 1.6
	process.scale_min = 0.5
	process.scale_max = 1.3
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_shape_scale = Vector3(12.0, 0.05, 12.0)
	process.emission_box_extents = Vector3(12.0, 0.05, 12.0)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	gradient.colors = PackedColorArray([
		Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0.0),
	])
	var ramp := GradientTexture2D.new()
	ramp.gradient = gradient
	process.color_ramp = ramp
	particles.process_material = process
	particles.draw_pass_1 = _make_particle_mesh(Vector2(0.1, 0.1), SPLASH_SHADER)
	return particles


## La intensidad de lluvia modula la cantidad visible (emitting + amount_ratio,
## sin crear ni destruir partículas).
func update_fx(rain_intensity: float, wind_mps: float, camera: Camera3D = null) -> void:
	if _streaks == null or _splashes == null:
		return
	var rain := clampf(rain_intensity, 0.0, 1.0)
	_streaks.emitting = rain > 0.02
	_splashes.emitting = rain > 0.12
	_streaks.amount_ratio = clampf(0.15 + rain * 0.85, 0.0, 1.0)
	_splashes.amount_ratio = clampf(rain * 1.1, 0.0, 1.0)
	var wind := clampf(wind_mps, 0.0, 25.0)
	if _streaks.process_material is ParticleProcessMaterial:
		var process := _streaks.process_material as ParticleProcessMaterial
		process.gravity = Vector3(0.0, -3.5, wind * 0.22)
	if camera != null:
		var anchor := camera.global_position + (-camera.global_transform.basis.z) * 7.0
		_streaks.position = anchor + Vector3(0.0, 4.0, 0.0)
		_splashes.position = Vector3(anchor.x, 0.02, anchor.z)
