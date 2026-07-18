extends Area3D
class_name CircuitSourceSelector

signal source_mode_changed(mode: String)

@export_enum("battery", "lightning", "off") var initial_mode: String = "battery"

var battery_source: CircuitVoltageSource
var excitation_port: CircuitExcitationPort
var source_mode: String = "battery"


func _ready() -> void:
	add_to_group("debuggable")
	add_to_group("lab_resettable")
	source_mode = initial_mode
	apply_mode()


func configure_sources(
	battery: CircuitVoltageSource,
	port: CircuitExcitationPort
) -> void:
	battery_source = battery
	excitation_port = port
	apply_mode()


func cycle_mode() -> void:
	match source_mode:
		"battery":
			set_mode("lightning")
		"lightning":
			set_mode("off")
		_:
			set_mode("battery")


func set_mode(next_mode: String) -> void:
	if next_mode not in ["battery", "lightning", "off"]:
		return
	source_mode = next_mode
	apply_mode()
	source_mode_changed.emit(source_mode)


func apply_mode() -> void:
	if battery_source != null:
		battery_source.path_enabled = source_mode == "battery"
		battery_source.notify_topology_changed()
	if excitation_port != null:
		excitation_port.path_enabled = source_mode == "lightning"
		if source_mode != "lightning":
			excitation_port.clear_excitation()
		else:
			excitation_port.notify_topology_changed()
	update_label()


func update_label() -> void:
	var label: Label3D = get_node_or_null("StateLabel") as Label3D
	if label == null:
		return
	match source_mode:
		"battery":
			label.text = "SOURCE SELECTOR\nBATTERY"
		"lightning":
			label.text = "SOURCE SELECTOR\nLIGHTNING INPUT"
		_:
			label.text = "SOURCE SELECTOR\nOFF"


func interact() -> Dictionary:
	cycle_mode()
	return {
		"message": "Circuit source selected: " + source_mode.capitalize() + ".",
		"objective": "Power the same circuit with a battery, a Lightning spell, or environmental Lightning.",
	}


func reset_target() -> void:
	set_mode(initial_mode)


func get_debug_data() -> Dictionary:
	return {
		"source_selector": source_mode,
		"battery_enabled": battery_source.path_enabled if battery_source != null else false,
		"lightning_port_enabled": excitation_port.path_enabled if excitation_port != null else false,
	}
