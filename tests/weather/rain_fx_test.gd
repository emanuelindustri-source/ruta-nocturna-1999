extends Node
## Pruebas headless de la lluvia física de F3.3 (tag v0.3.2).
##
## Valida contrato, humedad, gotas, limpiaparabrisas, charcos y presupuestos
## CPU. No mide GPU ni shaders: eso es F3.4/F3.5.

const EXPECTED_VERSION := "0.3.3"
const DELTA := 1.0 / 60.0
const DELTA_MOBILE := 1.0 / 30.0

var _passed := 0
var _failed: Array[String] = []
var _spec: RainSurfaceSpec


func _ready() -> void:
	print("[RAIN] Inicio de pruebas de lluvia física, humedad y charcos")
	_spec = RainSurfaceSpec.new()
	_test_contract()
	_test_wetness()
	_test_droplets()
	_test_wipers()
	_test_puddles()
	_test_budgets()
	_test_fx_shaders()
	await _test_fx_controller()
	_test_fx_budgets()
	_finish()


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("[RAIN] OK   %s" % label)
	else:
		_failed.append(label)
		print("[RAIN] FAIL %s" % label)


func _check_near(value: float, expected: float, tolerance: float, label: String) -> void:
	_check(absf(value - expected) <= tolerance, "%s (%.4f ~ %.4f)" % [label, value, expected])


func _finish() -> void:
	if _failed.is_empty():
		print("[RAIN] OK %d comprobaciones" % _passed)
		get_tree().quit(0)
		return
	print("[RAIN] Fallaron %d de %d comprobaciones:" % [_failed.size(), _passed + _failed.size()])
	for failure in _failed:
		print("[RAIN]   - %s" % failure)
	print("[RAIN] FAIL")
	get_tree().quit(1)


func _test_contract() -> void:
	_check(_spec.load_spec(), "contrato rain_surface_fx carga sin errores")
	_check(_spec.errors.is_empty(), "cargador sin errores")
	_check(int(_spec.integer("schema_version")) == 1, "schema_version 1")
	_check(str(_spec.value("vehicle_id", "")) == "chevrolet_esteem_1999_auto_beige", "vehicle_id del Esteem")
	_check(_spec.section("surfaces").get("classes", []).size() >= 6, "seis clases de superficie")
	_check(_spec.section("surfaces").get("vehicle_panels", []).size() >= 8, "ocho paneles de vehículo")
	_check(_spec.section("surfaces").get("road_surfaces", []).size() >= 3, "tres superficies de vía")
	_check(_spec.section("droplets").get("profiles", []).size() == 2, "perfiles glass/paint")
	_check(_spec.section("wiper").get("wipers", []).size() == 2, "dos limpiaparabrisas")
	_check(_spec.section("puddles").get("zone_archetypes", []).size() >= 5, "cinco arquetipos de charco")
	_check(_spec.section("budgets").has("pc"), "presupuesto PC declarado")
	_check(_spec.section("budgets").has("mobile"), "presupuesto móvil declarado")
	_check(_spec.panel_spec("windshield").get("wiper_zone") == "windshield", "parabrisas con zona de limpia")
	var panels: Array = _spec.section("surfaces").get("vehicle_panels", [])
	var wiper_entries: Array = _spec.section("wiper").get("wipers", [])
	var windshield_entry: Dictionary = panels[0] if not panels.is_empty() else {}
	var left_wiper: Dictionary = wiper_entries[0] if not wiper_entries.is_empty() else {}
	var right_wiper: Dictionary = wiper_entries[1] if wiper_entries.size() > 1 else {}
	_check_near(float(windshield_entry.get("exposure", 0.0)), 1.0, 0.001, "exposición del parabrisas")
	_check(float(left_wiper.get("blade_length_m", 0.0)) > 0.4, "longitud de la escoba izquierda")
	_check(float(right_wiper.get("sweep_delta_deg", 0.0)) > 0.0, "barrido derecho positivo")
	_check(float(left_wiper.get("sweep_delta_deg", 0.0)) < 0.0, "barrido izquierdo espejo")
	_check(_spec.number("puddles.vehicle_water_link.air_intake_height_m", 0.0) > 0.5, "altura de admisión enlazada")
	_check(_spec.boolean("budgets.measurement.warmup_required_before_gameplay"), "warm-up obligatorio declarado")
	var version := str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	_check(version == EXPECTED_VERSION, "versión del proyecto %s" % EXPECTED_VERSION)
	_check(FileAccess.file_exists("res://VERSION") and FileAccess.get_file_as_string("res://VERSION").strip_edges() == EXPECTED_VERSION, "VERSION coincide")
	_check(str(_spec.value("budgets.pc.gpu.status", "")) == "pending_f34_f35", "GPU pendiente de F3.4/F3.5")
	_check(int(_spec.integer("budgets.pc.added_triangles")) == 0, "F3.3 no añade triángulos")
	_check(int(_spec.integer("budgets.pc.added_draw_calls")) == 0, "F3.3 no añade draw calls")


func _test_wetness() -> void:
	var model := SurfaceWetnessModel.new()
	_check(model.configure(_spec), "modelo de humedad configura")
	_check(model.get_panel_ids().size() >= 8, "paneles de vehículo cargados")
	_check(model.get_road_ids().size() >= 3, "superficies de vía cargadas")
	_check(model.get_wetness("windshield") == 0.0, "parabrisas inicia seco")
	_check(model.get_state("windshield") == "dry", "estado inicial dry")
	model.step(DELTA, 1.0, 0.95, 10.0, 19.0)
	_check(model.get_wetness("windshield") > 0.0, "la lluvia moja el parabrisas")
	for _i in range(1200):
		model.step(DELTA, 1.0, 0.95, 10.0, 19.0)
	_check(model.get_wetness("windshield") > 0.75, "parabrisas empapado tras 20 s de tormenta")
	_check(model.get_wetness("hood") > 0.35, "capó mojado tras 20 s de tormenta")
	_check(model.get_state("windshield") in ["wet", "soaked"], "estado de parabrisas mojado")
	_check(model.get_wetness("asphalt_crown") > 0.0, "asfalto acumula película")
	for _i in range(480):
		model.step(0.25, 0.0, 0.6, 6.0, 28.0)
	_check(model.get_film_mm("asphalt_crown") > model.get_film_mm("windshield"), "el asfalto retiene más agua absoluta que el vidrio")
	for _i in range(3120):
		model.step(0.25, 0.0, 0.6, 6.0, 28.0)
	print("[RAIN] Humedad tras secado: parabrisas %.4f, capó %.4f, asfalto %.4f" % [
		model.get_wetness("windshield"), model.get_wetness("hood"), model.get_wetness("asphalt_crown")
	])
	_check(model.get_wetness("windshield") < 0.25, "parabrisas se seca en 15 min")
	_check(model.get_wetness("hood") < 0.35, "capó se seca en 15 min")
	_check(model.get_runoff("windshield") >= 0.0, "escurrido no negativo")
	_check(model.get_absorber_runoff() >= 0.0, "escorrentía de vía no negativa")
	model.set_wetness("windshield", 2.0)
	_check_near(model.get_wetness("windshield"), 1.0, 0.0001, "wetness se acota a 1")
	model.set_wetness("windshield", -1.0)
	_check_near(model.get_wetness("windshield"), 0.0, 0.0001, "wetness se acota a 0")
	model.reset()
	_check(model.get_wetness("hood") == 0.0, "reset deja las superficies secas")


func _test_droplets() -> void:
	var field := DropletFlowModel.new()
	_check(field.configure(_spec, "glass", "windshield"), "campo de gotas de vidrio configura")
	_check(field.max_droplets == 1536, "capacidad de vidrio 1536")
	_check(field.count == 0, "campo de gotas inicia vacío")
	for _i in range(600):
		field.step(DELTA, 0.9, 1.0, 10.0)
	_check(field.count > 50, "nucleación produce gotas")
	_check(field.count <= field.max_droplets, "nunca supera la capacidad")
	var bounds := field.get_bounds_mm()
	var instances := field.get_instances()
	var valid := true
	for index in range(field.count):
		var x := instances[index * 6]
		var y := instances[index * 6 + 1]
		var radius := instances[index * 6 + 2]
		if x < 0.0 or x > bounds.x or y < 0.0 or y > bounds.y or radius <= 0.0 or is_nan(x + y + radius):
			valid = false
			break
	_check(valid, "todas las gotas están en bounds y tienen radio positivo")
	var sliding := 0
	for index in range(field.count):
		if field.get_state_name(index) == "sliding":
			sliding += 1
	_check(sliding > 0, "hay gotas deslizando tras la tormenta")
	for _i in range(900):
		field.step(DELTA, 0.9, 1.0, 10.0)
	_check(field.get_runoff_ml() > 0.0, "las gotas que salen suman escurrido")
	_check(field.get_critical_radius_mm(1.0) < field.get_critical_radius_mm(0.2), "el radio crítico baja con humedad")
	var deterministic_a := DropletFlowModel.new()
	var deterministic_b := DropletFlowModel.new()
	_check(deterministic_a.configure(_spec, "glass", "windshield"), "campo determinista A")
	_check(deterministic_b.configure(_spec, "glass", "windshield"), "campo determinista B")
	for _i in range(300):
		deterministic_a.step(DELTA, 0.9, 1.0, 10.0)
		deterministic_b.step(DELTA, 0.9, 1.0, 10.0)
	_check(deterministic_a.count == deterministic_b.count, "dos campos con la misma semilla coinciden en cantidad")
	if deterministic_a.count > 0 and deterministic_b.count > 0:
		var first_a := deterministic_a.get_instances()
		var first_b := deterministic_b.get_instances()
		_check_near(first_a[0], first_b[0], 0.0001, "la primera gota coincide en X")
		_check_near(first_a[1], first_b[1], 0.0001, "la primera gota coincide en Y")
	var wipe_field := DropletFlowModel.new()
	_check(wipe_field.configure(_spec, "glass", "windshield", 64), "campo pequeño para barrido")
	wipe_field.add_droplet(50.0, 0.0, 1.0)
	wipe_field.add_droplet(0.0, 50.0, 1.0)
	wipe_field.add_droplet(150.0, 0.0, 1.0)
	var removed := wipe_field.clear_sector(Vector2.ZERO, 100.0, deg_to_rad(-10.0), deg_to_rad(10.0), 1.0)
	_check(removed == 1, "el sector limpia solo la gota interior")
	_check(wipe_field.count == 2, "las gotas fuera del sector permanecen")
	var capped := DropletFlowModel.new()
	_check(capped.configure(_spec, "glass", "windshield", 8), "campo capado a 8 gotas")
	for _i in range(200):
		capped.step(DELTA, 1.0, 1.0, 0.0)
	_check(capped.count <= 8, "el campo capado respeta el máximo")
	var paint := DropletFlowModel.new()
	_check(paint.configure(_spec, "paint", "hood"), "campo de gotas de pintura configura")
	for _i in range(600):
		paint.step(DELTA, 0.9, 1.0, 10.0)
	_check(paint.count > 20, "la pintura también nuclea gotas")
	_check(paint.get_bounds_mm().x > field.get_bounds_mm().x, "el capó es más ancho que el parabrisas")


func _test_wipers() -> void:
	var wipers := WiperKinematics.new()
	_check(wipers.configure(_spec), "cinemática de limpiaparabrisas configura")
	_check(wipers.get_wiper_count() == 2, "dos escobillas")
	_check(wipers.get_wiper_ids() == PackedStringArray(["left", "right"]), "IDs left/right")
	_check(wipers.get_mode() == "off", "inicia apagado")
	var left_park := wipers.get_angle(0)
	var right_park := wipers.get_angle(1)
	_check(absf(left_park - 180.0) < 0.01, "escobilla izquierda aparcada a 180°")
	_check(absf(right_park) < 0.01, "escobilla derecha aparcada a 0°")
	_check(wipers.set_mode("low"), "modo lento aceptado")
	for _i in range(120):
		wipers.step(DELTA)
	_check(wipers.get_cycle_count() >= 1, "modo lento completa un ciclo en 2 s")
	_check(wipers.get_angle(0) != left_park or wipers.get_angle(1) != right_park, "el barrido mueve las escobillas")
	var low_cycles := wipers.get_cycle_count()
	_check(wipers.set_mode("high"), "modo rápido aceptado")
	for _i in range(600):
		wipers.step(DELTA)
	_check(wipers.get_cycle_count() - low_cycles > 5, "modo rápido completa más ciclos en 10 s")
	_check(wipers.set_mode("intermittent"), "modo intermitente aceptado")
	for _i in range(6):
		wipers.step(DELTA)
	_check(wipers.get_state() == "intermittent_wait", "intermitente espera tras arrancar")
	var angle_wait := wipers.get_angle(0)
	for _i in range(30):
		wipers.step(DELTA)
	_check(absf(wipers.get_angle(0) - angle_wait) < 0.01, "la escobilla queda aparcada durante la espera")
	_check(wipers.set_intermittent_index(2), "índice de intermitencia aceptado")
	_check(not wipers.set_intermittent_index(99), "índice de intermitencia inválido rechazado")
	wipers.set_mode("low")
	for _i in range(6000):
		wipers.step(DELTA)
	_check(wipers.get_wear() > 0.0, "el uso acumula desgaste")
	var efficiency_worn := wipers.get_clearing_efficiency()
	wipers.set_wear(0.0)
	_check(wipers.get_clearing_efficiency() > efficiency_worn, "la goma nueva limpia más que la gastada")
	wipers.set_wear(0.75)
	_check(wipers.is_service_limit(), "umbral de servicio alcanzado")
	_check(not wipers.is_replace_limit(), "umbral de sustitución aún no alcanzado")
	wipers.set_wear(0.95)
	_check(wipers.is_replace_limit(), "umbral de sustitución alcanzado")
	_check(wipers.get_streak_factor() > 0.0, "la goma gastada deja más estela")
	var clear_field := DropletFlowModel.new()
	_check(clear_field.configure(_spec, "glass", "windshield", 128), "campo para probar el barrido")
	for x in range(0, 11):
		for y in range(0, 5):
			clear_field.add_droplet(float(x) * 120.0, float(y) * 100.0, 1.0)
	var before := clear_field.count
	wipers.set_mode("low")
	wipers.set_wear(0.0)
	for _i in range(60):
		wipers.step(DELTA, clear_field)
	_check(clear_field.count < before, "el barrido elimina gotas del parabrisas")
	var empty_field := DropletFlowModel.new()
	_check(empty_field.configure(_spec, "glass", "windshield", 8), "campo vacío para barrido")
	wipers.set_mode("off")
	for _i in range(30):
		wipers.step(DELTA, empty_field)
	_check(wipers.get_state() == "off", "modo apagado detiene el barrido")


func _test_puddles() -> void:
	var puddles := PuddleModel.new()
	_check(puddles.configure(_spec, true), "modelo de charcos configura")
	_check(puddles.get_zone_ids().size() == 5, "cinco zonas por defecto")
	_check(puddles.get_archetype_ids().size() == 5, "cinco arquetipos cargados")
	_check(puddles.get_depth_mm("asphalt_low_spot") == 0.0, "charco inicia seco")
	_check(puddles.get_state("asphalt_low_spot") == "dry", "estado inicial dry")
	for _i in range(6000):
		puddles.step(0.1, 1.0, 0.95, 10.0, 19.0, 0.001)
	_check(puddles.get_depth_mm("asphalt_low_spot") > 0.2, "la tormenta forma charco en el hundimiento")
	_check(puddles.get_depth_mm("pothole") > 0.0, "el bache acumula agua")
	_check(puddles.get_depth_mm("asphalt_low_spot") <= 8.0, "el charco no supera su capacidad")
	_check(puddles.get_depth_mm("pothole") <= 35.0, "el bache no supera su capacidad")
	var storm_depth := puddles.get_depth_mm("asphalt_low_spot")
	for _i in range(6000):
		puddles.step(0.1, 0.0, 0.6, 6.0, 28.0, 0.0)
	_check(puddles.get_depth_mm("asphalt_low_spot") < storm_depth, "el charco drena al dejar de llover")
	_check(puddles.get_depth_mm("asphalt_low_spot") >= 0.0, "la profundidad nunca es negativa")
	puddles.set_depth("asphalt_low_spot", 4.0)
	_check_near(puddles.get_hydroplane_risk("asphalt_low_spot", 30.0), 0.0, 0.0001, "sin riesgo por debajo de 45 km/h")
	_check(puddles.get_hydroplane_risk("asphalt_low_spot", 80.0) > 0.0, "riesgo de hidroplaneo a 80 km/h")
	_check(puddles.get_hydroplane_risk("asphalt_low_spot", 120.0) >= puddles.get_hydroplane_risk("asphalt_low_spot", 80.0), "el riesgo no baja al subir la velocidad")
	puddles.set_depth("ford_crossing", 200.0)
	_check(puddles.get_wading_state("ford_crossing") == "safe", "vado de 0,2 m seguro")
	puddles.set_depth("ford_crossing", 500.0)
	_check(puddles.get_wading_state("ford_crossing") == "caution", "vado de 0,5 m con precaución")
	puddles.set_depth("ford_crossing", 1000.0)
	_check(puddles.get_wading_state("ford_crossing") == "danger", "vado de 1 m peligroso")
	_check(puddles.get_total_water_l() >= 0.0, "agua total no negativa")
	puddles.reset()
	_check(puddles.get_depth_mm("ford_crossing") == 0.0, "reset vacía los charcos")


func _test_budgets() -> void:
	var pc: Dictionary = _spec.section("budgets").get("pc", {})
	var mobile: Dictionary = _spec.section("budgets").get("mobile", {})
	_check(int(pc.get("max_droplets_total", 0)) == 4096, "presupuesto PC de 4096 gotas")
	_check(int(mobile.get("max_droplets_total", 0)) == 1536, "presupuesto móvil de 1536 gotas")
	_check(int(pc.get("max_puddle_zones", 0)) == 24, "presupuesto PC de 24 charcos")
	_check(int(mobile.get("max_puddle_zones", 0)) == 12, "presupuesto móvil de 12 charcos")
	_check(int(pc.get("simulation_hz", 0)) == 60, "simulación PC a 60 Hz")
	_check(int(mobile.get("simulation_hz", 0)) == 30, "simulación móvil a 30 Hz")
	_check(float(pc.get("rain_cpu_budget_ms", 0.0)) <= 1.0, "CPU PC declarada <= 1,0 ms")
	_check(float(mobile.get("rain_cpu_budget_ms", 0.0)) <= 1.5, "CPU móvil declarada <= 1,5 ms")
	_check(int(pc.get("added_triangles", -1)) == 0, "sin triángulos nuevos en PC")
	_check(int(mobile.get("added_draw_calls", -1)) == 0, "sin draw calls nuevos en móvil")
	_check(float(pc.get("rain_cpu_p95_budget_ms", 0.0)) >= float(pc.get("rain_cpu_budget_ms", 0.0)), "p95 PC >= media PC")
	_check(float(mobile.get("rain_cpu_p95_budget_ms", 0.0)) >= float(mobile.get("rain_cpu_budget_ms", 0.0)), "p95 móvil >= media móvil")
	var pc_result := _measure_profile(int(pc.get("max_droplets_total", 4096)) / 2, int(pc.get("max_droplets_total", 4096)) / 2, int(pc.get("max_puddle_zones", 24)), DELTA)
	print("[RAIN] Presupuesto PC: media %.3f ms, p95 %.3f ms, máx %.3f ms" % [pc_result["avg_ms"], pc_result["p95_ms"], pc_result["max_ms"]])
	_check(pc_result["avg_ms"] <= float(pc.get("rain_cpu_budget_ms", 1.0)), "CPU PC media dentro del presupuesto")
	_check(pc_result["p95_ms"] <= float(pc.get("rain_cpu_p95_budget_ms", 1.6)), "CPU PC p95 dentro del presupuesto")
	var mobile_result := _measure_profile(int(mobile.get("max_droplets_total", 1536)) / 2, int(mobile.get("max_droplets_total", 1536)) / 2, int(mobile.get("max_puddle_zones", 12)), DELTA_MOBILE)
	print("[RAIN] Presupuesto móvil: media %.3f ms, p95 %.3f ms, máx %.3f ms" % [mobile_result["avg_ms"], mobile_result["p95_ms"], mobile_result["max_ms"]])
	_check(mobile_result["avg_ms"] <= float(mobile.get("rain_cpu_budget_ms", 1.5)), "CPU móvil media dentro del presupuesto")
	_check(mobile_result["p95_ms"] <= float(mobile.get("rain_cpu_p95_budget_ms", 2.4)), "CPU móvil p95 dentro del presupuesto")
	_check(str(_spec.value("budgets.measurement.gpu_status", "")) == "pending_f34_f35", "GPU se medirá en F3.4/F3.5")


func _measure_profile(glass_capacity: int, paint_capacity: int, puddle_count: int, dt: float) -> Dictionary:
	var wetness := SurfaceWetnessModel.new()
	wetness.configure(_spec)
	var glass := DropletFlowModel.new()
	glass.configure(_spec, "glass", "windshield", glass_capacity)
	var paint := DropletFlowModel.new()
	paint.configure(_spec, "paint", "hood", paint_capacity)
	var wipers := WiperKinematics.new()
	wipers.configure(_spec)
	wipers.set_mode("high")
	var puddles := PuddleModel.new()
	puddles.configure(_spec, false)
	var archetypes := puddles.get_archetype_ids()
	for index in range(puddle_count):
		var archetype_id := archetypes[index % archetypes.size()]
		puddles.add_zone("bench_zone_%02d" % index, archetype_id, 1.0, 1.0)
	for _i in range(120):
		wetness.step(0.25, 1.0, 0.95, 10.0, 19.0)
		glass.step(0.25, wetness.get_wetness("windshield"), 1.0, 10.0)
		paint.step(0.25, wetness.get_wetness("hood"), 1.0, 10.0)
		wipers.step(0.25, glass)
		puddles.step(0.25, 1.0, 0.95, 10.0, 19.0, wetness.get_absorber_runoff())
	while glass.count < glass.max_droplets:
		glass.add_droplet(float(glass.count % 120) * 10.0, float(glass.count % 40) * 10.0, 1.0, false)
	while paint.count < paint.max_droplets:
		paint.add_droplet(float(paint.count % 150) * 10.0, float(paint.count % 130) * 10.0, 1.2, false)
	var samples: Array[float] = []
	for _step in range(300):
		var started := Time.get_ticks_usec()
		wetness.step(dt, 1.0, 0.95, 10.0, 19.0)
		glass.step(dt, wetness.get_wetness("windshield"), 1.0, 10.0)
		paint.step(dt, wetness.get_wetness("hood"), 1.0, 10.0)
		wipers.step(dt, glass)
		puddles.step(dt, 1.0, 0.95, 10.0, 19.0, wetness.get_absorber_runoff())
		samples.append(float(Time.get_ticks_usec() - started) / 1000.0)
	var total := 0.0
	var maximum := 0.0
	for sample in samples:
		total += sample
		maximum = maxf(maximum, sample)
	samples.sort()
	var p95_index := clampi(int(samples.size() * 0.95), 0, samples.size() - 1)
	return {
		"avg_ms": total / float(samples.size()),
		"p95_ms": samples[p95_index],
		"max_ms": maximum,
		"glass": glass.count,
		"paint": paint.count,
	}


# --- F3.4: GLSL de producción, gotas, barrido, charcos y VFX ----------------


func _test_fx_shaders() -> void:
	_check(FileAccess.file_exists("res://shaders/rain_fx_common.gdshaderinc"), "include común de lluvia presente")
	for path in [
		"res://shaders/wet_paint.gdshader",
		"res://shaders/wet_glass.gdshader",
		"res://shaders/wet_road.gdshader",
		"res://shaders/rain_streaks.gdshader",
		"res://shaders/splash_ring.gdshader",
		"res://shaders/camera_drops.gdshader",
	]:
		var shader := load(path) as Shader
		_check(shader != null, "shader %s carga" % path.get_file())
		if shader != null:
			# En headless el renderer Dummy no compila `spatial`: aquí se valida
			# que el código parsea y declara uniforms; la compilación GPU real es
			# la prueba de render (tools/dev/render_test.cmd).
			_check(shader.code.contains("uniform"), "shader %s declara uniforms" % path.get_file())
			_check(shader.code.contains("void fragment()"), "shader %s implementa fragment()" % path.get_file())
			_check(not shader.code.contains("billboard_keep_scale"), "shader %s sin render modes de Godot 3" % path.get_file())
	var paint := load("res://shaders/wet_paint.gdshader") as Shader
	_check(paint != null and paint.code.contains("rain_fx_common.gdshaderinc"), "wet_paint incluye el común")
	var glass := load("res://shaders/wet_glass.gdshader") as Shader
	_check(glass != null and glass.code.contains("wiper"), "wet_glass consume el barrido")
	var road := load("res://shaders/wet_road.gdshader") as Shader
	_check(road != null and road.code.contains("puddles"), "wet_road consume los charcos")
	_check(_spec.integer("droplets.instance_stride") == 6, "layout de instancias de 6 floats intacto")
	var warmup := RainFxWarmup.run(get_tree().root)
	_check(bool(warmup.get("done", false)), "warm-up de shaders termina (headless: sin GPU)")
	_check(bool(warmup.get("skipped", false)), "warm-up se omite en headless sin fingir compilación")


func _test_fx_controller() -> void:
	var packed := load("res://scenes/vertical_slice/VerticalSlice.tscn") as PackedScene
	_check(packed != null, "rebanada carga con el controlador de lluvia")
	if packed == null:
		return
	var slice := packed.instantiate()
	add_child(slice)
	await get_tree().process_frame
	var controller := slice.get_node_or_null("RainFx") as RainFxController
	_check(controller != null, "controlador RainFxController presente en la rebanada")
	if controller == null:
		slice.queue_free()
		return
	_check(controller.errors.is_empty(), "controlador configura sin errores")
	_check(controller.wetness != null and controller.wetness.panels.size() >= 8, "modelo de humedad enlazado")
	_check(controller.droplets_glass != null and controller.droplets_paint != null, "campos de gotas enlazados")
	_check(controller.wipers != null and controller.puddles != null, "barrido y charcos enlazados")
	_check(controller._materials.size() >= 20, "materiales de superficie aplicados (%d)" % controller._materials.size())
	_check(controller._wiper_pivots.size() == 2, "dos escobillas animadas por pivote")
	_check(controller._road_materials.size() >= 1, "material de vía mojada aplicado")
	controller.manual_mode = true
	controller.set_weather(1.0, 0.95, 10.0, 19.0)
	for _i in range(240):
		controller.step_models(DELTA)
	controller.refresh_uniforms()
	_check(controller.wetness.get_wetness("windshield") > 0.2, "la tormenta moja el parabrisas del controlador")
	var windshield_material := _windshield_material(controller)
	_check(windshield_material != null, "material de parabrisas localizado")
	if windshield_material != null:
		var wetness_uniform = windshield_material.get_shader_parameter("wetness_value")
		_check(
			wetness_uniform != null and float(wetness_uniform) > 0.2,
			"uniform wetness_value del shader sigue a SurfaceWetnessModel"
		)
		var density = windshield_material.get_shader_parameter("drop_density")
		_check(density != null and float(density) >= 0.0, "uniform drop_density derivada de DropletFlowModel")
		var wiper_on = windshield_material.get_shader_parameter("wiper_enabled")
		_check(wiper_on != null and bool(wiper_on), "uniform wiper_enabled activa en el parabrisas")
		var pivot_l = windshield_material.get_shader_parameter("wiper_pivot_l_mm")
		var pivot_r = windshield_material.get_shader_parameter("wiper_pivot_r_mm")
		_check(pivot_l != null and pivot_r != null, "pivotes de escobilla en el shader")
		if pivot_l != null and pivot_r != null:
			var left_mm := pivot_l as Vector2
			var right_mm := pivot_r as Vector2
			_check(left_mm.x < 0.0 and right_mm.x > 0.0, "pivotes izquierda/derecha en su lado (marco u = derecha)")
			_check(absf(left_mm.y - right_mm.y) < 5.0, "ambos pivotes sobre la base del cristal")
			_check(absf(left_mm.x + right_mm.x) < 30.0, "pivotes simétricos respecto al centro")
	# El barrido mueve el uniform de ángulo y las mallas de las escobillas.
	controller.wipers.set_mode("low")
	for _i in range(60):
		controller.step_models(DELTA)
	controller.refresh_uniforms()
	if windshield_material != null:
		var angle_uniform = windshield_material.get_shader_parameter("wiper_angle_l")
		_check(angle_uniform != null, "uniform wiper_angle_l presente")
		if angle_uniform != null:
			_check(absf(float(angle_uniform) - PI) > 0.01, "el barrido cambia el ángulo del shader")
	var pivot := controller._wiper_pivots[0]
	_check(pivot != null and not pivot.basis.is_equal_approx(Basis.IDENTITY), "la escobilla gira sobre su pivote")
	# Los charcos visibles llegan al uniform de la vía.
	for _i in range(600):
		controller.step_models(0.25)
	controller.refresh_uniforms()
	var road_material := controller._road_materials[0] if not controller._road_materials.is_empty() else null
	_check(road_material != null, "material de vía disponible")
	if road_material != null:
		var puddle_count = road_material.get_shader_parameter("puddle_count")
		_check(puddle_count != null and int(puddle_count) >= 1, "charcos visibles en el uniform de la vía (%s)" % str(puddle_count))
		var wetness_road = road_material.get_shader_parameter("wetness_value")
		_check(wetness_road != null and float(wetness_road) > 0.0, "uniform de humedad de vía enlazada")
	_check(controller._vfx != null, "VFX de lluvia construidos")
	if controller._vfx != null:
		_check(controller._vfx.get_child_count() == 2, "dos sistemas de partículas (estrellas y salpicaduras)")
	slice.queue_free()
	await get_tree().process_frame

	var cabin := load("res://scenes/vehicle/CabinInteraction.tscn") as PackedScene
	_check(cabin != null, "cabina carga con el controlador de lluvia")
	if cabin == null:
		return
	var cabin_scene := cabin.instantiate()
	add_child(cabin_scene)
	await get_tree().process_frame
	var cabin_controller := cabin_scene.get_node_or_null("RainFx") as RainFxController
	_check(cabin_controller != null, "controlador RainFxController presente en la cabina")
	if cabin_controller != null:
		_check(cabin_controller.camera_drops, "gotas sobre cámara activas en la cabina")
		_check(cabin_controller._camera_overlay != null, "quad de gotas sobre cámara creado")
		cabin_controller.manual_mode = true
		cabin_controller.set_weather(1.0, 0.95, 8.0, 19.0)
		for _i in range(240):
			cabin_controller.step_models(DELTA)
		cabin_controller.refresh_uniforms()
		if cabin_controller._camera_overlay != null:
			var overlay_material := cabin_controller._camera_overlay.material_override as ShaderMaterial
			_check(overlay_material != null, "material de gotas sobre cámara")
			if overlay_material != null:
				var overlay_density = overlay_material.get_shader_parameter("drop_density")
				_check(
					overlay_density != null and float(overlay_density) > 0.0,
					"las gotas de cámara siguen al campo de gotas"
				)
	cabin_scene.queue_free()
	await get_tree().process_frame


func _windshield_material(controller: RainFxController) -> ShaderMaterial:
	for entry in controller._materials:
		if entry["is_windshield"]:
			return entry["material"]
	return null


func _test_fx_budgets() -> void:
	var pc: Dictionary = _spec.section("budgets").get("pc", {})
	var mobile: Dictionary = _spec.section("budgets").get("mobile", {})
	var pc_gpu: Dictionary = pc.get("gpu", {})
	var mobile_gpu: Dictionary = mobile.get("gpu", {})
	_check(int(pc_gpu.get("max_draw_calls", 0)) == 8, "presupuesto GPU PC de 8 draw calls")
	_check(int(mobile_gpu.get("max_draw_calls", 0)) == 4, "presupuesto GPU móvil de 4 draw calls")
	_check(int(pc_gpu.get("max_overdraw_layers", 0)) == 5, "presupuesto GPU PC de 5 capas de overdraw")
	_check(int(mobile_gpu.get("max_overdraw_layers", 0)) == 3, "presupuesto GPU móvil de 3 capas de overdraw")
	_check(float(pc_gpu.get("max_fill_percent", 0.0)) == 6.0, "presupuesto GPU PC de 6 % de fill")
	_check(float(mobile_gpu.get("max_fill_percent", 0.0)) == 10.0, "presupuesto GPU móvil de 10 % de fill")
	# Configuración real de la rebanada: VFX sin gotas de cámara.
	var slice_fx := RainFxController.new()
	slice_fx.enable_vfx = true
	slice_fx.camera_drops = false
	var slice_budget := slice_fx.estimate_gpu_budget()
	_check(int(slice_budget["added_draw_calls"]) <= int(pc_gpu.get("max_draw_calls", 0)), "rebanada dentro de draw calls PC")
	_check(int(slice_budget["added_draw_calls"]) <= int(mobile_gpu.get("max_draw_calls", 0)), "rebanada dentro de draw calls móvil")
	_check(int(slice_budget["overdraw_layers"]) <= int(mobile_gpu.get("max_overdraw_layers", 0)), "rebanada dentro de overdraw móvil")
	_check(float(slice_budget["fill_percent"]) <= float(pc_gpu.get("max_fill_percent", 0.0)), "rebanada dentro del fill PC")
	# Configuración real de la cabina: gotas de cámara sin VFX de exteriores.
	var cabin_fx := RainFxController.new()
	cabin_fx.enable_vfx = false
	cabin_fx.camera_drops = true
	var cabin_budget := cabin_fx.estimate_gpu_budget()
	_check(int(cabin_budget["added_draw_calls"]) <= int(mobile_gpu.get("max_draw_calls", 0)), "cabina dentro de draw calls móvil")
	_check(int(cabin_budget["overdraw_layers"]) <= int(mobile_gpu.get("max_overdraw_layers", 0)), "cabina dentro de overdraw móvil")
	_check(float(cabin_budget["fill_percent"]) <= float(mobile_gpu.get("max_fill_percent", 0.0)), "cabina dentro del fill móvil")
	# Peor caso combinado nunca supera el presupuesto móvil.
	var worst_fx := RainFxController.new()
	worst_fx.enable_vfx = true
	worst_fx.camera_drops = true
	var worst := worst_fx.estimate_gpu_budget()
	_check(int(worst["added_draw_calls"]) <= int(mobile_gpu.get("max_draw_calls", 0)), "peor caso dentro de draw calls móvil")
	_check(int(worst["overdraw_layers"]) <= int(mobile_gpu.get("max_overdraw_layers", 0)), "peor caso dentro de overdraw móvil")
	_check(float(worst["fill_percent"]) <= float(mobile_gpu.get("max_fill_percent", 0.0)), "peor caso dentro del fill móvil")
	slice_fx.free()
	cabin_fx.free()
	worst_fx.free()
	_check(bool(_spec.boolean("budgets.measurement.warmup_required_before_gameplay")), "warm-up obligatorio antes del gameplay")
	print(
		"[RAIN] Presupuesto GPU proyectado: rebanada %s, cabina %s, peor caso %s"
		% [str(slice_budget), str(cabin_budget), str(worst)]
	)
