extends Node
class_name AdventureChunk

signal state_changed(chunk_id: String, previous_state: int, new_state: int)
signal chunk_available(chunk_id: String)
signal chunk_activated(chunk_id: String)
signal requirement_changed(chunk_id: String, requirement_id: String, complete: bool, detail: Dictionary)
signal chunk_completed(chunk_id: String)
signal chunk_failed(chunk_id: String, reason: String)
signal chunk_reset(chunk_id: String)

enum State {
	LOCKED,
	AVAILABLE,
	ACTIVE,
	COMPLETED,
	FAILED,
}

@export var definition: AdventureChunkDefinition
@export var managed_content_paths: Array[NodePath] = []
@export var auto_bind_requirements: bool = true
@export var print_debug: bool = false

var scope_root: Node
var state: State = State.LOCKED
var requirements: Dictionary = {}
var initialized: bool = false
var requirements_bound: bool = false
var activation_count: int = 0
var completion_count: int = 0
var failure_reason: String = ""


func _ready() -> void:
	add_to_group("adventure_chunks")
	add_to_group("debuggable")
	call_deferred("initialize_chunk")


func bind_scope(scope_value: Node) -> void:
	scope_root = scope_value
	if is_inside_tree():
		initialize_chunk()


func initialize_chunk() -> void:
	if initialized and requirements_bound:
		return
	if definition == null:
		push_error("AdventureChunk has no definition: " + str(get_path()))
		return
	for error_text: String in definition.validate_definition():
		push_error("AdventureChunkDefinition: " + error_text)
	if scope_root == null or not is_instance_valid(scope_root):
		scope_root = get_parent()
	initialized = true
	if auto_bind_requirements:
		_bind_requirements()
	sync_from_game_state()
	_apply_content_for_state()


func get_chunk_id() -> String:
	return definition.get_normalized_id() if definition != null else ""


func get_required_chunk_ids() -> Array[String]:
	return definition.get_normalized_dependencies() if definition != null else []


func is_optional() -> bool:
	return definition != null and definition.optional


func is_complete() -> bool:
	return state == State.COMPLETED


func is_active() -> bool:
	return state == State.ACTIVE


func is_available() -> bool:
	return state == State.AVAILABLE


func can_activate() -> bool:
	return state == State.AVAILABLE or (
		definition != null
		and definition.allow_replay
		and state == State.COMPLETED
	)


func set_available() -> bool:
	initialize_chunk()
	if state == State.COMPLETED or state == State.ACTIVE or state == State.AVAILABLE:
		return false
	_set_state(State.AVAILABLE)
	_apply_content_for_state()
	if definition != null and definition.objective_on_available != "":
		_set_objective(definition.objective_on_available)
	chunk_available.emit(get_chunk_id())
	return true


func activate_chunk() -> bool:
	initialize_chunk()
	if not can_activate():
		return false
	if state == State.COMPLETED and definition != null and definition.allow_replay:
		_reset_requirement_states(false)
	_set_state(State.ACTIVE)
	failure_reason = ""
	activation_count += 1
	_apply_content_for_state()
	_sync_requirements()
	if definition != null:
		if definition.activation_message != "":
			_show_message(definition.activation_message)
		if definition.objective_on_activate != "":
			_set_objective(definition.objective_on_activate)
	chunk_activated.emit(get_chunk_id())
	_evaluate_completion()
	if print_debug:
		print("Adventure chunk activated: ", get_debug_data())
	return true


func complete_chunk(from_restore: bool = false) -> bool:
	initialize_chunk()
	if state == State.COMPLETED:
		return false
	if state == State.LOCKED and not from_restore:
		return false
	_set_state(State.COMPLETED)
	completion_count += 1
	failure_reason = ""
	if definition != null:
		var completion_flag: String = definition.get_completion_flag()
		if completion_flag != "":
			GameState.set_flag(completion_flag, true)
		if not from_restore and definition.reward_mana > 0:
			GameState.restore_mana(definition.reward_mana)
		if not from_restore and definition.completion_message != "":
			_show_message(definition.completion_message)
		if definition.objective_on_complete != "":
			_set_objective(definition.objective_on_complete)
	_apply_content_for_state()
	chunk_completed.emit(get_chunk_id())
	if print_debug:
		print("Adventure chunk completed: ", get_debug_data())
	return true


func fail_chunk(reason: String = "Chunk failed.") -> bool:
	if state not in [State.ACTIVE, State.AVAILABLE]:
		return false
	failure_reason = reason
	_set_state(State.FAILED)
	_apply_content_for_state()
	chunk_failed.emit(get_chunk_id(), reason)
	return true


func reset_chunk(clear_persistence: bool = true) -> void:
	initialize_chunk()
	if clear_persistence and definition != null:
		var completion_flag: String = definition.get_completion_flag()
		if completion_flag != "":
			GameState.set_flag(completion_flag, false)
	failure_reason = ""
	_reset_requirement_states(true)
	_set_state(State.LOCKED)
	_apply_content_for_state()
	chunk_reset.emit(get_chunk_id())


func sync_from_game_state() -> void:
	if definition == null:
		return
	var completion_flag: String = definition.get_completion_flag()
	if completion_flag != "" and GameState.get_flag(completion_flag):
		if state != State.COMPLETED:
			complete_chunk(true)
		return
	if state == State.COMPLETED:
		_set_state(State.LOCKED)
	_apply_content_for_state()


func register_requirement(
	requirement_id: String,
	optional: bool = false,
	display_name: String = ""
) -> void:
	var normalized: String = AdventureChunkDefinition.normalize_id(requirement_id)
	if normalized == "":
		return
	var existing: Dictionary = (
		(requirements[normalized] as Dictionary).duplicate(true)
		if requirements.has(normalized) and requirements[normalized] is Dictionary
		else {}
	)
	existing["requirement_id"] = normalized
	existing["display_name"] = display_name if display_name != "" else normalized.replace("_", " ").capitalize()
	existing["optional"] = optional
	existing["complete"] = bool(existing.get("complete", false))
	existing["detail"] = (existing.get("detail", {}) as Dictionary).duplicate(true)
	requirements[normalized] = existing


func report_requirement(
	requirement_id: String,
	complete: bool,
	detail: Dictionary = {}
) -> void:
	var normalized: String = AdventureChunkDefinition.normalize_id(requirement_id)
	if normalized == "":
		return
	if not requirements.has(normalized):
		register_requirement(normalized)
	var row: Dictionary = (requirements[normalized] as Dictionary).duplicate(true)
	var changed: bool = bool(row.get("complete", false)) != complete
	row["complete"] = complete
	row["detail"] = detail.duplicate(true)
	requirements[normalized] = row
	if changed:
		requirement_changed.emit(get_chunk_id(), normalized, complete, detail.duplicate(true))
	_evaluate_completion()


func get_requirement_snapshot() -> Dictionary:
	return requirements.duplicate(true)


func get_required_requirement_count() -> int:
	var count: int = 0
	for value: Variant in requirements.values():
		if value is Dictionary and not bool((value as Dictionary).get("optional", false)):
			count += 1
	return count


func get_completed_requirement_count() -> int:
	var count: int = 0
	for value: Variant in requirements.values():
		if not value is Dictionary:
			continue
		var row: Dictionary = value as Dictionary
		if not bool(row.get("optional", false)) and bool(row.get("complete", false)):
			count += 1
	return count


func _bind_requirements() -> void:
	if requirements_bound:
		return
	requirements_bound = true
	for child: Node in get_children():
		if child.has_method("bind_chunk"):
			child.call("bind_chunk", self, scope_root)


func _sync_requirements() -> void:
	for child: Node in get_children():
		if child.has_method("sync_requirement"):
			child.call("sync_requirement")


func _reset_requirement_states(sync_after: bool) -> void:
	for requirement_id: Variant in requirements.keys():
		var row: Dictionary = (requirements[requirement_id] as Dictionary).duplicate(true)
		row["complete"] = false
		row["detail"] = {}
		requirements[requirement_id] = row
	for child: Node in get_children():
		if child.has_method("reset_requirement"):
			child.call("reset_requirement")
	if sync_after:
		_sync_requirements()


func _evaluate_completion() -> void:
	if state != State.ACTIVE or definition == null:
		return
	if definition.completion_policy == AdventureChunkDefinition.CompletionPolicy.MANUAL:
		return
	var required_count: int = get_required_requirement_count()
	if required_count <= 0:
		return
	var complete_count: int = get_completed_requirement_count()
	if (
		definition.completion_policy == AdventureChunkDefinition.CompletionPolicy.ALL_REQUIREMENTS
		and complete_count >= required_count
	):
		complete_chunk(false)
	elif (
		definition.completion_policy == AdventureChunkDefinition.CompletionPolicy.ANY_REQUIREMENT
		and complete_count > 0
	):
		complete_chunk(false)


func _set_state(next_state: State) -> void:
	if state == next_state:
		return
	var previous_state: State = state
	state = next_state
	state_changed.emit(get_chunk_id(), int(previous_state), int(state))


func _apply_content_for_state() -> void:
	if definition == null:
		return
	var content_enabled: bool = state == State.ACTIVE
	var content_visible: bool = state == State.ACTIVE
	if state == State.COMPLETED and definition.keep_content_after_complete:
		content_enabled = true
		content_visible = true
	elif state in [State.LOCKED, State.AVAILABLE]:
		content_enabled = not definition.disable_content_when_locked
		content_visible = not definition.hide_content_when_locked
	elif state == State.FAILED:
		content_enabled = true
		content_visible = true
	for path: NodePath in managed_content_paths:
		var content: Node = _resolve_scope_node(path)
		if content != null:
			_set_content_enabled_recursive(content, content_enabled, content_visible)


func _resolve_scope_node(path: NodePath) -> Node:
	if scope_root == null or not is_instance_valid(scope_root):
		return null
	if path == NodePath():
		return scope_root
	return scope_root.get_node_or_null(path)


func _set_content_enabled_recursive(node: Node, enabled: bool, visible: bool) -> void:
	if not node.has_meta("adventure_chunk_original_process_mode"):
		node.set_meta("adventure_chunk_original_process_mode", int(node.process_mode))
	node.process_mode = (
		int(node.get_meta("adventure_chunk_original_process_mode", Node.PROCESS_MODE_INHERIT))
		if enabled
		else Node.PROCESS_MODE_DISABLED
	)
	if node is Node3D:
		var node_3d := node as Node3D
		if not node.has_meta("adventure_chunk_original_visible"):
			node.set_meta("adventure_chunk_original_visible", node_3d.visible)
		node_3d.visible = bool(node.get_meta("adventure_chunk_original_visible", true)) if visible else false
	elif node is CanvasItem:
		var canvas_item := node as CanvasItem
		if not node.has_meta("adventure_chunk_original_visible"):
			node.set_meta("adventure_chunk_original_visible", canvas_item.visible)
		canvas_item.visible = bool(node.get_meta("adventure_chunk_original_visible", true)) if visible else false
	if node is CollisionObject3D:
		var collision := node as CollisionObject3D
		if not node.has_meta("adventure_chunk_original_layer"):
			node.set_meta("adventure_chunk_original_layer", collision.collision_layer)
			node.set_meta("adventure_chunk_original_mask", collision.collision_mask)
		collision.collision_layer = int(node.get_meta("adventure_chunk_original_layer", 1)) if enabled else 0
		collision.collision_mask = int(node.get_meta("adventure_chunk_original_mask", 1)) if enabled else 0
	for child: Node in node.get_children():
		_set_content_enabled_recursive(child, enabled, visible)


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


func get_state_name() -> String:
	return State.keys()[int(state)]


func get_debug_data() -> Dictionary:
	return {
		"chunk_id": get_chunk_id(),
		"display_name": definition.display_name if definition != null else "Missing Definition",
		"state": get_state_name(),
		"dependencies": get_required_chunk_ids(),
		"optional": is_optional(),
		"requirements": get_requirement_snapshot(),
		"required_count": get_required_requirement_count(),
		"completed_required_count": get_completed_requirement_count(),
		"activation_count": activation_count,
		"completion_count": completion_count,
		"failure_reason": failure_reason,
		"content_paths": managed_content_paths.duplicate(),
	}
