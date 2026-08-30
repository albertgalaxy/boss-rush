extends Node2D

var fraction := 0.0
@export var radius := 12.0
@export var color := Color(1, 1, 1, 0.85)

func _process(_delta: float) -> void:
	if visible:
		queue_redraw()

func _draw() -> void:
	if fraction <= 0.0:
		return
	draw_arc(Vector2.ZERO, radius, -PI / 2.0, -PI / 2.0 + TAU * fraction, 24, color, 3.0, true)
