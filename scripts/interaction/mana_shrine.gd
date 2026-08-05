extends Area3D

signal shrine_used(result: Dictionary)

@export var prompt_text: String = "Touch Shrine"
@export var mana_cost: int = 1
@export var restores_after_failed_use: bool = true

var use_count: int = 0


func interact() -> Dictionary:
	var spent_mana: bool = GameState.spend_mana(mana_cost)
	var result: Dictionary = {}

	if spent_mana:
		var current_mana: int = GameState.get_stat("mana")
		var max_mana: int = GameState.get_stat("max_mana")
		result = {
			"message": "The shrine drinks a spark of mana. Mana: " + str(current_mana) + " / " + str(max_mana),
			"objective": "Mana can now be spent by interactables.",
			"spent_mana": true,
		}
	else:
		if restores_after_failed_use:
			GameState.restore_mana(1)
		var restored_mana: int = GameState.get_stat("mana")
		var restored_max_mana: int = GameState.get_stat("max_mana")
		result = {
			"message": "The shrine finds no mana to take, so it gives one back. Mana: " + str(restored_mana) + " / " + str(restored_max_mana),
			"objective": "Touch the shrine again to spend mana.",
			"spent_mana": false,
		}

	use_count += 1
	result["use_count"] = use_count
	shrine_used.emit(result.duplicate(true))
	return result


func get_debug_data() -> Dictionary:
	return {
		"mana_cost": mana_cost,
		"use_count": use_count,
		"restores_after_failed_use": restores_after_failed_use,
	}
