extends Node
class_name SoulManipulable

signal manipulation_started(controller: Node)
signal manipulation_ended()
signal target_pose_changed(target_position: Vector3)

@export var body_path: NodePath = NodePath("..")
@export var anchor_offset: Vector3 = Vector3.ZERO
@export var manipulation_enabled: bool = true
@export_range(0.0, 1.0, 0.01) var resistance: float = 0.0
@export_range(0.1, 40.0, 0.1) var position_stiffness: float = 8.0
@export_range(0.1, 40.0, 0.1) var velocity_response: float = 14.0
@export_range(0.0, 1.0, 0.01) var mass_speed_exponent: float = 0.32
@export_range(0.1, 30.0, 0.1) var maximum_speed: float = 12.0
@export_range(0.1, 10.0, 0.1) var minimum_speed: float = 1.4
@export_range(1.0, 720.0, 1.0) var rotation_response_degrees: float = 260.0

var body: CharacterBody3D = null
var controlling_node: Node = null
var active: bool = false
var target_global_position: Vector3 = Vector3.ZERO
var target_global_basis: Basis = Basis.IDENTITY


func _ready() -> void:
	body = get_node_or_null(body_path) as CharacterBody3D
	add_to_group("soul_manipulable")
	add_to_group("debuggable")

	if body == null:
		push_warning(name + " could not find a CharacterBody3D at " + str(body_path))


func can_begin_manipulation() -> bool:
	return manipulation_enabled and body != null and not active


func begin_manipulation(controller: Node) -> bool:
	if not can_begin_manipulation():
		return false

	controlling_node = controller
	active = true
	target_global_position = get_anchor_global_position()
	target_global_basis = body.global_basis
	manipulation_started.emit(controller)
	return true


func end_manipulation() -> void:
	if not active:
		return

	active = false
	controlling_node = null
	manipulation_ended.emit()


func is_being_manipulated() -> bool:
	return active and body != null


func set_target_pose(next_position: Vector3, next_basis: Basis) -> void:
	if not is_being_manipulated():
		return

	target_global_position = next_position - body.global_basis * anchor_offset
	target_global_basis = next_basis.orthonormalized()
	target_pose_changed.emit(target_global_position)


func get_anchor_global_position() -> Vector3:
	if body == null:
		return Vector3.ZERO
	return body.global_position + body.global_basis * anchor_offset


func get_commanded_velocity(
	current_velocity: Vector3,
	effective_mass: float,
	delta: float
) -> Vector3:
	if not is_being_manipulated() or delta <= 0.0:
		return current_velocity

	var error: Vector3 = target_global_position - body.global_position
	var mass: float = max(effective_mass, 0.1)
	var mass_factor: float = 1.0 / pow(mass, mass_speed_exponent)
	var resistance_factor: float = clampf(1.0 - resistance, 0.05, 1.0)
	var response_factor: float = mass_factor * resistance_factor
	var desired_velocity: Vector3 = error * position_stiffness * response_factor
	var speed_limit: float = max(minimum_speed, maximum_speed * response_factor)

	if desired_velocity.length() > speed_limit:
		desired_velocity = desired_velocity.normalized() * speed_limit

	var blend: float = 1.0 - exp(-velocity_response * response_factor * delta)
	return current_velocity.lerp(desired_velocity, clampf(blend, 0.0, 1.0))


func apply_rotation_step(delta: float) -> void:
	if not is_being_manipulated() or delta <= 0.0:
		return

	var current_quaternion: Quaternion = body.global_basis.get_rotation_quaternion()
	var target_quaternion: Quaternion = target_global_basis.get_rotation_quaternion()
	var angle: float = current_quaternion.angle_to(target_quaternion)

	if angle <= 0.0001:
		return

	var maximum_step: float = deg_to_rad(rotation_response_degrees) * delta
	var weight: float = min(maximum_step / angle, 1.0)
	var next_quaternion: Quaternion = current_quaternion.slerp(target_quaternion, weight)
	body.global_basis = Basis(next_quaternion).scaled(body.global_basis.get_scale())


func reset_target() -> void:
	end_manipulation()


func get_debug_data() -> Dictionary:
	return {
		"soul_manipulable": true,
		"enabled": manipulation_enabled,
		"active": active,
		"controller": controlling_node.name if controlling_node != null else "none",
		"anchor": get_anchor_global_position(),
		"target": target_global_position,
		"resistance": resistance,
	}
