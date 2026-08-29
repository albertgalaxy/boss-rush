extends Node

var _rng := RandomNumberGenerator.new()
var _hitstop_token := 0

var _shake_camera: Camera2D = null
var _shake_time_left := 0.0
var _shake_duration := 0.0
var _shake_strength := 0.0

func _ready() -> void:
	_rng.randomize()

func _process(delta: float) -> void:
	if _shake_time_left > 0.0 and is_instance_valid(_shake_camera):
		_shake_time_left = max(_shake_time_left - delta, 0.0)
		var falloff := _shake_time_left / _shake_duration if _shake_duration > 0.0 else 0.0
		_shake_camera.offset = Vector2(
			_rng.randf_range(-1.0, 1.0),
			_rng.randf_range(-1.0, 1.0)
		) * _shake_strength * falloff
		if _shake_time_left <= 0.0:
			_shake_camera.offset = Vector2.ZERO

func flash(node: CanvasItem, color: Color = Color(1, 1, 1), duration: float = 0.08) -> void:
	if not is_instance_valid(node):
		return
	if not node.has_meta("_juice_base_modulate"):
		node.set_meta("_juice_base_modulate", node.modulate)
	node.modulate = color
	await get_tree().create_timer(duration, true, false, true).timeout
	if is_instance_valid(node):
		node.modulate = node.get_meta("_juice_base_modulate", Color.WHITE)

func shake(camera: Camera2D, strength: float = 8.0, duration: float = 0.2) -> void:
	if not is_instance_valid(camera):
		return
	_shake_camera = camera
	_shake_strength = strength
	_shake_duration = duration
	_shake_time_left = duration

func hitstop(duration: float = 0.05, scale: float = 0.05) -> void:
	_hitstop_token += 1
	var token := _hitstop_token
	Engine.time_scale = scale
	await get_tree().create_timer(duration, true, false, true).timeout
	if token == _hitstop_token:
		Engine.time_scale = 1.0

func burst(parent: Node, global_pos: Vector2, color: Color = Color.WHITE, amount: int = 12) -> void:
	if not is_instance_valid(parent):
		return
	var particles := CPUParticles2D.new()
	parent.add_child(particles)
	particles.global_position = global_pos
	particles.one_shot = true
	particles.amount = amount
	particles.lifetime = 0.4
	particles.explosiveness = 1.0
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.gravity = Vector2(0, 500)
	particles.initial_velocity_min = 80.0
	particles.initial_velocity_max = 220.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = color
	particles.process_mode = Node.PROCESS_MODE_ALWAYS
	particles.emitting = true
	get_tree().create_timer(particles.lifetime + 0.1, true, false, true).timeout.connect(particles.queue_free)

var _flash_layer: CanvasLayer = null
var _flash_rect: ColorRect = null
var _flash_tween: Tween = null

func _ensure_flash_overlay() -> void:
	if _flash_rect != null and is_instance_valid(_flash_rect):
		return
	_flash_layer = CanvasLayer.new()
	_flash_layer.layer = 100
	_flash_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_flash_rect = ColorRect.new()
	_flash_rect.color = Color(1, 1, 1, 0.0)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_layer.add_child(_flash_rect)
	get_tree().root.add_child(_flash_layer)

func screen_flash(color: Color = Color(1, 1, 1, 0.3), duration: float = 0.12) -> void:
	_ensure_flash_overlay()
	_flash_rect.color = color
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = _flash_layer.create_tween()
	_flash_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_flash_tween.tween_property(_flash_rect, "color:a", 0.0, duration).set_ease(Tween.EASE_OUT)

func poison_tick_popup(parent: Node, global_pos: Vector2, amount: int) -> void:
	if not is_instance_valid(parent):
		return
	var label := Label.new()
	label.text = "-%d" % amount
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.5, 0.95, 0.35))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var jitter := Vector2(_rng.randf_range(-8.0, 8.0), 0.0)
	label.global_position = global_pos + Vector2(-8, -20) + jitter
	label.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(label)
	var tween := label.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(label, "global_position", label.global_position + Vector2(0, -18), 0.4).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.4)
	tween.tween_callback(label.queue_free)

func damage_popup(parent: Node, global_pos: Vector2, amount: int, is_crit: bool = false) -> void:
	if not is_instance_valid(parent):
		return
	var label := Label.new()
	label.text = str(amount)
	label.add_theme_font_size_override("font_size", 26 if is_crit else 16)
	label.add_theme_color_override("font_color", Color(1, 0.85, 0.2) if is_crit else Color(1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var jitter := Vector2(_rng.randf_range(-10.0, 10.0), 0.0)
	label.global_position = global_pos + Vector2(-10, -30) + jitter
	label.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(label)
	var tween := label.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(label, "global_position", label.global_position + Vector2(0, -26), 0.45).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.45)
	tween.tween_callback(label.queue_free)

func crit_popup(parent: Node, global_pos: Vector2) -> void:
	if not is_instance_valid(parent):
		return
	var label := Label.new()
	label.text = "CRIT!"
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.global_position = global_pos + Vector2(-24, -50)
	label.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(label)
	var tween := label.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(label, "global_position", label.global_position + Vector2(0, -30), 0.5).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)
