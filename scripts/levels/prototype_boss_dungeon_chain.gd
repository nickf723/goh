extends Node3D

@export var opening_objective: String = "Church Trial: save, clear combat, solve the lock, defeat the armor, then exit."
@export var opening_message: String = "Church Trial Prototype: the final room now contains an animated armor. Sleep before the boss."
@export var apply_save_on_ready: bool = true


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	await get_tree().process_frame

	if apply_save_on_ready and GameState.apply_save_for_current_scene():
		set_objective(GameState.current_objective)
		show_message("Grace wakes at the last save bed.")
		return

	set_objective(opening_objective)
	show_message(opening_message)


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui != null and ui.has_method("show_message"):
		ui.show_message(text)


func set_objective(text: String) -> void:
	GameState.set_objective(text)

	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui != null and ui.has_method("set_objective"):
		ui.set_objective(text)
