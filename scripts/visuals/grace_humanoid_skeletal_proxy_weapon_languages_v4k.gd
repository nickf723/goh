extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_weapon_languages_v4j.gd"

# V4K is the focused Staff language. Ordinary attacks stay near chest and waist
# height; the grounded charges own a returning toss and a planted front guard;
# Aerial Heavy owns the descending, bending, timing-based pole vault.


func _build_attack_stage_pose(
	attack: WeaponAttackDefinition,
	stage: String
) -> Dictionary:
	if _get_equipped_weapon_class() != "staff" or attack == null:
		return super._build_attack_stage_pose(attack, stage)
	if attack.extra_tags.has("staff_throw_charge"):
		return _build_staff_throw_ready_pose()
	if attack.extra_tags.has("staff_returning_throw"):
		return _build_staff_throw_release_pose(stage)
	if attack.extra_tags.has("staff_angel_ring"):
		return _build_staff_angel_ring_pose()
	if attack.extra_tags.has("staff_angel_ring_release"):
		return _build_staff_ring_release_pose(stage)
	if attack.extra_tags.has("staff_vault_descent"):
		return _build_staff_vault_descent_pose()
	if attack.extra_tags.has("staff_vault_bend"):
		return _build_staff_vault_bend_pose()
	if attack.extra_tags.has("staff_vault_launch"):
		return _build_staff_vault_launch_pose(stage)
	if attack.extra_tags.has("staff_vault_overheld_drop"):
		return _build_staff_vault_drop_pose(stage)
	return _build_staff_normal_attack_pose(attack, stage)


func _build_staff_normal_attack_pose(
	attack: WeaponAttackDefinition,
	stage: String
) -> Dictionary:
	var pose: Dictionary = {}
	match attack.attack_id:
		"staff_l1":
			_build_staff_sweep_pose(pose, stage, 1.0, false)
		"staff_l2":
			_build_staff_sweep_pose(pose, stage, -1.0, false)
		"staff_l3":
			_build_staff_thrust_pose_v2(pose, stage, false)
		"staff_h0":
			_build_staff_thrust_pose_v2(pose, stage, true)
		"staff_h1":
			_build_staff_sweep_pose(pose, stage, 1.0, true)
		"staff_h2":
			_build_staff_sweep_pose(pose, stage, -1.0, true)
		"staff_h3":
			_build_staff_spinning_ward_pose(pose, stage)
		_:
			_build_staff_sweep_pose(pose, stage, _attack_side(attack), attack.input_kind == "heavy")
	return pose


func _build_staff_sweep_pose(
	pose: Dictionary,
	stage: String,
	side: float,
	heavy: bool
) -> void:
	var weight: float = 1.16 if heavy else 1.0
	match stage:
		"windup":
			_set_pose_deg(pose, "pelvis", Vector3(5.0, -13.0 * side * weight, -3.0 * side))
			_set_pose_deg(pose, "spine_01", Vector3(3.0, -8.0 * side, 2.0 * side))
			_set_pose_deg(pose, "spine_02", Vector3(2.0, -11.0 * side, 3.0 * side))
			_set_pose_deg(pose, "chest", Vector3(1.0, -16.0 * side, 4.0 * side))
			_set_pose_deg(pose, "head", Vector3(-2.0, 7.0 * side, -1.0 * side))
			_set_pose_deg(pose, "upper_arm_r", Vector3(50.0, -16.0 * side, 20.0 * side))
			_set_pose_deg(pose, "forearm_r", Vector3(-48.0, 7.0 * side, -5.0 * side))
			_set_pose_deg(pose, "upper_arm_l", Vector3(44.0, 12.0 * side, -18.0 * side))
			_set_pose_deg(pose, "forearm_l", Vector3(-46.0, -5.0 * side, 4.0 * side))
			_set_pose_deg(pose, "thigh_l", Vector3(-12.0 * weight, 0.0, -4.0))
			_set_pose_deg(pose, "thigh_r", Vector3(14.0 * weight, 0.0, 4.0))
			_set_pose_deg(pose, "shin_l", Vector3(20.0 * weight, 0.0, 0.0))
			_set_pose_deg(pose, "shin_r", Vector3(10.0 * weight, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.018 * side, -0.052 * weight, 0.018)
		"contact":
			_set_pose_deg(pose, "pelvis", Vector3(-3.0, 17.0 * side * weight, 3.0 * side))
			_set_pose_deg(pose, "spine_01", Vector3(-4.0, 11.0 * side, -2.0 * side))
			_set_pose_deg(pose, "spine_02", Vector3(-5.0, 16.0 * side, -3.0 * side))
			_set_pose_deg(pose, "chest", Vector3(-6.0, 23.0 * side, -4.0 * side))
			_set_pose_deg(pose, "head", Vector3(2.0, -8.0 * side, 1.0 * side))
			_set_pose_deg(pose, "upper_arm_r", Vector3(78.0, 20.0 * side, -18.0 * side))
			_set_pose_deg(pose, "forearm_r", Vector3(-20.0, -8.0 * side, 5.0 * side))
			_set_pose_deg(pose, "upper_arm_l", Vector3(70.0, -17.0 * side, 17.0 * side))
			_set_pose_deg(pose, "forearm_l", Vector3(-24.0, 7.0 * side, -4.0 * side))
			_set_pose_deg(pose, "thigh_l", Vector3(12.0 * weight, 0.0, -4.0))
			_set_pose_deg(pose, "thigh_r", Vector3(-16.0 * weight, 0.0, 4.0))
			_set_pose_deg(pose, "shin_l", Vector3(10.0 * weight, 0.0, 0.0))
			_set_pose_deg(pose, "shin_r", Vector3(22.0 * weight, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(-0.02 * side, -0.058 * weight, -0.062 * weight)
		"follow":
			_set_pose_deg(pose, "pelvis", Vector3(-5.0, 23.0 * side * weight, 4.0 * side))
			_set_pose_deg(pose, "chest", Vector3(-8.0, 31.0 * side, -5.0 * side))
			_set_pose_deg(pose, "upper_arm_r", Vector3(88.0, 28.0 * side, -22.0 * side))
			_set_pose_deg(pose, "forearm_r", Vector3(-10.0, -10.0 * side, 7.0 * side))
			_set_pose_deg(pose, "upper_arm_l", Vector3(80.0, -22.0 * side, 21.0 * side))
			_set_pose_deg(pose, "forearm_l", Vector3(-14.0, 9.0 * side, -6.0 * side))
			pose["__pelvis_offset"] = Vector3(-0.024 * side, -0.052 * weight, -0.082 * weight)
		_:
			_set_pose_deg(pose, "pelvis", Vector3(2.0, 3.0 * side, 0.0))
			_set_pose_deg(pose, "chest", Vector3(3.0, 5.0 * side, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(28.0, 3.0 * side, 9.0 * side))
			_set_pose_deg(pose, "forearm_r", Vector3(-28.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(26.0, -3.0 * side, -9.0 * side))
			_set_pose_deg(pose, "forearm_l", Vector3(-30.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.025, -0.014)


func _build_staff_thrust_pose_v2(
	pose: Dictionary,
	stage: String,
	heavy: bool
) -> void:
	var weight: float = 1.18 if heavy else 1.0
	match stage:
		"windup":
			_set_pose_deg(pose, "pelvis", Vector3(8.0, -5.0, 0.0))
			_set_pose_deg(pose, "spine_01", Vector3(6.0, -4.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(3.0, -7.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(48.0, -12.0, 16.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-62.0, 5.0, -4.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(46.0, 10.0, -16.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-58.0, -4.0, 4.0))
			_set_pose_deg(pose, "thigh_l", Vector3(-17.0 * weight, 0.0, -4.0))
			_set_pose_deg(pose, "thigh_r", Vector3(22.0 * weight, 0.0, 4.0))
			_set_pose_deg(pose, "shin_l", Vector3(20.0 * weight, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.052 * weight, 0.06)
		"contact":
			_set_pose_deg(pose, "pelvis", Vector3(-7.0, 6.0, 0.0))
			_set_pose_deg(pose, "spine_01", Vector3(-9.0, 5.0, 0.0))
			_set_pose_deg(pose, "spine_02", Vector3(-11.0, 5.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(-14.0, 5.0, 0.0))
			_set_pose_deg(pose, "head", Vector3(5.0, -2.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(82.0, 2.0, -7.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-8.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(76.0, -2.0, 7.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-11.0, 0.0, 0.0))
			_set_pose_deg(pose, "thigh_l", Vector3(20.0 * weight, 0.0, -3.0))
			_set_pose_deg(pose, "thigh_r", Vector3(-22.0 * weight, 0.0, 3.0))
			_set_pose_deg(pose, "shin_r", Vector3(24.0 * weight, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.045 * weight, -0.105 * weight)
		"follow":
			_set_pose_deg(pose, "pelvis", Vector3(-8.0, 8.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(-16.0, 7.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(88.0, 3.0, -8.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-3.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(82.0, -3.0, 8.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-6.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.042 * weight, -0.13 * weight)
		_:
			_set_pose_deg(pose, "pelvis", Vector3(2.0, 0.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(3.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(30.0, 1.0, 9.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-30.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(28.0, -1.0, -9.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-32.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.025, -0.018)


func _build_staff_spinning_ward_pose(
	pose: Dictionary,
	stage: String
) -> void:
	match stage:
		"windup":
			_set_pose_deg(pose, "pelvis", Vector3(7.0, -16.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(4.0, -20.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(56.0, -18.0, 20.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-42.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(52.0, 18.0, -20.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-46.0, 0.0, 0.0))
			_set_pose_deg(pose, "thigh_l", Vector3(-20.0, 0.0, -8.0))
			_set_pose_deg(pose, "thigh_r", Vector3(-18.0, 0.0, 8.0))
			_set_pose_deg(pose, "shin_l", Vector3(34.0, 0.0, 0.0))
			_set_pose_deg(pose, "shin_r", Vector3(32.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.095, 0.01)
		"contact":
			_set_pose_deg(pose, "pelvis", Vector3(4.0, 22.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(2.0, 28.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(76.0, 22.0, -18.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-18.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(72.0, -22.0, 18.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-22.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.09, -0.045)
		"follow":
			_set_pose_deg(pose, "pelvis", Vector3(5.0, -24.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(3.0, -31.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(78.0, -24.0, 18.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-16.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(74.0, 24.0, -18.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-20.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.085, -0.06)
		_:
			_set_pose_deg(pose, "pelvis", Vector3(2.0, 0.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(3.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(30.0, 0.0, 9.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-30.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(28.0, 0.0, -9.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-32.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.028, -0.016)


func _build_staff_throw_ready_pose() -> Dictionary:
	var pose: Dictionary = {}
	_set_pose_deg(pose, "pelvis", Vector3(6.0, -12.0, -3.0))
	_set_pose_deg(pose, "spine_01", Vector3(4.0, -7.0, 2.0))
	_set_pose_deg(pose, "spine_02", Vector3(2.0, -10.0, 3.0))
	_set_pose_deg(pose, "chest", Vector3(0.0, -15.0, 4.0))
	_set_pose_deg(pose, "head", Vector3(-2.0, 8.0, -1.0))
	_set_pose_deg(pose, "upper_arm_r", Vector3(46.0, -18.0, 24.0))
	_set_pose_deg(pose, "forearm_r", Vector3(-56.0, 8.0, -6.0))
	_set_pose_deg(pose, "upper_arm_l", Vector3(34.0, 12.0, -22.0))
	_set_pose_deg(pose, "forearm_l", Vector3(-44.0, -5.0, 5.0))
	_set_pose_deg(pose, "thigh_l", Vector3(-16.0, 0.0, -6.0))
	_set_pose_deg(pose, "thigh_r", Vector3(-10.0, 0.0, 6.0))
	_set_pose_deg(pose, "shin_l", Vector3(28.0, 0.0, 0.0))
	_set_pose_deg(pose, "shin_r", Vector3(22.0, 0.0, 0.0))
	pose["__pelvis_offset"] = Vector3(0.018, -0.075, 0.018)
	return pose


func _build_staff_throw_release_pose(stage: String) -> Dictionary:
	if stage == "windup":
		return _build_staff_throw_ready_pose()
	var pose: Dictionary = {}
	match stage:
		"contact":
			_set_pose_deg(pose, "pelvis", Vector3(-5.0, 18.0, 3.0))
			_set_pose_deg(pose, "chest", Vector3(-9.0, 24.0, -4.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(90.0, 10.0, -12.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-4.0, -8.0, 4.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(34.0, -12.0, 16.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-20.0, 5.0, -3.0))
			pose["__pelvis_offset"] = Vector3(-0.02, -0.055, -0.09)
		"follow":
			_set_pose_deg(pose, "pelvis", Vector3(-6.0, 24.0, 4.0))
			_set_pose_deg(pose, "chest", Vector3(-11.0, 31.0, -5.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(102.0, 18.0, -18.0))
			_set_pose_deg(pose, "forearm_r", Vector3(8.0, -12.0, 6.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(22.0, -8.0, 12.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-16.0, 3.0, -2.0))
			pose["__pelvis_offset"] = Vector3(-0.025, -0.05, -0.12)
		_:
			_set_pose_deg(pose, "pelvis", Vector3(2.0, 0.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(3.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(24.0, 0.0, 8.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-24.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(20.0, 0.0, -8.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-24.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.025, -0.015)
	return pose


func _build_staff_angel_ring_pose() -> Dictionary:
	var pose: Dictionary = {}
	_set_pose_deg(pose, "pelvis", Vector3(8.0, 0.0, 0.0))
	_set_pose_deg(pose, "spine_01", Vector3(4.0, 0.0, 0.0))
	_set_pose_deg(pose, "spine_02", Vector3(1.0, 0.0, 0.0))
	_set_pose_deg(pose, "chest", Vector3(-2.0, 0.0, 0.0))
	_set_pose_deg(pose, "head", Vector3(1.0, 0.0, 0.0))
	_set_pose_deg(pose, "upper_arm_r", Vector3(72.0, -4.0, 12.0))
	_set_pose_deg(pose, "forearm_r", Vector3(-22.0, 0.0, 0.0))
	_set_pose_deg(pose, "upper_arm_l", Vector3(68.0, 4.0, -12.0))
	_set_pose_deg(pose, "forearm_l", Vector3(-26.0, 0.0, 0.0))
	_set_pose_deg(pose, "thigh_l", Vector3(-25.0, 0.0, -12.0))
	_set_pose_deg(pose, "thigh_r", Vector3(-25.0, 0.0, 12.0))
	_set_pose_deg(pose, "shin_l", Vector3(43.0, 0.0, 0.0))
	_set_pose_deg(pose, "shin_r", Vector3(43.0, 0.0, 0.0))
	pose["__pelvis_offset"] = Vector3(0.0, -0.13, -0.025)
	return pose


func _build_staff_ring_release_pose(stage: String) -> Dictionary:
	if stage == "windup":
		return _build_staff_angel_ring_pose()
	var pose: Dictionary = _build_staff_angel_ring_pose()
	if stage in ["contact", "follow"]:
		_add_pose_deg(pose, "pelvis", Vector3(-4.0, 0.0, 0.0))
		_add_pose_deg(pose, "chest", Vector3(-9.0, 0.0, 0.0))
		_add_pose_deg(pose, "upper_arm_r", Vector3(13.0, 0.0, 0.0))
		_add_pose_deg(pose, "forearm_r", Vector3(14.0, 0.0, 0.0))
		_add_pose_deg(pose, "upper_arm_l", Vector3(13.0, 0.0, 0.0))
		_add_pose_deg(pose, "forearm_l", Vector3(14.0, 0.0, 0.0))
		pose["__pelvis_offset"] = Vector3(0.0, -0.12, -0.09)
	return pose


func _build_staff_vault_descent_pose() -> Dictionary:
	var pose: Dictionary = {}
	_set_pose_deg(pose, "pelvis", Vector3(18.0, 0.0, 0.0))
	_set_pose_deg(pose, "spine_01", Vector3(14.0, 0.0, 0.0))
	_set_pose_deg(pose, "spine_02", Vector3(10.0, 0.0, 0.0))
	_set_pose_deg(pose, "chest", Vector3(6.0, 0.0, 0.0))
	_set_pose_deg(pose, "head", Vector3(-7.0, 0.0, 0.0))
	_set_pose_deg(pose, "upper_arm_r", Vector3(88.0, -4.0, 10.0))
	_set_pose_deg(pose, "forearm_r", Vector3(-8.0, 0.0, 0.0))
	_set_pose_deg(pose, "upper_arm_l", Vector3(84.0, 4.0, -10.0))
	_set_pose_deg(pose, "forearm_l", Vector3(-12.0, 0.0, 0.0))
	_set_pose_deg(pose, "thigh_l", Vector3(22.0, 0.0, -7.0))
	_set_pose_deg(pose, "thigh_r", Vector3(16.0, 0.0, 7.0))
	_set_pose_deg(pose, "shin_l", Vector3(-22.0, 0.0, 0.0))
	_set_pose_deg(pose, "shin_r", Vector3(-17.0, 0.0, 0.0))
	pose["__pelvis_offset"] = Vector3(0.0, 0.015, -0.12)
	return pose


func _build_staff_vault_bend_pose() -> Dictionary:
	var pose: Dictionary = {}
	var bend: float = 0.0
	if weapon_controller != null and weapon_controller.has_method("get_staff_vault_bend_ratio"):
		bend = clampf(float(weapon_controller.call("get_staff_vault_bend_ratio")), 0.0, 1.0)
	_set_pose_deg(pose, "pelvis", Vector3(lerpf(18.0, -24.0, bend), 0.0, lerpf(0.0, -7.0, bend)))
	_set_pose_deg(pose, "spine_01", Vector3(lerpf(14.0, -19.0, bend), 0.0, 0.0))
	_set_pose_deg(pose, "spine_02", Vector3(lerpf(10.0, -14.0, bend), 0.0, 0.0))
	_set_pose_deg(pose, "chest", Vector3(lerpf(6.0, -10.0, bend), 0.0, 0.0))
	_set_pose_deg(pose, "head", Vector3(lerpf(-7.0, 5.0, bend), 0.0, 0.0))
	_set_pose_deg(pose, "upper_arm_r", Vector3(lerpf(88.0, 82.0, bend), -4.0, 10.0))
	_set_pose_deg(pose, "forearm_r", Vector3(lerpf(-8.0, -2.0, bend), 0.0, 0.0))
	_set_pose_deg(pose, "upper_arm_l", Vector3(lerpf(84.0, 78.0, bend), 4.0, -10.0))
	_set_pose_deg(pose, "forearm_l", Vector3(lerpf(-12.0, -5.0, bend), 0.0, 0.0))
	_set_pose_deg(pose, "thigh_l", Vector3(lerpf(-18.0, 42.0, bend), 0.0, -8.0))
	_set_pose_deg(pose, "thigh_r", Vector3(lerpf(-15.0, 36.0, bend), 0.0, 8.0))
	_set_pose_deg(pose, "shin_l", Vector3(lerpf(34.0, -50.0, bend), 0.0, 0.0))
	_set_pose_deg(pose, "shin_r", Vector3(lerpf(30.0, -44.0, bend), 0.0, 0.0))
	pose["__pelvis_offset"] = Vector3(
		lerpf(0.0, 0.055, bend),
		lerpf(-0.07, 0.36, bend),
		lerpf(-0.1, -0.24, bend)
	)
	return pose


func _build_staff_vault_launch_pose(stage: String) -> Dictionary:
	var pose: Dictionary = {}
	match stage:
		"windup":
			return _build_staff_vault_bend_pose()
		"contact":
			_set_pose_deg(pose, "pelvis", Vector3(-26.0, 0.0, 7.0))
			_set_pose_deg(pose, "spine_01", Vector3(-18.0, 0.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(-10.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(78.0, -4.0, 12.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-2.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(74.0, 4.0, -12.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-5.0, 0.0, 0.0))
			_set_pose_deg(pose, "thigh_l", Vector3(38.0, 0.0, -8.0))
			_set_pose_deg(pose, "thigh_r", Vector3(30.0, 0.0, 8.0))
			_set_pose_deg(pose, "shin_l", Vector3(-44.0, 0.0, 0.0))
			_set_pose_deg(pose, "shin_r", Vector3(-36.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.045, 0.3, -0.31)
		"follow":
			_set_pose_deg(pose, "pelvis", Vector3(-12.0, 0.0, 4.0))
			_set_pose_deg(pose, "chest", Vector3(-7.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(44.0, -2.0, 12.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-22.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(40.0, 2.0, -12.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-25.0, 0.0, 0.0))
			_set_pose_deg(pose, "thigh_l", Vector3(-18.0, 0.0, -5.0))
			_set_pose_deg(pose, "thigh_r", Vector3(-12.0, 0.0, 5.0))
			_set_pose_deg(pose, "shin_l", Vector3(18.0, 0.0, 0.0))
			_set_pose_deg(pose, "shin_r", Vector3(14.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, 0.08, -0.35)
		_:
			_set_pose_deg(pose, "pelvis", Vector3(0.0, 0.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(1.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, 0.02, -0.05)
	return pose


func _build_staff_vault_drop_pose(stage: String) -> Dictionary:
	var pose: Dictionary = {}
	var dropped: bool = stage in ["contact", "follow", "recover"]
	var weight: float = 1.0 if dropped else 0.0
	_set_pose_deg(pose, "pelvis", Vector3(lerpf(-20.0, 17.0, weight), 0.0, 0.0))
	_set_pose_deg(pose, "chest", Vector3(lerpf(-12.0, 19.0, weight), 0.0, 0.0))
	_set_pose_deg(pose, "upper_arm_r", Vector3(lerpf(82.0, 54.0, weight), -3.0, 10.0))
	_set_pose_deg(pose, "forearm_r", Vector3(lerpf(-2.0, -34.0, weight), 0.0, 0.0))
	_set_pose_deg(pose, "upper_arm_l", Vector3(lerpf(78.0, 50.0, weight), 3.0, -10.0))
	_set_pose_deg(pose, "forearm_l", Vector3(lerpf(-5.0, -37.0, weight), 0.0, 0.0))
	_set_pose_deg(pose, "thigh_l", Vector3(lerpf(38.0, -28.0, weight), 0.0, -7.0))
	_set_pose_deg(pose, "thigh_r", Vector3(lerpf(32.0, -24.0, weight), 0.0, 7.0))
	_set_pose_deg(pose, "shin_l", Vector3(lerpf(-46.0, 44.0, weight), 0.0, 0.0))
	_set_pose_deg(pose, "shin_r", Vector3(lerpf(-40.0, 40.0, weight), 0.0, 0.0))
	pose["__pelvis_offset"] = Vector3(0.0, lerpf(0.3, -0.15, weight), lerpf(-0.22, -0.08, weight))
	return pose


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["weapon_language_v4k"] = true
	data["staff_focus_language"] = true
	data["staff_low_contact_plane"] = true
	data["staff_returning_throw_pose"] = true
	data["staff_angel_ring_pose"] = true
	data["staff_timed_aerial_vault_pose"] = true
	return data
