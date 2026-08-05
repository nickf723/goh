extends MechanismSignalNode
class_name MechanismOutputAdapter

@export_group("Target")
@export var target_path: NodePath
@export var target_method: StringName = &"set_mechanism_active"
@export var active_method: StringName
@export var inactive_method: StringName
@export var bool_property_name: StringName
@export var invert_target_state: bool = false
@export var apply_on_ready: bool = true

var target_node: Node
var application_count: int = 0


func _ready() -> void:
	evaluate_sources_as_or = true
	super._ready()
	call_deferred("resolve_target")


func resolve_target() -> Node:
	if target_node != null and is_instance_valid(target_node):
		return target_node
	if target_path != NodePath():
		target_node = get_node_or_null(target_path)
		if target_node == null and get_parent() != null:
			target_node = get_parent().get_node_or_null(target_path)
	if apply_on_ready and target_node != null:
		apply_target_state()
	return target_node


func bind_target(target: Node) -> bool:
	target_node = target
	if target_node == null or not is_instance_valid(target_node):
		return false
	apply_target_state()
	return true


func _on_signal_state_applied(_changed: bool) -> void:
	apply_target_state()


func apply_target_state() -> bool:
	var target: Node = resolve_target()
	if target == null:
		return false
	var target_active: bool = not active if invert_target_state else active
	var applied: bool = false
	if target_method != StringName() and target.has_method(target_method):
		target.call(target_method, target_active, get_mechanism_packet())
		applied = true
	elif target_active and active_method != StringName() and target.has_method(active_method):
		target.call(active_method)
		applied = true
	elif not target_active and inactive_method != StringName() and target.has_method(inactive_method):
		target.call(inactive_method)
		applied = true
	elif bool_property_name != StringName() and bool_property_name in target:
		target.set(bool_property_name, target_active)
		applied = true
	if applied:
		application_count += 1
	return applied


func reset_target() -> void:
	super.reset_target()
	apply_target_state()


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["output_adapter"] = true
	data["target"] = str(target_node.get_path()) if target_node != null and is_instance_valid(target_node) else "missing"
	data["target_method"] = str(target_method)
	data["applications"] = application_count
	data["inverted"] = invert_target_state
	return data
