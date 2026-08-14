extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_weapon_languages_v4g.gd"

# V4H follows the visible Chain head, stages the Axe charge as two distinct
# ground plants joined by a levered corkscrew, and gives Staff Heavy charge a
# held mounted pose before its long-distance traversal release.


func _build_attack_stage_pose(
	attack: WeaponAttackDefinition,
	stage: String
) -> Dictionary:
	var weapon_class: String = _get_equipped_weapon_class()
	if weapon_class == "chains" and attack != null:
		if attack.extra_tags.has("chain_charge_orbit"):
			return _build_chain_charge_pose_v2()
		if attack.extra_tags.has("ground_slam") or attack.extra_tags.has("slam"):
			return _build_chain_slam_pose_v2(attack)
		return _build_chain_weight_follow_pose(attack)
	if attack != null and attack.extra_tags.has("axe_charge_ready"):
		return _build_axe_charge_ready_pose()
	if attack != null and attack.extra_tags.has("axe_lever_vault"):
		return _build_axe_lever_twist_pose(attack, stage)
	if attack != null and attack.extra_tags.has("staff_charge_mount"):
		return _build_staff_mount_pose()
	if attack != null and attack.extra_tags.has("staff_charge_vault"):
		return _build_staff_map_vault_pose(attack, stage)
	return super._build_attack_stage_pose(attack, stage)


func _build_chain_weight_follow_pose(
	attack: WeaponAttackDefinition
) -> Dictionary:
	var pose: Dictionary = {}
	var state: Dictionary = _get_chain_head_state()
	var head_yaw: float = float(state.get("yaw", 0.0))
	var head_height: float = float(state.get("height", 0.3))
	var speed_ratio: float = float(state.get("speed", 0.0))
	var heavy: bool = attack.input_kind == "heavy"
	var side: float = _attack_side(attack)
	var progress: float = _get_attack_progress(attack)
	var effort: float = sin(clampf(progress, 0.0, 1.0) * PI)
	var weight: float = (1.18 if heavy else 1.0) * lerpf(0.82, 1.0, effort)
	var counter_yaw: float = clampf(-head_yaw * 0.2, -27.0, 27.0)
	var shoulder_yaw: float = clampf(head_yaw * 0.28, -36.0, 36.0)
	var height_bias: float = clampf((head_height - 0.35) * 18.0, -9.0, 12.0)
	var crouch: float = lerpf(12.0, 21.0, speed_ratio) * weight

	_set_pose_deg(pose, "pelvis", Vector3(crouch * 0.34, counter_yaw, -side * 4.0 * effort))
	_set_pose_deg(pose, "spine_01", Vector3(5.0 * weight, shoulder_yaw * 0.42, side * 3.0 * effort))
	_set_pose_deg(pose, "spine_02", Vector3(4.0 * weight, shoulder_yaw * 0.68, side * 4.0 * effort))
	_set_pose_deg(pose, "chest", Vector3(2.0 * weight, shoulder_yaw, side * 6.0 * effort))
	_set_pose_deg(pose, "head", Vector3(-2.0, -shoulder_yaw * 0.36, -side * 2.0))
	_set_pose_deg(pose, "upper_arm_r", Vector3(42.0 + height_bias, shoulder_yaw * 0.55, 18.0))
	_set_pose_deg(pose, "forearm_r", Vector3(-46.0 + speed_ratio * 10.0, 0.0, 0.0))
	_set_pose_deg(pose, "upper_arm_l", Vector3(36.0 + height_bias * 0.75, shoulder_yaw * 0.42, -20.0))
	_set_pose_deg(pose, "forearm_l", Vector3(-50.0 + speed_ratio * 8.0, 0.0, 0.0))
	_set_pose_deg(pose, "thigh_l", Vector3(-crouch, 0.0, -8.0))
	_set_pose_deg(pose, "thigh_r", Vector3(-crouch * 0.86, 0.0, 8.0))
	_set_pose_deg(pose, "shin_l", Vector3(crouch * 1.7, 0.0, 0.0))
	_set_pose_deg(pose, "shin_r", Vector3(crouch * 1.55, 0.0, 0.0))
	pose["__pelvis_offset"] = Vector3(
		clampf(-head_yaw / 180.0, -1.0, 1.0) * 0.018,
		-0.075 - crouch * 0.0022,
		-effort * 0.045
	)
	return pose


func _build_chain_slam_pose_v2(
	attack: WeaponAttackDefinition
) -> Dictionary:
	var pose: Dictionary = {}
	var progress: float = _get_attack_progress(attack)
	var startup_share: float = _get_attack_startup_share(attack)
	var heavy: bool = attack.input_kind == "heavy"
	var side: float = _attack_side(attack)
	var weight: float = 1.18 if heavy else 1.0
	if progress < startup_share:
		var p: float = smoothstep(0.0, 1.0, progress / maxf(startup_share, 0.001))
		_set_pose_deg(pose, "pelvis", Vector3(lerpf(13.0, -5.0, p), -side * 10.0, 0.0))
		_set_pose_deg(pose, "chest", Vector3(lerpf(9.0, -14.0, p), -side * 14.0, 0.0))
		_set_pose_deg(pose, "upper_arm_r", Vector3(lerpf(32.0, 116.0, p), -side * 10.0, 20.0))
		_set_pose_deg(pose, "forearm_r", Vector3(lerpf(-52.0, -14.0, p), 0.0, 0.0))
		_set_pose_deg(pose, "upper_arm_l", Vector3(lerpf(28.0, 108.0, p), side * 10.0, -20.0))
		_set_pose_deg(pose, "forearm_l", Vector3(lerpf(-56.0, -18.0, p), 0.0, 0.0))
		_set_pose_deg(pose, "thigh_l", Vector3(-18.0 * weight, 0.0, -7.0))
		_set_pose_deg(pose, "thigh_r", Vector3(-16.0 * weight, 0.0, 7.0))
		_set_pose_deg(pose, "shin_l", Vector3(34.0 * weight, 0.0, 0.0))
		_set_pose_deg(pose, "shin_r", Vector3(31.0 * weight, 0.0, 0.0))
		pose["__pelvis_offset"] = Vector3(0.0, lerpf(-0.11, -0.045, p), -0.02)
		return pose
	var strike: float = smoothstep(
		0.0,
		1.0,
		clampf((progress - startup_share) / maxf(1.0 - startup_share, 0.001), 0.0, 1.0)
	)
	_set_pose_deg(pose, "pelvis", Vector3(lerpf(-5.0, 25.0, strike), side * 7.0, 0.0))
	_set_pose_deg(pose, "chest", Vector3(lerpf(-14.0, 34.0, strike), side * 10.0, 0.0))
	_set_pose_deg(pose, "upper_arm_r", Vector3(lerpf(116.0, -66.0, strike), side * 8.0, 22.0))
	_set_pose_deg(pose, "forearm_r", Vector3(lerpf(-14.0, -38.0, strike), 0.0, 0.0))
	_set_pose_deg(pose, "upper_arm_l", Vector3(lerpf(108.0, -60.0, strike), -side * 8.0, -22.0))
	_set_pose_deg(pose, "forearm_l", Vector3(lerpf(-18.0, -40.0, strike), 0.0, 0.0))
	_set_pose_deg(pose, "thigh_l", Vector3(lerpf(-14.0, -30.0, strike), 0.0, -8.0))
	_set_pose_deg(pose, "thigh_r", Vector3(lerpf(-12.0, -26.0, strike), 0.0, 8.0))
	_set_pose_deg(pose, "shin_l", Vector3(lerpf(30.0, 48.0, strike), 0.0, 0.0))
	_set_pose_deg(pose, "shin_r", Vector3(lerpf(28.0, 44.0, strike), 0.0, 0.0))
	pose["__pelvis_offset"] = Vector3(0.0, lerpf(-0.045, -0.16, strike), lerpf(-0.02, -0.11, strike))
	return pose


func _build_chain_charge_pose_v2() -> Dictionary:
	var pose: Dictionary = {}
	var state: Dictionary = _get_chain_head_state()
	var head_yaw: float = float(state.get("yaw", 0.0))
	var speed_ratio: float = float(state.get("speed", 0.0))
	var charge: float = 0.0
	if weapon_controller != null and weapon_controller.has_method("get_weapon_charge_ratio"):
		charge = float(weapon_controller.call("get_weapon_charge_ratio"))
	var counter_yaw: float = clampf(-head_yaw * 0.18, -23.0, 23.0)
	var shoulder_yaw: float = clampf(head_yaw * 0.2, -28.0, 28.0)
	var crouch: float = lerpf(18.0, 27.0, charge)
	var pull: float = lerpf(0.72, 1.0, speed_ratio)
	_set_pose_deg(pose, "pelvis", Vector3(10.0, counter_yaw, -head_yaw * 0.025))
	_set_pose_deg(pose, "spine_01", Vector3(7.0, shoulder_yaw * 0.45, head_yaw * 0.02))
	_set_pose_deg(pose, "spine_02", Vector3(5.0, shoulder_yaw * 0.72, head_yaw * 0.025))
	_set_pose_deg(pose, "chest", Vector3(3.0, shoulder_yaw, head_yaw * 0.03))
	_set_pose_deg(pose, "head", Vector3(-3.0, -shoulder_yaw * 0.3, 0.0))
	_set_pose_deg(pose, "upper_arm_r", Vector3(43.0, shoulder_yaw * 0.6, 18.0))
	_set_pose_deg(pose, "forearm_r", Vector3(-50.0 + pull * 8.0, 0.0, 0.0))
	_set_pose_deg(pose, "upper_arm_l", Vector3(37.0, shoulder_yaw * 0.5, -20.0))
	_set_pose_deg(pose, "forearm_l", Vector3(-54.0 + pull * 7.0, 0.0, 0.0))
	_set_pose_deg(pose, "thigh_l", Vector3(-crouch, 0.0, -11.0))
	_set_pose_deg(pose, "thigh_r", Vector3(-crouch, 0.0, 11.0))
	_set_pose_deg(pose, "shin_l", Vector3(crouch * 1.72, 0.0, 0.0))
	_set_pose_deg(pose, "shin_r", Vector3(crouch * 1.72, 0.0, 0.0))
	pose["__pelvis_offset"] = Vector3(
		clampf(-head_yaw / 180.0, -1.0, 1.0) * 0.022,
		-0.115 - charge * 0.025,
		0.0
	)
	return pose


func _build_axe_charge_ready_pose() -> Dictionary:
	var pose: Dictionary = {}
	var speed: float = 0.0
	if actor != null:
		speed = Vector2(actor.velocity.x, actor.velocity.z).length()
	var walk_weight: float = clampf(speed / 1.8, 0.0, 1.0)
	var stride: float = sin(elapsed * 5.2) * walk_weight
	var charge: float = 0.0
	if weapon_controller != null and weapon_controller.has_method("get_weapon_charge_ratio"):
		charge = float(weapon_controller.call("get_weapon_charge_ratio"))
	_set_pose_deg(pose, "pelvis", Vector3(2.0, -stride * 3.0, 0.0))
	_set_pose_deg(pose, "spine_01", Vector3(-3.0, stride * 1.5, 0.0))
	_set_pose_deg(pose, "spine_02", Vector3(-5.0, stride * 2.0, 0.0))
	_set_pose_deg(pose, "chest", Vector3(-7.0, stride * 2.5, 0.0))
	_set_pose_deg(pose, "head", Vector3(3.0, -stride * 1.5, 0.0))
	_set_pose_deg(pose, "upper_arm_r", Vector3(126.0, -8.0, 22.0))
	_set_pose_deg(pose, "forearm_r", Vector3(-18.0, 0.0, 0.0))
	_set_pose_deg(pose, "upper_arm_l", Vector3(120.0, 8.0, -22.0))
	_set_pose_deg(pose, "forearm_l", Vector3(-22.0, 0.0, 0.0))
	_set_pose_deg(pose, "thigh_l", Vector3(stride * 18.0, 0.0, -4.0))
	_set_pose_deg(pose, "thigh_r", Vector3(-stride * 18.0, 0.0, 4.0))
	_set_pose_deg(pose, "shin_l", Vector3(maxf(-stride, 0.0) * 32.0, 0.0, 0.0))
	_set_pose_deg(pose, "shin_r", Vector3(maxf(stride, 0.0) * 32.0, 0.0, 0.0))
	pose["__pelvis_offset"] = Vector3(0.0, -0.035 - charge * 0.015 - absf(stride) * 0.012, 0.0)
	return pose


func _build_axe_lever_twist_pose(
	attack: WeaponAttackDefinition,
	stage: String
) -> Dictionary:
	var pose: Dictionary = {}
	if weapon_controller == null:
		return pose
	var startup: float = maxf(attack.get_startup_duration(weapon_controller.get_attack_speed()), 0.01)
	var time: float = maxf(weapon_controller.current_attack_elapsed, 0.0)
	var p: float = clampf(time / startup, 0.0, 1.0)
	if time >= startup:
		_build_axe_final_slam_pose(pose, stage)
		return pose

	if p < 0.18:
		var plant: float = smoothstep(0.0, 1.0, p / 0.18)
		_set_pose_deg(pose, "pelvis", Vector3(lerpf(2.0, 20.0, plant), 0.0, 0.0))
		_set_pose_deg(pose, "chest", Vector3(lerpf(-7.0, 27.0, plant), 0.0, 0.0))
		_set_pose_deg(pose, "upper_arm_r", Vector3(lerpf(126.0, -52.0, plant), -8.0, 22.0))
		_set_pose_deg(pose, "forearm_r", Vector3(lerpf(-18.0, -42.0, plant), 0.0, 0.0))
		_set_pose_deg(pose, "upper_arm_l", Vector3(lerpf(120.0, -48.0, plant), 8.0, -22.0))
		_set_pose_deg(pose, "forearm_l", Vector3(lerpf(-22.0, -44.0, plant), 0.0, 0.0))
		_set_pose_deg(pose, "thigh_l", Vector3(lerpf(-8.0, -30.0, plant), 0.0, -5.0))
		_set_pose_deg(pose, "thigh_r", Vector3(lerpf(12.0, -24.0, plant), 0.0, 5.0))
		_set_pose_deg(pose, "shin_l", Vector3(lerpf(18.0, 48.0, plant), 0.0, 0.0))
		_set_pose_deg(pose, "shin_r", Vector3(lerpf(12.0, 42.0, plant), 0.0, 0.0))
		pose["__pelvis_offset"] = Vector3(0.0, lerpf(-0.035, -0.145, plant), lerpf(0.0, -0.1, plant))
		return pose

	if p < 0.46:
		var lever: float = smoothstep(0.0, 1.0, (p - 0.18) / 0.28)
		_set_pose_deg(pose, "pelvis", Vector3(lerpf(20.0, -34.0, lever), 0.0, lerpf(0.0, 12.0, lever)))
		_set_pose_deg(pose, "spine_01", Vector3(lerpf(24.0, -22.0, lever), 0.0, 8.0 * lever))
		_set_pose_deg(pose, "spine_02", Vector3(lerpf(26.0, -18.0, lever), 0.0, 10.0 * lever))
		_set_pose_deg(pose, "chest", Vector3(lerpf(27.0, -14.0, lever), 0.0, 12.0 * lever))
		_set_pose_deg(pose, "upper_arm_r", Vector3(lerpf(-52.0, 28.0, lever), -8.0, 22.0))
		_set_pose_deg(pose, "forearm_r", Vector3(lerpf(-42.0, -64.0, lever), 0.0, 0.0))
		_set_pose_deg(pose, "upper_arm_l", Vector3(lerpf(-48.0, 24.0, lever), 8.0, -22.0))
		_set_pose_deg(pose, "forearm_l", Vector3(lerpf(-44.0, -66.0, lever), 0.0, 0.0))
		_set_pose_deg(pose, "thigh_l", Vector3(lerpf(-30.0, 54.0, lever), 0.0, -7.0))
		_set_pose_deg(pose, "thigh_r", Vector3(lerpf(-24.0, 48.0, lever), 0.0, 7.0))
		_set_pose_deg(pose, "shin_l", Vector3(lerpf(48.0, -64.0, lever), 0.0, 0.0))
		_set_pose_deg(pose, "shin_r", Vector3(lerpf(42.0, -58.0, lever), 0.0, 0.0))
		pose["__pelvis_offset"] = Vector3(0.0, lerpf(-0.145, 0.19, lever), lerpf(-0.1, -0.18, lever))
		return pose

	if p < 0.58:
		var pull: float = smoothstep(0.0, 1.0, (p - 0.46) / 0.12)
		_set_pose_deg(pose, "pelvis", Vector3(lerpf(-34.0, -20.0, pull), 0.0, lerpf(12.0, 24.0, pull)))
		_set_pose_deg(pose, "chest", Vector3(lerpf(-14.0, -20.0, pull), 0.0, lerpf(12.0, 24.0, pull)))
		_set_pose_deg(pose, "upper_arm_r", Vector3(lerpf(28.0, 94.0, pull), -8.0, 22.0))
		_set_pose_deg(pose, "forearm_r", Vector3(lerpf(-64.0, -30.0, pull), 0.0, 0.0))
		_set_pose_deg(pose, "upper_arm_l", Vector3(lerpf(24.0, 88.0, pull), 8.0, -22.0))
		_set_pose_deg(pose, "forearm_l", Vector3(lerpf(-66.0, -32.0, pull), 0.0, 0.0))
		_set_pose_deg(pose, "thigh_l", Vector3(50.0, 0.0, -8.0))
		_set_pose_deg(pose, "thigh_r", Vector3(45.0, 0.0, 8.0))
		_set_pose_deg(pose, "shin_l", Vector3(-62.0, 0.0, 0.0))
		_set_pose_deg(pose, "shin_r", Vector3(-58.0, 0.0, 0.0))
		pose["__pelvis_offset"] = Vector3(0.0, lerpf(0.19, 0.23, pull), lerpf(-0.18, -0.2, pull))
		return pose

	if p < 0.9:
		var twist: float = smoothstep(0.0, 1.0, (p - 0.58) / 0.32)
		var twist_angle: float = twist * 360.0
		var diagonal_roll: float = sin(twist * PI) * 34.0
		var axe_orbit: float = sin(twist * TAU)
		_set_pose_deg(pose, "pelvis", Vector3(-20.0 + sin(twist * PI) * 18.0, twist_angle, diagonal_roll))
		_set_pose_deg(pose, "spine_01", Vector3(-18.0, twist_angle * 0.78, diagonal_roll * 0.82))
		_set_pose_deg(pose, "spine_02", Vector3(-16.0, twist_angle * 0.9, diagonal_roll * 0.9))
		_set_pose_deg(pose, "chest", Vector3(-14.0, twist_angle + 18.0, diagonal_roll))
		_set_pose_deg(pose, "head", Vector3(5.0, -18.0, -diagonal_roll * 0.25))
		_set_pose_deg(pose, "upper_arm_r", Vector3(94.0 + axe_orbit * 28.0, -10.0, 24.0))
		_set_pose_deg(pose, "forearm_r", Vector3(-30.0 + axe_orbit * 18.0, 0.0, 0.0))
		_set_pose_deg(pose, "upper_arm_l", Vector3(88.0 + axe_orbit * 26.0, 10.0, -24.0))
		_set_pose_deg(pose, "forearm_l", Vector3(-32.0 + axe_orbit * 16.0, 0.0, 0.0))
		_set_pose_deg(pose, "thigh_l", Vector3(55.0, 0.0, -10.0))
		_set_pose_deg(pose, "thigh_r", Vector3(48.0, 0.0, 10.0))
		_set_pose_deg(pose, "shin_l", Vector3(-70.0, 0.0, 0.0))
		_set_pose_deg(pose, "shin_r", Vector3(-64.0, 0.0, 0.0))
		pose["__pelvis_offset"] = Vector3(0.0, lerpf(0.23, 0.035, twist), lerpf(-0.2, -0.31, twist))
		return pose

	var descend: float = smoothstep(0.0, 1.0, (p - 0.9) / 0.1)
	_set_pose_deg(pose, "pelvis", Vector3(lerpf(-2.0, 20.0, descend), 360.0, lerpf(0.0, -8.0, descend)))
	_set_pose_deg(pose, "chest", Vector3(lerpf(-14.0, 30.0, descend), 378.0, lerpf(0.0, -10.0, descend)))
	_set_pose_deg(pose, "upper_arm_r", Vector3(lerpf(112.0, -58.0, descend), -8.0, 22.0))
	_set_pose_deg(pose, "forearm_r", Vector3(lerpf(-18.0, -40.0, descend), 0.0, 0.0))
	_set_pose_deg(pose, "upper_arm_l", Vector3(lerpf(106.0, -54.0, descend), 8.0, -22.0))
	_set_pose_deg(pose, "forearm_l", Vector3(lerpf(-20.0, -42.0, descend), 0.0, 0.0))
	_set_pose_deg(pose, "thigh_l", Vector3(lerpf(32.0, -30.0, descend), 0.0, -7.0))
	_set_pose_deg(pose, "thigh_r", Vector3(lerpf(28.0, -26.0, descend), 0.0, 7.0))
	_set_pose_deg(pose, "shin_l", Vector3(lerpf(-36.0, 48.0, descend), 0.0, 0.0))
	_set_pose_deg(pose, "shin_r", Vector3(lerpf(-32.0, 44.0, descend), 0.0, 0.0))
	pose["__pelvis_offset"] = Vector3(0.0, lerpf(0.035, -0.15, descend), lerpf(-0.31, -0.36, descend))
	return pose


func _build_axe_final_slam_pose(
	pose: Dictionary,
	stage: String
) -> void:
	match stage:
		"contact":
			_set_pose_deg(pose, "pelvis", Vector3(22.0, 0.0, -8.0))
			_set_pose_deg(pose, "chest", Vector3(32.0, 8.0, -10.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(-62.0, -8.0, 22.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(-58.0, 8.0, -22.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.16, -0.36)
		"follow":
			_set_pose_deg(pose, "pelvis", Vector3(28.0, 0.0, -10.0))
			_set_pose_deg(pose, "chest", Vector3(38.0, 10.0, -12.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(-74.0, -10.0, 26.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(-70.0, 10.0, -26.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.18, -0.38)
		_:
			_set_pose_deg(pose, "pelvis", Vector3(7.0, 0.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(9.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.045, -0.04)


func _build_staff_mount_pose() -> Dictionary:
	var pose: Dictionary = {}
	var charge: float = 0.0
	if weapon_controller != null and weapon_controller.has_method("get_weapon_charge_ratio"):
		charge = float(weapon_controller.call("get_weapon_charge_ratio"))
	var balance: float = sin(elapsed * 1.8) * lerpf(1.5, 3.0, charge)
	_set_pose_deg(pose, "pelvis", Vector3(-8.0, balance, 0.0))
	_set_pose_deg(pose, "spine_01", Vector3(-10.0, -balance * 0.45, 0.0))
	_set_pose_deg(pose, "spine_02", Vector3(-8.0, -balance * 0.55, 0.0))
	_set_pose_deg(pose, "chest", Vector3(-6.0, -balance * 0.7, 0.0))
	_set_pose_deg(pose, "head", Vector3(4.0, balance * 0.35, 0.0))
	_set_pose_deg(pose, "upper_arm_r", Vector3(84.0, -6.0, 12.0))
	_set_pose_deg(pose, "forearm_r", Vector3(-36.0, 0.0, 0.0))
	_set_pose_deg(pose, "upper_arm_l", Vector3(80.0, 6.0, -12.0))
	_set_pose_deg(pose, "forearm_l", Vector3(-40.0, 0.0, 0.0))
	_set_pose_deg(pose, "thigh_l", Vector3(58.0, 0.0, -11.0))
	_set_pose_deg(pose, "thigh_r", Vector3(54.0, 0.0, 11.0))
	_set_pose_deg(pose, "shin_l", Vector3(-82.0, 0.0, 0.0))
	_set_pose_deg(pose, "shin_r", Vector3(-78.0, 0.0, 0.0))
	_set_pose_deg(pose, "foot_l", Vector3(22.0, 0.0, 0.0))
	_set_pose_deg(pose, "foot_r", Vector3(20.0, 0.0, 0.0))
	pose["__pelvis_offset"] = Vector3(0.0, lerpf(0.24, 0.43, charge), -0.055)
	return pose


func _build_staff_map_vault_pose(
	attack: WeaponAttackDefinition,
	stage: String
) -> Dictionary:
	var pose: Dictionary = {}
	if weapon_controller == null:
		return pose
	var startup: float = maxf(attack.get_startup_duration(weapon_controller.get_attack_speed()), 0.01)
	var time: float = maxf(weapon_controller.current_attack_elapsed, 0.0)
	var p: float = clampf(time / startup, 0.0, 1.0)
	if time >= startup:
		_build_staff_vault_follow_pose(pose, stage)
		return pose
	if p < 0.34:
		var compress: float = smoothstep(0.0, 1.0, p / 0.34)
		_set_pose_deg(pose, "pelvis", Vector3(lerpf(-8.0, 18.0, compress), 0.0, 0.0))
		_set_pose_deg(pose, "chest", Vector3(lerpf(-6.0, 20.0, compress), 0.0, 0.0))
		_set_pose_deg(pose, "upper_arm_r", Vector3(lerpf(84.0, 94.0, compress), -5.0, 10.0))
		_set_pose_deg(pose, "forearm_r", Vector3(lerpf(-36.0, -14.0, compress), 0.0, 0.0))
		_set_pose_deg(pose, "upper_arm_l", Vector3(lerpf(80.0, 90.0, compress), 5.0, -10.0))
		_set_pose_deg(pose, "forearm_l", Vector3(lerpf(-40.0, -18.0, compress), 0.0, 0.0))
		_set_pose_deg(pose, "thigh_l", Vector3(lerpf(58.0, -24.0, compress), 0.0, -9.0))
		_set_pose_deg(pose, "thigh_r", Vector3(lerpf(54.0, -20.0, compress), 0.0, 9.0))
		_set_pose_deg(pose, "shin_l", Vector3(lerpf(-82.0, 42.0, compress), 0.0, 0.0))
		_set_pose_deg(pose, "shin_r", Vector3(lerpf(-78.0, 38.0, compress), 0.0, 0.0))
		pose["__pelvis_offset"] = Vector3(0.0, lerpf(0.38, 0.08, compress), lerpf(-0.055, -0.11, compress))
		return pose
	if p < 0.72:
		var rise: float = smoothstep(0.0, 1.0, (p - 0.34) / 0.38)
		_set_pose_deg(pose, "pelvis", Vector3(lerpf(18.0, -22.0, rise), 0.0, 0.0))
		_set_pose_deg(pose, "chest", Vector3(lerpf(20.0, -12.0, rise), 0.0, 0.0))
		_set_pose_deg(pose, "upper_arm_r", Vector3(lerpf(94.0, 82.0, rise), -4.0, 9.0))
		_set_pose_deg(pose, "forearm_r", Vector3(lerpf(-14.0, -4.0, rise), 0.0, 0.0))
		_set_pose_deg(pose, "upper_arm_l", Vector3(lerpf(90.0, 78.0, rise), 4.0, -9.0))
		_set_pose_deg(pose, "forearm_l", Vector3(lerpf(-18.0, -6.0, rise), 0.0, 0.0))
		_set_pose_deg(pose, "thigh_l", Vector3(lerpf(-24.0, 30.0, rise), 0.0, -7.0))
		_set_pose_deg(pose, "thigh_r", Vector3(lerpf(-20.0, 26.0, rise), 0.0, 7.0))
		_set_pose_deg(pose, "shin_l", Vector3(lerpf(42.0, -34.0, rise), 0.0, 0.0))
		_set_pose_deg(pose, "shin_r", Vector3(lerpf(38.0, -30.0, rise), 0.0, 0.0))
		pose["__pelvis_offset"] = Vector3(0.0, lerpf(0.08, 0.52, rise), lerpf(-0.11, -0.2, rise))
		return pose
	var launch: float = smoothstep(0.0, 1.0, (p - 0.72) / 0.28)
	_set_pose_deg(pose, "pelvis", Vector3(lerpf(-22.0, -6.0, launch), 0.0, 0.0))
	_set_pose_deg(pose, "chest", Vector3(lerpf(-12.0, -4.0, launch), 0.0, 0.0))
	_set_pose_deg(pose, "upper_arm_r", Vector3(lerpf(82.0, 28.0, launch), -4.0, 12.0))
	_set_pose_deg(pose, "forearm_r", Vector3(lerpf(-4.0, -28.0, launch), 0.0, 0.0))
	_set_pose_deg(pose, "upper_arm_l", Vector3(lerpf(78.0, 24.0, launch), 4.0, -12.0))
	_set_pose_deg(pose, "forearm_l", Vector3(lerpf(-6.0, -30.0, launch), 0.0, 0.0))
	_set_pose_deg(pose, "thigh_l", Vector3(lerpf(30.0, -18.0, launch), 0.0, -5.0))
	_set_pose_deg(pose, "thigh_r", Vector3(lerpf(26.0, -14.0, launch), 0.0, 5.0))
	_set_pose_deg(pose, "shin_l", Vector3(lerpf(-34.0, 18.0, launch), 0.0, 0.0))
	_set_pose_deg(pose, "shin_r", Vector3(lerpf(-30.0, 16.0, launch), 0.0, 0.0))
	pose["__pelvis_offset"] = Vector3(0.0, lerpf(0.52, 0.08, launch), lerpf(-0.2, -0.34, launch))
	return pose


func _build_staff_vault_follow_pose(
	pose: Dictionary,
	stage: String
) -> void:
	match stage:
		"contact", "follow":
			_set_pose_deg(pose, "pelvis", Vector3(-7.0, 0.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(-5.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(24.0, -3.0, 13.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-30.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(20.0, 3.0, -13.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-32.0, 0.0, 0.0))
			_set_pose_deg(pose, "thigh_l", Vector3(-20.0, 0.0, -5.0))
			_set_pose_deg(pose, "thigh_r", Vector3(-15.0, 0.0, 5.0))
			_set_pose_deg(pose, "shin_l", Vector3(20.0, 0.0, 0.0))
			_set_pose_deg(pose, "shin_r", Vector3(17.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, 0.06, -0.34)
		_:
			_set_pose_deg(pose, "pelvis", Vector3(1.0, 0.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(2.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, 0.01, -0.04)


func _get_chain_head_state() -> Dictionary:
	var result: Dictionary = {"yaw": 0.0, "height": 0.3, "speed": 0.0}
	if weapon_controller == null or actor == null:
		return result
	var rig: Node = weapon_controller.runtime_weapon_rig
	if rig == null or not rig.has_method("get_head_world_position"):
		return result
	var head_value: Variant = rig.call("get_head_world_position")
	if not head_value is Vector3:
		return result
	var head_position: Vector3 = head_value as Vector3
	var offset: Vector3 = head_position - actor.global_position
	var planar: Vector3 = offset
	planar.y = 0.0
	var forward: Vector3 = -actor.global_transform.basis.z
	var right: Vector3 = actor.global_transform.basis.x
	forward.y = 0.0
	right.y = 0.0
	if planar.length_squared() > 0.0001 and forward.length_squared() > 0.0001 and right.length_squared() > 0.0001:
		result["yaw"] = rad_to_deg(atan2(planar.dot(right.normalized()), planar.dot(forward.normalized())))
	result["height"] = offset.y
	if rig.has_method("get_head_speed_ratio"):
		result["speed"] = clampf(float(rig.call("get_head_speed_ratio")), 0.0, 1.0)
	return result


func _get_attack_progress(attack: WeaponAttackDefinition) -> float:
	if attack == null or weapon_controller == null:
		return 0.0
	var total: float = maxf(attack.get_total_duration(weapon_controller.get_attack_speed()), 0.001)
	return clampf(weapon_controller.current_attack_elapsed / total, 0.0, 1.0)


func _get_attack_startup_share(attack: WeaponAttackDefinition) -> float:
	if attack == null or weapon_controller == null:
		return 0.5
	var speed: float = weapon_controller.get_attack_speed()
	var startup: float = attack.get_startup_duration(speed)
	var total: float = maxf(attack.get_total_duration(speed), 0.001)
	return clampf(startup / total, 0.05, 0.95)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["weapon_language_v4h"] = true
	data["chain_pose_follows_head"] = true
	data["axe_two_plant_lever_twist"] = true
	data["staff_mounted_map_vault"] = true
	return data
