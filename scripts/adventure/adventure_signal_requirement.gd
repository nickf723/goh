extends Node
class_name AdventureSignalRequirement

signal requirement_status_changed(requirement_id: String, complete: bool, detail: Dictionary)

@export_group("Requirement")
@export var requirement_id: String = "requirement"
@export var display_name: String = "Requirement"
@export var optional: bool = false
@export var complete_on_signal: bool = true

@export_group("Source")
@export var source_path: NodePath
@export var source_signal: StringName
@export var source_property: StringName
@export var expected_boolean_value: bool = true
@export var source_reset_method: StringName

var chunk: Node
var scope_root: Node
var source_node: Node
var complete: bool = false
var bound: bool = false
var last_detail: Dictionary = {}


func _ready() -> void:
	add_to_group("adventure_chunk_requirements")
	add_to_group("debuggable")


func _exit_tree() -> void:
	_disconnect_source()


func bind_chunk(chunk_value: Node, scope_value: Node) -> bool:
	chunk = chunk_value
	scope_root = scope_value
	var normalized_id: String = get_normalized_id()
	if chunk == null or normalized_id == "":
		return false
	if chunk.has_method("register_requirement"):
		chunk.call("register_requirement", normalized_id, optional, display_name)
	_resolve_source()
	bound = source_node != null
	sync_requirement()
	return bound


func get_normalized_id() -> String:
	return AdventureChunkDefinition.normalize_id(requirement_id)


func sync_requirement() -> bool:
	if source_node == null or not is_instance_valid(source_node):
		_resolve_source()
	if source_node == null:
		return false
	if source_property != StringName() and source_property in source_node:
		var property_value: Variant = source_node.get(source_property)
		set_requirement_complete(bool(property_value) == expected_boolean_value, {
			"source": str(source_node.get_path()),
			"property": str(source_property),
			"value": property_value,
		})
	return complete


func set_requirement_complete(value: bool, detail: Dictionary = {}) -> void:
	var changed: bool = complete != value
	complete = value
	last_detail = detail.duplicate(true)
	if chunk != null and is_instance_valid(chunk) and chunk.has_method("report_requirement"):
		chunk.call("report_requirement", get_normalized_id(), complete, last_detail)
	if changed:
		requirement_status_changed.emit(get_normalized_id(), complete, last_detail.duplicate(true))


func reset_requirement() -> void:
	if source_node == null or not is_instance_valid(source_node):
		_resolve_source()
	if (
		source_node != null
		and source_reset_method != StringName()
		and source_node.has_method(source_reset_method)
	):
		source_node.call(source_reset_method)
	complete = false
	last_detail.clear()
	if chunk != null and is_instance_valid(chunk) and chunk.has_method("report_requirement"):
		chunk.call("report_requirement", get_normalized_id(), false, {})
	sync_requirement()


func _resolve_source() -> void:
	_disconnect_source()
	if scope_root == null or not is_instance_valid(scope_root):
		return
	if source_path == NodePath():
		source_node = scope_root
	else:
		source_node = scope_root.get_node_or_null(source_path)
	if source_node == null:
		return
	if source_signal == StringName() or not source_node.has_signal(source_signal):
		return
	var callback := Callable(self, "_on_source_signal")
	if not source_node.is_connected(source_signal, callback):
		source_node.connect(source_signal, callback)


func _disconnect_source() -> void:
	if source_node == null or not is_instance_valid(source_node):
		source_node = null
		return
	if source_signal != StringName() and source_node.has_signal(source_signal):
		var callback := Callable(self, "_on_source_signal")
		if source_node.is_connected(source_signal, callback):
			source_node.disconnect(source_signal, callback)
	source_node = null


func _on_source_signal(
	arg_1: Variant = null,
	arg_2: Variant = null,
	arg_3: Variant = null,
	arg_4: Variant = null
) -> void:
	if not complete_on_signal:
		sync_requirement()
		return
	set_requirement_complete(true, {
		"source": str(source_node.get_path()) if source_node != null and is_instance_valid(source_node) else "missing",
		"signal": str(source_signal),
		"arguments": [arg_1, arg_2, arg_3, arg_4],
	})


func get_debug_data() -> Dictionary:
	return {
		"requirement_id": get_normalized_id(),
		"display_name": display_name,
		"optional": optional,
		"complete": complete,
		"bound": bound,
		"source_path": str(source_path),
		"source_signal": str(source_signal),
		"source_property": str(source_property),
		"source_reset_method": str(source_reset_method),
		"source_found": source_node != null and is_instance_valid(source_node),
		"detail": last_detail.duplicate(true),
	}
