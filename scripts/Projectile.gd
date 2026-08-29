extends Area2D

var direction := Vector2.RIGHT
var speed := 500.0
var damage := 10
var pierce := 0
var source: Node = null
var charged_fraction := -1.0
var _hit_bodies: Array = []

@onready var timer: Timer = $Timer

func setup(dir: Vector2, dmg: int, pierce_count: int, src: Node) -> void:
	direction = dir.normalized()
	damage = dmg
	pierce = pierce_count
	source = src
	rotation = direction.angle()
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
	if body == source:
		return
	if body in _hit_bodies:
		return
	if not body.has_method("take_damage"):
		return
	_hit_bodies.append(body)
	if source and source.has_method("resolve_ranged_hit"):
		source.resolve_ranged_hit(body, damage, charged_fraction)
	else:
		body.take_damage(damage, source)
	if pierce <= 0:
		queue_free()
	else:
		pierce -= 1
