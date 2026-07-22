extends Node
class_name ComponentResetAdapter

@export var reset_signal_source_path: NodePath = NodePath("..")
@export var reset_signal_name: String = "reset_completed"
@export var component_paths: Array[NodePath] = []
@export var reset_method_name: String = "reset_target"

var reset_signal_source: Node = null
var last_reset_count: int = 0


func _ready() -> void:
	resolve_signal_source()
	connect_reset_signal()
	add_to_group("debuggable")


func resolve_signal_source() -> void:
	reset_signal_source = get_node_or_null(reset_signal_source_path)


func connect_reset_signal() -> void:
	if reset_signal_source == null:
		push_warning(name + " could not find reset signal source at " + str(reset_signal_source_path))
		return

	if not reset_signal_source.has_signal(reset_signal_name):
		push_warning(name + " could not find signal " + reset_signal_name)
		return

	var callback: Callable = Callable(self, "reset_components")

	if not reset_signal_source.is_connected(reset_signal_name, callback):
		reset_signal_source.connect(reset_signal_name, callback)


func reset_components() -> void:
	last_reset_count = 0

	for component_path: NodePath in component_paths:
		var component: Node = get_node_or_null(component_path)

		if component == null:
			push_warning(name + " could not reset missing component at " + str(component_path))
			continue

		if not component.has_method(reset_method_name):
			push_warning(component.name + " does not provide " + reset_method_name)
			continue

		component.call(reset_method_name)
		last_reset_count += 1


func get_debug_data() -> Dictionary:
	return {
		"component_reset_adapter": true,
		"signal": reset_signal_name,
		"method": reset_method_name,
		"configured_components": component_paths.size(),
		"last_reset_count": last_reset_count,
	}
