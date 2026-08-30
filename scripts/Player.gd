extends CharacterBody2D
class_name Player

signal died
signal leveled_up
signal xp_changed(current_xp: int, xp_needed: int)
signal hp_changed(current_hp: int, max_hp_value: int)

const SPEED := 220.0
const JUMP_VELOCITY := -420.0
const BASE_ATTACK_DAMAGE := 10
const ATTACK_DURATION := 0.15
const FALL_DEATH_Y := 900.0
const MANA_SHIELD_REDUCTION := 0.5
const MANA_SHIELD_DURATION := 0.3
const MAX_DAMAGE_REDUCTION := 0.75
const CHARGE_MIN_TIME := 0.25
const CHARGE_MAX_TIME := 0.9
const QUICK_MOVE_COOLDOWN := 0.35
const RIPOSTE_WINDOW := 0.6
const ProjectileScene := preload("res://scenes/Projectile.tscn")

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

var class_id: String = "warrior"
var is_ranged := false

var max_hp := 100
var hp := 100
var level := 1
var xp := 0
var xp_to_next := 20

var attack_damage := BASE_ATTACK_DAMAGE
var attack_cooldown := 0.35
var move_speed_mult := 1.0
var can_dash := false
var extra_jump := false
var lifesteal := 0.0
var crit_chance := 0.0
var poison_damage := 0
var thorns_pct := 0.0
var berserk := false
var cleave := false
var multishot := false
var pierce := 0
var mana_shield := false
var shadow_step := false
var damage_reduction_pct := 0.0
var second_wind_available := false
var crit_damage_mult := 2.0
var crit_lifesteal_pct := 0.0
var overload := false
var resonance := false
var double_strike_chance := 0.0
var assassinate_bonus := 0.0
var charged_damage_bonus_mult := 1.0
var knockback_mult := 1.0
var vengeance := false

var _cast_count := 0

var acquired_abilities: Array[String] = []

var jumps_left := 1
var invincible := false
var _attack_timer := 0.0
var _attack_cooldown_timer := 0.0
var _facing := 1
var _dashing := false
var _dash_timer := 0.0
var _dash_cooldown_timer := 0.0
var _invincible_timer := 0.0
var _mana_shield_timer := 0.0
var _charging := false
var _charge_time := 0.0
var _charged_attack_active := false
var _charged_damage := 0
var _charged_fraction := 0.0
var _suppress_screen_flash := false
var _lunge_velocity := 0.0
var _quick_cooldown_timer := 0.0
var _time_since_damaged := 999.0

@onready var attack_area: Area2D = $AttackArea
@onready var attack_shape: CollisionShape2D = $AttackArea/CollisionShape2D
@onready var sprite: ColorRect = $Sprite
@onready var camera: Camera2D = $Camera2D
@onready var mana_shield_visual: Node2D = $ManaShieldVisual
@onready var charge_visual: Node2D = $ChargeVisual
@onready var swing_visual: Node2D = $SwingVisual
@onready var cooldown_visual: Node2D = $CooldownVisual

func _ready() -> void:
	add_to_group("player")
	class_id = GameManager.selected_class
	_apply_class_base()
	attack_area.monitoring = false
	attack_area.body_entered.connect(_on_attack_area_body_entered)
	hp_changed.emit(hp, max_hp)

func _apply_class_base() -> void:
	var stats: Dictionary = GameManager.class_stats.get(class_id, {})
	max_hp = stats.get("max_hp", 100)
	hp = max_hp
	attack_damage = stats.get("attack_damage", BASE_ATTACK_DAMAGE)
	attack_cooldown = stats.get("attack_cooldown", 0.35)
	move_speed_mult = stats.get("speed_mult", 1.0)
	is_ranged = stats.get("ranged", false)
	crit_chance = stats.get("crit_chance", 0.0)
	pierce = stats.get("pierce", 0)
	if sprite:
		sprite.color = stats.get("color", Color.WHITE)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		jumps_left = 2 if extra_jump else 1

	_handle_movement()
	_handle_jump()
	_tick_timers(delta)
	move_and_slide()

	if global_position.y > FALL_DEATH_Y and hp > 0:
		hp = 0
		hp_changed.emit(hp, max_hp)
		died.emit()

func _handle_movement() -> void:
	if _dashing:
		return
	var direction := 0.0
	if Input.is_action_pressed("move_left"):
		direction -= 1.0
	if Input.is_action_pressed("move_right"):
		direction += 1.0

	if direction != 0.0:
		_facing = 1 if direction > 0 else -1
		attack_area.position.x = 24.0 * _facing

	velocity.x = direction * SPEED * move_speed_mult + _lunge_velocity

func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump") and jumps_left > 0:
		velocity.y = JUMP_VELOCITY
		jumps_left -= 1

func _tick_timers(delta: float) -> void:
	if _attack_cooldown_timer > 0.0:
		_attack_cooldown_timer -= delta
	if _attack_cooldown_timer > 0.0 and attack_cooldown > 0.0:
		cooldown_visual.visible = true
		cooldown_visual.fraction = 1.0 - clampf(_attack_cooldown_timer / attack_cooldown, 0.0, 1.0)
	else:
		cooldown_visual.visible = false
	if _attack_timer > 0.0:
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			attack_area.monitoring = false
			if _charged_attack_active:
				_charged_attack_active = false
				_suppress_screen_flash = false
				attack_shape.scale = Vector2(1.6, 2.0) if cleave else Vector2.ONE
	if _charging:
		_charge_time = min(_charge_time + delta, CHARGE_MAX_TIME)
		charge_visual.fraction = clampf((_charge_time - CHARGE_MIN_TIME) / (CHARGE_MAX_TIME - CHARGE_MIN_TIME), 0.0, 1.0)
	_lunge_velocity = move_toward(_lunge_velocity, 0.0, 900.0 * delta)
	if _dash_cooldown_timer > 0.0:
		_dash_cooldown_timer -= delta
	if _dashing:
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			_dashing = false
	if _invincible_timer > 0.0:
		_invincible_timer -= delta
		if _invincible_timer <= 0.0:
			invincible = false
	if _mana_shield_timer > 0.0:
		_mana_shield_timer -= delta
	mana_shield_visual.visible = _mana_shield_timer > 0.0
	if _quick_cooldown_timer > 0.0:
		_quick_cooldown_timer -= delta
	_time_since_damaged += delta

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack"):
		_start_charge()
	elif event.is_action_released("attack"):
		_release_charge()
	elif event.is_action_pressed("dash"):
		_try_dash()
	elif event.is_action_pressed("quick_move"):
		_try_quick_move()

func _try_quick_move() -> void:
	if _quick_cooldown_timer > 0.0:
		return
	match class_id:
		"warrior":
			_try_riposte()
		"mage":
			_cast_flicker_bolt()
		"rogue":
			_do_flicker_strike()

func _try_riposte() -> void:
	if _time_since_damaged > RIPOSTE_WINDOW:
		return
	_quick_cooldown_timer = QUICK_MOVE_COOLDOWN
	_charged_damage = int(attack_damage * 1.5)
	_charged_attack_active = true
	_charged_fraction = 0.3
	attack_shape.scale = Vector2(1.6, 2.0) if cleave else Vector2.ONE
	_attack_timer = ATTACK_DURATION
	attack_area.monitoring = true
	Juice.flash(sprite, Color(0.3, 1.0, 0.5), 0.1)
	swing_visual.play(ATTACK_DURATION, _facing, Color(0.3, 1.0, 0.5, 0.7), 42.0)

func _cast_flicker_bolt() -> void:
	_quick_cooldown_timer = QUICK_MOVE_COOLDOWN
	var dmg := int(attack_damage * 0.4)
	var proj := ProjectileScene.instantiate()
	get_parent().add_child(proj)
	proj.global_position = global_position
	var dir := Vector2(_facing, 0)
	proj.setup(dir, dmg, pierce, self)
	proj.scale = Vector2.ONE * 0.7

func _do_flicker_strike() -> void:
	_quick_cooldown_timer = QUICK_MOVE_COOLDOWN
	_charged_damage = int(attack_damage * 0.5)
	_charged_attack_active = true
	_charged_fraction = 0.0
	_suppress_screen_flash = true
	attack_shape.scale = Vector2(1.6, 2.0) if cleave else Vector2.ONE
	_attack_timer = ATTACK_DURATION * 0.6
	attack_area.monitoring = true
	swing_visual.play(ATTACK_DURATION * 0.6, _facing, Color(1, 0.4, 0.8, 0.7), 32.0)

func _start_charge() -> void:
	if _attack_cooldown_timer > 0.0:
		return
	_charging = true
	_charge_time = 0.0
	charge_visual.fraction = 0.0
	charge_visual.visible = true

func _release_charge() -> void:
	if not _charging:
		return
	_charging = false
	charge_visual.visible = false
	var held_time := _charge_time
	_charge_time = 0.0
	if held_time < CHARGE_MIN_TIME:
		_try_attack()
		return
	var fraction := clampf((held_time - CHARGE_MIN_TIME) / (CHARGE_MAX_TIME - CHARGE_MIN_TIME), 0.0, 1.0)
	_perform_charged_attack(fraction)

func _try_attack() -> void:
	if _attack_cooldown_timer > 0.0:
		return
	_attack_cooldown_timer = attack_cooldown
	if is_ranged:
		_cast_projectile()
		if mana_shield:
			_mana_shield_timer = MANA_SHIELD_DURATION
	else:
		_attack_timer = ATTACK_DURATION
		attack_area.monitoring = true
		swing_visual.play(ATTACK_DURATION, _facing, Color(1, 0.85, 0.2, 0.7), 42.0)

func _perform_charged_attack(fraction: float) -> void:
	_attack_cooldown_timer = attack_cooldown * (1.0 + fraction)
	if is_ranged:
		_cast_charged_bolt(fraction)
	else:
		_do_charged_melee(fraction)

func _cast_charged_bolt(fraction: float) -> void:
	var dmg := int(attack_damage * (1.0 + fraction * 2.0))
	var proj := ProjectileScene.instantiate()
	get_parent().add_child(proj)
	proj.global_position = global_position
	var dir := Vector2(_facing, 0)
	var effective_pierce := 99 if fraction >= 0.99 else pierce
	proj.setup(dir, dmg, effective_pierce, self)
	proj.scale = Vector2.ONE * (1.0 + fraction * 1.2)
	proj.charged_fraction = fraction
	if mana_shield:
		_mana_shield_timer = MANA_SHIELD_DURATION

func _do_charged_melee(fraction: float) -> void:
	var dmg_mult := 1.0 + fraction * (2.5 if class_id == "rogue" else 1.5)
	_charged_damage = int(attack_damage * dmg_mult * charged_damage_bonus_mult)
	_charged_attack_active = true
	_charged_fraction = fraction
	var scale_mult := 1.3 + fraction * 0.5
	attack_shape.scale = (Vector2(1.6, 2.0) if cleave else Vector2.ONE) * scale_mult
	_attack_timer = ATTACK_DURATION * 1.5
	attack_area.monitoring = true
	var swing_color := Color(1, 0.2, 0.5, 0.8) if class_id == "rogue" else Color(1, 0.6, 0.15, 0.8)
	swing_visual.play(ATTACK_DURATION * 1.5, _facing, swing_color, 42.0 * scale_mult)
	if class_id == "rogue":
		_lunge_velocity = _facing * SPEED * 2.2

func _cast_projectile() -> void:
	var angles := [0.0]
	if multishot:
		angles = [-0.4, -0.2, 0.0, 0.2, 0.4] if resonance else [-0.25, 0.0, 0.25]
	_cast_count += 1
	var dmg := attack_damage
	var is_overload_shot := overload and _cast_count % 3 == 0
	if is_overload_shot:
		dmg = int(dmg * 2.0)
	for a in angles:
		var proj := ProjectileScene.instantiate()
		get_parent().add_child(proj)
		proj.global_position = global_position
		var dir := Vector2(_facing, 0).rotated(a)
		proj.setup(dir, dmg, pierce, self)
		if is_overload_shot:
			proj.scale = Vector2(1.4, 1.4)

func _try_dash() -> void:
	if not can_dash or _dash_cooldown_timer > 0.0:
		return
	_dashing = true
	_dash_timer = 0.15
	_dash_cooldown_timer = 1.2
	velocity.x = _facing * SPEED * 3.0
	if shadow_step:
		invincible = true
		_invincible_timer = 0.2

func _on_attack_area_body_entered(body: Node) -> void:
	if _charged_attack_active:
		_deal_hit(body, _charged_damage)
		if class_id == "warrior" and body.has_method("apply_knockback"):
			body.apply_knockback(_facing * 220.0 * knockback_mult)
		var f := _charged_fraction
		Juice.shake(camera, 4.0 + f * 6.0, 0.12 + f * 0.1)
		Juice.hitstop(0.04 + f * 0.05, 0.05)
		if not _suppress_screen_flash:
			Juice.screen_flash(Color(1, 0.6, 0.15, 0.15 + f * 0.15), 0.12)
	else:
		_deal_hit(body)

func resolve_ranged_hit(body: Node, base_dmg: int, charged_fraction: float = -1.0) -> void:
	_deal_hit(body, base_dmg)
	if charged_fraction >= 0.0 and is_instance_valid(body):
		Juice.shake(camera, 3.0 + charged_fraction * 5.0, 0.1 + charged_fraction * 0.1)
		Juice.hitstop(0.03 + charged_fraction * 0.05, 0.05)
		Juice.screen_flash(Color(0.4, 0.7, 1.0, 0.15 + charged_fraction * 0.15), 0.12)
		Juice.burst(get_parent(), body.global_position, Color(0.4, 0.7, 1.0), int(10 + charged_fraction * 14))

func _deal_hit(body: Node, override_dmg: int = -1) -> void:
	if not body.has_method("take_damage"):
		return
	var dmg := override_dmg if override_dmg >= 0 else attack_damage
	if berserk and hp <= max_hp * 0.3:
		dmg = int(dmg * 1.5)
	if assassinate_bonus > 0.0 and "hp" in body and "max_hp" in body and body.max_hp > 0 and float(body.hp) / float(body.max_hp) > 0.8:
		dmg = int(dmg * (1.0 + assassinate_bonus))
	var is_crit := randf() < crit_chance
	if is_crit:
		dmg = int(dmg * crit_damage_mult)
	body.take_damage(dmg, self)
	var total_dmg_dealt := dmg
	if body.has_method("apply_knockback"):
		body.apply_knockback(_facing * 60.0)
	if body.has_method("apply_stagger"):
		body.apply_stagger()
	Juice.damage_popup(get_parent(), body.global_position, dmg, is_crit)
	if is_crit:
		Juice.shake(camera, 8.0, 0.18)
		Juice.hitstop(0.06, 0.04)
		Juice.screen_flash(Color(1, 0.85, 0.2, 0.25), 0.12)
		Juice.burst(get_parent(), body.global_position, Color(1, 0.85, 0.2), 16)
		Juice.crit_popup(get_parent(), body.global_position)
	else:
		Juice.shake(camera, 2.5, 0.08)
	if poison_damage > 0 and body.has_method("apply_poison"):
		body.apply_poison(poison_damage)
	if lifesteal > 0.0:
		heal(int(dmg * lifesteal))
	if is_crit and crit_lifesteal_pct > 0.0:
		heal(int(dmg * crit_lifesteal_pct))
	if double_strike_chance > 0.0 and randf() < double_strike_chance and is_instance_valid(body):
		await get_tree().create_timer(0.12, true, false, true).timeout
		if is_instance_valid(body):
			body.take_damage(dmg, self)
			if body.has_method("apply_knockback"):
				body.apply_knockback(_facing * 100.0)
			if body.has_method("apply_stagger"):
				body.apply_stagger()
			total_dmg_dealt += dmg
			Juice.damage_popup(get_parent(), body.global_position, dmg, false)
			Juice.shake(camera, 3.5, 0.08)
			if not is_ranged:
				swing_visual.play(0.12, _facing, Color(1, 1, 1, 0.75), 40.0)
	if not ("grants_xp" in body) or body.grants_xp:
		var xp_gain := maxi(1, int(total_dmg_dealt / 5.0))
		if GameManager.endless_depth > 0:
			xp_gain = maxi(1, int(xp_gain * 0.5))
		gain_xp(xp_gain)

func take_damage(amount: int, attacker: Node = null) -> void:
	if invincible:
		return
	_time_since_damaged = 0.0
	var total_reduction := damage_reduction_pct
	if _mana_shield_timer > 0.0:
		total_reduction += MANA_SHIELD_REDUCTION
	total_reduction = clamp(total_reduction, 0.0, MAX_DAMAGE_REDUCTION)
	var reduced_amount := int(amount * (1.0 - total_reduction))
	if hp - reduced_amount <= 0 and second_wind_available:
		second_wind_available = false
		hp = 1
		hp_changed.emit(hp, max_hp)
		Juice.flash(sprite, Color(1, 0.9, 0.3), 0.25)
		Juice.hitstop(0.15, 0.05)
		return
	hp = max(hp - reduced_amount, 0)
	hp_changed.emit(hp, max_hp)
	if _mana_shield_timer > 0.0:
		Juice.flash(sprite, Color(0.4, 0.7, 1.0), 0.1)
		Juice.shake(camera, 2.0, 0.1)
	else:
		Juice.flash(sprite, Color(1, 0.3, 0.3), 0.1)
		Juice.shake(camera, 5.0, 0.15)
	if thorns_pct > 0.0 and attacker != null and attacker.has_method("take_damage"):
		var reflected := int(amount * thorns_pct)
		attacker.take_damage(reflected)
		if vengeance:
			heal(reflected)
	if hp <= 0:
		Juice.hitstop(0.15, 0.03)
		Juice.burst(get_parent(), global_position, sprite.color, 20)
		died.emit()

func heal(amount: int) -> void:
	hp = min(hp + amount, max_hp)
	hp_changed.emit(hp, max_hp)

func gain_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		xp_to_next = int(xp_to_next * 1.4)
		leveled_up.emit()
	xp_changed.emit(xp, xp_to_next)

func apply_ability(id: String) -> void:
	acquired_abilities.append(id)
	match id:
		"damage_up":
			attack_damage = int(attack_damage * 1.35)
		"max_hp_up":
			max_hp += 30
			hp += 30
			hp_changed.emit(hp, max_hp)
		"speed_up":
			move_speed_mult *= 1.2
		"dash":
			can_dash = true
		"double_jump":
			extra_jump = true
		"lifesteal":
			lifesteal += 0.15
		"attack_speed":
			attack_cooldown = max(0.1, attack_cooldown * 0.75)
		"cleave":
			cleave = true
			attack_shape.scale = Vector2(1.6, 2.0)
		"thorns":
			thorns_pct += 0.25
		"berserk":
			berserk = true
		"multishot":
			multishot = true
		"pierce":
			pierce += 3
		"mana_shield":
			mana_shield = true
		"crit_up":
			crit_chance = min(0.8, crit_chance + 0.2)
		"poison_blade":
			poison_damage = max(2, int(attack_damage * 0.2))
		"shadow_step":
			shadow_step = true
		"juggernaut":
			max_hp = int(max_hp * 1.25)
			hp = int(hp * 1.25)
			hp_changed.emit(hp, max_hp)
			move_speed_mult *= 0.9
			attack_damage = int(attack_damage * 1.15)
		"unbreakable":
			second_wind_available = true
		"arcane_focus":
			attack_damage = int(attack_damage * 1.4)
			attack_cooldown *= 1.15
		"ward":
			damage_reduction_pct = min(0.6, damage_reduction_pct + 0.3)
		"momentum":
			move_speed_mult *= 1.15
			attack_cooldown = max(0.1, attack_cooldown * 0.85)
		"opportunist":
			crit_damage_mult += 0.5
			crit_lifesteal_pct += 0.05
		"overload":
			overload = true
		"resonance":
			resonance = true
		"double_strike":
			double_strike_chance += 0.25
		"assassinate":
			assassinate_bonus += 0.5
		"colossal_blow":
			charged_damage_bonus_mult += 0.5
			knockback_mult += 0.75
		"vengeance":
			vengeance = true
