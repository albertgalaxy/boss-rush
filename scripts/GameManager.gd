extends Node

const SAVE_PATH := "user://save_data.json"

var selected_class: String = "warrior"
var selected_boss: String = "brute"

var boss_ids: Array[String] = ["brute", "warhammer", "swarm"]
var boss_display_names := {
	"brute": "The Brute",
	"warhammer": "Warhammer",
	"swarm": "The Swarmcaller",
}
var boss_order: Array[String] = []
var boss_index := 0
var endless_depth := 0

var save_data := {
	"best_bosses_defeated": 0,
	"best_level": 0,
	"best_endless_depth": 0,
}

func _ready() -> void:
	load_save()

func start_run() -> void:
	var order: Array[String] = boss_ids.duplicate()
	if order.has(selected_boss):
		order.erase(selected_boss)
	order.push_front(selected_boss)
	boss_order = order
	boss_index = 0
	endless_depth = 0

func load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		save_data.merge(parsed, true)

func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(save_data))
	f.close()

func record_run_result(bosses_defeated: int, level: int, depth: int) -> void:
	var changed := false
	if bosses_defeated > save_data.best_bosses_defeated:
		save_data.best_bosses_defeated = bosses_defeated
		changed = true
	if level > save_data.best_level:
		save_data.best_level = level
		changed = true
	if depth > save_data.best_endless_depth:
		save_data.best_endless_depth = depth
		changed = true
	if changed:
		save_game()

var class_stats := {
	"warrior": {
		"name": "Warrior",
		"description": "High HP, strong melee, fast attack speed.",
		"color": Color(0.85, 0.25, 0.25),
		"max_hp": 140,
		"attack_damage": 14,
		"attack_cooldown": 0.35,
		"speed_mult": 0.95,
		"ranged": false,
		"crit_chance": 0.05,
	},
	"mage": {
		"name": "Mage",
		"description": "Fragile ranged spellcaster, slow attack speed.",
		"color": Color(0.3, 0.5, 0.9),
		"max_hp": 80,
		"attack_damage": 9,
		"attack_cooldown": 0.65,
		"speed_mult": 1.0,
		"ranged": true,
		"pierce": 1,
		"crit_chance": 0.08,
	},
	"rogue": {
		"name": "Rogue",
		"description": "Fast, high crit chance, low HP.",
		"color": Color(0.3, 0.8, 0.4),
		"max_hp": 95,
		"attack_damage": 10,
		"attack_cooldown": 0.28,
		"speed_mult": 1.25,
		"ranged": false,
		"crit_chance": 0.125,
	},
}

var class_attacks := {
	"warrior": "LMB: Swing\nHold: Overhead Slam\nRMB: Riposte (counter)",
	"mage": "LMB: Bolt\nHold: Charged Bolt (pierces)\nRMB: Flicker Bolt",
	"rogue": "LMB: Strike\nHold: Execute (lunge)\nRMB: Flicker Strike",
}

var shared_abilities := {
	"damage_up": {"name": "Sharpened Edge", "desc": "+35% attack damage"},
	"max_hp_up": {"name": "Vitality", "desc": "+30 max HP"},
	"speed_up": {"name": "Swift Boots", "desc": "+20% move speed"},
	"dash": {"name": "Dash", "desc": "Unlock a dash (Shift)", "unique": true},
	"double_jump": {"name": "Double Jump", "desc": "Unlock an extra jump", "unique": true},
	"lifesteal": {"name": "Vampiric Strike", "desc": "+15% lifesteal on hit"},
	"attack_speed": {"name": "Haste", "desc": "-25% attack cooldown"},
}

var class_abilities := {
	"warrior": {
		"cleave": {"name": "Cleave", "desc": "Wider attack that hits everything nearby", "unique": true},
		"thorns": {"name": "Thorns", "desc": "Reflect 25% of damage taken back to attacker", "unique": true},
		"berserk": {"name": "Berserker Rage", "desc": "+50% damage when below 30% HP", "unique": true},
		"juggernaut": {"name": "Juggernaut", "desc": "+25% max HP, +15% attack damage, -10% move speed", "unique": true},
		"unbreakable": {"name": "Unbreakable", "desc": "Survive one killing blow with 1 HP", "unique": true},
		"colossal_blow": {"name": "Colossal Blow", "desc": "+50% charged attack damage, +75% knockback", "unique": true},
		"vengeance": {"name": "Vengeance", "desc": "Thorns reflection also heals you", "unique": true, "requires": "thorns"},
	},
	"mage": {
		"multishot": {"name": "Multishot", "desc": "Fire 3 bolts in a spread", "unique": true},
		"pierce": {"name": "Piercing Bolts", "desc": "+3 pierce — bolts hit more enemies", "unique": true},
		"mana_shield": {"name": "Mana Shield", "desc": "Take 50% less damage briefly after casting", "unique": true},
		"arcane_focus": {"name": "Arcane Focus", "desc": "+40% attack damage, -15% attack speed", "unique": true},
		"ward": {"name": "Ward", "desc": "Take 30% less damage from all sources", "unique": true},
		"overload": {"name": "Overload", "desc": "Every 3rd bolt is empowered for 2x damage", "unique": true},
		"resonance": {"name": "Resonance", "desc": "Multishot fires 5 bolts instead of 3", "unique": true, "requires": "multishot"},
	},
	"rogue": {
		"crit_up": {"name": "Precision", "desc": "+20% critical hit chance (2x damage)"},
		"poison_blade": {"name": "Poison Blade", "desc": "Attacks apply poison damage over time", "unique": true},
		"shadow_step": {"name": "Shadow Step", "desc": "Dash grants brief invincibility", "unique": true, "requires": "dash"},
		"momentum": {"name": "Momentum", "desc": "+15% move speed, -15% attack cooldown", "unique": true},
		"opportunist": {"name": "Opportunist", "desc": "Crits hit harder and heal you", "unique": true, "requires": "crit_up"},
		"double_strike": {"name": "Double Strike", "desc": "25% chance to hit twice", "unique": true},
		"assassinate": {"name": "Assassinate", "desc": "+50% damage against enemies above 80% HP", "unique": true},
	},
}

func get_ability_pool() -> Dictionary:
	var pool := {}
	for id in shared_abilities.keys():
		pool[id] = shared_abilities[id]
	if class_abilities.has(selected_class):
		for id in class_abilities[selected_class].keys():
			pool[id] = class_abilities[selected_class][id]
	return pool

func get_random_choices(player, count: int) -> Array:
	var pool := get_ability_pool()
	var valid_ids: Array = []
	for id in pool.keys():
		var def: Dictionary = pool[id]
		if def.get("unique", false) and player.acquired_abilities.has(id):
			continue
		if def.has("requires") and not player.acquired_abilities.has(def["requires"]):
			continue
		valid_ids.append(id)
	valid_ids.shuffle()
	var result: Array = []
	for i in range(min(count, valid_ids.size())):
		result.append({"id": valid_ids[i], "def": pool[valid_ids[i]]})
	return result
