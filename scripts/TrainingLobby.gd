extends Node2D

const PlayerScene := preload("res://scenes/Player.tscn")

@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var dummy: BossBase = $TrainingDummy
@onready var hud: CanvasLayer = $HUD
@onready var level_up_menu: CanvasLayer = $LevelUpMenu
@onready var warrior_btn: Button = $UI/Root/ClassRow/WarriorButton
@onready var mage_btn: Button = $UI/Root/ClassRow/MageButton
@onready var rogue_btn: Button = $UI/Root/ClassRow/RogueButton
@onready var start_btn: Button = $UI/Root/StartButton
@onready var best_run_label: Label = $UI/Root/BestRunLabel

var player: Player

func _ready() -> void:
	warrior_btn.pressed.connect(_swap_class.bind("warrior"))
	mage_btn.pressed.connect(_swap_class.bind("mage"))
	rogue_btn.pressed.connect(_swap_class.bind("rogue"))
	start_btn.pressed.connect(_on_start_pressed)
	dummy.hp_changed.connect(hud.set_boss_hp)
	hud.boss_progress_label.text = "Training Dummy"
	level_up_menu.visible = false
	_refresh_best_run_label()
	_spawn_player(GameManager.selected_class)

func _refresh_best_run_label() -> void:
	var data := GameManager.save_data
	if data.best_bosses_defeated <= 0 and data.best_level <= 0:
		best_run_label.text = "No runs recorded yet"
		return
	var text := "Best run — Level %d, %d bosses defeated" % [data.best_level, data.best_bosses_defeated]
	if data.best_endless_depth > 0:
		text += ", Endless depth %d" % data.best_endless_depth
	best_run_label.text = text

func _swap_class(class_id: String) -> void:
	_spawn_player(class_id)

func _spawn_player(class_id: String) -> void:
	GameManager.selected_class = class_id
	if is_instance_valid(player):
		player.queue_free()
	player = PlayerScene.instantiate()
	add_child(player)
	player.global_position = player_spawn.global_position
	player.hp_changed.connect(hud.set_player_hp)
	player.xp_changed.connect(hud.set_player_xp)
	player.leveled_up.connect(_on_player_leveled_up)
	player.died.connect(_on_player_died)
	var class_def: Dictionary = GameManager.class_stats.get(class_id, {})
	hud.set_class_name(class_def.get("name", "Player"))
	hud.set_level(player.level)
	hud.set_player_hp(player.hp, player.max_hp)
	hud.set_player_xp(player.xp, player.xp_to_next)
	hud.set_abilities(player.acquired_abilities, GameManager.get_ability_pool())
	hud.set_boss_hp(dummy.hp, dummy.max_hp)

func _on_player_leveled_up() -> void:
	hud.set_level(player.level)
	var choices := GameManager.get_random_choices(player, 3)
	if choices.is_empty():
		return
	get_tree().paused = true
	level_up_menu.show_choices(choices, func(id: String) -> void:
		player.apply_ability(id)
		hud.set_abilities(player.acquired_abilities, GameManager.get_ability_pool())
		get_tree().paused = false
	)

func _on_player_died() -> void:
	_spawn_player(GameManager.selected_class)

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/BossSelect.tscn")
