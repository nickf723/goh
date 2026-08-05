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

@export_group("Value Target")
@export var forward_value: bool = false
@export var value_source_id: String = ""
@export var value_target_method: StringName = &"set_mechanism_value"
@export var value_property_name: StringName
@export var use_normalized_value: bool = false
@export var value_scale: float = 1.0
@export var value_offset: float = 0.0
@export var also_apply_boolean_state: bool = false

var target_node: Node
var application_count: int = 0
var value_application_count: int = 0
var last_applied_value: float = 0.0


func _ready() -> void:
	evaluate_sources_as_or = true
	super._ready()
	call_deferred("_resolve_and_apply_target")


func _resolve_and_apply_target() -> void:
	resolve_target()
	if apply_on_ready:
		apply_target_state()


func resolve_target() -> Node:
	if target_node != null and is_instance_valid(target_node):
		return target_node
	if target_path != NodePath():
		target_node = get_node_or_null(target_path)
		if target_node == null and get_parent() != null:
			target_node = get_parent().get_node_or_null(target_path)
	return target_node


func bind_target(target: Node) -> bool:
	target_node = target
	if target_node == null or not is_instance_valid(target_node):
		return false
	apply_target_state()
	return true


func _on_signal_state_applied(_changed: bool) -> void:
	apply_target_state()


func _on_signal_value_applied(_changed: bool) -> void:
	if forward_value:
		apply_target_state()


func apply_target_state() -> bool:
	var target: Node = resolve_target()
	if target == null:
		return false

	var applied_any: bool = false
	if forward_value:
		var value_packet: Dictionary = _build_forwarded_value_packet()
		var target_value: float = float(value_packet.get("forwarded_value", 0.0))
		var value_applied: bool = false
		if (
			value_target_method != StringName()
			and target.has_method(value_target_method)
		):
			target.call(value_target_method, target_value, value_packet)
			value_applied = true
		elif (
			value_property_name != StringName()
			and value_property_name in target
		):
			target.set(value_property_name, target_value)
			value_applied = true
		if value_applied:
			last_applied_value = target_value
			value_application_count += 1
			application_count += 1
			applied_any = true
			if not also_apply_boolean_state:
				return true

	var target_active: bool = not active if invert_target_state else active
	var boolean_applied: bool = false
	if target_method != StringName() and target.has_method(target_method):
		target.call(target_method, target_active, get_mechanism_packet())
		boolean_applied = true
	elif target_active and active_method != StringName() and target.has_method(active_method):
		target.call(active_method)
		boolean_applied = true
	elif not target_active and inactive_method != StringName() and target.has_method(inactive_method):
		target.call(inactive_method)
		boolean_applied = true
	elif bool_property_name != StringName() and bool_property_name in target:
		target.set(bool_property_name, target_active)
		boolean_applied = true
	if boolean_applied:
		application_count += 1
		applied_any = true
	return applied_any


func _build_forwarded_value_packet() -> Dictionary:
	var source_id: String = get_primary_source_id(value_source_id)
	var packet: Dictionary = (
		get_source_packet(source_id)
		if source_id != ""
		else get_mechanism_packet()
	)
	var raw_value: float = (
		get_source_value(source_id)
		if source_id != ""
		else get_mechanism_value()
	)
	var normalized_value: float = (
		get_source_normalized_value(source_id)
		if source_id != ""
		else get_mechanism_normalized_value()
	)
	var selected_value: float = normalized_value if use_normalized_value else raw_value
	var forwarded_value: float = selected_value * value_scale + value_offset
	packet["reason"] = "value_output_adapter"
	packet["adapter_id"] = get_mechanism_id()
	packet["value_source_id"] = source_id
	packet["raw_value"] = raw_value
	packet["normalized_value"] = normalized_value
	packet["selected_value"] = selected_value
	packet["value_scale"] = value_scale
	packet["value_offset"] = value_offset
	packet["forwarded_value"] = forwarded_value
	packet["forwarded_normalized"] = use_normalized_value
	return packet


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
	data["forwards_value"] = forward_value
	data["value_source_id"] = get_primary_source_id(value_source_id)
	data["value_target_method"] = str(value_target_method)
	data["value_applications"] = value_application_count
	data["last_applied_value"] = last_applied_value
	data["uses_normalized_value"] = use_normalized_value
	data["value_scale"] = value_scale
	data["value_offset"] = value_offset
	return data
