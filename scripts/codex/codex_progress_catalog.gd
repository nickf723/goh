extends RefCounted
class_name CodexProgressCatalog

const AchievementCatalogScript = preload(
	"res://scripts/progression/achievement_catalog.gd"
)
const AchievementServiceScript = preload(
	"res://scripts/progression/achievement_service.gd"
)
const SpellcastingMasteryServiceScript = preload(
	"res://scripts/progression/spellcasting_mastery_service.gd"
)
const SpellcastingTraditionCatalogScript = preload(
	"res://scripts/progression/spellcasting_tradition_catalog.gd"
)
const UnlockCatalogScript = preload(
	"res://scripts/systems/unlock_catalog.gd"
)

const CATEGORY_ORDER: Array[String] = [
	"story",
	"side",
	"challenges",
	"achievements",
	"completion",
]

const CATEGORIES: Dictionary = {
	"story": {
		"id": "story",
		"title": "Story Quests",
		"icon": "★",
		"description": "Grace's primary path through the story, current objectives, stages, optional goals, and rewards.",
	},
	"side": {
		"id": "side",
		"title": "Side Quests",
		"icon": "✦",
		"description": "Optional people, places, mysteries, favors, trials, and systemic adventures discovered along the road.",
	},
	"challenges": {
		"id": "challenges",
		"title": "Challenges",
		"icon": "◆",
		"description": "Risk-of-Rain-style goals whose completion unlocks spells, upgrades, permissions, blessings, and Divine Specials.",
	},
	"achievements": {
		"id": "achievements",
		"title": "Achievements",
		"icon": "🏆",
		"description": "Persistent milestones, including the four stages of every spellcasting tradition.",
	},
	"completion": {
		"id": "completion",
		"title": "Completion",
		"icon": "◉",
		"description": "Aggregate completion across quests, unlock challenges, achievements, and mastery systems.",
	},
}


static func get_definition(category_id: String) -> Dictionary:
	if not CATEGORIES.has(category_id):
		return {}
	return (CATEGORIES[category_id] as Dictionary).duplicate(true)


static func get_rows(category_id: String) -> Array[Dictionary]:
	match category_id:
		"story":
			return get_quest_rows("story")
		"side":
			return get_quest_rows("side")
		"challenges":
			return get_challenge_rows()
		"achievements":
			return get_achievement_rows()
		"completion":
			return get_completion_rows()
	return []


static func get_quest_rows(quest_kind: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for quest: Dictionary in GameState.get_quest_rows():
		if _classify_quest(quest) != quest_kind:
			continue
		var state: String = str(quest.get("state", "active"))
		var stages: Array = quest.get("stages", []) if quest.get("stages", []) is Array else []
		var stage_index: int = maxi(int(quest.get("stage", 0)), 0)
		var target: int = maxi(stages.size(), 1)
		var current: int = target if state == "completed" else mini(stage_index + 1, target)
		var optional_completed: Dictionary = (
			quest.get("optional_completed", {}) as Dictionary
			if quest.get("optional_completed", {}) is Dictionary
			else {}
		)
		var optional_total: int = _get_optional_total(quest)
		var objective: String = str(quest.get("objective", "Continue the quest."))
		var current_stage: String = ""
		if not stages.is_empty() and stage_index < stages.size():
			current_stage = str(stages[stage_index])
		var details: Array[String] = [
			"State: " + state.capitalize(),
			"Stage: " + str(current) + "/" + str(target),
		]
		if current_stage != "":
			details.append("Current step: " + current_stage)
		if optional_total > 0:
			details.append(
				"Optional goals: " + str(optional_completed.size()) + "/" + str(optional_total)
			)
		var reward: String = _quest_reward_text(quest)
		rows.append({
			"id": str(quest.get("id", "quest")),
			"name": str(quest.get("title", "Untitled Quest")),
			"icon": "✓" if state == "completed" else ("★" if quest_kind == "story" else "✦"),
			"summary": str(quest.get("description", objective)),
			"status": state.to_upper(),
			"progress_current": current,
			"progress_target": target,
			"progress_fraction": 1.0 if state == "completed" else float(current) / float(target),
			"requirement": objective,
			"reward": reward,
			"details": details,
			"complete": state == "completed",
			"active": state == "active",
			"state": state,
			"kind": quest_kind,
		})
	rows.sort_custom(_sort_progress_rows)
	return rows


static func get_challenge_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for unlock_id_value: Variant in UnlockCatalogScript.UNLOCK_DEFS.keys():
		var unlock_id: String = str(unlock_id_value)
		var definition: Dictionary = UnlockCatalogScript.get_definition(unlock_id)
		if not _is_challenge_definition(definition):
			continue
		var requirements: Array[String] = _string_array(definition.get("requires", []))
		var completed_requirements: int = 0
		for requirement_id: String in requirements:
			if _requirement_satisfied(requirement_id):
				completed_requirements += 1
		var unlocked: bool = _requirement_satisfied(unlock_id)
		var target: int = maxi(requirements.size(), 1)
		var current: int = target if unlocked else completed_requirements
		var requirement_text: String = "Complete " + str(definition.get("source", "the associated challenge"))
		if not requirements.is_empty():
			var names: Array[String] = []
			for requirement_id: String in requirements:
				names.append(str(UnlockCatalogScript.get_definition(requirement_id).get("display_name", requirement_id.capitalize())))
			requirement_text = "Requires: " + ", ".join(names)
		var details: Array[String] = [
			"Unlock type: " + str(definition.get("type", "unlock")).replace("_", " ").capitalize(),
			"Source: " + str(definition.get("source", "Unknown")),
		]
		var effect_preview: String = str(definition.get("effect_preview", ""))
		if effect_preview != "":
			details.append("Effect: " + effect_preview)
		rows.append({
			"id": unlock_id,
			"name": str(definition.get("display_name", unlock_id.capitalize())),
			"icon": _unlock_icon(str(definition.get("type", "unknown"))),
			"summary": str(definition.get("description", "Unlock challenge.")),
			"status": "UNLOCKED" if unlocked else "LOCKED",
			"progress_current": current,
			"progress_target": target,
			"progress_fraction": 1.0 if unlocked else float(current) / float(target),
			"requirement": requirement_text,
			"reward": "Unlocks: " + str(definition.get("display_name", unlock_id.capitalize())),
			"details": details,
			"complete": unlocked,
			"active": not unlocked,
			"state": "completed" if unlocked else "active",
			"kind": "challenge",
		})
	rows.sort_custom(_sort_progress_rows)
	return rows


static func get_achievement_rows() -> Array[Dictionary]:
	SpellcastingMasteryServiceScript.ensure_story_baseline()
	var rows: Array[Dictionary] = []
	for definition: Dictionary in AchievementCatalogScript.get_definitions():
		var achievement_id: String = str(definition.get("id", "achievement"))
		var unlocked: bool = AchievementServiceScript.is_unlocked(achievement_id)
		var tradition_id: String = str(definition.get("tradition_id", ""))
		var target_rank: int = maxi(int(definition.get("stage_rank", 1)), 1)
		var current_rank: int = (
			SpellcastingMasteryServiceScript.get_rank(tradition_id)
			if tradition_id != ""
			else (target_rank if unlocked else 0)
		)
		var current: int = target_rank if unlocked else mini(current_rank, target_rank)
		var reward_hooks: Array[String] = _string_array(definition.get("reward_hooks", []))
		var reward: String = "Achievement recorded"
		if not reward_hooks.is_empty():
			reward = "Unlocks: " + ", ".join(_pretty_array(reward_hooks))
		rows.append({
			"id": achievement_id,
			"name": str(definition.get("display_name", achievement_id.capitalize())),
			"icon": "🏆" if unlocked else "◇",
			"summary": str(definition.get("description", "Achievement milestone.")),
			"status": "ACHIEVED" if unlocked else "INCOMPLETE",
			"progress_current": current,
			"progress_target": target_rank,
			"progress_fraction": 1.0 if unlocked else float(current) / float(target_rank),
			"requirement": (
				"Advance "
				+ SpellcastingTraditionCatalogScript.get_display_name(tradition_id)
				+ " to "
				+ str(definition.get("stage_id", "stage")).capitalize()
				if tradition_id != ""
				else "Complete the associated milestone."
			),
			"reward": reward,
			"details": [
				"Source: " + str(definition.get("source", "Achievement system")),
				"Persistence: save slot",
			],
			"complete": unlocked,
			"active": not unlocked,
			"state": "completed" if unlocked else "active",
			"kind": "achievement",
		})
	rows.sort_custom(_sort_progress_rows)
	return rows


static func get_completion_rows() -> Array[Dictionary]:
	var all_quests: Array[Dictionary] = []
	all_quests.append_array(get_quest_rows("story"))
	all_quests.append_array(get_quest_rows("side"))
	var challenges: Array[Dictionary] = get_challenge_rows()
	var achievements: Array[Dictionary] = get_achievement_rows()
	var mastered: int = SpellcastingMasteryServiceScript.get_mastered_tradition_ids().size()
	return [
		_make_completion_row("quests", "Quests", "★", all_quests, "Complete story and side quests."),
		_make_completion_row("challenges", "Unlock Challenges", "◆", challenges, "Complete challenge requirements to unlock mechanics."),
		_make_completion_row("achievements", "Achievements", "🏆", achievements, "Earn persistent milestones."),
		{
			"id": "traditions",
			"name": "Spellcasting Traditions",
			"icon": "✦",
			"summary": "Master every magical relationship and claim its capstone.",
			"status": str(mastered) + "/" + str(SpellcastingTraditionCatalogScript.TRADITION_IDS.size()),
			"progress_current": mastered,
			"progress_target": SpellcastingTraditionCatalogScript.TRADITION_IDS.size(),
			"progress_fraction": float(mastered) / float(maxi(SpellcastingTraditionCatalogScript.TRADITION_IDS.size(), 1)),
			"requirement": "Reach Mastery in all eight traditions.",
			"reward": "Complete magical mastery ledger",
			"details": ["Current mastered traditions: " + str(mastered)],
			"complete": mastered >= SpellcastingTraditionCatalogScript.TRADITION_IDS.size(),
			"active": true,
			"state": "active",
			"kind": "completion",
		},
		_make_overall_completion_row(all_quests, challenges, achievements, mastered),
	]


static func get_summary() -> Dictionary:
	var story: Array[Dictionary] = get_quest_rows("story")
	var side: Array[Dictionary] = get_quest_rows("side")
	var challenges: Array[Dictionary] = get_challenge_rows()
	var achievements: Array[Dictionary] = get_achievement_rows()
	return {
		"story_active": _count_state(story, "active"),
		"side_active": _count_state(side, "active"),
		"quests_complete": _count_complete(story) + _count_complete(side),
		"quests_total": story.size() + side.size(),
		"challenges_complete": _count_complete(challenges),
		"challenges_total": challenges.size(),
		"achievements_complete": _count_complete(achievements),
		"achievements_total": achievements.size(),
	}


static func validate_catalog() -> Array[String]:
	var failures: Array[String] = []
	if CATEGORY_ORDER.size() != 5:
		failures.append("codex must define five pursuit categories")
	for category_id: String in CATEGORY_ORDER:
		if get_definition(category_id).is_empty():
			failures.append("missing codex category: " + category_id)
	if get_achievement_rows().size() != AchievementCatalogScript.get_total_count():
		failures.append("codex achievement ledger does not match achievement catalog")
	if get_completion_rows().size() < 5:
		failures.append("codex completion dashboard is incomplete")
	return failures


static func _classify_quest(quest: Dictionary) -> String:
	var authored: String = str(
		quest.get("quest_type", quest.get("category", quest.get("type", "")))
	).to_lower()
	if authored in ["story", "main", "main_quest"]:
		return "story"
	if authored in ["side", "optional", "side_quest"]:
		return "side"
	var quest_id: String = str(quest.get("id", "")).to_lower()
	if quest_id.contains("main") or quest_id.contains("story"):
		return "story"
	return "side"


static func _get_optional_total(quest: Dictionary) -> int:
	var optionals: Variant = quest.get("optional_objectives", quest.get("optionals", []))
	if optionals is Array:
		return (optionals as Array).size()
	if optionals is Dictionary:
		return (optionals as Dictionary).size()
	return 0


static func _quest_reward_text(quest: Dictionary) -> String:
	for key: String in ["reward", "reward_text", "rewards"]:
		var value: Variant = quest.get(key, null)
		if value is String and str(value) != "":
			return str(value)
		if value is Array and not (value as Array).is_empty():
			return ", ".join(_pretty_array(_string_array(value)))
	return "Story and world progression"


static func _is_challenge_definition(definition: Dictionary) -> bool:
	var unlock_type: String = str(definition.get("type", ""))
	if unlock_type == UnlockCatalogScript.TYPE_ACHIEVEMENT:
		return false
	if str(definition.get("source", "")) == "Starting Spell Pack":
		return false
	return unlock_type in [
		UnlockCatalogScript.TYPE_KEY_ITEM,
		UnlockCatalogScript.TYPE_MODIFIER,
		UnlockCatalogScript.TYPE_PASSIVE,
		UnlockCatalogScript.TYPE_PERMISSION,
		UnlockCatalogScript.TYPE_DIVINE_SPECIAL,
	]


static func _requirement_satisfied(requirement_id: String) -> bool:
	if requirement_id == "":
		return true
	if GameState.has_unlock(requirement_id):
		return true
	if GameState.has_method("has_key_item") and bool(GameState.call("has_key_item", requirement_id)):
		return true
	return false


static func _unlock_icon(unlock_type: String) -> String:
	match unlock_type:
		UnlockCatalogScript.TYPE_KEY_ITEM:
			return "🔑"
		UnlockCatalogScript.TYPE_PERMISSION:
			return "🚪"
		UnlockCatalogScript.TYPE_DIVINE_SPECIAL:
			return "☀"
		UnlockCatalogScript.TYPE_MODIFIER, UnlockCatalogScript.TYPE_PASSIVE:
			return "✦"
	return "◆"


static func _make_completion_row(
	row_id: String,
	title: String,
	icon: String,
	rows: Array[Dictionary],
	requirement: String
) -> Dictionary:
	var complete: int = _count_complete(rows)
	var total: int = rows.size()
	return {
		"id": row_id,
		"name": title,
		"icon": icon,
		"summary": requirement,
		"status": str(complete) + "/" + str(total),
		"progress_current": complete,
		"progress_target": total,
		"progress_fraction": float(complete) / float(maxi(total, 1)),
		"requirement": requirement,
		"reward": "100% category completion",
		"details": ["Completed records: " + str(complete), "Total records: " + str(total)],
		"complete": total > 0 and complete >= total,
		"active": true,
		"state": "active",
		"kind": "completion",
	}


static func _make_overall_completion_row(
	quests: Array[Dictionary],
	challenges: Array[Dictionary],
	achievements: Array[Dictionary],
	mastered: int
) -> Dictionary:
	var current: int = (
		_count_complete(quests)
		+ _count_complete(challenges)
		+ _count_complete(achievements)
		+ mastered
	)
	var target: int = (
		quests.size()
		+ challenges.size()
		+ achievements.size()
		+ SpellcastingTraditionCatalogScript.TRADITION_IDS.size()
	)
	return {
		"id": "overall",
		"name": "Overall Codex Completion",
		"icon": "◉",
		"summary": "A combined measure of quests, challenges, achievements, and spellcasting mastery.",
		"status": str(roundi(float(current) / float(maxi(target, 1)) * 100.0)) + "%",
		"progress_current": current,
		"progress_target": target,
		"progress_fraction": float(current) / float(maxi(target, 1)),
		"requirement": "Complete every tracked pursuit.",
		"reward": "A gloriously overfilled ledger",
		"details": ["Completed milestones: " + str(current), "Tracked milestones: " + str(target)],
		"complete": target > 0 and current >= target,
		"active": true,
		"state": "active",
		"kind": "completion",
	}


static func _count_complete(rows: Array[Dictionary]) -> int:
	var count: int = 0
	for row: Dictionary in rows:
		if bool(row.get("complete", false)):
			count += 1
	return count


static func _count_state(rows: Array[Dictionary], state: String) -> int:
	var count: int = 0
	for row: Dictionary in rows:
		if str(row.get("state", "")) == state:
			count += 1
	return count


static func _sort_progress_rows(a: Dictionary, b: Dictionary) -> bool:
	var a_complete: bool = bool(a.get("complete", false))
	var b_complete: bool = bool(b.get("complete", false))
	if a_complete != b_complete:
		return not a_complete
	return str(a.get("name", "")) < str(b.get("name", ""))


static func _string_array(value: Variant) -> Array[String]:
	var rows: Array[String] = []
	if value is Array:
		for raw: Variant in value as Array:
			var text: String = str(raw).strip_edges()
			if text != "":
				rows.append(text)
	return rows


static func _pretty_array(values: Array[String]) -> Array[String]:
	var rows: Array[String] = []
	for value: String in values:
		rows.append(value.replace("_", " ").capitalize())
	return rows
