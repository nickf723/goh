extends RefCounted
class_name AuthoredQuestRuntime

var quest_id: String
var definition: Dictionary


func _init(id: String, quest_definition: Dictionary) -> void:
	quest_id = id
	definition = quest_definition.duplicate(true)


func ensure_started() -> Dictionary:
	var existing: Dictionary = GameState.get_quest(quest_id)
	if not existing.is_empty():
		return existing
	GameState.start_quest(quest_id, definition)
	return GameState.get_quest(quest_id)


func set_stage(stage: int, objective: String) -> void:
	ensure_started()
	GameState.set_quest_stage(quest_id, stage, objective)
	GameState.set_objective(objective)


func complete_optional(optional_id: String) -> void:
	if optional_id.is_empty():
		return
	ensure_started()
	GameState.complete_quest_optional(quest_id, optional_id)


func complete(final_objective: String) -> void:
	ensure_started()
	GameState.complete_quest(quest_id, final_objective)
	GameState.set_objective(final_objective)


func get_state() -> String:
	return str(GameState.get_quest(quest_id).get("state", "missing"))


func get_stage() -> int:
	return int(GameState.get_quest(quest_id).get("stage", -1))


func is_active() -> bool:
	return get_state() == "active"


func is_complete() -> bool:
	return get_state() == "completed"
