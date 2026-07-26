extends RefCounted
class_name ExpeditionRecordStore

const DEFAULT_RECORD_PATH: String = "user://expedition_cypress_blue_ridge.json"
const RECORD_VERSION: int = 1


static func load_or_create(
	route_id: String,
	default_seed: int,
	record_path: String = DEFAULT_RECORD_PATH
) -> Dictionary:
	var loaded: Dictionary = load_record(record_path)
	if not loaded.is_empty() and str(loaded.get("route_id", "")) == route_id:
		return normalize_record(loaded, route_id, default_seed)
	var created: Dictionary = create_record(route_id, default_seed)
	save_record(created, record_path)
	return created


static func create_record(route_id: String, seed_value: int) -> Dictionary:
	return {
		"version": RECORD_VERSION,
		"route_id": route_id,
		"seed": seed_value,
		"segment_plan": [],
		"discoveries": {},
		"completed_forward": false,
		"completed_round_trip": false,
		"shortcut_unlocked": false,
	}


static func normalize_record(record: Dictionary, route_id: String, default_seed: int) -> Dictionary:
	var normalized: Dictionary = record.duplicate(true)
	normalized["version"] = RECORD_VERSION
	normalized["route_id"] = route_id
	normalized["seed"] = int(normalized.get("seed", default_seed))
	if not normalized.get("segment_plan", []) is Array:
		normalized["segment_plan"] = []
	if not normalized.get("discoveries", {}) is Dictionary:
		normalized["discoveries"] = {}
	normalized["completed_forward"] = bool(normalized.get("completed_forward", false))
	normalized["completed_round_trip"] = bool(normalized.get("completed_round_trip", false))
	normalized["shortcut_unlocked"] = bool(normalized.get("shortcut_unlocked", false))
	return normalized


static func load_record(record_path: String = DEFAULT_RECORD_PATH) -> Dictionary:
	if not FileAccess.file_exists(record_path):
		return {}
	var file: FileAccess = FileAccess.open(record_path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


static func save_record(
	record: Dictionary,
	record_path: String = DEFAULT_RECORD_PATH
) -> bool:
	var file: FileAccess = FileAccess.open(record_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(record, "\t"))
	return true


static func delete_record(record_path: String = DEFAULT_RECORD_PATH) -> void:
	if FileAccess.file_exists(record_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(record_path))
