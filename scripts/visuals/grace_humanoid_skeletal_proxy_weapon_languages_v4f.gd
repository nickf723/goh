extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_weapon_languages_v4e.gd"

# Charge language: sustained Chain orbit and the Axe plant-vault-slam release.


func _build_attack_stage_pose(attack: WeaponAttackDefinition, stage: String) -> Dictionary:
	if attack != null and attack.extra_tags.has("chain_charge_orbit"):
		return _build_chain_charge_pose(stage)
	if attack != null and attack.extra_tags.has("axe_charge_plant"):
		return _build_axe_plant_pose(stage)
	if attack != null and attack.extra_tags.has("axe_vault_slam"):
		return _build_axe_vault_slam_pose(attack, stage)
	return super._build_attack_stage_pose(attack, stage)


func _build_chain_charge_pose(stage: String) -> Dictionary:
	var pose: Dictionary = {}
	var seconds: float = 0.0
	var charge: float = 0.0
	if weapon_controller != null:
		if weapon_controller.has_method("get_weapon_charge_elapsed"):
			seconds = float(weapon_controller.call("get_weapon_charge_elapsed"))
		if weapon_controller.has_method("get_weapon_charge_ratio"):
			charge = float(weapon_controller.call("get_weapon_charge_ratio"))
	var phase: float = seconds * lerpf(2.15, 3.05, clampf(charge, 0.0, 1.0))
	var orbit: float = sin(phase)
	var counter: float = cos(phase)
	var weight: float = lerpf(0.72, 1.0, charge)
	_set_pose_deg(pose, "pelvis", Vector3(10.0, orbit * 18.0 * weight, -counter * 9.0 * weight))
	_set_pose_deg(pose, "spine_01", Vector3(8.0, orbit * 13.0 * weight, counter * 8.0 * weight))
	_set_pose_deg(pose, "spine_02", Vector3(6.0, orbit * 16.0 * weight, counter * 10.0 * weight))
	_set_pose_deg(pose, "chest", Vector3(4.0, orbit * 22.0 * weight, counter * 12.0 * weight))
	_set_pose_deg(pose, "head", Vector3(-4.0, -orbit * 10.0, -counter * 4.0))
	_set_pose_deg(pose, "upper_arm_r", Vector3(48.0, -20.0 + orbit * 12.0, 20.0))
	_set_pose_deg(pose, "forearm_r", Vector3(-42.0, 0.0, 0.0))
	_set_pose_deg(pose, "upper_arm_l", Vector3(40.0, 15.0 + orbit * 10.0, -24.0))
	_set_pose_deg(pose, "forearm_l", Vector3(-48.0, 0.0, 0.0))
	_set_pose_deg(pose, "thigh_l", Vector3(-18.0, 0.0, -10.0))
	_set_pose_deg(pose, "thigh_r", Vector3(-18.0, 0.0, 10.0))
	_set_pose_deg(pose, "shin_l", Vector3(32.0, 0.0, 0.0))
	_set_pose_deg(pose, "shin_r", Vector3(32.0, 0.0, 0.0))
	pose["__pelvis_offset"] = Vector3(-counter * 0.035, -0.105, orbit * 0.025)
	return pose


func _build_axe_plant_pose(_stage: String) -> Dictionary:
	var pose: Dictionary = {}
	var charge: float = 0.0
	if weapon_controller != null and weapon_controller.has_method("get_weapon_charge_ratio"):
		charge = float(weapon_controller.call("get_weapon_charge_ratio"))
	var settle: float = lerpf(0.75, 1.0, charge)
	_set_pose_deg(pose, "pelvis", Vector3(18.0 * settle, -4.0, 0.0))
	_set_pose_deg(pose, "spine_01", Vector3(22.0 * settle, -4.0, 0.0))
	_set_pose_deg(pose, "spine_02", Vector3(20.0 * settle, -5.0, 0.0))
	_set_pose_deg(pose, "chest", Vector3(18.0 * settle, -6.0, 0.0))
	_set_pose_deg(pose, "upper_arm_r", Vector3(-48.0, -10.0, 30.0))
	_set_pose_deg(pose, "forearm_r", Vector3(-62.0, 0.0, 0.0))
	_set_pose_deg(pose, "upper_arm_l", Vector3(-42.0, 12.0, -28.0))
	_set_pose_deg(pose, "forearm_l", Vector3(-58.0, 0.0, 0.0))
	_set_pose_deg(pose, "thigh_l", Vector3(-34.0, 0.0, -6.0))
	_set_pose_deg(pose, "thigh_r", Vector3(-28.0, 0.0, 6.0))
	_set_pose_deg(pose, "shin_l", Vector3(50.0, 0.0, 0.0))
	_set_pose_deg(pose, "shin_r", Vector3(44.0, 0.0, 0.0))
	pose["__pelvis_offset"] = Vector3(0.0, -0.145 * settle, 0.035)
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
	if p < 0.24:
		return _build_axe_plant_pose(stage)
	if p < 0.64:
		var flip_p: float = (p - 0.24) / 0.4
		var tuck: float = sin(flip_p * PI)
		_set_pose_deg(pose, "pelvis", Vector3(-150.0 * tuck, 0.0, 0.0))
		_set_pose_deg(pose, "spine_01", Vector3(-42.0 * tuck, 0.0, 0.0))
		_set_pose_deg(pose, "spine_02", Vector3(-32.0 * tuck, 0.0, 0.0))
		_set_pose_deg(pose, "chest", Vector3(-28.0 * tuck, 0.0, 0.0))
		_set_pose_deg(pose, "upper_arm_r", Vector3(96.0, -8.0, 22.0))
		_set_pose_deg(pose, "forearm_r", Vector3(-18.0, 0.0, 0.0))
		_set_pose_deg(pose, "upper_arm_l", Vector3(88.0, 10.0, -22.0))
		_set_pose_deg(pose, "forearm_l", Vector3(-22.0, 0.0, 0.0))
		_set_pose_deg(pose, "thigh_l", Vector3(82.0 * tuck, 0.0, -6.0))
		_set_pose_deg(pose, "thigh_r", Vector3(82.0 * tuck, 0.0, 6.0))
		_set_pose_deg(pose, "shin_l", Vector3(-96.0 * tuck, 0.0, 0.0))
		_set_pose_deg(pose, "shin_r", Vector3(-96.0 * tuck, 0.0, 0.0))
		pose["__pelvis_offset"] = Vector3(0.0, 0.04 + tuck * 0.09, -0.04)
		return pose
	var descend: float = (p - 0.64) / 0.36
	_set_pose_deg(pose, "pelvis", Vector3(lerpf(-24.0, -8.0, descend), 0.0, 0.0))
	_set_pose_deg(pose, "chest", Vector3(lerpf(-30.0, -16.0, descend), 0.0, 0.0))
	_set_pose_deg(pose, "upper_arm_r", Vector3(lerpf(118.0, 146.0, descend), -8.0, 18.0))
	_set_pose_deg(pose, "forearm_r", Vector3(lerpf(-12.0, 4.0, descend), 0.0, 0.0))
	_set_pose_deg(pose, "upper_arm_l", Vector3(lerpf(110.0, 138.0, descend), 8.0, -18.0))
	_set_pose_deg(pose, "forearm_l", Vector3(lerpf(-16.0, 2.0, descend), 0.0, 0.0))
	_set_pose_deg(pose, "thigh_l", Vector3(lerpf(34.0, -12.0, descend), 0.0, -4.0))
	_set_pose_deg(pose, "thigh_r", Vector3(lerpf(30.0, -10.0, descend), 0.0, 4.0))
	_set_pose_deg(pose, "shin_l", Vector3(lerpf(-36.0, 24.0, descend), 0.0, 0.0))
	_set_pose_deg(pose, "shin_r", Vector3(lerpf(-34.0, 22.0, descend), 0.0, 0.0))
	pose["__pelvis_offset"] = Vector3(0.0, lerpf(0.02, -0.05, descend), -0.08)
	return pose


func _build_axe_slam_finish_pose(pose: Dictionary, stage: String) -> void:
	match stage:
		"contact":
			_set_pose_deg(pose, "pelvis", Vector3(18.0, 0.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(26.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(-58.0, -6.0, 22.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(-52.0, 6.0, -22.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.14, -0.1)
		"follow":
			_set_pose_deg(pose, "pelvis", Vector3(24.0, 0.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(32.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(-72.0, -8.0, 26.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(-66.0, 8.0, -26.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.16, -0.12)
		_:
			_set_pose_deg(pose, "pelvis", Vector3(6.0, 0.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(8.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.04, -0.02)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["weapon_language_v4f"] = true
	data["charge_pose_language"] = true
	return data
