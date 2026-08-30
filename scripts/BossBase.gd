extends CharacterBody2D
class_name BossBase

signal died
signal hp_changed(current_hp: int, max_hp_value: int)

@export var max_hp := 300
var hp := 300
var knockback_velocity := 0.0
var grants_xp := true

const POISON_TICK_INTERVAL := 0.5
const POISON_DURATION := 2.0
const STAGGER_DURATION := 0.08
const FALL_RESET_Y := 900.0

var poison_damage := 0
var poison_time_left := 0.0
var _poison_tick_timer := 0.0
var stagger_time_left := 0.0
var spawn_position := Vector2.ZERO

# Endless-mode buffs, set by Arena's endless scaling; 0 = no bonus.
var damage_reduction_pct := 0.0
var knockback_resist := 0.0

func apply_knockback(amount: float) -> void:
	knockback_velocity += amount * (1.0 - knockback_resist)

func apply_stagger() -> void:
	stagger_time_left = STAGGER_DURATION * (1.0 - knockback_resist)

func take_damage(_amount: int, _attacker: Node = null) -> void:
	pass

func apply_poison(damage_per_tick: int) -> void:
	poison_damage = damage_per_tick
	poison_time_left = POISON_DURATION
	_poison_tick_timer = POISON_TICK_INTERVAL

func _process(delta: float) -> void:
	if global_position.y > FALL_RESET_Y:
		global_position = spawn_position
		velocity = Vector2.ZERO
		knockback_velocity = 0.0
	if poison_time_left > 0.0:
		poison_time_left -= delta
		_poison_tick_timer -= delta
		if _poison_tick_timer <= 0.0:
			_poison_tick_timer = POISON_TICK_INTERVAL
			take_damage(poison_damage, null)
			Juice.poison_tick_popup(get_parent(), global_position, poison_damage)
			Juice.burst(get_parent(), global_position, Color(0.4, 0.9, 0.3), 5)
