extends CanvasLayer

@onready var button_container: HBoxContainer = $Panel/VBoxContainer/Choices

var _callback: Callable

func show_choices(choices: Array, callback: Callable) -> void:
	_callback = callback
	for child in button_container.get_children():
		child.queue_free()
	for choice in choices:
		var id: String = choice["id"]
		var def: Dictionary = choice["def"]
		var btn := Button.new()
		btn.text = "%s\n%s" % [def.get("name", id), def.get("desc", "")]
		btn.custom_minimum_size = Vector2(220, 90)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD
		btn.process_mode = Node.PROCESS_MODE_ALWAYS
		btn.pressed.connect(_on_choice_pressed.bind(id))
		button_container.add_child(btn)
	visible = true

func _on_choice_pressed(id: String) -> void:
	visible = false
	var cb := _callback
	_callback = Callable()
	cb.call(id)
