extends Node

signal knowledge_changed(species_id: String, points: int, rank: int)
signal discovery_recorded(species_id: String, discovery_id: String, label: String)
signal unlock_earned(species_id: String, unlock_id: String, label: String)

const SNAPSHOT_VERSION: int = 1

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
}

# Presentation data stays beside the progression definition so the Field Kit can
# render useful notes without inventing a second bestiary database.
const SPECIES_PRESENTATION: Dictionary = {
	"goose": {
		"icon": "🪿",
		"category": "Animal",
		"summary": "A social waterfowl whose gait, food choices, trust, and alarm behavior can be studied.",
		"rank_titles": [
			"Sighted",
			"Recognized",
			"Understood",
			"Bonded",
			"Mastered",
		],
	},
}

var knowledge_points: Dictionary = {}
var discoveries: Dictionary = {}
var earned_unlocks: Dictionary = {}


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
			label
			if label.strip_edges() != ""
			else discovery_id.replace("_", " ").capitalize()
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
		row["summary"] = str(
			presentation.get(
				"summary",
				"Field observations will gradually clarify this species."
			)
		)
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
			0
			if bool(row["is_max_rank"])
			else maxi(int(row.get("next_threshold", 0)) - int(row.get("points", 0)), 0)
		)
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
	}
	for row: Dictionary in get_all_species_rows(true):
		summary["species_total"] = int(summary["species_total"]) + 1
		summary["observations"] = (
			int(summary["observations"]) + int(row.get("discovery_count", 0))
		)
		summary["unlocks_earned"] = (
			int(summary["unlocks_earned"]) + int(row.get("unlock_count", 0))
		)
		summary["unlocks_total"] = (
			int(summary["unlocks_total"]) + int(row.get("unlock_total", 0))
		)
		if bool(row.get("observed", false)):
			summary["species_observed"] = int(summary["species_observed"]) + 1
		if bool(row.get("is_max_rank", false)):
			summary["species_mastered"] = int(summary["species_mastered"]) + 1
	return summary


func get_snapshot() -> Dictionary:
	var point_snapshot: Dictionary = {}
	var discovery_snapshot: Dictionary = {}
	for species_id_variant: Variant in SPECIES.keys():
		var species_id: String = str(species_id_variant)
		point_snapshot[species_id] = maxi(
			int(knowledge_points.get(species_id, 0)),
			0
		)
		var known_value: Variant = discoveries.get(species_id, {})
		discovery_snapshot[species_id] = (
			(known_value as Dictionary).duplicate(true)
			if known_value is Dictionary
			else {}
		)
	return {
		"version": SNAPSHOT_VERSION,
		"knowledge_points": point_snapshot,
		"discoveries": discovery_snapshot,
	}


func apply_snapshot(snapshot: Dictionary) -> Dictionary:
	knowledge_points.clear()
	discoveries.clear()
	earned_unlocks.clear()
	var saved_points: Dictionary = {}
	var saved_discoveries: Dictionary = {}
	var point_value: Variant = snapshot.get("knowledge_points", {})
	var discovery_value: Variant = snapshot.get("discoveries", {})
	if point_value is Dictionary:
		saved_points = point_value as Dictionary
	if discovery_value is Dictionary:
		saved_discoveries = discovery_value as Dictionary
	for species_id_variant: Variant in SPECIES.keys():
		var species_id: String = str(species_id_variant)
		knowledge_points[species_id] = maxi(
			int(saved_points.get(species_id, 0)),
			0
		)
		var clean_discoveries: Dictionary = {}
		var saved_species_value: Variant = saved_discoveries.get(species_id, {})
		if saved_species_value is Dictionary:
			var saved_species: Dictionary = saved_species_value as Dictionary
			for discovery_id_variant: Variant in saved_species.keys():
				var discovery_id: String = str(discovery_id_variant)
				if discovery_id.strip_edges() == "":
					continue
				var label: String = str(saved_species[discovery_id_variant])
				clean_discoveries[discovery_id] = (
					label
					if label.strip_edges() != ""
					else discovery_id.replace("_", " ").capitalize()
				)
		discoveries[species_id] = clean_discoveries
		earned_unlocks[species_id] = {}
		_evaluate_unlocks(species_id)
	return get_summary()


func reset_all() -> void:
	for species_id_variant: Variant in SPECIES.keys():
		reset_species(str(species_id_variant))


func get_rank(species_id: String) -> int:
	if not SPECIES.has(species_id):
		return 0
	_ensure_species(species_id)
	var points: int = int(knowledge_points[species_id])
	var thresholds: Array = SPECIES[species_id].get("rank_thresholds", [0])
	var rank: int = 0
	for index: int in range(thresholds.size()):
		if points >= int(thresholds[index]):
			rank = index
	return rank


func get_rank_title(species_id: String) -> String:
	if not SPECIES.has(species_id):
		return "Unknown"
	var rank: int = get_rank(species_id)
	var presentation: Dictionary = SPECIES_PRESENTATION.get(species_id, {})
	var titles_value: Variant = presentation.get("rank_titles", [])
	if titles_value is Array:
		var titles: Array = titles_value as Array
		if not titles.is_empty():
			return str(titles[clampi(rank, 0, titles.size() - 1)])
	return "Rank " + str(rank)


func get_next_threshold(species_id: String) -> int:
	if not SPECIES.has(species_id):
		return 0
	var rank: int = get_rank(species_id)
	var thresholds: Array = SPECIES[species_id].get("rank_thresholds", [0])
	return (
		int(thresholds[rank + 1])
		if rank + 1 < thresholds.size()
		else int(thresholds.back())
	)


func get_next_unlock(species_id: String) -> Dictionary:
	if not SPECIES.has(species_id):
		return {}
	var unlock_list: Array = SPECIES[species_id].get("unlocks", [])
	var next_index: int = get_rank(species_id) + 1
	if next_index < 0 or next_index >= unlock_list.size():
		return {}
	var next_value: Variant = unlock_list[next_index]
	return (
		(next_value as Dictionary).duplicate(true)
		if next_value is Dictionary
		else {}
	)


func has_unlock(species_id: String, unlock_id: String) -> bool:
	if not SPECIES.has(species_id):
		return false
	_ensure_species(species_id)
	return (earned_unlocks.get(species_id, {}) as Dictionary).has(unlock_id)


func reset_species(species_id: String) -> void:
	if not SPECIES.has(species_id):
		return
	knowledge_points[species_id] = 0
	discoveries[species_id] = {}
	earned_unlocks[species_id] = {}
	_evaluate_unlocks(species_id)
	knowledge_changed.emit(species_id, 0, 0)


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
	var definition: Dictionary = SPECIES[species_id]
	var rank: int = get_rank_without_ensure(species_id)
	var unlock_list: Array = definition.get("unlocks", [])
	var current: Dictionary = earned_unlocks.get(species_id, {})
	for index: int in range(mini(rank + 1, unlock_list.size())):
		var unlock_data: Dictionary = unlock_list[index]
		var unlock_id: String = str(unlock_data.get("id", ""))
		if unlock_id == "" or current.has(unlock_id):
			continue
		current[unlock_id] = str(unlock_data.get("label", unlock_id.capitalize()))
		unlock_earned.emit(species_id, unlock_id, str(current[unlock_id]))
	earned_unlocks[species_id] = current
	knowledge_changed.emit(
		species_id,
		int(knowledge_points.get(species_id, 0)),
		rank
	)


func get_rank_without_ensure(species_id: String) -> int:
	var points: int = int(knowledge_points.get(species_id, 0))
	var thresholds: Array = SPECIES[species_id].get("rank_thresholds", [0])
	var rank: int = 0
	for index: int in range(thresholds.size()):
		if points >= int(thresholds[index]):
			rank = index
	return rank


func _sort_species_rows(a: Dictionary, b: Dictionary) -> bool:
	var a_category: String = str(a.get("category", "Species"))
	var b_category: String = str(b.get("category", "Species"))
	if a_category == b_category:
		return str(a.get("name", "")) < str(b.get("name", ""))
	return a_category < b_category
