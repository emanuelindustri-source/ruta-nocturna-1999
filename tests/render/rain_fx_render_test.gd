extends Node
## Prueba de render real de F3.4/F3.5 (solo ventana, Vulkan Forward+).
##
## Carga boot, rebanada y cabina con los shaders/VFX, captura las referencias
## visuales de la subfase, mide tiempo de carga, frame time + frame pacing,
## draw calls y primitivas, y ejecuta la sonda GPU de F3.5:
##   - fill visual real (pixeles que cambian con los FX activos),
##   - fill de fragmentos y capas de overdraw con sonda aditiva calibrada,
##   - coste real de frame (delta con vsync desactivado, FX on vs off),
##   - delta exacto de draw calls con FX on vs off.
## Todo se contrasta con `budgets.pc.gpu` del contrato rain_surface_fx.json.
##
## Ejecutar (ventana, no headless):
##   C:\Dev\Godot\Godot_v4.7.2-stable_win64_console.exe --path . res://tests/render/RainFxRenderTest.tscn

const BOOT_SCENE := "res://scenes/boot/Boot.tscn"
const SLICE_SCENE := "res://scenes/vertical_slice/VerticalSlice.tscn"
const CABIN_SCENE := "res://scenes/vehicle/CabinInteraction.tscn"
const SHOT_DIR := "res://build/logs/render"
## Prefijo de capturas de la subfase (F3.5 usa f35_*; F3.4 dejo f34_*).
const SHOT_PREFIX := "f35"
const CONTRACT_PATH := "res://data/schemas/rain_surface_fx.json"
const MEASURE_FRAMES := 90
const WARM_FRAMES := 30
## Segundos de tormenta pre-simulados antes de capturar: los modelos de F3.3
## son fisicos y la pelicula/charcos tardan en formarse (lookdev reproducible).
const SOAK_SECONDS := 90.0
## Presupuesto del contrato (budgets.pc.frame_budget_ms) con tolerancia de
## vsync a 60 Hz: el bloqueo de presentacion enlentece ~1 ms la medicion.
const FRAME_BUDGET_MS := 16.667
const FRAME_BUDGET_TOLERANCE := 1.15
## Sonda GPU (F3.5): fotogramas de espera entre capturas (1 frame = el estado
## ya se renderizo; el gap minimo mantiene baja la deriva temporal de los
## shaders con TIME) y tamanos de muestreo.
const PROBE_SNAP_FRAMES := 1
const PROBE_DRAW_FRAMES := 15
const PROBE_TIMING_FRAMES := 60
## Umbral de "pixel visualmente afectado" por los FX (codigos de 8 bits).
const VISUAL_FILL_THRESHOLD := 6
## Umbral minimo de respuesta de calibracion por capa aditiva (codigos).
const CALIB_MIN_RESPONSE := 1
## Incremento lineal de la sonda aditiva: 1/255 en espacio lineal.
const PROBE_STEP := 1.0 / 255.0

var _failures: Array[String] = []
var _gpu_budget := {
	"max_draw_calls": 8, "max_overdraw_layers": 5, "max_fill_percent": 6.0,
}


func _ready() -> void:
	_load_gpu_budget()
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


func _load_gpu_budget() -> void:
	var text := FileAccess.get_file_as_string(CONTRACT_PATH)
	if text.is_empty():
		return
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return
	var gpu: Variant = (parsed as Dictionary).get("budgets", {}).get("pc", {}).get("gpu", {})
	if gpu is Dictionary:
		_gpu_budget = {
			"max_draw_calls": int(gpu.get("max_draw_calls", 8)),
			"max_overdraw_layers": int(gpu.get("max_overdraw_layers", 5)),
			"max_fill_percent": float(gpu.get("max_fill_percent", 6.0)),
		}


func _run_scene(label: String, path: String, check_rainfx: bool) -> void:
	print("[RENDER] SCENE_START %s" % label)
	var load_started := Time.get_ticks_usec()
	var packed := load(path) as PackedScene
	if packed == null:
		_failures.append("carga:%s" % path)
		return
	var load_ms := float(Time.get_ticks_usec() - load_started) / 1000.0
	var instance_started := Time.get_ticks_usec()
	var scene := packed.instantiate()
	var instantiate_ms := float(Time.get_ticks_usec() - instance_started) / 1000.0
	print("[RENDER][LOAD] scene=%s load_ms=%.2f instantiate_ms=%.2f" % [label, load_ms, instantiate_ms])
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
	var shot_path := "%s/%s_%s.png" % [SHOT_DIR, SHOT_PREFIX, label]
	image.save_png(shot_path)
	print("[RENDER] SHOT %s" % shot_path)
	if label == "vertical_slice":
		await _capture_detail(scene)
	if label == "cabin":
		await _debug_overlay(scene)
	if check_rainfx:
		var rain_controller := scene.get_node_or_null("RainFx") as RainFxController
		if rain_controller != null:
			await _probe_gpu(label, scene, rain_controller)
	scene.queue_free()
	for _i in range(3):
		await get_tree().process_frame
	print("[RENDER] SCENE_DONE %s" % label)


## Depuracion de lookdev: lectura de uniforms y captura con el quad en rojo
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
		var shot_path := "%s/%s_cabin_debug.png" % [SHOT_DIR, SHOT_PREFIX]
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


## Toma de detalle del capo/parabrisas para ver gotas y barrido de cerca.
func _capture_detail(scene: Node) -> void:
	var camera := scene.get_node_or_null("Camera3D") as Camera3D
	if camera == null:
		return
	var previous_transform := camera.transform
	camera.position = Vector3(1.4, 1.6, -1.2)
	camera.look_at(Vector3(0.0, 1.1, 0.2))
	for _i in range(10):
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var shot_path := "%s/%s_vertical_slice_detail.png" % [SHOT_DIR, SHOT_PREFIX]
	image.save_png(shot_path)
	print("[RENDER] SHOT %s" % shot_path)
	# Restaura la camara: la sonda GPU de F3.5 mide con el encuadre normal.
	camera.transform = previous_transform
	await get_tree().process_frame


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
	var worst := samples[samples.size() - 1]
	var jank_slow := 0
	var jank_stall := 0
	for sample in samples:
		if sample > FRAME_BUDGET_MS * 1.5:
			jank_slow += 1
		if sample > 100.0:
			jank_stall += 1
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
	print(
		"[RENDER][PACING] scene=%s frame_ms_max=%.3f jank_gt_25ms=%d jank_gt_100ms=%d frames=%d"
		% [label, worst, jank_slow, jank_stall, samples.size()]
	)
	if avg > FRAME_BUDGET_MS * FRAME_BUDGET_TOLERANCE:
		_failures.append("frame_time:%s avg=%.3f" % [label, avg])


# --- Sonda GPU (F3.5) --------------------------------------------------------
#
# Cuatro mediciones con el render real:
#   1. Delta exacto de draw calls (Performance, FX on vs off).
#   2. Fill visual: pixeles cuyo valor cambia con los FX visibles, con el
#      material real (mismo criterio que las estimaciones de F3.4), menos el
#      ruido de fondo por la animacion con TIME de los shaders mojados.
#   3. Fill de fragmentos y capas de overdraw: los materiales de los FX se
#      sustituyen temporalmente por una sonda aditiva (1/255 lineal por
#      fragmento) y se calibra la respuesta del pipeline con un quad a
#      pantalla completa de 1 y 2 capas. Asi se cuenta cada fragmento real
#      que procesa la GPU, sin asumir la funcion de transferencia de salida.
#   4. Coste real: frame time medio con vsync desactivado, FX off vs on.


func _probe_gpu(label: String, scene: Node, controller: RainFxController) -> void:
	print("[RENDER][GPU] phase=start scene=%s" % label)
	var camera := controller._camera
	if camera == null:
		_failures.append("gpu_camera:%s" % label)
		return
	var hidden := _hide_ui(scene)
	var mirror_was_visible := _set_node_visible(scene, "Mirrors", false)
	var fx_roots: Array[Node] = []
	if controller._vfx != null:
		fx_roots.append(controller._vfx)
	var overlay := controller._camera_overlay

	# 1) Draw calls anadidos (materiales reales).
	var added_draw_calls := await _measure_added_draw_calls(fx_roots, overlay)
	print("[RENDER][GPU] phase=draw_calls scene=%s added=%.2f" % [label, added_draw_calls])

	# 2) Fill visual con materiales reales (off, on, off2 para el ruido).
	_set_fx_visible(fx_roots, overlay, false)
	var visual_off := await _snap()
	_set_fx_visible(fx_roots, overlay, true)
	var visual_on := await _snap()
	_set_fx_visible(fx_roots, overlay, false)
	var visual_off2 := await _snap()
	var visual_fill := _visual_fill_percent(visual_off, visual_on)
	var visual_noise := _visual_fill_percent(visual_off, visual_off2)
	var visual_fill_net := maxf(0.0, visual_fill - visual_noise)
	_save_probe_shot("%s_%s_visual_off.png" % [SHOT_PREFIX, label], visual_off)
	_save_probe_shot("%s_%s_visual_on.png" % [SHOT_PREFIX, label], visual_on)
	_save_probe_shot("%s_%s_visual_diff.png" % [SHOT_PREFIX, label], _diff_image(visual_off, visual_on))
	print("[RENDER][GPU] phase=visual scene=%s fill=%.2f noise=%.2f" % [label, visual_fill, visual_noise])

	# 3) Sonda aditiva de fragmentos con calibracion.
	var saved := _apply_probe_materials(controller)
	var calib := _make_calib_quad(camera)
	var nodepth_material := _probe_material(true)
	calib.material_override = nodepth_material
	# base (FX apagados, sin calibracion)
	_set_fx_visible(fx_roots, overlay, false)
	calib.visible = false
	var probe_base := await _snap()
	# calibracion de 1 capa
	nodepth_material.set_shader_parameter("add_color", Vector3(PROBE_STEP, PROBE_STEP, PROBE_STEP))
	calib.visible = true
	var probe_cal1 := await _snap()
	# calibracion de 2 capas
	nodepth_material.set_shader_parameter("add_color", Vector3(PROBE_STEP * 2.0, PROBE_STEP * 2.0, PROBE_STEP * 2.0))
	var probe_cal2 := await _snap()
	# FX con sonda aditiva (1 capa de referencia para el overlay de gotas)
	nodepth_material.set_shader_parameter("add_color", Vector3(PROBE_STEP, PROBE_STEP, PROBE_STEP))
	calib.visible = false
	_set_fx_visible(fx_roots, overlay, true)
	var probe_fx := await _snap()
	# ruido de fondo: segunda base al final de la secuencia
	_set_fx_visible(fx_roots, overlay, false)
	var probe_base2 := await _snap()
	var fragment_stats := _fragment_stats(probe_base, probe_cal1, probe_cal2, probe_fx)
	var probe_noise := _noise_layers(probe_base, probe_base2, probe_cal1)
	print("[RENDER][GPU] phase=fragment scene=%s fill=%.2f max=%.1f noise=%.2f" % [
		label, float(fragment_stats["fill_fragments_percent"]),
		float(fragment_stats["overdraw_max"]), probe_noise,
	])

	# Restaura materiales reales de los FX.
	for entry in saved:
		match str(entry["kind"]):
			"override":
				(entry["obj"] as GeometryInstance3D).material_override = entry["value"]
			"mesh_material":
				(entry["obj"] as Mesh).material = entry["value"]
	calib.queue_free()
	await get_tree().process_frame

	# 4) Coste real de frame con vsync desactivado.
	var frame_delta_ms := await _measure_frame_cost(fx_roots, overlay)
	print("[RENDER][GPU] phase=frame_cost scene=%s delta_ms=%.3f" % [label, frame_delta_ms])

	# Restaura visibilidad y UI.
	_set_fx_visible(fx_roots, overlay, true)
	for node in hidden:
		if node is CanvasLayer:
			(node as CanvasLayer).visible = true
		elif node is Control:
			(node as Control).visible = true
	if mirror_was_visible:
		_set_node_visible(scene, "Mirrors", true)

	var added_dc := roundi(added_draw_calls)
	var overdraw_max := float(fragment_stats["overdraw_max"])
	var overdraw_p99 := float(fragment_stats["overdraw_p99"])
	print(
		"[RENDER][GPU] scene=%s added_draw_calls=%d(%.1f) fill_visual_pct=%.2f fill_visual_noise_pct=%.2f fill_visual_net_pct=%.2f"
		% [label, added_dc, added_draw_calls, visual_fill, visual_noise, visual_fill_net]
	)
	print(
		"[RENDER][GPU] scene=%s fill_fragments_pct=%.2f fill_fragments_noise_pct=%.2f overdraw_max=%.1f overdraw_p99=%.1f excluded_pct=%.1f"
		% [
			label, float(fragment_stats["fill_fragments_percent"]),
			probe_noise, overdraw_max, overdraw_p99,
			float(fragment_stats["excluded_percent"]),
		]
	)
	print(
		"[RENDER][GPU] scene=%s fx_frame_ms_delta=%.3f frame_budget_ms=%.3f"
		% [label, frame_delta_ms, FRAME_BUDGET_MS]
	)

	var max_draw_calls := int(_gpu_budget["max_draw_calls"])
	var max_overdraw := int(_gpu_budget["max_overdraw_layers"])
	var max_fill := float(_gpu_budget["max_fill_percent"])
	if added_dc > max_draw_calls:
		_failures.append("gpu_draw_calls:%s %d>%d" % [label, added_dc, max_draw_calls])
	if overdraw_max > float(max_overdraw):
		_failures.append("gpu_overdraw:%s %.1f>%d" % [label, overdraw_max, max_overdraw])
	if visual_fill_net > max_fill:
		_failures.append("gpu_fill_visual:%s %.2f>%.1f" % [label, visual_fill_net, max_fill])


func _measure_added_draw_calls(fx_roots: Array[Node], overlay: MeshInstance3D) -> float:
	_set_fx_visible(fx_roots, overlay, false)
	for _i in range(PROBE_DRAW_FRAMES):
		await get_tree().process_frame
	var off_total := 0.0
	for _i in range(PROBE_DRAW_FRAMES):
		await get_tree().process_frame
		off_total += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	_set_fx_visible(fx_roots, overlay, true)
	for _i in range(PROBE_DRAW_FRAMES):
		await get_tree().process_frame
	var on_total := 0.0
	for _i in range(PROBE_DRAW_FRAMES):
		await get_tree().process_frame
		on_total += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	return on_total / float(PROBE_DRAW_FRAMES) - off_total / float(PROBE_DRAW_FRAMES)


## Coste real de los FX: media de frame time con vsync off, FX off vs on.
func _measure_frame_cost(fx_roots: Array[Node], overlay: MeshInstance3D) -> float:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_set_fx_visible(fx_roots, overlay, false)
	var off_avg := await _avg_frame_ms(PROBE_TIMING_FRAMES)
	_set_fx_visible(fx_roots, overlay, true)
	var on_avg := await _avg_frame_ms(PROBE_TIMING_FRAMES)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	return on_avg - off_avg


func _avg_frame_ms(frames: int) -> float:
	for _i in range(5):
		await get_tree().process_frame
	var samples: Array[float] = []
	var previous := Time.get_ticks_usec()
	for _i in range(frames):
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		samples.append(float(now - previous) / 1000.0)
		previous = now
	var total := 0.0
	for sample in samples:
		total += sample
	return total / float(samples.size())


## Una captura tras dejar renderizar el estado actual (gap minimo de 1 frame
## para reducir la deriva temporal de los shaders con TIME).
func _snap() -> Image:
	for _i in range(PROBE_SNAP_FRAMES):
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	return image


func _set_fx_visible(fx_roots: Array[Node], overlay: MeshInstance3D, visible: bool) -> void:
	for root in fx_roots:
		root.visible = visible
	if overlay != null:
		overlay.visible = visible


func _hide_ui(scene: Node) -> Array[Node]:
	var hidden: Array[Node] = []
	var nodes: Array[Node] = []
	_collect_nodes(scene, nodes)
	for node in nodes:
		if node is CanvasLayer and (node as CanvasLayer).visible:
			(node as CanvasLayer).visible = false
			hidden.append(node)
		elif node is Control and node.get_parent() == scene and (node as Control).visible:
			(node as Control).visible = false
			hidden.append(node)
	return hidden


func _set_node_visible(scene: Node, node_name: String, visible: bool) -> bool:
	var target := scene.get_node_or_null(node_name)
	if target is Node3D and (target as Node3D).visible != visible:
		var previous := (target as Node3D).visible
		(target as Node3D).visible = visible
		return previous
	return false


func _collect_nodes(root: Node, out: Array[Node]) -> void:
	for child in root.get_children():
		out.append(child)
		_collect_nodes(child, out)


func _save_probe_shot(filename: String, image: Image) -> void:
	var path := "%s/%s" % [SHOT_DIR, filename]
	image.save_png(path)
	print("[RENDER] SHOT %s" % path)


## Imagen de evidencia: rojo donde los FX cambian el pixel.
func _diff_image(a: Image, b: Image) -> Image:
	var data_a := a.get_data()
	var data_b := b.get_data()
	var pixels := a.get_width() * a.get_height()
	var out := PackedByteArray()
	out.resize(pixels * 4)
	for index in range(pixels):
		var offset := index * 4
		var changed := (
			absi(int(data_a[offset]) - int(data_b[offset])) > VISUAL_FILL_THRESHOLD
			or absi(int(data_a[offset + 1]) - int(data_b[offset + 1])) > VISUAL_FILL_THRESHOLD
			or absi(int(data_a[offset + 2]) - int(data_b[offset + 2])) > VISUAL_FILL_THRESHOLD
		)
		if changed:
			out[offset] = 255
			out[offset + 3] = 255
		else:
			out[offset + 3] = 255
	return Image.create_from_data(a.get_width(), a.get_height(), false, Image.FORMAT_RGBA8, out)


## Pixeles que cambian mas de VISUAL_FILL_THRESHOLD codigos en cualquier canal.
func _visual_fill_percent(a: Image, b: Image) -> float:
	var data_a := a.get_data()
	var data_b := b.get_data()
	var pixels := a.get_width() * a.get_height()
	var changed := 0
	for index in range(pixels):
		var offset := index * 4
		if (
			absi(int(data_a[offset]) - int(data_b[offset])) > VISUAL_FILL_THRESHOLD
			or absi(int(data_a[offset + 1]) - int(data_b[offset + 1])) > VISUAL_FILL_THRESHOLD
			or absi(int(data_a[offset + 2]) - int(data_b[offset + 2])) > VISUAL_FILL_THRESHOLD
		):
			changed += 1
	return 100.0 * float(changed) / float(pixels)


## Piso de ruido de la sonda aditiva, en unidades de capas: delta medio
## absoluto entre dos capturas base (misma escena, sin FX) dividido por la
## respuesta media de una capa de calibracion. Es el sesgo maximo esperado
## por la animacion con TIME de los shaders mojados entre capturas.
func _noise_layers(base: Image, other: Image, cal1: Image) -> float:
	var data_base := base.get_data()
	var data_other := other.get_data()
	var data_cal := cal1.get_data()
	var pixels := base.get_width() * base.get_height()
	var response_sum := 0.0
	var delta_sum := 0.0
	for index in range(pixels):
		var offset := index * 4
		var best_r1 := 0
		var best_channel := -1
		for channel in range(3):
			var response := int(data_cal[offset + channel]) - int(data_base[offset + channel])
			if response > best_r1:
				best_r1 = response
				best_channel = channel
		if best_channel < 0 or best_r1 < CALIB_MIN_RESPONSE:
			continue
		response_sum += float(best_r1)
		delta_sum += float(absi(int(data_other[offset + best_channel]) - int(data_base[offset + best_channel])))
	if response_sum <= 0.0:
		return 0.0
	return delta_sum / response_sum


## Cuenta fragmentos FX por pixel resolviendo la respuesta calibrada del
## pipeline (1 y 2 capas aditivas) con interpolacion piecewise lineal: no
## asume sRGB, gamma ni tonemap. Los pixeles con respuesta de calibracion
## menor que CALIB_MIN_RESPONSE quedan excluidos y reportados.
func _fragment_stats(base: Image, cal1: Image, cal2: Image, fx: Image) -> Dictionary:
	var data_base := base.get_data()
	var data_cal1 := cal1.get_data()
	var data_cal2 := cal2.get_data()
	var data_fx := fx.get_data()
	var pixels := base.get_width() * base.get_height()
	var valid := 0
	var excluded := 0
	var sum := 0.0
	var max_n := 0.0
	var histogram := PackedInt32Array()
	histogram.resize(9)
	for index in range(pixels):
		var offset := index * 4
		# Elige el canal con mayor respuesta de calibracion (mas resolucion).
		var best_r1 := 0
		var best_channel := -1
		for channel in range(3):
			var response := int(data_cal1[offset + channel]) - int(data_base[offset + channel])
			if response > best_r1:
				best_r1 = response
				best_channel = channel
		if best_channel < 0 or best_r1 < CALIB_MIN_RESPONSE:
			excluded += 1
			continue
		var r2 := int(data_cal2[offset + best_channel]) - int(data_base[offset + best_channel])
		var delta := int(data_fx[offset + best_channel]) - int(data_base[offset + best_channel])
		if delta < 0:
			delta = 0
		var layers := 0.0
		if delta <= best_r1:
			layers = float(delta) / float(best_r1)
		else:
			var step := float(maxi(1, r2 - best_r1))
			if delta <= r2:
				layers = 1.0 + float(delta - best_r1) / step
			else:
				layers = 2.0 + float(delta - r2) / step
		layers = clampf(layers, 0.0, 8.0)
		valid += 1
		sum += layers
		histogram[clampi(int(round(layers)), 0, 8)] += 1
		if layers > max_n:
			max_n = layers
	# Percentil 99 de capas sobre los pixeles validos.
	var p99 := 0.0
	if valid > 0:
		var target := int(ceil(float(valid) * 0.99))
		var accumulated := 0
		for bucket in range(histogram.size()):
			accumulated += histogram[bucket]
			if accumulated >= target:
				p99 = float(bucket)
				break
	return {
		"fill_fragments_percent": 100.0 * sum / float(pixels),
		"overdraw_max": max_n,
		"overdraw_p99": p99,
		"valid_pixels": valid,
		"excluded_percent": 100.0 * float(excluded) / float(pixels),
	}


## Sustituye SOLO los materiales de los FX por la sonda aditiva. La escena
## conserva sus materiales reales (cancela en el diff). La sonda reutiliza el
## `vertex()` original de cada shader (billboard de estrellas, salpicaduras y
## gotas de camara) y solo sustituye el fragment() por un color aditivo
## constante, para que la geometria proyectada sea identificara al render real.
func _apply_probe_materials(controller: RainFxController) -> Array[Dictionary]:
	var saved: Array[Dictionary] = []
	if controller._vfx != null:
		var nodes: Array[Node] = []
		_collect_nodes(controller._vfx, nodes)
		for node in nodes:
			if node is GPUParticles3D:
				var particles := node as GPUParticles3D
				var pass_count := maxi(1, int(particles.get("draw_passes")))
				for pass_index in range(1, pass_count + 1):
					var draw_pass = particles.get("draw_pass_%d" % pass_index)
					if draw_pass == null:
						continue
					if draw_pass is Mesh:
						var mesh := draw_pass as Mesh
						saved.append({"kind": "mesh_material", "obj": mesh, "value": mesh.material})
						mesh.material = _probe_from_material(mesh.material)
					elif draw_pass is MeshInstance3D:
						var mesh_instance := draw_pass as MeshInstance3D
						saved.append({
							"kind": "override", "obj": mesh_instance,
							"value": mesh_instance.material_override,
						})
						mesh_instance.material_override = _probe_from_material(mesh_instance.material_override)
			elif node is GeometryInstance3D:
				var geometry := node as GeometryInstance3D
				saved.append({"kind": "override", "obj": geometry, "value": geometry.material_override})
				geometry.material_override = _probe_from_material(geometry.material_override)
	if controller._camera_overlay != null:
		var overlay := controller._camera_overlay
		saved.append({"kind": "override", "obj": overlay, "value": overlay.material_override})
		overlay.material_override = _probe_from_material(overlay.material_override)
	return saved


## Construye la sonda aditiva a partir del shader original del material.
func _probe_from_material(original: Material) -> ShaderMaterial:
	if original is ShaderMaterial and (original as ShaderMaterial).shader != null:
		return _probe_from_shader((original as ShaderMaterial).shader)
	return _probe_material(true)


func _probe_from_shader(original: Shader) -> ShaderMaterial:
	var code := original.code
	var marker := "void fragment()"
	var index := code.find(marker)
	var head := code.substr(0, index) if index > 0 else code
	# La sonda siempre suma: blend_mix dejaria el pixel sin el incremento
	# calibrado. Los flags de profundidad originales se conservan (estrellas y
	# salpicaduras con test de profundidad; gotas de camara sin el).
	head = head.replace("blend_mix", "blend_add")
	# Declarar add_color junto a render_mode (antes que cualquier uso).
	var uniform_line := "\nuniform vec3 add_color = vec3(0.00392156862745098);"
	var render_index := head.find("render_mode")
	var statement_end := head.find(";", render_index) if render_index >= 0 else -1
	if statement_end >= 0:
		head = head.substr(0, statement_end + 1) + uniform_line + head.substr(statement_end + 1)
	else:
		head += uniform_line
	var shader := Shader.new()
	shader.code = head + "\nvoid fragment() {\n\tALBEDO = add_color;\n}\n"
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func _probe_material(nodepth: bool) -> ShaderMaterial:
	var shader := Shader.new()
	var modes := "blend_add, unshaded, cull_disabled, depth_draw_never, fog_disabled"
	if nodepth:
		modes += ", depth_test_disabled"
	shader.code = (
		"shader_type spatial;\n"
		+ "render_mode %s;\n" % modes
		+ "uniform vec3 add_color = vec3(0.00392156862745098);\n"
		+ "void fragment() {\n\tALBEDO = add_color;\n}\n"
	)
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func _make_calib_quad(camera: Camera3D) -> MeshInstance3D:
	var quad := MeshInstance3D.new()
	quad.name = "ProbeCalib"
	var mesh := QuadMesh.new()
	mesh.size = Vector2(8.0, 8.0)
	quad.mesh = mesh
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	camera.add_child(quad)
	quad.position = Vector3(0.0, 0.0, -0.1)
	quad.visible = false
	return quad
