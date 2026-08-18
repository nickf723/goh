extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_animation_v4.gd"
class_name GraceHumanoidSkeletalProxyAnimationV5

# V5 turns the generic flinch into a short physical sequence. Defense gameplay
# already owns the recoil velocity and timers, so presentation samples those
# authoritative values rather than introducing another reaction state machine.

@export_group("Hit Reaction Animation")
@export_range(0.0, 30.0, 0.5) var hit_torso_recoil_degrees: float = 16.0
@export_range(0.0, 36.0, 0.5) var hit_twist_degrees: float = 18.0
@export_range(0.0, 0.18, 0.005) var hit_center_drop: float = 0.075
@export_range(0.0, 45.0, 0.5) var guard_break_fold_degrees: float = 28.0

var last_reaction_outcome: String = "none"
var last_reaction_progress: float = 0.0
var last_reaction_side: float = 0.0
var last_reaction_forward: float = 0.0


func _pose_hit(targets: Dictionary) -> Vector3:
	if defense_controller == null:
		return super._pose_hit(targets)
	var remaining: float = maxf(defense_controller.hit_reaction_remaining, 0.0)
	if remaining <= 0.001:
		return super._pose_hit(targets)

	var outcome: String = defense_controller.last_outcome
	var guard_broken: bool = outcome in ["guard_broken", "guard_break"]
	var duration: float = defense_controller.hit_reaction_seconds
	if guard_broken:
		duration = defense_controller.guard_break_seconds
	elif outcome in ["perfect_guard", "blocked", "block"]:
		duration = defense_controller.guard_recoil_seconds
	duration = maxf(duration, remaining, 0.01)
	var progress: float = clampf(1.0 - remaining / duration, 0.0, 1.0)
	var world_recoil: Vector3 = defense_controller.hit_reaction_velocity
	var local_recoil: Vector3 = (
		actor.global_transform.basis.orthonormalized().inverse() * world_recoil
		if actor != null
		else Vector3.ZERO
	)
	var planar_length: float = Vector2(local_recoil.x, local_recoil.z).length()
	var side: float = clampf(local_recoil.x / maxf(planar_length, 0.001), -1.0, 1.0) if planar_length > 0.001 else 0.0
	var forward: float = clampf(-local_recoil.z / maxf(planar_length, 0.001), -1.0, 1.0) if planar_length > 0.001 else -1.0
	last_reaction_outcome = outcome
	last_reaction_progress = progress
	last_reaction_side = side
	last_reaction_forward = forward

	if guard_broken:
		return _pose_guard_break(targets, progress, side, forward)
	if outcome in ["perfect_guard", "blocked", "block"]:
		return _pose_guard_recoil(targets, progress, side, forward, outcome == "perfect_guard")
	return _pose_direct_hit(targets, progress, side, forward)


func _pose_direct_hit(
	targets: Dictionary,
	progress: float,
	side: float,
	forward: float
) -> Vector3:
	var snap: float = 1.0 - smoothstep(0.0, 0.18, progress)
	var recoil_in: float = smoothstep(0.0, 0.16, progress)
	var recoil_out: float = 1.0 - smoothstep(0.42, 1.0, progress)
	var recoil: float = recoil_in * recoil_out
	var weight: float = clampf(snap * 0.72 + recoil, 0.0, 1.0)
	var side_sign: float = 1.0 if side >= 0.0 else -1.0
	var twist: float = side * hit_twist_degrees * weight
	var back_recoil: float = -forward * hit_torso_recoil_degrees * weight

	_set_deg(targets, "pelvis", Vector3(back_recoil * 0.35 + 5.0 * weight, twist * 0.28, -side * 7.0 * weight))
	_set_deg(targets, "spine_01", Vector3(back_recoil * 0.55 + 7.0 * weight, twist * 0.46, side * 5.0 * weight))
	_set_deg(targets, "spine_02", Vector3(back_recoil * 0.76 + 8.0 * weight, twist * 0.72, side * 7.0 * weight))
	_set_deg(targets, "chest", Vector3(back_recoil + 8.0 * snap, twist, side * 9.0 * weight))
	_set_deg(targets, "neck", Vector3(-back_recoil * 0.34 - 5.0 * snap, -twist * 0.3, -side * 3.0 * weight))
	_set_deg(targets, "head", Vector3(-back_recoil * 0.48 - 8.0 * snap, -twist * 0.42, -side * 4.0 * weight))

	var near_left: bool = side_sign < 0.0
	_set_deg(targets, "upper_arm_l", Vector3(22.0 * weight, -side * 6.0, (-32.0 if near_left else -18.0) * weight))
	_set_deg(targets, "upper_arm_r", Vector3(26.0 * weight, -side * 6.0, (18.0 if near_left else 34.0) * weight))
	_set_deg(targets, "forearm_l", Vector3((-18.0 if near_left else -31.0) * weight, 0.0, 0.0))
	_set_deg(targets, "forearm_r", Vector3((-32.0 if near_left else -20.0) * weight, 0.0, 0.0))

	var catch_left: bool = side <= 0.0
	_set_deg(targets, "thigh_l", Vector3((-18.0 if catch_left else -7.0) * weight, 0.0, -side * 3.0))
	_set_deg(targets, "thigh_r", Vector3((-18.0 if not catch_left else -7.0) * weight, 0.0, -side * 3.0))
	_set_deg(targets, "shin_l", Vector3((31.0 if catch_left else 13.0) * weight, 0.0, 0.0))
	_set_deg(targets, "shin_r", Vector3((31.0 if not catch_left else 13.0) * weight, 0.0, 0.0))
	animation_weight = weight
	return Vector3(-side * 0.025 * weight, -hit_center_drop * weight, forward * 0.032 * weight)


func _pose_guard_recoil(
	targets: Dictionary,
	progress: float,
	side: float,
	forward: float,
	perfect: bool
) -> Vector3:
	var impulse: float = sin(clampf(progress, 0.0, 1.0) * PI)
	var strength: float = impulse * (0.7 if perfect else 1.0)
	var twist: float = side * hit_twist_degrees * 0.42 * strength
	var brace: float = maxf(-forward, 0.25)
	_set_deg(targets, "pelvis", Vector3(8.0 * strength, twist * 0.25, -side * 3.5 * strength))
	_set_deg(targets, "spine_01", Vector3(7.0 * strength, twist * 0.35, side * 2.5 * strength))
	_set_deg(targets, "spine_02", Vector3(5.0 * strength, twist * 0.55, side * 3.5 * strength))
	_set_deg(targets, "chest", Vector3((-6.0 if perfect else -2.0) * strength, twist, side * 4.0 * strength))
	_set_deg(targets, "head", Vector3(3.0 * strength, -twist * 0.35, -side * 2.0 * strength))
	_set_deg(targets, "upper_arm_l", Vector3(48.0 * brace * strength, -side * 8.0, -18.0 * strength))
	_set_deg(targets, "upper_arm_r", Vector3(53.0 * brace * strength, -side * 8.0, 18.0 * strength))
	_set_deg(targets, "forearm_l", Vector3(-48.0 * strength, 0.0, 0.0))
	_set_deg(targets, "forearm_r", Vector3(-51.0 * strength, 0.0, 0.0))
	_set_deg(targets, "thigh_l", Vector3(-16.0 * strength, 0.0, -2.0))
	_set_deg(targets, "thigh_r", Vector3(-15.0 * strength, 0.0, 2.0))
	_set_deg(targets, "shin_l", Vector3(29.0 * strength, 0.0, 0.0))
	_set_deg(targets, "shin_r", Vector3(27.0 * strength, 0.0, 0.0))
	animation_weight = strength
	return Vector3(-side * 0.012 * strength, -hit_center_drop * 0.7 * strength, 0.028 * strength)


func _pose_guard_break(
	targets: Dictionary,
	progress: float,
	side: float,
	forward: float
) -> Vector3:
	var collapse_in: float = smoothstep(0.0, 0.24, progress)
	var collapse_out: float = 1.0 - smoothstep(0.58, 1.0, progress)
	var collapse: float = collapse_in * collapse_out
	var initial_snap: float = 1.0 - smoothstep(0.0, 0.12, progress)
	var weight: float = clampf(collapse + initial_snap * 0.55, 0.0, 1.0)
	var side_sign: float = 1.0 if side >= 0.0 else -1.0
	_set_deg(targets, "pelvis", Vector3(guard_break_fold_degrees * 0.45 * weight, side * 6.0 * weight, -side * 10.0 * weight))
	_set_deg(targets, "spine_01", Vector3(guard_break_fold_degrees * 0.62 * weight, -side * 4.0 * weight, side * 8.0 * weight))
	_set_deg(targets, "spine_02", Vector3(guard_break_fold_degrees * 0.78 * weight, -side * 6.0 * weight, side * 9.0 * weight))
	_set_deg(targets, "chest", Vector3(guard_break_fold_degrees * weight, -side * 9.0 * weight, side * 11.0 * weight))
	_set_deg(targets, "neck", Vector3(-11.0 * weight, side * 4.0 * weight, -side * 4.0 * weight))
	_set_deg(targets, "head", Vector3(-14.0 * weight, side * 6.0 * weight, -side * 5.0 * weight))
	_set_deg(targets, "upper_arm_l", Vector3((34.0 - side_sign * 8.0) * weight, -8.0 * side, -39.0 * weight))
	_set_deg(targets, "upper_arm_r", Vector3((34.0 + side_sign * 8.0) * weight, -8.0 * side, 39.0 * weight))
	_set_deg(targets, "forearm_l", Vector3(-13.0 * weight, 0.0, 0.0))
	_set_deg(targets, "forearm_r", Vector3(-15.0 * weight, 0.0, 0.0))
	_set_deg(targets, "thigh_l", Vector3(-28.0 * weight, 0.0, -side * 5.0))
	_set_deg(targets, "thigh_r", Vector3(-25.0 * weight, 0.0, -side * 5.0))
	_set_deg(targets, "shin_l", Vector3(47.0 * weight, 0.0, 0.0))
	_set_deg(targets, "shin_r", Vector3(43.0 * weight, 0.0, 0.0))
	animation_weight = weight
	return Vector3(-side * 0.035 * weight, -hit_center_drop * 1.45 * weight, forward * 0.04 * weight)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["animation_v5"] = true
	data["phase_authored_hit_reaction"] = true
	data["last_reaction_outcome"] = last_reaction_outcome
	data["last_reaction_progress"] = snappedf(last_reaction_progress, 0.01)
	data["last_reaction_side"] = snappedf(last_reaction_side, 0.01)
	data["last_reaction_forward"] = snappedf(last_reaction_forward, 0.01)
	return data
