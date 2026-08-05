extends Node

signal encounter_started(initial_enemy_count: int)
signal encounter_completed(initial_enemy_count: int)

@export var enemy_group_name: String = "enemy"
@export var reward_mana: int = 1

var initial_enemy_count: int = 0
var encounter_complete: bool = false
var completion_count: int = 0


func _ready() -> void:
	await get_tree().process_frame
	initial_enemy_count = get_tree().get_nodes_in_group(enemy_group_name).size()
	print("Encounter started with enemies: ", initial_enemy_count)
	encounter_started.emit(initial_enemy_count)


func _process(_delta: float) -> void:
	if encounter_complete:
		return
	if initial_enemy_count <= 0:
		return
	if GameState.get_stat("health") <= 0:
		return
	var remaining_enemies: int = get_tree().get_nodes_in_group(enemy_group_name).size()
	if remaining_enemies <= 0:
		complete_encounter()


func complete_encounter() -> void:
	if encounter_complete:
		return
	encounter_complete = true
	completion_count += 1

	if reward_mana > 0:
		GameState.restore_mana(reward_mana)

	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null:
		if ui.has_method("show_message"):
			ui.call("show_message", "Encounter cleared. Grace recovers " + str(reward_mana) + " mana.")
		if ui.has_method("set_objective"):
			ui.call("set_objective", "Encounter cleared.")

	unlock_reward_objects()
	encounter_completed.emit(initial_enemy_count)


func unlock_reward_objects() -> void:
	var reward_objects: Array[Node] = get_tree().get_nodes_in_group("encounter_reward")
	for reward_object: Node in reward_objects:
		if reward_object.has_method("unlock"):
			reward_object.call("unlock")


func reset_encounter_state() -> void:
	encounter_complete = false
	initial_enemy_count = get_tree().get_nodes_in_group(enemy_group_name).size()
	encounter_started.emit(initial_enemy_count)


func get_debug_data() -> Dictionary:
	return {
		"enemy_group": enemy_group_name,
		"initial_enemy_count": initial_enemy_count,
		"remaining_enemy_count": get_tree().get_nodes_in_group(enemy_group_name).size(),
		"complete": encounter_complete,
		"completion_count": completion_count,
		"reward_mana": reward_mana,
	}
