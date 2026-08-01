extends Node
class_name ProgressionTrackerService

signal event_recorded(event_type: String, event_key: String, evidence: Dictionary)
signal challenge_progressed(challenge_id: String, current: int, target: int)
signal challenge_completed(challenge_id: String, reward_id: String)
signal knowledge_discovered(category: String, record_id: String, evidence: Dictionary)
signal tracked_quest_changed(quest_id: String)

const ChallengeCatalogScript = preload(
	"res://scripts/progression/progression_challenge_catalog.gd"
)
const UnlockCatalogScript = preload("res://scripts/systems/unlock_catalog.gd")

const STORAGE_PREFIX: String = "__progression__::"
const COUNTER_PREFIX: String = STORAGE_PREFIX + "counter::"
const RECORD_PREFIX: String = STORAGE_PREFIX + "record::"
const TRACKED_QUEST_KEY: String = STORAGE_PREFIX + "tracked_quest"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_connect_game_state()
	call_deferred("_bootstrap_existing_progress")


func record_event(
	event_type: String,
	event_key: String,
	evidence: Dictionary = {}
) -> void:
	var resolved_type: String = event_type.strip_edges().to_lower()
	var resolved_key: String = event_key.strip_edges().to_lower()
	if resolved_type == "" or resolved_key == "":
		return
	var stored: Dictionary = evidence.duplicate(true)
	stored["event_type"] = resolved_type
	stored["event_key"] = resolved_key
	stored["recorded_at"] = Time.get_datetime_string_from_system(false, true)
	if resolved_type == "reaction_triggered":
		record_discovery("reaction", resolved_key, stored)
	elif resolved_type == "recipe_discovered":
		record_discovery("recipe", resolved_key, stored)
	elif resolved_type == "quest_completed":
		record_discovery("quest", resolved_key, stored)
	for definition: Dictionary in ChallengeCatalogScript.get_matching(
		resolved_type,
		resolved_key
	):
		_apply_event_to_challenge(definition, resolved_key, stored)
	event_recorded.emit(resolved_type, resolved_key, stored)


func record_reaction_result(result: Dictionary) -> void:
	var reaction_id: String = str(
		result.get("reaction", result.get("reaction_id", ""))
	).strip_edges().to_lower()
	if reaction_id == "":
		return
	var evidence: Dictionary = result.duplicate(true)
	evidence["rule_id"] = str(result.get("rule", result.get("rule_id", "")))
	record_event("reaction_triggered", reaction_id, evidence)


func record_discovery(
	category: String,
	record_id: String,
	evidence: Dictionary = {}
) -> bool:
	var key: String = _record_key(category, record_id)
	if bool(GameState.story_flags.get(key, false)):
		return false
	GameState.story_flags[key] = true
	knowledge_discovered.emit(category, record_id, evidence.duplicate(true))
	if category == "reaction" and GameState.has_method("show_system_message"):
		GameState.call(
			"show_system_message",
			"Journal discovery: " + record_id.replace("_", " ").capitalize()
		)
	return true


func has_discovery(category: String, record_id: String) -> bool:
	return bool(GameState.story_flags.get(_record_key(category, record_id), false))


func get_discovery_count(category: String) -> int:
	var prefix: String = RECORD_PREFIX + category + "::"
	var count: int = 0
	for raw_key: Variant in GameState.story_flags.keys():
		var key: String = str(raw_key)
		if key.begins_with(prefix) and bool(GameState.story_flags.get(key, false)):
			count += 1
	return count


func get_challenge_progress(challenge_id: String) -> Dictionary:
	var definition: Dictionary = ChallengeCatalogScript.get_definition(challenge_id)
	if definition.is_empty():
		return {}
	var target: int = maxi(int(definition.get("target", 1)), 1)
	var reward_id: String = str(definition.get("reward_id", ""))
	var complete: bool = reward_id != "" and GameState.has_unlock(reward_id)
	var current: int = _get_counter(challenge_id)
	if str(definition.get("mode", "")) == "unique":
		current = get_discovery_count("challenge_unique::" + challenge_id)
	if complete:
		current = target
	current = clampi(current, 0, target)
	return {
		"id": challenge_id,
		"current": current,
		"target": target,
		"fraction": float(current) / float(target),
		"complete": complete,
		"reward_id": reward_id,
	}


func get_challenge_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for definition: Dictionary in ChallengeCatalogScript.get_definitions():
		var challenge_id: String = str(definition.get("id", ""))
		var progress: Dictionary = get_challenge_progress(challenge_id)
		var complete: bool = bool(progress.get("complete", false))
		rows.append({
			"id": "progression." + challenge_id,
			"challenge_id": challenge_id,
			"name": str(definition.get("display_name", challenge_id.capitalize())),
			"icon": str(definition.get("icon", "◆")),
			"summary": str(definition.get("description", "Progression challenge.")),
			"status": "UNLOCKED" if complete else "IN PROGRESS",
			"progress_current": int(progress.get("current", 0)),
			"progress_target": int(progress.get("target", 1)),
			"progress_fraction": float(progress.get("fraction", 0.0)),
			"requirement": str(definition.get("requirement", "Complete the challenge.")),
			"reward": "Unlocks: " + str(definition.get("reward_name", "Reward")),
			"details": [
				"Event: " + str(definition.get("event_type", "event")).replace("_", " ").capitalize(),
				"Progress persists with the save slot.",
			],
			"complete": complete,
			"active": not complete,
			"state": "completed" if complete else "active",
			"kind": "challenge",
		})
	return rows


func track_quest(quest_id: String) -> bool:
	var quest: Dictionary = GameState.get_quest(quest_id)
	if quest.is_empty() or str(quest.get("state", "")) != "active":
		return false
	GameState.story_flags[TRACKED_QUEST_KEY] = quest_id
	var objective: String = str(quest.get("objective", ""))
	if objective != "":
		GameState.set_objective(objective)
	tracked_quest_changed.emit(quest_id)
	if GameState.has_method("show_system_message"):
		GameState.call(
			"show_system_message",
			"Tracking quest: " + str(quest.get("title", quest_id.capitalize()))
		)
	return true


func get_tracked_quest_id() -> String:
	return str(GameState.story_flags.get(TRACKED_QUEST_KEY, ""))


func _apply_event_to_challenge(
	definition: Dictionary,
	event_key: String,
	evidence: Dictionary
) -> void:
	var challenge_id: String = str(definition.get("id", ""))
	var mode: String = str(definition.get("mode", "count"))
	var target: int = maxi(int(definition.get("target", 1)), 1)
	var current: int = 0
	match mode:
		"unique":
			record_discovery("challenge_unique::" + challenge_id, event_key, evidence)
			current = get_discovery_count("challenge_unique::" + challenge_id)
		"absolute":
			current = maxi(
				_get_counter(challenge_id),
				int(evidence.get("value", evidence.get("rank", 0)))
			)
			_set_counter(challenge_id, current)
		_:
			current = _get_counter(challenge_id) + maxi(
				int(evidence.get("amount", 1)),
				1
			)
			_set_counter(challenge_id, current)
	current = mini(current, target)
	challenge_progressed.emit(challenge_id, current, target)
	if current >= target:
		_complete_challenge(definition, evidence)


func _complete_challenge(
	definition: Dictionary,
	evidence: Dictionary
) -> void:
	var challenge_id: String = str(definition.get("id", ""))
	var reward_id: String = str(definition.get("reward_id", ""))
	if reward_id == "" or GameState.has_unlock(reward_id):
		return
	var reward: Dictionary = {}
	if definition.get("reward_definition", null) is Dictionary:
		reward = (definition.get("reward_definition", {}) as Dictionary).duplicate(true)
	elif UnlockCatalogScript.has_definition(reward_id):
		reward = UnlockCatalogScript.get_definition(reward_id)
	else:
		reward = {
			"id": reward_id,
			"display_name": str(definition.get("reward_name", reward_id.capitalize())),
			"type": "passive",
			"menu_category": "Challenge Rewards",
			"description": str(definition.get("description", "Challenge reward.")),
			"source": str(definition.get("display_name", challenge_id.capitalize())),
			"tags": ["challenge", challenge_id],
		}
	reward["challenge_id"] = challenge_id
	reward["challenge_evidence"] = evidence.duplicate(true)
	GameState.grant_unlock(reward_id, reward)
	_set_counter(challenge_id, maxi(int(definition.get("target", 1)), 1))
	challenge_completed.emit(challenge_id, reward_id)
	if GameState.has_method("show_system_message"):
		GameState.call(
			"show_system_message",
			"Challenge complete: " + str(definition.get("display_name", challenge_id.capitalize()))
		)


func _connect_game_state() -> void:
	if not GameState.flag_changed.is_connected(_on_flag_changed):
		GameState.flag_changed.connect(_on_flag_changed)
	if not GameState.quest_changed.is_connected(_on_quest_changed):
		GameState.quest_changed.connect(_on_quest_changed)


func _bootstrap_existing_progress() -> void:
	var species: Node = get_node_or_null("/root/SpeciesKnowledge")
	if species != null:
		if species.has_signal("knowledge_changed") and not species.knowledge_changed.is_connected(_on_species_knowledge_changed):
			species.knowledge_changed.connect(_on_species_knowledge_changed)
		if species.has_method("get_all_species_rows"):
			var value: Variant = species.call("get_all_species_rows", true)
			if value is Array:
				for raw: Variant in value as Array:
					if raw is Dictionary:
						var row: Dictionary = raw as Dictionary
						record_event("species_rank", str(row.get("id", "")), {"value": int(row.get("rank", 0)), "bootstrap": true})
	for raw_flag: Variant in GameState.get_story_flags_snapshot().keys():
		var flag_name: String = str(raw_flag)
		if flag_name.begins_with("recipe_discovered_") and GameState.get_flag(flag_name):
			record_event("recipe_discovered", flag_name.trim_prefix("recipe_discovered_"), {"bootstrap": true})


func _on_flag_changed(flag_name: String, value: bool) -> void:
	if value and flag_name.begins_with("recipe_discovered_"):
		record_event("recipe_discovered", flag_name.trim_prefix("recipe_discovered_"), {"source": "game_state_flag"})


func _on_quest_changed(quest_id: String, quest_data: Dictionary) -> void:
	if str(quest_data.get("state", "")) == "completed":
		record_event("quest_completed", quest_id, quest_data)
	if quest_id == get_tracked_quest_id():
		var objective: String = str(quest_data.get("objective", ""))
		if objective != "":
			GameState.set_objective(objective)


func _on_species_knowledge_changed(
	species_id: String,
	_points: int,
	rank: int
) -> void:
	record_event("species_rank", species_id, {"value": rank, "rank": rank})


func _counter_key(challenge_id: String) -> String:
	return COUNTER_PREFIX + challenge_id


func _get_counter(challenge_id: String) -> int:
	return maxi(int(GameState.story_flags.get(_counter_key(challenge_id), 0)), 0)


func _set_counter(challenge_id: String, value: int) -> void:
	GameState.story_flags[_counter_key(challenge_id)] = maxi(value, 0)


func _record_key(category: String, record_id: String) -> String:
	return RECORD_PREFIX + category.strip_edges().to_lower() + "::" + record_id.strip_edges().to_lower()
