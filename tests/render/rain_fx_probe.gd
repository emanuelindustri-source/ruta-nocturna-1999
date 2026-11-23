extends Node
## Sonda de volumen de emision F3.4: compara emission_box_extents frente a
## emission_shape_scale (y ambas) para ver cual dispersa las particulas.

func _ready() -> void:
	print("[PROBE] START")
	var camera := Camera3D.new()
	add_child(camera)
	camera.current = true
	camera.position = Vector3(0.0, 2.0, 8.0)
	camera.look_at(Vector3(0.0, 1.0, 0.0))
	var world := Environment.new()
	world.background_mode = Environment.BG_COLOR
	world.background_color = Color(0.05, 0.15, 0.05)
	var environment_node := WorldEnvironment.new()
	environment_node.environment = world
	add_child(environment_node)

	add_system(Vector3(-3.5, 2.0, 0.0), false, true, "A_box_extents")
	add_system(Vector3(0.0, 2.0, 0.0), true, false, "B_shape_scale")
	add_system(Vector3(3.5, 2.0, 0.0), true, true, "C_both")

	for _i in range(30):
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	image.save_png("res://build/logs/render/f34_probe.png")
	print("[PROBE] SHOT res://build/logs/render/f34_probe.png")
	get_tree().quit(0)


func add_system(position: Vector3, use_scale: bool, use_extents: bool, label: String) -> void:
	var particles := GPUParticles3D.new()
	particles.name = "Probe_%s" % label
	particles.amount = 100
	particles.lifetime = 20.0
	particles.preprocess = 5.0
	particles.local_coords = true
	particles.visibility_aabb = AABB(Vector3(-6, -6, -6), Vector3(12, 12, 12))
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0.0, 0.0, 0.0)
	process.spread = 180.0
	process.gravity = Vector3(0.0, 0.0, 0.0)
	process.initial_velocity_min = 0.0
	process.initial_velocity_max = 0.0
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	if use_scale:
		process.emission_shape_scale = Vector3(2.0, 2.0, 2.0)
	if use_extents:
		process.emission_box_extents = Vector3(2.0, 2.0, 2.0)
	particles.process_material = process
	var mesh_instance := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)
	mesh_instance.mesh = quad
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1, 1, 1)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_instance.material_override = material
	particles.add_child(mesh_instance)
	add_child(particles)
	particles.position = position
	particles.emitting = true
	print("[PROBE] system %s scale=%s extents=%s" % [label, str(use_scale), str(use_extents)])
