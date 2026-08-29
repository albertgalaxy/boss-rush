extends BossBase
class_name TrainingDummy

const REGEN_DELAY := 1.5

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var _regen_timer := 0.0

@onready var sprite: ColorRect = $Sprite

func _ready() -> void:
	hp = max_hp
	grants_xp = false

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	if hp < max_hp:
		_regen_timer -= delta
		if _regen_timer <= 0.0:
			hp = max_hp
			hp_changed.emit(hp, max_hp)
			Juice.flash(sprite, Color(0.6, 0.9, 1.0), 0.2)
	velocity.x = 0
	move_and_slide()

func apply_knockback(_amount: float) -> void:
	pass

func take_damage(amount: int, _attacker: Node = null) -> void:
	hp = max(hp - amount, 1)
	hp_changed.emit(hp, max_hp)
	Juice.flash(sprite, Color(1, 1, 1), 0.08)
	_regen_timer = REGEN_DELAY
