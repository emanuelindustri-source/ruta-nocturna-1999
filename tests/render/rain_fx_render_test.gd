extends Node
## Prueba de render real de F3.4 (solo ventana, Vulkan Forward+).
##
## Carga boot, rebanada y cabina con los shaders/VFX nuevos, captura
## capturas de pantalla, mide draw calls, frame time y proyecta overdraw y
## fill rate contra `budgets.*.gpu`, y verifica que el warm-up de shaders se
## ejecuta antes del gameplay. La medición GPU completa en ruta/dispositivo
## es F3.5/F10.1.
##
## Ejecutar (ventana, no headless):
##   C:\Dev\Godot\Godot_v4.7.2-stable_win64_console.exe --path . res://tests/render/RainFxRenderTest.tscn

const BOOT_SCENE := "res://scenes/boot/Boot.tscn"
const SLICE_SCENE := "res://scenes/vertical_slice/VerticalSlice.tscn"
const CABIN_SCENE := "res://scenes/vehicle/CabinInteraction.tscn"
const SHOT_DIR := "res://build/logs/render"
const MEASURE_FRAMES := 90
const WARM_FRAMES := 30
## Segundos de tormenta pre-simulados antes de capturar: los modelos de F3.3
## son físicos y la película/charcos tardan en formarse (lookdev reproducible).
const SOAK_SECONDS := 90.0
## Presupuesto del contrato (budgets.pc.frame_budget_ms) con tolerancia de
## vsync a 60 Hz: el bloqueo de presentación enlentece ~1 ms la medición.
const FRAME_BUDGET_MS := 16.667
const FRAME_BUDGET_TOLERANCE := 1.15

var _failures: Array[String] = []


func _ready() -> void:
	print("[RENDER] START version=%s renderer=%s" % [
		str(ProjectSettings.get_setting("application/config/version", "0.0.0")),
		RenderingServer.get_video_adapter_name(),
	])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	await _run_scene("boot", BOOT_SCENE, false)
	await _run_scene("vertical_slice", SLICE_SCENE, true)
	await _run_scene("cabin", CABIN_SCENE, true)
	if _failures.is_empty():
		print("[RENDER] RENDER_OK")
		get_tree().quit(0)
		return
	for failure in _failures:
		print("[RENDER] FAIL %s" % failure)
	print("[RENDER] RENDER_FAIL")
	get_tree().quit(1)


func _run_scene(label: String, path: String, check_rainfx: bool) -> void:
	var packed := load(path) as PackedScene
	if packed == null:
		_failures.append("carga:%s" % path)
		return
	var scene := packed.instantiate()
	add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	if check_rainfx:
		var controller := scene.get_node_or_null("RainFx") as RainFxController
		if controller == null:
			_failures.append("rainfx:%s" % label)
		else:
			_check_warmup(label, controller)
			_soak(controller)
			await _measure(label, controller)
	else:
		await _measure(label, null)
	var image := get_viewport().get_texture().get_image()
	var shot_path := "%s/f34_%s.png" % [SHOT_DIR, label]
	image.save_png(shot_path)
	print("[RENDER] SHOT %s" % shot_path)
	if label == "vertical_slice":
		await _capture_detail(scene)
	if label == "cabin":
		await _debug_overlay(scene)
	scene.queue_free()
	for _i in range(3):
		await get_tree().process_frame


## Depuración de lookdev: lectura de uniforms y captura con el quad en rojo
## para separar "el quad no se dibuja" de "el campo de gotas no pinta".
func _debug_overlay(scene: Node) -> void:
	var controller := scene.get_node_or_null("RainFx") as RainFxController
	if controller == null or controller._camera_overlay == null:
		return
	var overlay := controller._camera_overlay
	var material := overlay.material_override as ShaderMaterial
	print("[RENDER][DEBUG] overlay parent=%s visible=%s pos=%s" % [
		str(overlay.get_parent().name), str(overlay.visible), str(overlay.position),
	])
	if material != null:
		for parameter in [
			"drop_density", "drop_radius_mm", "wetness_value", "slide_speed_mm_s", "wiper_sweep",
		]:
			print("[RENDER][DEBUG] uniform %s = %s" % [parameter, str(material.get_shader_parameter(parameter))])
		material.set_shader_parameter("debug_flat", 1.0)
		for _i in range(4):
			await get_tree().process_frame
		var image := get_viewport().get_texture().get_image()
		var shot_path := "%s/f34_cabin_debug.png" % SHOT_DIR
		image.save_png(shot_path)
		print("[RENDER] SHOT %s" % shot_path)
		material.set_shader_parameter("debug_flat", 0.0)


## Avanza los modelos de F3.3 con pasos acotados por precipitation.max_step_s.
func _soak(controller: RainFxController) -> void:
	controller.manual_mode = true
	var steps := int(SOAK_SECONDS * 4.0)
	for _i in range(steps):
		controller.step_models(0.25)
	controller.refresh_uniforms()
	print("[RAINFX] SOAK seconds=%.0f wetness_road=%.3f windshield=%.3f puddles=%s" % [
		SOAK_SECONDS, controller.wetness.get_wetness("asphalt_crown"),
		controller.wetness.get_wetness("windshield"),
		str(controller.puddles.get_depth_mm("asphalt_low_spot")),
	])
	if not controller._road_materials.is_empty():
		var road_material = controller._road_materials[0]
		print("[RENDER][DEBUG] road uniforms wetness=%s film=%s puddle_count=%s" % [
			str(road_material.get_shader_parameter("wetness_value")),
			str(road_material.get_shader_parameter("film_mm")),
			str(road_material.get_shader_parameter("puddle_count")),
		])
	if not controller._materials.is_empty():
		var surface_material = controller._materials[0]["material"]
		print("[RENDER][DEBUG] surface uniforms wetness=%s drop_density=%s drop_radius=%s" % [
			str(surface_material.get_shader_parameter("wetness_value")),
			str(surface_material.get_shader_parameter("drop_density")),
			str(surface_material.get_shader_parameter("drop_radius_mm")),
		])


## Toma de detalle del capó/parabrisas para ver gotas y barrido de cerca.
func _capture_detail(scene: Node) -> void:
	var camera := scene.get_node_or_null("Camera3D") as Camera3D
	if camera == null:
		return
	camera.position = Vector3(1.4, 1.6, -1.2)
	camera.look_at(Vector3(0.0, 1.1, 0.2))
	for _i in range(10):
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var shot_path := "%s/f34_vertical_slice_detail.png" % SHOT_DIR
	image.save_png(shot_path)
	print("[RENDER] SHOT %s" % shot_path)


func _check_warmup(label: String, controller: RainFxController) -> void:
	if not controller.warmup_done:
		_failures.append("warmup:%s" % label)
		return
	print(
		"[RENDER] WARMUP scene=%s done=%s ms=%.2f fx_active=%s"
		% [label, str(controller.warmup_done), controller.warmup_ms, str(controller.fx_active)]
	)
	if not controller.fx_active:
		_failures.append("fx_before_warmup:%s" % label)


func _measure(label: String, controller: RainFxController) -> void:
	# Deja estabilizar la escena antes de medir.
	for _i in range(WARM_FRAMES):
		await get_tree().process_frame
	var samples: Array[float] = []
	var draw_calls := 0.0
	var primitives := 0.0
	var previous := Time.get_ticks_usec()
	for _i in range(MEASURE_FRAMES):
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		samples.append(float(now - previous) / 1000.0)
		previous = now
		draw_calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		primitives += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	samples.sort()
	var total := 0.0
	for sample in samples:
		total += sample
	var avg := total / float(samples.size())
	var p95 := samples[clampi(int(samples.size() * 0.95), 0, samples.size() - 1)]
	var budget := controller.estimate_gpu_budget() if controller != null else {
		"added_draw_calls": 0, "overdraw_layers": 0, "fill_percent": 0.0,
	}
	print(
		"[RENDER][PERF] scene=%s frame_ms_avg=%.3f frame_ms_p95=%.3f draw_calls_avg=%.1f primitives_avg=%.1f added_draw_calls=%d overdraw_layers=%d fill_percent=%.1f"
		% [
			label, avg, p95, draw_calls / float(MEASURE_FRAMES), primitives / float(MEASURE_FRAMES),
			int(budget["added_draw_calls"]), int(budget["overdraw_layers"]), float(budget["fill_percent"]),
		]
	)
	if avg > FRAME_BUDGET_MS * FRAME_BUDGET_TOLERANCE:
		_failures.append("frame_time:%s avg=%.3f" % [label, avg])
