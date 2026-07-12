extends Node3D

const RewardAltarScene = preload("res://scenes/actors/interactables/church_trial_reward_altar.tscn")

@export var opening_objective: String = "Church Trial: save, clear combat, solve the lock, defeat the armor, claim the sigil, then exit."
@export var opening_message: String = "Church Trial Prototype: defeat the Animated Armor, then claim the reward altar beyond the gate."
@export var apply_save_on_ready: bool = true
@export var add_reward_altar: bool = true
@export var reward_altar_position: Vector3 = Vector3(0.0, 0.15, 112.5)


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	spawn_reward_altar()
	configure_final_exit()
	await get_tree().process_frame

	if apply_save_on_ready and GameState.apply_save_for_current_scene():
		set_objective(GameState.current_objective)
		show_message("Grace resumes from saved progress.")
		return

	set_objective(opening_objective)
	show_message(opening_message)


func spawn_reward_altar() -> void:
	if not add_reward_altar:
		return

	if get_node_or_null("ChurchTrialRewardAltar") != null:
		return

	var altar: Node3D = RewardAltarScene.instantiate() as Node3D

	if altar == null:
		return

	altar.name = "ChurchTrialRewardAltar"
	add_child(altar)
	altar.global_position = reward_altar_position


func configure_final_exit() -> void:
	var final_exit: Node = find_child_named(self, "LevelExit")

	if final_exit == null:
		return

	if "completion_message" in final_exit:
		final_exit.set("completion_message", "Church Trial complete. Grace carries the Church Trial Sigil beyond the reward chamber.")

	if "objective_after" in final_exit:
		final_exit.set("objective_after", "Church Trial complete.")

	if "required_key_item_id" in final_exit:
		final_exit.set("required_key_item_id", "church_trial_sigil")

	if "missing_key_item_message" in final_exit:
		final_exit.set("missing_key_item_message", "The final door waits for the Church Trial Sigil.")

	if "missing_key_item_objective" in final_exit:
		final_exit.set("missing_key_item_objective", "Claim the Church Trial Sigil from the reward altar.")


func find_child_named(root: Node, target_name: String) -> Node:
	if root.name == target_name:
		return root

	for child: Node in root.get_children():
		var found: Node = find_child_named(child, target_name)

		if found != null:
			return found

	return null


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui != null and ui.has_method("show_message"):
		ui.show_message(text)


func set_objective(text: String) -> void:
	GameState.set_objective(text)

	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui != null and ui.has_method("set_objective"):
		ui.set_objective(text)
