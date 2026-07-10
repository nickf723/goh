extends Area3D

@export var prompt_text: String = "Touch Shrine"
@export var mana_cost: int = 1
@export var restores_after_failed_use: bool = true


func interact() -> Dictionary:
	var spent_mana: bool = GameState.spend_mana(mana_cost)

	if spent_mana:
		var current_mana: int = GameState.get_stat("mana")
		var max_mana: int = GameState.get_stat("max_mana")

		return {
			"message": "The shrine drinks a spark of mana. Mana: " + str(current_mana) + " / " + str(max_mana),
			"objective": "Mana can now be spent by interactables."
		}

	if restores_after_failed_use:
		GameState.restore_mana(1)

	var restored_mana: int = GameState.get_stat("mana")
	var restored_max_mana: int = GameState.get_stat("max_mana")

	return {
		"message": "The shrine finds no mana to take, so it gives one back. Mana: " + str(restored_mana) + " / " + str(restored_max_mana),
		"objective": "Touch the shrine again to spend mana."
	}
