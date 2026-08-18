extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_animation_v25.gd"
class_name GraceHumanoidSkeletalProxyAnimationV26

# V26 visualizes the GroundMotionMotor's existing slippery response. No traction
# values change here; Grace simply widens her base, counterbalances more visibly,
# and catches braking/reversals with the body rather than looking unaffected.

@export_group("Slippery Surface Animation")
@export_range(0.0, 1.0, 0.05) var slippery_pose_strength: float = 0.82
@export_range(0.0, 24.0, 0.5) var slippery_arm_balance_degrees: float = 13.0
@export_range(0.0, 16.0, 0.5) var slippery_leg_spread_degrees: float = 7.0
@export_range(0.0, 0.1, 0.005) var slippery_center_drop: float = 0.035

var last_slippery_weight: float = 0.0
var last_slippery_balance_side: float = 0.0


func _pose_idle(targets: Dictionary) -> Vector3:
	var pelvis_offset: Vector3 = super._pose_idle(targets)
	pelvis_offset += _apply_slippery_balance(targets, false)
	return pelvis_offset


func _pose_locomotion(targets: Dictionary, delta: float) -> Vector3:
	var pelvis_offset: Vector3 = super._pose_locomotion(targets, delta)
	pelvis_offset += _apply_slippery_balance(targets, true)
	return pelvis_offset


func _apply_slippery_balance(
	targets: Dictionary,
	moving: bool
) -> Vector3:
	last_slippery_weight = 0.0
	last_slippery_balance_side = 0.0
	if ground_motion_motor == null or not ground_motion_motor.slippery_active:
		return Vector3.ZERO
	var speed_weight: float = 0.0
	if actor != null:
		speed_weight = clampf(
			Vector2(actor.velocity.x, actor.velocity.z).length()
			/ maxf(locomotion_speed_reference, 0.1),
			0.0,
			1.0
		)
	var braking: float = clampf(ground_motion_motor.braking_weight, 0.0, 1.0)
	var reversal: float = clampf(ground_motion_motor.reversal_weight, 0.0, 1.0)
	var turning: float = clampf(ground_motion_motor.turning_weight, 0.0, 1.0)
	var instability: float = clampf(
		maxf(speed_weight * 0.48, braking * 0.9, reversal, turning * 0.72),
		0.18,
		1.0
	)
	var weight: float = instability * slippery_pose_strength
	last_slippery_weight = weight
	var local_velocity: Vector3 = Vector3.ZERO
	if actor != null:
		local_velocity = (
			actor.global_transform.basis.orthonormalized().inverse()
			* Vector3(actor.velocity.x, 0.0, actor.velocity.z)
		)
	var side: float = signf(local_velocity.x)
	if absf(side) < 0.5:
		side = 1.0 if sin(stride_phase) >= 0.0 else -1.0
	last_slippery_balance_side = side
	var balance: float = slippery_arm_balance_degrees * weight
	var spread: float = slippery_leg_spread_degrees * weight

	_add_deg(targets, "pelvis", Vector3(5.0 * weight, -side * 2.0 * turning * weight, -side * 5.0 * weight))
	_add_deg(targets, "spine_01", Vector3(4.0 * weight, side * 1.5 * weight, side * 3.0 * weight))
	_add_deg(targets, "spine_02", Vector3(3.0 * weight, side * 2.0 * weight, side * 4.0 * weight))
	_add_deg(targets, "chest", Vector3(2.0 * weight, side * 2.5 * weight, side * 5.0 * weight))
	_add_deg(targets, "head", Vector3(-2.0 * weight, -side * 1.5 * weight, -side * 2.0 * weight))

	# Open the free arm strongly and the weapon arm only modestly so balance reads
	# without sacrificing weapon control.
	var weapon_class: String = _get_equipped_weapon_class()
	var weapon_arm_scale: float = 0.42 if weapon_class in ["staff", "axe"] else 0.82
	_add_deg(targets, "upper_arm_l", Vector3(3.0 * weight, 0.0, -balance))
	_add_deg(targets, "upper_arm_r", Vector3(3.0 * weight, 0.0, balance * weapon_arm_scale))
	_add_deg(targets, "forearm_l", Vector3(-6.0 * weight, 0.0, 0.0))
	_add_deg(targets, "forearm_r", Vector3(-4.0 * weight * weapon_arm_scale, 0.0, 0.0))

	_add_deg(targets, "thigh_l", Vector3(-5.0 * weight, 0.0, -spread))
	_add_deg(targets, "thigh_r", Vector3(-5.0 * weight, 0.0, spread))
	_add_deg(targets, "shin_l", Vector3(11.0 * weight, 0.0, 0.0))
	_add_deg(targets, "shin_r", Vector3(11.0 * weight, 0.0, 0.0))
	_add_deg(targets, "foot_l", Vector3(-2.0 * weight, -side * 2.0 * weight, -spread * 0.35))
	_add_deg(targets, "foot_r", Vector3(-2.0 * weight, -side * 2.0 * weight, spread * 0.35))

	return Vector3(
		-side * 0.012 * weight,
		-slippery_center_drop * weight,
		(0.012 if moving else 0.0) * braking * weight
	)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["animation_v26"] = true
	data["slippery_surface_animation"] = true
	data["slippery_pose_weight"] = snappedf(last_slippery_weight, 0.01)
	data["slippery_balance_side"] = last_slippery_balance_side
	return data
