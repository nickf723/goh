extends Node3D
class_name GraceHumanoidSkeletalProxyV1

# Production-shape skeletal proxy for combat calibration.
# Gameplay remains authoritative. This node owns only character presentation:
# a real Skeleton3D hierarchy, bone-level pose blending, disposable anatomical
# geometry, and a right-hand socket that drives the existing WeaponController.

@export_group("Rig Response")
@export_range(4.0, 40.0, 0.5) var pose_response: float = 18.0
@export_range(0.8, 1.05, 0.01) var presentation_scale: float = 0.93
@export_range(3.0, 8.0, 0.05) var locomotion_speed_reference: float = 5.45
@export_range(0.2, 1.0, 0.01) var stride_strength: float = 0.72
@export_range(0.1, 0.8, 0.01) var arm_swing_strength: float = 0.5

@export_group("Weapon Socket")
@export var drive_weapon_socket: bool = true
@export var weapon_socket_offset: Vector3 = Vector3(0.0, -0.035, -0.015)
@export var weapon_socket_rotation_degrees: Vector3 = Vector3.ZERO

var actor: CharacterBody3D
var weapon_controller: WeaponController
var ground_motion_motor: PlayerGroundMotionMotor
var dodge_controller: PlayerDodgeController
var defense_controller: PlayerDefenseController
var action_state: PlayerActionState

var skeleton: Skeleton3D
var bones: Dictionary = {}
var current_rotations: Dictionary = {}
var current_pelvis_offset: Vector3 = Vector3.ZERO
var segment_parts: Array[Dictionary] = []
var follow_parts: Array[Dictionary] = []

var skin_material: StandardMaterial3D
var robe_material: StandardMaterial3D
var sash_material: StandardMaterial3D
var leather_material: StandardMaterial3D
var hair_material: StandardMaterial3D
var gold_material: StandardMaterial3D
var eye_material: StandardMaterial3D

var elapsed: float = 0.0
var stride_phase: float = 0.0
var animation_state: String = "idle"
var animation_weight: float = 0.0
var last_attack_id: String = "none"
var last_socket_error: float = 0.0


func _ready() -> void:
	process_priority = 205
	actor = get_parent() as CharacterBody3D
	if actor != null:
		weapon_controller = actor.get_node_or_null("WeaponController") as WeaponController
		ground_motion_motor = actor.get_node_or_null("GroundMotionMotor") as PlayerGroundMotionMotor
		dodge_controller = actor.get_node_or_null("PlayerDodgeController") as PlayerDodgeController
		defense_controller = actor.get_node_or_null("PlayerDefenseController") as PlayerDefenseController
		action_state = actor.get_node_or_null("PlayerActionState") as PlayerActionState
	scale = Vector3.ONE * presentation_scale
	_build_materials()
	_build_skeleton()
	_build_proxy_body()
	add_to_group("grace_humanoid_skeletal_proxy")
	add_to_group("debuggable")
	set_process(true)
	_sample_pose(0.0)


func _process(delta: float) -> void:
	_sample_pose(maxf(delta, 0.0))


func _sample_pose(delta: float) -> void:
	if skeleton == null:
		return
	elapsed += delta
	var target_rotations: Dictionary = {}
	var pelvis_offset: Vector3 = Vector3.ZERO
	var resolved_state: String = _resolve_state()
	animation_state = resolved_state

	match resolved_state:
		"hit":
			pelvis_offset = _pose_hit(target_rotations)
		"dodge":
			pelvis_offset = _pose_dodge(target_rotations)
		"attack":
			pelvis_offset = _pose_attack(target_rotations)
		"jump", "fall":
			pelvis_offset = _pose_airborne(target_rotations, resolved_state)
		"locomotion":
			pelvis_offset = _pose_locomotion(target_rotations, delta)
		_:
			pelvis_offset = _pose_idle(target_rotations)

	_apply_target_engagement(target_rotations)
	_blend_skeleton_pose(target_rotations, pelvis_offset, delta)
	_update_proxy_geometry()
	_update_weapon_socket()


func _resolve_state() -> String:
	if actor == null:
		return "idle"
	if action_state != null and action_state.is_staggered:
		return "hit"
	if defense_controller != null and defense_controller.is_hit_reaction_active():
		return "hit"
	if dodge_controller != null and dodge_controller.is_dodge_active():
		return "dodge"
	if weapon_controller != null and weapon_controller.current_attack != null:
		return "attack"
	if not actor.is_on_floor():
		return "jump" if actor.velocity.y > 0.05 else "fall"
	var planar_speed: float = Vector2(actor.velocity.x, actor.velocity.z).length()
	if planar_speed > 0.12:
		return "locomotion"
	return "idle"


func _pose_idle(targets: Dictionary) -> Vector3:
	var breath: float = sin(elapsed * 2.15)
	var sway: float = sin(elapsed * 0.82)
	_set_deg(targets, "pelvis", Vector3(0.0, sway * 1.2, 0.0))
	_set_deg(targets, "spine_01", Vector3(-1.0 + breath * 0.8, -sway * 0.8, 0.0))
	_set_deg(targets, "spine_02", Vector3(-1.2 + breath * 1.0, sway * 1.0, 0.0))
	_set_deg(targets, "chest", Vector3(-1.0 + breath * 0.7, sway * 1.2, 0.0))
	_set_deg(targets, "neck", Vector3(0.6, -sway * 1.0, 0.0))
	_set_deg(targets, "head", Vector3(-0.5, -sway * 1.4, 0.0))
	_set_deg(targets, "upper_arm_l", Vector3(-3.0, 0.0, -3.0))
	_set_deg(targets, "upper_arm_r", Vector3(-3.0, 0.0, 3.0))
	_set_deg(targets, "forearm_l", Vector3(-8.0, 0.0, 0.0))
	_set_deg(targets, "forearm_r", Vector3(-8.0, 0.0, 0.0))
	animation_weight = 0.0
	return Vector3(0.0, breath * 0.008, 0.0)


func _pose_locomotion(targets: Dictionary, delta: float) -> Vector3:
	if actor == null:
		return Vector3.ZERO
	var velocity := Vector3(actor.velocity.x, 0.0, actor.velocity.z)
	var speed: float = velocity.length()
	var weight: float = clampf(speed / maxf(locomotion_speed_reference, 0.1), 0.0, 1.0)
	animation_weight = weight
	stride_phase = fposmod(stride_phase + delta * (5.4 + speed * 1.15), TAU)
	var stride: float = sin(stride_phase)
	var double_step: float = absf(sin(stride_phase * 2.0))
	var local_velocity: Vector3 = actor.global_transform.basis.orthonormalized().inverse() * velocity
	var lateral: float = clampf(local_velocity.x / maxf(locomotion_speed_reference, 0.1), -1.0, 1.0)

	var braking: float = 0.0
	var reversal: float = 0.0
	var turning: float = 0.0
	if ground_motion_motor != null:
		var motion: Dictionary = ground_motion_motor.get_debug_data()
		braking = float(motion.get("braking_weight", 0.0))
		reversal = float(motion.get("reversal_weight", 0.0))
		turning = float(motion.get("turning_weight", 0.0))

	var leg_angle: float = stride * rad_to_deg(stride_strength) * weight
	var arm_angle: float = stride * rad_to_deg(arm_swing_strength) * weight
	_set_deg(targets, "thigh_l", Vector3(leg_angle, 0.0, -lateral * 2.0))
	_set_deg(targets, "thigh_r", Vector3(-leg_angle, 0.0, -lateral * 2.0))
	_set_deg(targets, "shin_l", Vector3(maxf(-stride, 0.0) * 34.0 * weight, 0.0, 0.0))
	_set_deg(targets, "shin_r", Vector3(maxf(stride, 0.0) * 34.0 * weight, 0.0, 0.0))
	_set_deg(targets, "foot_l", Vector3(-stride * 8.0 * weight, 0.0, 0.0))
	_set_deg(targets, "foot_r", Vector3(stride * 8.0 * weight, 0.0, 0.0))
	_set_deg(targets, "upper_arm_l", Vector3(-arm_angle, 0.0, -4.0))
	_set_deg(targets, "upper_arm_r", Vector3(arm_angle, 0.0, 4.0))
	_set_deg(targets, "forearm_l", Vector3(-10.0 - maxf(stride, 0.0) * 12.0 * weight, 0.0, 0.0))
	_set_deg(targets, "forearm_r", Vector3(-10.0 - maxf(-stride, 0.0) * 12.0 * weight, 0.0, 0.0))
	_set_deg(targets, "pelvis", Vector3(0.0, -stride * 4.0 * weight, -lateral * 3.0 * turning))
	_set_deg(targets, "spine_01", Vector3(-2.5 * weight + braking * 4.0, stride * 2.4 * weight, lateral * 3.0 * turning))
	_set_deg(targets, "spine_02", Vector3(-2.0 * weight + braking * 3.0, stride * 3.0 * weight, lateral * 3.5 * turning))
	_set_deg(targets, "chest", Vector3(-1.5 * weight + braking * 2.5, stride * 3.2 * weight, lateral * 4.0 * turning))
	_set_deg(targets, "neck", Vector3(1.2 * weight, -stride * 1.6 * weight, -lateral * 1.5 * turning))
	_set_deg(targets, "head", Vector3(-0.8 * weight, -stride * 1.8 * weight, -lateral * 2.0 * turning))

	if reversal > 0.05:
		_add_deg(targets, "pelvis", Vector3(5.0 * reversal, 0.0, -lateral * 8.0 * reversal))
		_add_deg(targets, "spine_01", Vector3(7.0 * reversal, 0.0, lateral * 5.0 * reversal))
		_add_deg(targets, "thigh_l", Vector3(-7.0 * reversal, 0.0, 0.0))
		_add_deg(targets, "thigh_r", Vector3(-7.0 * reversal, 0.0, 0.0))

	return Vector3(
		-lateral * 0.018 * turning,
		-double_step * 0.028 * weight - braking * 0.025 - reversal * 0.035,
		0.0
	)


func _pose_dodge(targets: Dictionary) -> Vector3:
	if dodge_controller == null or actor == null:
		return Vector3.ZERO
	var progress: float = dodge_controller.get_normalized_progress()
	var wave: float = sin(clampf(progress, 0.0, 1.0) * PI)
	var direction: Vector3 = dodge_controller.dodge_direction
	var local_direction: Vector3 = actor.global_transform.basis.orthonormalized().inverse() * direction
	var side: float = clampf(local_direction.x, -1.0, 1.0)
	var forward: float = clampf(-local_direction.z, -1.0, 1.0)
	_set_deg(targets, "pelvis", Vector3(-6.0 * forward * wave, -side * 6.0 * wave, -side * 12.0 * wave))
	_set_deg(targets, "spine_01", Vector3(14.0 * forward * wave, side * 5.0 * wave, side * 9.0 * wave))
	_set_deg(targets, "spine_02", Vector3(16.0 * forward * wave, side * 7.0 * wave, side * 10.0 * wave))
	_set_deg(targets, "chest", Vector3(20.0 * forward * wave, side * 8.0 * wave, side * 12.0 * wave))
	_set_deg(targets, "head", Vector3(-8.0 * forward * wave, -side * 5.0 * wave, -side * 5.0 * wave))
	_set_deg(targets, "upper_arm_l", Vector3(-28.0 * wave, -side * 8.0, -18.0 * wave))
	_set_deg(targets, "upper_arm_r", Vector3(-34.0 * wave, -side * 8.0, 18.0 * wave))
	_set_deg(targets, "forearm_l", Vector3(-24.0 * wave, 0.0, 0.0))
	_set_deg(targets, "forearm_r", Vector3(-28.0 * wave, 0.0, 0.0))
	_set_deg(targets, "thigh_l", Vector3((-34.0 + side * 12.0) * wave, 0.0, -side * 7.0 * wave))
	_set_deg(targets, "thigh_r", Vector3((-26.0 - side * 12.0) * wave, 0.0, -side * 7.0 * wave))
	_set_deg(targets, "shin_l", Vector3(46.0 * wave, 0.0, 0.0))
	_set_deg(targets, "shin_r", Vector3(38.0 * wave, 0.0, 0.0))
	animation_weight = wave
	return Vector3(-side * 0.025 * wave, -0.115 * wave, forward * -0.025 * wave)


func _pose_airborne(targets: Dictionary, state_name: String) -> Vector3:
	if actor == null:
		return Vector3.ZERO
	var vertical_speed: float = actor.velocity.y
	if state_name == "jump":
		var rise: float = clampf(vertical_speed / 7.0, 0.0, 1.0)
		_set_deg(targets, "pelvis", Vector3(-4.0, 0.0, 0.0))
		_set_deg(targets, "spine_01", Vector3(-7.0 * rise, 0.0, 0.0))
		_set_deg(targets, "chest", Vector3(-8.0 * rise, 0.0, 0.0))
		_set_deg(targets, "upper_arm_l", Vector3(-24.0 * rise, 0.0, -20.0))
		_set_deg(targets, "upper_arm_r", Vector3(-24.0 * rise, 0.0, 20.0))
		_set_deg(targets, "thigh_l", Vector3(24.0, 0.0, -3.0))
		_set_deg(targets, "thigh_r", Vector3(-8.0, 0.0, 3.0))
		_set_deg(targets, "shin_l", Vector3(34.0, 0.0, 0.0))
		_set_deg(targets, "shin_r", Vector3(18.0, 0.0, 0.0))
		animation_weight = rise
		return Vector3(0.0, 0.025, 0.0)
	var fall: float = clampf(absf(vertical_speed) / 9.0, 0.0, 1.0)
	_set_deg(targets, "spine_01", Vector3(5.0 * fall, 0.0, 0.0))
	_set_deg(targets, "chest", Vector3(7.0 * fall, 0.0, 0.0))
	_set_deg(targets, "upper_arm_l", Vector3(16.0, 0.0, -48.0 * fall))
	_set_deg(targets, "upper_arm_r", Vector3(16.0, 0.0, 48.0 * fall))
	_set_deg(targets, "thigh_l", Vector3(-8.0, 0.0, -7.0))
	_set_deg(targets, "thigh_r", Vector3(12.0, 0.0, 7.0))
	_set_deg(targets, "shin_l", Vector3(18.0, 0.0, 0.0))
	_set_deg(targets, "shin_r", Vector3(28.0, 0.0, 0.0))
	animation_weight = fall
	return Vector3.ZERO


func _pose_hit(targets: Dictionary) -> Vector3:
	var pulse: float = 0.9 + sin(elapsed * 31.0) * 0.1
	_set_deg(targets, "pelvis", Vector3(7.0 * pulse, -5.0, -5.0))
	_set_deg(targets, "spine_01", Vector3(11.0 * pulse, 7.0, 7.0))
	_set_deg(targets, "spine_02", Vector3(12.0 * pulse, 8.0, 8.0))
	_set_deg(targets, "chest", Vector3(15.0 * pulse, 9.0, 9.0))
	_set_deg(targets, "neck", Vector3(-10.0 * pulse, -5.0, -4.0))
	_set_deg(targets, "head", Vector3(-12.0 * pulse, -6.0, -5.0))
	_set_deg(targets, "upper_arm_l", Vector3(22.0, 0.0, -28.0))
	_set_deg(targets, "upper_arm_r", Vector3(30.0, 0.0, 32.0))
	_set_deg(targets, "forearm_l", Vector3(-20.0, 0.0, 0.0))
	_set_deg(targets, "forearm_r", Vector3(-26.0, 0.0, 0.0))
	_set_deg(targets, "thigh_l", Vector3(-10.0, 0.0, -4.0))
	_set_deg(targets, "thigh_r", Vector3(12.0, 0.0, 4.0))
	animation_weight = 1.0
	return Vector3(0.0, -0.055, 0.035)


func _pose_attack(targets: Dictionary) -> Vector3:
	if weapon_controller == null or weapon_controller.current_attack == null:
		return Vector3.ZERO
	var attack: WeaponAttackDefinition = weapon_controller.current_attack
	last_attack_id = attack.attack_id
	var speed: float = maxf(weapon_controller.get_attack_speed(), 0.05)
	var startup: float = maxf(attack.get_startup_duration(speed), 0.001)
	var active: float = maxf(attack.get_active_duration(speed), 0.001)
	var recovery: float = maxf(attack.get_recovery_duration(speed), 0.001)
	var time: float = maxf(weapon_controller.current_attack_elapsed, 0.0)

	var windup: Dictionary = _build_attack_stage_pose(attack, "windup")
	var contact: Dictionary = _build_attack_stage_pose(attack, "contact")
	var follow: Dictionary = _build_attack_stage_pose(attack, "follow")
	var recover: Dictionary = _build_attack_stage_pose(attack, "recover")
	var sampled: Dictionary
	if time < startup:
		var p: float = smoothstep(0.0, 1.0, clampf(time / startup, 0.0, 1.0))
		sampled = _blend_pose({}, windup, p)
	elif time < startup + active:
		var p: float = smoothstep(0.0, 1.0, clampf((time - startup) / active, 0.0, 1.0))
		sampled = _blend_pose(windup, contact, p)
	else:
		var p: float = clampf((time - startup - active) / recovery, 0.0, 1.0)
		if p < 0.48:
			sampled = _blend_pose(contact, follow, smoothstep(0.0, 1.0, p / 0.48))
		else:
			sampled = _blend_pose(follow, recover, smoothstep(0.0, 1.0, (p - 0.48) / 0.52))

	for bone_name: Variant in bones.keys():
		var key: String = str(bone_name)
		if sampled.has(key):
			targets[key] = sampled[key]
	animation_weight = 1.0
	return sampled.get("__pelvis_offset", Vector3.ZERO) as Vector3


func _build_attack_stage_pose(attack: WeaponAttackDefinition, stage: String) -> Dictionary:
	var pose: Dictionary = {}
	if attack == null:
		return pose
	var profile: String = attack.character_pose_id.to_lower()
	var attack_name: String = attack.attack_id.to_lower()
	var is_thrust: bool = profile.contains("thrust") or attack.extra_tags.has("thrust") or attack.extra_tags.has("pierce")
	var is_overhead: bool = profile.contains("overhead") or attack_name == "sword_h0"
	var is_rising: bool = profile.contains("rising") or attack.extra_tags.has("launcher")
	var is_spin: bool = profile.contains("spin") or profile.contains("orbit") or attack.extra_tags.has("spin")
	var side: float = _attack_side(attack)

	if is_thrust:
		_build_thrust_pose(pose, stage, attack.input_kind == "heavy")
	elif is_overhead:
		_build_overhead_pose(pose, stage, attack.input_kind == "heavy")
	elif is_rising:
		_build_rising_pose(pose, stage, side, attack.input_kind == "heavy")
	elif is_spin:
		_build_cut_pose(pose, stage, side, true, attack.input_kind == "heavy")
	else:
		_build_cut_pose(pose, stage, side, false, attack.input_kind == "heavy")
	return pose


func _build_cut_pose(pose: Dictionary, stage: String, side: float, wide: bool, heavy: bool) -> void:
	var weight: float = 1.18 if heavy else 1.0
	var width: float = 1.28 if wide else 1.0
	match stage:
		"windup":
			_set_pose_deg(pose, "pelvis", Vector3(2.0, -12.0 * side * width, -2.0 * side))
			_set_pose_deg(pose, "spine_01", Vector3(-2.0, -8.0 * side * width, 2.0 * side))
			_set_pose_deg(pose, "spine_02", Vector3(-3.0, -12.0 * side * width, 3.0 * side))
			_set_pose_deg(pose, "chest", Vector3(-4.0, -18.0 * side * width, 4.0 * side))
			_set_pose_deg(pose, "head", Vector3(1.0, 8.0 * side, -1.0 * side))
			_set_pose_deg(pose, "clavicle_r", Vector3(0.0, -8.0 * side, 8.0 * side))
			_set_pose_deg(pose, "upper_arm_r", Vector3(64.0, -18.0 * side, 30.0 * side))
			_set_pose_deg(pose, "forearm_r", Vector3(-38.0, 10.0 * side, -10.0 * side))
			_set_pose_deg(pose, "hand_r", Vector3(-10.0, -12.0 * side, 14.0 * side))
			_set_pose_deg(pose, "upper_arm_l", Vector3(18.0, 8.0 * side, -18.0 * side))
			_set_pose_deg(pose, "forearm_l", Vector3(-16.0, 0.0, 0.0))
			_apply_cut_leg_pose(pose, side, -1.0)
			pose["__pelvis_offset"] = Vector3(0.018 * side, -0.035 * weight, 0.02)
		"contact":
			_set_pose_deg(pose, "pelvis", Vector3(-2.0, 14.0 * side * width * weight, 2.0 * side))
			_set_pose_deg(pose, "spine_01", Vector3(-4.0, 11.0 * side * width * weight, -2.0 * side))
			_set_pose_deg(pose, "spine_02", Vector3(-5.0, 17.0 * side * width * weight, -3.0 * side))
			_set_pose_deg(pose, "chest", Vector3(-6.0, 27.0 * side * width * weight, -4.0 * side))
			_set_pose_deg(pose, "head", Vector3(-1.0, -9.0 * side, 1.0 * side))
			_set_pose_deg(pose, "clavicle_r", Vector3(0.0, 10.0 * side, -7.0 * side))
			_set_pose_deg(pose, "upper_arm_r", Vector3(94.0, 30.0 * side, -28.0 * side))
			_set_pose_deg(pose, "forearm_r", Vector3(-12.0, -12.0 * side, 8.0 * side))
			_set_pose_deg(pose, "hand_r", Vector3(8.0, 14.0 * side, -16.0 * side))
			_set_pose_deg(pose, "upper_arm_l", Vector3(32.0, -10.0 * side, 26.0 * side))
			_set_pose_deg(pose, "forearm_l", Vector3(-24.0, 0.0, 0.0))
			_apply_cut_leg_pose(pose, side, 1.0)
			pose["__pelvis_offset"] = Vector3(-0.02 * side, -0.045 * weight, -0.055 * weight)
		"follow":
			_set_pose_deg(pose, "pelvis", Vector3(-3.0, 21.0 * side * width * weight, 3.0 * side))
			_set_pose_deg(pose, "spine_01", Vector3(-5.0, 16.0 * side * width * weight, -3.0 * side))
			_set_pose_deg(pose, "spine_02", Vector3(-6.0, 23.0 * side * width * weight, -4.0 * side))
			_set_pose_deg(pose, "chest", Vector3(-7.0, 36.0 * side * width * weight, -5.0 * side))
			_set_pose_deg(pose, "head", Vector3(-2.0, -14.0 * side, 2.0 * side))
			_set_pose_deg(pose, "upper_arm_r", Vector3(108.0, 42.0 * side, -34.0 * side))
			_set_pose_deg(pose, "forearm_r", Vector3(4.0, -16.0 * side, 10.0 * side))
			_set_pose_deg(pose, "hand_r", Vector3(12.0, 18.0 * side, -18.0 * side))
			_set_pose_deg(pose, "upper_arm_l", Vector3(40.0, -12.0 * side, 30.0 * side))
			_apply_cut_leg_pose(pose, side, 1.15)
			pose["__pelvis_offset"] = Vector3(-0.025 * side, -0.05 * weight, -0.075 * weight)
		_:
			_set_pose_deg(pose, "pelvis", Vector3(2.0, 3.0 * side, 0.0))
			_set_pose_deg(pose, "spine_01", Vector3(3.0, 2.0 * side, 0.0))
			_set_pose_deg(pose, "spine_02", Vector3(3.0, 3.0 * side, 0.0))
			_set_pose_deg(pose, "chest", Vector3(4.0, 5.0 * side, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(20.0, 5.0 * side, 6.0 * side))
			_set_pose_deg(pose, "forearm_r", Vector3(-18.0, 0.0, 0.0))
			_set_pose_deg(pose, "thigh_l", Vector3(-4.0, 0.0, 0.0))
			_set_pose_deg(pose, "thigh_r", Vector3(5.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.018, -0.012)


func _build_thrust_pose(pose: Dictionary, stage: String, heavy: bool) -> void:
	var weight: float = 1.2 if heavy else 1.0
	match stage:
		"windup":
			_set_pose_deg(pose, "pelvis", Vector3(4.0, -5.0, 0.0))
			_set_pose_deg(pose, "spine_01", Vector3(3.0, -5.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(1.0, -8.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(58.0, -18.0, 18.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-72.0, 8.0, -5.0))
			_set_pose_deg(pose, "hand_r", Vector3(-8.0, -5.0, 0.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(38.0, 8.0, -20.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-36.0, 0.0, 0.0))
			_set_pose_deg(pose, "thigh_l", Vector3(-15.0, 0.0, -3.0))
			_set_pose_deg(pose, "thigh_r", Vector3(20.0, 0.0, 3.0))
			_set_pose_deg(pose, "shin_l", Vector3(16.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.045, 0.055)
		"contact":
			_set_pose_deg(pose, "pelvis", Vector3(-5.0, 8.0, 0.0))
			_set_pose_deg(pose, "spine_01", Vector3(-7.0, 6.0, 0.0))
			_set_pose_deg(pose, "spine_02", Vector3(-9.0, 6.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(-12.0, 6.0, 0.0))
			_set_pose_deg(pose, "head", Vector3(4.0, -2.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(94.0, 3.0, -6.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-5.0, 0.0, 0.0))
			_set_pose_deg(pose, "hand_r", Vector3(0.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(62.0, -4.0, -12.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-20.0, 0.0, 0.0))
			_set_pose_deg(pose, "thigh_l", Vector3(20.0, 0.0, -2.0))
			_set_pose_deg(pose, "thigh_r", Vector3(-24.0, 0.0, 2.0))
			_set_pose_deg(pose, "shin_r", Vector3(18.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.035, -0.11 * weight)
		"follow":
			_set_pose_deg(pose, "pelvis", Vector3(-7.0, 10.0, 0.0))
			_set_pose_deg(pose, "spine_01", Vector3(-9.0, 8.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(-15.0, 8.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(102.0, 5.0, -6.0))
			_set_pose_deg(pose, "forearm_r", Vector3(4.0, 0.0, 0.0))
			_set_pose_deg(pose, "thigh_l", Vector3(24.0, 0.0, 0.0))
			_set_pose_deg(pose, "thigh_r", Vector3(-28.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.04, -0.14 * weight)
		_:
			_set_pose_deg(pose, "pelvis", Vector3(3.0, 2.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(4.0, 2.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(18.0, 0.0, 4.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-18.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.018, -0.02)


func _build_overhead_pose(pose: Dictionary, stage: String, heavy: bool) -> void:
	var weight: float = 1.18 if heavy else 1.0
	match stage:
		"windup":
			_set_pose_deg(pose, "pelvis", Vector3(8.0, -4.0, 0.0))
			_set_pose_deg(pose, "spine_01", Vector3(8.0, -3.0, 0.0))
			_set_pose_deg(pose, "spine_02", Vector3(10.0, -2.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(12.0, -2.0, 0.0))
			_set_pose_deg(pose, "head", Vector3(-6.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(154.0, -8.0, 12.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-34.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(138.0, 8.0, -18.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-50.0, 0.0, 0.0))
			_set_pose_deg(pose, "thigh_l", Vector3(-16.0, 0.0, -4.0))
			_set_pose_deg(pose, "thigh_r", Vector3(-14.0, 0.0, 4.0))
			_set_pose_deg(pose, "shin_l", Vector3(22.0, 0.0, 0.0))
			_set_pose_deg(pose, "shin_r", Vector3(20.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.09, 0.025)
		"contact":
			_set_pose_deg(pose, "pelvis", Vector3(-8.0, 4.0, 0.0))
			_set_pose_deg(pose, "spine_01", Vector3(-10.0, 3.0, 0.0))
			_set_pose_deg(pose, "spine_02", Vector3(-13.0, 2.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(-17.0, 2.0, 0.0))
			_set_pose_deg(pose, "head", Vector3(7.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(68.0, 6.0, 12.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-8.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(76.0, -4.0, -14.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-18.0, 0.0, 0.0))
			_set_pose_deg(pose, "thigh_l", Vector3(10.0, 0.0, -3.0))
			_set_pose_deg(pose, "thigh_r", Vector3(8.0, 0.0, 3.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.075, -0.06 * weight)
		"follow":
			_set_pose_deg(pose, "pelvis", Vector3(-12.0, 5.0, 0.0))
			_set_pose_deg(pose, "spine_01", Vector3(-14.0, 4.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(-22.0, 3.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(42.0, 8.0, 14.0))
			_set_pose_deg(pose, "forearm_r", Vector3(8.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(50.0, -5.0, -14.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.08, -0.08 * weight)
		_:
			_set_pose_deg(pose, "pelvis", Vector3(4.0, 0.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(6.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(20.0, 0.0, 6.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-18.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.025, -0.015)


func _build_rising_pose(pose: Dictionary, stage: String, side: float, heavy: bool) -> void:
	var weight: float = 1.18 if heavy else 1.0
	match stage:
		"windup":
			_set_pose_deg(pose, "pelvis", Vector3(9.0, -10.0 * side, 4.0 * side))
			_set_pose_deg(pose, "spine_01", Vector3(8.0, -8.0 * side, 3.0 * side))
			_set_pose_deg(pose, "chest", Vector3(10.0, -12.0 * side, 5.0 * side))
			_set_pose_deg(pose, "upper_arm_r", Vector3(44.0, -22.0 * side, 54.0 * side))
			_set_pose_deg(pose, "forearm_r", Vector3(-48.0, 8.0 * side, -12.0 * side))
			_set_pose_deg(pose, "thigh_l", Vector3(-22.0, 0.0, -4.0))
			_set_pose_deg(pose, "thigh_r", Vector3(-12.0, 0.0, 4.0))
			_set_pose_deg(pose, "shin_l", Vector3(30.0, 0.0, 0.0))
			_set_pose_deg(pose, "shin_r", Vector3(22.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.02 * side, -0.095, 0.03)
		"contact":
			_set_pose_deg(pose, "pelvis", Vector3(-7.0, 13.0 * side, -4.0 * side))
			_set_pose_deg(pose, "spine_01", Vector3(-9.0, 10.0 * side, -3.0 * side))
			_set_pose_deg(pose, "chest", Vector3(-14.0, 18.0 * side, -5.0 * side))
			_set_pose_deg(pose, "upper_arm_r", Vector3(116.0, 18.0 * side, -42.0 * side))
			_set_pose_deg(pose, "forearm_r", Vector3(-4.0, -8.0 * side, 10.0 * side))
			_set_pose_deg(pose, "thigh_l", Vector3(14.0, 0.0, -3.0))
			_set_pose_deg(pose, "thigh_r", Vector3(8.0, 0.0, 3.0))
			pose["__pelvis_offset"] = Vector3(-0.02 * side, -0.025, -0.075 * weight)
		"follow":
			_set_pose_deg(pose, "pelvis", Vector3(-9.0, 18.0 * side, -5.0 * side))
			_set_pose_deg(pose, "chest", Vector3(-18.0, 25.0 * side, -6.0 * side))
			_set_pose_deg(pose, "upper_arm_r", Vector3(138.0, 24.0 * side, -52.0 * side))
			_set_pose_deg(pose, "forearm_r", Vector3(8.0, -10.0 * side, 12.0 * side))
			pose["__pelvis_offset"] = Vector3(-0.025 * side, -0.02, -0.085 * weight)
		_:
			_set_pose_deg(pose, "pelvis", Vector3(3.0, 3.0 * side, 0.0))
			_set_pose_deg(pose, "chest", Vector3(5.0, 5.0 * side, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(22.0, 4.0 * side, 8.0 * side))
			_set_pose_deg(pose, "forearm_r", Vector3(-16.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.018, -0.015)


func _apply_cut_leg_pose(pose: Dictionary, side: float, phase: float) -> void:
	var plant_right: bool = side > 0.0
	var planted: String = "thigh_r" if plant_right else "thigh_l"
	var driving: String = "thigh_l" if plant_right else "thigh_r"
	var planted_shin: String = "shin_r" if plant_right else "shin_l"
	var driving_shin: String = "shin_l" if plant_right else "shin_r"
	_set_pose_deg(pose, planted, Vector3(-10.0 * phase, 0.0, 3.0 * side))
	_set_pose_deg(pose, driving, Vector3(13.0 * phase, 0.0, -3.0 * side))
	_set_pose_deg(pose, planted_shin, Vector3(14.0 + maxf(phase, 0.0) * 4.0, 0.0, 0.0))
	_set_pose_deg(pose, driving_shin, Vector3(8.0 + maxf(-phase, 0.0) * 6.0, 0.0, 0.0))


func _apply_target_engagement(targets: Dictionary) -> void:
	if animation_state != "attack" or actor == null or weapon_controller == null:
		return
	if not weapon_controller.has_method("get_engagement_aim_point"):
		return
	var aim_value: Variant = weapon_controller.call("get_engagement_aim_point")
	if not (aim_value is Vector3):
		return
	var aim_point: Vector3 = aim_value as Vector3
	if aim_point == Vector3.ZERO:
		return
	var offset: Vector3 = aim_point - actor.global_position
	var planar: Vector3 = offset
	planar.y = 0.0
	if planar.length_squared() <= 0.0001:
		return
	var local: Vector3 = actor.global_transform.basis.orthonormalized().inverse() * planar.normalized()
	var yaw: float = clampf(rad_to_deg(atan2(-local.x, -local.z)), -30.0, 30.0)
	_add_deg(targets, "spine_02", Vector3(0.0, yaw * 0.16, 0.0))
	_add_deg(targets, "chest", Vector3(0.0, yaw * 0.24, -local.x * 2.0))
	_add_deg(targets, "neck", Vector3(0.0, yaw * 0.16, 0.0))
	_add_deg(targets, "head", Vector3(0.0, yaw * 0.28, 0.0))


func _blend_skeleton_pose(targets: Dictionary, pelvis_offset: Vector3, delta: float) -> void:
	var blend: float = 1.0 if delta <= 0.0 else 1.0 - exp(-pose_response * delta)
	blend = clampf(blend, 0.0, 1.0)
	for bone_name_variant: Variant in bones.keys():
		var bone_name: String = str(bone_name_variant)
		var index: int = int(bones[bone_name])
		var target_euler: Vector3 = targets.get(bone_name, Vector3.ZERO) as Vector3
		var target_rotation: Quaternion = Basis.from_euler(target_euler).get_rotation_quaternion()
		var current: Quaternion = current_rotations.get(bone_name, Quaternion.IDENTITY) as Quaternion
		current = current.slerp(target_rotation, blend).normalized()
		current_rotations[bone_name] = current
		skeleton.set_bone_pose_rotation(index, current)
	current_pelvis_offset = current_pelvis_offset.lerp(pelvis_offset, blend)
	if bones.has("pelvis"):
		skeleton.set_bone_pose_position(int(bones["pelvis"]), current_pelvis_offset)


func _build_skeleton() -> void:
	skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	add_child(skeleton)
	_add_bone("root", "", Vector3.ZERO)
	_add_bone("pelvis", "root", Vector3(0.0, 0.88, 0.0))
	_add_bone("spine_01", "pelvis", Vector3(0.0, 0.16, 0.0))
	_add_bone("spine_02", "spine_01", Vector3(0.0, 0.15, 0.0))
	_add_bone("chest", "spine_02", Vector3(0.0, 0.17, 0.0))
	_add_bone("neck", "chest", Vector3(0.0, 0.17, -0.005))
	_add_bone("head", "neck", Vector3(0.0, 0.18, -0.01))
	_add_bone("clavicle_l", "chest", Vector3(-0.12, 0.11, 0.0))
	_add_bone("upper_arm_l", "clavicle_l", Vector3(-0.14, -0.02, 0.0))
	_add_bone("forearm_l", "upper_arm_l", Vector3(-0.02, -0.30, 0.0))
	_add_bone("hand_l", "forearm_l", Vector3(-0.015, -0.27, 0.0))
	_add_bone("clavicle_r", "chest", Vector3(0.12, 0.11, 0.0))
	_add_bone("upper_arm_r", "clavicle_r", Vector3(0.14, -0.02, 0.0))
	_add_bone("forearm_r", "upper_arm_r", Vector3(0.02, -0.30, 0.0))
	_add_bone("hand_r", "forearm_r", Vector3(0.015, -0.27, 0.0))
	_add_bone("thigh_l", "pelvis", Vector3(-0.145, -0.08, 0.0))
	_add_bone("shin_l", "thigh_l", Vector3(0.0, -0.40, 0.0))
	_add_bone("foot_l", "shin_l", Vector3(0.0, -0.37, -0.035))
	_add_bone("toe_l", "foot_l", Vector3(0.0, -0.04, -0.20))
	_add_bone("thigh_r", "pelvis", Vector3(0.145, -0.08, 0.0))
	_add_bone("shin_r", "thigh_r", Vector3(0.0, -0.40, 0.0))
	_add_bone("foot_r", "shin_r", Vector3(0.0, -0.37, -0.035))
	_add_bone("toe_r", "foot_r", Vector3(0.0, -0.04, -0.20))


func _add_bone(bone_name: String, parent_name: String, rest_origin: Vector3) -> void:
	skeleton.add_bone(bone_name)
	var index: int = skeleton.find_bone(bone_name)
	if parent_name != "" and bones.has(parent_name):
		skeleton.set_bone_parent(index, int(bones[parent_name]))
	skeleton.set_bone_rest(index, Transform3D(Basis.IDENTITY, rest_origin))
	bones[bone_name] = index
	current_rotations[bone_name] = Quaternion.IDENTITY


func _build_materials() -> void:
	skin_material = _make_material(Color(0.72, 0.53, 0.42, 1.0), 0.04, 0.68)
	robe_material = _make_material(Color(0.78, 0.72, 0.61, 1.0), 0.0, 0.78)
	sash_material = _make_material(Color(0.32, 0.14, 0.55, 1.0), 0.12, 0.48)
	leather_material = _make_material(Color(0.14, 0.095, 0.075, 1.0), 0.05, 0.72)
	hair_material = _make_material(Color(0.085, 0.065, 0.075, 1.0), 0.05, 0.62)
	gold_material = _make_material(Color(0.76, 0.55, 0.19, 1.0), 0.65, 0.28)
	eye_material = _make_material(Color(0.055, 0.06, 0.075, 1.0), 0.0, 0.45)


func _make_material(color: Color, metallic_value: float, roughness_value: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic_value
	material.roughness = roughness_value
	return material


func _build_proxy_body() -> void:
	_create_segment("UpperArmL", "upper_arm_l", "forearm_l", 0.065, robe_material)
	_create_segment("ForearmL", "forearm_l", "hand_l", 0.058, skin_material)
	_create_segment("UpperArmR", "upper_arm_r", "forearm_r", 0.065, robe_material)
	_create_segment("ForearmR", "forearm_r", "hand_r", 0.058, skin_material)
	_create_segment("ThighL", "thigh_l", "shin_l", 0.09, robe_material)
	_create_segment("ShinL", "shin_l", "foot_l", 0.072, leather_material)
	_create_segment("ThighR", "thigh_r", "shin_r", 0.09, robe_material)
	_create_segment("ShinR", "shin_r", "foot_r", 0.072, leather_material)

	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = 0.235
	torso_mesh.height = 0.52
	torso_mesh.radial_segments = 14
	torso_mesh.rings = 4
	_create_follow_mesh("Torso", "chest", torso_mesh, robe_material, Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, 1.0, 0.76)), Vector3(0.0, -0.17, 0.0)))

	var pelvis_mesh := CapsuleMesh.new()
	pelvis_mesh.radius = 0.22
	pelvis_mesh.height = 0.34
	pelvis_mesh.radial_segments = 12
	pelvis_mesh.rings = 3
	_create_follow_mesh("Pelvis", "pelvis", pelvis_mesh, robe_material, Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, 0.9, 0.78)), Vector3(0.0, -0.02, 0.0)))

	var skirt_mesh := CylinderMesh.new()
	skirt_mesh.top_radius = 0.24
	skirt_mesh.bottom_radius = 0.34
	skirt_mesh.height = 0.42
	skirt_mesh.radial_segments = 14
	_create_follow_mesh("ShortTunic", "pelvis", skirt_mesh, robe_material, Transform3D(Basis.IDENTITY, Vector3(0.0, -0.19, 0.015)))

	var sash_mesh := CylinderMesh.new()
	sash_mesh.top_radius = 0.255
	sash_mesh.bottom_radius = 0.255
	sash_mesh.height = 0.105
	sash_mesh.radial_segments = 14
	_create_follow_mesh("WaistSash", "pelvis", sash_mesh, sash_material, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.08, -0.005)))

	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.235
	head_mesh.height = 0.47
	head_mesh.radial_segments = 18
	head_mesh.rings = 10
	_create_follow_mesh("Head", "head", head_mesh, skin_material, Transform3D(Basis.IDENTITY.scaled(Vector3(0.94, 1.04, 0.9)), Vector3(0.0, 0.055, -0.01)))

	var hair_mesh := SphereMesh.new()
	hair_mesh.radius = 0.245
	hair_mesh.height = 0.49
	hair_mesh.radial_segments = 16
	hair_mesh.rings = 9
	_create_follow_mesh("HairMass", "head", hair_mesh, hair_material, Transform3D(Basis.IDENTITY.scaled(Vector3(1.02, 1.08, 0.92)), Vector3(0.0, 0.075, 0.055)))

	var hand_mesh := SphereMesh.new()
	hand_mesh.radius = 0.072
	hand_mesh.height = 0.144
	hand_mesh.radial_segments = 10
	hand_mesh.rings = 5
	_create_follow_mesh("HandL", "hand_l", hand_mesh, skin_material, Transform3D(Basis.IDENTITY.scaled(Vector3(0.88, 1.18, 0.78)), Vector3(0.0, -0.035, -0.015)))
	_create_follow_mesh("HandR", "hand_r", hand_mesh, skin_material, Transform3D(Basis.IDENTITY.scaled(Vector3(0.88, 1.18, 0.78)), Vector3(0.0, -0.035, -0.015)))

	var foot_mesh := BoxMesh.new()
	foot_mesh.size = Vector3(0.19, 0.12, 0.32)
	_create_follow_mesh("FootL", "foot_l", foot_mesh, leather_material, Transform3D(Basis.IDENTITY, Vector3(0.0, -0.035, -0.09)))
	_create_follow_mesh("FootR", "foot_r", foot_mesh, leather_material, Transform3D(Basis.IDENTITY, Vector3(0.0, -0.035, -0.09)))

	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.025
	eye_mesh.height = 0.05
	eye_mesh.radial_segments = 8
	eye_mesh.rings = 4
	_create_follow_mesh("EyeL", "head", eye_mesh, eye_material, Transform3D(Basis.IDENTITY.scaled(Vector3(0.82, 1.08, 0.55)), Vector3(-0.072, 0.07, -0.215)))
	_create_follow_mesh("EyeR", "head", eye_mesh, eye_material, Transform3D(Basis.IDENTITY.scaled(Vector3(0.82, 1.08, 0.55)), Vector3(0.072, 0.07, -0.215)))

	var collar_mesh := CylinderMesh.new()
	collar_mesh.top_radius = 0.205
	collar_mesh.bottom_radius = 0.225
	collar_mesh.height = 0.07
	collar_mesh.radial_segments = 12
	_create_follow_mesh("Collar", "chest", collar_mesh, gold_material, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.055, -0.005)))


func _create_segment(
	part_name: String,
	bone_a: String,
	bone_b: String,
	radius: float,
	material: StandardMaterial3D
) -> void:
	var node := MeshInstance3D.new()
	node.name = part_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 0.92
	mesh.height = 1.0
	mesh.radial_segments = 10
	node.mesh = mesh
	node.material_override = material
	add_child(node)
	segment_parts.append({
		"node": node,
		"a": bone_a,
		"b": bone_b,
	})


func _create_follow_mesh(
	part_name: String,
	bone_name: String,
	mesh: Mesh,
	material: StandardMaterial3D,
	local_transform: Transform3D
) -> void:
	var node := MeshInstance3D.new()
	node.name = part_name
	node.mesh = mesh
	node.material_override = material
	add_child(node)
	follow_parts.append({
		"node": node,
		"bone": bone_name,
		"local": local_transform,
	})


func _update_proxy_geometry() -> void:
	if skeleton == null:
		return
	for spec: Dictionary in segment_parts:
		var node: MeshInstance3D = spec.get("node") as MeshInstance3D
		var bone_a: String = str(spec.get("a", ""))
		var bone_b: String = str(spec.get("b", ""))
		if node == null or not bones.has(bone_a) or not bones.has(bone_b):
			continue
		var a: Vector3 = skeleton.get_bone_global_pose(int(bones[bone_a])).origin
		var b: Vector3 = skeleton.get_bone_global_pose(int(bones[bone_b])).origin
		var offset: Vector3 = b - a
		var length: float = offset.length()
		if length <= 0.0001:
			node.visible = false
			continue
		node.visible = true
		node.position = a.lerp(b, 0.5)
		node.quaternion = Quaternion(Vector3.UP, offset / length)
		node.scale = Vector3(1.0, length, 1.0)
	for spec: Dictionary in follow_parts:
		var node: MeshInstance3D = spec.get("node") as MeshInstance3D
		var bone_name: String = str(spec.get("bone", ""))
		if node == null or not bones.has(bone_name):
			continue
		var bone_pose: Transform3D = skeleton.get_bone_global_pose(int(bones[bone_name]))
		var local_transform: Transform3D = spec.get("local", Transform3D.IDENTITY) as Transform3D
		node.transform = bone_pose * local_transform


func _update_weapon_socket() -> void:
	last_socket_error = 0.0
	if not drive_weapon_socket or weapon_controller == null or skeleton == null:
		return
	if not bones.has("hand_r"):
		return
	var hand_anchor: Node3D = weapon_controller.get_node_or_null("HandAnchor") as Node3D
	if hand_anchor == null:
		return
	var hand_pose: Transform3D = skeleton.get_bone_global_pose(int(bones["hand_r"]))
	var socket_basis: Basis = Basis.from_euler(_degrees_to_radians(weapon_socket_rotation_degrees))
	var socket_local := Transform3D(socket_basis, weapon_socket_offset)
	var target_global: Transform3D = global_transform * hand_pose * socket_local
	hand_anchor.global_transform = target_global
	last_socket_error = hand_anchor.global_position.distance_to(target_global.origin)


func _attack_side(attack: WeaponAttackDefinition) -> float:
	if attack == null:
		return 1.0
	var delta_y: float = attack.strike_rotation_degrees.y - attack.windup_rotation_degrees.y
	if absf(delta_y) > 1.0:
		return 1.0 if delta_y > 0.0 else -1.0
	return -1.0 if attack.character_pose_id.to_lower().contains("left") else 1.0


func _blend_pose(a: Dictionary, b: Dictionary, weight: float) -> Dictionary:
	var result: Dictionary = {}
	var t: float = clampf(weight, 0.0, 1.0)
	for bone_name_variant: Variant in bones.keys():
		var bone_name: String = str(bone_name_variant)
		var av: Vector3 = a.get(bone_name, Vector3.ZERO) as Vector3
		var bv: Vector3 = b.get(bone_name, Vector3.ZERO) as Vector3
		result[bone_name] = av.lerp(bv, t)
	var a_offset: Vector3 = a.get("__pelvis_offset", Vector3.ZERO) as Vector3
	var b_offset: Vector3 = b.get("__pelvis_offset", Vector3.ZERO) as Vector3
	result["__pelvis_offset"] = a_offset.lerp(b_offset, t)
	return result


func _set_deg(targets: Dictionary, bone_name: String, degrees_value: Vector3) -> void:
	targets[bone_name] = _degrees_to_radians(degrees_value)


func _add_deg(targets: Dictionary, bone_name: String, degrees_value: Vector3) -> void:
	var current: Vector3 = targets.get(bone_name, Vector3.ZERO) as Vector3
	targets[bone_name] = current + _degrees_to_radians(degrees_value)


func _set_pose_deg(pose: Dictionary, bone_name: String, degrees_value: Vector3) -> void:
	pose[bone_name] = _degrees_to_radians(degrees_value)


func _degrees_to_radians(value: Vector3) -> Vector3:
	return Vector3(
		deg_to_rad(value.x),
		deg_to_rad(value.y),
		deg_to_rad(value.z)
	)


func get_weapon_socket_transform() -> Transform3D:
	if skeleton == null or not bones.has("hand_r"):
		return global_transform
	var hand_pose: Transform3D = skeleton.get_bone_global_pose(int(bones["hand_r"]))
	var socket_basis: Basis = Basis.from_euler(_degrees_to_radians(weapon_socket_rotation_degrees))
	return global_transform * hand_pose * Transform3D(socket_basis, weapon_socket_offset)


func get_debug_data() -> Dictionary:
	return {
		"skeletal_proxy": true,
		"skeleton_type": "Skeleton3D",
		"bone_count": skeleton.get_bone_count() if skeleton != null else 0,
		"animation_state": animation_state,
		"animation_weight": snappedf(animation_weight, 0.01),
		"attack": last_attack_id,
		"presentation_scale": presentation_scale,
		"weapon_socket_driven": drive_weapon_socket,
		"weapon_socket_error": snappedf(last_socket_error, 0.001),
		"has_pelvis": bones.has("pelvis"),
		"has_spine_chain": bones.has("spine_01") and bones.has("spine_02") and bones.has("chest"),
		"has_elbows": bones.has("forearm_l") and bones.has("forearm_r"),
		"has_knees": bones.has("shin_l") and bones.has("shin_r"),
		"has_weapon_hand": bones.has("hand_r"),
	}
