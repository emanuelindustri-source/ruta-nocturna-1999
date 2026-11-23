extends Node
## Guardados base con escritura atómica, checksum y backups.
##
## SaveManager lee snapshots de GameState y aplica la carga sobre el estado, nunca
## sobre nodos del mundo. Las migraciones reales llegan con la Fase 9.4.

const SAVE_VERSION := 1
const SAVE_DIR := "user://saves"
const QA_DIR := "user://saves/qa"
const MAX_SLOTS := 100

var _last_error := ""


func _ready() -> void:
	_ensure_directory(SAVE_DIR)
	_ensure_directory(QA_DIR)
	EventBus.save_requested.connect(_on_save_requested)
	EventBus.load_requested.connect(_on_load_requested)
	EventBus.diagnostics_context_requested.connect(_on_diagnostics_context_requested)


func get_last_error() -> String:
	return _last_error


func get_slot_path(slot: int, qa: bool = false) -> String:
	var directory := QA_DIR if qa else SAVE_DIR
	return "%s/slot_%02d.json" % [directory, slot]


func save_slot(slot: int, reason: String = "manual", qa_mode: int = -1) -> bool:
	if slot < 0 or slot >= MAX_SLOTS:
		return _fail_save(slot, "slot fuera de rango")
	var qa := GameState.is_test_save if qa_mode < 0 else bool(qa_mode)
	var path := get_slot_path(slot, qa)
	if not _ensure_directory(path.get_base_dir()):
		return _fail_save(slot, "no se pudo crear el directorio de guardados")
	if FileAccess.file_exists(path):
		var existing := _read_envelope(path)
		if existing.is_empty():
			return _fail_save(slot, "el guardado existente es ilegible; no se sobrescribe")
		if int(existing.get("save_version", 0)) > SAVE_VERSION:
			return _fail_save(slot, "el guardado existente es de una versión futura")
	var snapshot := GameState.snapshot()
	var snapshot_json := _canonical_json(snapshot)
	var envelope := {
		"save_version": SAVE_VERSION,
		"game_version": _game_version(),
		"checksum": snapshot_json.sha256_text(),
		"timestamp_utc": Time.get_datetime_string_from_system(true, false) + "Z",
		"rng_seed": int(snapshot.get("rng_seed", 1999)),
		"data": snapshot,
	}
	var serialized := JSON.stringify(envelope, "\t", true, true) + "\n"
	if not _write_atomic(path, serialized):
		return _fail_save(slot, "fallo de escritura atómica")
	EventBus.save_completed.emit(slot, path)
	EventBus.diagnostics_action.emit(
		"save_completed",
		{"slot": slot, "path": path, "reason": reason, "qa": qa}
	)
	return true


func load_slot(slot: int, qa_mode: int = -1) -> bool:
	if slot < 0 or slot >= MAX_SLOTS:
		return _fail_load(slot, "slot fuera de rango")
	var qa := GameState.is_test_save if qa_mode < 0 else bool(qa_mode)
	var path := get_slot_path(slot, qa)
	if not FileAccess.file_exists(path):
		var backup_path := path + ".bak"
		if FileAccess.file_exists(backup_path):
			push_warning("SaveManager: se usa el backup de %s" % path)
			path = backup_path
		else:
			return _fail_load(slot, "no existe el guardado")
	var envelope := _read_envelope(path)
	if envelope.is_empty():
		return _fail_load(slot, "JSON inválido")
	for key in ["save_version", "game_version", "checksum", "data"]:
		if not envelope.has(key):
			return _fail_load(slot, "guardado sin campo %s" % key)
	var save_version := int(envelope.get("save_version", 0))
	if save_version > SAVE_VERSION:
		return _fail_load(slot, "guardado de versión futura %d" % save_version)
	var data: Variant = envelope.get("data")
	if not data is Dictionary:
		return _fail_load(slot, "el bloque data no es un diccionario")
	var expected := str(envelope.get("checksum", ""))
	var actual := _canonical_json(data).sha256_text()
	if expected != actual:
		return _fail_load(slot, "checksum inválido")
	if save_version < SAVE_VERSION:
		_backup_file(path)
		var migrated := _migrate(data, save_version)
		if migrated.is_empty():
			return _fail_load(slot, "migración no disponible desde v%d" % save_version)
		data = migrated
	if not GameState.apply_snapshot(data, "slot_%02d" % slot):
		return _fail_load(slot, "GameState rechazó el snapshot")
	EventBus.load_completed.emit(slot, data)
	EventBus.diagnostics_action.emit(
		"load_completed",
		{"slot": slot, "path": path, "qa": qa, "save_version": save_version}
	)
	return true


func delete_slot(slot: int, qa: bool = false) -> bool:
	var path := get_slot_path(slot, qa)
	var directory := DirAccess.open(path.get_base_dir())
	if directory == null:
		return false
	var filename := path.get_file()
	var removed := false
	if directory.file_exists(filename):
		removed = directory.remove(filename) == OK
	if directory.file_exists(filename + ".bak"):
		directory.remove(filename + ".bak")
	EventBus.diagnostics_action.emit("delete_slot", {"slot": slot, "qa": qa, "removed": removed})
	return removed


func list_slots(include_qa: bool = false) -> Array:
	var slots: Array = []
	var directories := [SAVE_DIR]
	if include_qa:
		directories.append(QA_DIR)
	for directory_path in directories:
		var directory := DirAccess.open(directory_path)
		if directory == null:
			continue
		for filename in directory.get_files():
			if not filename.begins_with("slot_") or not filename.ends_with(".json"):
				continue
			var path := "%s/%s" % [directory_path, filename]
			var envelope := _read_envelope(path)
			if envelope.is_empty():
				continue
			slots.append(
				{
					"path": path,
					"save_version": int(envelope.get("save_version", 0)),
					"game_version": str(envelope.get("game_version", "")),
					"timestamp_utc": str(envelope.get("timestamp_utc", "")),
					"qa": directory_path == QA_DIR,
				}
			)
	return slots


func get_diagnostics_context() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"slot_count": list_slots(true).size(),
		"save_dir": SAVE_DIR,
		"last_error": _last_error,
	}


func _on_save_requested(slot: int, reason: String) -> void:
	save_slot(slot, reason)


func _on_load_requested(slot: int) -> void:
	load_slot(slot)


func _on_diagnostics_context_requested() -> void:
	EventBus.diagnostics_context_updated.emit("save", get_diagnostics_context())


func _fail_save(slot: int, reason: String) -> bool:
	_last_error = reason
	EventBus.save_failed.emit(slot, reason)
	EventBus.diagnostics_action.emit("save_failed", {"slot": slot, "reason": reason})
	push_warning("SaveManager: guardado %d falló: %s" % [slot, reason])
	return false


func _fail_load(slot: int, reason: String) -> bool:
	_last_error = reason
	EventBus.load_failed.emit(slot, reason)
	EventBus.diagnostics_action.emit("load_failed", {"slot": slot, "reason": reason})
	push_warning("SaveManager: carga %d falló: %s" % [slot, reason])
	return false


func _game_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


func _ensure_directory(path: String) -> bool:
	var directory := DirAccess.open(path)
	if directory != null:
		return true
	var user_dir := DirAccess.open("user://")
	if user_dir == null:
		return false
	var relative := path.trim_prefix("user://")
	var error := user_dir.make_dir_recursive(relative)
	return error == OK or DirAccess.open(path) != null


func _read_envelope(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	var parse_error := json.parse(text)
	if parse_error != OK:
		return {}
	var parsed: Variant = json.data
	if not parsed is Dictionary:
		return {}
	return parsed


func _write_atomic(path: String, text: String) -> bool:
	var temp_path := path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.flush()
	file.close()
	var check := FileAccess.open(temp_path, FileAccess.READ)
	if check == null:
		return false
	var written := check.get_as_text()
	check.close()
	if written != text:
		return false
	var directory := DirAccess.open(path.get_base_dir())
	if directory == null:
		return false
	var filename := path.get_file()
	if directory.file_exists(filename):
		if not _backup_file(path):
			push_warning("SaveManager: no se pudo respaldar %s" % filename)
		directory.remove(filename)
	var rename_error := directory.rename(filename + ".tmp", filename)
	if rename_error != OK:
		push_error("SaveManager: no se pudo activar %s (%s)" % [filename, rename_error])
		if directory.file_exists(filename + ".bak"):
			# DirAccess.copy resuelve las rutas contra el proceso, no contra el
			# directorio: se pasan rutas absolutas (F2.4, prueba de respaldo).
			directory.copy(path + ".bak", path)
		return false
	return true


func _backup_file(path: String) -> bool:
	var directory := DirAccess.open(path.get_base_dir())
	if directory == null:
		return false
	var filename := path.get_file()
	if not directory.file_exists(filename):
		return false
	if directory.file_exists(filename + ".bak"):
		directory.remove(filename + ".bak")
	return directory.copy(path, path + ".bak") == OK


func _migrate(data: Variant, from_version: int) -> Dictionary:
	# Fase 9.4 encadena migraciones reales. Solo existe la versión 1.
	if from_version == SAVE_VERSION and data is Dictionary:
		return (data as Dictionary).duplicate(true)
	return {}


func _canonical_json(value: Variant) -> String:
	match typeof(value):
		TYPE_DICTIONARY:
			var dictionary: Dictionary = value
			var keys: Array = dictionary.keys()
			keys.sort()
			var parts := PackedStringArray()
			for key in keys:
				parts.append(JSON.stringify(str(key)) + ":" + _canonical_json(dictionary[key]))
			return "{" + ",".join(parts) + "}"
		TYPE_ARRAY:
			var array: Array = value
			var items := PackedStringArray()
			for item in array:
				items.append(_canonical_json(item))
			return "[" + ",".join(items) + "]"
		TYPE_INT:
			return str(int(value))
		TYPE_FLOAT:
			var number := float(value)
			if is_equal_approx(number, roundf(number)) and absf(number) < 1.0e15:
				return str(int(number))
			return JSON.stringify(number, "", true, true)
		_:
			return JSON.stringify(value, "", true, true)
