extends BossBase
class_name Minion

@export var contact_damage := 6
@export var move_speed := 130.0

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var player: Node = null

@onready var sprite: ColorRect = $Sprite
@onready var hit_area: Area2D = $HitArea

func _ready() -> void:
	hp = max_hp
	grants_xp = false
	hit_area.body_entered.connect(_on_hit_area_body_entered)
	call_deferred("_find_player")

func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	if player and is_instance_valid(player):
		var dir: float = signf(player.global_position.x - global_position.x)
		velocity.x = dir * move_speed
	else:
		velocity.x = 0
	if stagger_time_left > 0.0:
		stagger_time_left -= delta
		velocity.x = 0
	knockback_velocity = move_toward(knockback_velocity, 0.0, 600.0 * delta)
	velocity.x += knockback_velocity
	move_and_slide()

func _on_hit_area_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(contact_damage, self)

func take_damage(amount: int, attacker: Node = null) -> void:
	hp = max(hp - amount, 0)
	hp_changed.emit(hp, max_hp)
	Juice.flash(sprite, Color(1, 1, 1), 0.06)
	if hp <= 0:
		Juice.burst(get_parent(), global_position, sprite.color, 8)
		died.emit()
		queue_free()
