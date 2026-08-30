extends BossBase
class_name Boss

const ProjectileScene := preload("res://scenes/Projectile.tscn")

@export var move_speed := 90.0
@export var contact_damage := 12
@export var charge_speed := 420.0

const CHARGE_DURATION := 0.4
const TELEGRAPH_LEFT := -70.0
const TELEGRAPH_RIGHT := 70.0
const TELEGRAPH_TOP := -55.0
const TELEGRAPH_BOTTOM := 55.0

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var player: Node = null
var phase := 1
var _state := "idle"
var _state_timer := 0.0
var _facing := -1
var _attack_cooldown := 0.6

@onready var sprite: ColorRect = $Sprite
@onready var slam_area: Area2D = $SlamArea
@onready var telegraph: ColorRect = $Telegraph

func _ready() -> void:
	add_to_group("boss")
	hp = max_hp
	slam_area.monitoring = false
	slam_area.body_entered.connect(_on_slam_body_entered)
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
		"telegraph_volley":
			velocity.x = 0
			if _state_timer <= 0.0:
				_do_volley()
		"telegraph_charge":
			velocity.x = 0
			if _state_timer <= 0.0:
				_start_charge()
		"charging":
			velocity.x = _facing * charge_speed
			if _state_timer <= 0.0:
				_end_charge()
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
	if dist > 40.0:
		velocity.x = dir * move_speed
	else:
		velocity.x = 0

func _pick_attack() -> void:
	var choices := ["slam", "volley", "charge"]
	var choice: String = choices[randi() % choices.size()]
	telegraph.offset_left = TELEGRAPH_LEFT
	telegraph.offset_right = TELEGRAPH_RIGHT
	telegraph.offset_top = TELEGRAPH_TOP
	telegraph.offset_bottom = TELEGRAPH_BOTTOM
	match choice:
		"slam":
			_state = "telegraph_slam"
			_state_timer = 0.6
			telegraph.color = Color(1, 0.2, 0.2, 0.35)
		"volley":
			_state = "telegraph_volley"
			_state_timer = 0.5
			telegraph.color = Color(0.75, 0.25, 1.0, 0.35)
		"charge":
			_state = "telegraph_charge"
			_state_timer = 0.5
			_facing = int(sign(player.global_position.x - global_position.x))
			telegraph.color = Color(1, 0.7, 0.1, 0.35)
			var reach := charge_speed * CHARGE_DURATION
			if _facing >= 0:
				telegraph.offset_left = 0.0
				telegraph.offset_right = reach
			else:
				telegraph.offset_left = -reach
				telegraph.offset_right = 0.0
	telegraph.visible = true

func _do_slam() -> void:
	telegraph.visible = false
	slam_area.monitoring = true
	_state = "recover"
	_state_timer = 0.5
	_attack_cooldown = 1.4 if phase == 1 else 0.9
	await get_tree().create_timer(0.15).timeout
	slam_area.monitoring = false

func _do_volley() -> void:
	telegraph.visible = false
	var count := 3 if phase == 1 else 5
	var angle_step := 0.42
	for i in range(count):
		var proj := ProjectileScene.instantiate()
		get_parent().add_child(proj)
		proj.global_position = global_position
		var spread: float = (i - float(count - 1) / 2.0) * angle_step
		var dir := Vector2(_facing, 0).rotated(spread)
		proj.setup(dir, contact_damage, 0, self)
	_state = "recover"
	_state_timer = 0.6
	_attack_cooldown = 1.6 if phase == 1 else 1.0

func _start_charge() -> void:
	telegraph.visible = false
	slam_area.monitoring = true
	_state = "charging"
	_state_timer = CHARGE_DURATION

func _end_charge() -> void:
	slam_area.monitoring = false
	velocity.x = 0
	_state = "recover"
	_state_timer = 0.5
	_attack_cooldown = 1.5 if phase == 1 else 1.0

func _on_slam_body_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(contact_damage, self)

func take_damage(amount: int, attacker: Node = null) -> void:
	var reduced := int(amount * (1.0 - damage_reduction_pct))
	hp = max(hp - reduced, 0)
	hp_changed.emit(hp, max_hp)
	Juice.flash(sprite, Color(1, 1, 1), 0.08)
	if hp <= max_hp * 0.5 and phase == 1:
		phase = 2
		move_speed *= 1.3
		sprite.color = sprite.color.lightened(0.2)
		Juice.hitstop(0.08, 0.05)
	if hp <= 0:
		Juice.hitstop(0.12, 0.03)
		Juice.burst(get_parent(), global_position, sprite.color, 24)
		died.emit()
		queue_free()
