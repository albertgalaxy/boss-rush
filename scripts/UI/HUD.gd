extends CanvasLayer

@onready var player_hp_bar: ProgressBar = $Root/PlayerHP
@onready var player_xp_bar: ProgressBar = $Root/PlayerXP
@onready var boss_hp_bar: ProgressBar = $Root/BossHP
@onready var boss_progress_label: Label = $Root/BossProgressLabel
@onready var level_label: Label = $Root/LevelLabel
@onready var ability_row: HBoxContainer = $Root/AbilityRow
@onready var ability_name_label: Label = $Root/AbilityNameLabel

var _class_name_text := "Player"

func set_class_name(text: String) -> void:
	_class_name_text = text
	_refresh_label(1)

func set_level(lvl: int) -> void:
	_refresh_label(lvl)

func _refresh_label(lvl: int) -> void:
	level_label.text = "%s — Lv.%d" % [_class_name_text, lvl]

func set_player_hp(current: int, max_value: int) -> void:
	player_hp_bar.max_value = max_value
	player_hp_bar.value = current

func set_player_xp(current: int, needed: int) -> void:
	player_xp_bar.max_value = needed
	player_xp_bar.value = current

func set_boss_hp(current: int, max_value: int) -> void:
	boss_hp_bar.max_value = max_value
	boss_hp_bar.value = current

func set_boss_progress(current: int, total: int) -> void:
	boss_progress_label.text = "Boss %d/%d" % [current, total]

func set_abilities(ids: Array, pool: Dictionary) -> void:
	for child in ability_row.get_children():
		child.queue_free()
	ability_name_label.text = ""
	for id in ids:
		var def: Dictionary = pool.get(id, {})
		var ability_name: String = def.get("name", id)
		var icon := ColorRect.new()
		icon.custom_minimum_size = Vector2(22, 22)
		icon.color = _color_for_ability(id)
		icon.mouse_filter = Control.MOUSE_FILTER_STOP
		icon.tooltip_text = "%s\n%s" % [ability_name, def.get("desc", "")]
		icon.mouse_entered.connect(func() -> void: ability_name_label.text = ability_name)
		icon.mouse_exited.connect(func() -> void: ability_name_label.text = "")
		ability_row.add_child(icon)

func _color_for_ability(id: String) -> Color:
	var h: int = abs(hash(id)) % 360
	return Color.from_hsv(h / 360.0, 0.55, 0.85)
