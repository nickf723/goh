extends CircuitComponent
class_name CircuitVoltageSource

@export var nominal_voltage_volts: float = 12.0
@export var reversible: bool = true
@export var initial_polarity: int = 1

var polarity_sign: int = 1


func _ready() -> void:
	is_voltage_source = true
	component_kind = "voltage_source"
	polarity_sign = 1 if initial_polarity >= 0 else -1
	refresh_voltage()
	super._ready()


func reverse_polarity() -> void:
	if not reversible:
		return
	polarity_sign *= -1
	refresh_voltage()
	notify_topology_changed()


func refresh_voltage() -> void:
	source_voltage_volts = abs(nominal_voltage_volts) * float(polarity_sign)


func interact() -> Dictionary:
	reverse_polarity()
	return {
		"message": display_name + " polarity reversed.",
		"objective": "Complete the conductive loop and observe current direction.",
	}


func reset_target() -> void:
	polarity_sign = 1 if initial_polarity >= 0 else -1
	refresh_voltage()
	apply_circuit_state(false, 0.0, 0.0, -1)
	notify_topology_changed()


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["polarity"] = polarity_sign
	return data
