class_name WeatherBridge
extends Node
## Puente de escena entre `WeatherManager` y `RainFxController` (F4.4).
##
## No es autoload y no crea dependencias circulares: WeatherManager no conoce la
## escena; este nodo lee su estado y lo inyecta en el controlador de lluvia con
## `set_weather()`. Conserva el lookdev `demo_*` de F3.4 hasta que el clima real
## se activa (cambio de preset/región o `always_follow`), de modo que las pruebas
## de render de F3.5 siguen siendo reproducibles.

@export var rain_fx_path: NodePath = NodePath("../RainFx")
@export var always_follow := false

var rain_fx: RainFxController
var _applied := false
var _last_revision := -1


func _ready() -> void:
	rain_fx = get_node_or_null(rain_fx_path) as RainFxController
	if rain_fx == null:
		rain_fx = get_parent().get_node_or_null("RainFx") as RainFxController
	_last_revision = WeatherManager.revision
	_applied = always_follow
	if _applied:
		apply_now()


func _process(_delta: float) -> void:
	if not _applied:
		if WeatherManager.revision == _last_revision:
			return
		_applied = true
	_last_revision = WeatherManager.revision
	apply_now()


func apply_now() -> Dictionary:
	if rain_fx == null:
		return {}
	var state := WeatherManager.get_state()
	rain_fx.set_weather(
		float(state.get("rain", 0.0)),
		float(state.get("humidity", 0.5)),
		float(state.get("wind", 0.0)),
		float(state.get("temperature", 20.0))
	)
	return state


func is_following() -> bool:
	return _applied
