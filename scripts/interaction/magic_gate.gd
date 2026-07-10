extends StaticBody3D

@export var gate_name: String = "Magic Gate"
@export var unlock_message: String = "The gate dissolves."

var is_unlocked: bool = false


func unlock() -> void:
	if is_unlocked:
		return

	is_unlocked = true

	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui != null and ui.has_method("show_message"):
		ui.show_message(unlock_message)

	queue_free()
