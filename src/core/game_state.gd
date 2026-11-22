extends Node
## Estado serializable de la partida. No escribe archivos y no toca el mundo.
##
## GameState publica cambios y solicita guardados por EventBus. SaveManager lee
## snapshots y aplica la carga; GameState nunca llama a SaveManager.

const SNAPSHOT_VERSION := 1
const DEFAULT_HUMANITY := 100.0
const MODE_BOOT := "boot"
const MODE_MENU := "menu"
const MODE_PLAYING := "playing"
const MODE_PAUSED := "paused"

var mode := MODE_BOOT
var chapter := 0
var region := ""
var mission_id := ""
var mission_stage := "none"
var flags: Dictionary = {}
var trust: Dictionary = {}
var humanity := DEFAULT_HUMANITY
var play_time_seconds := 0.0
var is_test_save := false
var rng_seed := 1999


func _ready() -> void:
	set_process(false)
	EventBus.diagnostics_context_requested.connect(_on_diagnostics_context_requested)
	EventBus.diagnostics_context_updated.emit("game_state", get_diagnostics_context())


func _process(delta: float) -> void:
	if mode == MODE_PLAYING:
		play_time_seconds += delta


func set_mode(new_mode: String) -> void:
	if mode == new_mode:
		return
	mode = new_mode
	set_process(mode == MODE_PLAYING)
	EventBus.mode_changed.emit(mode)
	EventBus.game_state_changed.emit("mode", mode)


func set_region(new_region: String) -> void:
	if region == new_region:
		return
	region = new_region
	EventBus.game_state_changed.emit("region", region)


func set_mission(new_mission_id: String, new_stage: String) -> void:
	mission_id = new_mission_id
	mission_stage = new_stage
	EventBus.mission_changed.emit(mission_id, mission_stage)
	EventBus.game_state_changed.emit("mission", {"id": mission_id, "stage": mission_stage})


func set_flag(flag: String, enabled: bool = true) -> void:
	if flag.is_empty():
		push_warning("GameState: bandera vacía rechazada")
		return
	if bool(flags.get(flag, false)) == enabled:
		return
	flags[flag] = enabled
	EventBus.flag_changed.emit(flag, enabled)
	EventBus.game_state_changed.emit("flag.%s" % flag, enabled)


func has_flag(flag: String) -> bool:
	return bool(flags.get(flag, false))


func clear_flags() -> void:
	flags.clear()
	EventBus.flags_cleared.emit()
	EventBus.game_state_changed.emit("flags", {})


func set_trust(passenger_id: String, value: float) -> void:
	if passenger_id.is_empty():
		push_warning("GameState: confianza sin pasajero")
		return
	var clamped := clampf(value, 0.0, 100.0)
	if is_equal_approx(float(trust.get(passenger_id, 50.0)), clamped):
		return
	trust[passenger_id] = clamped
	EventBus.trust_changed.emit(passenger_id, clamped)
	EventBus.game_state_changed.emit("trust.%s" % passenger_id, clamped)


func set_humanity(value: float) -> void:
	var clamped := clampf(value, 0.0, 100.0)
	if is_equal_approx(humanity, clamped):
		return
	humanity = clamped
	EventBus.humanity_changed.emit(humanity)
	EventBus.game_state_changed.emit("humanity", humanity)


func adjust_humanity(delta: float) -> void:
	set_humanity(humanity + delta)


func set_test_mode(enabled: bool) -> void:
	if is_test_save == enabled:
		return
	is_test_save = enabled
	EventBus.test_mode_changed.emit(enabled)
	EventBus.game_state_changed.emit("test_mode", enabled)


func start_new_game(test_save: bool = false) -> void:
	mode = MODE_MENU
	chapter = 0
	region = ""
	mission_id = ""
	mission_stage = "none"
	flags.clear()
	trust.clear()
	humanity = DEFAULT_HUMANITY
	play_time_seconds = 0.0
	is_test_save = test_save
	rng_seed = 1999
	set_process(false)
	EventBus.game_state_changed.emit("new_game", {"test_save": test_save})
	EventBus.test_mode_changed.emit(is_test_save)


func snapshot() -> Dictionary:
	return {
		"snapshot_version": SNAPSHOT_VERSION,
		"mode": mode,
		"chapter": chapter,
		"region": region,
		"mission_id": mission_id,
		"mission_stage": mission_stage,
		"flags": flags.duplicate(true),
		"trust": trust.duplicate(true),
		"humanity": humanity,
		"play_time_seconds": play_time_seconds,
		"is_test_save": is_test_save,
		"rng_seed": rng_seed,
	}


func apply_snapshot(data: Dictionary, source: String = "save") -> bool:
	if not data.has("snapshot_version"):
		push_warning("GameState: snapshot sin versión")
		return false
	chapter = int(data.get("chapter", 0))
	region = str(data.get("region", ""))
	mission_id = str(data.get("mission_id", ""))
	mission_stage = str(data.get("mission_stage", "none"))
	flags = Dictionary(data.get("flags", {})).duplicate(true)
	trust = Dictionary(data.get("trust", {})).duplicate(true)
	humanity = clampf(float(data.get("humanity", DEFAULT_HUMANITY)), 0.0, 100.0)
	play_time_seconds = maxf(0.0, float(data.get("play_time_seconds", 0.0)))
	is_test_save = bool(data.get("is_test_save", false))
	rng_seed = int(data.get("rng_seed", 1999))
	set_mode(str(data.get("mode", MODE_MENU)))
	EventBus.game_state_loaded.emit(source)
	EventBus.game_state_changed.emit("snapshot", {"source": source})
	return true


func request_save(slot: int, reason: String = "manual") -> void:
	EventBus.save_requested.emit(slot, reason)


func get_diagnostics_context() -> Dictionary:
	var flag_names := flags.keys()
	flag_names.sort()
	return {
		"mode": mode,
		"chapter": chapter,
		"region": region,
		"mission_id": mission_id,
		"mission_stage": mission_stage,
		"humanity": humanity,
		"trust": trust.duplicate(true),
		"flag_count": flags.size(),
		"flags": flag_names.slice(0, 20),
		"play_time_seconds": play_time_seconds,
		"is_test_save": is_test_save,
	}


func _on_diagnostics_context_requested() -> void:
	EventBus.diagnostics_context_updated.emit("game_state", get_diagnostics_context())
