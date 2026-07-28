extends RefCounted
class_name SpellcastingMasteryService

const AchievementServiceScript = preload("res://scripts/progression/achievement_service.gd")
const SpellcastingTraditionCatalogScript = preload("res://scripts/progression/spellcasting_tradition_catalog.gd")


static func is_stage_unlocked(tradition_id: String, stage_id: String) -> bool:
	var achievement_id: String = SpellcastingTraditionCatalogScript.get_achievement_id(
		tradition_id,
		stage_id
	)
	return achievement_id != "" and AchievementServiceScript.is_unlocked(achievement_id)


static func get_completed_stage_count(tradition_id: String) -> int:
	if not SpellcastingTraditionCatalogScript.has_tradition(tradition_id):
		return 0

	var completed: int = 0
	for stage_id: String in SpellcastingTraditionCatalogScript.STAGE_IDS:
		if not is_stage_unlocked(tradition_id, stage_id):
			break
		completed += 1
	return completed


static func get_rank(tradition_id: String) -> int:
	return get_completed_stage_count(tradition_id)


static func get_current_stage_id(tradition_id: String) -> String:
	return SpellcastingTraditionCatalogScript.get_stage_id(get_rank(tradition_id))


static func get_next_stage_id(tradition_id: String) -> String:
	if not SpellcastingTraditionCatalogScript.has_tradition(tradition_id):
		return ""
	return SpellcastingTraditionCatalogScript.get_stage_id(get_rank(tradition_id) + 1)


static func is_mastered(tradition_id: String) -> bool:
	return is_stage_unlocked(tradition_id, "mastery")


static func advance(tradition_id: String, evidence: Dictionary = {}) -> Dictionary:
	var next_stage_id: String = get_next_stage_id(tradition_id)
	if next_stage_id == "":
		if SpellcastingTraditionCatalogScript.has_tradition(tradition_id) and is_mastered(tradition_id):
			return {
				"ok": true,
				"tradition_id": tradition_id,
				"newly_unlocked": false,
				"already_complete": true,
				"rank": get_rank(tradition_id),
				"mastered": true,
				"capstone": SpellcastingTraditionCatalogScript.get_capstone(tradition_id),
			}
		return {
			"ok": false,
			"tradition_id": tradition_id,
			"newly_unlocked": false,
			"error": "unknown tradition",
		}
	return unlock_stage(tradition_id, next_stage_id, evidence)


static func unlock_stage(
	tradition_id: String,
	stage_id: String,
	evidence: Dictionary = {},
	allow_skip: bool = false
) -> Dictionary:
	if not SpellcastingTraditionCatalogScript.has_tradition(tradition_id):
		return _failure(tradition_id, stage_id, "unknown tradition")
	if not SpellcastingTraditionCatalogScript.has_stage(stage_id):
		return _failure(tradition_id, stage_id, "unknown mastery stage")

	var current_rank: int = get_rank(tradition_id)
	var target_rank: int = SpellcastingTraditionCatalogScript.get_stage_rank(stage_id)
	if target_rank <= current_rank:
		return {
			"ok": true,
			"tradition_id": tradition_id,
			"stage_id": stage_id,
			"newly_unlocked": false,
			"already_unlocked": true,
			"rank": current_rank,
			"mastered": is_mastered(tradition_id),
			"capstone": SpellcastingTraditionCatalogScript.get_capstone(tradition_id),
		}

	if not allow_skip and target_rank != current_rank + 1:
		return _failure(
			tradition_id,
			stage_id,
			"mastery stages must unlock in order; next is " + get_next_stage_id(tradition_id)
		)

	var unlocked_stage_ids: Array[String] = []
	for rank: int in range(current_rank + 1, target_rank + 1):
		var unlocked_stage_id: String = SpellcastingTraditionCatalogScript.get_stage_id(rank)
		var achievement_id: String = SpellcastingTraditionCatalogScript.get_achievement_id(
			tradition_id,
			unlocked_stage_id
		)
		var stage_evidence: Dictionary = evidence.duplicate(true)
		stage_evidence["tradition_id"] = tradition_id
		stage_evidence["stage_id"] = unlocked_stage_id
		if allow_skip and rank < target_rank:
			stage_evidence["filled_for_sequential_integrity"] = true

		var unlock_result: Dictionary = AchievementServiceScript.unlock(
			achievement_id,
			stage_evidence
		)
		if not bool(unlock_result.get("ok", false)):
			return _failure(
				tradition_id,
				unlocked_stage_id,
				str(unlock_result.get("error", "achievement unlock failed"))
			)
		if bool(unlock_result.get("newly_unlocked", false)):
			unlocked_stage_ids.append(unlocked_stage_id)

	var new_rank: int = get_rank(tradition_id)
	return {
		"ok": true,
		"tradition_id": tradition_id,
		"stage_id": stage_id,
		"unlocked_stage_ids": unlocked_stage_ids,
		"newly_unlocked": not unlocked_stage_ids.is_empty(),
		"rank": new_rank,
		"mastered": is_mastered(tradition_id),
		"capstone": SpellcastingTraditionCatalogScript.get_capstone(tradition_id),
	}


static func get_progress_row(tradition_id: String) -> Dictionary:
	if not SpellcastingTraditionCatalogScript.has_tradition(tradition_id):
		return {}

	var definition: Dictionary = SpellcastingTraditionCatalogScript.get_definition(tradition_id)
	var rank: int = get_rank(tradition_id)
	var current_stage_id: String = get_current_stage_id(tradition_id)
	var next_stage_id: String = get_next_stage_id(tradition_id)
	var unlocked_stage_ids: Array[String] = []
	var achievement_ids: Array[String] = []

	for stage_id: String in SpellcastingTraditionCatalogScript.STAGE_IDS:
		var achievement_id: String = SpellcastingTraditionCatalogScript.get_achievement_id(
			tradition_id,
			stage_id
		)
		achievement_ids.append(achievement_id)
		if AchievementServiceScript.is_unlocked(achievement_id):
			unlocked_stage_ids.append(stage_id)

	return {
		"id": tradition_id,
		"display_name": str(definition.get("display_name", tradition_id.capitalize())),
		"relationship": str(definition.get("relationship", "")),
		"verbs": (definition.get("verbs", []) as Array).duplicate(),
		"rank": rank,
		"rank_max": SpellcastingTraditionCatalogScript.STAGE_IDS.size(),
		"current_stage_id": current_stage_id,
		"current_stage_name": (
			"Uninitiated"
			if current_stage_id == ""
			else SpellcastingTraditionCatalogScript.get_stage_display_name(current_stage_id)
		),
		"next_stage_id": next_stage_id,
		"next_stage_name": SpellcastingTraditionCatalogScript.get_stage_display_name(next_stage_id) if next_stage_id != "" else "",
		"unlocked_stage_ids": unlocked_stage_ids,
		"achievement_ids": achievement_ids,
		"progress_fraction": float(rank) / float(SpellcastingTraditionCatalogScript.STAGE_IDS.size()),
		"mastered": is_mastered(tradition_id),
		"capstone_ready": is_mastered(tradition_id),
		"capstone": SpellcastingTraditionCatalogScript.get_capstone(tradition_id),
	}


static func get_progress_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for tradition_id: String in SpellcastingTraditionCatalogScript.TRADITION_IDS:
		rows.append(get_progress_row(tradition_id))
	return rows


static func get_mastered_tradition_ids() -> Array[String]:
	var mastered: Array[String] = []
	for tradition_id: String in SpellcastingTraditionCatalogScript.TRADITION_IDS:
		if is_mastered(tradition_id):
			mastered.append(tradition_id)
	return mastered


static func get_active_capstone_ids() -> Array[String]:
	var capstone_ids: Array[String] = []
	for tradition_id: String in get_mastered_tradition_ids():
		var capstone_id: String = str(
			SpellcastingTraditionCatalogScript.get_capstone(tradition_id).get("id", "")
		)
		if capstone_id != "" and not capstone_ids.has(capstone_id):
			capstone_ids.append(capstone_id)
	return capstone_ids


static func has_mastered_all() -> bool:
	return get_mastered_tradition_ids().size() == SpellcastingTraditionCatalogScript.TRADITION_IDS.size()


static func master_all_for_debug() -> Dictionary:
	var promoted: Array[String] = []
	for tradition_id: String in SpellcastingTraditionCatalogScript.TRADITION_IDS:
		var was_mastered: bool = is_mastered(tradition_id)
		var result: Dictionary = unlock_stage(
			tradition_id,
			"mastery",
			{"source": "debug_master_all"},
			true
		)
		if bool(result.get("ok", false)) and not was_mastered and is_mastered(tradition_id):
			promoted.append(tradition_id)

	return {
		"ok": has_mastered_all(),
		"promoted": promoted,
		"mastered": get_mastered_tradition_ids(),
		"capstones": get_active_capstone_ids(),
	}


static func reset_all() -> int:
	var revoked: int = 0
	for tradition_id: String in SpellcastingTraditionCatalogScript.TRADITION_IDS:
		for stage_id: String in SpellcastingTraditionCatalogScript.STAGE_IDS:
			var achievement_id: String = SpellcastingTraditionCatalogScript.get_achievement_id(
				tradition_id,
				stage_id
			)
			if AchievementServiceScript.revoke(achievement_id):
				revoked += 1
	return revoked


static func _failure(tradition_id: String, stage_id: String, error_text: String) -> Dictionary:
	return {
		"ok": false,
		"tradition_id": tradition_id,
		"stage_id": stage_id,
		"newly_unlocked": false,
		"error": error_text,
	}