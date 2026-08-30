extends BossBase
class_name BossMelee

const ShockwaveScene := preload("res://scenes/Shockwave.tscn")

@export var move_speed := 110.0
@export var slam_damage := 16
@export var punch_damage := 12
@export var jump_velocity := -420.0

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var player: Node = null
var phase := 1
var _state := "idle"
var _state_timer := 0.0
var _facing := -1
var _attack_cooldown := 0.6
var _punch_count := 0

@onready var sprite: ColorRect = $Sprite
@onready var punch_area: Area2D = $PunchArea
@onready var telegraph: ColorRect = $Telegraph

func _ready() -> void:
	add_to_group("boss")
	hp = max_hp
	punch_area.monitoring = false
	punch_area.body_entered.connect(_on_punch_body_entered)
	telegraph.visible = false
	call_deferred("_find_player")

func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	if player == null or not is_instance_valid(player):
		velocity.x = 0
		move_and_slide()
		return

	_attack_cooldown = max(0.0, _attack_cooldown - delta)
	_state_timer -= delta

	match _state:
		"idle":
			_do_move()
			if _attack_cooldown <= 0.0:
				_pick_attack()
		"telegraph_slam":
			velocity.x = 0
			if _state_timer <= 0.0:
				_do_slam()
		"telegraph_punch":
			velocity.x = 0
			if _state_timer <= 0.0:
				_start_punch_combo()
		"punching":
			velocity.x = 0
			if _state_timer <= 0.0:
				_next_punch()
		"telegraph_jump":
			velocity.x = 0
			if _state_timer <= 0.0:
				_start_jump()
		"jumping":
			if _state_timer <= 0.0 and is_on_floor():
				_land_jump()
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
	var dir: int = int(sign(player.global_position.x - global_position.x))
	if dir != 0:
		_facing = dir
	var dist: float = abs(player.global_position.x - global_position.x)
	if dist > 50.0:
		velocity.x = dir * move_speed
	else:
		velocity.x = 0

func _pick_attack() -> void:
	var choices := ["slam", "punch", "jump"]
	var choice: String = choices[randi() % choices.size()]
	match choice:
		"slam":
			_state = "telegraph_slam"
			_state_timer = 0.7
			telegraph.color = Color(1, 0.3, 0.1, 0.35)
		"punch":
			_state = "telegraph_punch"
			_state_timer = 0.4
			telegraph.color = Color(1, 0.85, 0.2, 0.35)
		"jump":
			_state = "telegraph_jump"
			_state_timer = 0.4
			telegraph.color = Color(0.3, 0.7, 1.0, 0.35)
	telegraph.visible = true

func _do_slam() -> void:
	telegraph.visible = false
	for dir_sign in [-1, 1]:
		var wave := ShockwaveScene.instantiate()
		get_parent().add_child(wave)
		wave.global_position = global_position + Vector2(0, 15)
		wave.setup(Vector2(dir_sign, 0), slam_damage, self)
	_state = "recover"
	_state_timer = 0.6
	_attack_cooldown = 1.8 if phase == 1 else 1.2

func _start_punch_combo() -> void:
	telegraph.visible = false
	_punch_count = 0
	punch_area.position.x = 30.0 * _facing
	_do_punch()

func _do_punch() -> void:
	punch_area.monitoring = true
	_state = "punching"
	_state_timer = 0.18
	await get_tree().create_timer(0.1).timeout
	punch_area.monitoring = false

func _next_punch() -> void:
	_punch_count += 1
	var max_punches := 3 if phase == 1 else 4
	if _punch_count >= max_punches:
		_state = "recover"
		_state_timer = 0.5
		_attack_cooldown = 1.6 if phase == 1 else 1.1
	else:
		_do_punch()

func _start_jump() -> void:
	telegraph.visible = false
	velocity.y = jump_velocity
	if player:
		velocity.x = clampf(player.global_position.x - global_position.x, -300.0, 300.0) * 1.2
	_state = "jumping"
	_state_timer = 0.2

func _land_jump() -> void:
	velocity.x = 0
	for dir_sign in [-1, 1]:
		var wave := ShockwaveScene.instantiate()
		get_parent().add_child(wave)
		wave.global_position = global_position + Vector2(0, 15)
		wave.setup(Vector2(dir_sign, 0), slam_damage, self)
	Juice.hitstop(0.06, 0.05)
	_state = "recover"
	_state_timer = 0.6
	_attack_cooldown = 1.8 if phase == 1 else 1.2

func _on_punch_body_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(punch_damage, self)

func take_damage(amount: int, attacker: Node = null) -> void:
	var reduced := int(amount * (1.0 - damage_reduction_pct))
	hp = max(hp - reduced, 0)
	hp_changed.emit(hp, max_hp)
	Juice.flash(sprite, Color(1, 1, 1), 0.08)
	if hp <= max_hp * 0.5 and phase == 1:
		phase = 2
		move_speed *= 1.25
		sprite.color = sprite.color.lightened(0.2)
		Juice.hitstop(0.08, 0.05)
	if hp <= 0:
		Juice.hitstop(0.12, 0.03)
		Juice.burst(get_parent(), global_position, sprite.color, 24)
		died.emit()
		queue_free()
