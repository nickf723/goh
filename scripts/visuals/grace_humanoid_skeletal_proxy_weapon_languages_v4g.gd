extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_weapon_languages_v4f.gd"

# V4G lets the flexible weapon carry the spectacle. Grace counters the Chain's
# pull instead of mimicking the head arc, while the Axe charge travels forward
# through a low vault and committed descending chop.


func _build_attack_stage_pose(attack: WeaponAttackDefinition, stage: String) -> Dictionary:
	var weapon_class: String = _get_equipped_weapon_class()
	if weapon_class == "chains" and attack != null:
		if attack.extra_tags.has("chain_charge_orbit"):
			return _build_chain_charge_pose(stage)
		return _build_chain_swing_pose(attack, stage)
	if attack != null and attack.extra_tags.has("axe_vault_slam"):
		return _build_axe_vault_slam_pose(attack, stage)
	return super._build_attack_stage_pose(attack, stage)


func _build_chain_swing_pose(attack: WeaponAttackDefinition, stage: String) -> Dictionary:
	var pose: Dictionary = {}
	var side: float = _attack_side(attack)
	var heavy: bool = attack.input_kind == "heavy"
	var weight: float = 1.18 if heavy else 1.0
	match stage:
		"windup":
			_set_pose_deg(pose, "pelvis", Vector3(8.0 * weight, -12.0 * side, -4.0 * side))
			_set_pose_deg(pose, "spine_01", Vector3(6.0, -8.0 * side, 4.0 * side))
			_set_pose_deg(pose, "spine_02", Vector3(5.0, -11.0 * side, 5.0 * side))
			_set_pose_deg(pose, "chest", Vector3(4.0, -16.0 * side, 7.0 * side))
			_set_pose_deg(pose, "upper_arm_r", Vector3(34.0, -18.0 * side, 22.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-44.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(26.0, 14.0 * side, -24.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-48.0, 0.0, 0.0))
			_set_pose_deg(pose, "thigh_l", Vector3(-16.0, 0.0, -7.0))
			_set_pose_deg(pose, "thigh_r", Vector3(-12.0, 0.0, 7.0))
			_set_pose_deg(pose, "shin_l", Vector3(28.0, 0.0, 0.0))
			_set_pose_deg(pose, "shin_r", Vector3(24.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.025 * side, -0.09 * weight, 0.015)
		"contact":
			_set_pose_deg(pose, "pelvis", Vector3(5.0, 18.0 * side * weight, 5.0 * side))
			_set_pose_deg(pose, "spine_01", Vector3(3.0, 12.0 * side, -4.0 * side))
			_set_pose_deg(pose, "spine_02", Vector3(2.0, 16.0 * side, -5.0 * side))
			_set_pose_deg(pose, "chest", Vector3(1.0, 22.0 * side, -7.0 * side))
			_set_pose_deg(pose, "upper_arm_r", Vector3(58.0, 20.0 * side, -14.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-26.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(46.0, -18.0 * side, 18.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-30.0, 0.0, 0.0))
			_set_pose_deg(pose, "thigh_l", Vector3(8.0, 0.0, -5.0))
			_set_pose_deg(pose, "thigh_r", Vector3(-18.0, 0.0, 5.0))
			pose["__pelvis_offset"] = Vector3(-0.025 * side, -0.075 * weight, -0.055)
		"follow":
			_set_pose_deg(pose, "pelvis", Vector3(7.0, 24.0 * side * weight, 6.0 * side))
			_set_pose_deg(pose, "chest", Vector3(5.0, 28.0 * side, -8.0 * side))
			_set_pose_deg(pose, "upper_arm_r", Vector3(66.0, 26.0 * side, -16.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-18.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(52.0, -22.0 * side, 20.0))
			pose["__pelvis_offset"] = Vector3(-0.03 * side, -0.07 * weight, -0.075)
		_:
			_set_pose_deg(pose, "pelvis", Vector3(4.0, 4.0 * side, 0.0))
			_set_pose_deg(pose, "chest", Vector3(3.0, 6.0 * side, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(24.0, 0.0, 12.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-28.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(20.0, 0.0, -12.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-30.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.035, -0.015)
	return pose


func _build_chain_charge_pose(_stage: String) -> Dictionary:
	var pose: Dictionary = {}
	var seconds: float = 0.0
	var charge: float = 0.0
	if weapon_controller != null:
		if weapon_controller.has_method("get_weapon_charge_elapsed"):
			seconds = float(weapon_controller.call("get_weapon_charge_elapsed"))
		if weapon_controller.has_method("get_weapon_charge_ratio"):
			charge = float(weapon_controller.call("get_weapon_charge_ratio"))
	var speed: float = lerpf(1.75, 2.5, clampf(charge, 0.0, 1.0))
	var phase: float = seconds * speed
	var orbit: float = sin(phase)
	var counter: float = cos(phase)
	var weight: float = lerpf(0.7, 1.0, charge)
	# Grace counters the moving mass with hips and shoulders, but stays readable.
	_set_pose_deg(pose, "pelvis", Vector3(11.0, -orbit * 11.0 * weight, -counter * 7.0 * weight))
	_set_pose_deg(pose, "spine_01", Vector3(8.0, orbit * 7.0 * weight, counter * 5.0 * weight))
	_set_pose_deg(pose, "spine_02", Vector3(6.0, orbit * 9.0 * weight, counter * 6.0 * weight))
	_set_pose_deg(pose, "chest", Vector3(4.0, orbit * 12.0 * weight, counter * 8.0 * weight))
	_set_pose_deg(pose, "head", Vector3(-3.0, -orbit * 5.0, -counter * 2.5))
	_set_pose_deg(pose, "upper_arm_r", Vector3(42.0, -8.0 + orbit * 8.0, 18.0))
	_set_pose_deg(pose, "forearm_r", Vector3(-48.0, 0.0, 0.0))
	_set_pose_deg(pose, "upper_arm_l", Vector3(36.0, 8.0 + orbit * 7.0, -20.0))
	_set_pose_deg(pose, "forearm_l", Vector3(-52.0, 0.0, 0.0))
	_set_pose_deg(pose, "thigh_l", Vector3(-20.0, 0.0, -11.0))
	_set_pose_deg(pose, "thigh_r", Vector3(-20.0, 0.0, 11.0))
	_set_pose_deg(pose, "shin_l", Vector3(35.0, 0.0, 0.0))
	_set_pose_deg(pose, "shin_r", Vector3(35.0, 0.0, 0.0))
	pose["__pelvis_offset"] = Vector3(counter * 0.018, -0.115, -orbit * 0.012)
	return pose


func _build_axe_vault_slam_pose(attack: WeaponAttackDefinition, stage: String) -> Dictionary:
	var pose: Dictionary = {}
	if weapon_controller == null:
		return pose
	var startup: float = maxf(attack.get_startup_duration(weapon_controller.get_attack_speed()), 0.01)
	var time: float = maxf(weapon_controller.current_attack_elapsed, 0.0)
	var p: float = clampf(time / startup, 0.0, 1.0)
	if stage != "windup" or time >= startup:
		_build_axe_slam_finish_pose(pose, stage)
		return pose
	if p < 0.2:
		return _build_axe_plant_pose(stage)
	if p < 0.58:
		var vault_p: float = (p - 0.2) / 0.38
		var tuck: float = sin(vault_p * PI)
		_set_pose_deg(pose, "pelvis", Vector3(-108.0 * tuck, 0.0, 0.0))
		_set_pose_deg(pose, "spine_01", Vector3(-32.0 * tuck, 0.0, 0.0))
		_set_pose_deg(pose, "spine_02", Vector3(-24.0 * tuck, 0.0, 0.0))
		_set_pose_deg(pose, "chest", Vector3(-20.0 * tuck, 0.0, 0.0))
		_set_pose_deg(pose, "upper_arm_r", Vector3(88.0, -7.0, 20.0))
		_set_pose_deg(pose, "forearm_r", Vector3(-24.0, 0.0, 0.0))
		_set_pose_deg(pose, "upper_arm_l", Vector3(82.0, 7.0, -20.0))
		_set_pose_deg(pose, "forearm_l", Vector3(-26.0, 0.0, 0.0))
		_set_pose_deg(pose, "thigh_l", Vector3(62.0 * tuck, 0.0, -6.0))
		_set_pose_deg(pose, "thigh_r", Vector3(54.0 * tuck, 0.0, 6.0))
		_set_pose_deg(pose, "shin_l", Vector3(-74.0 * tuck, 0.0, 0.0))
		_set_pose_deg(pose, "shin_r", Vector3(-68.0 * tuck, 0.0, 0.0))
		pose["__pelvis_offset"] = Vector3(0.0, 0.025 + tuck * 0.055, lerpf(-0.07, -0.16, vault_p))
		return pose
	var descend: float = (p - 0.58) / 0.42
	_set_pose_deg(pose, "pelvis", Vector3(lerpf(-20.0, 8.0, descend), 0.0, 0.0))
	_set_pose_deg(pose, "chest", Vector3(lerpf(-28.0, 18.0, descend), 0.0, 0.0))
	_set_pose_deg(pose, "upper_arm_r", Vector3(lerpf(112.0, -44.0, descend), -7.0, 18.0))
	_set_pose_deg(pose, "forearm_r", Vector3(lerpf(-14.0, -36.0, descend), 0.0, 0.0))
	_set_pose_deg(pose, "upper_arm_l", Vector3(lerpf(106.0, -40.0, descend), 7.0, -18.0))
	_set_pose_deg(pose, "forearm_l", Vector3(lerpf(-16.0, -34.0, descend), 0.0, 0.0))
	_set_pose_deg(pose, "thigh_l", Vector3(lerpf(28.0, -18.0, descend), 0.0, -4.0))
	_set_pose_deg(pose, "thigh_r", Vector3(lerpf(22.0, -14.0, descend), 0.0, 4.0))
	_set_pose_deg(pose, "shin_l", Vector3(lerpf(-28.0, 30.0, descend), 0.0, 0.0))
	_set_pose_deg(pose, "shin_r", Vector3(lerpf(-24.0, 28.0, descend), 0.0, 0.0))
	pose["__pelvis_offset"] = Vector3(0.0, lerpf(0.015, -0.09, descend), lerpf(-0.16, -0.24, descend))
	return pose


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["weapon_language_v4g"] = true
	data["chain_counterweight_pose"] = true
	data["axe_forward_vault_pose"] = true
	return data
