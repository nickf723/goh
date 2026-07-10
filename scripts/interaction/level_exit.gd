extends Area3D

@export var prompt_text: String = "Exit"
@export var completion_message: String = "Area cleared."
@export var objective_after: String = "Prototype room complete."
@export var next_scene_path: String = ""

@export var triggers_on_touch: bool = true

var has_triggered: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func interact() -> Dictionary:
	trigger_exit()

	return {
		"message": completion_message,
		"objective": objective_after
	}

func _on_body_entered(body: Node3D) -> void:
	if not triggers_on_touch:
		return

	if body.is_in_group("player"):
		trigger_exit()

func _on_area_entered(area: Area3D) -> void:
	if not triggers_on_touch:
		return

	var parent: Node = area.get_parent()

	if parent != null and parent.is_in_group("player"):
		trigger_exit()

func trigger_exit() -> void:
	if has_triggered:
		return

	has_triggered = true

	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui != null:
		if ui.has_method("show_message"):
			ui.show_message(completion_message)

		if ui.has_method("set_objective"):
			ui.set_objective(objective_after)

	if next_scene_path != "":
		get_tree().change_scene_to_file(next_scene_path)
