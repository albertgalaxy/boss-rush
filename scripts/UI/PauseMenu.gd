extends CanvasLayer

@onready var resume_button: Button = $Panel/VBoxContainer/ResumeButton
@onready var restart_button: Button = $Panel/VBoxContainer/RestartButton
@onready var controls_button: Button = $Panel/VBoxContainer/ControlsButton
@onready var menu_button: Button = $Panel/VBoxContainer/MenuButton
@onready var controls_menu: CanvasLayer = $ControlsMenu

func _ready() -> void:
	resume_button.pressed.connect(_on_resume)
	restart_button.pressed.connect(_on_restart)
	controls_button.pressed.connect(controls_menu.open)
	menu_button.pressed.connect(_on_menu)
	visible = false

func open() -> void:
	visible = true
	get_tree().paused = true
	resume_button.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_on_resume()
		get_viewport().set_input_as_handled()

func _on_resume() -> void:
	visible = false
	get_tree().paused = false

func _on_restart() -> void:
	GameManager.clear_run_progress()
	get_tree().paused = false
	GameManager.start_run()
	get_tree().reload_current_scene()

func _on_menu() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and is_instance_valid(player):
		GameManager.save_run_progress(player)
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/TrainingLobby.tscn")
