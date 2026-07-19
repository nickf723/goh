extends CircuitVoltageSource
class_name RotationalGeneratorSource

signal coupling_changed(is_coupled: bool)

@export var shaft_path: NodePath
@export var starts_coupled: bool = true
@export var minimum_generation_rpm: float = 120.0
@export var volts_per_1000_rpm: float = 12.0
@export var maximum_output_voltage: float = 18.0
@export var voltage_change_deadband: float = 0.03

var shaft: RotationalShaftState
var coupled: bool = true
var last_shaft_rpm: float = 0.0
var generated_voltage: float = 0.0


func _ready() -> void:
	coupled = starts_coupled
	if shaft == null and not shaft_path.is_empty():
		shaft = get_node_or_null(shaft_path) as RotationalShaftState
	reversible = false
	nominal_voltage_volts = 0.0
	path_enabled = coupled
	super._ready()
	component_kind = "rotational_generator"
	update_generated_voltage(true)
	add_to_group("lab_resettable")


func _process(_delta: float) -> void:
	update_generated_voltage()


func configure_shaft(next_shaft: RotationalShaftState) -> void:
	shaft = next_shaft


func get_voltage_for_rpm(rpm: float) -> float:
	if not coupled or absf(rpm) < max(minimum_generation_rpm, 0.0):
		return 0.0
	return min(
		absf(rpm) / 1000.0 * max(volts_per_1000_rpm, 0.0),
		max(maximum_output_voltage, 0.0)
	)


func update_generated_voltage(force_notification: bool = false) -> void:
	var previous_voltage: float = source_voltage_volts
	var previous_path_enabled: bool = path_enabled
	last_shaft_rpm = shaft.current_rpm if shaft != null else 0.0
	generated_voltage = get_voltage_for_rpm(last_shaft_rpm)
	polarity_sign = 1 if last_shaft_rpm >= 0.0 else -1
	nominal_voltage_volts = generated_voltage
	path_enabled = coupled
	refresh_voltage()
	if (
		force_notification
		or absf(source_voltage_volts - previous_voltage) >= max(voltage_change_deadband, 0.001)
		or path_enabled != previous_path_enabled
	):
		notify_topology_changed()


func set_coupled(next_coupled: bool) -> void:
	if coupled == next_coupled:
		return
	coupled = next_coupled
	update_generated_voltage(true)
	coupling_changed.emit(coupled)


func interact() -> Dictionary:
	set_coupled(not coupled)
	return {
		"message": display_name + (" coupled to the circuit." if coupled else " disconnected from the circuit."),
		"objective": "Compare turbine rotation with and without electrical output.",
	}


func reset_target() -> void:
	coupled = starts_coupled
	generated_voltage = 0.0
	last_shaft_rpm = shaft.current_rpm if shaft != null else 0.0
	update_generated_voltage(true)
	apply_circuit_state(false, 0.0, 0.0, -1)
	coupling_changed.emit(coupled)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["rotational_generator"] = true
	data["coupled"] = coupled
	data["shaft_rpm"] = snapped(last_shaft_rpm, 0.1)
	data["generated_voltage"] = snapped(generated_voltage, 0.01)
	data["minimum_generation_rpm"] = minimum_generation_rpm
	return data
