extends Area3D
class_name VillageMemoryRelic

@export var prompt_text: String = "Listen"
@export var relic_id: String = "village_memory"
@export var story_flag: String = "found_village_memory"
@export_multiline var hidden_message: String = "The air hums faintly, but the source remains buried beneath the silence."
@export_multiline var revealed_message: String = "A child's wooden bird rests where no floor remains. Its carved wings are polished by centuries of handling."
@export var objective_after: String = "Continue toward the church above the ruins."
@export var revealable_receiver_path: NodePath = NodePath("RevealableReceiver")

@onready var revealable_receiver: Node = get_node_or_null(revealable_receiver_path)


func _ready() -> void:
	add_to_group("village_memory")
	add_to_group("debuggable")
	sync_from_game_state()


func sync_from_game_state() -> void:
	if story_flag == "" or not GameState.get_flag(story_flag):
		return
	if revealable_receiver != null and revealable_receiver.has_method("reveal_target"):
		revealable_receiver.call("reveal_target", 0.0, "restored memory")


func interact() -> Dictionary:
	var revealed: bool = is_revealed()

	if not revealed:
		return {
			"message": hidden_message,
			"objective": "Use Sound to search the village square.",
		}

	if story_flag != "":
		GameState.set_flag(story_flag, true)

	if objective_after != "":
		GameState.set_objective(objective_after)

	return {
		"message": revealed_message,
		"objective": objective_after,
	}


func is_revealed() -> bool:
	if revealable_receiver == null:
		return false
	var value: Variant = revealable_receiver.get("is_revealed")
	return bool(value) if value != null else false


func reset_memory() -> void:
	if revealable_receiver != null and revealable_receiver.has_method("reset_reveal"):
		revealable_receiver.call("reset_reveal")
	if story_flag != "":
		GameState.set_flag(story_flag, false)


func get_debug_data() -> Dictionary:
	return {
		"memory": relic_id,
		"revealed": is_revealed(),
		"collected": GameState.get_flag(story_flag) if story_flag != "" else false,
	}
