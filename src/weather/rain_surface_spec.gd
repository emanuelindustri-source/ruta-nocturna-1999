class_name RainSurfaceSpec
extends RefCounted
## Carga y valida el contrato de lluvia física, humedad y limpiaparabrisas.
##
## La fuente de verdad es `data/schemas/rain_surface_fx.json`. Este cargador
## comprueba la estructura mínima en runtime; la validación completa de tipos y
## referencias cruzadas vive en `tools/validate_schemas.py` (Python).

const SPEC_PATH := "res://data/schemas/rain_surface_fx.json"
const REQUIRED_SECTIONS := [
	"precipitation",
	"surfaces",
	"wetness",
	"droplets",
	"wiper",
	"puddles",
	"budgets",
	"states",
]

var data: Dictionary = {}
var errors: PackedStringArray = []


func load_spec(path: String = SPEC_PATH) -> bool:
	errors.clear()
	data.clear()
	if not FileAccess.file_exists(path):
		errors.append("missing:%s" % path)
		return false
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		errors.append("empty:%s" % path)
		return false
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		errors.append("invalid_json:%s" % path)
		return false
	data = parsed
	if int(data.get("schema_version", 0)) < 1:
		errors.append("schema_version")
	for section_name in REQUIRED_SECTIONS:
		var section_value: Variant = data.get(section_name, null)
		if not (section_value is Dictionary):
			errors.append("section:%s" % section_name)
	if int(data.get("schema_version", 0)) != 1:
		errors.append("schema_version_unsupported")
	return errors.is_empty()


func section(section_name: String) -> Dictionary:
	var value: Variant = data.get(section_name, {})
	return value if value is Dictionary else {}


func value(path: String, fallback: Variant = null) -> Variant:
	var current: Variant = data
	for part in path.split("."):
		if not (current is Dictionary) or not current.has(part):
			return fallback
		current = current[part]
	return current


func number(path: String, fallback: float = 0.0) -> float:
	var found: Variant = value(path, fallback)
	if found is int or found is float:
		return float(found)
	return fallback


func integer(path: String, fallback: int = 0) -> int:
	var found: Variant = value(path, fallback)
	if found is int or found is float:
		return int(found)
	return fallback


func boolean(path: String, fallback: bool = false) -> bool:
	var found: Variant = value(path, fallback)
	return bool(found) if found is bool else fallback


func array(path: String, fallback: Array = []) -> Array:
	var found: Variant = value(path, fallback)
	return found if found is Array else fallback


func dictionary(path: String, fallback: Dictionary = {}) -> Dictionary:
	var found: Variant = value(path, fallback)
	return found if found is Dictionary else fallback


func class_spec(class_id: String) -> Dictionary:
	for entry in section("surfaces").get("classes", []):
		if entry is Dictionary and str(entry.get("id", "")) == class_id:
			return entry
	return {}


func panel_spec(panel_id: String) -> Dictionary:
	for entry in section("surfaces").get("vehicle_panels", []):
		if entry is Dictionary and str(entry.get("id", "")) == panel_id:
			return entry
	return {}


func droplet_profile(profile_id: String) -> Dictionary:
	for entry in section("droplets").get("profiles", []):
		if entry is Dictionary and str(entry.get("id", "")) == profile_id:
			return entry
	return {}


func puddle_archetype(zone_id: String) -> Dictionary:
	for entry in section("puddles").get("zone_archetypes", []):
		if entry is Dictionary and str(entry.get("id", "")) == zone_id:
			return entry
	return {}
