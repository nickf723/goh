extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_locomotion_v3.gd"
class_name GraceHumanoidSkeletalProxyAnimationV4

# Animation V4 gives dodge movement the same physical continuity as locomotion.
# Gameplay velocity remains authoritative; this layer only describes how Grace
# compresses into the launch, carries her mass through travel, catches the landing,
# and recovers onto the appropriate foot.

@export_group("Dodge Animation V2")
@export_range(0.0, 16.0, 0.5) var dodge_launch_compression_degrees: float = 9.0
@export_range(0.0, 20.0, 0.5) var dodge_travel_lean_degrees: float = 13.0
@export_range(0.0, 24.0, 0.5) var dodge_side_bank_degrees: float = 15.0
@export_range(0.0, 0.18, 0.005) var dodge_center_drop: float = 0.105
@export_range(0.0, 0.12, 0.005) var dodge_travel_shift: float = 0.065

var last_dodge_phase: String = "idle"
var last_dodge_kind: String = "none"
var dodge_receiving_sign: float = 1.0


func _pose_dodge(targets: Dictionary) -> Vector3:
	if dodge_controller == null or actor == null:
		return super._pose_dodge(targets)

	var progress: float = clampf(dodge_controller.get_normalized_progress(), 0.0, 1.0)
	var phase: String = dodge_controller.get_dodge_phase()
	var pose_weight: float = clampf(dodge_controller.get_visual_pose_weight(), 0.0, 1.0)
	var direction: Vector3 = dodge_controller.dodge_direction
	if direction.length_squared() <= 0.0001:
		direction = -actor.global_transform.basis.z
	var local_direction: Vector3 = (
		actor.global_transform.basis.orthonormalized().inverse()
		* direction.normalized()
	)
	var side: float = clampf(local_direction.x, -1.0, 1.0)
	var forward: float = clampf(-local_direction.z, -1.0, 1.0)
	var kind: String = dodge_controller.dodge_kind
	last_dodge_phase = phase
	last_dodge_kind = kind

	if phase == "launch":
		dodge_receiving_sign = _resolve_dodge_receiving_sign(side, forward)

	var pelvis_offset := Vector3.ZERO
	match phase:
		"launch":
			var p: float = smoothstep(0.0, 1.0, inverse_lerp(0.0, maxf(dodge_controller.get_launch_end(), 0.01), progress))
			_build_dodge_launch_pose(targets, side, forward, kind, p)
			pelvis_offset = Vector3(
				-side * 0.025 * p,
				-dodge_center_drop * p,
				-forward * 0.025 * p
			)
		"travel":
			var travel_start: float = dodge_controller.get_launch_end()
			var travel_end: float = dodge_controller.get_travel_end()
			var p: float = smoothstep(0.0, 1.0, inverse_lerp(travel_start, maxf(travel_end, travel_start + 0.01), progress))
			_build_dodge_travel_pose(targets, side, forward, kind, p)
			pelvis_offset = Vector3(
				-side * dodge_travel_shift * 0.42,
				-dodge_center_drop * lerpf(1.0, 0.76, p),
				-forward * dodge_travel_shift
			)
		"landing":
			var landing_start: float = dodge_controller.get_travel_end()
			var landing_end: float = dodge_controller.get_landing_end()
			var p: float = smoothstep(0.0, 1.0, inverse_lerp(landing_start, maxf(landing_end, landing_start + 0.01), progress))
			_build_dodge_landing_pose(targets, side, forward, kind, p)
			var catch_wave: float = sin(p * PI)
			pelvis_offset = Vector3(
				-side * 0.02 * (1.0 - p),
				-dodge_center_drop * lerpf(0.82, 0.46, p) - catch_wave * 0.028,
				-forward * 0.035 * (1.0 - p)
			)
		"recovery":
			var recovery_start: float = dodge_controller.get_landing_end()
			var p: float = smoothstep(0.0, 1.0, inverse_lerp(recovery_start, 1.0, progress))
			_build_dodge_recovery_pose(targets, side, forward, p)
			pelvis_offset = Vector3(
				0.0,
				-dodge_center_drop * 0.38 * (1.0 - p),
				-forward * 0.018 * (1.0 - p)
			)
		_:
			return super._pose_dodge(targets)

	animation_weight = pose_weight
	return pelvis_offset


func _build_dodge_launch_pose(
	targets: Dictionary,
	side: float,
	forward: float,
	kind: String,
	p: float
) -> void:
	var compression: float = dodge_launch_compression_degrees * p
	var side_sign: float = _sign_or(side, dodge_receiving_sign)
	var backward: float = maxf(-forward, 0.0)
	var forward_drive: float = maxf(forward, 0.0)

	_set_deg(targets, "pelvis", Vector3(
		compression * (0.72 + backward * 0.25),
		-side * 5.0 * p,
		-side * dodge_side_bank_degrees * 0.35 * p
	))
	_set_deg(targets, "spine_01", Vector3(
		compression * (0.82 - forward_drive * 0.25),
		side * 3.0 * p,
		side * dodge_side_bank_degrees * 0.32 * p
	))
	_set_deg(targets, "spine_02", Vector3(
		compression * (0.72 - forward_drive * 0.35),
		side * 4.0 * p,
		side * dodge_side_bank_degrees * 0.42 * p
	))
	_set_deg(targets, "chest", Vector3(
		compression * (0.58 - forward_drive * 0.55) - backward * 7.0 * p,
		side * 5.0 * p,
		side * dodge_side_bank_degrees * 0.52 * p
	))
	_set_deg(targets, "head", Vector3(
		-forward_drive * 2.5 * p + backward * 4.0 * p,
		-side * 3.0 * p,
		-side * dodge_side_bank_degrees * 0.15 * p
	))

	_set_deg(targets, "upper_arm_l", Vector3(-18.0 * p, -side * 5.0 * p, -15.0 * p))
	_set_deg(targets, "upper_arm_r", Vector3(-22.0 * p, -side * 5.0 * p, 15.0 * p))
	_set_deg(targets, "forearm_l", Vector3(-20.0 * p, 0.0, 0.0))
	_set_deg(targets, "forearm_r", Vector3(-24.0 * p, 0.0, 0.0))

	var left_plant: float = 1.0 if side_sign > 0.0 else 0.0
	var right_plant: float = 1.0 - left_plant
	_set_deg(targets, "thigh_l", Vector3(
		-28.0 * left_plant * p + 12.0 * right_plant * p - forward * 6.0 * p,
		0.0,
		-side * 5.0 * p
	))
	_set_deg(targets, "thigh_r", Vector3(
		-28.0 * right_plant * p + 12.0 * left_plant * p - forward * 6.0 * p,
		0.0,
		-side * 5.0 * p
	))
	_set_deg(targets, "shin_l", Vector3(42.0 * left_plant * p + 16.0 * right_plant * p, 0.0, 0.0))
	_set_deg(targets, "shin_r", Vector3(42.0 * right_plant * p + 16.0 * left_plant * p, 0.0, 0.0))
	_set_deg(targets, "foot_l", Vector3(-6.0 * left_plant * p, side * 4.0 * p, 0.0))
	_set_deg(targets, "foot_r", Vector3(-6.0 * right_plant * p, side * 4.0 * p, 0.0))

	if kind == "backstep" or kind == "backward":
		_add_deg(targets, "chest", Vector3(-7.0 * p, 0.0, 0.0))
		_add_deg(targets, "upper_arm_l", Vector3(8.0 * p, 0.0, -5.0 * p))
		_add_deg(targets, "upper_arm_r", Vector3(8.0 * p, 0.0, 5.0 * p))


func _build_dodge_travel_pose(
	targets: Dictionary,
	side: float,
	forward: float,
	kind: String,
	p: float
) -> void:
	var side_abs: float = absf(side)
	var forward_abs: float = absf(forward)
	var bank: float = side * dodge_side_bank_degrees
	var travel_lean: float = dodge_travel_lean_degrees

	_set_deg(targets, "pelvis", Vector3(
		-4.0 * forward + 4.0 * maxf(-forward, 0.0),
		-side * 5.0,
		-bank * 0.62
	))
	_set_deg(targets, "spine_01", Vector3(-travel_lean * forward * 0.42, side * 3.0, bank * 0.35))
	_set_deg(targets, "spine_02", Vector3(-travel_lean * forward * 0.68, side * 4.0, bank * 0.48))
	_set_deg(targets, "chest", Vector3(-travel_lean * forward, side * 5.5, bank * 0.62))
	_set_deg(targets, "neck", Vector3(travel_lean * forward * 0.18, -side * 2.5, -bank * 0.14))
	_set_deg(targets, "head", Vector3(travel_lean * forward * 0.12, -side * 3.5, -bank * 0.2))

	# Arms tuck near the torso during peak travel, avoiding the spread-eagle look
	# that makes fast dodges read weightless.
	_set_deg(targets, "upper_arm_l", Vector3(-30.0 + forward_abs * 6.0, -side * 8.0, -18.0 + side_abs * 4.0))
	_set_deg(targets, "upper_arm_r", Vector3(-34.0 + forward_abs * 6.0, -side * 8.0, 18.0 - side_abs * 4.0))
	_set_deg(targets, "forearm_l", Vector3(-34.0, side * 4.0, 0.0))
	_set_deg(targets, "forearm_r", Vector3(-38.0, side * 4.0, 0.0))

	if side_abs > 0.35:
		var outside_left: bool = side < 0.0
		_set_deg(targets, "thigh_l", Vector3(-8.0 if outside_left else -30.0, side * 4.0, -side * 7.0))
		_set_deg(targets, "thigh_r", Vector3(-30.0 if outside_left else -8.0, side * 4.0, -side * 7.0))
		_set_deg(targets, "shin_l", Vector3(18.0 if outside_left else 44.0, 0.0, 0.0))
		_set_deg(targets, "shin_r", Vector3(44.0 if outside_left else 18.0, 0.0, 0.0))
	else:
		var lead_left: bool = dodge_receiving_sign < 0.0
		_set_deg(targets, "thigh_l", Vector3(18.0 if lead_left else -22.0, 0.0, -3.0))
		_set_deg(targets, "thigh_r", Vector3(-22.0 if lead_left else 18.0, 0.0, 3.0))
		_set_deg(targets, "shin_l", Vector3(26.0 if lead_left else 38.0, 0.0, 0.0))
		_set_deg(targets, "shin_r", Vector3(38.0 if lead_left else 26.0, 0.0, 0.0))

	if kind == "backstep" or kind == "backward":
		_add_deg(targets, "pelvis", Vector3(7.0, 0.0, 0.0))
		_add_deg(targets, "spine_01", Vector3(-6.0, 0.0, 0.0))
		_add_deg(targets, "spine_02", Vector3(-8.0, 0.0, 0.0))
		_add_deg(targets, "chest", Vector3(-11.0, 0.0, 0.0))


func _build_dodge_landing_pose(
	targets: Dictionary,
	side: float,
	forward: float,
	_kind: String,
	p: float
) -> void:
	var receive_left: bool = dodge_receiving_sign > 0.0
	var receive_weight: float = 1.0 - smoothstep(0.45, 1.0, p)
	var rise: float = smoothstep(0.25, 1.0, p)

	_set_deg(targets, "pelvis", Vector3(9.0 * receive_weight - 2.0 * rise, -side * 2.0 * receive_weight, -side * 4.0 * receive_weight))
	_set_deg(targets, "spine_01", Vector3(10.0 * receive_weight - 2.0 * rise, side * 1.5 * receive_weight, side * 2.0 * receive_weight))
	_set_deg(targets, "spine_02", Vector3(9.0 * receive_weight - 3.0 * rise, side * 2.0 * receive_weight, side * 3.0 * receive_weight))
	_set_deg(targets, "chest", Vector3(8.0 * receive_weight - 4.0 * rise, side * 2.5 * receive_weight, side * 3.5 * receive_weight))
	_set_deg(targets, "head", Vector3(-3.0 * receive_weight, -side * 1.5 * receive_weight, 0.0))

	_set_deg(targets, "thigh_l", Vector3(-25.0 * receive_weight if receive_left else -7.0 * receive_weight, 0.0, -side * 3.0))
	_set_deg(targets, "thigh_r", Vector3(-25.0 * receive_weight if not receive_left else -7.0 * receive_weight, 0.0, -side * 3.0))
	_set_deg(targets, "shin_l", Vector3(42.0 * receive_weight if receive_left else 14.0 * receive_weight, 0.0, 0.0))
	_set_deg(targets, "shin_r", Vector3(42.0 * receive_weight if not receive_left else 14.0 * receive_weight, 0.0, 0.0))
	_set_deg(targets, "foot_l", Vector3(-7.0 * receive_weight if receive_left else 4.0 * receive_weight, side * 4.0, 0.0))
	_set_deg(targets, "foot_r", Vector3(-7.0 * receive_weight if not receive_left else 4.0 * receive_weight, side * 4.0, 0.0))
	_set_deg(targets, "toe_l", Vector3(5.0 * receive_weight if receive_left else 0.0, 0.0, 0.0))
	_set_deg(targets, "toe_r", Vector3(5.0 * receive_weight if not receive_left else 0.0, 0.0, 0.0))

	_set_deg(targets, "upper_arm_l", Vector3(-18.0 * receive_weight, -side * 2.0, -10.0 * receive_weight))
	_set_deg(targets, "upper_arm_r", Vector3(-20.0 * receive_weight, -side * 2.0, 10.0 * receive_weight))
	_set_deg(targets, "forearm_l", Vector3(-19.0 * receive_weight, 0.0, 0.0))
	_set_deg(targets, "forearm_r", Vector3(-22.0 * receive_weight, 0.0, 0.0))

	# Forward travel keeps one knee under the center of mass while a backstep puts
	# the receiving foot slightly behind Grace before she rises.
	if forward < -0.35:
		_add_deg(targets, "pelvis", Vector3(-3.0 * receive_weight, 0.0, 0.0))


func _build_dodge_recovery_pose(
	targets: Dictionary,
	side: float,
	forward: float,
	p: float
) -> void:
	var remaining: float = 1.0 - p
	var receive_left: bool = dodge_receiving_sign > 0.0
	_set_deg(targets, "pelvis", Vector3(3.0 * remaining, -side * 1.5 * remaining, -side * 2.0 * remaining))
	_set_deg(targets, "spine_01", Vector3(3.5 * remaining, side * 1.0 * remaining, side * 1.5 * remaining))
	_set_deg(targets, "chest", Vector3(2.5 * remaining, side * 1.5 * remaining, side * 2.0 * remaining))
	_set_deg(targets, "thigh_l", Vector3(-8.0 * remaining if receive_left else 2.0 * remaining, 0.0, 0.0))
	_set_deg(targets, "thigh_r", Vector3(-8.0 * remaining if not receive_left else 2.0 * remaining, 0.0, 0.0))
	_set_deg(targets, "shin_l", Vector3(13.0 * remaining if receive_left else 5.0 * remaining, 0.0, 0.0))
	_set_deg(targets, "shin_r", Vector3(13.0 * remaining if not receive_left else 5.0 * remaining, 0.0, 0.0))
	_set_deg(targets, "upper_arm_l", Vector3(-8.0 * remaining, 0.0, -5.0 * remaining))
	_set_deg(targets, "upper_arm_r", Vector3(-9.0 * remaining, 0.0, 5.0 * remaining))
	if absf(forward) > 0.35:
		_add_deg(targets, "chest", Vector3(-forward * 2.0 * remaining, 0.0, 0.0))


func _resolve_dodge_receiving_sign(side: float, forward: float) -> float:
	if absf(side) > 0.35:
		# Dodging right catches on the left leg and vice versa.
		return -1.0 if side > 0.0 else 1.0
	# Alternate forward/back catches to keep chained evasions from always stamping
	# the same foot. Chain count is stable for the duration of the dodge.
	var chain_index: int = dodge_controller.chain_count if dodge_controller != null else 0
	var parity: float = 1.0 if chain_index % 2 == 0 else -1.0
	return parity if forward >= 0.0 else -parity


func _sign_or(value: float, fallback: float) -> float:
	if absf(value) >= 0.01:
		return 1.0 if value > 0.0 else -1.0
	return 1.0 if fallback >= 0.0 else -1.0


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["animation_v4"] = true
	data["phase_authored_dodge"] = true
	data["last_dodge_phase"] = last_dodge_phase
	data["last_dodge_kind"] = last_dodge_kind
	data["dodge_receiving_foot"] = "left" if dodge_receiving_sign > 0.0 else "right"
	return data
