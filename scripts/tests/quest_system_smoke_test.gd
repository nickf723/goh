extends Node

const QUEST_ID: String = "quest_system_smoke_test"


func _ready() -> void:
	GameState.reset_quest(QUEST_ID)
	var started: bool = GameState.start_quest(QUEST_ID, {
		"title": "Smoke Test Quest",
		"description": "Validate persistent quest state.",
		"objective": "Begin.",
		"stage": 0,
		"stages": ["Begin", "Continue", "Return"],
	})
	assert(started)
	assert(str(GameState.get_quest(QUEST_ID).get("state", "")) == "active")
	assert(GameState.set_quest_stage(QUEST_ID, 1, "Continue."))
	assert(int(GameState.get_quest(QUEST_ID).get("stage", -1)) == 1)
	assert(GameState.complete_quest_optional(QUEST_ID, "alternate_route"))
	var optional: Dictionary = GameState.get_quest(QUEST_ID).get("optional_completed", {})
	assert(bool(optional.get("alternate_route", false)))
	assert(GameState.complete_quest(QUEST_ID))
	assert(str(GameState.get_quest(QUEST_ID).get("state", "")) == "completed")
	assert(GameState.get_quest_rows("completed").size() >= 1)
	GameState.reset_quest(QUEST_ID)
	print("PASS: Persistent quest lifecycle, stages, optional goals, and completion.")
