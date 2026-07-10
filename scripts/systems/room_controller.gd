extends Node3D

@export var starting_objective: String = "Defeat the goblin and clear the path."
@export var restore_player_on_start: bool = true


func _ready() -> void:
	if restore_player_on_start:
		GameState.set_stat("health", GameState.get_stat("max_health"))
		GameState.set_stat("mana", GameState.get_stat("max_mana"))
		GameState.set_stat("stamina", GameState.get_stat("max_stamina"))
		GameState.set_stat("stance", GameState.get_stat("max_stance"))

	GameState.set_objective(starting_objective)

	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui != null and ui.has_method("set_objective"):
		ui.set_objective(starting_objective)
