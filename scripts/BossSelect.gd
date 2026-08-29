extends Control

@onready var brute_btn: Button = $VBoxContainer/BruteButton
@onready var warhammer_btn: Button = $VBoxContainer/WarhammerButton
@onready var swarm_btn: Button = $VBoxContainer/SwarmButton
@onready var back_btn: Button = $BackButton

func _ready() -> void:
	brute_btn.pressed.connect(_select.bind("brute"))
	warhammer_btn.pressed.connect(_select.bind("warhammer"))
	swarm_btn.pressed.connect(_select.bind("swarm"))
	back_btn.pressed.connect(_on_back)
	brute_btn.grab_focus()

func _select(boss_id: String) -> void:
	GameManager.selected_boss = boss_id
	GameManager.start_run()
	get_tree().change_scene_to_file("res://scenes/Arena.tscn")

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/TrainingLobby.tscn")
