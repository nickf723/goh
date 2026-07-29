extends RefCounted
class_name SpellcastingMasteryService

const AchievementCatalogScript = preload(
	"res://scripts/progression/achievement_catalog.gd"
)
const AchievementServiceScript = preload(
	"res://scripts/progression/achievement_service.gd"
)
const SpellcastingTraditionCatalogScript = preload(
	"res://scripts/progression/spellcasting_tradition_catalog.gd"
)


static func ensure_story_baseline() -> Dictionary:
	var unlocked: Array[String] = []
	for tradition_id: String in SpellcastingTraditionCatalogScript.get_baseline_tradition_ids():
		var baseline_stage_id: String = (
			SpellcastingTraditionCatalogScript.get_baseline_stage_id(tradition_id)
		)
		if baseline_stage_id == "":
			continue
		var was_unlocked: bool = is_stage_unlocked(tradition_id, baseline_stage_id)
		var result: Dictionary = unlock_stage(
			tradition_id,
			baseline_stage_id,
			{
				"source": "story_baseline",
				"reason": "Grace begins as a sorcerer by bloodline and wizard by study.",
				"silent": true,
			},
			true
		)
		if bool(result.get("ok", false)) and not was_unlocked:
			unlocked.append(tradition_id)
	return {
		"ok": true,
		"unlocked": unlocked,
		"baseline": SpellcastingTraditionCatalogScript.get_baseline_tradition_ids(),
	}


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
		return _failure(tradition_id, "", "unknown tradition")
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
	var stage_rows: Array[Dictionary] = []

	for stage_id: String in SpellcastingTraditionCatalogScript.STAGE_IDS:
		var achievement_id: String = SpellcastingTraditionCatalogScript.get_achievement_id(
			tradition_id,
			stage_id
		)
		var unlocked: bool = AchievementServiceScript.is_unlocked(achievement_id)
		var achievement_definition: Dictionary = AchievementCatalogScript.get_definition(
			achievement_id
		)
		achievement_ids.append(achievement_id)
		if unlocked:
			unlocked_stage_ids.append(stage_id)
		stage_rows.append({
			"id": stage_id,
			"name": SpellcastingTraditionCatalogScript.get_stage_display_name(stage_id),
			"rank": SpellcastingTraditionCatalogScript.get_stage_rank(stage_id),
			"achievement_id": achievement_id,
			"description": str(achievement_definition.get("description", "")),
			"unlocked": unlocked,
			"is_current": stage_id == current_stage_id,
			"is_next": stage_id == next_stage_id,
		})

	var capstone: Dictionary = SpellcastingTraditionCatalogScript.get_capstone(tradition_id)
	var mastered: bool = is_mastered(tradition_id)
	var capstone_implemented: bool = bool(capstone.get("implemented", false))
	var capstone_state: String = "locked"
	if mastered:
		capstone_state = "active" if capstone_implemented else "reserved"

	return {
		"id": tradition_id,
		"display_name": str(definition.get("display_name", tradition_id.capitalize())),
		"icon": str(definition.get("icon", "✦")),
		"relationship": str(definition.get("relationship", "")),
		"verbs": _copy_string_array(definition.get("verbs", [])),
		"baseline_stage_id": str(definition.get("baseline_stage_id", "")),
		"rank": rank,
		"rank_max": SpellcastingTraditionCatalogScript.STAGE_IDS.size(),
		"current_stage_id": current_stage_id,
		"current_stage_name": (
			"Uninitiated"
			if current_stage_id == ""
			else SpellcastingTraditionCatalogScript.get_stage_display_name(current_stage_id)
		),
		"next_stage_id": next_stage_id,
		"next_stage_name": (
			SpellcastingTraditionCatalogScript.get_stage_display_name(next_stage_id)
			if next_stage_id != ""
			else ""
		),
		"unlocked_stage_ids": unlocked_stage_ids,
		"achievement_ids": achievement_ids,
		"stage_rows": stage_rows,
		"progress_fraction": (
			float(rank) / float(SpellcastingTraditionCatalogScript.STAGE_IDS.size())
		),
		"mastered": mastered,
		"capstone_ready": mastered,
		"capstone_implemented": capstone_implemented,
		"capstone_state": capstone_state,
		"capstone": capstone,
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
		var capstone: Dictionary = SpellcastingTraditionCatalogScript.get_capstone(tradition_id)
		if not bool(capstone.get("implemented", false)):
			continue
		var capstone_id: String = str(capstone.get("id", ""))
		if capstone_id != "" and not capstone_ids.has(capstone_id):
			capstone_ids.append(capstone_id)
	return capstone_ids


static func has_active_capstone(capstone_id: String) -> bool:
	return capstone_id != "" and get_active_capstone_ids().has(capstone_id)


static func has_mastered_all() -> bool:
	return (
		get_mastered_tradition_ids().size()
		== SpellcastingTraditionCatalogScript.TRADITION_IDS.size()
	)


static func get_summary() -> Dictionary:
	var rows: Array[Dictionary] = get_progress_rows()
	var initiated_count: int = 0
	var mastered_count: int = 0
	for row: Dictionary in rows:
		if int(row.get("rank", 0)) > 0:
			initiated_count += 1
		if bool(row.get("mastered", false)):
			mastered_count += 1
	var achievement_summary: Dictionary = AchievementServiceScript.get_summary()
	return {
		"tradition_count": rows.size(),
		"initiated_count": initiated_count,
		"mastered_count": mastered_count,
		"achievement_unlocked": int(achievement_summary.get("unlocked", 0)),
		"achievement_total": int(achievement_summary.get("total", 0)),
		"active_capstones": get_active_capstone_ids(),
		"all_mastered": has_mastered_all(),
	}


static func master_all_for_debug() -> Dictionary:
	var promoted: Array[String] = []
	for tradition_id: String in SpellcastingTraditionCatalogScript.TRADITION_IDS:
		var was_mastered: bool = is_mastered(tradition_id)
		var result: Dictionary = unlock_stage(
			tradition_id,
			"mastery",
			{"source": "debug_master_all", "silent": true},
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


static func reset_all(preserve_story_baseline: bool = false) -> int:
	var revoked: int = 0
	for tradition_id: String in SpellcastingTraditionCatalogScript.TRADITION_IDS:
		for stage_id: String in SpellcastingTraditionCatalogScript.STAGE_IDS:
			var achievement_id: String = SpellcastingTraditionCatalogScript.get_achievement_id(
				tradition_id,
				stage_id
			)
			if AchievementServiceScript.revoke(achievement_id):
				revoked += 1
	if preserve_story_baseline:
		ensure_story_baseline()
	return revoked


static func _copy_string_array(raw_values: Variant) -> Array[String]:
	var values: Array[String] = []
	if not raw_values is Array:
		return values
	for raw_value: Variant in raw_values as Array:
		var value: String = str(raw_value)
		if value != "":
			values.append(value)
	return values


static func _failure(
	tradition_id: String,
	stage_id: String,
	error_text: String
) -> Dictionary:
	return {
		"ok": false,
		"tradition_id": tradition_id,
		"stage_id": stage_id,
		"newly_unlocked": false,
		"error": error_text,
	}
