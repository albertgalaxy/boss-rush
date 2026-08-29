extends Node2D

var fraction := 0.0
@export var radius := 22.0
@export var color := Color(1, 0.8, 0.3, 0.85)

func _process(_delta: float) -> void:
	if visible:
		queue_redraw()

func _draw() -> void:
	if fraction <= 0.0:
		return
	draw_arc(Vector2.ZERO, radius, -PI / 2.0, -PI / 2.0 + TAU * fraction, 32, color, 3.0)
	draw_circle(Vector2.ZERO, 3.0 + fraction * 5.0, color)
