extends Node

signal objective_changed(new_objective: String)
signal flag_changed(flag_name: String, value: bool)
signal stat_changed(stat_name: String, value: int)
signal player_defeated

var current_objective: String = "Look around."

var stats: Dictionary = {
	"level": 1,
	
	"health": 5,
	"max_health": 5,
	"stamina": 1,
	"max_stamina": 1,
	"mana": 5,
	"max_mana": 5,
	"stance": 5,
	"max_stance": 5,
	
	"power": 1,
	"dexterity": 1,
	"arcana": 1,
	"intelligence": 1,
	
	"defense": 1,
	"resilience": 1,
	"constitution": 1,
	"evasion": 1,
	
	"charisma": 1,
	"focus": 5,
	"skill": 1,
	"luck": 1,



	"fire": 1,
	"water": 1,
	"earth": 1,
	"air": 1,
	"ice": 1,
	"metal": 1,
	"lightning": 1,
	"poison": 1,
	"life": 1,
	"death": 1,
	"body": 1,
	"soul": 1,
	"dream": 1,
	"sound": 1,
	"space": 1,
	"time": 1,
	"light": 1,
	"darkness": 1,
	"void": 1
}

var story_flags: Dictionary = {
	"inspected_stone": false,
	"inspected_sign": false,
	"inspected_flowers": false,
	"met_church_finder": false,
	"chose_play_prologue": false,
	"chose_skip_prologue": false,
}

var player_invulnerable: bool = false
var player_invulnerability_timer: float = 0.0

func _process(delta: float) -> void:
	update_player_invulnerability(delta)

func set_objective(new_objective: String) -> void:
	current_objective = new_objective
	objective_changed.emit(current_objective)

func set_flag(flag_name: String, value: bool = true) -> void:
	story_flags[flag_name] = value
	flag_changed.emit(flag_name, value)

func get_flag(flag_name: String) -> bool:
	if not story_flags.has(flag_name):
		return false

	return story_flags[flag_name]

func set_stat(stat_name: String, value: int) -> void:
	stats[stat_name] = value
	stat_changed.emit(stat_name, value)

func get_stat(stat_name: String) -> int:
	if not stats.has(stat_name):
		return 0

	return stats[stat_name]

func add_stat(stat_name: String, amount: int) -> void:
	var current_value: int = get_stat(stat_name)
	set_stat(stat_name, current_value + amount)

func take_damage(amount: int) -> void:
	if player_invulnerable:
		print("Grace avoided the hit.")
		return
	var current_health: int = get_stat("health")
	var max_health: int = get_stat("max_health")
	var new_health: int = clamp(current_health - amount, 0, max_health)

	print("Grace takes damage: ", amount)
	print("Health: ", current_health, " -> ", new_health)

	set_stat("health", new_health)

	if new_health <= 0:
		print("Grace defeated signal emitted.")
		player_defeated.emit()

func heal(amount: int) -> void:
	var current_health: int = get_stat("health")
	var max_health: int = get_stat("max_health")
	var new_health: int = clamp(current_health + amount, 0, max_health)

	set_stat("health", new_health)

func spend_stamina(amount: int) -> bool:
	var current_stamina: int = get_stat("stamina")

	if current_stamina < amount:
		return false

	set_stat("stamina", current_stamina - amount)
	return true

func restore_stamina(amount: int) -> void:
	var current_stamina: int = get_stat("stamina")
	var max_stamina: int = get_stat("max_stamina")
	var new_stamina: int = clamp(current_stamina + amount, 0, max_stamina)

	set_stat("stamina", new_stamina)

func spend_mana(amount: int) -> bool:
	var current_mana: int = get_stat("mana")
	if current_mana < amount:
		return false
	set_stat("mana", current_mana - amount)
	return true

func restore_mana(amount: int) -> void:
	var current_mana: int = get_stat("mana")
	var max_mana: int = get_stat("max_mana")
	var new_mana: int = clamp(current_mana + amount, 0, max_mana)

	set_stat("mana", new_mana)

func damage_stance(amount: int) -> void:
	var current_stance: int = get_stat("stance")
	var new_stance: int = clamp(current_stance - amount, 0, get_stat("max_stance"))

	set_stat("stance", new_stance)

func restore_stance(amount: int) -> void:
	var current_stance: int = get_stat("stance")
	var max_stance: int = get_stat("max_stance")
	var new_stance: int = clamp(current_stance + amount, 0, max_stance)

	set_stat("stance", new_stance)

func reset_run() -> void:
	current_objective = "Look around."

	for stat_name: String in stats.keys():
		stats[stat_name] = 1

	for flag_name: String in story_flags.keys():
		story_flags[flag_name] = false

	objective_changed.emit(current_objective)

func begin_player_invulnerability(duration: float) -> void:
	if duration <= 0.0:
		return

	player_invulnerable = true
	player_invulnerability_timer = max(player_invulnerability_timer, duration)

func update_player_invulnerability(delta: float) -> void:
	if not player_invulnerable:
		return

	player_invulnerability_timer -= delta

	if player_invulnerability_timer <= 0.0:
		player_invulnerability_timer = 0.0
		player_invulnerable = false

func is_player_invulnerable() -> bool:
	return player_invulnerable
