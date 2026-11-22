extends Node
## Consulta releases de GitHub sin bloquear el juego y sin autoinstalar.
##
## Desactivado por defecto. La build de GitHub puede ofrecer la descarga; la
## variante de Play solo abrirá la ficha de la tienda en la fase OTA.

const API_URL := "https://api.github.com/repos/emanuelindustri-source/ruta-nocturna-1999/releases/latest"
const REQUEST_TIMEOUT_SECONDS := 10.0

var _http: HTTPRequest = null
var _requesting := false
var _last_status := "idle"
var _last_detail := ""


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.name = "GitHubRequest"
	_http.timeout = REQUEST_TIMEOUT_SECONDS
	_http.request_completed.connect(_on_request_completed)
	add_child(_http)
	EventBus.application_booted.connect(_on_application_booted)
	EventBus.diagnostics_context_requested.connect(_on_diagnostics_context_requested)
	EventBus.diagnostics_context_updated.emit("update", get_diagnostics_context())


func check_for_updates(force: bool = false) -> bool:
	if _requesting:
		return false
	if not force and not bool(SettingsManager.get_value("network", "check_updates", false)):
		_last_status = "disabled"
		_last_detail = "Las actualizaciones están desactivadas en Ajustes."
		EventBus.update_check_finished.emit(_last_status, _last_detail)
		return false
	var headers := PackedStringArray(
		["Accept: application/vnd.github+json", "User-Agent: RutaNocturna1999"]
	)
	var error := _http.request(API_URL, headers, HTTPClient.METHOD_GET)
	if error != OK:
		_last_status = "error"
		_last_detail = "No se pudo iniciar la consulta (%s)." % error
		EventBus.update_check_finished.emit(_last_status, _last_detail)
		return false
	_requesting = true
	_last_status = "requesting"
	_last_detail = ""
	return true


func get_last_status() -> Dictionary:
	return {"status": _last_status, "detail": _last_detail, "requesting": _requesting}


func get_current_version() -> String:
	var raw := str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	return raw.trim_prefix("v")


func is_newer_version(candidate: String, base: String) -> bool:
	var candidate_parts := _version_parts(candidate)
	var base_parts := _version_parts(base)
	if candidate_parts.is_empty() or base_parts.is_empty():
		return false
	for index in range(3):
		if candidate_parts[index] > base_parts[index]:
			return true
		if candidate_parts[index] < base_parts[index]:
			return false
	return false


func get_diagnostics_context() -> Dictionary:
	return {"status": _last_status, "detail": _last_detail, "requesting": _requesting}


func _version_parts(version: String) -> Array[int]:
	var cleaned := version.strip_edges().trim_prefix("v").trim_prefix("V")
	if cleaned.is_empty():
		return []
	cleaned = cleaned.split("-")[0]
	var parts := cleaned.split(".")
	if parts.is_empty() or not parts[0].is_valid_int():
		return []
	var result: Array[int] = []
	for index in range(3):
		if index < parts.size() and parts[index].is_valid_int():
			result.append(int(parts[index]))
		else:
			result.append(0)
	return result


func _on_request_completed(
	result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray
) -> void:
	_requesting = false
	if result != HTTPRequest.RESULT_SUCCESS:
		_last_status = "offline"
		_last_detail = "Sin conexión o consulta cancelada (%s)." % result
		EventBus.update_check_finished.emit(_last_status, _last_detail)
		return
	if response_code != 200:
		_last_status = "error"
		_last_detail = "GitHub respondió HTTP %d." % response_code
		EventBus.update_check_finished.emit(_last_status, _last_detail)
		return
	var json := JSON.new()
	var parse_error := json.parse(body.get_string_from_utf8())
	if parse_error != OK or not json.data is Dictionary:
		_last_status = "error"
		_last_detail = "Respuesta de GitHub inválida."
		EventBus.update_check_finished.emit(_last_status, _last_detail)
		return
	var release: Dictionary = json.data
	var tag := str(release.get("tag_name", ""))
	var url := str(release.get("html_url", ""))
	if tag.is_empty():
		_last_status = "error"
		_last_detail = "La release no tiene tag."
		EventBus.update_check_finished.emit(_last_status, _last_detail)
		return
	if is_newer_version(tag, get_current_version()):
		_last_status = "available"
		_last_detail = tag
		EventBus.update_available.emit(tag, url)
	else:
		_last_status = "up_to_date"
		_last_detail = tag
	EventBus.update_check_finished.emit(_last_status, _last_detail)


func _on_diagnostics_context_requested() -> void:
	EventBus.diagnostics_context_updated.emit("update", get_diagnostics_context())


func _on_application_booted(_version: String) -> void:
	# Solo consulta si el jugador habilitó las actualizaciones. No bloquea.
	call_deferred("check_for_updates", false)
