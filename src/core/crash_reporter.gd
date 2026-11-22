extends Node
## Caja negra local de Ruta Nocturna: 1999.
##
## - Instala un Logger nativo y conserva las últimas 200 líneas.
## - Guarda contexto de servicios por EventBus, sin dependencias directas.
## - Detecta cierres anómalos con un marcador de sesión y emite el reporte en el
##   siguiente arranque.
## - Nunca sube datos a internet.
## - Escribe el reporte legible en user://ultimo_reporte_error.txt.

const CrashLoggerScript := preload("res://src/core/crash_logger.gd")

const REPORT_PATH := "user://ultimo_reporte_error.txt"
const SESSION_PATH := "user://sesion_activa.json"
const MAX_LOG_LINES := 200
const MAX_ACTIONS := 40
const HEARTBEAT_SECONDS := 10.0
const FPS_SAMPLE_SECONDS := 5.0
const FPS_THRESHOLD := 20.0
const FPS_SUSTAINED_SAMPLES := 3

var previous_session_detected := false

var _log_lines: Array[String] = []
var _actions: Array[String] = []
var _context: Dictionary = {}
var _mutex := Mutex.new()
var _writer_mutex := Mutex.new()
var _logger = null
var _pending_error := ""
var _writing_report := false
var _session_started_unix := 0.0
var _session_active := false
var _last_action := "ninguna"
var _fps_elapsed := 0.0
var _fps_low_samples := 0
var _heartbeat: Timer = null


func _ready() -> void:
	_install_logger()
	previous_session_detected = FileAccess.file_exists(SESSION_PATH)
	EventBus.diagnostics_context_updated.connect(_on_diagnostics_context_updated)
	EventBus.diagnostics_action.connect(_on_diagnostics_action)
	EventBus.crash_report_requested.connect(_on_crash_report_requested)
	call_deferred("_start_diagnostics")


func _exit_tree() -> void:
	_end_session_clean()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_end_session_clean()


func _process(delta: float) -> void:
	if DisplayServer.get_name() == "headless" or OS.has_feature("editor"):
		return
	_fps_elapsed += delta
	if _fps_elapsed < FPS_SAMPLE_SECONDS:
		return
	_fps_elapsed = 0.0
	var fps := float(Engine.get_frames_per_second())
	if fps > 0.0 and fps < FPS_THRESHOLD:
		_fps_low_samples += 1
	else:
		_fps_low_samples = 0
	if _fps_low_samples >= FPS_SUSTAINED_SAMPLES:
		_fps_low_samples = 0
		EventBus.performance_warning.emit("fps", fps, FPS_THRESHOLD)
		_append_action("fps_bajo: %.1f (< %.0f)" % [fps, FPS_THRESHOLD])


func write_report(reason: String, details: Dictionary = {}) -> String:
	if _writing_report:
		return REPORT_PATH
	_writing_report = true
	_writer_mutex.lock()
	EventBus.diagnostics_context_requested.emit()
	var report := _build_report(reason, details)
	var ok := _write_text(REPORT_PATH, report)
	_writer_mutex.unlock()
	_writing_report = false
	if not ok:
		print("[CRASH] No se pudo escribir %s" % REPORT_PATH)
		return ""
	EventBus.crash_report_written.emit(REPORT_PATH, reason)
	return REPORT_PATH


func get_last_report_text() -> String:
	if not FileAccess.file_exists(REPORT_PATH):
		return ""
	var file := FileAccess.open(REPORT_PATH, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func has_session_marker() -> bool:
	return FileAccess.file_exists(SESSION_PATH)


func get_status() -> Dictionary:
	return {
		"report_path": REPORT_PATH,
		"has_report": FileAccess.file_exists(REPORT_PATH),
		"session_marker": has_session_marker(),
		"previous_session_detected": previous_session_detected,
		"log_lines": _log_lines.size(),
		"actions": _actions.size(),
		"context_sections": _context.keys(),
	}


func get_diagnostics_context() -> Dictionary:
	return {
		"previous_session_detected": previous_session_detected,
		"has_report": FileAccess.file_exists(REPORT_PATH),
		"session_active": _session_active,
		"log_lines": _log_lines.size(),
		"last_action": _last_action,
	}


func _start_diagnostics() -> void:
	_report_previous_session_if_needed()
	_start_session()
	_heartbeat = Timer.new()
	_heartbeat.name = "Heartbeat"
	_heartbeat.wait_time = HEARTBEAT_SECONDS
	_heartbeat.autostart = true
	_heartbeat.timeout.connect(_on_heartbeat)
	add_child(_heartbeat)
	if DisplayServer.get_name() != "headless" and not OS.has_feature("editor"):
		set_process(true)
	print(
		"[CRASH] caja negra lista · sesión %s · reporte previo: %s"
		% [
			"activa" if _session_active else "inactiva",
			"sí" if previous_session_detected else "no",
		]
	)
	EventBus.diagnostics_context_updated.emit("crash", get_diagnostics_context())


func _install_logger() -> void:
	_logger = CrashLoggerScript.new()
	_logger.setup(self)
	OS.add_logger(_logger)


func _report_previous_session_if_needed() -> void:
	if not FileAccess.file_exists(SESSION_PATH):
		previous_session_detected = false
		return
	previous_session_detected = true
	var marker := _read_json(SESSION_PATH)
	_remove_session_file()
	var session_data: Variant = marker.get("session", {})
	if not session_data is Dictionary:
		session_data = {}
	write_report(
		"cierre_anormal_previo",
		{
			"session": session_data,
			"stack": "no disponible (el proceso anterior no pudo capturarlo)",
		}
	)
	print("[CRASH] Se detectó un cierre anormal previo; reporte generado.")


func _start_session() -> void:
	_session_started_unix = Time.get_unix_time_from_system()
	_session_active = true
	_write_session_marker(false)


func _end_session_clean() -> void:
	if not _session_active:
		return
	_session_active = false
	_remove_session_file()
	if _logger != null and OS.has_method("remove_logger"):
		OS.remove_logger(_logger)
		_logger = null


func _on_heartbeat() -> void:
	if _session_active:
		_write_session_marker(false)


func _write_session_marker(clean_exit: bool) -> void:
	var marker := {
		"version": str(ProjectSettings.get_setting("application/config/version", "0.0.0")),
		"platform": OS.get_name(),
		"engine": str(Engine.get_version_info().get("string", "")),
		"pid": OS.get_process_id(),
		"clean_exit": clean_exit,
		"last_heartbeat_utc": Time.get_datetime_string_from_system(true, false) + "Z",
		"session": {
			"started_unix": _session_started_unix,
			"last_action": _last_action,
			"context": _context.duplicate(true),
		},
	}
	_write_text(SESSION_PATH, JSON.stringify(marker, "\t", true, true) + "\n")


func _remove_session_file() -> void:
	if not FileAccess.file_exists(SESSION_PATH):
		return
	var directory := DirAccess.open("user://")
	if directory != null:
		directory.remove("sesion_activa.json")


func _capture_log(message: String, error: bool) -> void:
	_mutex.lock()
	var prefix := "ERROR " if error else ""
	_log_lines.append("%s%s" % [prefix, message])
	while _log_lines.size() > MAX_LOG_LINES:
		_log_lines.pop_front()
	_mutex.unlock()


func _capture_error(text: String, error_type: int) -> void:
	_capture_log(text, true)
	if error_type == Logger.ERROR_TYPE_WARNING:
		return
	_mutex.lock()
	var should_defer := _pending_error.is_empty()
	if should_defer:
		_pending_error = text
	_mutex.unlock()
	if should_defer:
		call_deferred("_flush_pending_error")


func _flush_pending_error() -> void:
	_mutex.lock()
	var stack := _pending_error
	_pending_error = ""
	_mutex.unlock()
	if stack.is_empty():
		return
	write_report("error_gdscript", {"stack": stack})


func _on_diagnostics_context_updated(section: String, data: Dictionary) -> void:
	_mutex.lock()
	_context[section] = data.duplicate(true)
	_mutex.unlock()


func _on_diagnostics_action(action: String, details: Dictionary) -> void:
	_append_action("%s %s" % [action, JSON.stringify(details)])


func _on_crash_report_requested(reason: String) -> void:
	write_report(reason)


func _append_action(text: String) -> void:
	_last_action = text
	_mutex.lock()
	_actions.append("%s %s" % [Time.get_time_string_from_system(), text])
	while _actions.size() > MAX_ACTIONS:
		_actions.pop_front()
	_mutex.unlock()


func _build_report(reason: String, details: Dictionary) -> String:
	_mutex.lock()
	var context_snapshot := _context.duplicate(true)
	var log_snapshot := _log_lines.duplicate()
	var action_snapshot := _actions.duplicate()
	_mutex.unlock()
	var game: Dictionary = context_snapshot.get("game_state", {})
	var weather: Dictionary = context_snapshot.get("weather", {})
	var localization: Dictionary = context_snapshot.get("localization", {})
	var hardware: Dictionary = context_snapshot.get("hardware", {})
	var state_summary := "modo %s · región %s · misión %s/%s · humanidad %.1f · banderas %d" % [
		game.get("mode", "desconocido"),
		game.get("region", "desconocida") if str(game.get("region", "")) != "" else "desconocida",
		game.get("mission_id", "ninguna") if str(game.get("mission_id", "")) != "" else "ninguna",
		game.get("mission_stage", "none"),
		float(game.get("humanity", 0.0)),
		int(game.get("flag_count", 0)),
	]
	var weather_summary := "%s · humedad %.2f · lluvia %.2f · viento %.1f" % [
		weather.get("preset", "desconocido"),
		float(weather.get("humidity", 0.0)),
		float(weather.get("rain", 0.0)),
		float(weather.get("wind", 0.0)),
	]
	var lines := PackedStringArray()
	lines.append("RUTA NOCTURNA 1999 - REPORTE")
	lines.append("=".repeat(48))
	lines.append("motivo: %s" % reason)
	lines.append("fecha_utc: %s" % (Time.get_datetime_string_from_system(true, false) + "Z"))
	lines.append(
		"versión: %s" % str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	)
	lines.append(
		"plataforma: %s · %s · %s"
		% [OS.get_name(), OS.get_model_name(), hardware.get("cpu_name", "CPU desconocida")]
	)
	lines.append("idioma: %s" % localization.get("locale", "desconocido"))
	lines.append("región: %s" % (game.get("region", "desconocida") if str(game.get("region", "")) != "" else "desconocida"))
	lines.append("clima: %s" % weather_summary)
	lines.append("hora: %s" % Time.get_time_string_from_system())
	lines.append("estado del vehículo: %s" % ("sin vehículo jugable en Fase 1.2"))
	lines.append("última acción: %s" % _last_action)
	lines.append("tipo de fallo: %s" % reason)
	lines.append("stack disponible: %s" % str(details.get("stack", "no")))
	lines.append("estado de juego: %s" % state_summary)
	lines.append("acciones recientes:")
	if action_snapshot.is_empty():
		lines.append("  (ninguna)")
	else:
		for action in action_snapshot:
			lines.append("  - %s" % action)
	lines.append("contexto:")
	lines.append(JSON.stringify(context_snapshot, "  ", true, true))
	lines.append("últimas líneas de log:")
	if log_snapshot.is_empty():
		lines.append("  (vacío)")
	else:
		for log_line in log_snapshot:
			lines.append(log_line)
	lines.append("")
	lines.append("Este reporte es local. No se subió a internet.")
	return "\n".join(lines)


func _write_text(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.flush()
	file.close()
	return true


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	var parsed: Variant = json.data
	if not parsed is Dictionary:
		return {}
	return parsed
