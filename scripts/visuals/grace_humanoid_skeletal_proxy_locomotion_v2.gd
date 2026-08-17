extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_weapon_languages_v4o.gd"
class_name GraceHumanoidSkeletalProxyLocomotionV2

# Locomotion V2 sits above the authored weapon languages. Combat poses, support
# hand IK, weapon physics, and gameplay timing remain untouched; this layer only
# improves the body language connecting those authored actions.

@export_group("Locomotion V2")
@export_range(0.08, 0.4, 0.01) var start_pose_seconds: float = 0.2
@export_range(0.08, 0.45, 0.01) var stop_pose_seconds: float = 0.24
@export_range(0.0, 12.0, 0.1) var maximum_run_lean_degrees: float = 6.5
@export_range(0.0, 10.0, 0.1) var start_extra_lean_degrees: float = 5.0
@export_range(0.0, 0.08, 0.002) var run_vertical_bob: float = 0.018
@export_range(0.0, 0.08, 0.002) var idle_weight_shift: float = 0.018
@export_range(0.0, 0.25, 0.005) var landing_compression_depth: float = 0.135

var locomotion_vertical_controller: PlayerVerticalMotionController
var previous_pose_state: String = "idle"
var locomotion_started_at: float = -100.0
var locomotion_stopped_at: float = -100.0
var stop_stride_sign: float = 1.0
var stop_speed_weight: float = 0.0
var start_lead_sign: float = 1.0
var last_locomotion_speed: float = 0.0


func _ready() -> void:
	super._ready()
	if actor != null:
		locomotion_vertical_controller = actor.get_node_or_null(
			"VerticalMotionController"
		) as PlayerVerticalMotionController
	# Slightly slower than the combat-entry response. This lets hips, shoulders,
	# and planted feet carry perceptible inertia without making attacks mushy.
	pose_response = clampf(pose_response, 15.0, 20.0)
	add_to_group("grace_locomotion_v2")


func _resolve_state() -> String:
	previous_pose_state = animation_state
	return super._resolve_state()


func _pose_idle(targets: Dictionary) -> Vector3:
	var breath: float = sin(elapsed * 1.85)
	var breath_secondary: float = sin(elapsed * 3.7 + 0.65)
	var weight_wave: float = sin(elapsed * 0.58)
	var head_drift: float = sin(elapsed * 0.31 + 1.2)
	var weight_left: float = clampf(weight_wave, 0.0, 1.0)
	var weight_right: float = clampf(-weight_wave, 0.0, 1.0)

	_set_deg(targets, "pelvis", Vector3(
		0.7 + breath * 0.35,
		weight_wave * 1.5,
		-weight_wave * 2.2
	))
	_set_deg(targets, "spine_01", Vector3(
		-1.5 + breath * 0.55,
		-weight_wave * 0.65,
		weight_wave * 1.25
	))
	_set_deg(targets, "spine_02", Vector3(
		-1.1 + breath * 0.75,
		-weight_wave * 0.95,
		weight_wave * 1.55
	))
	_set_deg(targets, "chest", Vector3(
		-0.7 + breath * 0.65 + breath_secondary * 0.15,
		-weight_wave * 1.1,
		weight_wave * 1.8
	))
	_set_deg(targets, "neck", Vector3(0.45, head_drift * 1.0, -weight_wave * 0.45))
	_set_deg(targets, "head", Vector3(-0.35, head_drift * 1.6, -weight_wave * 0.8))

	# Unequal arms and a relaxed supporting knee prevent the neutral pose from
	# reading as a mirrored mannequin stance.
	_set_deg(targets, "upper_arm_l", Vector3(-4.5, -1.0, -5.0))
	_set_deg(targets, "upper_arm_r", Vector3(-2.5, 1.0, 4.0))
	_set_deg(targets, "forearm_l", Vector3(-11.5 + breath * 0.6, 0.0, -1.0))
	_set_deg(targets, "forearm_r", Vector3(-8.5 - breath * 0.4, 0.0, 1.0))
	_set_deg(targets, "thigh_l", Vector3(-2.5 * weight_right, 0.0, -1.6 * weight_wave))
	_set_deg(targets, "thigh_r", Vector3(-2.5 * weight_left, 0.0, -1.6 * weight_wave))
	_set_deg(targets, "shin_l", Vector3(5.5 * weight_right, 0.0, 0.0))
	_set_deg(targets, "shin_r", Vector3(5.5 * weight_left, 0.0, 0.0))
	_set_deg(targets, "foot_l", Vector3(-1.2 * weight_right, 0.0, 0.0))
	_set_deg(targets, "foot_r", Vector3(-1.2 * weight_left, 0.0, 0.0))

	animation_weight = 0.0
	var pelvis_offset := Vector3(
		weight_wave * idle_weight_shift,
		breath * 0.006,
		0.0
	)

	if previous_pose_state == "locomotion":
		locomotion_stopped_at = elapsed
		stop_stride_sign = 1.0 if sin(stride_phase) >= 0.0 else -1.0
		stop_speed_weight = clampf(
			last_locomotion_speed / maxf(locomotion_speed_reference, 0.1),
			0.0,
			1.0
		)

	_apply_stop_pose(targets, pelvis_offset)
	_apply_landing_overlay(targets, pelvis_offset)
	return pelvis_offset


func _pose_locomotion(targets: Dictionary, delta: float) -> Vector3:
	if actor == null:
		return Vector3.ZERO
	var velocity := Vector3(actor.velocity.x, 0.0, actor.velocity.z)
	var speed: float = velocity.length()
	var weight: float = clampf(
		speed / maxf(locomotion_speed_reference, 0.1),
		0.0,
		1.0
	)
	animation_weight = weight
	last_locomotion_speed = speed

	if previous_pose_state != "locomotion":
		locomotion_started_at = elapsed
		start_lead_sign *= -1.0
		stride_phase = PI * 0.5 if start_lead_sign > 0.0 else PI * 1.5

	# Cadence grows with actual world speed but stays in a human range. Starting
	# from a planted phase makes acceleration read as a push-off instead of feet
	# instantly cycling under a stationary torso.
	var cadence: float = lerpf(6.4, 10.5, weight)
	stride_phase = fposmod(stride_phase + delta * cadence, TAU)
	var stride: float = sin(stride_phase)
	var stride_cos: float = cos(stride_phase)
	var double_step: float = absf(sin(stride_phase * 2.0))
	var local_velocity: Vector3 = (
		actor.global_transform.basis.orthonormalized().inverse() * velocity
	)
	var lateral: float = clampf(
		local_velocity.x / maxf(locomotion_speed_reference, 0.1),
		-1.0,
		1.0
	)
	var forward: float = clampf(
		-local_velocity.z / maxf(locomotion_speed_reference, 0.1),
		-1.0,
		1.0
	)

	var braking: float = 0.0
	var reversal: float = 0.0
	var turning: float = 0.0
	if ground_motion_motor != null:
		var motion: Dictionary = ground_motion_motor.get_debug_data()
		braking = clampf(float(motion.get("braking_weight", 0.0)), 0.0, 1.0)
		reversal = clampf(float(motion.get("reversal_weight", 0.0)), 0.0, 1.0)
		turning = clampf(float(motion.get("turning_weight", 0.0)), 0.0, 1.0)

	var start_progress: float = clampf(
		(elapsed - locomotion_started_at) / maxf(start_pose_seconds, 0.01),
		0.0,
		1.0
	)
	var start_weight: float = 1.0 - smoothstep(0.0, 1.0, start_progress)
	var run_lean: float = maximum_run_lean_degrees * weight
	var acceleration_lean: float = start_extra_lean_degrees * start_weight
	var leg_swing_degrees: float = lerpf(18.0, 37.0, weight)
	var arm_swing_degrees: float = lerpf(12.0, 29.0, weight)

	var left_forward: float = stride
	var right_forward: float = -stride
	var left_knee: float = (
		maxf(left_forward, 0.0) * lerpf(16.0, 31.0, weight)
		+ maxf(-stride_cos, 0.0) * 5.0 * weight
	)
	var right_knee: float = (
		maxf(right_forward, 0.0) * lerpf(16.0, 31.0, weight)
		+ maxf(stride_cos, 0.0) * 5.0 * weight
	)

	_set_deg(targets, "thigh_l", Vector3(
		left_forward * leg_swing_degrees,
		-stride * 1.5 * weight,
		-lateral * 2.5
	))
	_set_deg(targets, "thigh_r", Vector3(
		right_forward * leg_swing_degrees,
		-stride * 1.5 * weight,
		-lateral * 2.5
	))
	_set_deg(targets, "shin_l", Vector3(left_knee, 0.0, 0.0))
	_set_deg(targets, "shin_r", Vector3(right_knee, 0.0, 0.0))
	_set_deg(targets, "foot_l", Vector3(
		-maxf(left_forward, 0.0) * 11.0 * weight
		+ maxf(-left_forward, 0.0) * 15.0 * weight,
		0.0,
		0.0
	))
	_set_deg(targets, "foot_r", Vector3(
		-maxf(right_forward, 0.0) * 11.0 * weight
		+ maxf(-right_forward, 0.0) * 15.0 * weight,
		0.0,
		0.0
	))

	# Shoulders counter the pelvis rather than simply mirroring the legs.
	_set_deg(targets, "upper_arm_l", Vector3(
		-left_forward * arm_swing_degrees,
		stride * 2.0 * weight,
		-5.0
	))
	_set_deg(targets, "upper_arm_r", Vector3(
		-right_forward * arm_swing_degrees,
		stride * 2.0 * weight,
		5.0
	))
	_set_deg(targets, "forearm_l", Vector3(
		-12.0 - maxf(-left_forward, 0.0) * 12.0 * weight,
		0.0,
		0.0
	))
	_set_deg(targets, "forearm_r", Vector3(
		-12.0 - maxf(-right_forward, 0.0) * 12.0 * weight,
		0.0,
		0.0
	))

	var hip_yaw: float = -stride * lerpf(2.0, 5.2, weight)
	var shoulder_yaw: float = -hip_yaw * 0.92
	var turn_bank: float = lateral * turning
	_set_deg(targets, "pelvis", Vector3(
		1.5 + braking * 4.5 + reversal * 3.0,
		hip_yaw - turn_bank * 4.0,
		-turn_bank * 5.5
	))
	_set_deg(targets, "spine_01", Vector3(
		-run_lean * 0.5 - acceleration_lean * 0.65 + braking * 5.0,
		shoulder_yaw * 0.42 + turn_bank * 2.0,
		turn_bank * 3.0
	))
	_set_deg(targets, "spine_02", Vector3(
		-run_lean * 0.7 - acceleration_lean * 0.78 + braking * 4.0,
		shoulder_yaw * 0.72 + turn_bank * 3.0,
		turn_bank * 4.0
	))
	_set_deg(targets, "chest", Vector3(
		-run_lean - acceleration_lean + braking * 3.0,
		shoulder_yaw + turn_bank * 4.2,
		turn_bank * 5.0
	))
	_set_deg(targets, "neck", Vector3(
		run_lean * 0.25,
		-shoulder_yaw * 0.2 - turn_bank * 1.5,
		-turn_bank * 1.8
	))
	_set_deg(targets, "head", Vector3(
		run_lean * 0.18,
		-shoulder_yaw * 0.28 - turn_bank * 2.0,
		-turn_bank * 2.4
	))

	if reversal > 0.04:
		var catch_side: float = 1.0 if lateral >= 0.0 else -1.0
		_add_deg(targets, "pelvis", Vector3(6.0 * reversal, 0.0, -catch_side * 8.0 * reversal))
		_add_deg(targets, "spine_01", Vector3(6.5 * reversal, 0.0, catch_side * 5.0 * reversal))
		_add_deg(targets, "chest", Vector3(4.0 * reversal, 0.0, catch_side * 3.0 * reversal))
		_add_deg(targets, "thigh_l", Vector3(-8.0 * reversal, 0.0, catch_side * 2.0))
		_add_deg(targets, "thigh_r", Vector3(-8.0 * reversal, 0.0, catch_side * 2.0))
		_add_deg(targets, "shin_l", Vector3(10.0 * reversal, 0.0, 0.0))
		_add_deg(targets, "shin_r", Vector3(10.0 * reversal, 0.0, 0.0))

	var pelvis_offset := Vector3(
		-lateral * 0.02 * turning,
		-double_step * run_vertical_bob * weight
		- braking * 0.024
		- reversal * 0.034
		- start_weight * 0.025,
		-forward * start_weight * 0.018
	)
	_apply_landing_overlay(targets, pelvis_offset)
	return pelvis_offset


func _pose_airborne(targets: Dictionary, state_name: String) -> Vector3:
	if actor == null:
		return Vector3.ZERO
	var vertical_state: String = state_name
	var phase: float = 0.0
	var airborne_time: float = 0.0
	if locomotion_vertical_controller != null:
		vertical_state = locomotion_vertical_controller.vertical_state
		phase = locomotion_vertical_controller.get_phase_progress()
		airborne_time = locomotion_vertical_controller.airborne_time
	var vertical_speed: float = actor.velocity.y
	var planar_speed: float = Vector2(actor.velocity.x, actor.velocity.z).length()
	var travel_weight: float = clampf(
		planar_speed / maxf(locomotion_speed_reference, 0.1),
		0.0,
		1.0
	)
	var pelvis_offset := Vector3.ZERO

	match vertical_state:
		"launch":
			var compress: float = 1.0 - smoothstep(0.0, 0.42, phase)
			var extend: float = smoothstep(0.2, 1.0, phase)
			_set_deg(targets, "pelvis", Vector3(8.0 * compress - 4.0 * extend, 0.0, 0.0))
			_set_deg(targets, "spine_01", Vector3(10.0 * compress - 5.0 * extend, 0.0, 0.0))
			_set_deg(targets, "spine_02", Vector3(8.0 * compress - 6.0 * extend, 0.0, 0.0))
			_set_deg(targets, "chest", Vector3(7.0 * compress - 7.0 * extend, 0.0, 0.0))
			_set_deg(targets, "upper_arm_l", Vector3(-18.0 * compress - 25.0 * extend, 0.0, -18.0))
			_set_deg(targets, "upper_arm_r", Vector3(-18.0 * compress - 25.0 * extend, 0.0, 18.0))
			_set_deg(targets, "thigh_l", Vector3(-20.0 * compress + 16.0 * extend, 0.0, -4.0))
			_set_deg(targets, "thigh_r", Vector3(-20.0 * compress - 8.0 * extend, 0.0, 4.0))
			_set_deg(targets, "shin_l", Vector3(40.0 * compress + 18.0 * extend, 0.0, 0.0))
			_set_deg(targets, "shin_r", Vector3(38.0 * compress + 12.0 * extend, 0.0, 0.0))
			pelvis_offset.y = -0.08 * compress + 0.035 * extend
		"rising":
			var rise: float = clampf(vertical_speed / 7.0, 0.0, 1.0)
			var settle: float = smoothstep(0.0, 1.0, phase)
			_set_deg(targets, "pelvis", Vector3(-5.0 * rise, 1.5 * settle, 0.0))
			_set_deg(targets, "spine_01", Vector3(-7.0 * rise - travel_weight * 2.0, -1.5 * settle, 0.0))
			_set_deg(targets, "spine_02", Vector3(-8.0 * rise - travel_weight * 2.5, -2.0 * settle, 0.0))
			_set_deg(targets, "chest", Vector3(-8.0 * rise - travel_weight * 3.0, -2.4 * settle, 0.0))
			_set_deg(targets, "upper_arm_l", Vector3(-28.0 * rise, 0.0, -22.0 + settle * 5.0))
			_set_deg(targets, "upper_arm_r", Vector3(-28.0 * rise, 0.0, 22.0 - settle * 5.0))
			_set_deg(targets, "thigh_l", Vector3(25.0 - settle * 9.0, 0.0, -4.0))
			_set_deg(targets, "thigh_r", Vector3(-9.0 + settle * 6.0, 0.0, 4.0))
			_set_deg(targets, "shin_l", Vector3(34.0 - settle * 10.0, 0.0, 0.0))
			_set_deg(targets, "shin_r", Vector3(19.0 + settle * 4.0, 0.0, 0.0))
			pelvis_offset.y = 0.025
		"apex":
			var float_wave: float = sin(airborne_time * 5.0) * 0.5 + 0.5
			_set_deg(targets, "pelvis", Vector3(-1.5, 0.0, 0.0))
			_set_deg(targets, "spine_01", Vector3(-2.5, 0.0, 0.0))
			_set_deg(targets, "spine_02", Vector3(-3.0, 0.0, 0.0))
			_set_deg(targets, "chest", Vector3(-3.5, 0.0, 0.0))
			_set_deg(targets, "upper_arm_l", Vector3(-16.0, 0.0, -20.0 - float_wave * 3.0))
			_set_deg(targets, "upper_arm_r", Vector3(-16.0, 0.0, 20.0 + float_wave * 3.0))
			_set_deg(targets, "thigh_l", Vector3(17.0, 0.0, -4.0))
			_set_deg(targets, "thigh_r", Vector3(9.0, 0.0, 4.0))
			_set_deg(targets, "shin_l", Vector3(29.0, 0.0, 0.0))
			_set_deg(targets, "shin_r", Vector3(23.0, 0.0, 0.0))
			pelvis_offset.y = 0.03 + float_wave * 0.004
		_:
			var fall: float = clampf(absf(minf(vertical_speed, 0.0)) / 10.0, 0.0, 1.0)
			var landing_prep: float = smoothstep(0.2, 1.0, fall)
			_set_deg(targets, "pelvis", Vector3(4.0 * landing_prep, 0.0, 0.0))
			_set_deg(targets, "spine_01", Vector3(4.0 * landing_prep + travel_weight * 1.5, 0.0, 0.0))
			_set_deg(targets, "spine_02", Vector3(5.0 * landing_prep + travel_weight * 2.0, 0.0, 0.0))
			_set_deg(targets, "chest", Vector3(6.0 * landing_prep + travel_weight * 2.5, 0.0, 0.0))
			_set_deg(targets, "head", Vector3(-3.0 * landing_prep, 0.0, 0.0))
			_set_deg(targets, "upper_arm_l", Vector3(8.0 * fall, 0.0, -24.0 - fall * 7.0))
			_set_deg(targets, "upper_arm_r", Vector3(8.0 * fall, 0.0, 24.0 + fall * 7.0))
			_set_deg(targets, "thigh_l", Vector3(9.0 + landing_prep * 15.0, 0.0, -5.0))
			_set_deg(targets, "thigh_r", Vector3(6.0 + landing_prep * 13.0, 0.0, 5.0))
			_set_deg(targets, "shin_l", Vector3(24.0 + landing_prep * 15.0, 0.0, 0.0))
			_set_deg(targets, "shin_r", Vector3(21.0 + landing_prep * 14.0, 0.0, 0.0))
			_set_deg(targets, "foot_l", Vector3(-8.0 * landing_prep, 0.0, 0.0))
			_set_deg(targets, "foot_r", Vector3(-8.0 * landing_prep, 0.0, 0.0))
			pelvis_offset.y = 0.012 - landing_prep * 0.018

	animation_weight = clampf(
		absf(vertical_speed) / 7.0 + travel_weight * 0.25,
		0.2,
		1.0
	)
	return pelvis_offset


func _apply_stop_pose(targets: Dictionary, pelvis_offset: Vector3) -> void:
	var since_stop: float = elapsed - locomotion_stopped_at
	if since_stop < 0.0 or since_stop > stop_pose_seconds:
		return
	var progress: float = clampf(
		since_stop / maxf(stop_pose_seconds, 0.01),
		0.0,
		1.0
	)
	var weight: float = (1.0 - smoothstep(0.0, 1.0, progress)) * stop_speed_weight
	var side: float = stop_stride_sign
	_add_deg(targets, "pelvis", Vector3(5.0 * weight, side * 2.0 * weight, side * 3.0 * weight))
	_add_deg(targets, "spine_01", Vector3(6.0 * weight, -side * 1.5 * weight, -side * 2.0 * weight))
	_add_deg(targets, "spine_02", Vector3(5.0 * weight, -side * 2.0 * weight, -side * 2.5 * weight))
	_add_deg(targets, "chest", Vector3(4.0 * weight, -side * 2.5 * weight, -side * 3.0 * weight))
	_add_deg(targets, "thigh_l", Vector3(-11.0 * weight if side > 0.0 else -4.0 * weight, 0.0, 0.0))
	_add_deg(targets, "thigh_r", Vector3(-11.0 * weight if side < 0.0 else -4.0 * weight, 0.0, 0.0))
	_add_deg(targets, "shin_l", Vector3(18.0 * weight if side > 0.0 else 8.0 * weight, 0.0, 0.0))
	_add_deg(targets, "shin_r", Vector3(18.0 * weight if side < 0.0 else 8.0 * weight, 0.0, 0.0))
	pelvis_offset.y -= 0.045 * weight
	pelvis_offset.z += 0.025 * weight


func _apply_landing_overlay(targets: Dictionary, pelvis_offset: Vector3) -> void:
	if locomotion_vertical_controller == null or locomotion_vertical_controller.vertical_state != "landing":
		return
	var progress: float = locomotion_vertical_controller.get_phase_progress()
	var strength: float = clampf(locomotion_vertical_controller.last_landing_strength, 0.0, 1.0)
	if strength <= 0.001:
		return
	var compression: float
	if progress < 0.3:
		compression = smoothstep(0.0, 1.0, progress / 0.3)
	else:
		compression = 1.0 - smoothstep(0.3, 1.0, progress)
	compression *= strength
	var planar_speed: float = 0.0
	if actor != null:
		planar_speed = Vector2(actor.velocity.x, actor.velocity.z).length()
	var moving: float = clampf(planar_speed / maxf(locomotion_speed_reference, 0.1), 0.0, 1.0)
	_add_deg(targets, "pelvis", Vector3(12.0 * compression, 0.0, 0.0))
	_add_deg(targets, "spine_01", Vector3(12.0 * compression, 0.0, 0.0))
	_add_deg(targets, "spine_02", Vector3(14.0 * compression, 0.0, 0.0))
	_add_deg(targets, "chest", Vector3(16.0 * compression, 0.0, 0.0))
	_add_deg(targets, "head", Vector3(-6.0 * compression, 0.0, 0.0))
	_add_deg(targets, "thigh_l", Vector3(-19.0 * compression, 0.0, -2.0 * moving))
	_add_deg(targets, "thigh_r", Vector3(-17.0 * compression, 0.0, 2.0 * moving))
	_add_deg(targets, "shin_l", Vector3(39.0 * compression, 0.0, 0.0))
	_add_deg(targets, "shin_r", Vector3(36.0 * compression, 0.0, 0.0))
	_add_deg(targets, "upper_arm_l", Vector3(11.0 * compression, 0.0, -10.0 * compression))
	_add_deg(targets, "upper_arm_r", Vector3(11.0 * compression, 0.0, 10.0 * compression))
	pelvis_offset.y -= landing_compression_depth * compression
	pelvis_offset.z -= 0.025 * moving * compression


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["locomotion_v2"] = true
	data["locomotion_previous_state"] = previous_pose_state
	data["locomotion_start_age"] = snappedf(maxf(elapsed - locomotion_started_at, 0.0), 0.01)
	data["locomotion_stop_age"] = snappedf(maxf(elapsed - locomotion_stopped_at, 0.0), 0.01)
	data["last_locomotion_speed"] = snappedf(last_locomotion_speed, 0.01)
	data["vertical_phase"] = (
		locomotion_vertical_controller.vertical_state
		if locomotion_vertical_controller != null
		else "unavailable"
	)
	data["vertical_phase_progress"] = (
		snappedf(locomotion_vertical_controller.get_phase_progress(), 0.01)
		if locomotion_vertical_controller != null
		else 0.0
	)
	return data
