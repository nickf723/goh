extends Node3D
class_name CounterweightedSlidingDoor

signal open_fraction_changed(open_fraction: float)

@export var shaft_path: NodePath = NodePath("Motor/Shaft")
@export var motor_path: NodePath = NodePath("Motor")
@export var moving_body_path: NodePath = NodePath("DoorBody")
@export var state_label_path: NodePath = NodePath("StateLabel")
@export var open_offset: Vector3 = Vector3(0.0, 3.5, 0.0)
@export_range(0.1, 20.0, 0.1) var revolutions_to_open: float = 3.0
@export_range(1.0, 600.0, 1.0) var counterweight_return_rpm: float = 62.0
@export_range(0.0, 100.0, 0.1) var powered_rpm_threshold: float = 1.0
@export var positive_rotation_opens: bool = true

var shaft: RotationalShaftState = null
var motor: ElectricMotorComponent = null
var moving_body: Node3D = null
var state_label: Label3D = null
var closed_position: Vector3 = Vector3.ZERO
var open_fraction: float = 0.0
var last_emitted_fraction: float = -1.0


func _ready() -> void:
	shaft = get_node_or_null(shaft_path) as RotationalShaftState
	motor = get_node_or_null(motor_path) as ElectricMotorComponent
	moving_body = get_node_or_null(moving_body_path) as Node3D
	state_label = get_node_or_null(state_label_path) as Label3D
	if moving_body != null:
		closed_position = moving_body.position
	add_to_group("mechanism_actuators")
	add_to_group("lab_resettable")
	add_to_group("debuggable")
	reset_target()


func _process(_delta: float) -> void:
	if shaft == null or moving_body == null:
		return

	var opening_sign: float = 1.0 if positive_rotation_opens else -1.0
	var signed_revolutions: float = shaft.total_revolutions * opening_sign
	var motor_opening: bool = (
		motor != null
		and motor.energized
		and motor.target_output_rpm * opening_sign > powered_rpm_threshold
	)

	if not motor_opening:
		if signed_revolutions > 0.001:
			shaft.set_target_rpm(-counterweight_return_rpm * opening_sign, "door counterweight")
		else:
			shaft.current_rpm = 0.0
			shaft.stop_drive("door closed")

	signed_revolutions = shaft.total_revolutions * opening_sign
	if signed_revolutions <= 0.0:
		shaft.total_revolutions = 0.0
		if shaft.current_rpm * opening_sign < 0.0:
			shaft.current_rpm = 0.0
			shaft.stop_drive("door closed limit")
	elif signed_revolutions >= revolutions_to_open:
		shaft.total_revolutions = revolutions_to_open * opening_sign
		if shaft.current_rpm * opening_sign > 0.0:
			shaft.current_rpm = 0.0
			shaft.stop_drive("door open limit")

	open_fraction = clampf(
		(shaft.total_revolutions * opening_sign) / max(revolutions_to_open, 0.001),
		0.0,
		1.0
	)
	moving_body.position = closed_position + open_offset * open_fraction
	refresh_label()
	if absf(open_fraction - last_emitted_fraction) >= 0.01:
		last_emitted_fraction = open_fraction
		open_fraction_changed.emit(open_fraction)


func refresh_label() -> void:
	if state_label == null:
		return
	var state_text: String = "CLOSED"
	if open_fraction >= 0.99:
		state_text = "OPEN"
	elif open_fraction > 0.01:
		state_text = "MOVING " + str(int(round(open_fraction * 100.0))) + "%"
	state_label.text = "COUNTERWEIGHT DOOR\n" + state_text


func reset_target() -> void:
	if shaft == null:
		shaft = get_node_or_null(shaft_path) as RotationalShaftState
	if motor == null:
		motor = get_node_or_null(motor_path) as ElectricMotorComponent
	if moving_body == null:
		moving_body = get_node_or_null(moving_body_path) as Node3D
	if state_label == null:
		state_label = get_node_or_null(state_label_path) as Label3D

	if shaft != null:
		shaft.current_rpm = 0.0
		shaft.target_rpm = 0.0
		shaft.total_revolutions = 0.0
		shaft.drive_source = "door reset"
	if moving_body != null:
		moving_body.position = closed_position
	open_fraction = 0.0
	last_emitted_fraction = -1.0
	refresh_label()
	open_fraction_changed.emit(open_fraction)


func get_debug_data() -> Dictionary:
	return {
		"counterweighted_door": true,
		"open_fraction": snapped(open_fraction, 0.01),
		"revolutions_to_open": revolutions_to_open,
		"shaft_revolutions": snapped(shaft.total_revolutions, 0.01) if shaft != null else 0.0,
		"shaft_rpm": snapped(shaft.current_rpm, 0.1) if shaft != null else 0.0,
		"motor_energized": motor.energized if motor != null else false,
		"drive_source": shaft.drive_source if shaft != null else "none",
	}
