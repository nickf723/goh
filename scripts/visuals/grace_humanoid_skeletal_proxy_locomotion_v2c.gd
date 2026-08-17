extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_locomotion_v2b.gd"
class_name GraceHumanoidSkeletalProxyLocomotionV2C

# V2C concentrates on contact rather than adding more motion. A readable support
# foot, catch step, pivot, and inherited takeoff leg keep Grace's center of mass
# connected to the ground instead of letting a good pose cycle skate underneath
# her gameplay velocity.

@export_group("Foot Contact")
@export_range(0.0, 0.06, 0.002) var support_weight_shift: float = 0.018
@export_range(0.0, 8.0, 0.25) var support_hip_roll_degrees: float = 2.75
@export_range(0.0, 18.0, 0.5) var swing_toe_lift_degrees: float = 9.0
@export_range(0.0, 12.0, 0.5) var stance_knee_softness_degrees: float = 4.5

@export_group("Directional Steps")
@export_range(20.0, 120.0, 1.0) var pivot_begin_angle_degrees: float = 52.0
@export_range(30.0, 170.0, 1.0) var pivot_full_angle_degrees: float = 105.0
@export_range(0.0, 18.0, 0.5) var pivot_foot_yaw_degrees: float = 10.0
@export_range(0.0, 18.0, 0.5) var reversal_catch_degrees: float = 11.0

@export_group("Air Continuity")
@export_range(0.05, 0.8, 0.01) var takeoff_asymmetry_seconds: float = 0.34
@export_range(0.0, 18.0, 0.5) var takeoff_leg_memory_degrees: float = 8.0

var takeoff_support_sign: float = 1.0
var landing_support_sign: float = 1.0
var last_left_support: float = 0.5
var last_right_support: float = 0.5
var last_pivot_weight: float = 0.0
var last_turn_angle: float = 0.0
var landing_phase_seeded: bool = false


func _pose_locomotion(targets: Dictionary, delta: float) -> Vector3:
	# A landing that rolls directly into a run starts from the leg that was already
	# prepared to receive Grace rather than restarting the gait at an arbitrary phase.
	if previous_pose_state in ["jump", "fall"]:
		landing_support_sign = takeoff_support_sign
		stride_phase = 0.0 if landing_support_sign > 0.0 else PI
		landing_phase_seeded = true
	elif (
		locomotion_vertical_controller == null
		or locomotion_vertical_controller.vertical_state != "landing"
	):
		landing_phase_seeded = false

	var pelvis_offset: Vector3 = super._pose_locomotion(targets, delta)
	if actor == null:
		return pelvis_offset
	var velocity: Vector3 = Vector3(actor.velocity.x, 0.0, actor.velocity.z)
	var speed_weight: float = clampf(
		velocity.length() / maxf(locomotion_speed_reference, 0.1),
		0.0,
		1.0
	)
	_apply_support_transfer(targets, pelvis_offset, speed_weight)
	_apply_directional_step(targets, pelvis_offset, speed_weight)
	return pelvis_offset


func _pose_idle(targets: Dictionary) -> Vector3:
	var pelvis_offset: Vector3 = super._pose_idle(targets)
	# Preserve the final planted leg while the stop settles. It gives the stop pose
	# a visible foot to balance over instead of letting both feet become equally soft.
	var since_stop: float = elapsed - locomotion_stopped_at
	if since_stop >= 0.0 and since_stop <= stop_pose_seconds:
		var settle: float = 1.0 - smoothstep(
			0.0,
			1.0,
			since_stop / maxf(stop_pose_seconds, 0.01)
		)
		var side: float = stop_stride_sign
		if side > 0.0:
			_add_deg(targets, "shin_l", Vector3(stance_knee_softness_degrees * settle, 0.0, 0.0))
			_add_deg(targets, "foot_l", Vector3(-2.0 * settle, 0.0, 0.0))
			_add_deg(targets, "toe_l", Vector3(3.0 * settle, 0.0, 0.0))
		else:
			_add_deg(targets, "shin_r", Vector3(stance_knee_softness_degrees * settle, 0.0, 0.0))
			_add_deg(targets, "foot_r", Vector3(-2.0 * settle, 0.0, 0.0))
			_add_deg(targets, "toe_r", Vector3(3.0 * settle, 0.0, 0.0))
		pelvis_offset.x += side * support_weight_shift * settle * 0.7
	return pelvis_offset


func _pose_airborne(targets: Dictionary, state_name: String) -> Vector3:
	if previous_pose_state == "locomotion":
		# cos(stride_phase) is the support-foot wave: positive is left, negative right.
		takeoff_support_sign = 1.0 if cos(stride_phase) >= 0.0 else -1.0
		landing_support_sign = takeoff_support_sign
	var pelvis_offset: Vector3 = super._pose_airborne(targets, state_name)
	var air_age: float = 0.0
	if locomotion_vertical_controller != null:
		air_age = maxf(locomotion_vertical_controller.airborne_time, 0.0)
	var memory: float = 1.0 - smoothstep(
		0.0,
		1.0,
		air_age / maxf(takeoff_asymmetry_seconds, 0.01)
	)
	if memory > 0.001:
		var lead: float = takeoff_support_sign
		_add_deg(targets, "pelvis", Vector3(0.0, -lead * 2.2 * memory, lead * 1.4 * memory))
		_add_deg(targets, "thigh_l", Vector3(-lead * takeoff_leg_memory_degrees * memory, 0.0, -lead * 1.5 * memory))
		_add_deg(targets, "thigh_r", Vector3(lead * takeoff_leg_memory_degrees * memory, 0.0, -lead * 1.5 * memory))
		_add_deg(targets, "shin_l", Vector3(maxf(lead, 0.0) * 7.0 * memory, 0.0, 0.0))
		_add_deg(targets, "shin_r", Vector3(maxf(-lead, 0.0) * 7.0 * memory, 0.0, 0.0))
		_add_deg(targets, "upper_arm_l", Vector3(lead * 4.0 * memory, 0.0, 0.0))
		_add_deg(targets, "upper_arm_r", Vector3(-lead * 4.0 * memory, 0.0, 0.0))
		pelvis_offset.x += lead * support_weight_shift * 0.45 * memory
	return pelvis_offset


func _apply_support_transfer(
	targets: Dictionary,
	pelvis_offset: Vector3,
	speed_weight: float
) -> void:
	if speed_weight <= 0.02:
		last_left_support = 0.5
		last_right_support = 0.5
		return
	var support_wave: float = cos(stride_phase)
	# Smooth the center of the gait so support transfers rather than popping exactly
	# when cosine crosses zero. The support foot is nearly flat around peak loading.
	var left_support: float = smoothstep(-0.3, 0.72, support_wave)
	var right_support: float = smoothstep(-0.3, 0.72, -support_wave)
	var support_total: float = maxf(left_support + right_support, 0.001)
	left_support /= support_total
	right_support /= support_total
	last_left_support = left_support
	last_right_support = right_support
	var signed_support: float = left_support - right_support
	var loading: float = absf(signed_support) * speed_weight

	_add_deg(targets, "pelvis", Vector3(
		0.8 * loading,
		0.0,
		-signed_support * support_hip_roll_degrees * speed_weight
	))
	_add_deg(targets, "spine_01", Vector3(0.0, 0.0, signed_support * support_hip_roll_degrees * 0.35 * speed_weight))
	_add_deg(targets, "chest", Vector3(0.0, 0.0, signed_support * support_hip_roll_degrees * 0.22 * speed_weight))

	# Loaded leg yields a little at the knee. Swing leg dorsiflexes so its toe clears
	# rather than tracing the same ground plane as the planted foot.
	_add_deg(targets, "shin_l", Vector3(left_support * stance_knee_softness_degrees * speed_weight, 0.0, 0.0))
	_add_deg(targets, "shin_r", Vector3(right_support * stance_knee_softness_degrees * speed_weight, 0.0, 0.0))
	_add_deg(targets, "foot_l", Vector3(-(1.0 - left_support) * swing_toe_lift_degrees * speed_weight, 0.0, 0.0))
	_add_deg(targets, "foot_r", Vector3(-(1.0 - right_support) * swing_toe_lift_degrees * speed_weight, 0.0, 0.0))
	_add_deg(targets, "toe_l", Vector3(left_support * 4.0 * speed_weight, 0.0, 0.0))
	_add_deg(targets, "toe_r", Vector3(right_support * 4.0 * speed_weight, 0.0, 0.0))
	pelvis_offset.x += signed_support * support_weight_shift * speed_weight


func _apply_directional_step(
	targets: Dictionary,
	pelvis_offset: Vector3,
	speed_weight: float
) -> void:
	last_pivot_weight = 0.0
	last_turn_angle = 0.0
	if ground_motion_motor == null or speed_weight <= 0.02:
		return
	var motion: Dictionary = ground_motion_motor.get_debug_data()
	var turning: float = clampf(float(motion.get("turning_weight", 0.0)), 0.0, 1.0)
	var reversal: float = clampf(float(motion.get("reversal_weight", 0.0)), 0.0, 1.0)
	var turn_angle: float = absf(float(motion.get("turn_angle_degrees", 0.0)))
	var local_direction: Vector3 = motion.get("local_direction", Vector3.ZERO) as Vector3
	var turn_side: float = signf(local_direction.x)
	if absf(turn_side) < 0.5:
		turn_side = signf(local_direction.z) if reversal > 0.15 else 1.0
	last_turn_angle = turn_angle

	var pivot: float = inverse_lerp(
		pivot_begin_angle_degrees,
		maxf(pivot_full_angle_degrees, pivot_begin_angle_degrees + 1.0),
		turn_angle
	)
	pivot = clampf(pivot, 0.0, 1.0) * turning * speed_weight
	last_pivot_weight = pivot
	if pivot > 0.001:
		var left_is_plant: bool = turn_side > 0.0
		var plant_support: float = last_left_support if left_is_plant else last_right_support
		var pivot_strength: float = pivot * lerpf(0.65, 1.0, plant_support)
		_add_deg(targets, "pelvis", Vector3(4.0 * pivot_strength, turn_side * 7.0 * pivot_strength, -turn_side * 5.0 * pivot_strength))
		_add_deg(targets, "chest", Vector3(2.0 * pivot_strength, -turn_side * 5.0 * pivot_strength, turn_side * 3.0 * pivot_strength))
		if left_is_plant:
			_add_deg(targets, "thigh_l", Vector3(-7.0 * pivot_strength, turn_side * 4.0 * pivot_strength, 0.0))
			_add_deg(targets, "shin_l", Vector3(12.0 * pivot_strength, 0.0, 0.0))
			_add_deg(targets, "foot_l", Vector3(-2.0 * pivot_strength, turn_side * pivot_foot_yaw_degrees * pivot_strength, 0.0))
			_add_deg(targets, "toe_l", Vector3(5.0 * pivot_strength, turn_side * 3.0 * pivot_strength, 0.0))
		else:
			_add_deg(targets, "thigh_r", Vector3(-7.0 * pivot_strength, turn_side * 4.0 * pivot_strength, 0.0))
			_add_deg(targets, "shin_r", Vector3(12.0 * pivot_strength, 0.0, 0.0))
			_add_deg(targets, "foot_r", Vector3(-2.0 * pivot_strength, turn_side * pivot_foot_yaw_degrees * pivot_strength, 0.0))
			_add_deg(targets, "toe_r", Vector3(5.0 * pivot_strength, turn_side * 3.0 * pivot_strength, 0.0))
		pelvis_offset.y -= 0.022 * pivot_strength

	if reversal > 0.001:
		var catch: float = reversal * speed_weight
		var catch_sign: float = 1.0 if last_left_support >= last_right_support else -1.0
		_add_deg(targets, "pelvis", Vector3(7.0 * catch, catch_sign * 3.0 * catch, -catch_sign * reversal_catch_degrees * 0.35 * catch))
		_add_deg(targets, "spine_01", Vector3(8.0 * catch, -catch_sign * 2.0 * catch, catch_sign * 4.0 * catch))
		_add_deg(targets, "thigh_l", Vector3(-reversal_catch_degrees * catch if catch_sign > 0.0 else -4.0 * catch, 0.0, 0.0))
		_add_deg(targets, "thigh_r", Vector3(-reversal_catch_degrees * catch if catch_sign < 0.0 else -4.0 * catch, 0.0, 0.0))
		_add_deg(targets, "shin_l", Vector3(18.0 * catch if catch_sign > 0.0 else 7.0 * catch, 0.0, 0.0))
		_add_deg(targets, "shin_r", Vector3(18.0 * catch if catch_sign < 0.0 else 7.0 * catch, 0.0, 0.0))
		pelvis_offset.y -= 0.028 * catch


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["locomotion_v2c"] = true
	data["left_support"] = snappedf(last_left_support, 0.01)
	data["right_support"] = snappedf(last_right_support, 0.01)
	data["pivot_weight"] = snappedf(last_pivot_weight, 0.01)
	data["turn_angle"] = snappedf(last_turn_angle, 0.1)
	data["takeoff_support"] = "left" if takeoff_support_sign > 0.0 else "right"
	data["landing_support"] = "left" if landing_support_sign > 0.0 else "right"
	data["landing_phase_seeded"] = landing_phase_seeded
	return data
