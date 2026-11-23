class_name CabinInteractionSpec
extends RefCounted
## Carga y consulta el contrato de interaccion contextual de la cabina.
##
## La fuente de verdad es data/schemas/cabin_interaction.json. El contrato no
## duplica el tren motriz: la palanca y el Overdrive se delegan en
## VehiclePowertrain y el freno de mano termina en brakes.parking.

const SPEC_PATH := "res://data/schemas/cabin_interaction.json"

var data: Dictionary = {}
var errors: PackedStringArray = []


func load_spec(path: String = SPEC_PATH) -> bool:
	errors.clear()
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		errors.append("no se pudo leer %s" % path)
		return false
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		errors.append("JSON invalido en %s" % path)
		return false
	data = parsed
	if int(data.get("schema_version", 0)) != 1:
		errors.append("schema_version no soportada")
	if not (data.get("controls") is Array) or not (data.get("hands") is Dictionary):
		errors.append("faltan las secciones controls/hands")
	return errors.is_empty()


func get_value(path: String, default_value: Variant = null) -> Variant:
	var current: Variant = data
	for part in path.split("."):
		if not (current is Dictionary) or not current.has(part):
			return default_value
		current = current[part]
	return current


func section(path: String) -> Dictionary:
	var value: Variant = get_value(path, {})
	return value if value is Dictionary else {}


func array(path: String) -> Array:
	var value: Variant = get_value(path, [])
	return value if value is Array else []


func number(path: String, default_value: float) -> float:
	var value: Variant = get_value(path, default_value)
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return float(value)
	return default_value


func string(path: String, default_value: String = "") -> String:
	var value: Variant = get_value(path, default_value)
	return default_value if value == null else str(value)


func boolean(path: String, default_value: bool = false) -> bool:
	var value: Variant = get_value(path, default_value)
	return bool(value)


func control(control_id: String) -> Dictionary:
	for entry in array("controls"):
		if entry is Dictionary and str(entry.get("id", "")) == control_id:
			return entry
	return {}


func control_ids() -> PackedStringArray:
	var result := PackedStringArray()
	for entry in array("controls"):
		if entry is Dictionary:
			result.append(str(entry.get("id", "")))
	return result


func pose(pose_id: String) -> Dictionary:
	for entry in array("hands.poses"):
		if entry is Dictionary and str(entry.get("id", "")) == pose_id:
			return entry
	return {}


func feedback_key(code: String) -> String:
	var feedback: Dictionary = section("feedback")
	return str(feedback.get(code, ""))
