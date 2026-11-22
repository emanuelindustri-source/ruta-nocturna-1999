extends Node
## Detecta hardware y recomienda un perfil gráfico. No cambia ajustes:
## SettingsManager es el único que persiste calidad y accesibilidad.

const PROFILE_DESKTOP_HIGH := "desktop_high"
const PROFILE_DESKTOP_BALANCED := "desktop_balanced"
const PROFILE_MOBILE_HIGH := "mobile_high"
const PROFILE_MOBILE_LOW := "mobile_low"

var _info: Dictionary = {}
var _recommended_profile := PROFILE_DESKTOP_BALANCED


func _ready() -> void:
	_info = _detect_hardware()
	_recommended_profile = _recommend_profile(_info)
	_info["recommended_profile"] = _recommended_profile
	EventBus.diagnostics_context_requested.connect(_on_diagnostics_context_requested)
	EventBus.diagnostics_context_updated.emit("hardware", get_info())
	print(
		"[HARDWARE] %s · %s · %s núcleos · %.2f GB RAM · perfil %s"
		% [
			_info.get("platform", "desconocida"),
			_info.get("cpu_name", "CPU desconocida"),
			_info.get("cpu_count", 0),
			float(_info.get("memory_physical_bytes", 0)) / 1073741824.0,
			_recommended_profile,
		]
	)


func get_info() -> Dictionary:
	return _info.duplicate(true)


func get_recommended_profile() -> String:
	return _recommended_profile


func is_mobile() -> bool:
	return bool(_info.get("is_mobile", false))


func _detect_hardware() -> Dictionary:
	var memory_info: Dictionary = OS.get_memory_info()
	var screen_size: Vector2i = DisplayServer.screen_get_size()
	var engine_info: Dictionary = Engine.get_version_info()
	var info := {
		"platform": OS.get_name(),
		"is_mobile": OS.has_feature("mobile"),
		"model": OS.get_model_name(),
		"cpu_name": OS.get_processor_name(),
		"cpu_count": OS.get_processor_count(),
		"memory_physical_bytes": int(memory_info.get("physical", 0)),
		"memory_available_bytes": int(memory_info.get("available", 0)),
		"gpu_vendor": RenderingServer.get_video_adapter_vendor(),
		"gpu_name": RenderingServer.get_video_adapter_name(),
		"gpu_api": RenderingServer.get_video_adapter_api_version(),
		"gpu_type": str(RenderingServer.get_video_adapter_type()),
		"screen_width": screen_size.x,
		"screen_height": screen_size.y,
		"screen_scale": DisplayServer.screen_get_scale(),
		"engine_version": str(engine_info.get("string", "")),
		"debug_build": OS.is_debug_build(),
	}
	return info


func _recommend_profile(info: Dictionary) -> String:
	var memory_gb := float(info.get("memory_physical_bytes", 0)) / 1073741824.0
	var cpu_count := int(info.get("cpu_count", 0))
	if bool(info.get("is_mobile", false)):
		if memory_gb >= 5.5 and cpu_count >= 8:
			return PROFILE_MOBILE_HIGH
		return PROFILE_MOBILE_LOW
	if memory_gb >= 12.0 and cpu_count >= 8:
		return PROFILE_DESKTOP_HIGH
	return PROFILE_DESKTOP_BALANCED


func _on_diagnostics_context_requested() -> void:
	EventBus.diagnostics_context_updated.emit("hardware", get_info())
