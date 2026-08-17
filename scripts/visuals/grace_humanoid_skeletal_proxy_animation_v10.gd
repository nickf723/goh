extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_animation_v9.gd"
class_name GraceHumanoidSkeletalProxyAnimationV10

# V10 separates forward running, strafing, and backward footwork. The locomotion
# foundation still supplies phase/support contacts; this layer reshapes that same
# gait according to actual local travel direction.

@export_group("Directional Gait")
@export_range(0.0, 1.0, 0.05) var strafe_gait_strength: float = 0.82
@export_range(0.0, 1.0, 0.05) var backward_gait_strength: float = 0.88
@export_range(0.0, 20.0, 0.5) var strafe_foot_yaw_degrees: float = 9.0
@export_range(0.0, 16.0, 0.5) var backward_upright_degrees: float = 7.0

var last_strafe_weight: float = 0.0
var last_backward_weight: float = 0.0
var last_directional_side: float = 0.0


func _pose_locomotion(targets: Dictionary, delta: float) -> Vector3:
	var pelvis_offset: Vector3 = super._pose_locomotion(targets, delta)
	_apply_directional_gait(targets)
	return pelvis_offset


func _apply_directional_gait(targets: Dictionary) -> void:
	last_strafe_weight = 0.0
	last_backward_weight = 0.0
	last_directional_side = 0.0
	if actor == null:
		return
	var velocity := Vector3(actor.velocity.x, 0.0, actor.velocity.z)
	var speed: float = velocity.length()
	if speed <= 0.08:
		return
	var local_velocity: Vector3 = (
		actor.global_transform.basis.orthonormalized().inverse() * velocity
	)
	var local_direction: Vector3 = local_velocity / speed
	var side: float = clampf(local_direction.x, -1.0, 1.0)
	var backward: float = clampf(local_direction.z, 0.0, 1.0)
	var strafe_abs: float = absf(side)
	# Forward diagonals retain the running gait. Sideways dominance progressively
	# becomes a sidestep, while true backward travel becomes guarded footwork.
	var strafe_weight: float = smoothstep(0.35, 0.88, strafe_abs) * (1.0 - backward * 0.55)
	strafe_weight *= strafe_gait_strength
	var backward_weight: float = smoothstep(0.18, 0.92, backward) * backward_gait_strength
	last_strafe_weight = strafe_weight
	last_backward_weight = backward_weight
	last_directional_side = side

	if strafe_weight > 0.001:
		_apply_strafe_gait(targets, side, strafe_weight)
	if backward_weight > 0.001:
		_apply_backward_gait(targets, side, backward_weight)


func _apply_strafe_gait(
	targets: Dictionary,
	side: float,
	weight: float
) -> void:
	var side_sign: float = 1.0 if side >= 0.0 else -1.0
	var stride: float = sin(stride_phase)
	var left: Vector3 = targets.get("thigh_l", Vector3.ZERO) as Vector3
	var right: Vector3 = targets.get("thigh_r", Vector3.ZERO) as Vector3
	left.x *= lerpf(1.0, 0.58, weight)
	right.x *= lerpf(1.0, 0.58, weight)
	left.y += side_sign * lerpf(0.0, 5.0, weight)
	right.y += side_sign * lerpf(0.0, 5.0, weight)
	left.z += -side_sign * stride * 5.5 * weight
	right.z += side_sign * stride * 5.5 * weight
	targets["thigh_l"] = left
	targets["thigh_r"] = right

	var left_foot: Vector3 = targets.get("foot_l", Vector3.ZERO) as Vector3
	var right_foot: Vector3 = targets.get("foot_r", Vector3.ZERO) as Vector3
	left_foot.y += side_sign * strafe_foot_yaw_degrees * weight
	right_foot.y += side_sign * strafe_foot_yaw_degrees * weight
	left_foot.z += -side_sign * 2.0 * weight
	right_foot.z += side_sign * 2.0 * weight
	targets["foot_l"] = left_foot
	targets["foot_r"] = right_foot

	_add_deg(targets, "pelvis", Vector3(2.0 * weight, -side_sign * 3.0 * weight, -side_sign * 4.5 * weight))
	_add_deg(targets, "spine_01", Vector3(0.0, side_sign * 1.5 * weight, side_sign * 3.0 * weight))
	_add_deg(targets, "spine_02", Vector3(0.0, side_sign * 2.0 * weight, side_sign * 3.5 * weight))
	_add_deg(targets, "chest", Vector3(0.0, side_sign * 2.5 * weight, side_sign * 4.0 * weight))
	_add_deg(targets, "head", Vector3(0.0, -side_sign * 2.0 * weight, -side_sign * 1.5 * weight))


func _apply_backward_gait(
	targets: Dictionary,
	side: float,
	weight: float
) -> void:
	var stride: float = sin(stride_phase)
	# Shorter steps and more knee flexion prevent backward travel from reading as a
	# forward cycle played in reverse. Grace keeps her chest more upright and ready.
	for bone_name: String in ["thigh_l", "thigh_r"]:
		var value: Vector3 = targets.get(bone_name, Vector3.ZERO) as Vector3
		value.x *= lerpf(1.0, 0.62, weight)
		targets[bone_name] = value
	for bone_name: String in ["upper_arm_l", "upper_arm_r"]:
		var value: Vector3 = targets.get(bone_name, Vector3.ZERO) as Vector3
		value.x *= lerpf(1.0, 0.7, weight)
		targets[bone_name] = value

	_add_deg(targets, "pelvis", Vector3(5.0 * weight, -side * 2.0 * weight, -side * 2.0 * weight))
	_add_deg(targets, "spine_01", Vector3(backward_upright_degrees * 0.42 * weight, side * 1.0 * weight, side * 1.0 * weight))
	_add_deg(targets, "spine_02", Vector3(backward_upright_degrees * 0.72 * weight, side * 1.5 * weight, side * 1.5 * weight))
	_add_deg(targets, "chest", Vector3(backward_upright_degrees * weight, side * 2.0 * weight, side * 2.0 * weight))
	_add_deg(targets, "head", Vector3(-backward_upright_degrees * 0.35 * weight, -side * 1.5 * weight, 0.0))
	_add_deg(targets, "shin_l", Vector3((7.0 + maxf(stride, 0.0) * 6.0) * weight, 0.0, 0.0))
	_add_deg(targets, "shin_r", Vector3((7.0 + maxf(-stride, 0.0) * 6.0) * weight, 0.0, 0.0))
	_add_deg(targets, "foot_l", Vector3(4.0 * weight, -side * 2.0 * weight, 0.0))
	_add_deg(targets, "foot_r", Vector3(4.0 * weight, -side * 2.0 * weight, 0.0))


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["animation_v10"] = true
	data["directional_gait"] = true
	data["strafe_weight"] = snappedf(last_strafe_weight, 0.01)
	data["backward_weight"] = snappedf(last_backward_weight, 0.01)
	data["directional_side"] = snappedf(last_directional_side, 0.01)
	return data
