class_name CabinReticle
extends Control
## Reticulo contextual de la cabina. Solo dibuja: no captura eventos ni duplica
## controles. El color y el texto del prompt comunican el estado sin depender
## unicamente del color.

const IDLE_COLOR := Color(0.82, 0.84, 0.8, 0.5)
const FOCUS_COLOR := Color(1.0, 0.72, 0.2, 0.95)
const BLOCKED_COLOR := Color(0.92, 0.3, 0.24, 0.95)

var focused := false
var available := true


func set_state(focused_in: bool, available_in: bool) -> void:
	focused = focused_in
	available = available_in
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := maxf(4.0, minf(size.x, size.y) * 0.34)
	var color := IDLE_COLOR
	if focused:
		color = FOCUS_COLOR if available else BLOCKED_COLOR
	draw_arc(center, radius, 0.0, TAU, 32, color, 2.0, true)
	draw_circle(center, 1.6, color)
