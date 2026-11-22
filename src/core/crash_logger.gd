extends Logger
## Logger nativo que entrega mensajes a CrashReporter.
##
## Se mantiene en un archivo separado para que el autoload CrashReporter sea el
## único dueño del búfer, el marcador de sesión y el reporte local.

var _reporter = null


func setup(reporter: Node) -> void:
	_reporter = reporter


func _log_message(message: String, error: bool) -> void:
	if _reporter == null or not is_instance_valid(_reporter):
		return
	_reporter._capture_log(message, error)


func _log_error(
	function: String,
	file: String,
	line: int,
	code: String,
	rationale: String,
	_editor_notify: bool,
	error_type: int,
	script_backtraces: Array[ScriptBacktrace]
) -> void:
	if _reporter == null or not is_instance_valid(_reporter):
		return
	var level := "WARNING" if error_type == Logger.ERROR_TYPE_WARNING else "ERROR"
	var text := "%s %s (%s:%d) %s" % [level, function, file, line, code]
	if not rationale.is_empty():
		text += " | " + rationale
	for backtrace in script_backtraces:
		if backtrace == null or backtrace.is_empty():
			continue
		text += "\n" + backtrace.format(4, 12)
	_reporter._capture_error(text, error_type)
