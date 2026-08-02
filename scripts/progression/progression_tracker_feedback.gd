extends "res://scripts/progression/progression_tracker.gd"

signal tracked_progress_changed(kind: String, record_id: String, row: Dictionary)

const TRACKED_KIND_KEY: String = "__progression__::tracked_kind"
const TRACKED_RECORD_KEY: String = "__progression__::tracked_record"
const LEGACY_TRACKED_QUEST_KEY: String = "__progression__::tracked_quest"


func track_quest(quest_id: String) -> bool:
	var quest: Dictionary = GameState.get_quest(quest_id)
	if quest.is_empty() or str(quest.get("state", "")) != "active":
		return false
	GameState.story_flags[LEGACY_TRACKED_QUEST_KEY] = quest_id
	var objective: String = str(quest.get("objective", ""))
	if objective != "":
		GameState.set_objective(objective)
	tracked_quest_changed.emit(quest_id)
	return _set_tracked_progress("quest", quest_id)


func track_challenge(challenge_id: String) -> bool:
	if ChallengeCatalogScript.get_definition(challenge_id).is_empty():
		return false
	return _set_tracked_progress("challenge", challenge_id)


func track_progress(kind: String, record_id: String) -> bool:
	match kind.strip_edges().to_lower():
		"quest":
			return track_quest(record_id)
		"challenge":
			return track_challenge(record_id)
	return false


func clear_tracked_progress() -> void:
	GameState.story_flags.erase(TRACKED_KIND_KEY)
	GameState.story_flags.erase(TRACKED_RECORD_KEY)
	tracked_progress_changed.emit("", "", {})


func get_tracked_progress_kind() -> String:
	var kind: String = str(GameState.story_flags.get(TRACKED_KIND_KEY, ""))
	if kind == "" and get_tracked_quest_id() != "":
		return "quest"
	return kind


func get_tracked_progress_id() -> String:
	var record_id: String = str(GameState.story_flags.get(TRACKED_RECORD_KEY, ""))
	if record_id == "" and get_tracked_progress_kind() == "quest":
		return get_tracked_quest_id()
	return record_id


func is_progress_tracked(kind: String, record_id: String) -> bool:
	return (
		get_tracked_progress_kind() == kind.strip_edges().to_lower()
		and get_tracked_progress_id() == record_id
	)


func get_tracked_progress_row() -> Dictionary:
	var kind: String = get_tracked_progress_kind()
	var record_id: String = get_tracked_progress_id()
	if kind == "" or record_id == "":
		return {}
	match kind:
		"challenge":
			return _make_tracked_challenge_row(record_id)
		"quest":
			return _make_tracked_quest_row(record_id)
	return {}


func get_challenge_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = super.get_challenge_rows()
	for row: Dictionary in rows:
		var challenge_id: String = str(row.get("challenge_id", ""))
		var tracked: bool = is_progress_tracked("challenge", challenge_id)
		row["tracked"] = tracked
		if tracked:
			row["status"] = "TRACKED • " + str(row.get("status", "IN PROGRESS"))
			var details: Array[String] = []
			for raw_detail: Variant in row.get("details", []):
				details.append(str(raw_detail))
			details.append("Pinned to the gameplay HUD.")
			row["details"] = details
		else:
			var details: Array[String] = []
			for raw_detail: Variant in row.get("details", []):
				details.append(str(raw_detail))
			details.append("Select this record again to pin it to the gameplay HUD.")
			row["details"] = details
	return rows


func _set_tracked_progress(kind: String, record_id: String) -> bool:
	var resolved_kind: String = kind.strip_edges().to_lower()
	var resolved_id: String = record_id.strip_edges()
	if resolved_kind == "" or resolved_id == "":
		return false
	GameState.story_flags[TRACKED_KIND_KEY] = resolved_kind
	GameState.story_flags[TRACKED_RECORD_KEY] = resolved_id
	var row: Dictionary = get_tracked_progress_row()
	if row.is_empty():
		return false
	tracked_progress_changed.emit(resolved_kind, resolved_id, row.duplicate(true))
	return true


func _make_tracked_challenge_row(challenge_id: String) -> Dictionary:
	var definition: Dictionary = ChallengeCatalogScript.get_definition(challenge_id)
	var progress: Dictionary = get_challenge_progress(challenge_id)
	if definition.is_empty() or progress.is_empty():
		return {}
	var complete: bool = bool(progress.get("complete", false))
	return {
		"kind": "challenge",
		"id": challenge_id,
		"record_id": "progression." + challenge_id,
		"title": str(definition.get("display_name", challenge_id.capitalize())),
		"detail": (
			"Reward active: " + str(definition.get("reward_name", "Reward"))
			if complete
			else str(definition.get("requirement", "Complete the challenge."))
		),
		"current": int(progress.get("current", 0)),
		"target": int(progress.get("target", 1)),
		"fraction": float(progress.get("fraction", 0.0)),
		"complete": complete,
		"state": "completed" if complete else "active",
		"reward_id": str(definition.get("reward_id", "")),
		"reward_name": str(definition.get("reward_name", "Reward")),
		"menu_tab": "codex",
		"menu_category": "challenges",
	}


func _make_tracked_quest_row(quest_id: String) -> Dictionary:
	var quest: Dictionary = GameState.get_quest(quest_id)
	if quest.is_empty():
		return {}
	var state: String = str(quest.get("state", "active"))
	var stages_value: Variant = quest.get("stages", [])
	var stage_count: int = (stages_value as Array).size() if stages_value is Array else 0
	var stage: int = maxi(int(quest.get("stage", 0)), 0)
	var current: int = mini(stage + 1, maxi(stage_count, 1))
	var complete: bool = state == "completed"
	if complete and stage_count > 0:
		current = stage_count
	return {
		"kind": "quest",
		"id": quest_id,
		"record_id": quest_id,
		"title": str(quest.get("title", quest_id.replace("_", " ").capitalize())),
		"detail": str(quest.get("objective", "Continue the tracked quest.")),
		"current": current if stage_count > 0 else -1,
		"target": stage_count if stage_count > 0 else -1,
		"fraction": (
			float(current) / float(maxi(stage_count, 1))
			if stage_count > 0
			else 0.0
		),
		"complete": complete,
		"state": state,
		"menu_tab": "codex",
		"menu_category": str(quest.get("quest_type", "side")),
	}
