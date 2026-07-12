extends Node3D

@export var opening_objective: String = "Enter the trial chain. Clear the combat room, then solve the element lock."
@export var opening_message: String = "Prototype mini-dungeon: shrine, combat, element lock."


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	await get_tree().process_frame
	set_objective(opening_objective)
	show_message(opening_message)


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui != null and ui.has_method("show_message"):
		ui.show_message(text)


func set_objective(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui != null and ui.has_method("set_objective"):
		ui.set_objective(text)
