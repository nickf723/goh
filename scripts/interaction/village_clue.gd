extends Area3D
class_name VillageClue

signal clue_inspected(clue_id: String)

@export var prompt_text: String = "Inspect"
@export var clue_id: String = "village_clue"
@export_multiline var clue_message: String = "Something here does not belong."
@export var objective_after: String = "Continue toward the church."
@export var story_flag: String = ""
@export var one_time: bool = true

var has_been_read: bool = false


func _ready() -> void:
	add_to_group("village_clue")
	add_to_group("debuggable")
	sync_from_game_state()


func sync_from_game_state() -> void:
	has_been_read = story_flag != "" and GameState.get_flag(story_flag)


func interact() -> Dictionary:
	if one_time and has_been_read:
		return {
			"message": clue_message,
			"objective": "",
		}

	has_been_read = true

	if story_flag != "":
		GameState.set_flag(story_flag, true)

	if objective_after != "":
		GameState.set_objective(objective_after)

	clue_inspected.emit(clue_id)
	return {
		"message": clue_message,
		"objective": objective_after,
	}


func reset_clue() -> void:
	has_been_read = false
	if story_flag != "":
		GameState.set_flag(story_flag, false)


func get_debug_data() -> Dictionary:
	return {
		"clue": clue_id,
		"read": has_been_read,
		"flag": story_flag,
	}
