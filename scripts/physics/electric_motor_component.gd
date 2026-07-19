extends CircuitComponent
class_name ElectricMotorComponent

signal running_state_changed(is_running: bool)
signal winding_changed(winding_sign: int)

@export var shaft_path: NodePath
@export var minimum_activation_amps: float = 0.05
@export var rpm_per_amp: float = 420.0
@export var maximum_output_rpm: float = 1600.0
@export var initial_winding_sign: int = 1

var shaft: RotationalShaftState
var winding_sign: int = 1
var running: bool = false
var target_output_rpm: float = 0.0
var last_electrical_power_w: float = 0.0


func _ready() -> void:
	component_kind = "electric_motor"
	winding_sign = 1 if initial_winding_sign >= 0 else -1
	if shaft == null and not shaft_path.is_empty():
		shaft = get_node_or_null(shaft_path) as RotationalShaftState
	super._ready()
	add_to_group("lab_resettable")
	update_motor_drive()


func configure_shaft(next_shaft: RotationalShaftState) -> void:
	shaft = next_shaft
	update_motor_drive()


func _on_circuit_state_applied() -> void:
	update_motor_drive()


func update_motor_drive() -> void:
	var current: float = signed_current_amps if energized else 0.0
	last_electrical_power_w = absf(current) * absf(voltage_drop_volts)
	target_output_rpm = get_target_rpm_for_current(current)
	if shaft != null:
		if absf(target_output_rpm) > 0.01:
			shaft.set_target_rpm(target_output_rpm, "electric motor")
		else:
			shaft.stop_drive("motor unpowered")
	set_running(absf(target_output_rpm) > 0.01)


func get_target_rpm_for_current(current_amps: float) -> float:
	if absf(current_amps) < max(minimum_activation_amps, 0.0):
		return 0.0
	var magnitude: float = min(
		absf(current_amps) * max(rpm_per_amp, 0.0),
		max(maximum_output_rpm, 0.0)
	)
	return magnitude * signf(current_amps) * float(winding_sign)


func set_winding_sign(next_sign: int) -> void:
	var normalized: int = 1 if next_sign >= 0 else -1
	if normalized == winding_sign:
		return
	winding_sign = normalized
	update_motor_drive()
	winding_changed.emit(winding_sign)


func reverse_winding() -> void:
	set_winding_sign(-winding_sign)


func set_running(next_running: bool) -> void:
	if running == next_running:
		return
	running = next_running
	running_state_changed.emit(running)


func interact() -> Dictionary:
	reverse_winding()
	return {
		"message": display_name + " winding reversed.",
		"objective": "Observe current direction and winding direction determine motor rotation.",
	}


func reset_target() -> void:
	winding_sign = 1 if initial_winding_sign >= 0 else -1
	running = false
	target_output_rpm = 0.0
	last_electrical_power_w = 0.0
	if shaft != null:
		shaft.stop_drive("motor reset")
	apply_circuit_state(false, 0.0, 0.0, -1)
	winding_changed.emit(winding_sign)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["electric_motor"] = true
	data["running"] = running
	data["winding_sign"] = winding_sign
	data["target_output_rpm"] = snapped(target_output_rpm, 0.1)
	data["shaft_rpm"] = snapped(shaft.current_rpm, 0.1) if shaft != null else 0.0
	data["electrical_power_w"] = snapped(last_electrical_power_w, 0.01)
	return data
