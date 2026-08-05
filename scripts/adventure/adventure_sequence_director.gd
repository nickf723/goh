extends Node
class_name AdventureSequenceDirector

signal sequence_initialized(sequence_id: String, chunk_count: int)
signal sequence_started(sequence_id: String)
signal chunk_became_available(chunk_id: String)
signal chunk_became_active(chunk_id: String)
signal chunk_finished(chunk_id: String)
signal sequence_completed(sequence_id: String)
signal sequence_reset(sequence_id: String)
signal graph_validation_failed(sequence_id: String, errors: Array[String])

@export_group("Identity")
@export var sequence_id: String = "adventure_sequence"
@export var display_name: String = "Adventure Sequence"
@export var completion_flag: String = ""

@export_group("Discovery")
@export var chunk_container_path: NodePath = NodePath("AdventureChunks")
@export var auto_initialize: bool = true
@export var auto_start: bool = true

@export_group("Completion")
@export var completion_message: String = ""
@export var objective_on_complete: String = ""
@export var print_debug: bool = false

var scope_root: Node
var chunks: Dictionary = {}
var started: bool = false
var completed: bool = false
var initialized: bool = false
var initializing: bool = false
var validation_errors: Array[String] = []
var availability_passes: int = 0
var completion_order: Array[String] = []


func _ready() -> void:
	add_to_group("adventure_sequence_directors")
	add_to_group("debuggable")
	if auto_initialize:
		call_deferred("initialize_sequence")


func bind_scope(scope_value: Node) -> void:
	scope_root = scope_value


func initialize_sequence() -> bool:
	if initializing:
		return false
	initializing = true
	if scope_root == null or not is_instance_valid(scope_root):
		scope_root = get_parent()
	_disconnect_chunks()
	chunks.clear()
	validation_errors.clear()
	_discover_chunks()
	validation_errors.append_array(validate_graph())
	initialized = validation_errors.is_empty()
	initializing = false
	if not validation_errors.is_empty():
		for error_text: String in validation_errors:
			push_error("AdventureSequenceDirector: " + error_text)
		graph_validation_failed.emit(get_normalized_sequence_id(), validation_errors.duplicate())
		return false
	for chunk_value: Variant in chunks.values():
		var chunk := chunk_value as AdventureChunk
		chunk.sync_from_game_state()
	sequence_initialized.emit(get_normalized_sequence_id(), chunks.size())
	_sync_sequence_completion_from_game_state()
	if auto_start and not completed:
		start_sequence()
	elif completed:
		_update_available_chunks()
	return true


func get_normalized_sequence_id() -> String:
	return AdventureChunkDefinition.normalize_id(sequence_id)


func get_completion_flag() -> String:
	var normalized: String = completion_flag.to_lower().strip_edges().replace(" ", "_")
	if normalized != "":
		return normalized
	var id: String = get_normalized_sequence_id()
	return "adventure_sequence_" + id if id != "" else ""


func start_sequence() -> bool:
	if not initialized:
		if not initialize_sequence():
			return false
	if started or completed:
		return false
	started = true
	sequence_started.emit(get_normalized_sequence_id())
	_update_available_chunks()
	if print_debug:
		print("Adventure sequence started: ", get_debug_data())
	return true


func activate_chunk(chunk_id: String) -> bool:
	var chunk: AdventureChunk = get_chunk(chunk_id)
	if chunk == null:
		return false
	return chunk.activate_chunk()


func complete_chunk(chunk_id: String) -> bool:
	var chunk: AdventureChunk = get_chunk(chunk_id)
	if chunk == null:
		return false
	return chunk.complete_chunk(false)


func fail_chunk(chunk_id: String, reason: String) -> bool:
	var chunk: AdventureChunk = get_chunk(chunk_id)
	if chunk == null:
		return false
	return chunk.fail_chunk(reason)


func get_chunk(chunk_id: String) -> AdventureChunk:
	var normalized: String = AdventureChunkDefinition.normalize_id(chunk_id)
	if not chunks.has(normalized) or not chunks[normalized] is AdventureChunk:
		return null
	return chunks[normalized] as AdventureChunk


func get_chunk_state(chunk_id: String) -> String:
	var chunk: AdventureChunk = get_chunk(chunk_id)
	return chunk.get_state_name() if chunk != null else "MISSING"


func get_active_chunk_ids() -> Array[String]:
	var ids: Array[String] = []
	for chunk_id: Variant in chunks.keys():
		var chunk := chunks[chunk_id] as AdventureChunk
		if chunk.is_active():
			ids.append(str(chunk_id))
	ids.sort()
	return ids


func get_available_chunk_ids() -> Array[String]:
	var ids: Array[String] = []
	for chunk_id: Variant in chunks.keys():
		var chunk := chunks[chunk_id] as AdventureChunk
		if chunk.is_available():
			ids.append(str(chunk_id))
	ids.sort()
	return ids


func get_completed_chunk_ids() -> Array[String]:
	var ids: Array[String] = []
	for chunk_id: Variant in chunks.keys():
		var chunk := chunks[chunk_id] as AdventureChunk
		if chunk.is_complete():
			ids.append(str(chunk_id))
	ids.sort()
	return ids


func reset_sequence(clear_persistence: bool = true) -> void:
	for chunk_value: Variant in chunks.values():
		(chunk_value as AdventureChunk).reset_chunk(clear_persistence)
	if clear_persistence:
		var flag: String = get_completion_flag()
		if flag != "":
			GameState.set_flag(flag, false)
	started = false
	completed = false
	completion_order.clear()
	sequence_reset.emit(get_normalized_sequence_id())
	if auto_start:
		start_sequence()


func validate_graph() -> Array[String]:
	var errors: Array[String] = []
	if get_normalized_sequence_id() == "":
		errors.append("sequence_id is empty")
	if chunks.is_empty():
		errors.append(get_normalized_sequence_id() + " has no chunks")
	for chunk_id: Variant in chunks.keys():
		var chunk := chunks[chunk_id] as AdventureChunk
		if chunk.definition == null:
			errors.append(str(chunk_id) + " has no definition")
			continue
		for dependency_id: String in chunk.get_required_chunk_ids():
			if not chunks.has(dependency_id):
				errors.append(str(chunk_id) + " depends on missing chunk " + dependency_id)
	var visiting: Dictionary = {}
	var visited: Dictionary = {}
	for chunk_id: Variant in chunks.keys():
		_validate_cycle_from(str(chunk_id), visiting, visited, [], errors)
	var content_owners: Dictionary = {}
	for chunk_id: Variant in chunks.keys():
		var chunk := chunks[chunk_id] as AdventureChunk
		for path: NodePath in chunk.managed_content_paths:
			var path_key: String = str(path)
			if path_key == "":
				continue
			if content_owners.has(path_key):
				errors.append(
					"managed content " + path_key + " is owned by both "
					+ str(content_owners[path_key]) + " and " + str(chunk_id)
				)
			else:
				content_owners[path_key] = str(chunk_id)
	return errors


func _discover_chunks() -> void:
	var container: Node = scope_root
	if chunk_container_path != NodePath():
		var resolved: Node = scope_root.get_node_or_null(chunk_container_path)
		if resolved != null:
			container = resolved
	_collect_chunks_recursive(container)


func _collect_chunks_recursive(node: Node) -> void:
	for child: Node in node.get_children():
		if child is AdventureChunk:
			_register_chunk(child as AdventureChunk)
		else:
			_collect_chunks_recursive(child)


func _register_chunk(chunk: AdventureChunk) -> void:
	chunk.bind_scope(scope_root)
	var chunk_id: String = chunk.get_chunk_id()
	if chunk_id == "":
		validation_errors.append("chunk at " + str(chunk.get_path()) + " has an empty id")
		return
	if chunks.has(chunk_id):
		validation_errors.append("duplicate chunk id: " + chunk_id)
		return
	chunks[chunk_id] = chunk
	var available_callback := Callable(self, "_on_chunk_available")
	var active_callback := Callable(self, "_on_chunk_activated")
	var complete_callback := Callable(self, "_on_chunk_completed")
	var failed_callback := Callable(self, "_on_chunk_failed")
	if not chunk.chunk_available.is_connected(available_callback):
		chunk.chunk_available.connect(available_callback)
	if not chunk.chunk_activated.is_connected(active_callback):
		chunk.chunk_activated.connect(active_callback)
	if not chunk.chunk_completed.is_connected(complete_callback):
		chunk.chunk_completed.connect(complete_callback)
	if not chunk.chunk_failed.is_connected(failed_callback):
		chunk.chunk_failed.connect(failed_callback)


func _disconnect_chunks() -> void:
	for chunk_value: Variant in chunks.values():
		if not chunk_value is AdventureChunk:
			continue
		var chunk := chunk_value as AdventureChunk
		var available_callback := Callable(self, "_on_chunk_available")
		var active_callback := Callable(self, "_on_chunk_activated")
		var complete_callback := Callable(self, "_on_chunk_completed")
		var failed_callback := Callable(self, "_on_chunk_failed")
		if chunk.chunk_available.is_connected(available_callback):
			chunk.chunk_available.disconnect(available_callback)
		if chunk.chunk_activated.is_connected(active_callback):
			chunk.chunk_activated.disconnect(active_callback)
		if chunk.chunk_completed.is_connected(complete_callback):
			chunk.chunk_completed.disconnect(complete_callback)
		if chunk.chunk_failed.is_connected(failed_callback):
			chunk.chunk_failed.disconnect(failed_callback)


func _update_available_chunks() -> void:
	if not initialized or not started:
		return
	var changed: bool = true
	var safety: int = maxi(chunks.size() * 3, 3)
	while changed and safety > 0:
		changed = false
		safety -= 1
		availability_passes += 1
		for chunk_value: Variant in chunks.values():
			var chunk := chunk_value as AdventureChunk
			if chunk.state not in [AdventureChunk.State.LOCKED, AdventureChunk.State.AVAILABLE]:
				continue
			if not _dependencies_complete(chunk):
				continue
			if chunk.state == AdventureChunk.State.LOCKED:
				changed = chunk.set_available() or changed
			if (
				chunk.is_available()
				and chunk.definition != null
				and chunk.definition.auto_activate_when_available
			):
				changed = chunk.activate_chunk() or changed
	_check_sequence_completion()


func _dependencies_complete(chunk: AdventureChunk) -> bool:
	for dependency_id: String in chunk.get_required_chunk_ids():
		var dependency: AdventureChunk = get_chunk(dependency_id)
		if dependency == null or not dependency.is_complete():
			return false
	return true


func _check_sequence_completion() -> void:
	if completed or chunks.is_empty():
		return
	var required_count: int = 0
	for chunk_value: Variant in chunks.values():
		var chunk := chunk_value as AdventureChunk
		if chunk.is_optional():
			continue
		required_count += 1
		if not chunk.is_complete():
			return
	if required_count <= 0:
		return
	complete_sequence(false)


func complete_sequence(from_restore: bool = false) -> bool:
	if completed:
		return false
	completed = true
	var flag: String = get_completion_flag()
	if flag != "":
		GameState.set_flag(flag, true)
	if not from_restore and completion_message != "":
		_show_message(completion_message)
	if objective_on_complete != "":
		_set_objective(objective_on_complete)
	sequence_completed.emit(get_normalized_sequence_id())
	return true


func _sync_sequence_completion_from_game_state() -> void:
	var flag: String = get_completion_flag()
	if flag != "" and GameState.get_flag(flag):
		completed = true
		started = true
		return
	completed = false


func _on_chunk_available(chunk_id: String) -> void:
	chunk_became_available.emit(chunk_id)


func _on_chunk_activated(chunk_id: String) -> void:
	chunk_became_active.emit(chunk_id)


func _on_chunk_completed(chunk_id: String) -> void:
	if not completion_order.has(chunk_id):
		completion_order.append(chunk_id)
	chunk_finished.emit(chunk_id)
	if not initializing:
		_update_available_chunks()


func _on_chunk_failed(_chunk_id: String, _reason: String) -> void:
	pass


func _validate_cycle_from(
	chunk_id: String,
	visiting: Dictionary,
	visited: Dictionary,
	path: Array[String],
	errors: Array[String]
) -> void:
	if visited.has(chunk_id):
		return
	if visiting.has(chunk_id):
		var cycle_path: Array[String] = path.duplicate()
		cycle_path.append(chunk_id)
		var error_text: String = "dependency cycle: " + " -> ".join(cycle_path)
		if not errors.has(error_text):
			errors.append(error_text)
		return
	if not chunks.has(chunk_id):
		return
	visiting[chunk_id] = true
	var next_path: Array[String] = path.duplicate()
	next_path.append(chunk_id)
	var chunk := chunks[chunk_id] as AdventureChunk
	for dependency_id: String in chunk.get_required_chunk_ids():
		_validate_cycle_from(dependency_id, visiting, visited, next_path, errors)
	visiting.erase(chunk_id)
	visited[chunk_id] = true


func _show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	else:
		print(text)


func _set_objective(text: String) -> void:
	GameState.set_objective(text)
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("set_objective"):
		ui.call("set_objective", text)


func get_graph_snapshot() -> Dictionary:
	var chunk_rows: Dictionary = {}
	for chunk_id: Variant in chunks.keys():
		chunk_rows[str(chunk_id)] = (chunks[chunk_id] as AdventureChunk).get_debug_data()
	return {
		"sequence_id": get_normalized_sequence_id(),
		"display_name": display_name,
		"started": started,
		"completed": completed,
		"active_chunks": get_active_chunk_ids(),
		"available_chunks": get_available_chunk_ids(),
		"completed_chunks": get_completed_chunk_ids(),
		"completion_order": completion_order.duplicate(),
		"chunks": chunk_rows,
		"validation_errors": validation_errors.duplicate(),
	}


func get_debug_data() -> Dictionary:
	var data: Dictionary = get_graph_snapshot()
	data["initialized"] = initialized
	data["availability_passes"] = availability_passes
	data["completion_flag"] = get_completion_flag()
	return data
