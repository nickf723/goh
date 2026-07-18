extends CircuitComponent
class_name CircuitSwitch

@export var starts_closed: bool = true


func _ready() -> void:
	component_kind = "switch"
	path_enabled = starts_closed
	super._ready()


func toggle_switch() -> void:
	path_enabled = not path_enabled
	notify_topology_changed()


func interact() -> Dictionary:
	toggle_switch()
	return {
		"message": display_name + (" closed." if path_enabled else " opened."),
		"objective": "Complete the conductive loop and observe current direction.",
	}


func reset_target() -> void:
	path_enabled = starts_closed
	apply_circuit_state(false, 0.0, 0.0, -1)
	notify_topology_changed()


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["closed"] = path_enabled
	return data
