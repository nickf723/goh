extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_animation_v15.gd"
class_name GraceHumanoidSkeletalProxyAnimationV16

# V16 promotes traversal controllers to first-class presentation states. Gameplay
# already owns wall attachment, mantle travel, buoyancy, and currents; the rig now
# stops interpreting those motions as generic falling.

var climbing_controller: PlayerClimbingController
var swimming_controller: PlayerSwimmingController
var climb_phase: float = 0.0
var swim_phase: float = 0.0
var last_traversal_state: String = "none"


func _ready() -> void:
	super._ready()
	if actor != null:
		climbing_controller = actor.get_node_or_null(
			"ClimbingController"
		) as PlayerClimbingController
		swimming_controller = actor.get_node_or_null(
			"SwimmingController"
		) as PlayerSwimmingController


func _resolve_state() -> String:
	var base_state: String = super._resolve_state()
	if base_state in ["hit", "dodge", "attack"]:
		return base_state
	if climbing_controller != null and climbing_controller.should_handle_locomotion():
		return "mantle" if climbing_controller.mantling else "climb"
	if swimming_controller != null and swimming_controller.should_handle_locomotion():
		return "swim_underwater" if swimming_controller.underwater else "swim_surface"
	return base_state


func _sample_pose(delta: float) -> void:
	if skeleton == null:
		return
	elapsed += delta
	var target_rotations: Dictionary = {}
	var pelvis_offset: Vector3 = Vector3.ZERO
	var resolved_state: String = _resolve_state()
	animation_state = resolved_state
	last_traversal_state = (
		resolved_state
		if resolved_state in ["climb", "mantle", "swim_surface", "swim_underwater"]
		else "none"
	)

	match resolved_state:
		"hit":
			pelvis_offset = _pose_hit(target_rotations)
		"dodge":
			pelvis_offset = _pose_dodge(target_rotations)
		"attack":
			pelvis_offset = _pose_attack(target_rotations)
		"climb":
			pelvis_offset = _pose_climb(target_rotations, delta)
		"mantle":
			pelvis_offset = _pose_mantle(target_rotations)
		"swim_surface":
			pelvis_offset = _pose_swim_surface(target_rotations, delta)
		"swim_underwater":
			pelvis_offset = _pose_swim_underwater(target_rotations, delta)
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


func _pose_climb(targets: Dictionary, delta: float) -> Vector3:
	if actor == null or climbing_controller == null:
		return Vector3.ZERO
	var local_velocity: Vector3 = (
		actor.global_transform.basis.orthonormalized().inverse() * actor.velocity
	)
	var effort: float = clampf(
		Vector2(local_velocity.x, actor.velocity.y).length() / maxf(climbing_controller.climb_speed, 0.1),
		0.0,
		1.0
	)
	climb_phase = fposmod(
		climb_phase + delta * lerpf(2.2, 5.4, effort),
		TAU
	)
	var reach: float = sin(climb_phase)
	var lift: float = cos(climb_phase)
	var left_reach: float = reach
	var right_reach: float = -reach

	_set_deg(targets, "pelvis", Vector3(7.0, -local_velocity.x * 2.0, -local_velocity.x * 3.0))
	_set_deg(targets, "spine_01", Vector3(-4.0, local_velocity.x * 1.0, local_velocity.x * 1.5))
	_set_deg(targets, "spine_02", Vector3(-7.0, local_velocity.x * 1.5, local_velocity.x * 2.0))
	_set_deg(targets, "chest", Vector3(-10.0, local_velocity.x * 2.0, local_velocity.x * 2.5))
	_set_deg(targets, "head", Vector3(7.0, -local_velocity.x * 1.5, 0.0))

	# Opposite hand/foot pairs create readable three-point support.
	_set_deg(targets, "upper_arm_l", Vector3(118.0 + left_reach * 16.0 * effort, 8.0, -16.0))
	_set_deg(targets, "upper_arm_r", Vector3(118.0 + right_reach * 16.0 * effort, -8.0, 16.0))
	_set_deg(targets, "forearm_l", Vector3(-48.0 + left_reach * 13.0 * effort, -3.0, 2.0))
	_set_deg(targets, "forearm_r", Vector3(-48.0 + right_reach * 13.0 * effort, 3.0, -2.0))
	_set_deg(targets, "hand_l", Vector3(-7.0, 0.0, -6.0))
	_set_deg(targets, "hand_r", Vector3(-7.0, 0.0, 6.0))

	_set_deg(targets, "thigh_l", Vector3(35.0 - right_reach * 18.0 * effort, 0.0, -8.0))
	_set_deg(targets, "thigh_r", Vector3(35.0 - left_reach * 18.0 * effort, 0.0, 8.0))
	_set_deg(targets, "shin_l", Vector3(58.0 + maxf(right_reach, 0.0) * 16.0 * effort, 0.0, 0.0))
	_set_deg(targets, "shin_r", Vector3(58.0 + maxf(left_reach, 0.0) * 16.0 * effort, 0.0, 0.0))
	_set_deg(targets, "foot_l", Vector3(-22.0, 0.0, -4.0))
	_set_deg(targets, "foot_r", Vector3(-22.0, 0.0, 4.0))
	animation_weight = lerpf(0.62, 1.0, effort)
	return Vector3(
		-local_velocity.x * 0.012,
		-lift * 0.012 * effort,
		-0.035
	)


func _pose_mantle(targets: Dictionary) -> Vector3:
	if climbing_controller == null:
		return Vector3.ZERO
	var duration: float = maxf(climbing_controller.mantle_duration, 0.01)
	var progress: float = clampf(
		1.0 - climbing_controller.mantle_remaining / duration,
		0.0,
		1.0
	)
	var pull: float = smoothstep(0.0, 1.0, clampf(progress / 0.58, 0.0, 1.0))
	var stand: float = smoothstep(0.58, 1.0, progress)
	var knee_side: float = 1.0 if int(floor(elapsed * 2.0)) % 2 == 0 else -1.0

	_set_deg(targets, "pelvis", Vector3(lerpf(18.0, -4.0, stand), 0.0, knee_side * 3.0 * (1.0 - stand)))
	_set_deg(targets, "spine_01", Vector3(lerpf(-14.0, -2.0, stand), 0.0, 0.0))
	_set_deg(targets, "spine_02", Vector3(lerpf(-20.0, -3.0, stand), 0.0, 0.0))
	_set_deg(targets, "chest", Vector3(lerpf(-28.0, -4.0, stand), 0.0, 0.0))
	_set_deg(targets, "head", Vector3(lerpf(11.0, 1.0, stand), 0.0, 0.0))

	_set_deg(targets, "upper_arm_l", Vector3(lerpf(132.0, 18.0, stand), 7.0, -16.0))
	_set_deg(targets, "upper_arm_r", Vector3(lerpf(132.0, 18.0, stand), -7.0, 16.0))
	_set_deg(targets, "forearm_l", Vector3(lerpf(-34.0, -12.0, stand), -2.0, 2.0))
	_set_deg(targets, "forearm_r", Vector3(lerpf(-34.0, -12.0, stand), 2.0, -2.0))

	var left_knee: float = 1.0 if knee_side > 0.0 else 0.0
	_set_deg(targets, "thigh_l", Vector3(lerpf(62.0 * left_knee + 24.0 * (1.0 - left_knee), 0.0, stand), 0.0, -4.0))
	_set_deg(targets, "thigh_r", Vector3(lerpf(62.0 * (1.0 - left_knee) + 24.0 * left_knee, 0.0, stand), 0.0, 4.0))
	_set_deg(targets, "shin_l", Vector3(lerpf(72.0 if left_knee > 0.5 else 40.0, 0.0, stand), 0.0, 0.0))
	_set_deg(targets, "shin_r", Vector3(lerpf(72.0 if left_knee < 0.5 else 40.0, 0.0, stand), 0.0, 0.0))
	animation_weight = 1.0
	return Vector3(0.0, -0.045 * (1.0 - stand) + pull * 0.025, -0.055 * pull)


func _pose_swim_surface(targets: Dictionary, delta: float) -> Vector3:
	if swimming_controller == null or actor == null:
		return Vector3.ZERO
	var speed: float = Vector2(actor.velocity.x, actor.velocity.z).length()
	var speed_weight: float = clampf(speed / maxf(swimming_controller.surface_swim_speed, 0.1), 0.0, 1.0)
	swim_phase = fposmod(swim_phase + delta * lerpf(3.2, 6.8, speed_weight), TAU)
	var stroke: float = sin(swim_phase)
	var kick: float = sin(swim_phase * 2.0)
	var sprint: float = 1.0 if swimming_controller.sprinting else 0.0

	_set_deg(targets, "pelvis", Vector3(-8.0 - sprint * 3.0, stroke * 2.0, 0.0))
	_set_deg(targets, "spine_01", Vector3(-9.0 - sprint * 2.0, -stroke * 1.5, 0.0))
	_set_deg(targets, "spine_02", Vector3(-11.0 - sprint * 2.0, -stroke * 2.0, 0.0))
	_set_deg(targets, "chest", Vector3(-13.0 - sprint * 3.0, -stroke * 2.5, 0.0))
	_set_deg(targets, "head", Vector3(12.0 + sprint * 2.0, stroke * 1.5, 0.0))

	_set_deg(targets, "upper_arm_l", Vector3(lerpf(38.0, 112.0, 0.5 + 0.5 * stroke), 0.0, -28.0))
	_set_deg(targets, "upper_arm_r", Vector3(lerpf(38.0, 112.0, 0.5 - 0.5 * stroke), 0.0, 28.0))
	_set_deg(targets, "forearm_l", Vector3(-42.0 - maxf(stroke, 0.0) * 28.0, 0.0, 0.0))
	_set_deg(targets, "forearm_r", Vector3(-42.0 - maxf(-stroke, 0.0) * 28.0, 0.0, 0.0))
	_set_deg(targets, "thigh_l", Vector3(8.0 + kick * 10.0, 0.0, -4.0))
	_set_deg(targets, "thigh_r", Vector3(8.0 - kick * 10.0, 0.0, 4.0))
	_set_deg(targets, "shin_l", Vector3(18.0 - kick * 8.0, 0.0, 0.0))
	_set_deg(targets, "shin_r", Vector3(18.0 + kick * 8.0, 0.0, 0.0))
	_set_deg(targets, "foot_l", Vector3(17.0, 0.0, 0.0))
	_set_deg(targets, "foot_r", Vector3(17.0, 0.0, 0.0))
	animation_weight = lerpf(0.48, 1.0, speed_weight)
	return Vector3(0.0, sin(swim_phase * 2.0) * 0.008, -0.025)


func _pose_swim_underwater(targets: Dictionary, delta: float) -> Vector3:
	if swimming_controller == null or actor == null:
		return Vector3.ZERO
	var speed: float = actor.velocity.length()
	var speed_weight: float = clampf(speed / maxf(swimming_controller.underwater_swim_speed, 0.1), 0.0, 1.0)
	swim_phase = fposmod(swim_phase + delta * lerpf(2.6, 5.6, speed_weight), TAU)
	var cycle: float = 0.5 + 0.5 * sin(swim_phase)
	var open: float = sin(cycle * PI)
	var vertical_direction: float = clampf(actor.velocity.y / maxf(swimming_controller.vertical_swim_speed, 0.1), -1.0, 1.0)

	_set_deg(targets, "pelvis", Vector3(-14.0 + vertical_direction * 6.0, 0.0, 0.0))
	_set_deg(targets, "spine_01", Vector3(-10.0 + vertical_direction * 4.0, 0.0, 0.0))
	_set_deg(targets, "spine_02", Vector3(-9.0 + vertical_direction * 3.0, 0.0, 0.0))
	_set_deg(targets, "chest", Vector3(-8.0 + vertical_direction * 2.0, 0.0, 0.0))
	_set_deg(targets, "head", Vector3(7.0 - vertical_direction * 3.0, 0.0, 0.0))

	_set_deg(targets, "upper_arm_l", Vector3(lerpf(120.0, 42.0, cycle), 0.0, -lerpf(12.0, 54.0, open)))
	_set_deg(targets, "upper_arm_r", Vector3(lerpf(120.0, 42.0, cycle), 0.0, lerpf(12.0, 54.0, open)))
	_set_deg(targets, "forearm_l", Vector3(lerpf(-18.0, -62.0, cycle), 0.0, 0.0))
	_set_deg(targets, "forearm_r", Vector3(lerpf(-18.0, -62.0, cycle), 0.0, 0.0))
	_set_deg(targets, "thigh_l", Vector3(lerpf(-2.0, 28.0, open), 0.0, -lerpf(2.0, 15.0, open)))
	_set_deg(targets, "thigh_r", Vector3(lerpf(-2.0, 28.0, open), 0.0, lerpf(2.0, 15.0, open)))
	_set_deg(targets, "shin_l", Vector3(lerpf(11.0, 45.0, open), 0.0, 0.0))
	_set_deg(targets, "shin_r", Vector3(lerpf(11.0, 45.0, open), 0.0, 0.0))
	_set_deg(targets, "foot_l", Vector3(18.0, 0.0, -4.0 * open))
	_set_deg(targets, "foot_r", Vector3(18.0, 0.0, 4.0 * open))
	animation_weight = lerpf(0.55, 1.0, speed_weight)
	return Vector3(0.0, sin(swim_phase) * 0.012, -0.035)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["animation_v16"] = true
	data["traversal_animation_states"] = true
	data["traversal_state"] = last_traversal_state
	data["climb_phase"] = snappedf(climb_phase, 0.01)
	data["swim_phase"] = snappedf(swim_phase, 0.01)
	return data
