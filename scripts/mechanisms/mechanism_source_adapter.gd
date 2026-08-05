extends MechanismSignalNode
class_name MechanismSourceAdapter

@export_group("External Source")
@export var external_source_path: NodePath
@export var external_signal_name: StringName
@export var active_property_name: StringName
@export var use_signal_boolean_argument: bool = false
@export_range(0, 3, 1) var signal_boolean_argument_index: int = 0
@export var invert_external_state: bool = false

var external_source: Node
var external_bound: bool = false


func _ready() -> void:
	evaluate_sources_as_or = false
	super._ready()
	call_deferred("bind_exported_external_source")


func _exit_tree() -> void:
	unbind_external_source()
	super._exit_tree()


func bind_exported_external_source() -> bool:
	if external_source_path == NodePath():
		return false
	var source: Node = get_node_or_null(external_source_path)
	if source == null and get_parent() != null:
		source = get_parent().get_node_or_null(external_source_path)
	return bind_external_source(source)


func bind_external_source(source: Node) -> bool:
	unbind_external_source()
	if source == null or not is_instance_valid(source):
		return false
	external_source = source
	if external_signal_name != StringName() and source.has_signal(external_signal_name):
		var callback := Callable(self, "_on_external_signal")
		if not source.is_connected(external_signal_name, callback):
			source.connect(external_signal_name, callback)
		external_bound = true
	elif active_property_name != StringName():
		external_bound = true
	sync_from_external_source()
	return external_bound


func unbind_external_source() -> void:
	if external_source != null and is_instance_valid(external_source):
		if external_signal_name != StringName() and external_source.has_signal(external_signal_name):
			var callback := Callable(self, "_on_external_signal")
			if external_source.is_connected(external_signal_name, callback):
				external_source.disconnect(external_signal_name, callback)
	external_source = null
	external_bound = false


func sync_from_external_source(signal_arguments: Array = []) -> bool:
	if external_source == null or not is_instance_valid(external_source):
		return false
	var next_active: bool = active
	var state_resolved: bool = false
	if active_property_name != StringName() and active_property_name in external_source:
		var property_value: Variant = external_source.get(active_property_name)
		next_active = bool(property_value)
		state_resolved = true
	elif use_signal_boolean_argument and signal_boolean_argument_index < signal_arguments.size():
		next_active = bool(signal_arguments[signal_boolean_argument_index])
		state_resolved = true
	elif external_source.has_method("is_mechanism_active"):
		next_active = bool(external_source.call("is_mechanism_active"))
		state_resolved = true
	if not state_resolved:
		return false
	if invert_external_state:
		next_active = not next_active
	set_mechanism_active(next_active, {
		"reason": "external_source",
		"external_source": str(external_source.get_path()),
		"external_signal": str(external_signal_name),
		"external_property": str(active_property_name),
	})
	return true


func _on_external_signal(
	arg_1: Variant = null,
	arg_2: Variant = null,
	arg_3: Variant = null,
	arg_4: Variant = null
) -> void:
	sync_from_external_source([arg_1, arg_2, arg_3, arg_4])


func reset_target() -> void:
	super.reset_target()
	sync_from_external_source()


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["source_adapter"] = true
	data["external_bound"] = external_bound
	data["external_source"] = str(external_source.get_path()) if external_source != null and is_instance_valid(external_source) else "missing"
	data["external_signal"] = str(external_signal_name)
	data["active_property"] = str(active_property_name)
	return data
