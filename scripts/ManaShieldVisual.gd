extends Node2D

@export var radius := 30.0
@export var color := Color(0.3, 0.6, 1.0, 0.35)
@export var ring_color := Color(0.6, 0.85, 1.0, 0.85)

func _process(_delta: float) -> void:
	if visible:
		queue_redraw()

func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var pulse := 3.0 * sin(t * 10.0)
	draw_circle(Vector2.ZERO, radius + pulse, color)
	draw_arc(Vector2.ZERO, radius + 2.0 + pulse, 0.0, TAU, 48, ring_color, 2.5)
