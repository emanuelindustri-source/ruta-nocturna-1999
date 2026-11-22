extends Node
## Pruebas headless del tren motriz de la Fase 2.1.
##
## Ejecutar:
##   .\tools\dev\powertrain_test.cmd
## El proceso devuelve 0 solo si el contrato carga y todos los subsistemas
## (motor, caja P-R-N-D-2-L, Overdrive, frenos, combustible, térmica y
## electroventilador) responden dentro de los valores declarados.

const DELTA := 1.0 / 60.0
const THERMAL_DELTA := 0.05

var _passed := 0
var _failed: Array[String] = []


func _ready() -> void:
	print("[POWERTRAIN] Inicio de pruebas del tren motriz")
	await get_tree().process_frame
	await get_tree().process_frame
	_test_contract()
	_test_start_and_selector()
	_test_engine_speed()
	_test_transmission_upshift_and_overdrive()
	_test_ranges_and_reverse()
	_test_brakes()
	_test_fuel()
	_test_thermal_and_fan()
	_test_fan_faults_and_overheat()
	_test_flood_and_dry()
	_test_converter_and_engine_braking()
	_finish()


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("[POWERTRAIN] OK   %s" % label)
	else:
		_failed.append(label)
		print("[POWERTRAIN] FAIL %s" % label)


func _check_near(value: float, expected: float, tolerance: float, label: String) -> void:
	_check(absf(value - expected) <= tolerance, "%s (%.3f ≈ %.3f)" % [label, value, expected])


func _make_vp() -> VehiclePowertrain:
	var vp := VehiclePowertrain.new()
	vp.auto_simulate = false
	add_child(vp)
	return vp


func _run(vp: VehiclePowertrain, seconds: float, delta: float = DELTA) -> void:
	var steps := maxi(1, int(ceil(seconds / delta)))
	for _index in range(steps):
		vp.simulate(delta)


func _run_until_stopped(vp: VehiclePowertrain, seconds: float = 12.0, delta: float = DELTA) -> Dictionary:
	var distance := 0.0
	var elapsed := 0.0
	var steps := maxi(1, int(ceil(seconds / delta)))
	for _index in range(steps):
		vp.simulate(delta)
		distance += absf(vp.speed_mps) * delta
		elapsed += delta
		if absf(vp.speed_mps) < 0.08:
			break
	return {"distance_m": distance, "time_s": elapsed}


func _finish() -> void:
	if _failed.is_empty():
		print("[POWERTRAIN] OK %d comprobaciones" % _passed)
		get_tree().quit(0)
		return
	print("[POWERTRAIN] Fallaron %d de %d comprobaciones:" % [_failed.size(), _passed + _failed.size()])
	for failure in _failed:
		print("[POWERTRAIN]   - %s" % failure)
	print("[POWERTRAIN] FAIL")
	get_tree().quit(1)


func _test_contract() -> void:
	var vp := _make_vp()
	_check(vp.spec != null and vp.spec.errors.is_empty(), "contrato vehicle_powertrain carga sin errores")
	_check(not vp.spec.section("engine").is_empty(), "sección engine presente")
	_check(not vp.spec.section("transmission").is_empty(), "sección transmission presente")
	_check(not vp.spec.section("brakes").is_empty(), "sección brakes presente")
	_check(not vp.spec.section("fuel").is_empty(), "sección fuel presente")
	_check(not vp.spec.section("cooling").is_empty(), "sección cooling presente")
	_check(not vp.spec.section("vehicle").is_empty(), "sección vehicle presente")
	_check(int(vp.spec.integer("schema_version")) == 1, "schema_version 1")
	_check(int(vp.spec.integer("engine.displacement_cc")) == 1590, "cilindrada 1590 cc")
	_check_near(vp.spec.number("engine.bore_mm"), 75.0, 0.01, "diámetro del cilindro del manual")
	_check_near(vp.spec.number("engine.stroke_mm"), 90.0, 0.01, "carrera del manual")
	_check_near(vp.spec.number("engine.compression_ratio"), 9.5, 0.01, "relación de compresión del manual")
	_check_near(vp.spec.number("engine.oil.crankcase_capacity_l"), 3.3, 0.01, "aceite de motor del manual")
	_check(vp.spec.array("transmission.selector_modes") == ["P", "R", "N", "D", "2", "L"], "selector P-R-N-D-2-L")
	_check(int(vp.spec.integer("transmission.gears")) == 4, "caja de cuatro marchas")
	_check(bool(vp.spec.boolean("transmission.overdrive")), "Overdrive declarado")
	_check_near(vp.fuel.capacity_l, 50.0, 0.01, "tanque de 50 L del contrato")
	_check_near(vp.cooling.coolant_c, vp.ambient_c, 0.01, "refrigerante inicia a temperatura ambiente")
	_check_near(vp.brakes.temp_c, vp.ambient_c, 0.01, "frenos inician a temperatura ambiente")
	_check(vp.engine.get_state_name() == "off", "motor inicia apagado")
	_check(vp.transmission.selector == "P", "caja inicia en P")
	vp.queue_free()


func _test_start_and_selector() -> void:
	var vp := _make_vp()
	_check(vp.start_engine(), "arranque permitido en P")
	_run(vp, 2.0)
	_check(vp.engine.get_state_name() == "idle", "motor en ralenti tras arrancar")
	_check(vp.engine.rpm > 650.0 and vp.engine.rpm < 950.0, "ralentí alrededor de 800 rpm")
	_check(not vp.starter, "marcha se libera al arrancar")

	vp.stop_engine()
	_run(vp, 1.0)
	_check(vp.engine.get_state_name() == "off", "motor se apaga con ignición")
	_check(vp.set_selector("D"), "P a D en reposo")
	_check(not vp.start_engine(), "arranque bloqueado en D")
	_check(vp.last_rejection.contains("park"), "rechazo de arranque en D explicado")
	_check(vp.set_selector("P"), "retorno a P en reposo")
	_check(vp.start_engine(), "arranque de nuevo en P")
	_run(vp, 2.0)

	for mode in ["R", "N", "D", "2", "L", "P"]:
		_check(vp.set_selector(mode), "selección %s en reposo" % mode)

	vp.set_speed_kph(20.0)
	_check(not vp.set_selector("P"), "P rechazada en movimiento")
	_check(not vp.set_selector("R"), "R rechazada con avance")
	_check(vp.set_selector("N"), "N aceptada en movimiento")
	vp.set_speed_kph(-10.0)
	_check(not vp.set_selector("D"), "D rechazada con reversa")
	_check(vp.set_selector("R"), "R aceptada con reversa")
	vp.queue_free()


func _test_engine_speed() -> void:
	var vp := _make_vp()
	vp.start_engine()
	_run(vp, 2.0)
	var idle_rpm := vp.engine.rpm
	vp.set_throttle(0.5)
	_run(vp, 2.0)
	_check(vp.engine.rpm > idle_rpm + 1000.0, "acelerador eleva rpm en P")
	_check(vp.engine.rpm < 6600.0, "motor no supera el corte de inyección")
	vp.set_throttle(0.0)
	_run(vp, 3.0)
	_check(vp.engine.rpm < 1000.0, "motor vuelve al ralentí")
	vp.queue_free()


func _test_transmission_upshift_and_overdrive() -> void:
	var vp := _make_vp()
	var gear_changes: Array[String] = []
	vp.gear_changed.connect(func(label: String) -> void: gear_changes.append(label))
	var overdrive_changes: Array[bool] = []
	vp.overdrive_changed.connect(func(enabled: bool) -> void: overdrive_changes.append(enabled))
	vp.start_engine()
	_run(vp, 2.0)
	_check(vp.set_selector("D"), "D engranada para prueba de subida")
	vp.set_throttle(1.0)
	_run(vp, 22.0)
	_check(vp.transmission.gear == 4, "caja alcanza cuarta a fondo")
	_check(vp.speed_mps * 3.6 > 90.0, "velocidad superior a 90 km/h en cuarta")
	_check(vp.engine.rpm < 6600.0, "motor dentro de rango en cuarta")
	_check(gear_changes.size() >= 3, "señales de cambio 1-2-3-4 emitidas")
	_check(vp.overdrive_enabled, "Overdrive activo por defecto")
	_check(vp.toggle_overdrive(), "botón O/D apaga Overdrive")
	_run(vp, 1.0)
	_check(not vp.overdrive_enabled, "Overdrive desactivado")
	_check(vp.transmission.gear == 3, "O/D off baja a tercera")
	_run(vp, 8.0)
	_check(vp.transmission.gear == 3, "O/D off mantiene máximo tercera")
	_check(vp.toggle_overdrive(), "botón O/D vuelve a activar")
	_run(vp, 10.0)
	_check(vp.overdrive_enabled and vp.transmission.gear == 4, "O/D on recupera cuarta")
	_check(overdrive_changes.size() >= 2, "señales de Overdrive emitidas")
	vp.queue_free()


func _test_ranges_and_reverse() -> void:
	var vp := _make_vp()
	vp.start_engine()
	_run(vp, 2.0)
	vp.set_selector("D")
	vp.set_throttle(1.0)
	_run(vp, 10.0)
	_check(vp.set_selector("2"), "rango 2 seleccionado en marcha")
	vp.set_throttle(0.0)
	vp.set_brake_pedal(0.6)
	_run(vp, 6.0)
	_check(vp.transmission.gear >= 1 and vp.transmission.gear <= 2, "rango 2 limita a primera/segunda")
	_check(vp.set_selector("L"), "rango L seleccionado")
	_run(vp, 6.0)
	_check(vp.transmission.gear == 1, "rango L mantiene primera")
	vp.set_brake_pedal(0.0)

	var reverse := _make_vp()
	reverse.start_engine()
	_run(reverse, 2.0)
	_check(reverse.set_selector("R"), "R engranada en reposo")
	reverse.set_throttle(0.4)
	_run(reverse, 4.0)
	_check(reverse.speed_mps < -0.5, "vehículo retrocede en R")
	_check(reverse.transmission.gear == -1, "marcha R activa")
	reverse.set_throttle(0.0)
	reverse.set_brake_pedal(1.0)
	_run_until_stopped(reverse, 5.0)
	_check(absf(reverse.speed_mps) < 0.1, "frenos detienen la reversa")
	reverse.queue_free()
	vp.queue_free()


func _test_brakes() -> void:
	var vp := _make_vp()
	vp.set_selector("N")
	vp.set_speed_kph(100.0)
	vp.set_brake_pedal(1.0)
	var stop := _run_until_stopped(vp, 12.0)
	_check(float(stop["distance_m"]) < 60.0, "frenada de 100 km/h en menos de 60 m (%.1f m)" % float(stop["distance_m"]))
	_check(float(stop["time_s"]) < 5.0, "frenada de 100 km/h en menos de 5 s (%.2f s)" % float(stop["time_s"]))
	_check(absf(vp.speed_mps) < 0.1, "vehículo detenido por frenos")

	var parking := _make_vp()
	parking.set_selector("N")
	parking.set_grade_percent(10.0)
	parking.set_parking_brake(true)
	_run(parking, 3.0)
	_check(absf(parking.speed_mps) < 0.05, "freno de mano sostiene en pendiente del 10%")
	parking.set_grade_percent(-10.0)
	_run(parking, 3.0)
	_check(absf(parking.speed_mps) < 0.05, "freno de mano sostiene en bajada")
	parking.queue_free()

	var fade := _make_vp()
	fade.set_selector("N")
	for _stop_index in range(12):
		fade.set_speed_kph(100.0)
		fade.set_brake_pedal(1.0)
		_run_until_stopped(fade, 12.0)
		fade.set_brake_pedal(0.0)
		_run(fade, 2.0)
	_check(fade.brakes.temp_c > 300.0, "frenos acumulan calor tras frenadas repetidas")
	_check(fade.brakes.fade_factor < 0.99, "fade reduce la fuerza de frenado")
	fade.set_speed_kph(60.0)
	fade.set_brake_pedal(1.0)
	_run(fade, 0.1)
	var hot_force := fade.brakes.force_n
	fade.set_brake_pedal(0.0)
	_run(fade, 90.0)
	_check(fade.brakes.temp_c < 300.0, "frenos se enfrían con flujo de aire")
	_check(fade.brakes.fade_factor > 0.9, "fade se recupera al enfriar")
	fade.set_brake_pedal(1.0)
	_run(fade, 0.1)
	_check(fade.brakes.force_n > hot_force, "fuerza recuperada tras enfriar")
	fade.queue_free()

	var worn := _make_vp()
	worn.set_selector("N")
	worn.set_speed_kph(50.0)
	worn.set_brake_pedal(1.0)
	worn.set_brake_pad_wear(0.0)
	_run(worn, 0.1)
	var new_force := worn.brakes.force_n
	worn.set_brake_pad_wear(0.9)
	_run(worn, 0.1)
	_check(worn.brakes.force_n < new_force * 0.7, "pastillas desgastadas reducen la frenada")
	worn.set_brake_pad_wear(0.0)
	worn.set_brake_fluid_level(0.1)
	_run(worn, 0.1)
	_check(worn.brakes.force_n < new_force * 0.5, "líquido bajo reduce la frenada")
	worn.queue_free()


func _test_fuel() -> void:
	var vp := _make_vp()
	vp.set_fuel_level(5.0)
	vp.start_engine()
	_run(vp, 2.0)
	var before := vp.fuel.level_l
	_run(vp, 10.0)
	_check(vp.fuel.level_l < before, "el motor consume combustible en ralentí")
	_check(vp.fuel.low_warning, "aviso de combustible bajo activo")
	vp.set_fuel_level(0.4)
	_run(vp, 1.0)
	_check(vp.engine.get_state_name() == "stalled", "motor se cala sin combustible")
	_check(not vp.fuel.has_fuel(), "tanque por debajo del umbral vacío")
	var added := vp.refuel(10.0)
	_check_near(added, 10.0, 0.01, "repostaje añade litros")
	_check(not vp.fuel.low_warning, "aviso bajo se apaga al repostar")
	_check_near(vp.refuel(100.0), 39.6, 0.2, "repostaje se limita a la capacidad")
	_check_near(vp.fuel.level_l, 50.0, 0.01, "tanque lleno a 50 L")
	_check(vp.start_engine(), "arranque posible tras repostar")
	_run(vp, 2.0)
	_check(vp.engine.get_state_name() == "idle", "motor vuelve a ralentí")
	vp.queue_free()


func _test_thermal_and_fan() -> void:
	var warm := _make_vp()
	warm.set_ambient_temperature(26.0)
	warm.start_engine()
	_run(warm, 420.0, THERMAL_DELTA)
	_check(warm.cooling.coolant_c > 70.0, "motor alcanza temperatura de servicio en ralentí")
	_check(warm.cooling.coolant_c < 100.0, "termostato evita sobrecalentamiento en ralentí")
	_check(warm.cooling.thermostat_opening >= 0.0, "apertura de termostato calculada")
	warm.queue_free()

	var fan := _make_vp()
	fan.start_engine()
	_run(fan, 2.0)
	fan.set_selector("D")
	fan.set_throttle(1.0)
	fan.set_brake_pedal(1.0)
	var saw_low := false
	var saw_high := false
	for _index in range(2000):
		fan.simulate(THERMAL_DELTA)
		if fan.cooling.fan_mode == "low":
			saw_low = true
		elif fan.cooling.fan_mode == "high":
			saw_high = true
	_check(saw_low, "electroventilador activa velocidad baja")
	_check(saw_high, "electroventilador activa velocidad alta")
	_check(fan.cooling.coolant_c > 95.0, "carga sostenida eleva la temperatura")
	fan.set_throttle(0.0)
	fan.set_brake_pedal(0.0)
	fan.set_parking_brake(true)
	_run(fan, 90.0, THERMAL_DELTA)
	_check(fan.cooling.coolant_c < 100.0, "temperatura baja al descargar el motor")
	fan.queue_free()


func _test_fan_faults_and_overheat() -> void:
	var vp := _make_vp()
	vp.start_engine()
	_run(vp, 2.0)
	vp.set_selector("D")
	vp.set_throttle(1.0)
	vp.set_brake_pedal(1.0)
	_check(vp.set_fan_fault("cooling.fan_fuse", true), "fallo de fusible del ventilador aplicado")
	_run(vp, 65.0, THERMAL_DELTA)
	_check(vp.get_warning("fan_fault"), "aviso de fallo del ventilador")
	_check(vp.cooling.overheat_warning, "aviso de sobrecalentamiento")
	_check(vp.cooling.safe_mode, "modo seguro térmico activo")
	_check(vp.engine.get_state_name() == "overheated_safe", "motor en protección térmica")
	_check(vp.engine.derate < 1.0, "potencia limitada por temperatura")
	var hot_temp := vp.cooling.coolant_c
	vp.set_throttle(0.0)
	vp.set_brake_pedal(0.0)
	vp.set_parking_brake(true)
	_check(vp.repair_component("cooling.fan_fuse"), "reparación de fusible del ventilador")
	_run(vp, 90.0, THERMAL_DELTA)
	_check(vp.cooling.coolant_c < hot_temp, "temperatura desciende tras reparar")
	_check(not vp.cooling.safe_mode, "modo seguro se desactiva")
	_check(not vp.get_warning("fan_fault"), "aviso de fallo se apaga")
	vp.queue_free()

	var relay := _make_vp()
	relay.start_engine()
	_run(relay, 2.0)
	relay.cooling.coolant_c = 105.0
	relay.set_fan_relay_intermittent(true)
	var saw_on := false
	var saw_off := false
	for _index in range(160):
		relay.simulate(THERMAL_DELTA)
		if relay.cooling.fan_running:
			saw_on = true
		else:
			saw_off = true
	_check(saw_on and saw_off, "relé intermitente enciende y apaga el ventilador")
	relay.queue_free()

	var seized := _make_vp()
	seized.start_engine()
	_run(seized, 2.0)
	seized.set_selector("D")
	seized.set_throttle(1.0)
	seized.set_brake_pedal(1.0)
	seized.set_fan_fault("cooling.fan_motor", true)
	_run(seized, 130.0, THERMAL_DELTA)
	_check(seized.cooling.seized, "motor se agarrota tras sobrecalentamiento prolongado")
	_check(seized.engine.get_state_name() == "seized", "estado seized del motor")
	_check(seized.get_warning("engine_seized"), "aviso de motor agarrotado")
	_check(seized.repair_component("engine.seized"), "reparación de motor agarrotado")
	_check(seized.engine.get_state_name() == "off", "motor reparado vuelve a off")
	_check(seized.set_selector("P"), "P seleccionada tras reparar")
	seized.set_throttle(0.0)
	seized.set_brake_pedal(0.0)
	_check(seized.start_engine(), "arranque posible tras reparación")
	_run(seized, 2.0)
	_check(seized.engine.get_state_name() == "idle", "motor reparado vuelve a ralentí")
	seized.queue_free()


func _test_flood_and_dry() -> void:
	var vp := _make_vp()
	vp.set_spark_plugs_wet(true)
	_check(vp.start_engine(), "intento de arranque con bujías mojadas")
	_run(vp, 2.0)
	_check(vp.engine.get_state_name() == "flooded", "motor se ahoga con bujías mojadas")
	_check(vp.dry_engine(), "secado de bujías iniciado")
	_run(vp, 21.0)
	_check(vp.engine.get_state_name() == "off", "secado completa y apaga el motor")
	_check(vp.start_engine(), "arranque tras secar bujías")
	_run(vp, 2.0)
	_check(vp.engine.get_state_name() == "idle", "motor en ralentí tras secado")
	vp.queue_free()


func _test_converter_and_engine_braking() -> void:
	var vp := _make_vp()
	vp.start_engine()
	_run(vp, 2.0)
	vp.set_selector("D")
	vp.set_brake_pedal(1.0)
	vp.set_throttle(1.0)
	_run(vp, 1.0)
	_check(vp.transmission.converter_multiplication > 1.5, "convertidor multiplica par en parado")
	_check(vp.engine.rpm > 1800.0 and vp.engine.rpm < 2400.0, "stall del convertidor alrededor de 2200 rpm")
	vp.set_brake_pedal(0.0)
	vp.set_throttle(0.7)
	_run(vp, 16.0)
	_check(vp.speed_mps * 3.6 > 70.0, "vehículo acelera con convertidor")
	vp.set_throttle(0.3)
	_run(vp, 3.0)
	_check(vp.transmission.converter_locked, "convertidor bloquea en crucero")
	vp.set_throttle(0.0)
	_run(vp, 1.0)
	_check(vp.engine.braking_torque_nm > 0.0, "retención del motor activa sin acelerador")
	vp.queue_free()
