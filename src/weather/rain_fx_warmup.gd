class_name RainFxWarmup
extends RefCounted
## Warm-up de shaders de lluvia (F3.4).
##
## Compila las pipelines GLSL de gotas, película, barrido, asfalto, VFX y
## gotas de cámara ANTES del gameplay: dibuja cada shader una vez en un
## SubViewport mínimo y lo destruye. El contrato (`budgets.measurement`)
## exige warm-up antes del gameplay; la evidencia son los marcadores
## `[RAINFX] WARMUP_*` de los logs de render (antes de
## `VERTICAL_SLICE_READY`/`CABIN_READY`). En headless no hay GPU que compilar.

const SHADER_PATHS := [
	"res://shaders/wet_paint.gdshader",
	"res://shaders/wet_glass.gdshader",
	"res://shaders/wet_road.gdshader",
	"res://shaders/rain_streaks.gdshader",
	"res://shaders/splash_ring.gdshader",
	"res://shaders/camera_drops.gdshader",
]


static func run(host: Node) -> Dictionary:
	if host == null or not host.is_inside_tree():
		return {"done": false, "skipped": true, "reason": "no_tree", "variants": 0, "ms": 0.0}
	if DisplayServer.get_name() == "headless":
		print("[RAINFX] WARMUP_SKIP reason=headless")
		return {"done": true, "skipped": true, "reason": "headless", "variants": 0, "ms": 0.0}
	var started := Time.get_ticks_usec()
	var viewport := SubViewport.new()
	viewport.name = "RainFxWarmupViewport"
	viewport.size = Vector2i(96, 96)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.disable_3d = false
	host.add_child(viewport)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 0.0, 3.0)
	viewport.add_child(camera)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35.0, 25.0, 0.0)
	viewport.add_child(light)

	var variants := 0
	for path in SHADER_PATHS:
		var shader := load(path) as Shader
		if shader == null:
			continue
		var quad := MeshInstance3D.new()
		var mesh := QuadMesh.new()
		mesh.size = Vector2(1.5, 1.5)
		quad.mesh = mesh
		var material := ShaderMaterial.new()
		material.shader = shader
		# Valores activos: mismo estado que en gameplay para compilar la variante.
		material.set_shader_parameter("wetness_value", 1.0)
		material.set_shader_parameter("film_mm", 0.1)
		material.set_shader_parameter("drop_density", 0.8)
		material.set_shader_parameter("drop_radius_mm", 1.5)
		material.set_shader_parameter("wiper_enabled", true)
		material.set_shader_parameter("wiper_sweep", 0.3)
		material.set_shader_parameter("rain_intensity", 1.0)
		material.set_shader_parameter("puddle_count", 1)
		quad.material_override = material
		quad.position = Vector3(float(variants % 3) - 1.0, floor(float(variants) / 3.0) - 1.0, 0.0)
		viewport.add_child(quad)
		variants += 1

	# Una pasada de render compila las pipelines de todos los shaders.
	RenderingServer.force_draw(false)
	var elapsed_ms := float(Time.get_ticks_usec() - started) / 1000.0
	viewport.queue_free()
	print("[RAINFX] WARMUP_DONE variants=%d ms=%.2f" % [variants, elapsed_ms])
	return {"done": true, "skipped": false, "reason": "", "variants": variants, "ms": elapsed_ms}
