extends Area2D

var direction := Vector2.RIGHT
var speed := 260.0
var damage := 10
var source: Node = null
var _hit_bodies: Array = []

@onready var timer: Timer = $Timer

func setup(dir: Vector2, dmg: int, src: Node) -> void:
	direction = dir.normalized()
	damage = dmg
	source = src
	if src and src.is_in_group("player"):
		collision_mask = 4
	else:
		collision_mask = 2

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	timer.timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

func _on_body_entered(body: Node) -> void:
	if body == source or body in _hit_bodies:
		return
	if body.has_method("take_damage"):
		body.take_damage(damage, source)
		_hit_bodies.append(body)
