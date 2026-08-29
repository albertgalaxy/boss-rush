extends BossBase
class_name BossSwarm

@export var move_speed := 60.0
@export var swipe_damage := 14

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var player: Node = null
var phase := 1
var _state := "idle"
var _state_timer := 0.0
var _facing := -1
var _attack_cooldown := 1.0

@onready var sprite: ColorRect = $Sprite
@onready var swipe_area: Area2D = $SwipeArea
@onready var telegraph: ColorRect = $Telegraph

func _ready() -> void:
	add_to_group("boss")
	hp = max_hp
	swipe_area.monitoring = false
	swipe_area.body_entered.connect(_on_swipe_body_entered)
	telegraph.visible = false
	call_deferred("_find_player")

func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	if player == null or not is_instance_valid(player):
		velocity.x = 0
		if stagger_time_left > 0.0:
			stagger_time_left -= delta
			velocity.x = 0
		knockback_velocity = move_toward(knockback_velocity, 0.0, 600.0 * delta)
		velocity.x += knockback_velocity
		move_and_slide()
		return

	_attack_cooldown = max(0.0, _attack_cooldown - delta)
	_state_timer -= delta

	match _state:
		"idle":
			_do_move()
			if _attack_cooldown <= 0.0:
				_pick_attack()
		"telegraph_summon":
			velocity.x = 0
			if _state_timer <= 0.0:
				_do_summon()
		"telegraph_swipe":
			velocity.x = 0
			if _state_timer <= 0.0:
				_do_swipe()
		"recover":
			velocity.x = 0
			if _state_timer <= 0.0:
				_state = "idle"

	if stagger_time_left > 0.0:
		stagger_time_left -= delta
		velocity.x = 0
	knockback_velocity = move_toward(knockback_velocity, 0.0, 600.0 * delta)
	velocity.x += knockback_velocity
	move_and_slide()

func _do_move() -> void:
	var dist: float = player.global_position.x - global_position.x
	var dir: int = int(sign(dist))
	if dir != 0:
		_facing = dir
	if abs(dist) < 160.0:
		velocity.x = -dir * move_speed
	elif abs(dist) > 260.0:
		velocity.x = dir * move_speed
	else:
		velocity.x = 0

func _pick_attack() -> void:
	var dist: float = abs(player.global_position.x - global_position.x)
	telegraph.visible = true
	if dist < 90.0:
		_state = "telegraph_swipe"
		_state_timer = 0.4
		telegraph.color = Color(1, 0.3, 0.1, 0.35)
	else:
		_state = "telegraph_summon"
		_state_timer = 0.6
		telegraph.color = Color(0.6, 0.2, 0.8, 0.35)

func _do_summon() -> void:
	telegraph.visible = false
	var minion_scene: PackedScene = load("res://scenes/Minion.tscn")
	var count := 2 if phase == 1 else 3
	for i in range(count):
		var minion := minion_scene.instantiate()
		get_parent().add_child(minion)
		var spread: float = (i - float(count - 1) / 2.0) * 40.0
		minion.global_position = global_position + Vector2(spread, -20.0)
	_state = "recover"
	_state_timer = 0.5
	_attack_cooldown = 3.0 if phase == 1 else 2.0

func _do_swipe() -> void:
	telegraph.visible = false
	swipe_area.monitoring = true
	_state = "recover"
	_state_timer = 0.4
	_attack_cooldown = 1.4 if phase == 1 else 1.0
	await get_tree().create_timer(0.15).timeout
	swipe_area.monitoring = false

func _on_swipe_body_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(swipe_damage, self)

func take_damage(amount: int, attacker: Node = null) -> void:
	hp = max(hp - amount, 0)
	hp_changed.emit(hp, max_hp)
	Juice.flash(sprite, Color(1, 1, 1), 0.08)
	if hp <= max_hp * 0.5 and phase == 1:
		phase = 2
		move_speed *= 1.2
		sprite.color = sprite.color.lightened(0.2)
		Juice.hitstop(0.08, 0.05)
	if hp <= 0:
		Juice.hitstop(0.12, 0.03)
		Juice.burst(get_parent(), global_position, sprite.color, 24)
		died.emit()
		queue_free()
