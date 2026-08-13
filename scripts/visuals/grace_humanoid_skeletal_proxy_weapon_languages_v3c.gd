extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_weapon_languages_v3b.gd"

# Weapon Language V3C: polearm-control family.
# Reuse the proven Lance body grammar, then bend it toward hook-and-reap Halberd
# control or flowing Staff redirects instead of copying Lance literally.


func _build_attack_stage_pose(attack: WeaponAttackDefinition, stage: String) -> Dictionary:
	var weapon_class: String = _get_equipped_weapon_class()
	if weapon_class == "halberd":
		return _build_halberd_attack_pose(attack, stage)
	if weapon_class == "staff":
		return _build_staff_attack_pose(attack, stage)
	return super._build_attack_stage_pose(attack, stage)


func _build_halberd_attack_pose(attack: WeaponAttackDefinition, stage: String) -> Dictionary:
	var pose: Dictionary = {}
	if attack == null:
		return pose
	var index: int = _proxy_attack_index(attack.attack_id)
	var heavy: bool = attack.input_kind == "heavy"
	if attack.extra_tags.has("aerial_heavy") or heavy and index == 3:
		_build_hammer_slam_pose(pose, stage, false)
		_add_halberd_two_hand_bias(pose, stage)
	elif attack.extra_tags.has("dash_light") or index == 1 and not heavy:
		_build_lance_thrust_pose(pose, stage, false, true)
	elif attack.extra_tags.has("dash_heavy") or heavy and index == 0:
		_build_lance_thrust_pose(pose, stage, true, true)
	elif heavy and index == 1:
		_build_lance_sweep_pose(pose, stage, 1.0, true, false)
		_apply_halberd_hook_bias(pose, stage)
	else:
		_build_lance_sweep_pose(pose, stage, _attack_side(attack), heavy, index >= 2)
		_add_halberd_two_hand_bias(pose, stage)
	return pose


func _apply_halberd_hook_bias(pose: Dictionary, stage: String) -> void:
	if stage == "windup":
		_add_pose_deg(pose, "pelvis", Vector3(1.0, -6.0, 0.0))
		_add_pose_deg(pose, "chest", Vector3(2.0, -9.0, 0.0))
		_add_pose_deg(pose, "upper_arm_l", Vector3(-4.0, -8.0, -4.0))
	elif stage == "contact":
		_add_pose_deg(pose, "pelvis", Vector3(2.0, -10.0, 0.0))
		_add_pose_deg(pose, "chest", Vector3(3.0, -14.0, 0.0))
		_add_pose_deg(pose, "upper_arm_l", Vector3(-6.0, -12.0, 7.0))
		pose["__pelvis_offset"] = Vector3(0.035, -0.05, -0.035)
	elif stage == "follow":
		_add_pose_deg(pose, "pelvis", Vector3(3.0, -15.0, 0.0))
		_add_pose_deg(pose, "chest", Vector3(4.0, -19.0, 0.0))
		_add_pose_deg(pose, "upper_arm_l", Vector3(-8.0, -16.0, 9.0))
		pose["__pelvis_offset"] = Vector3(0.045, -0.052, 0.005)


func _add_halberd_two_hand_bias(pose: Dictionary, stage: String) -> void:
	if stage in ["windup", "contact", "follow"]:
		_add_pose_deg(pose, "upper_arm_l", Vector3(-4.0, 0.0, -5.0))
		_add_pose_deg(pose, "forearm_l", Vector3(-5.0, 0.0, 0.0))


func _build_staff_attack_pose(attack: WeaponAttackDefinition, stage: String) -> Dictionary:
	var pose: Dictionary = {}
	if attack == null:
		return pose
	var index: int = _proxy_attack_index(attack.attack_id)
	var heavy: bool = attack.input_kind == "heavy"
	if attack.extra_tags.has("staff_pole_vault"):
		_build_staff_pole_vault_pose(pose, stage)
	elif attack.extra_tags.has("aerial_heavy") or heavy and index == 0:
		_build_hammer_slam_pose(pose, stage, false)
		_soften_staff_drop(pose, stage)
	elif attack.extra_tags.has("dash_heavy") or index == 2:
		_build_lance_thrust_pose(pose, stage, heavy, false)
		_soften_staff_thrust(pose, stage)
	elif heavy and index == 3:
		_build_staff_guard_pose(pose, stage)
	else:
		_build_lance_sweep_pose(pose, stage, _attack_side(attack), heavy, index >= 1)
		_apply_staff_flow_bias(pose, stage, _attack_side(attack))
	return pose


func _build_staff_pole_vault_pose(pose: Dictionary, stage: String) -> void:
	match stage:
		"windup":
			# Compress behind the staff instead of raising it into another overhead hit.
			_set_pose_deg(pose, "pelvis", Vector3(12.0, -4.0, 0.0))
			_set_pose_deg(pose, "spine_01", Vector3(10.0, -3.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(7.0, -2.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(74.0, -8.0, 12.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-38.0, 2.0, -3.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(70.0, 8.0, -12.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-42.0, -2.0, 3.0))
			_set_pose_deg(pose, "thigh_l", Vector3(-22.0, 0.0, -5.0))
			_set_pose_deg(pose, "thigh_r", Vector3(-18.0, 0.0, 5.0))
			_set_pose_deg(pose, "shin_l", Vector3(34.0, 0.0, 0.0))
			_set_pose_deg(pose, "shin_r", Vector3(30.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.1, 0.025)
		"contact":
			# Plant the far end in front of Grace and fold over the pole.
			_set_pose_deg(pose, "pelvis", Vector3(-13.0, 2.0, 0.0))
			_set_pose_deg(pose, "spine_01", Vector3(-17.0, 2.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(-23.0, 1.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(91.0, 5.0, 10.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-14.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(86.0, -5.0, -10.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-18.0, 0.0, 0.0))
			_set_pose_deg(pose, "thigh_l", Vector3(9.0, 0.0, -4.0))
			_set_pose_deg(pose, "thigh_r", Vector3(12.0, 0.0, 4.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.115, -0.105)
		"follow":
			# The controller fires the traversal impulse here, so the legs trail through.
			_set_pose_deg(pose, "pelvis", Vector3(-18.0, 0.0, 0.0))
			_set_pose_deg(pose, "spine_01", Vector3(-9.0, 0.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(8.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(84.0, 4.0, 8.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-5.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(80.0, -4.0, -8.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-8.0, 0.0, 0.0))
			_set_pose_deg(pose, "thigh_l", Vector3(30.0, 0.0, -7.0))
			_set_pose_deg(pose, "thigh_r", Vector3(24.0, 0.0, 7.0))
			_set_pose_deg(pose, "shin_l", Vector3(24.0, 0.0, 0.0))
			_set_pose_deg(pose, "shin_r", Vector3(32.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.025, -0.17)
		_:
			_set_pose_deg(pose, "pelvis", Vector3(2.0, 0.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(3.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(34.0, 2.0, 9.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-26.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(30.0, -2.0, -9.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-28.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.025, -0.015)


func _apply_staff_flow_bias(pose: Dictionary, stage: String, side: float) -> void:
	if stage == "windup":
		_add_pose_deg(pose, "pelvis", Vector3(-2.0, 4.0 * side, 0.0))
		_add_pose_deg(pose, "chest", Vector3(-3.0, 6.0 * side, 0.0))
	elif stage in ["contact", "follow"]:
		_add_pose_deg(pose, "pelvis", Vector3(2.0, -4.0 * side, 0.0))
		_add_pose_deg(pose, "chest", Vector3(3.0, -6.0 * side, 0.0))
		pose["__pelvis_offset"] = Vector3(-0.012 * side, -0.035, -0.04)


func _soften_staff_drop(pose: Dictionary, stage: String) -> void:
	if stage == "windup":
		_add_pose_deg(pose, "upper_arm_r", Vector3(-22.0, 0.0, 0.0))
		_add_pose_deg(pose, "upper_arm_l", Vector3(-20.0, 0.0, 0.0))
	elif stage in ["contact", "follow"]:
		pose["__pelvis_offset"] = Vector3(0.0, -0.06, -0.045)


func _soften_staff_thrust(pose: Dictionary, stage: String) -> void:
	if stage in ["contact", "follow"]:
		_add_pose_deg(pose, "chest", Vector3(3.0, 0.0, 0.0))
		pose["__pelvis_offset"] = Vector3(0.0, -0.028, -0.085)


func _build_staff_guard_pose(pose: Dictionary, stage: String) -> void:
	if stage == "windup":
		_build_lance_sweep_pose(pose, stage, -1.0, true, false)
		pose["__pelvis_offset"] = Vector3(0.0, -0.04, 0.015)
		return
	_set_pose_deg(pose, "pelvis", Vector3(-2.0, 4.0, 0.0))
	_set_pose_deg(pose, "spine_01", Vector3(-3.0, 3.0, 0.0))
	_set_pose_deg(pose, "chest", Vector3(-5.0, 6.0, 0.0))
	_set_pose_deg(pose, "upper_arm_r", Vector3(66.0, 12.0, -14.0))
	_set_pose_deg(pose, "forearm_r", Vector3(-34.0, -6.0, 4.0))
	_set_pose_deg(pose, "upper_arm_l", Vector3(62.0, 9.0, 14.0))
	_set_pose_deg(pose, "forearm_l", Vector3(-36.0, 5.0, -4.0))
	pose["__pelvis_offset"] = Vector3(0.0, -0.03, -0.018)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["weapon_language_v3c"] = true
	var classes: Array = data.get("authored_language_classes", []) as Array
	for weapon_class: String in ["halberd", "staff"]:
		if not classes.has(weapon_class):
			classes.append(weapon_class)
	data["authored_language_classes"] = classes
	data["halberd_language"] = true
	data["staff_language"] = true
	data["staff_pole_vault_pose"] = true
	return data
