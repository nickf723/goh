extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_animation_v18.gd"
class_name GraceHumanoidSkeletalProxyAnimationV19

# V19 extends engagement awareness beyond the actual attack frames. Lock-on gaze
# stays primarily in the head/chest so locomotion feet and weapon technique retain
# authority over the body.

@export_group("Combat Gaze")
@export_range(0.0, 45.0, 1.0) var maximum_lock_on_gaze_degrees: float = 24.0
@export_range(0.0, 1.0, 0.05) var idle_gaze_strength: float = 0.86
@export_range(0.0, 1.0, 0.05) var moving_gaze_strength: float = 0.62

var last_lock_on_gaze_yaw: float = 0.0
var last_lock_on_gaze_weight: float = 0.0


func _pose_idle(targets: Dictionary) -> Vector3:
	var pelvis_offset: Vector3 = super._pose_idle(targets)
	_apply_lock_on_gaze(targets, idle_gaze_strength)
	return pelvis_offset


func _pose_locomotion(targets: Dictionary, delta: float) -> Vector3:
	var pelvis_offset: Vector3 = super._pose_locomotion(targets, delta)
	_apply_lock_on_gaze(targets, moving_gaze_strength)
	return pelvis_offset


func _apply_lock_on_gaze(targets: Dictionary, strength: float) -> void:
	last_lock_on_gaze_yaw = 0.0
	last_lock_on_gaze_weight = 0.0
	if actor == null:
		return
	if action_state != null and (
		action_state.is_attacking
		or action_state.is_dodging
		or action_state.is_staggered
		or action_state.is_manipulating
	):
		return
	var target_value: Variant = actor.get("lock_on_target")
	if target_value == null or not is_instance_valid(target_value):
		return
	if not target_value is Node3D:
		return
	var target: Node3D = target_value as Node3D
	var offset: Vector3 = target.global_position - actor.global_position
	var planar: Vector3 = offset
	planar.y = 0.0
	if planar.length_squared() <= 0.0001:
		return
	var local_direction: Vector3 = (
		actor.global_transform.basis.orthonormalized().inverse()
		* planar.normalized()
	)
	var yaw: float = rad_to_deg(atan2(-local_direction.x, -local_direction.z))
	var clamped_yaw: float = clampf(
		yaw,
		-maximum_lock_on_gaze_degrees,
		maximum_lock_on_gaze_degrees
	)
	var distance_weight: float = clampf(
		planar.length() / 1.25,
		0.35,
		1.0
	)
	var gaze_weight: float = clampf(strength, 0.0, 1.0) * distance_weight
	last_lock_on_gaze_yaw = clamped_yaw
	last_lock_on_gaze_weight = gaze_weight

	_add_deg(targets, "spine_02", Vector3(0.0, clamped_yaw * 0.12 * gaze_weight, 0.0))
	_add_deg(targets, "chest", Vector3(0.0, clamped_yaw * 0.2 * gaze_weight, -local_direction.x * 1.2 * gaze_weight))
	_add_deg(targets, "neck", Vector3(0.0, clamped_yaw * 0.26 * gaze_weight, 0.0))
	_add_deg(targets, "head", Vector3(0.0, clamped_yaw * 0.48 * gaze_weight, -local_direction.x * 0.8 * gaze_weight))


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["animation_v19"] = true
	data["neutral_lock_on_gaze"] = true
	data["lock_on_gaze_yaw"] = snappedf(last_lock_on_gaze_yaw, 0.1)
	data["lock_on_gaze_weight"] = snappedf(last_lock_on_gaze_weight, 0.01)
	return data
