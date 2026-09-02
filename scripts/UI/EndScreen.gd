extends CanvasLayer

@onready var label: Label = $Panel/VBoxContainer/ResultLabel
@onready var stats_label: Label = $Panel/VBoxContainer/StatsLabel
@onready var continue_button: Button = $Panel/VBoxContainer/ContinueButton
@onready var restart_button: Button = $Panel/VBoxContainer/RestartButton
@onready var menu_button: Button = $Panel/VBoxContainer/MenuButton

var _continue_callback: Callable

func _ready() -> void:
	continue_button.pressed.connect(_on_continue)
	restart_button.pressed.connect(_on_restart)
	menu_button.pressed.connect(_on_menu)

func show_result(won: bool, level: int = 1, bosses_beaten: int = 0, bosses_total: int = 0, ability_ids: Array = [], continue_callback: Callable = Callable()) -> void:
	GameManager.record_run_result(bosses_beaten, level, GameManager.endless_depth)
	if not won:
		# The run is over the instant death is registered — don't leave a
		# resumable checkpoint lying around just because the player hasn't
		# clicked through this screen yet (e.g. if they close the game here).
		GameManager.clear_run_progress()
	label.text = "Victory!" if won else "You Died"
	var pool := GameManager.get_ability_pool()
	var names: Array = []
	for id in ability_ids:
		names.append(pool.get(id, {}).get("name", id))
	var names_text := ", ".join(names) if names.size() > 0 else "None"
	var depth_text := ""
	if GameManager.endless_depth > 0:
		depth_text = "\nEndless depth reached: %d" % GameManager.endless_depth
	stats_label.text = "Level %d — Bosses defeated: %d/%d%s\nAbilities: %s" % [level, bosses_beaten, bosses_total, depth_text, names_text]
	_continue_callback = continue_callback
	continue_button.visible = continue_callback.is_valid()
	visible = true

func _on_continue() -> void:
	visible = false
	get_tree().paused = false
	var cb := _continue_callback
	_continue_callback = Callable()
	if cb.is_valid():
		cb.call()

func _on_restart() -> void:
	GameManager.clear_run_progress()
	get_tree().paused = false
	GameManager.start_run()
	get_tree().reload_current_scene()

func _on_menu() -> void:
	GameManager.clear_run_progress()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/TrainingLobby.tscn")
