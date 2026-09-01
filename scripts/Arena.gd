extends Node2D

const BOSS_SCENES := {
	"brute": preload("res://scenes/Boss.tscn"),
	"warhammer": preload("res://scenes/BossMelee.tscn"),
	"swarm": preload("res://scenes/BossSwarm.tscn"),
}

@onready var player: Player = $Player
@onready var boss_spawn: Marker2D = $BossSpawn
@onready var hud: CanvasLayer = $HUD
@onready var level_up_menu: CanvasLayer = $LevelUpMenu
@onready var end_screen: CanvasLayer = $EndScreen
@onready var pause_menu: CanvasLayer = $PauseMenu

var boss: BossBase

func _ready() -> void:
	if GameManager.boss_order.is_empty():
		GameManager.start_run()

	player.hp_changed.connect(hud.set_player_hp)
	player.xp_changed.connect(hud.set_player_xp)
	player.leveled_up.connect(_on_player_leveled_up)
	player.died.connect(_on_player_died)

	if GameManager.resume_pending:
		_restore_player_state()
		GameManager.resume_pending = false

	_spawn_boss()

	var class_def: Dictionary = GameManager.class_stats.get(GameManager.selected_class, {})
	hud.set_class_name(class_def.get("name", "Player"))
	hud.set_level(player.level)
	hud.set_player_hp(player.hp, player.max_hp)
	hud.set_player_xp(player.xp, player.xp_to_next)
	hud.set_abilities(player.acquired_abilities, GameManager.get_ability_pool())
	level_up_menu.visible = false
	end_screen.visible = false
	pause_menu.visible = false

func _restore_player_state() -> void:
	var data: Dictionary = GameManager.save_data.get("in_progress", {})
	for id in data.get("acquired_abilities", []):
		player.apply_ability(str(id))
	player.level = int(data.get("level", player.level))
	player.xp = int(data.get("xp", player.xp))
	player.xp_to_next = int(data.get("xp_to_next", player.xp_to_next))
	player.hp = clampi(int(data.get("hp", player.hp)), 1, player.max_hp)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not get_tree().paused:
		pause_menu.open()

func _spawn_boss() -> void:
	var boss_id: String = GameManager.boss_order[GameManager.boss_index]
	var scene: PackedScene = BOSS_SCENES.get(boss_id, BOSS_SCENES["brute"])
	boss = scene.instantiate()
	boss.name = "Boss"
	add_child(boss)
	boss.global_position = boss_spawn.global_position
	boss.spawn_position = boss_spawn.global_position
	if GameManager.endless_depth > 0:
		_apply_endless_scaling(boss, GameManager.endless_depth)
	boss.hp_changed.connect(hud.set_boss_hp)
	boss.died.connect(_on_boss_died)
	hud.set_boss_hp(boss.hp, boss.max_hp)
	if GameManager.endless_depth > 0:
		hud.boss_progress_label.text = "Endless Depth %d" % GameManager.endless_depth
	else:
		hud.set_boss_progress(GameManager.boss_index + 1, GameManager.boss_order.size())
	GameManager.save_run_progress(player)

func _apply_endless_scaling(b: BossBase, depth: int) -> void:
	var hp_mult := 1.0 + depth * 0.25
	var dmg_mult := 1.0 + depth * 0.15
	var speed_mult := 1.0 + depth * 0.08
	b.max_hp = int(b.max_hp * hp_mult)
	b.hp = b.max_hp
	if "move_speed" in b:
		b.move_speed *= speed_mult
	if "contact_damage" in b:
		b.contact_damage = int(b.contact_damage * dmg_mult)
	if "swipe_damage" in b:
		b.swipe_damage = int(b.swipe_damage * dmg_mult)
	if "slam_damage" in b:
		b.slam_damage = int(b.slam_damage * dmg_mult)
	if "punch_damage" in b:
		b.punch_damage = int(b.punch_damage * dmg_mult)
	b.damage_reduction_pct = min(0.5, depth * 0.08)
	b.knockback_resist = min(0.85, depth * 0.15)

func _on_player_leveled_up() -> void:
	hud.set_level(player.level)
	if end_screen.visible:
		# The run just ended in this same hit (boss or player death) — don't
		# open a competing modal on top of it, the level is already recorded.
		return
	var choices := GameManager.get_random_choices(player, 3)
	if choices.is_empty():
		return
	get_tree().paused = true
	level_up_menu.show_choices(choices, func(id: String) -> void:
		player.apply_ability(id)
		hud.set_abilities(player.acquired_abilities, GameManager.get_ability_pool())
		get_tree().paused = false
		GameManager.save_run_progress(player)
	)

func _on_player_died() -> void:
	level_up_menu.visible = false
	get_tree().paused = true
	end_screen.show_result(false, player.level, GameManager.boss_index, GameManager.boss_order.size(), player.acquired_abilities)

func _on_boss_died() -> void:
	level_up_menu.visible = false
	GameManager.boss_index += 1
	if GameManager.boss_index < GameManager.boss_order.size():
		await get_tree().create_timer(1.2).timeout
		_spawn_boss()
	else:
		get_tree().paused = true
		end_screen.show_result(true, player.level, GameManager.boss_index, GameManager.boss_order.size(), player.acquired_abilities, _continue_to_endless)

func _continue_to_endless() -> void:
	GameManager.endless_depth += 1
	GameManager.boss_order.append(GameManager.boss_ids[randi() % GameManager.boss_ids.size()])
	_spawn_boss()
