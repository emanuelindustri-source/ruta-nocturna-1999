extends Node
## Sonda de rendimiento de dispositivo (F3.5). Servicio de escena, NO autoload.
##
## Se instancia en Boot, VerticalSlice y CabinInteraction. Es inerte si no
## existe `user://perf_route.marker`: sin marcador no cambia ningun comportamiento
## normal del juego ni de las pruebas.
##
## Flujo (lo crea `tools/test_android_adb.ps1` en el Redmi):
##   1. En Boot espera `EventBus.application_booted`, registra el tiempo hasta
##      BOOT_READY y navega a la primera escena de la ruta.
##   2. En cada escena de la ruta espera el warm-up de RainFx, pre-simula 90 s
##      de tormenta (modelos de F3.3), mide frames, primitivas y draw calls, y
##      escribe el parcial en `user://perf_report.json` (status=measuring para
##      que la prueba ADB pueda capturar PSS/captura en esa escena).
##   3. Al terminar la ultima escena marca `done=true` y borra el marcador y el
##      estado; la app se queda en la ultima escena para la captura final.
##
## Presupuestos (AGENTS.md seccion 9 + budgets.mobile.frame_budget_ms del
## contrato): 33,333 ms/frame, 120.000 triángulos, PSS <= 1.228,8 MB medidos
## por la prueba ADB, carga de escena <= 15.000 ms.

const MARKER_PATH := "user://perf_route.marker"
const STATE_PATH := "user://perf_state.json"
const REPORT_PATH := "user://perf_report.json"

const BOOT_SCENE := "res://scenes/boot/Boot.tscn"
const SLICE_SCENE := "res://scenes/vertical_slice/VerticalSlice.tscn"
const CABIN_SCENE := "res://scenes/vehicle/CabinInteraction.tscn"
const WORLD_SCENE := "res://scenes/world/WorldTerrain.tscn"
const WORLD_WAIT_MS := 30000
const WORLD_STRESS_SPEED_MPS := 1200.0

const MEASURE_FRAMES := 300
const AUTO_FRAMES := 15
const SOAK_SECONDS := 90.0

## Presupuestos moviles obligatorios (AGENTS.md seccion 9).
const BUDGET_FRAME_MS := 33.333
const BUDGET_MIN_FPS := 30
const BUDGET_TARGET_FPS := 60
const BUDGET_TRIANGLES := 120000
const BUDGET_PSS_MB := 1228.8
const BUDGET_LOAD_MS := 15000.0

var _routes: Array[String] = []
var _active := false


func _ready() -> void:
	if not FileAccess.file_exists(MARKER_PATH):
		return
	_routes = _parse_marker(_read_text(MARKER_PATH))
	if _routes.is_empty():
		return
	var root := get_parent()
	if root == null:
		return
	var root_path := str(root.scene_file_path)
	if root_path == BOOT_SCENE:
		_active = true
		EventBus.application_booted.connect(_on_booted, CONNECT_ONE_SHOT)
		var routes_text := ""
		for route_index in range(_routes.size()):
			if route_index > 0:
				routes_text += ","
			routes_text += _routes[route_index]
		print("[PERF] ROUTE_ARMED routes=%s" % routes_text)
	elif root_path in [SLICE_SCENE, CABIN_SCENE, WORLD_SCENE]:
		_run_for_scene(root_path)


func _on_booted(_version: String) -> void:
	# BOOT_READY emitido por Boot._ready: el arranque del motor ya esta medido
	# desde el arranque del proceso hasta aqui.
	var boot_ready_ms := Time.get_ticks_msec()
	var state := {
		"routes": _routes,
		"index": 0,
		"t0_ms": boot_ready_ms,
		"boot_ready_ms": boot_ready_ms,
		"started_utc": Time.get_datetime_string_from_system(true),
	}
	_write_json(STATE_PATH, state)
	print("[PERF] BOOT_READY_MS %d" % boot_ready_ms)
	var target := _scene_for(_routes[0])
	if target.is_empty() or not SceneRouter.change_scene(target, "device_perf"):
		_finish_error("no_se_pudo_navegar_a_%s" % _routes[0])


func _run_for_scene(root_path: String) -> void:
	var state := _read_json(STATE_PATH)
	if state.is_empty():
		return
	var routes: Array = state.get("routes", [])
	var index := int(state.get("index", -1))
	if index < 0 or index >= routes.size() or index >= _routes.size():
		return
	if _scene_for(str(routes[index])) != root_path:
		# Otra escena de la ruta: todavia no le toca (o el marcador quedo viejo).
		return
	_active = true
	_measure(str(routes[index]), index, state)


func _measure(label: String, index: int, state: Dictionary) -> void:
	var t0_ms := int(state.get("t0_ms", Time.get_ticks_msec()))
	var root := get_parent()
	var world: WorldDirector = root as WorldDirector
	var world_ready := true
	if world != null:
		var waited := 0
		while not world.is_world_ready() and waited < WORLD_WAIT_MS:
			await get_tree().process_frame
			waited += 16
		world_ready = world.is_world_ready()
		world.set_tour_speed(WORLD_STRESS_SPEED_MPS)
		world.set_paused(false)
	await get_tree().process_frame
	await get_tree().process_frame
	var load_ms := Time.get_ticks_msec() - t0_ms

	var controller := root.get_node_or_null("RainFx") as RainFxController
	var warmup_done := true
	var warmup_ms := 0.0
	if controller != null:
		warmup_done = controller.warmup_done
		warmup_ms = controller.warmup_ms
		# Arranque en modo automatico para que RainVFX active emitting con la
		# camara anclada; luego paso manual determinista como en la prueba de
		# render de PC.
		for _i in range(AUTO_FRAMES):
			await get_tree().process_frame
		controller.manual_mode = true
		var steps := int(SOAK_SECONDS * 4.0)
		for _i in range(steps):
			controller.step_models(0.25)
		controller.refresh_uniforms()

	var section := {
		"scene": label,
		"status": "measuring",
		"load_ms": load_ms,
		"warmup_done": warmup_done and world_ready,
		"warmup_ms": warmup_ms,
		"soak_seconds": SOAK_SECONDS if controller != null else 0.0,
		"measuring_started_utc": Time.get_datetime_string_from_system(true),
	}
	if world != null:
		section["world"] = world.streaming_snapshot()
	_write_report(section, index, false)
	print("[PERF] MEASURE_START scene=%s load_ms=%d warmup=%s" % [label, load_ms, str(warmup_done)])

	var samples: Array[float] = []
	var primitives := 0.0
	var draw_calls := 0.0
	var objects := 0.0
	var previous := Time.get_ticks_usec()
	for _i in range(MEASURE_FRAMES):
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		samples.append(float(now - previous) / 1000.0)
		previous = now
		primitives += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		draw_calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		objects += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)

	samples.sort()
	var total := 0.0
	for sample in samples:
		total += sample
	var count := float(samples.size())
	var avg := total / count
	var p50 := samples[clampi(int(count * 0.50), 0, samples.size() - 1)]
	var p95 := samples[clampi(int(count * 0.95), 0, samples.size() - 1)]
	var worst := samples[samples.size() - 1]
	var jank_budget := 0
	var jank_severe := 0
	for sample in samples:
		if sample > BUDGET_FRAME_MS:
			jank_budget += 1
		if sample > 100.0:
			jank_severe += 1

	section["status"] = "done"
	section["frames"] = samples.size()
	section["frame_ms_avg"] = avg
	section["frame_ms_p50"] = p50
	section["frame_ms_p95"] = p95
	section["frame_ms_max"] = worst
	section["fps_avg"] = 1000.0 / maxf(0.001, avg)
	section["jank_gt_frame_budget"] = jank_budget
	section["jank_gt_100ms"] = jank_severe
	section["primitives_avg"] = primitives / count
	section["draw_calls_avg"] = draw_calls / count
	section["objects_avg"] = objects / count
	section["measuring_done_utc"] = Time.get_datetime_string_from_system(true)
	if world != null:
		world.set_tour_speed(0.0)
		world.set_paused(true)
		section["world"] = world.streaming_snapshot()

	var last := index >= _routes.size() - 1
	_write_report(section, index, last)
	print(
		"[PERF] MEASURE_DONE scene=%s avg=%.2f p95=%.2f max=%.2f prims=%.0f draws=%.1f"
		% [label, avg, p95, worst, primitives / count, draw_calls / count]
	)

	if last:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(MARKER_PATH))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(STATE_PATH))
		print("[PERF] ROUTE_DONE scenes=%d" % _routes.size())
		return

	var next_index := index + 1
	var next_state := {
		"routes": _routes,
		"index": next_index,
		"t0_ms": Time.get_ticks_msec(),
		"boot_ready_ms": int(state.get("boot_ready_ms", 0)),
		"started_utc": str(state.get("started_utc", "")),
	}
	_write_json(STATE_PATH, next_state)
	var target := _scene_for(_routes[next_index])
	if target.is_empty() or not SceneRouter.change_scene(target, "device_perf"):
		_finish_error("no_se_pudo_navegar_a_%s" % _routes[next_index])


## Escribe (o reescribe) el reporte manteniendo las secciones ya completadas.
func _write_report(section: Dictionary, index: int, done: bool) -> void:
	var report := _read_json(REPORT_PATH)
	if report.is_empty():
		report = {
			"project_version": str(ProjectSettings.get_setting("application/config/version", "0.0.0")),
			"platform": OS.get_name(),
			"renderer": RenderingServer.get_video_adapter_name(),
			"viewport": "%dx%d" % [
				get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y,
			],
			"started_utc": Time.get_datetime_string_from_system(true),
			"budgets": {
				"frame_budget_ms": BUDGET_FRAME_MS,
				"min_fps": BUDGET_MIN_FPS,
				"target_fps": BUDGET_TARGET_FPS,
				"max_triangles": BUDGET_TRIANGLES,
				"max_pss_mb": BUDGET_PSS_MB,
				"max_load_ms": BUDGET_LOAD_MS,
			},
			"sections": [],
		}
	var sections: Array = report.get("sections", [])
	var replaced := false
	for i in range(sections.size()):
		var existing: Dictionary = sections[i]
		if str(existing.get("scene", "")) == str(section.get("scene", "")):
			sections[i] = section
			replaced = true
			break
	if not replaced:
		sections.append(section)
	report["sections"] = sections
	report["route_index"] = index
	report["done"] = done
	report["updated_utc"] = Time.get_datetime_string_from_system(true)
	_write_json(REPORT_PATH, report)


func _finish_error(reason: String) -> void:
	var report := _read_json(REPORT_PATH)
	if report.is_empty():
		report = {"sections": [], "budgets": {}}
	report["error"] = reason
	report["done"] = true
	report["updated_utc"] = Time.get_datetime_string_from_system(true)
	_write_json(REPORT_PATH, report)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(MARKER_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(STATE_PATH))
	print("[PERF] ROUTE_ERROR %s" % reason)


func _scene_for(route: String) -> String:
	match route:
		"boot":
			return BOOT_SCENE
		"slice":
			return SLICE_SCENE
		"cabin":
			return CABIN_SCENE
		"world":
			return WORLD_SCENE
	return ""


func _parse_marker(text: String) -> Array[String]:
	var result: Array[String] = []
	for entry in text.strip_edges().split(","):
		var route := entry.strip_edges().to_lower()
		if route in ["boot", "slice", "cabin", "world"] and not result.has(route):
			result.append(route)
	return result


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(_read_text(path))
	return parsed if parsed is Dictionary else {}


func _write_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("[PERF] no se pudo escribir %s" % path)
		return
	file.store_string(JSON.stringify(data, "  "))
	file.close()
