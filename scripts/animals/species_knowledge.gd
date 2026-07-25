extends Node

signal knowledge_changed(species_id: String, points: int, rank: int)
signal discovery_recorded(species_id: String, discovery_id: String, label: String)
signal unlock_earned(species_id: String, unlock_id: String, label: String)

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

var knowledge_points: Dictionary = {}
var discoveries: Dictionary = {}
var earned_unlocks: Dictionary = {}


func add_discovery(species_id: String, discovery_id: String, label: String, points: int = 1) -> Dictionary:
	if not SPECIES.has(species_id):
		return {}
	_ensure_species(species_id)
	var known: Dictionary = discoveries[species_id]
	var is_new: bool = not known.has(discovery_id)
	if is_new:
		known[discovery_id] = label
		discoveries[species_id] = known
		knowledge_points[species_id] = int(knowledge_points[species_id]) + maxi(points, 0)
		discovery_recorded.emit(species_id, discovery_id, label)
		_evaluate_unlocks(species_id)
	var result := get_species_data(species_id)
	result["new_discovery"] = is_new
	result["discovery_label"] = label
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


func get_next_threshold(species_id: String) -> int:
	if not SPECIES.has(species_id):
		return 0
	var rank: int = get_rank(species_id)
	var thresholds: Array = SPECIES[species_id].get("rank_thresholds", [0])
	return int(thresholds[rank + 1]) if rank + 1 < thresholds.size() else int(thresholds.back())


func has_unlock(species_id: String, unlock_id: String) -> bool:
	_ensure_species(species_id)
	return (earned_unlocks.get(species_id, {}) as Dictionary).has(unlock_id)


func reset_species(species_id: String) -> void:
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
	knowledge_changed.emit(species_id, int(knowledge_points.get(species_id, 0)), rank)


func get_rank_without_ensure(species_id: String) -> int:
	var points: int = int(knowledge_points.get(species_id, 0))
	var thresholds: Array = SPECIES[species_id].get("rank_thresholds", [0])
	var rank: int = 0
	for index: int in range(thresholds.size()):
		if points >= int(thresholds[index]):
			rank = index
	return rank
