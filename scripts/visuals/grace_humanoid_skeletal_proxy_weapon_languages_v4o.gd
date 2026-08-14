extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_weapon_languages_v4n.gd"

# V4O completes the first authored Axe set: forward-driving Aerial Light, an
# edge-first crashing Aerial Heavy, and the charge-Light catch/reversal.


func _build_attack_stage_pose(
	attack: WeaponAttackDefinition,
	stage: String
) -> Dictionary:
	if _get_equipped_weapon_class() != "axe" or attack == null:
		return super._build_attack_stage_pose(attack, stage)
	if attack.extra_tags.has("axe_counter_guard"):
		return _build_axe_counter_guard_pose()
	if attack.extra_tags.has("axe_counter_reversal"):
		return _build_axe_counter_reversal_pose(stage)
	if attack.extra_tags.has("axe_aerial_drive"):
		return _build_axe_aerial_drive_pose(stage)
	if attack.extra_tags.has("axe_aerial_crash"):
		return _build_axe_aerial_crash_pose(stage)
	return super._build_attack_stage_pose(attack, stage)


func _build_axe_counter_guard_pose() -> Dictionary:
	var pose: Dictionary = {}
	var timing: float = 0.0
	if weapon_controller != null and weapon_controller.has_method("get_axe_counter_timing_ratio"):
		timing = clampf(
			float(weapon_controller.call("get_axe_counter_timing_ratio")),
			0.0,
			1.0
		)
	var pulse: float = sin(elapsed * 34.0) * timing
	_set_pose_deg(pose, "pelvis", Vector3(9.0, -4.0, -2.0))
	_set_pose_deg(pose, "spine_01", Vector3(5.0, -3.0, 2.0))
	_set_pose_deg(pose, "spine_02", Vector3(1.0, -5.0, 3.0))
	_set_pose_deg(pose, "chest", Vector3(-4.0, -8.0, 4.0))
	_set_pose_deg(pose, "head", Vector3(2.0, 4.0, -1.0))
	_set_pose_deg(pose, "upper_arm_r", Vector3(72.0 + pulse * 2.0, -19.0, 21.0))
	_set_pose_deg(pose, "forearm_r", Vector3(-41.0 + pulse * 2.0, 6.0, -4.0))
	_set_pose_deg(pose, "hand_r", Vector3(-5.0, 0.0, 31.0 + timing * 3.0))
	_set_pose_deg(pose, "upper_arm_l", Vector3(66.0 - pulse * 2.0, 17.0, -21.0))
	_set_pose_deg(pose, "forearm_l", Vector3(-45.0 - pulse * 2.0, -5.0, 4.0))
	_set_pose_deg(pose, "hand_l", Vector3(-6.0, 0.0, 28.0 + timing * 3.0))
	_set_pose_deg(pose, "thigh_l", Vector3(-24.0, 0.0, -9.0))
	_set_pose_deg(pose, "thigh_r", Vector3(-21.0, 0.0, 9.0))
	_set_pose_deg(pose, "shin_l", Vector3(40.0, 0.0, 0.0))
	_set_pose_deg(pose, "shin_r", Vector3(36.0, 0.0, 0.0))
	pose["__pelvis_offset"] = Vector3(
		pulse * 0.006,
		-0.125 - timing * 0.012,
		-0.035 - timing * 0.018
	)
	return pose


func _build_axe_counter_reversal_pose(stage: String) -> Dictionary:
	if stage == "windup":
		return _build_axe_counter_guard_pose()
	var pose: Dictionary = {}
	match stage:
		"contact":
			_set_pose_deg(pose, "pelvis", Vector3(-11.0, 25.0, -4.0))
			_set_pose_deg(pose, "spine_01", Vector3(-13.0, 18.0, 3.0))
			_set_pose_deg(pose, "spine_02", Vector3(-15.0, 25.0, 4.0))
			_set_pose_deg(pose, "chest", Vector3(-19.0, 36.0, 5.0))
			_set_pose_deg(pose, "head", Vector3(5.0, -11.0, -1.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(94.0, 31.0, -25.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-8.0, -9.0, 6.0))
			_set_pose_deg(pose, "hand_r", Vector3(4.0, 0.0, 32.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(61.0, -16.0, 24.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-18.0, 6.0, -5.0))
			_set_pose_deg(pose, "hand_l", Vector3(2.0, 0.0, 29.0))
			_set_pose_deg(pose, "thigh_l", Vector3(22.0, 0.0, -5.0))
			_set_pose_deg(pose, "thigh_r", Vector3(-28.0, 0.0, 5.0))
			_set_pose_deg(pose, "shin_r", Vector3(39.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(-0.025, -0.075, -0.12)
		"follow":
			_set_pose_deg(pose, "pelvis", Vector3(-15.0, 34.0, -5.0))
			_set_pose_deg(pose, "chest", Vector3(-25.0, 48.0, 7.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(112.0, 43.0, -32.0))
			_set_pose_deg(pose, "forearm_r", Vector3(4.0, -12.0, 8.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(69.0, -22.0, 29.0))
			_set_pose_deg(pose, "hand_r", Vector3(7.0, 0.0, 30.0))
			_set_pose_deg(pose, "hand_l", Vector3(4.0, 0.0, 27.0))
			pose["__pelvis_offset"] = Vector3(-0.04, -0.08, -0.17)
		_:
			_set_pose_deg(pose, "pelvis", Vector3(5.0, 2.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(8.0, 4.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(30.0, 4.0, 9.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-25.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(21.0, -2.0, -8.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.03, -0.02)
	return pose


func _build_axe_aerial_drive_pose(stage: String) -> Dictionary:
	var pose: Dictionary = {}
	match stage:
		"windup":
			_set_pose_deg(pose, "pelvis", Vector3(-13.0, -17.0, -3.0))
			_set_pose_deg(pose, "spine_01", Vector3(-9.0, -12.0, 2.0))
			_set_pose_deg(pose, "spine_02", Vector3(-7.0, -17.0, 3.0))
			_set_pose_deg(pose, "chest", Vector3(-6.0, -24.0, 4.0))
			_set_pose_deg(pose, "head", Vector3(5.0, 8.0, -1.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(63.0, -27.0, 28.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-48.0, 8.0, -7.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(27.0, 9.0, -21.0))
			_set_pose_deg(pose, "thigh_l", Vector3(18.0, 0.0, -6.0))
			_set_pose_deg(pose, "thigh_r", Vector3(10.0, 0.0, 6.0))
			_set_pose_deg(pose, "shin_l", Vector3(-25.0, 0.0, 0.0))
			_set_pose_deg(pose, "shin_r", Vector3(-18.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.02, 0.015, -0.11)
		"contact":
			_set_pose_deg(pose, "pelvis", Vector3(-21.0, 24.0, 3.0))
			_set_pose_deg(pose, "spine_01", Vector3(-16.0, 18.0, -2.0))
			_set_pose_deg(pose, "chest", Vector3(-20.0, 34.0, -4.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(98.0, 32.0, -25.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-9.0, -9.0, 6.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(39.0, -12.0, 23.0))
			_set_pose_deg(pose, "thigh_l", Vector3(-12.0, 0.0, -5.0))
			_set_pose_deg(pose, "thigh_r", Vector3(-18.0, 0.0, 5.0))
			_set_pose_deg(pose, "shin_l", Vector3(14.0, 0.0, 0.0))
			_set_pose_deg(pose, "shin_r", Vector3(20.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(-0.025, 0.005, -0.2)
		"follow":
			_set_pose_deg(pose, "pelvis", Vector3(-24.0, 33.0, 4.0))
			_set_pose_deg(pose, "chest", Vector3(-25.0, 46.0, -5.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(112.0, 42.0, -30.0))
			_set_pose_deg(pose, "forearm_r", Vector3(2.0, -12.0, 8.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(45.0, -17.0, 27.0))
			pose["__pelvis_offset"] = Vector3(-0.04, 0.0, -0.25)
		_:
			_set_pose_deg(pose, "pelvis", Vector3(-5.0, 3.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(-3.0, 5.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(29.0, 4.0, 8.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-24.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, 0.0, -0.05)
	return pose


func _build_axe_aerial_crash_pose(stage: String) -> Dictionary:
	var pose: Dictionary = {}
	match stage:
		"windup":
			_set_pose_deg(pose, "pelvis", Vector3(-18.0, -2.0, 0.0))
			_set_pose_deg(pose, "spine_01", Vector3(-13.0, -2.0, 0.0))
			_set_pose_deg(pose, "spine_02", Vector3(-9.0, -2.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(-5.0, -2.0, 0.0))
			_set_pose_deg(pose, "head", Vector3(5.0, 1.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(132.0, -5.0, 13.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-27.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(107.0, 7.0, -15.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-45.0, 0.0, 0.0))
			_set_pose_deg(pose, "hand_r", Vector3(-4.0, 0.0, 34.0))
			_set_pose_deg(pose, "hand_l", Vector3(-6.0, 0.0, 30.0))
			_set_pose_deg(pose, "thigh_l", Vector3(36.0, 0.0, -7.0))
			_set_pose_deg(pose, "thigh_r", Vector3(31.0, 0.0, 7.0))
			_set_pose_deg(pose, "shin_l", Vector3(-46.0, 0.0, 0.0))
			_set_pose_deg(pose, "shin_r", Vector3(-40.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, 0.11, -0.1)
		"contact":
			_set_pose_deg(pose, "pelvis", Vector3(20.0, 2.0, 0.0))
			_set_pose_deg(pose, "spine_01", Vector3(23.0, 2.0, 0.0))
			_set_pose_deg(pose, "spine_02", Vector3(28.0, 2.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(35.0, 2.0, 0.0))
			_set_pose_deg(pose, "head", Vector3(-10.0, -1.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(48.0, 4.0, 12.0))
			_set_pose_deg(pose, "forearm_r", Vector3(5.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(43.0, -4.0, -12.0))
			_set_pose_deg(pose, "forearm_l", Vector3(1.0, 0.0, 0.0))
			_set_pose_deg(pose, "hand_r", Vector3(0.0, 0.0, 32.0))
			_set_pose_deg(pose, "hand_l", Vector3(0.0, 0.0, 28.0))
			_set_pose_deg(pose, "thigh_l", Vector3(-18.0, 0.0, -5.0))
			_set_pose_deg(pose, "thigh_r", Vector3(-23.0, 0.0, 5.0))
			_set_pose_deg(pose, "shin_l", Vector3(28.0, 0.0, 0.0))
			_set_pose_deg(pose, "shin_r", Vector3(34.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.11, -0.18)
		"follow":
			_set_pose_deg(pose, "pelvis", Vector3(25.0, 3.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(42.0, 3.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(35.0, 5.0, 13.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(31.0, -5.0, -13.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.15, -0.22)
		_:
			_set_pose_deg(pose, "pelvis", Vector3(7.0, 0.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(10.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(27.0, 0.0, 8.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-24.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.035, -0.03)
	return pose


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["weapon_language_v4o"] = true
	data["axe_aerial_drive_pose"] = true
	data["axe_aerial_crash_pose"] = true
	data["axe_counter_guard_pose"] = true
	data["axe_counter_reversal_pose"] = true
	return data
