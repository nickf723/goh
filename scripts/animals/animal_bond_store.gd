extends Node
class_name AnimalBondStore

signal record_changed(animal_id: String, record: Dictionary)
signal records_loaded(record_count: int)
signal records_saved(record_count: int)

const STORE_NODE_NAME: String = "AnimalBondStore"
const DEFAULT_SAVE_PATH: String = "user://goh_named_animal_bonds.json"
const STORE_VERSION: int = 2

var save_path: String = DEFAULT_SAVE_PATH
var records: Dictionary = {}
var dirty: bool = false


static func get_or_create(tree: SceneTree, requested_path: String = "") -> AnimalBondStore:
	if tree == null or tree.root == null:
		return null
	var existing: Node = tree.root.get_node_or_null(STORE_NODE_NAME)
	if existing is AnimalBondStore:
		var existing_store := existing as AnimalBondStore
		if requested_path != "" and existing_store.save_path != requested_path:
			existing_store.save_path = requested_path
			existing_store.load_from_disk()
		return existing_store
	var store := AnimalBondStore.new()
	store.name = STORE_NODE_NAME
	if requested_path != "":
		store.save_path = requested_path
	tree.root.add_child(store)
	store.load_from_disk()
	return store


func set_record(animal_id: String, record: Dictionary, save_now: bool = false) -> Dictionary:
	var normalized_id: String = _normalize_id(animal_id)
	if normalized_id == "":
		return {}
	var normalized: Dictionary = _normalize_record(normalized_id, record)
	records[normalized_id] = normalized
	dirty = true
	record_changed.emit(normalized_id, normalized.duplicate(true))
	if save_now:
		save_to_disk()
	return normalized.duplicate(true)


func get_record(animal_id: String) -> Dictionary:
	var normalized_id: String = _normalize_id(animal_id)
	if not records.has(normalized_id) or not records[normalized_id] is Dictionary:
		return {}
	return (records[normalized_id] as Dictionary).duplicate(true)


func has_record(animal_id: String) -> bool:
	return records.has(_normalize_id(animal_id))


func remove_record(animal_id: String, save_now: bool = false) -> bool:
	var normalized_id: String = _normalize_id(animal_id)
	if not records.has(normalized_id):
		return false
	records.erase(normalized_id)
	dirty = true
	record_changed.emit(normalized_id, {})
	if save_now:
		save_to_disk()
	return true


func clear_records(prefix: String = "", save_now: bool = false) -> int:
	var normalized_prefix: String = prefix.to_lower().strip_edges()
	var removed: int = 0
	for key_variant: Variant in records.keys().duplicate():
		var key: String = str(key_variant)
		if normalized_prefix != "" and not key.begins_with(normalized_prefix):
			continue
		records.erase(key)
		record_changed.emit(key, {})
		removed += 1
	if removed > 0:
		dirty = true
	if save_now:
		save_to_disk()
	return removed


func get_snapshot() -> Dictionary:
	return records.duplicate(true)


func export_data() -> Dictionary:
	return {
		"version": STORE_VERSION,
		"records": get_snapshot(),
	}


func import_data(data: Dictionary, save_now: bool = false) -> int:
	records.clear()
	var source: Dictionary = data.get("records", data) as Dictionary
	for key_variant: Variant in source.keys():
		if not source[key_variant] is Dictionary:
			continue
		var animal_id: String = _normalize_id(str(key_variant))
		if animal_id == "":
			continue
		records[animal_id] = _normalize_record(animal_id, source[key_variant] as Dictionary)
	dirty = true
	records_loaded.emit(records.size())
	if save_now:
		save_to_disk()
	return records.size()


func save_to_disk() -> Dictionary:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return {
			"ok": false,
			"message": "Animal bond save failed: " + str(FileAccess.get_open_error()),
		}
	file.store_string(JSON.stringify(export_data(), "\t"))
	file.close()
	dirty = false
	records_saved.emit(records.size())
	return {
		"ok": true,
		"path": save_path,
		"record_count": records.size(),
	}


func load_from_disk() -> bool:
	if not FileAccess.file_exists(save_path):
		records.clear()
		dirty = false
		records_loaded.emit(0)
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not parsed is Dictionary:
		return false
	import_data(parsed as Dictionary, false)
	dirty = false
	return true


func flush_if_dirty() -> Dictionary:
	return save_to_disk() if dirty else {"ok": true, "record_count": records.size()}


func _normalize_record(animal_id: String, record: Dictionary) -> Dictionary:
	var relationship: Dictionary = record.get("relationship", {}) as Dictionary
	var command: Dictionary = record.get("companion_command", {}) as Dictionary
	return {
		"animal_id": animal_id,
		"animal_name": str(record.get("animal_name", animal_id.get_file().capitalize())),
		"species_id": str(record.get("species_id", "unknown")).to_lower().strip_edges(),
		"personality_profile_id": str(record.get("personality_profile_id", "balanced")),
		"relationship": {
			"trust": clampf(float(relationship.get("trust", 0.0)), -1.0, 1.0),
			"familiarity": clampf(float(relationship.get("familiarity", 0.0)), 0.0, 1.0),
			"fear_association": clampf(float(relationship.get("fear_association", 0.0)), 0.0, 1.0),
			"peaceful_exposure": maxf(float(relationship.get("peaceful_exposure", 0.0)), 0.0),
			"last_interaction": str(relationship.get("last_interaction", "none")),
			"interaction_count": maxi(int(relationship.get("interaction_count", 0)), 0),
		},
		"bonded": bool(record.get("bonded", false)),
		"follow_enabled": bool(record.get("follow_enabled", false)),
		"help_events": maxi(int(record.get("help_events", 0)), 0),
		"harm_events": maxi(int(record.get("harm_events", 0)), 0),
		"companion_command": _normalize_companion_command(command),
		"updated_at": Time.get_datetime_string_from_system(false, true),
	}


func _normalize_companion_command(command: Dictionary) -> Dictionary:
	var command_id: String = str(command.get("command_id", "none")).to_lower().strip_edges()
	if command_id not in ["none", "follow", "stay", "come_here", "move_to"]:
		command_id = "none"
	var previous_id: String = str(command.get("previous_command_id", "none")).to_lower().strip_edges()
	if previous_id not in ["none", "follow", "stay"]:
		previous_id = "none"
	return {
		"command_id": command_id,
		"previous_command_id": previous_id,
		"has_anchor": bool(command.get("has_anchor", false)),
		"anchor": _normalize_vector_dictionary(command.get("anchor", {}) as Dictionary),
		"has_destination": bool(command.get("has_destination", false)),
		"destination": _normalize_vector_dictionary(command.get("destination", {}) as Dictionary),
		"last_completed_command_id": str(command.get("last_completed_command_id", "")),
		"completion_count": maxi(int(command.get("completion_count", 0)), 0),
		"sequence": maxi(int(command.get("sequence", 0)), 0),
	}


func _normalize_vector_dictionary(value: Dictionary) -> Dictionary:
	return {
		"x": float(value.get("x", 0.0)),
		"y": float(value.get("y", 0.0)),
		"z": float(value.get("z", 0.0)),
	}


func _normalize_id(value: String) -> String:
	return value.to_lower().strip_edges().replace(" ", "_")
