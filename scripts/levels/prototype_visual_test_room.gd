extends Node3D

@export var opening_objective: String = "Read the room colors, clear the enemies, then pass through the blue gate."
@export var opening_message: String = "Prototype visual test: gray floor, dark walls, black oil, blue water, cyan mana, gold gate, gold exit."


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	await get_tree().process_frame
	show_opening_ui()


func show_opening_ui() -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui == null:
		return

	if ui.has_method("set_objective"):
		ui.set_objective(opening_objective)

	if ui.has_method("show_message"):
		ui.show_message(opening_message)
