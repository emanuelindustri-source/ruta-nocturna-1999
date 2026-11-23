class_name CabinControls
extends Node
## Estado funcional de los controles de cabina.
##
## No simula conduccion ni duplica el tren motriz. La palanca y el Overdrive se
## delegan en VehiclePowertrain; el freno de mano termina en brakes.parking. Las
## puertas, vidrios, luces, antena, radio y guantera viven aqui como estado de
## cabina y emiten senales locales para la UI/audio de fases posteriores.

signal door_changed(door_id: String, open: bool, locked: bool)
signal lock_changed(locked: bool)
signal window_changed(window_id: String, position: float)
signal lights_changed(state: String)
signal antenna_changed(extended: bool, extension: float)
signal radio_changed(power_on: bool, band: String, station: float, volume: int)
signal glovebox_changed(open: bool)
signal gear_gate_changed(mode: String)
signal overdrive_changed(enabled: bool)
signal handbrake_changed(engaged: bool)
signal feedback(code: String)

const DOOR_IDS := ["driver", "passenger"]
const WINDOW_IDS := ["driver", "passenger"]
const LIGHTS_STATES := ["off", "parking", "headlights"]

var spec: CabinInteractionSpec
var powertrain: VehiclePowertrain
var radio: CabinRadio
var position_provider: Callable = Callable()

var doors_locked := false
var door_open := {"driver": false, "passenger": false}
var door_openness := {"driver": 0.0, "passenger": 0.0}
var window_position := {"driver": 0.0, "passenger": 0.0}
var window_direction := {"driver": 0.0, "passenger": 0.0}
var lights_state := "off"
var antenna_extended := false
var antenna_extension := 0.0
var glovebox_open := false
var glovebox_openness := 0.0
var handbrake_engaged := false
var handbrake_amount := 0.0
var gear_mode := "P"
var gear_target_index := 0.0
var gear_visual_index := 0.0
var overdrive_enabled := true
var last_rejection := ""
var last_feedback := ""

var _configured := false
var _door_travel_s := 0.55
var _window_travel_s := 2.4
var _antenna_travel_s := 0.8
var _handbrake_travel_s := 0.35
var _glovebox_travel_s := 0.45
var _gear_travel_s := 0.18
var _gear_reject_s := 0.25
var _gear_reject_timer := 0.0
var _stationary_speed_mps := 0.3
var _modes: Array = ["P", "R", "N", "D", "2", "L"]


func configure(spec_in: CabinInteractionSpec, powertrain_in: VehiclePowertrain) -> void:
	spec = spec_in
	powertrain = powertrain_in
	_modes = spec.array("gear_gate.modes")
	if _modes.is_empty():
		_modes = ["P", "R", "N", "D", "2", "L"]
	_door_travel_s = maxf(0.05, spec.number("doors.travel_s", 0.55))
	_window_travel_s = maxf(0.05, spec.number("windows.travel_s", 2.4))
	_antenna_travel_s = maxf(0.05, spec.number("antenna.travel_s", 0.8))
	_handbrake_travel_s = maxf(0.05, spec.number("handbrake.travel_s", 0.35))
	_glovebox_travel_s = maxf(0.05, spec.number("glovebox.travel_s", 0.45))
	_gear_travel_s = maxf(0.02, spec.number("gear_gate.travel_s", 0.18))
	_gear_reject_s = maxf(0.02, spec.number("gear_gate.reject_s", 0.25))
	_stationary_speed_mps = spec.number("interaction.stationary_speed_mps", 0.3)
	doors_locked = spec.boolean("doors.default_locked", false)
	lights_state = spec.string("lights.initial_state", "off")
	if not LIGHTS_STATES.has(lights_state):
		lights_state = "off"
	antenna_extended = spec.boolean("antenna.initial_extended", false)
	antenna_extension = 1.0 if antenna_extended else 0.0
	glovebox_open = spec.boolean("glovebox.initial_open", false)
	glovebox_openness = 1.0 if glovebox_open else 0.0
	handbrake_engaged = spec.boolean("handbrake.initial_engaged", false)
	handbrake_amount = 1.0 if handbrake_engaged else 0.0
	gear_mode = "P"
	gear_target_index = 0.0
	gear_visual_index = 0.0
	overdrive_enabled = true
	_ensure_radio()
	radio.configure(spec.section("radio"))
	radio.set_antenna_extension(antenna_extension)
	_configured = true
	sync_from_powertrain()
	_emit_all_state()


func advance(delta: float) -> void:
	if not _configured:
		return
	var step := maxf(delta, 0.0)
	sync_from_powertrain()
	_advance_doors(step)
	_advance_windows(step)
	_advance_antenna(step)
	_advance_glovebox(step)
	_advance_handbrake(step)
	_advance_gear(step)
	_gear_reject_timer = maxf(0.0, _gear_reject_timer - step)
	if radio != null:
		radio.set_antenna_extension(antenna_extension)


func get_control_position(control_id: String) -> Vector3:
	if position_provider.is_valid():
		var provided: Variant = position_provider.call(control_id)
		if provided is Vector3:
			return provided
	var control := spec.control(control_id) if spec != null else {}
	var position: Array = control.get("interaction_position_m", control.get("position_m", []))
	if position.size() != 3:
		return Vector3.ZERO
	return Vector3(float(position[0]), float(position[1]), float(position[2]))


func is_stationary() -> bool:
	if powertrain == null:
		return true
	return absf(powertrain.speed_mps) <= _stationary_speed_mps


func is_locked() -> bool:
	return doors_locked


func set_locked(value: bool) -> void:
	if doors_locked == value:
		return
	doors_locked = value
	lock_changed.emit(doors_locked)


func toggle_locked() -> bool:
	set_locked(not doors_locked)
	return doors_locked


func is_door_open(door_id: String) -> bool:
	return bool(door_open.get(door_id, false))


func toggle_door(door_id: String) -> bool:
	if not door_open.has(door_id):
		return false
	if not is_door_open(door_id):
		if doors_locked:
			_feedback("locked")
			return false
		if not is_stationary():
			_feedback("moving")
			return false
		door_open[door_id] = true
		door_changed.emit(door_id, true, doors_locked)
		return true
	door_open[door_id] = false
	door_changed.emit(door_id, false, doors_locked)
	return true


func get_door_openness(door_id: String) -> float:
	return float(door_openness.get(door_id, 0.0))


func set_window_direction(window_id: String, direction: String) -> bool:
	var side := _window_side(window_id)
	if side.is_empty():
		return false
	if direction == "up":
		window_direction[side] = -1.0
	elif direction == "down":
		window_direction[side] = 1.0
	elif direction == "":
		window_direction[side] = 0.0
	else:
		return false
	return true


func stop_window(window_id: String) -> void:
	var side := _window_side(window_id)
	if not side.is_empty():
		window_direction[side] = 0.0


func get_window_position(window_id: String) -> float:
	var side := _window_side(window_id)
	return float(window_position.get(side, 0.0))


func cycle_lights() -> String:
	var index := LIGHTS_STATES.find(lights_state)
	lights_state = LIGHTS_STATES[(index + 1) % LIGHTS_STATES.size()]
	lights_changed.emit(lights_state)
	return lights_state


func set_lights_state(value: String) -> bool:
	if not LIGHTS_STATES.has(value):
		return false
	lights_state = value
	lights_changed.emit(lights_state)
	return true


func toggle_antenna() -> bool:
	antenna_extended = not antenna_extended
	antenna_changed.emit(antenna_extended, antenna_extension)
	return antenna_extended


func get_antenna_extension() -> float:
	return antenna_extension


func toggle_glovebox() -> bool:
	glovebox_open = not glovebox_open
	glovebox_changed.emit(glovebox_open)
	return glovebox_open


func get_glovebox_openness() -> float:
	return glovebox_openness


func set_handbrake(value: bool) -> void:
	if handbrake_engaged == value:
		return
	handbrake_engaged = value
	if powertrain != null:
		powertrain.set_parking_brake(value)
	handbrake_changed.emit(handbrake_engaged)


func toggle_handbrake() -> bool:
	set_handbrake(not handbrake_engaged)
	return handbrake_engaged


func get_handbrake_amount() -> float:
	return handbrake_amount


func get_gear_visual_index() -> float:
	var nudge := 0.0
	if _gear_reject_timer > 0.0 and _gear_reject_s > 0.0:
		var t := 1.0 - _gear_reject_timer / _gear_reject_s
		nudge = sin(t * PI) * 0.08
	return clampf(gear_visual_index + nudge, 0.0, float(maxi(0, _modes.size() - 1)))


func select_gear(mode: String) -> bool:
	if powertrain == null or not _modes.has(mode):
		_feedback("gear_rejected")
		return false
	var accepted := powertrain.set_selector(mode)
	if accepted:
		gear_mode = mode
		gear_target_index = float(_modes.find(mode))
		last_rejection = ""
		gear_gate_changed.emit(gear_mode)
		return true
	last_rejection = powertrain.last_rejection
	_gear_reject_timer = _gear_reject_s
	_feedback(_gear_rejection_code(last_rejection))
	return false


func nudge_gear(direction: int) -> bool:
	if direction == 0:
		return false
	var index := _modes.find(gear_mode)
	if index < 0:
		index = 0
	var target := clampi(index + direction, 0, _modes.size() - 1)
	if target == index:
		return false
	return select_gear(str(_modes[target]))


func toggle_overdrive() -> bool:
	if powertrain == null:
		return false
	if powertrain.toggle_overdrive():
		overdrive_enabled = powertrain.overdrive_enabled
		overdrive_changed.emit(overdrive_enabled)
		return true
	last_rejection = powertrain.last_rejection
	_feedback("overdrive_needs_drive" if last_rejection == "overdrive_needs_drive" else "gear_rejected")
	return false


func get_overdrive_enabled() -> bool:
	return overdrive_enabled


func radio_toggle_power() -> bool:
	_ensure_radio()
	return radio.toggle_power()


func radio_cycle_band() -> String:
	_ensure_radio()
	if not radio.power_on:
		_feedback("radio_off")
		return radio.band
	return radio.cycle_band()


func radio_seek() -> float:
	_ensure_radio()
	if not radio.power_on:
		_feedback("radio_off")
		return 0.0
	return radio.seek()


func radio_volume(direction: int) -> int:
	_ensure_radio()
	if not radio.power_on:
		_feedback("radio_off")
		return radio.volume_step
	if direction > 0:
		return radio.volume_up()
	if direction < 0:
		return radio.volume_down()
	return radio.volume_step


func get_last_rejection() -> String:
	return last_rejection


func sync_from_powertrain() -> void:
	if powertrain == null:
		return
	var selector := str(powertrain.selector)
	if _modes.has(selector) and selector != gear_mode:
		gear_mode = selector
		gear_target_index = float(_modes.find(selector))
	overdrive_enabled = bool(powertrain.overdrive_enabled)
	if bool(powertrain.parking_brake) != handbrake_engaged:
		handbrake_engaged = bool(powertrain.parking_brake)
		if powertrain.brakes != null:
			powertrain.brakes.parking = handbrake_engaged
		handbrake_changed.emit(handbrake_engaged)


func _ensure_radio() -> void:
	if radio != null:
		return
	radio = CabinRadio.new()
	radio.name = "Radio"
	add_child(radio)
	radio.state_changed.connect(_on_radio_state_changed)


func _advance_doors(delta: float) -> void:
	for door_id in DOOR_IDS:
		var target := 1.0 if is_door_open(door_id) else 0.0
		var current := float(door_openness.get(door_id, 0.0))
		if not is_equal_approx(current, target):
			door_openness[door_id] = move_toward(current, target, delta / _door_travel_s)


func _advance_windows(delta: float) -> void:
	for side in WINDOW_IDS:
		var direction := float(window_direction.get(side, 0.0))
		if is_zero_approx(direction):
			continue
		var current := float(window_position.get(side, 0.0))
		var next := clampf(current + direction * delta / _window_travel_s, 0.0, 1.0)
		if not is_equal_approx(next, current):
			window_position[side] = next
			window_changed.emit(side, next)
		if is_equal_approx(next, 0.0) and direction < 0.0:
			window_direction[side] = 0.0
			_feedback("window_limit")
		elif is_equal_approx(next, 1.0) and direction > 0.0:
			window_direction[side] = 0.0
			_feedback("window_limit")


func _advance_antenna(delta: float) -> void:
	var target := 1.0 if antenna_extended else 0.0
	var current := antenna_extension
	if not is_equal_approx(current, target):
		antenna_extension = move_toward(current, target, delta / _antenna_travel_s)
		antenna_changed.emit(antenna_extended, antenna_extension)


func _advance_glovebox(delta: float) -> void:
	var target := 1.0 if glovebox_open else 0.0
	if not is_equal_approx(glovebox_openness, target):
		glovebox_openness = move_toward(glovebox_openness, target, delta / _glovebox_travel_s)


func _advance_handbrake(delta: float) -> void:
	var target := 1.0 if handbrake_engaged else 0.0
	if not is_equal_approx(handbrake_amount, target):
		handbrake_amount = move_toward(handbrake_amount, target, delta / _handbrake_travel_s)


func _advance_gear(delta: float) -> void:
	if not is_equal_approx(gear_visual_index, gear_target_index):
		gear_visual_index = move_toward(gear_visual_index, gear_target_index, delta / _gear_travel_s)


func _window_side(window_id: String) -> String:
	if window_id in WINDOW_IDS:
		return window_id
	if window_id == "window_driver":
		return "driver"
	if window_id == "window_passenger":
		return "passenger"
	return ""


func _gear_rejection_code(code: String) -> String:
	if code in ["moving", "forward_motion", "reverse_motion"]:
		return "gear_rejected"
	if code == "overdrive_needs_drive":
		return "overdrive_needs_drive"
	return "gear_rejected"


func _feedback(code: String) -> void:
	last_feedback = code
	feedback.emit(code)


func _on_radio_state_changed(power_on: bool, band: String, station: float, volume: int) -> void:
	radio_changed.emit(power_on, band, station, volume)


func _emit_all_state() -> void:
	lock_changed.emit(doors_locked)
	for door_id in DOOR_IDS:
		door_changed.emit(door_id, is_door_open(door_id), doors_locked)
	for side in WINDOW_IDS:
		window_changed.emit(side, float(window_position.get(side, 0.0)))
	lights_changed.emit(lights_state)
	antenna_changed.emit(antenna_extended, antenna_extension)
	glovebox_changed.emit(glovebox_open)
	gear_gate_changed.emit(gear_mode)
	overdrive_changed.emit(overdrive_enabled)
	handbrake_changed.emit(handbrake_engaged)
	if radio != null:
		radio_changed.emit(radio.power_on, radio.band, radio.get_station_frequency(), radio.volume_step)
