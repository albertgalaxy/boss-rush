extends Node2D

const HALF_ARC := deg_to_rad(70.0)

var active := false
var duration := 0.15
var facing := 1
var color := Color(1, 0.85, 0.2, 0.7)
var reach := 42.0

var _timer := 0.0

func play(p_duration: float, p_facing: int, p_color: Color, p_reach: float = 42.0) -> void:
	duration = max(0.01, p_duration)
	facing = p_facing
	color = p_color
	reach = p_reach
	_timer = 0.0
	active = true
	visible = true
	queue_redraw()

func _process(delta: float) -> void:
	if not active:
		return
	_timer += delta
	queue_redraw()
	if _timer >= duration:
		active = false
		visible = false

func _draw() -> void:
	if not active:
		return
	var progress := clampf(_timer / duration, 0.0, 1.0)
	var base_angle := 0.0 if facing >= 0 else PI
	var start_angle := base_angle - HALF_ARC
	var end_angle := base_angle + HALF_ARC
	var current_end := lerpf(start_angle, end_angle, progress)
	var fade := 1.0 - clampf((progress - 0.5) / 0.5, 0.0, 1.0)
	var draw_color := Color(color.r, color.g, color.b, color.a * fade)

	var inner_radius := reach * 0.3
	var steps := 16
	var points := PackedVector2Array()
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var a := lerpf(start_angle, current_end, t)
		points.append(Vector2(cos(a), sin(a)) * reach)
	for i in range(steps, -1, -1):
		var t := float(i) / float(steps)
		var a := lerpf(start_angle, current_end, t)
		points.append(Vector2(cos(a), sin(a)) * inner_radius)

	draw_colored_polygon(points, draw_color)
