extends Node3D
class_name RotationalShaftState

signal speed_changed(current_rpm: float, target_rpm: float, source: String)

@export var starting_rpm: float = 0.0
@export var acceleration_rpm_per_second: float = 900.0
@export var deceleration_rpm_per_second: float = 650.0
@export var maximum_abs_rpm: float = 1800.0
@export var rotation_axis: Vector3 = Vector3.FORWARD
@export var rotor_visual_path: NodePath

var current_rpm: float = 0.0
var target_rpm: float = 0.0
var drive_source: String = "none"
var total_revolutions: float = 0.0
var rotor_visual: Node3D


func _ready() -> void:
	current_rpm = clampf(starting_rpm, -maximum_abs_rpm, maximum_abs_rpm)
	target_rpm = current_rpm
	rotor_visual = get_node_or_null(rotor_visual_path) as Node3D if not rotor_visual_path.is_empty() else null
	add_to_group("rotational_shafts")
	add_to_group("debuggable")
	add_to_group("lab_resettable")


func _process(delta: float) -> void:
	step_rotation(delta)


func set_target_rpm(next_target_rpm: float, source: String = "unknown") -> void:
	target_rpm = clampf(next_target_rpm, -maximum_abs_rpm, maximum_abs_rpm)
	drive_source = source


func stop_drive(source: String = "stopped") -> void:
	set_target_rpm(0.0, source)


func step_rotation(delta: float) -> float:
	if delta <= 0.0:
		return current_rpm
	var previous_rpm: float = current_rpm
	var speeding_up: bool = absf(target_rpm) > absf(current_rpm)
	var rate: float = acceleration_rpm_per_second if speeding_up else deceleration_rpm_per_second
	current_rpm = move_toward(current_rpm, target_rpm, max(rate, 0.0) * delta)
	var revolutions: float = current_rpm / 60.0 * delta
	total_revolutions += revolutions
	if rotor_visual != null and absf(revolutions) > 0.000001:
		var axis: Vector3 = rotation_axis.normalized() if rotation_axis.length() > 0.001 else Vector3.FORWARD
		rotor_visual.rotate(axis, TAU * revolutions)
	if absf(current_rpm - previous_rpm) > 0.01:
		speed_changed.emit(current_rpm, target_rpm, drive_source)
	return current_rpm


func get_speed_ratio() -> float:
	if maximum_abs_rpm <= 0.0:
		return 0.0
	return clampf(absf(current_rpm) / maximum_abs_rpm, 0.0, 1.0)


func reset_target() -> void:
	current_rpm = clampf(starting_rpm, -maximum_abs_rpm, maximum_abs_rpm)
	target_rpm = current_rpm
	drive_source = "reset"
	total_revolutions = 0.0
	speed_changed.emit(current_rpm, target_rpm, drive_source)


func get_debug_data() -> Dictionary:
	return {
		"rotational_shaft": true,
		"rpm": snapped(current_rpm, 0.1),
		"target_rpm": snapped(target_rpm, 0.1),
		"speed_ratio": snapped(get_speed_ratio(), 0.01),
		"drive_source": drive_source,
		"total_revolutions": snapped(total_revolutions, 0.01),
	}
