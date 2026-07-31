extends Node

signal knowledge_changed(species_id: String, points: int, rank: int)
signal discovery_recorded(species_id: String, discovery_id: String, label: String)
signal unlock_earned(species_id: String, unlock_id: String, label: String)
signal familiar_loadout_changed(species_id: String, loadout: Dictionary)
signal equipped_familiar_changed(species_id: String)

const SNAPSHOT_VERSION: int = 2

const SPECIES: Dictionary = {
	"goose": {
		"name": "Goose",
		"rank_thresholds": [0, 3, 7, 12, 18],
		"unlocks": [
			{"id": "goose_codex", "label": "Goose Codex"},
			{"id": "goose_familiar", "label": "Goose Familiar Form"},
			{"id": "alarm_cry", "label": "Alarm Cry Capability"},
			{"id": "migratory_wings", "label": "Migratory Flight Capability"},
			{"id": "goose_transformation", "label": "Goose Transformation"},
		],
	},
	"gremlin": {
		"name": "Gremlin",
		"rank_thresholds": [0, 2, 5, 9, 14],
		"unlocks": [
			{"id": "gremlin_codex", "label": "Gremlin Field Record"},
			{"id": "gremlin_familiar", "label": "Gremlin Familiar"},
			{"id": "gremlin_pounce", "label": "Pounce Technique"},
			{"id": "gremlin_mire_spit", "label": "Mire Spit Technique"},
			{"id": "gremlin_transformation", "label": "Gremlin Transformation"},
		],
		"familiar": {
			"unlock_id": "gremlin_familiar",
			"presence_cost": 1,
			"roles": ["skirmisher", "primer"],
			"temperaments": ["cautious", "balanced", "bold"],
			"commands": ["RALLY", "FOCUS", "ASSIST", "HOLD"],
			"max_techniques": 3,
			"default_role": "skirmisher",
			"default_temperament": "balanced",
			"default_command": "ASSIST",
			"default_techniques": ["bite", "backstep"],
			"techniques": [
				{
					"id": "bite",
					"label": "Bite",
					"unlock_id": "gremlin_familiar",
					"description": "Fast close-range pressure inherited from wild gremlins.",
				},
				{
					"id": "backstep",
					"label": "Backstep",
					"unlock_id": "gremlin_familiar",
					"description": "Retreats from crowded melee and opens a pressure lane.",
				},
				{
					"id": "pounce",
					"label": "Pounce",
					"unlock_id": "gremlin_pounce",
					"description": "Committed gap-closing strike learned by surviving the attack.",
				},
				{
					"id": "mire_spit",
					"label": "Mire Spit",
					"unlock_id": "gremlin_mire_spit",
					"description": "Ranged Water setup that applies Wet for allied payoffs.",
				},
			],
		},
	},
}

const SPECIES_PRESENTATION: Dictionary = {
	"goose": {
		"icon": "🪿",
		"category": "Animal",
		"summary": "A social waterfowl whose gait, food choices, trust, and alarm behavior can be studied.",
		"rank_titles": ["Sighted", "Recognized", "Understood", "Bonded", "Mastered"],
	},
	"gremlin": {
		"icon": "◇",
		"category": "Monster",
		"summary": "A quick social scavenger whose evasive movement and pack tactics can be learned, summoned, and eventually embodied.",
		"rank_titles": ["Sighted", "Tracked", "Understood", "Bonded", "Mastered"],
	},
}

var knowledge_points: Dictionary = {}
var discoveries: Dictionary = {}
var earned_unlocks: Dictionary = {}
var familiar_loadouts: Dictionary = {}
var equipped_familiar_species_id: String = ""


func add_discovery(
	species_id: String,
	discovery_id: String,
	label: String,
	points: int = 1
) -> Dictionary:
	if not SPECIES.has(species_id) or discovery_id.strip_edges() == "":
		return {}
	_ensure_species(species_id)
	var known: Dictionary = discoveries[species_id]
	var is_new: bool = not known.has(discovery_id)
	if is_new:
		known[discovery_id] = (
			label if label.strip_edges() != "" else discovery_id.replace("_", " ").capitalize()
		)
		discoveries[species_id] = known
		knowledge_points[species_id] = int(knowledge_points[species_id]) + maxi(points, 0)
		discovery_recorded.emit(species_id, discovery_id, str(known[discovery_id]))
		_evaluate_unlocks(species_id)
	var result: Dictionary = get_species_data(species_id)
	result["new_discovery"] = is_new
	result["discovery_label"] = str(known.get(discovery_id, label))
	return result


func get_species_data(species_id: String) -> Dictionary:
	if not SPECIES.has(species_id):
		return {}
	_ensure_species(species_id)
	var definition: Dictionary = SPECIES[species_id]
	return {
		"id": species_id,
		"name": definition.get("name", species_id.capitalize()),
		"points": int(knowledge_points[species_id]),
		"rank": get_rank(species_id),
		"discoveries": (discoveries[species_id] as Dictionary).duplicate(true),
		"unlocks": (earned_unlocks[species_id] as Dictionary).duplicate(true),
		"next_threshold": get_next_threshold(species_id),
	}


func get_all_species_rows(include_unobserved: bool = true) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for species_id_variant: Variant in SPECIES.keys():
		var species_id: String = str(species_id_variant)
		var row: Dictionary = get_species_data(species_id)
		var discovery_map: Dictionary = row.get("discoveries", {})
		var unlock_map: Dictionary = row.get("unlocks", {})
		var definition: Dictionary = SPECIES[species_id]
		var thresholds: Array = definition.get("rank_thresholds", [0])
		var unlock_definitions: Array = definition.get("unlocks", [])
		var presentation: Dictionary = SPECIES_PRESENTATION.get(species_id, {})
		var discovery_labels: Array[String] = []
		var unlock_labels: Array[String] = []
		for value: Variant in discovery_map.values():
			discovery_labels.append(str(value))
		for value: Variant in unlock_map.values():
			unlock_labels.append(str(value))
		discovery_labels.sort()
		unlock_labels.sort()
		var rank: int = int(row.get("rank", 0))
		var maximum_rank: int = maxi(thresholds.size() - 1, 0)
		var next_unlock: Dictionary = get_next_unlock(species_id)
		row["icon"] = str(presentation.get("icon", "◇"))
		row["category"] = str(presentation.get("category", "Species"))
		row["summary"] = str(presentation.get("summary", "Field observations will gradually clarify this species."))
		row["rank_title"] = get_rank_title(species_id)
		row["max_rank"] = maximum_rank
		row["is_max_rank"] = rank >= maximum_rank
		row["observed"] = not discovery_map.is_empty()
		row["discovery_count"] = discovery_map.size()
		row["discovery_labels"] = discovery_labels
		row["unlock_count"] = unlock_map.size()
		row["unlock_total"] = unlock_definitions.size()
		row["unlock_labels"] = unlock_labels
		row["next_unlock_id"] = str(next_unlock.get("id", ""))
		row["next_unlock_label"] = str(next_unlock.get("label", ""))
		row["points_to_next"] = (
			0 if bool(row["is_max_rank"]) else maxi(int(row.get("next_threshold", 0)) - int(row.get("points", 0)), 0)
		)
		row["has_familiar"] = definition.get("familiar", null) is Dictionary
		row["familiar_unlocked"] = is_familiar_unlocked(species_id)
		if include_unobserved or bool(row["observed"]):
			rows.append(row)
	rows.sort_custom(_sort_species_rows)
	return rows


func get_summary() -> Dictionary:
	var summary: Dictionary = {
		"species_total": 0,
		"species_observed": 0,
		"observations": 0,
		"unlocks_earned": 0,
		"unlocks_total": 0,
		"species_mastered": 0,
		"familiars_available": 0,
		"familiars_unlocked": 0,
	}
	for row: Dictionary in get_all_species_rows(true):
		summary["species_total"] = int(summary["species_total"]) + 1
		summary["observations"] = int(summary["observations"]) + int(row.get("discovery_count", 0))
		summary["unlocks_earned"] = int(summary["unlocks_earned"]) + int(row.get("unlock_count", 0))
		summary["unlocks_total"] = int(summary["unlocks_total"]) + int(row.get("unlock_total", 0))
		if bool(row.get("observed", false)):
			summary["species_observed"] = int(summary["species_observed"]) + 1
		if bool(row.get("is_max_rank", false)):
			summary["species_mastered"] = int(summary["species_mastered"]) + 1
		if bool(row.get("has_familiar", false)):
			summary["familiars_available"] = int(summary["familiars_available"]) + 1
		if bool(row.get("familiar_unlocked", false)):
			summary["familiars_unlocked"] = int(summary["familiars_unlocked"]) + 1
	return summary


func get_snapshot() -> Dictionary:
	var point_snapshot: Dictionary = {}
	var discovery_snapshot: Dictionary = {}
	var loadout_snapshot: Dictionary = {}
	for species_id_variant: Variant in SPECIES.keys():
		var species_id: String = str(species_id_variant)
		point_snapshot[species_id] = maxi(int(knowledge_points.get(species_id, 0)), 0)
		var known_value: Variant = discoveries.get(species_id, {})
		discovery_snapshot[species_id] = (
			(known_value as Dictionary).duplicate(true) if known_value is Dictionary else {}
		)
		if _get_familiar_definition(species_id) != null:
			loadout_snapshot[species_id] = get_familiar_loadout(species_id)
	return {
		"version": SNAPSHOT_VERSION,
		"knowledge_points": point_snapshot,
		"discoveries": discovery_snapshot,
		"familiar_loadouts": loadout_snapshot,
		"equipped_familiar_species_id": equipped_familiar_species_id,
	}


func apply_snapshot(snapshot: Dictionary) -> Dictionary:
	knowledge_points.clear()
	discoveries.clear()
	earned_unlocks.clear()
	familiar_loadouts.clear()
	equipped_familiar_species_id = ""
	var saved_points: Dictionary = _dictionary(snapshot.get("knowledge_points", {}))
	var saved_discoveries: Dictionary = _dictionary(snapshot.get("discoveries", {}))
	for species_id_variant: Variant in SPECIES.keys():
		var species_id: String = str(species_id_variant)
		knowledge_points[species_id] = maxi(int(saved_points.get(species_id, 0)), 0)
		var clean_discoveries: Dictionary = {}
		var saved_species: Dictionary = _dictionary(saved_discoveries.get(species_id, {}))
		for discovery_id_variant: Variant in saved_species.keys():
			var discovery_id: String = str(discovery_id_variant)
			if discovery_id.strip_edges() == "":
				continue
			var saved_label: String = str(saved_species[discovery_id_variant])
			clean_discoveries[discovery_id] = (
				saved_label if saved_label.strip_edges() != "" else discovery_id.replace("_", " ").capitalize()
			)
		discoveries[species_id] = clean_discoveries
		earned_unlocks[species_id] = {}
		_evaluate_unlocks(species_id)
	var saved_loadouts: Dictionary = _dictionary(snapshot.get("familiar_loadouts", {}))
	for species_id_variant: Variant in SPECIES.keys():
		var species_id: String = str(species_id_variant)
		if _get_familiar_definition(species_id) == null:
			continue
		familiar_loadouts[species_id] = _sanitize_familiar_loadout(
			species_id,
			_dictionary(saved_loadouts.get(species_id, {}))
		)
	var equipped: String = str(snapshot.get("equipped_familiar_species_id", ""))
	if equipped != "" and is_familiar_unlocked(equipped):
		equipped_familiar_species_id = equipped
	return get_summary()


func reset_all() -> void:
	for species_id_variant: Variant in SPECIES.keys():
		reset_species(str(species_id_variant))
	equipped_familiar_species_id = ""
	equipped_familiar_changed.emit("")


func reset_species(species_id: String) -> void:
	if not SPECIES.has(species_id):
		return
	knowledge_points[species_id] = 0
	discoveries[species_id] = {}
	earned_unlocks[species_id] = {}
	familiar_loadouts.erase(species_id)
	if equipped_familiar_species_id == species_id:
		equipped_familiar_species_id = ""
		equipped_familiar_changed.emit("")
	_evaluate_unlocks(species_id)
	knowledge_changed.emit(species_id, 0, 0)


func get_rank(species_id: String) -> int:
	if not SPECIES.has(species_id):
		return 0
	_ensure_species(species_id)
	return get_rank_without_ensure(species_id)


func get_rank_title(species_id: String) -> String:
	if not SPECIES.has(species_id):
		return "Unknown"
	var rank: int = get_rank(species_id)
	var presentation: Dictionary = SPECIES_PRESENTATION.get(species_id, {})
	var titles_value: Variant = presentation.get("rank_titles", [])
	if titles_value is Array and not (titles_value as Array).is_empty():
		var titles: Array = titles_value as Array
		return str(titles[clampi(rank, 0, titles.size() - 1)])
	return "Rank " + str(rank)


func get_next_threshold(species_id: String) -> int:
	if not SPECIES.has(species_id):
		return 0
	var rank: int = get_rank(species_id)
	var thresholds: Array = SPECIES[species_id].get("rank_thresholds", [0])
	if rank + 1 < thresholds.size():
		return int(thresholds[rank + 1])
	return int(thresholds.back())


func get_next_unlock(species_id: String) -> Dictionary:
	if not SPECIES.has(species_id):
		return {}
	var unlock_list: Array = SPECIES[species_id].get("unlocks", [])
	var next_index: int = get_rank(species_id) + 1
	if next_index < 0 or next_index >= unlock_list.size():
		return {}
	var next_value: Variant = unlock_list[next_index]
	return (next_value as Dictionary).duplicate(true) if next_value is Dictionary else {}


func has_unlock(species_id: String, unlock_id: String) -> bool:
	if not SPECIES.has(species_id):
		return false
	_ensure_species(species_id)
	return _dictionary(earned_unlocks.get(species_id, {})).has(unlock_id)


func is_familiar_unlocked(species_id: String) -> bool:
	var definition: Dictionary = _get_familiar_definition(species_id)
	if definition.is_empty():
		return false
	return has_unlock(species_id, str(definition.get("unlock_id", "")))


func get_familiar_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for species_id_variant: Variant in SPECIES.keys():
		var species_id: String = str(species_id_variant)
		var familiar_definition: Dictionary = _get_familiar_definition(species_id)
		if familiar_definition.is_empty():
			continue
		var presentation: Dictionary = SPECIES_PRESENTATION.get(species_id, {})
		var loadout: Dictionary = get_familiar_loadout(species_id)
		var technique_rows: Array[Dictionary] = []
		for technique_value: Variant in familiar_definition.get("techniques", []):
			if not technique_value is Dictionary:
				continue
			var technique: Dictionary = (technique_value as Dictionary).duplicate(true)
			var technique_id: String = str(technique.get("id", ""))
			var unlock_id: String = str(technique.get("unlock_id", ""))
			technique["unlocked"] = unlock_id == "" or has_unlock(species_id, unlock_id)
			technique["equipped"] = _string_array(loadout.get("technique_ids", [])).has(technique_id)
			technique_rows.append(technique)
		rows.append({
			"species_id": species_id,
			"display_name": str(SPECIES[species_id].get("name", species_id.capitalize())),
			"icon": str(presentation.get("icon", "◇")),
			"summary": str(presentation.get("summary", "")),
			"rank": get_rank(species_id),
			"rank_title": get_rank_title(species_id),
			"unlocked": is_familiar_unlocked(species_id),
			"equipped": equipped_familiar_species_id == species_id,
			"presence_cost": int(familiar_definition.get("presence_cost", 1)),
			"roles": _string_array(familiar_definition.get("roles", [])),
			"temperaments": _string_array(familiar_definition.get("temperaments", [])),
			"commands": _string_array(familiar_definition.get("commands", [])),
			"max_techniques": int(familiar_definition.get("max_techniques", 1)),
			"loadout": loadout,
			"techniques": technique_rows,
		})
	return rows


func get_familiar_loadout(species_id: String) -> Dictionary:
	var definition: Dictionary = _get_familiar_definition(species_id)
	if definition.is_empty():
		return {}
	var saved: Dictionary = _dictionary(familiar_loadouts.get(species_id, {}))
	var sanitized: Dictionary = _sanitize_familiar_loadout(species_id, saved)
	familiar_loadouts[species_id] = sanitized
	return sanitized.duplicate(true)


func get_equipped_familiar_species_id() -> String:
	return equipped_familiar_species_id


func get_equipped_familiar_loadout() -> Dictionary:
	if equipped_familiar_species_id == "":
		return {}
	var loadout: Dictionary = get_familiar_loadout(equipped_familiar_species_id)
	loadout["species_id"] = equipped_familiar_species_id
	return loadout


func set_equipped_familiar_species(species_id: String) -> Dictionary:
	if species_id == "":
		equipped_familiar_species_id = ""
		equipped_familiar_changed.emit("")
		return {"ok": true, "species_id": ""}
	if not is_familiar_unlocked(species_id):
		return {"ok": false, "error": "Familiar is not unlocked"}
	equipped_familiar_species_id = species_id
	get_familiar_loadout(species_id)
	equipped_familiar_changed.emit(species_id)
	return {"ok": true, "species_id": species_id}


func cycle_familiar_role(species_id: String, direction: int = 1) -> Dictionary:
	return _cycle_familiar_field(species_id, "role", "roles", direction)


func cycle_familiar_temperament(species_id: String, direction: int = 1) -> Dictionary:
	return _cycle_familiar_field(species_id, "temperament", "temperaments", direction)


func cycle_familiar_command(species_id: String, direction: int = 1) -> Dictionary:
	return _cycle_familiar_field(species_id, "command", "commands", direction)


func toggle_familiar_technique(species_id: String, technique_id: String) -> Dictionary:
	var definition: Dictionary = _get_familiar_definition(species_id)
	if definition.is_empty() or not is_familiar_unlocked(species_id):
		return {"ok": false, "error": "Familiar is not unlocked"}
	var technique: Dictionary = _find_technique(definition, technique_id)
	if technique.is_empty():
		return {"ok": false, "error": "Unknown technique"}
	var unlock_id: String = str(technique.get("unlock_id", ""))
	if unlock_id != "" and not has_unlock(species_id, unlock_id):
		return {"ok": false, "error": "Technique is not unlocked"}
	var loadout: Dictionary = get_familiar_loadout(species_id)
	var techniques: Array[String] = _string_array(loadout.get("technique_ids", []))
	if techniques.has(technique_id):
		if techniques.size() <= 1:
			return {"ok": false, "error": "At least one technique must remain equipped"}
		techniques.erase(technique_id)
	else:
		var maximum: int = maxi(int(definition.get("max_techniques", 1)), 1)
		if techniques.size() >= maximum:
			return {"ok": false, "error": "Technique capacity is full"}
		techniques.append(technique_id)
	loadout["technique_ids"] = techniques
	familiar_loadouts[species_id] = loadout
	familiar_loadout_changed.emit(species_id, loadout.duplicate(true))
	return {"ok": true, "loadout": loadout.duplicate(true)}


func get_rank_without_ensure(species_id: String) -> int:
	var points: int = int(knowledge_points.get(species_id, 0))
	var thresholds: Array = SPECIES[species_id].get("rank_thresholds", [0])
	var rank: int = 0
	for index: int in range(thresholds.size()):
		if points >= int(thresholds[index]):
			rank = index
	return rank


func _ensure_species(species_id: String) -> void:
	if not knowledge_points.has(species_id):
		knowledge_points[species_id] = 0
	if not discoveries.has(species_id):
		discoveries[species_id] = {}
	if not earned_unlocks.has(species_id):
		earned_unlocks[species_id] = {}
	_evaluate_unlocks(species_id)


func _evaluate_unlocks(species_id: String) -> void:
	if not SPECIES.has(species_id):
		return
	var rank: int = get_rank_without_ensure(species_id)
	var unlock_list: Array = SPECIES[species_id].get("unlocks", [])
	var current: Dictionary = _dictionary(earned_unlocks.get(species_id, {}))
	for index: int in range(mini(rank + 1, unlock_list.size())):
		var unlock_value: Variant = unlock_list[index]
		if not unlock_value is Dictionary:
			continue
		var unlock_data: Dictionary = unlock_value as Dictionary
		var unlock_id: String = str(unlock_data.get("id", ""))
		if unlock_id == "" or current.has(unlock_id):
			continue
		current[unlock_id] = str(unlock_data.get("label", unlock_id.capitalize()))
		unlock_earned.emit(species_id, unlock_id, str(current[unlock_id]))
	earned_unlocks[species_id] = current
	knowledge_changed.emit(species_id, int(knowledge_points.get(species_id, 0)), rank)


func _get_familiar_definition(species_id: String) -> Dictionary:
	if not SPECIES.has(species_id):
		return {}
	var value: Variant = (SPECIES[species_id] as Dictionary).get("familiar", {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _sanitize_familiar_loadout(species_id: String, raw: Dictionary) -> Dictionary:
	var definition: Dictionary = _get_familiar_definition(species_id)
	if definition.is_empty():
		return {}
	var roles: Array[String] = _string_array(definition.get("roles", []))
	var temperaments: Array[String] = _string_array(definition.get("temperaments", []))
	var commands: Array[String] = _string_array(definition.get("commands", []))
	var role: String = str(raw.get("role", definition.get("default_role", "skirmisher"))).to_lower()
	var temperament: String = str(raw.get("temperament", definition.get("default_temperament", "balanced"))).to_lower()
	var command: String = str(raw.get("command", definition.get("default_command", "ASSIST"))).to_upper()
	if not roles.has(role):
		role = str(definition.get("default_role", roles[0] if not roles.is_empty() else "skirmisher"))
	if not temperaments.has(temperament):
		temperament = str(definition.get("default_temperament", temperaments[0] if not temperaments.is_empty() else "balanced"))
	if not commands.has(command):
		command = str(definition.get("default_command", commands[0] if not commands.is_empty() else "ASSIST"))
	var requested: Array[String] = _string_array(raw.get("technique_ids", definition.get("default_techniques", [])))
	var available: Array[String] = []
	for technique_value: Variant in definition.get("techniques", []):
		if not technique_value is Dictionary:
			continue
		var technique: Dictionary = technique_value as Dictionary
		var technique_id: String = str(technique.get("id", ""))
		var unlock_id: String = str(technique.get("unlock_id", ""))
		if technique_id != "" and (unlock_id == "" or has_unlock(species_id, unlock_id)):
			available.append(technique_id)
	var selected: Array[String] = []
	for technique_id: String in requested:
		if available.has(technique_id) and not selected.has(technique_id):
			selected.append(technique_id)
	var maximum: int = maxi(int(definition.get("max_techniques", 1)), 1)
	while selected.size() > maximum:
		selected.pop_back()
	if selected.is_empty() and not available.is_empty():
		selected.append(available[0])
	return {
		"role": role,
		"temperament": temperament,
		"command": command,
		"technique_ids": selected,
		"presence_cost": int(definition.get("presence_cost", 1)),
	}


func _cycle_familiar_field(
	species_id: String,
	field_name: String,
	definition_field: String,
	direction: int
) -> Dictionary:
	var definition: Dictionary = _get_familiar_definition(species_id)
	if definition.is_empty() or not is_familiar_unlocked(species_id):
		return {"ok": false, "error": "Familiar is not unlocked"}
	var values: Array[String] = _string_array(definition.get(definition_field, []))
	if values.is_empty():
		return {"ok": false, "error": "No options are authored"}
	var loadout: Dictionary = get_familiar_loadout(species_id)
	var current: String = str(loadout.get(field_name, values[0]))
	var index: int = values.find(current)
	if index < 0:
		index = 0
	index = wrapi(index + (1 if direction >= 0 else -1), 0, values.size())
	loadout[field_name] = values[index]
	familiar_loadouts[species_id] = loadout
	familiar_loadout_changed.emit(species_id, loadout.duplicate(true))
	return {"ok": true, "loadout": loadout.duplicate(true)}


func _find_technique(definition: Dictionary, technique_id: String) -> Dictionary:
	for technique_value: Variant in definition.get("techniques", []):
		if technique_value is Dictionary and str((technique_value as Dictionary).get("id", "")) == technique_id:
			return (technique_value as Dictionary).duplicate(true)
	return {}


func _sort_species_rows(a: Dictionary, b: Dictionary) -> bool:
	var a_category: String = str(a.get("category", "Species"))
	var b_category: String = str(b.get("category", "Species"))
	if a_category == b_category:
		return str(a.get("name", "")) < str(b.get("name", ""))
	return a_category < b_category


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value as Array:
			var text: String = str(raw)
			if text != "" and not result.has(text):
				result.append(text)
	return result
