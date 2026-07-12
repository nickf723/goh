extends Area3D

@export var prompt_text: String = "Sleep / Save"
@export var bed_id: String = "save_bed"
@export var bed_display_name: String = "Save Bed"
@export var save_position_offset: Vector3 = Vector3(0.0, 1.0, 0.0)
@export var rest_restores_resources: bool = true
@export var sleep_objective_after: String = "Saved. Continue the dungeon."


func _ready() -> void:
	add_to_group("save_point")


func interact() -> Dictionary:
	if rest_restores_resources and GameState.has_method("restore_rest_resources"):
		GameState.restore_rest_resources()

	GameState.set_objective(sleep_objective_after)

	var save_position: Vector3 = global_position + save_position_offset
	var save_result: Dictionary = GameState.save_at_bed(bed_id, bed_display_name, save_position)

	if bool(save_result.get("ok", false)):
		return {
			"message": get_success_message(),
			"objective": sleep_objective_after,
		}

	return {
		"message": "Grace tries to sleep, but the save fails. " + str(save_result.get("message", "Unknown save error.")),
		"objective": "The bed is working, but the save file did not write.",
	}


func get_success_message() -> String:
	var message: String = "Grace sleeps. Progress saved at " + bed_display_name + "."

	if rest_restores_resources:
		message += " Health, mana, stamina, and stance are restored."

	return message


func get_debug_data() -> Dictionary:
	return {
		"bed_id": bed_id,
		"bed": bed_display_name,
		"restores": rest_restores_resources,
	}
