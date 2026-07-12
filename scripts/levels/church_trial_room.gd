extends Node3D

@export var opening_objective: String = "Clear the trial room, then reach the exit beyond the sealed gate."
@export var opening_message: String = "Church Trial: use movement, spells, and the oil patch to clear the room."


func _ready() -> void:
	call_deferred("announce_room")


func announce_room() -> void:
	await get_tree().process_frame

	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui == null:
		return

	if ui.has_method("set_objective"):
		ui.set_objective(opening_objective)

	if ui.has_method("show_message"):
		ui.show_message(opening_message)

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
