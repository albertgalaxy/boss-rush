extends CanvasLayer

const ACTION_LABELS := {
	"move_left": "Move Left",
	"move_right": "Move Right",
	"jump": "Jump",
	"dash": "Dash",
	"attack": "Attack",
	"quick_move": "Riposte / Quick Move",
}

@onready var action_list: VBoxContainer = $Panel/VBoxContainer/ActionList
@onready var reset_button: Button = $Panel/VBoxContainer/ButtonRow/ResetButton
@onready var back_button: Button = $Panel/VBoxContainer/ButtonRow/BackButton

var action_buttons := {}
var listening_for_action: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	reset_button.pressed.connect(_on_reset_pressed)
	back_button.pressed.connect(_on_back_pressed)
	_build_rows()

func open() -> void:
	listening_for_action = ""
	_refresh_all_labels()
	visible = true

func _build_rows() -> void:
	for child in action_list.get_children():
		child.queue_free()
	action_buttons.clear()
	for action in GameManager.REBINDABLE_ACTIONS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var label := Label.new()
		label.text = ACTION_LABELS.get(action, action)
		label.custom_minimum_size = Vector2(170, 0)
		row.add_child(label)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(150, 0)
		btn.text = _binding_text(action)
		btn.pressed.connect(_on_rebind_pressed.bind(action))
		row.add_child(btn)
		action_buttons[action] = btn
		action_list.add_child(row)

func _binding_text(action: String) -> String:
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return "Unbound"
	return events[0].as_text().trim_suffix(" (Physical)")

func _refresh_all_labels() -> void:
	for action in action_buttons.keys():
		action_buttons[action].text = _binding_text(action)

func _on_rebind_pressed(action: String) -> void:
	if listening_for_action != "" and action_buttons.has(listening_for_action):
		action_buttons[listening_for_action].text = _binding_text(listening_for_action)
	listening_for_action = action
	action_buttons[action].text = "Press a key or click..."

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if listening_for_action == "":
		if event.is_action_pressed("ui_cancel"):
			_on_back_pressed()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			action_buttons[listening_for_action].text = _binding_text(listening_for_action)
			listening_for_action = ""
		else:
			_apply_binding(listening_for_action, event)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		_apply_binding(listening_for_action, event)
		get_viewport().set_input_as_handled()

func _apply_binding(action: String, event: InputEvent) -> void:
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event.duplicate())
	action_buttons[action].text = _binding_text(action)
	listening_for_action = ""
	GameManager.save_keybinds()

func _on_reset_pressed() -> void:
	for action in GameManager.REBINDABLE_ACTIONS:
		InputMap.action_erase_events(action)
		for e in GameManager.default_keybind_events[action]:
			InputMap.action_add_event(action, e)
	listening_for_action = ""
	_refresh_all_labels()
	GameManager.save_keybinds()

func _on_back_pressed() -> void:
	listening_for_action = ""
	visible = false
