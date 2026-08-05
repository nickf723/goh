extends Node
class_name FamiliarTaskStateStore

signal task_state_changed(task_key: String, state: Dictionary)
signal states_loaded(state_count: int)
signal states_saved(state_count: int)

const STORE_NODE_NAME: String = "FamiliarTaskStateStore"
const DEFAULT_SAVE_PATH: String = "user://goh_familiar_task_states_v1.json"
const STORE_VERSION: int = 1

var save_path: String = DEFAULT_SAVE_PATH
var states: Dictionary = {}
var dirty: bool = false


static func get_or_create(tree: SceneTree, requested_path: String = "") -> FamiliarTaskStateStore:
	if tree == null or tree.root == null:
		return null
	var existing: Node = tree.root.get_node_or_null(STORE_NODE_NAME)
	if existing is FamiliarTaskStateStore:
		var existing_store := existing as FamiliarTaskStateStore
		if requested_path != "" and existing_store.save_path != requested_path:
			existing_store.save_path = requested_path
			existing_store.load_from_disk()
		return existing_store
	var store := FamiliarTaskStateStore.new()
	store.name = STORE_NODE_NAME
	if requested_path != "":
		store.save_path = requested_path
	tree.root.add_child(store)
	store.load_from_disk()
	return store


func set_task_state(task_key: String, state: Dictionary, save_now: bool = false) -> Dictionary:
	var normalized_key: String = _normalize_key(task_key)
	if normalized_key == "":
		return {}
	var normalized: Dictionary = _normalize_state(normalized_key, state)
	states[normalized_key] = normalized
	dirty = true
	task_state_changed.emit(normalized_key, normalized.duplicate(true))
	if save_now:
		save_to_disk()
	return normalized.duplicate(true)


func mark_completed(
	task_key: String,
	task_id: String,
	familiar_id: String = "",
	extra: Dictionary = {},
	save_now: bool = true
) -> Dictionary:
	var state: Dictionary = extra.duplicate(true)
	state["task_id"] = task_id
	state["completed"] = true
	state["familiar_id"] = familiar_id
	return set_task_state(task_key, state, save_now)


func get_task_state(task_key: String) -> Dictionary:
	var normalized_key: String = _normalize_key(task_key)
	if not states.has(normalized_key) or not states[normalized_key] is Dictionary:
		return {}
	return (states[normalized_key] as Dictionary).duplicate(true)


func is_completed(task_key: String) -> bool:
	return bool(get_task_state(task_key).get("completed", false))


func remove_task_state(task_key: String, save_now: bool = false) -> bool:
	var normalized_key: String = _normalize_key(task_key)
	if not states.has(normalized_key):
		return false
	states.erase(normalized_key)
	dirty = true
	task_state_changed.emit(normalized_key, {})
	if save_now:
		save_to_disk()
	return true


func clear_states(prefix: String = "", save_now: bool = false) -> int:
	var normalized_prefix: String = _normalize_key(prefix)
	var removed: int = 0
	for key_variant: Variant in states.keys().duplicate():
		var key: String = str(key_variant)
		if normalized_prefix != "" and not key.begins_with(normalized_prefix):
			continue
		states.erase(key)
		task_state_changed.emit(key, {})
		removed += 1
	if removed > 0:
		dirty = true
	if save_now:
		save_to_disk()
	return removed


func get_snapshot() -> Dictionary:
	return states.duplicate(true)


func export_data() -> Dictionary:
	return {
		"version": STORE_VERSION,
		"states": get_snapshot(),
	}


func import_data(data: Dictionary, save_now: bool = false) -> int:
	states.clear()
	var source: Dictionary = data.get("states", data) as Dictionary
	for key_variant: Variant in source.keys():
		if not source[key_variant] is Dictionary:
			continue
		var task_key: String = _normalize_key(str(key_variant))
		if task_key == "":
			continue
		states[task_key] = _normalize_state(task_key, source[key_variant] as Dictionary)
	dirty = true
	states_loaded.emit(states.size())
	if save_now:
		save_to_disk()
	return states.size()


func save_to_disk() -> Dictionary:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return {
			"ok": false,
			"message": "Familiar task save failed: " + str(FileAccess.get_open_error()),
		}
	file.store_string(JSON.stringify(export_data(), "\t"))
	file.close()
	dirty = false
	states_saved.emit(states.size())
	return {
		"ok": true,
		"path": save_path,
		"state_count": states.size(),
	}


func load_from_disk() -> bool:
	if not FileAccess.file_exists(save_path):
		states.clear()
		dirty = false
		states_loaded.emit(0)
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not parsed is Dictionary:
		return false
	import_data(parsed as Dictionary, false)
	dirty = false
	return true


func flush_if_dirty() -> Dictionary:
	return save_to_disk() if dirty else {"ok": true, "state_count": states.size()}


func _normalize_state(task_key: String, state: Dictionary) -> Dictionary:
	var normalized: Dictionary = state.duplicate(true)
	normalized["task_key"] = task_key
	normalized["task_id"] = str(state.get("task_id", "task")).to_lower().strip_edges()
	normalized["completed"] = bool(state.get("completed", false))
	normalized["familiar_id"] = str(state.get("familiar_id", "")).to_lower().strip_edges()
	normalized["updated_at"] = Time.get_datetime_string_from_system(false, true)
	return normalized


func _normalize_key(value: String) -> String:
	return value.to_lower().strip_edges().replace(" ", "_")
