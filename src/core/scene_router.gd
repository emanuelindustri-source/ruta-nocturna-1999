extends Node
## Cambios de escena con carga threaded y un único estado de carga.
##
## SceneRouter conoce GameState para actualizar el modo, pero no guarda partidas
## ni muta el mundo. La UI solicita cambios por EventBus o por API.

var _pending_path := ""
var _pending_reason := ""
var _current_path := ""


func _ready() -> void:
	EventBus.scene_change_requested.connect(_on_scene_change_requested)
	EventBus.diagnostics_context_requested.connect(_on_diagnostics_context_requested)
	call_deferred("_capture_current_scene")
	EventBus.diagnostics_context_updated.emit("scene", get_diagnostics_context())


func _process(_delta: float) -> void:
	if _pending_path.is_empty():
		set_process(false)
		return
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(_pending_path, progress)
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			var ratio := 0.0
			if not progress.is_empty():
				ratio = float(progress[0])
			EventBus.loading_progress.emit(_pending_path, ratio)
		ResourceLoader.THREAD_LOAD_LOADED:
			var resource := ResourceLoader.load_threaded_get(_pending_path)
			if not resource is PackedScene:
				_fail("el recurso no es una PackedScene")
				return
			var error := get_tree().change_scene_to_packed(resource)
			if error != OK:
				_fail("change_scene_to_packed devolvió %s" % error)
				return
			var completed_path := _pending_path
			_current_path = completed_path
			_pending_path = ""
			set_process(false)
			GameState.set_mode(_mode_for_path(completed_path))
			EventBus.scene_changed.emit(completed_path)
			EventBus.diagnostics_action.emit(
				"scene_changed", {"path": completed_path, "reason": _pending_reason}
			)
			_pending_reason = ""
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_fail("carga threaded fallida (%s)" % status)


func change_scene(path: String, reason: String = "manual") -> bool:
	if not _pending_path.is_empty():
		push_warning("SceneRouter: ya hay una carga en curso hacia %s" % _pending_path)
		return false
	if not ResourceLoader.exists(path, "PackedScene"):
		EventBus.scene_load_failed.emit(path, "la escena no existe")
		push_warning("SceneRouter: escena inexistente %s" % path)
		return false
	var error := ResourceLoader.load_threaded_request(path, "PackedScene")
	if error != OK:
		EventBus.scene_load_failed.emit(path, "no se pudo iniciar la carga (%s)" % error)
		push_warning("SceneRouter: no se pudo iniciar %s (%s)" % [path, error])
		return false
	_pending_path = path
	_pending_reason = reason
	set_process(true)
	return true


func reload_current_scene(reason: String = "reload") -> bool:
	var path := get_current_scene_path()
	if path.is_empty():
		return false
	return change_scene(path, reason)


func route_to_boot() -> bool:
	return change_scene("res://scenes/boot/Boot.tscn", "route_to_boot")


func can_route_to(path: String) -> bool:
	return ResourceLoader.exists(path, "PackedScene")


func is_loading() -> bool:
	return not _pending_path.is_empty()


func get_pending_path() -> String:
	return _pending_path


func get_current_scene_path() -> String:
	if not _current_path.is_empty():
		return _current_path
	var scene := get_tree().current_scene
	if scene != null and not scene.scene_file_path.is_empty():
		_current_path = scene.scene_file_path
	return _current_path


func get_diagnostics_context() -> Dictionary:
	return {
		"current_scene": get_current_scene_path(),
		"pending_scene": _pending_path,
		"loading": is_loading(),
	}


func _capture_current_scene() -> void:
	var scene := get_tree().current_scene
	if scene != null:
		_current_path = scene.scene_file_path
		GameState.set_mode(_mode_for_path(_current_path))


func _fail(reason: String) -> void:
	var path := _pending_path
	_pending_path = ""
	_pending_reason = ""
	set_process(false)
	EventBus.scene_load_failed.emit(path, reason)
	EventBus.diagnostics_action.emit("scene_load_failed", {"path": path, "reason": reason})
	push_warning("SceneRouter: %s falló: %s" % [path, reason])


func _mode_for_path(path: String) -> String:
	if path.contains("/world/") or path.ends_with("World.tscn"):
		return GameState.MODE_PLAYING
	if path.contains("/menu/") or path.ends_with("MainMenu.tscn"):
		return GameState.MODE_MENU
	if path.contains("/boot/") or path.ends_with("Boot.tscn"):
		return GameState.MODE_BOOT
	return GameState.MODE_MENU


func _on_scene_change_requested(path: String, reason: String) -> void:
	change_scene(path, reason)


func _on_diagnostics_context_requested() -> void:
	EventBus.diagnostics_context_updated.emit("scene", get_diagnostics_context())
