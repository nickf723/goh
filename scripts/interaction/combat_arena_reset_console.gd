extends Area3D
class_name CombatArenaResetConsole

@export var prompt_text: String = "Reset Combat Arena"


func interact() -> Dictionary:
	var director: Node = get_tree().get_first_node_in_group("combat_arena_director")

	if director == null or not director.has_method("reset_arena"):
		return {
			"message": "The arena reset mechanism is offline.",
			"objective": "",
		}

	director.call("reset_arena")
	return {
		"message": "The arena rebuilds its training formation.",
		"objective": "Equip a weapon and test another combo branch.",
	}
