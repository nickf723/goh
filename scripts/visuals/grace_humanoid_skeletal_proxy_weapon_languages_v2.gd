extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_grounded.gd"

# Second authored weapon-language layer for the skeletal Grace proxy.
# Sword remains owned by the grounded parent. This layer adds three deliberate
# contrast classes without changing gameplay timing or hit authority:
# - Hammer: planted, two-handed weight and delayed reversal.
# - Lance: linear reach, rear-leg drive, compact support-hand control.
# - Daggers: alternating hands, low stance, evasive pressure.

var offhand_dagger_root: Node3D
var offhand_dagger_signature: String = ""


func _process(delta: float) -> void:
	super._process(delta)
	_update_offhand_dagger()


func _build_attack_stage_pose(attack: WeaponAttackDefinition, stage: String) -> Dictionary:
	var weapon_class: String = _get_equipped_weapon_class()
	match weapon_class:
		"hammer":
			return _build_hammer_attack_pose(attack, stage)
		"lance":
			return _build_lance_attack_pose(attack, stage)
		"daggers":
			return _build_dagger_attack_pose(attack, stage)
		_:
			return super._build_attack_stage_pose(attack, stage)


func _get_equipped_weapon_class() -> String:
	if weapon_controller == null or weapon_controller.equipped_weapon == null:
		return ""
	return weapon_controller.equipped_weapon.weapon_class


func _build_hammer_attack_pose(attack: WeaponAttackDefinition, stage: String) -> Dictionary:
	var pose: Dictionary = {}
	if attack == null:
		return pose
	if attack.extra_tags.has("dash_light"):
		_build_hammer_dash_pose(pose, stage, false)
		return pose
	if attack.extra_tags.has("dash_heavy"):
		_build_hammer_dash_pose(pose, stage, true)
		return pose
	if attack.extra_tags.has("aerial_light"):
		_build_hammer_aerial_pose(pose, stage, false)
		return pose
	if attack.extra_tags.has("aerial_heavy"):
		_build_hammer_aerial_pose(pose, stage, true)
		return pose

	var attack_id: String = attack.attack_id.to_lower()
	var side: float = _attack_side(attack)
	if attack_id in ["hammer_l3", "hammer_h0", "hammer_h3"] or attack.extra_tags.has("ground_slam"):
		_build_hammer_slam_pose(pose, stage, attack_id == "hammer_h3")
	elif attack_id == "hammer_h1" or attack.extra_tags.has("launcher"):
		_build_hammer_rising_pose(pose, stage)
	else:
		_build_hammer_sweep_pose(
			pose,
			stage,
			side,
			attack.input_kind == "heavy",
			attack_id == "hammer_h2" or attack.extra_tags.has("cleave")
		)
	return pose


func _build_hammer_sweep_pose(
	pose: Dictionary,
	stage: String,
	side: float,
	heavy: bool,
	broad: bool
) -> void:
	var weight: float = 1.16 if heavy else 1.0
	var width: float = 1.18 if broad else 1.0
	match stage:
		"windup":
			_set_pose_deg(pose, "pelvis", Vector3(5.0, -13.0 * side * width, 2.0 * side))
			_set_pose_deg(pose, "spine_01", Vector3(5.0, -10.0 * side * width, -2.0 * side))
			_set_pose_deg(pose, "spine_02", Vector3(6.0, -13.0 * side * width, -2.0 * side))
			_set_pose_deg(pose, "chest", Vector3(7.0, -18.0 * side * width, -3.0 * side))
			_set_pose_deg(pose, "head", Vector3(-2.0, 7.0 * side, 1.0 * side))
			_set_pose_deg(pose, "clavicle_r", Vector3(0.0, -6.0 * side, 6.0 * side))
			_set_pose_deg(pose, "upper_arm_r", Vector3(72.0, -18.0 * side, 24.0 * side))
			_set_pose_deg(pose, "forearm_r", Vector3(-38.0, 8.0 * side, -6.0 * side))
			_set_pose_deg(pose, "hand_r", Vector3(-8.0, -7.0 * side, 8.0 * side))
			_set_pose_deg(pose, "upper_arm_l", Vector3(62.0, -6.0 * side, -22.0 * side))
			_set_pose_deg(pose, "forearm_l", Vector3(-46.0, -6.0 * side, 4.0 * side))
			_set_pose_deg(pose, "hand_l", Vector3(-5.0, 6.0 * side, -4.0 * side))
			_set_hammer_stance(pose, side, -1.0, heavy)
			pose["__pelvis_offset"] = Vector3(0.012 * side, -0.052 * weight, 0.025)
		"contact":
			_set_pose_deg(pose, "pelvis", Vector3(-7.0, 16.0 * side * width * weight, -2.0 * side))
			_set_pose_deg(pose, "spine_01", Vector3(-9.0, 12.0 * side * width * weight, 2.0 * side))
			_set_pose_deg(pose, "spine_02", Vector3(-11.0, 16.0 * side * width * weight, 2.0 * side))
			_set_pose_deg(pose, "chest", Vector3(-13.0, 23.0 * side * width * weight, 3.0 * side))
			_set_pose_deg(pose, "head", Vector3(4.0, -8.0 * side, -1.0 * side))
			_set_pose_deg(pose, "upper_arm_r", Vector3(94.0, 22.0 * side, -20.0 * side))
			_set_pose_deg(pose, "forearm_r", Vector3(-14.0, -7.0 * side, 5.0 * side))
			_set_pose_deg(pose, "hand_r", Vector3(8.0, 8.0 * side, -7.0 * side))
			_set_pose_deg(pose, "upper_arm_l", Vector3(82.0, 11.0 * side, 20.0 * side))
			_set_pose_deg(pose, "forearm_l", Vector3(-20.0, 5.0 * side, -4.0 * side))
			_set_pose_deg(pose, "hand_l", Vector3(5.0, -5.0 * side, 4.0 * side))
			_set_hammer_stance(pose, side, 1.0, heavy)
			pose["__pelvis_offset"] = Vector3(-0.015 * side, -0.065 * weight, -0.05 * weight)
		"follow":
			_set_pose_deg(pose, "pelvis", Vector3(-10.0, 21.0 * side * width * weight, -3.0 * side))
			_set_pose_deg(pose, "spine_01", Vector3(-12.0, 16.0 * side * width * weight, 3.0 * side))
			_set_pose_deg(pose, "chest", Vector3(-17.0, 29.0 * side * width * weight, 4.0 * side))
			_set_pose_deg(pose, "upper_arm_r", Vector3(102.0, 28.0 * side, -24.0 * side))
			_set_pose_deg(pose, "forearm_r", Vector3(-4.0, -9.0 * side, 7.0 * side))
			_set_pose_deg(pose, "upper_arm_l", Vector3(90.0, 16.0 * side, 23.0 * side))
			_set_pose_deg(pose, "forearm_l", Vector3(-10.0, 6.0 * side, -5.0 * side))
			_set_hammer_stance(pose, side, 1.12, heavy)
			pose["__pelvis_offset"] = Vector3(-0.02 * side, -0.07 * weight, -0.072 * weight)
		_:
			_set_pose_deg(pose, "pelvis", Vector3(4.0, 2.0 * side, 0.0))
			_set_pose_deg(pose, "spine_01", Vector3(5.0, 2.0 * side, 0.0))
			_set_pose_deg(pose, "chest", Vector3(7.0, 3.0 * side, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(28.0, 3.0 * side, 8.0 * side))
			_set_pose_deg(pose, "forearm_r", Vector3(-24.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(24.0, -2.0 * side, -8.0 * side))
			_set_pose_deg(pose, "forearm_l", Vector3(-26.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.025, -0.015)


func _build_hammer_slam_pose(pose: Dictionary, stage: String, finisher: bool) -> void:
	var weight: float = 1.16 if finisher else 1.0
	match stage:
		"windup":
			_set_pose_deg(pose, "pelvis", Vector3(10.0, -3.0, 0.0))
			_set_pose_deg(pose, "spine_01", Vector3(12.0, -2.0, 0.0))
			_set_pose_deg(pose, "spine_02", Vector3(14.0, -2.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(17.0, -2.0, 0.0))
			_set_pose_deg(pose, "head", Vector3(-8.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(126.0, -5.0, 12.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-42.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(116.0, 5.0, -12.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-48.0, 0.0, 0.0))
			_set_pose_deg(pose, "thigh_l", Vector3(-18.0, 0.0, -4.0))
			_set_pose_deg(pose, "thigh_r", Vector3(-18.0, 0.0, 4.0))
			_set_pose_deg(pose, "shin_l", Vector3(28.0, 0.0, 0.0))
			_set_pose_deg(pose, "shin_r", Vector3(28.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.105 * weight, 0.035)
		"contact":
			_set_pose_deg(pose, "pelvis", Vector3(-11.0, 2.0, 0.0))
			_set_pose_deg(pose, "spine_01", Vector3(-15.0, 2.0, 0.0))
			_set_pose_deg(pose, "spine_02", Vector3(-18.0, 1.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(-23.0, 1.0, 0.0))
			_set_pose_deg(pose, "head", Vector3(8.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(58.0, 4.0, 10.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-7.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(62.0, -4.0, -10.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-12.0, 0.0, 0.0))
			_set_pose_deg(pose, "thigh_l", Vector3(8.0, 0.0, -3.0))
			_set_pose_deg(pose, "thigh_r", Vector3(8.0, 0.0, 3.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.09 * weight, -0.07 * weight)
		"follow":
			_set_pose_deg(pose, "pelvis", Vector3(-14.0, 2.0, 0.0))
			_set_pose_deg(pose, "spine_01", Vector3(-18.0, 2.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(-27.0, 1.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(38.0, 5.0, 10.0))
			_set_pose_deg(pose, "forearm_r", Vector3(4.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(42.0, -5.0, -10.0))
			_set_pose_deg(pose, "forearm_l", Vector3(0.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.095 * weight, -0.085 * weight)
		_:
			_set_pose_deg(pose, "pelvis", Vector3(5.0, 0.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(8.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(24.0, 0.0, 7.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(22.0, 0.0, -7.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-22.0, 0.0, 0.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-22.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.03, -0.01)


func _build_hammer_rising_pose(pose: Dictionary, stage: String) -> void:
	match stage:
		"windup":
			_set_pose_deg(pose, "pelvis", Vector3(11.0, -8.0, 2.0))
			_set_pose_deg(pose, "spine_01", Vector3(12.0, -7.0, 2.0))
			_set_pose_deg(pose, "chest", Vector3(14.0, -10.0, 3.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(42.0, -18.0, 38.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-52.0, 8.0, -10.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(38.0, -8.0, -34.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-56.0, -6.0, 8.0))
			_set_pose_deg(pose, "thigh_l", Vector3(-24.0, 0.0, -4.0))
			_set_pose_deg(pose, "thigh_r", Vector3(-18.0, 0.0, 4.0))
			_set_pose_deg(pose, "shin_l", Vector3(34.0, 0.0, 0.0))
			_set_pose_deg(pose, "shin_r", Vector3(28.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.015, -0.105, 0.035)
		"contact":
			_set_pose_deg(pose, "pelvis", Vector3(-7.0, 10.0, -2.0))
			_set_pose_deg(pose, "spine_01", Vector3(-10.0, 8.0, -2.0))
			_set_pose_deg(pose, "chest", Vector3(-15.0, 13.0, -3.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(112.0, 14.0, -30.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-6.0, -7.0, 7.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(104.0, 7.0, 28.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-12.0, 5.0, -6.0))
			_set_pose_deg(pose, "thigh_l", Vector3(10.0, 0.0, -3.0))
			_set_pose_deg(pose, "thigh_r", Vector3(8.0, 0.0, 3.0))
			pose["__pelvis_offset"] = Vector3(-0.015, -0.03, -0.07)
		"follow":
			_set_pose_deg(pose, "pelvis", Vector3(-9.0, 14.0, -3.0))
			_set_pose_deg(pose, "chest", Vector3(-18.0, 18.0, -4.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(126.0, 19.0, -36.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(116.0, 10.0, 32.0))
			pose["__pelvis_offset"] = Vector3(-0.02, -0.025, -0.085)
		_:
			_set_pose_deg(pose, "pelvis", Vector3(4.0, 2.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(7.0, 3.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(26.0, 2.0, 8.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(24.0, -2.0, -8.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.025, -0.015)


func _set_hammer_stance(pose: Dictionary, side: float, phase: float, heavy: bool) -> void:
	var depth: float = 1.18 if heavy else 1.0
	var plant_right: bool = side > 0.0
	var planted: String = "thigh_r" if plant_right else "thigh_l"
	var driving: String = "thigh_l" if plant_right else "thigh_r"
	var planted_shin: String = "shin_r" if plant_right else "shin_l"
	var driving_shin: String = "shin_l" if plant_right else "shin_r"
	_set_pose_deg(pose, planted, Vector3(-13.0 * phase * depth, 0.0, 4.0 * side))
	_set_pose_deg(pose, driving, Vector3(16.0 * phase * depth, 0.0, -4.0 * side))
	_set_pose_deg(pose, planted_shin, Vector3(22.0 + maxf(phase, 0.0) * 5.0, 0.0, 0.0))
	_set_pose_deg(pose, driving_shin, Vector3(14.0 + maxf(-phase, 0.0) * 6.0, 0.0, 0.0))


func _build_hammer_dash_pose(pose: Dictionary, stage: String, heavy: bool) -> void:
	if heavy:
		_build_hammer_slam_pose(pose, stage, false)
		if stage in ["windup", "contact", "follow"]:
			_add_pose_deg(pose, "pelvis", Vector3(-2.0, -9.0, 0.0))
			_add_pose_deg(pose, "chest", Vector3(-4.0, -12.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.07, -0.12 if stage != "windup" else -0.02)
		return
	_build_hammer_sweep_pose(pose, stage, 1.0, false, false)
	if stage in ["contact", "follow"]:
		pose["__pelvis_offset"] = Vector3(-0.02, -0.045, -0.13)


func _build_hammer_aerial_pose(pose: Dictionary, stage: String, heavy: bool) -> void:
	if heavy:
		_build_hammer_slam_pose(pose, stage, true)
		if stage == "windup":
			pose["__pelvis_offset"] = Vector3(0.0, 0.015, 0.02)
		elif stage in ["contact", "follow"]:
			pose["__pelvis_offset"] = Vector3(0.0, -0.12, -0.04)
		return
	_build_hammer_sweep_pose(pose, stage, 1.0, false, false)
	if stage == "windup":
		pose["__pelvis_offset"] = Vector3(0.0, 0.02, 0.02)
	elif stage in ["contact", "follow"]:
		pose["__pelvis_offset"] = Vector3(-0.015, -0.02, -0.08)


func _build_lance_attack_pose(attack: WeaponAttackDefinition, stage: String) -> Dictionary:
	var pose: Dictionary = {}
	if attack == null:
		return pose
	if attack.extra_tags.has("dash_light"):
		_build_lance_dash_pose(pose, stage, false)
		return pose
	if attack.extra_tags.has("dash_heavy"):
		_build_lance_dash_pose(pose, stage, true)
		return pose
	if attack.extra_tags.has("aerial_light"):
		_build_lance_aerial_pose(pose, stage, false)
		return pose
	if attack.extra_tags.has("aerial_heavy"):
		_build_lance_aerial_pose(pose, stage, true)
		return pose

	var attack_id: String = attack.attack_id.to_lower()
	if attack.extra_tags.has("thrust") or attack.extra_tags.has("pierce") and not attack.extra_tags.has("sweep"):
		_build_lance_thrust_pose(pose, stage, attack.input_kind == "heavy", attack_id in ["spear_l2", "spear_h2"])
	else:
		_build_lance_sweep_pose(pose, stage, _attack_side(attack), attack.input_kind == "heavy", attack_id == "spear_h3")
	return pose


func _build_lance_thrust_pose(
	pose: Dictionary,
	stage: String,
	heavy: bool,
	driving: bool
) -> void:
	var weight: float = 1.12 if heavy else 1.0
	var drive: float = 1.14 if driving else 1.0
	match stage:
		"windup":
			_set_pose_deg(pose, "pelvis", Vector3(3.0, -7.0, 0.0))
			_set_pose_deg(pose, "spine_01", Vector3(2.0, -6.0, 0.0))
			_set_pose_deg(pose, "spine_02", Vector3(1.0, -7.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(0.0, -9.0, 0.0))
			_set_pose_deg(pose, "head", Vector3(0.0, 4.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(56.0, -12.0, 13.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-62.0, 5.0, -4.0))
			_set_pose_deg(pose, "hand_r", Vector3(-5.0, -3.0, 0.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(50.0, 10.0, -16.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-54.0, -4.0, 3.0))
			_set_pose_deg(pose, "hand_l", Vector3(-4.0, 3.0, 0.0))
			_set_lance_stance(pose, -1.0, heavy)
			pose["__pelvis_offset"] = Vector3(0.0, -0.035 * weight, 0.055)
		"contact":
			_set_pose_deg(pose, "pelvis", Vector3(-5.0, 7.0, 0.0))
			_set_pose_deg(pose, "spine_01", Vector3(-7.0, 5.0, 0.0))
			_set_pose_deg(pose, "spine_02", Vector3(-9.0, 5.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(-12.0, 5.0, 0.0))
			_set_pose_deg(pose, "head", Vector3(4.0, -2.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(94.0, 2.0, -5.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-5.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(84.0, -3.0, -10.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-16.0, 0.0, 0.0))
			_set_lance_stance(pose, 1.0, heavy)
			pose["__pelvis_offset"] = Vector3(0.0, -0.03, -0.105 * weight * drive)
		"follow":
			_set_pose_deg(pose, "pelvis", Vector3(-7.0, 9.0, 0.0))
			_set_pose_deg(pose, "spine_01", Vector3(-9.0, 7.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(-15.0, 7.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(102.0, 4.0, -6.0))
			_set_pose_deg(pose, "forearm_r", Vector3(3.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(90.0, -2.0, -11.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-8.0, 0.0, 0.0))
			_set_lance_stance(pose, 1.08, heavy)
			pose["__pelvis_offset"] = Vector3(0.0, -0.035, -0.13 * weight * drive)
		_:
			_set_pose_deg(pose, "pelvis", Vector3(2.0, 2.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(4.0, 2.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(23.0, 0.0, 4.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-20.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(21.0, 0.0, -5.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-22.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.018, -0.018)


func _build_lance_sweep_pose(
	pose: Dictionary,
	stage: String,
	side: float,
	heavy: bool,
	broad: bool
) -> void:
	var weight: float = 1.1 if heavy else 1.0
	var width: float = 1.16 if broad else 1.0
	match stage:
		"windup":
			_set_pose_deg(pose, "pelvis", Vector3(2.0, -12.0 * side * width, -2.0 * side))
			_set_pose_deg(pose, "spine_01", Vector3(-1.0, -9.0 * side * width, 2.0 * side))
			_set_pose_deg(pose, "chest", Vector3(-3.0, -17.0 * side * width, 3.0 * side))
			_set_pose_deg(pose, "upper_arm_r", Vector3(66.0, -16.0 * side, 22.0 * side))
			_set_pose_deg(pose, "forearm_r", Vector3(-42.0, 7.0 * side, -7.0 * side))
			_set_pose_deg(pose, "upper_arm_l", Vector3(54.0, -5.0 * side, -20.0 * side))
			_set_pose_deg(pose, "forearm_l", Vector3(-48.0, -5.0 * side, 5.0 * side))
			_set_lance_stance(pose, -1.0, heavy)
			pose["__pelvis_offset"] = Vector3(0.014 * side, -0.04, 0.025)
		"contact":
			_set_pose_deg(pose, "pelvis", Vector3(-3.0, 13.0 * side * width * weight, 2.0 * side))
			_set_pose_deg(pose, "spine_01", Vector3(-5.0, 10.0 * side * width * weight, -2.0 * side))
			_set_pose_deg(pose, "chest", Vector3(-7.0, 22.0 * side * width * weight, -3.0 * side))
			_set_pose_deg(pose, "upper_arm_r", Vector3(88.0, 24.0 * side, -19.0 * side))
			_set_pose_deg(pose, "forearm_r", Vector3(-16.0, -9.0 * side, 6.0 * side))
			_set_pose_deg(pose, "upper_arm_l", Vector3(76.0, 12.0 * side, 18.0 * side))
			_set_pose_deg(pose, "forearm_l", Vector3(-24.0, 6.0 * side, -5.0 * side))
			_set_lance_stance(pose, 1.0, heavy)
			pose["__pelvis_offset"] = Vector3(-0.015 * side, -0.045, -0.05 * weight)
		"follow":
			_set_pose_deg(pose, "pelvis", Vector3(-5.0, 18.0 * side * width * weight, 3.0 * side))
			_set_pose_deg(pose, "chest", Vector3(-10.0, 29.0 * side * width * weight, -4.0 * side))
			_set_pose_deg(pose, "upper_arm_r", Vector3(96.0, 30.0 * side, -22.0 * side))
			_set_pose_deg(pose, "upper_arm_l", Vector3(84.0, 17.0 * side, 20.0 * side))
			_set_lance_stance(pose, 1.08, heavy)
			pose["__pelvis_offset"] = Vector3(-0.018 * side, -0.05, -0.065 * weight)
		_:
			_set_pose_deg(pose, "pelvis", Vector3(2.0, 2.0 * side, 0.0))
			_set_pose_deg(pose, "chest", Vector3(4.0, 3.0 * side, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(22.0, 2.0 * side, 5.0 * side))
			_set_pose_deg(pose, "upper_arm_l", Vector3(20.0, -2.0 * side, -5.0 * side))
			pose["__pelvis_offset"] = Vector3(0.0, -0.02, -0.012)


func _set_lance_stance(pose: Dictionary, phase: float, heavy: bool) -> void:
	var depth: float = 1.16 if heavy else 1.0
	_set_pose_deg(pose, "thigh_l", Vector3(18.0 * phase * depth, 0.0, -3.0))
	_set_pose_deg(pose, "thigh_r", Vector3(-22.0 * phase * depth, 0.0, 3.0))
	_set_pose_deg(pose, "shin_l", Vector3(13.0 + maxf(phase, 0.0) * 4.0, 0.0, 0.0))
	_set_pose_deg(pose, "shin_r", Vector3(22.0 + maxf(-phase, 0.0) * 5.0, 0.0, 0.0))


func _build_lance_dash_pose(pose: Dictionary, stage: String, heavy: bool) -> void:
	_build_lance_thrust_pose(pose, stage, heavy, true)
	if stage == "windup":
		pose["__pelvis_offset"] = Vector3(0.0, -0.045, 0.04)
	elif stage in ["contact", "follow"]:
		pose["__pelvis_offset"] = Vector3(0.0, -0.035, -0.18 if heavy else -0.15)


func _build_lance_aerial_pose(pose: Dictionary, stage: String, heavy: bool) -> void:
	if heavy:
		_build_lance_thrust_pose(pose, stage, true, true)
		_add_pose_deg(pose, "chest", Vector3(16.0, 0.0, 0.0))
		_add_pose_deg(pose, "upper_arm_r", Vector3(-10.0, 0.0, 0.0))
		_add_pose_deg(pose, "upper_arm_l", Vector3(-8.0, 0.0, 0.0))
		if stage in ["contact", "follow"]:
			pose["__pelvis_offset"] = Vector3(0.0, -0.1, -0.05)
		return
	_build_lance_thrust_pose(pose, stage, false, true)
	if stage in ["contact", "follow"]:
		pose["__pelvis_offset"] = Vector3(0.0, -0.015, -0.11)


func _build_dagger_attack_pose(attack: WeaponAttackDefinition, stage: String) -> Dictionary:
	var pose: Dictionary = {}
	if attack == null:
		return pose
	if attack.extra_tags.has("dash_light"):
		_build_dagger_dash_pose(pose, stage, false)
		return pose
	if attack.extra_tags.has("dash_heavy"):
		_build_dagger_dash_pose(pose, stage, true)
		return pose
	if attack.extra_tags.has("aerial_light"):
		_build_dagger_aerial_pose(pose, stage, false)
		return pose
	if attack.extra_tags.has("aerial_heavy"):
		_build_dagger_aerial_pose(pose, stage, true)
		return pose

	var attack_id: String = attack.attack_id.to_lower()
	var index: int = _dagger_attack_index(attack_id)
	if attack.input_kind == "heavy":
		_build_dagger_heavy_pose(pose, stage, index)
	else:
		_build_dagger_light_pose(pose, stage, index)
	return pose


func _dagger_attack_index(attack_id: String) -> int:
	for index: int in range(4):
		if attack_id.ends_with("l" + str(index + 1)) or attack_id.ends_with("h" + str(index)):
			return index
	return 0


func _build_dagger_light_pose(pose: Dictionary, stage: String, index: int) -> void:
	var right_leads: bool = index % 2 == 0
	var side: float = 1.0 if right_leads else -1.0
	match stage:
		"windup":
			_set_pose_deg(pose, "pelvis", Vector3(-5.0, -8.0 * side, -2.0 * side))
			_set_pose_deg(pose, "spine_01", Vector3(-7.0, -6.0 * side, 2.0 * side))
			_set_pose_deg(pose, "chest", Vector3(-9.0, -10.0 * side, 3.0 * side))
			_set_pose_deg(pose, "head", Vector3(2.0, 5.0 * side, -1.0 * side))
			_set_pose_deg(pose, "upper_arm_r", Vector3(43.0 if right_leads else 24.0, -13.0 * side, 20.0 * side))
			_set_pose_deg(pose, "forearm_r", Vector3(-54.0 if right_leads else -30.0, 6.0 * side, -5.0 * side))
			_set_pose_deg(pose, "upper_arm_l", Vector3(24.0 if right_leads else 43.0, -10.0 * side, -20.0 * side))
			_set_pose_deg(pose, "forearm_l", Vector3(-30.0 if right_leads else -54.0, -5.0 * side, 5.0 * side))
			_set_dagger_stance(pose, side, -1.0)
			pose["__pelvis_offset"] = Vector3(0.012 * side, -0.05, 0.035)
		"contact":
			_set_pose_deg(pose, "pelvis", Vector3(-9.0, 9.0 * side, 2.0 * side))
			_set_pose_deg(pose, "spine_01", Vector3(-11.0, 7.0 * side, -2.0 * side))
			_set_pose_deg(pose, "chest", Vector3(-14.0, 12.0 * side, -3.0 * side))
			_set_pose_deg(pose, "upper_arm_r", Vector3(90.0 if right_leads else 58.0, 10.0 * side, -12.0 * side))
			_set_pose_deg(pose, "forearm_r", Vector3(-12.0 if right_leads else -34.0, -4.0 * side, 4.0 * side))
			_set_pose_deg(pose, "upper_arm_l", Vector3(58.0 if right_leads else 90.0, 9.0 * side, 12.0 * side))
			_set_pose_deg(pose, "forearm_l", Vector3(-34.0 if right_leads else -12.0, 4.0 * side, -4.0 * side))
			_set_dagger_stance(pose, side, 1.0)
			pose["__pelvis_offset"] = Vector3(-0.012 * side, -0.045, -0.075)
		"follow":
			_set_pose_deg(pose, "pelvis", Vector3(-10.0, 12.0 * side, 2.0 * side))
			_set_pose_deg(pose, "chest", Vector3(-15.0, 16.0 * side, -3.0 * side))
			_set_pose_deg(pose, "upper_arm_r", Vector3(96.0 if right_leads else 62.0, 13.0 * side, -14.0 * side))
			_set_pose_deg(pose, "upper_arm_l", Vector3(62.0 if right_leads else 96.0, 12.0 * side, 14.0 * side))
			_set_dagger_stance(pose, side, 1.08)
			pose["__pelvis_offset"] = Vector3(-0.015 * side, -0.045, -0.09)
		_:
			_set_pose_deg(pose, "pelvis", Vector3(-2.0, 2.0 * side, 0.0))
			_set_pose_deg(pose, "chest", Vector3(-3.0, 3.0 * side, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(20.0, 0.0, 7.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(20.0, 0.0, -7.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-26.0, 0.0, 0.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-26.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.025, -0.012)


func _build_dagger_heavy_pose(pose: Dictionary, stage: String, index: int) -> void:
	match index:
		0, 2:
			_build_dagger_pierce_pose(pose, stage, index >= 2)
		1:
			_build_dagger_step_pose(pose, stage)
		_:
			_build_dagger_cross_pose(pose, stage, true)


func _build_dagger_pierce_pose(pose: Dictionary, stage: String, committed: bool) -> void:
	var weight: float = 1.12 if committed else 1.0
	match stage:
		"windup":
			_set_pose_deg(pose, "pelvis", Vector3(-5.0, -5.0, 0.0))
			_set_pose_deg(pose, "spine_01", Vector3(-6.0, -4.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(-8.0, -6.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(48.0, -9.0, 14.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-58.0, 4.0, -3.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(48.0, 9.0, -14.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-58.0, -4.0, 3.0))
			_set_dagger_stance(pose, 1.0, -1.0)
			pose["__pelvis_offset"] = Vector3(0.0, -0.055, 0.045)
		"contact":
			_set_pose_deg(pose, "pelvis", Vector3(-10.0, 4.0, 0.0))
			_set_pose_deg(pose, "spine_01", Vector3(-12.0, 3.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(-16.0, 4.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(92.0, 2.0, -7.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-8.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(90.0, -2.0, 7.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-10.0, 0.0, 0.0))
			_set_dagger_stance(pose, 1.0, 1.0)
			pose["__pelvis_offset"] = Vector3(0.0, -0.045, -0.13 * weight)
		"follow":
			_set_pose_deg(pose, "pelvis", Vector3(-12.0, 5.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(-18.0, 5.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(98.0, 3.0, -8.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(96.0, -3.0, 8.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.04, -0.15 * weight)
		_:
			_set_pose_deg(pose, "pelvis", Vector3(-2.0, 1.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(-3.0, 2.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(21.0, 0.0, 7.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(21.0, 0.0, -7.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.025, -0.015)


func _build_dagger_step_pose(pose: Dictionary, stage: String) -> void:
	_build_dagger_light_pose(pose, stage, 1)
	if stage == "windup":
		_add_pose_deg(pose, "pelvis", Vector3(-3.0, -9.0, -5.0))
		pose["__pelvis_offset"] = Vector3(0.06, -0.055, 0.02)
	elif stage in ["contact", "follow"]:
		_add_pose_deg(pose, "chest", Vector3(-3.0, 8.0, 4.0))
		pose["__pelvis_offset"] = Vector3(-0.06, -0.04, -0.1)


func _build_dagger_cross_pose(pose: Dictionary, stage: String, heavy: bool) -> void:
	var weight: float = 1.12 if heavy else 1.0
	match stage:
		"windup":
			_set_pose_deg(pose, "pelvis", Vector3(-5.0, 0.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(-8.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(42.0, -18.0, 24.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-54.0, 7.0, -7.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(42.0, 18.0, -24.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-54.0, -7.0, 7.0))
			_set_dagger_stance(pose, 1.0, -1.0)
			pose["__pelvis_offset"] = Vector3(0.0, -0.055, 0.03)
		"contact":
			_set_pose_deg(pose, "pelvis", Vector3(-9.0, 0.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(-14.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(86.0, 18.0, -18.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-15.0, -6.0, 6.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(86.0, -18.0, 18.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-15.0, 6.0, -6.0))
			_set_dagger_stance(pose, 1.0, 1.0)
			pose["__pelvis_offset"] = Vector3(0.0, -0.045, -0.1 * weight)
		"follow":
			_set_pose_deg(pose, "pelvis", Vector3(-11.0, 0.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(-16.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(94.0, 22.0, -20.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(94.0, -22.0, 20.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.04, -0.12 * weight)
		_:
			_set_pose_deg(pose, "pelvis", Vector3(-2.0, 0.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(-3.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(20.0, 0.0, 7.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(20.0, 0.0, -7.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.025, -0.012)


func _set_dagger_stance(pose: Dictionary, side: float, phase: float) -> void:
	_set_pose_deg(pose, "thigh_l", Vector3(13.0 * phase, 0.0, -5.0 - side * 2.0))
	_set_pose_deg(pose, "thigh_r", Vector3(-16.0 * phase, 0.0, 5.0 - side * 2.0))
	_set_pose_deg(pose, "shin_l", Vector3(20.0 + maxf(phase, 0.0) * 5.0, 0.0, 0.0))
	_set_pose_deg(pose, "shin_r", Vector3(24.0 + maxf(-phase, 0.0) * 5.0, 0.0, 0.0))


func _build_dagger_dash_pose(pose: Dictionary, stage: String, heavy: bool) -> void:
	if heavy:
		_build_dagger_pierce_pose(pose, stage, true)
	else:
		_build_dagger_light_pose(pose, stage, 0)
	if stage == "windup":
		pose["__pelvis_offset"] = Vector3(0.0, -0.055, 0.015)
	elif stage in ["contact", "follow"]:
		pose["__pelvis_offset"] = Vector3(0.0, -0.04, -0.16 if heavy else -0.13)


func _build_dagger_aerial_pose(pose: Dictionary, stage: String, heavy: bool) -> void:
	if heavy:
		_build_dagger_cross_pose(pose, stage, true)
		if stage in ["contact", "follow"]:
			_add_pose_deg(pose, "chest", Vector3(18.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.095, -0.04)
		return
	_build_dagger_cross_pose(pose, stage, false)
	if stage == "windup":
		pose["__pelvis_offset"] = Vector3(0.0, 0.018, 0.02)
	elif stage in ["contact", "follow"]:
		pose["__pelvis_offset"] = Vector3(0.0, -0.02, -0.08)


func _add_pose_deg(pose: Dictionary, bone_name: String, degrees_value: Vector3) -> void:
	var current: Vector3 = pose.get(bone_name, Vector3.ZERO) as Vector3
	pose[bone_name] = current + _degrees_to_radians(degrees_value)


func _update_offhand_dagger() -> void:
	var daggers_active: bool = (
		_get_equipped_weapon_class() == "daggers"
		and skeleton != null
		and bones.has("hand_l")
	)
	if not daggers_active:
		if offhand_dagger_root != null:
			offhand_dagger_root.visible = false
		return

	_ensure_offhand_dagger()
	if offhand_dagger_root == null:
		return
	offhand_dagger_root.visible = true
	var hand_pose: Transform3D = skeleton.get_bone_global_pose(int(bones["hand_l"]))
	var socket_basis: Basis = Basis.from_euler(Vector3(0.0, 0.0, deg_to_rad(4.0)))
	offhand_dagger_root.transform = hand_pose * Transform3D(
		socket_basis,
		Vector3(0.0, -0.025, -0.015)
	)
	_hide_runtime_proxy_offhand()


func _ensure_offhand_dagger() -> void:
	if weapon_controller == null or weapon_controller.equipped_weapon == null:
		return
	var weapon: WeaponDefinition = weapon_controller.equipped_weapon
	var signature: String = str(weapon.visual_primary_color) + str(weapon.visual_accent_color)
	if offhand_dagger_root != null and signature == offhand_dagger_signature:
		return
	if offhand_dagger_root != null:
		offhand_dagger_root.queue_free()
	offhand_dagger_root = Node3D.new()
	offhand_dagger_root.name = "SkeletalOffhandDagger"
	add_child(offhand_dagger_root)
	offhand_dagger_signature = signature

	var grip := MeshInstance3D.new()
	grip.name = "Grip"
	var grip_mesh := BoxMesh.new()
	grip_mesh.size = Vector3(0.075, 0.075, 0.28)
	grip.mesh = grip_mesh
	grip.position = Vector3(0.0, 0.0, 0.12)
	grip.material_override = _dagger_material(weapon.visual_secondary_color, false)
	offhand_dagger_root.add_child(grip)

	var blade := MeshInstance3D.new()
	blade.name = "Blade"
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.075, 0.045, 0.72)
	blade.mesh = blade_mesh
	blade.position = Vector3(0.0, 0.0, -0.38)
	blade.rotation_degrees.z = -6.0
	blade.material_override = _dagger_material(weapon.visual_accent_color, true)
	offhand_dagger_root.add_child(blade)


func _hide_runtime_proxy_offhand() -> void:
	if weapon_controller == null or weapon_controller.runtime_weapon_rig == null:
		return
	for child_name: String in ["LeftGrip", "LeftBlade"]:
		var child: Node3D = weapon_controller.runtime_weapon_rig.get_node_or_null(child_name) as Node3D
		if child != null:
			child.visible = false


func _dagger_material(color: Color, emissive: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.48
	material.roughness = 0.32
	if emissive:
		material.emission_enabled = true
		material.emission = Color(color.r, color.g, color.b, 1.0)
		material.emission_energy_multiplier = 0.6
	return material


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["weapon_language_v2"] = true
	data["authored_language_classes"] = ["sword", "hammer", "lance", "daggers"]
	data["hammer_language"] = true
	data["lance_language"] = true
	data["dagger_language"] = true
	data["dagger_offhand_socket"] = offhand_dagger_root != null
	return data
