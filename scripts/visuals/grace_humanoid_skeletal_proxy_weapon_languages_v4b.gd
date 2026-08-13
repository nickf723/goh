extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_weapon_languages_v4a.gd"

# Weapon Language V4B: ranged family.
# All three follow the live projectile aim already owned by WeaponController,
# while preserving distinct draw, throw, and flick body rhythms.


func _build_attack_stage_pose(attack: WeaponAttackDefinition, stage: String) -> Dictionary:
	var weapon_class: String = _get_equipped_weapon_class()
	var pose: Dictionary
	if weapon_class == "bow":
		pose = _build_bow_pose(attack, stage)
	elif weapon_class == "boomerang":
		pose = _build_boomerang_pose(attack, stage)
	elif weapon_class == "shuriken":
		pose = _build_shuriken_pose(attack, stage)
	else:
		return super._build_attack_stage_pose(attack, stage)
	_apply_ranged_aim_bias(pose)
	return pose


func _build_bow_pose(attack: WeaponAttackDefinition, stage: String) -> Dictionary:
	var pose: Dictionary = {}
	if attack == null:
		return pose
	var heavy: bool = attack.input_kind == "heavy"
	var draw: float = 1.15 if heavy else 1.0
	match stage:
		"windup":
			_set_pose_deg(pose, "pelvis", Vector3(-2.0, -18.0, 0.0))
			_set_pose_deg(pose, "spine_01", Vector3(-2.0, -13.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(-2.0, -23.0, 0.0))
			_set_pose_deg(pose, "head", Vector3(0.0, 18.0, 0.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(88.0, 2.0, -8.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-5.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(52.0, 42.0 * draw, 32.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-92.0, -8.0, -8.0))
			_set_pose_deg(pose, "hand_r", Vector3(-8.0, -8.0, 4.0))
			_set_ranged_stance(pose, -1.0, heavy)
			pose["__pelvis_offset"] = Vector3(0.0, -0.035, 0.015)
		"contact":
			_set_pose_deg(pose, "pelvis", Vector3(-3.0, -15.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(-4.0, -20.0, 0.0))
			_set_pose_deg(pose, "head", Vector3(0.0, 16.0, 0.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(92.0, 1.0, -6.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-2.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(62.0, 24.0, 20.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-64.0, -4.0, -5.0))
			_set_ranged_stance(pose, 0.2, heavy)
			pose["__pelvis_offset"] = Vector3(0.0, -0.03, -0.025)
		"follow":
			_set_pose_deg(pose, "pelvis", Vector3(-2.0, -11.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(-3.0, -14.0, 0.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(88.0, 0.0, -5.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-4.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(48.0, 14.0, 15.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-52.0, -2.0, -3.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.028, -0.012)
		_:
			_set_pose_deg(pose, "pelvis", Vector3(-1.0, -6.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(-2.0, -8.0, 0.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(42.0, 0.0, -10.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-34.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(28.0, 5.0, 12.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-38.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.02, -0.01)
	return pose


func _build_boomerang_pose(attack: WeaponAttackDefinition, stage: String) -> Dictionary:
	var pose: Dictionary = {}
	if attack == null:
		return pose
	var heavy: bool = attack.input_kind == "heavy"
	var w: float = 1.12 if heavy else 1.0
	match stage:
		"windup":
			_set_pose_deg(pose, "pelvis", Vector3(2.0, -18.0 * w, 2.0))
			_set_pose_deg(pose, "spine_01", Vector3(1.0, -14.0 * w, -2.0))
			_set_pose_deg(pose, "chest", Vector3(2.0, -24.0 * w, -3.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(48.0, -30.0, 46.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-62.0, 12.0, -12.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(18.0, 6.0, -18.0))
			_set_ranged_stance(pose, -1.0, heavy)
			pose["__pelvis_offset"] = Vector3(0.02, -0.04, 0.025)
		"contact":
			_set_pose_deg(pose, "pelvis", Vector3(-5.0, 17.0 * w, -2.0))
			_set_pose_deg(pose, "spine_01", Vector3(-7.0, 13.0 * w, 2.0))
			_set_pose_deg(pose, "chest", Vector3(-10.0, 25.0 * w, 3.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(104.0, 20.0, -20.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-8.0, -8.0, 7.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(28.0, -7.0, 20.0))
			_set_ranged_stance(pose, 1.0, heavy)
			pose["__pelvis_offset"] = Vector3(-0.02, -0.035, -0.055 * w)
		"follow":
			_set_pose_deg(pose, "pelvis", Vector3(-7.0, 22.0 * w, -3.0))
			_set_pose_deg(pose, "chest", Vector3(-13.0, 31.0 * w, 4.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(112.0, 27.0, -24.0))
			_set_pose_deg(pose, "forearm_r", Vector3(3.0, -10.0, 9.0))
			pose["__pelvis_offset"] = Vector3(-0.025, -0.035, -0.07 * w)
		_:
			_set_pose_deg(pose, "pelvis", Vector3(-1.0, 2.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(-2.0, 3.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(22.0, 2.0, 8.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-28.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.02, -0.01)
	return pose


func _build_shuriken_pose(attack: WeaponAttackDefinition, stage: String) -> Dictionary:
	var pose: Dictionary = {}
	if attack == null:
		return pose
	var index: int = _proxy_attack_index(attack.attack_id)
	var side: float = -1.0 if index % 2 == 0 else 1.0
	var heavy: bool = attack.input_kind == "heavy"
	var w: float = 1.08 if heavy else 1.0
	match stage:
		"windup":
			_set_pose_deg(pose, "pelvis", Vector3(-3.0, -5.0 * side, 1.0 * side))
			_set_pose_deg(pose, "chest", Vector3(-5.0, -8.0 * side, -1.0 * side))
			_set_pose_deg(pose, "upper_arm_r", Vector3(48.0, -18.0 * side, 24.0 * side))
			_set_pose_deg(pose, "forearm_r", Vector3(-68.0, 8.0 * side, -6.0 * side))
			_set_pose_deg(pose, "upper_arm_l", Vector3(18.0, 4.0 * side, -14.0 * side))
			_set_ranged_stance(pose, -0.6, heavy)
			pose["__pelvis_offset"] = Vector3(0.008 * side, -0.035, 0.015)
		"contact":
			_set_pose_deg(pose, "pelvis", Vector3(-5.0, 7.0 * side * w, -1.0 * side))
			_set_pose_deg(pose, "chest", Vector3(-8.0, 11.0 * side * w, 1.0 * side))
			_set_pose_deg(pose, "upper_arm_r", Vector3(92.0, 12.0 * side, -12.0 * side))
			_set_pose_deg(pose, "forearm_r", Vector3(-6.0, -5.0 * side, 4.0 * side))
			_set_pose_deg(pose, "upper_arm_l", Vector3(22.0, -4.0 * side, 15.0 * side))
			pose["__pelvis_offset"] = Vector3(-0.01 * side, -0.03, -0.045 * w)
		"follow":
			_set_pose_deg(pose, "pelvis", Vector3(-5.0, 9.0 * side * w, -1.0 * side))
			_set_pose_deg(pose, "chest", Vector3(-9.0, 14.0 * side * w, 1.0 * side))
			_set_pose_deg(pose, "upper_arm_r", Vector3(98.0, 15.0 * side, -14.0 * side))
			_set_pose_deg(pose, "forearm_r", Vector3(2.0, -6.0 * side, 5.0 * side))
			pose["__pelvis_offset"] = Vector3(-0.012 * side, -0.028, -0.052 * w)
		_:
			_set_pose_deg(pose, "pelvis", Vector3(-1.0, 0.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(-2.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(19.0, 0.0, 8.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-30.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.018, -0.008)
	return pose


func _set_ranged_stance(pose: Dictionary, phase: float, heavy: bool) -> void:
	var w: float = 1.08 if heavy else 1.0
	_set_pose_deg(pose, "thigh_l", Vector3(10.0 * phase * w, 0.0, -3.0))
	_set_pose_deg(pose, "thigh_r", Vector3(-12.0 * phase * w, 0.0, 3.0))
	_set_pose_deg(pose, "shin_l", Vector3(16.0 + maxf(phase, 0.0) * 4.0, 0.0, 0.0))
	_set_pose_deg(pose, "shin_r", Vector3(18.0 + maxf(-phase, 0.0) * 4.0, 0.0, 0.0))


func _apply_ranged_aim_bias(pose: Dictionary) -> void:
	if actor == null or weapon_controller == null or weapon_controller.current_attack == null:
		return
	var forward: Vector3 = weapon_controller.get_attack_forward()
	forward.y = 0.0
	if forward.length_squared() <= 0.0001:
		return
	var local: Vector3 = actor.global_transform.basis.orthonormalized().inverse() * forward.normalized()
	var yaw: float = clampf(rad_to_deg(atan2(-local.x, -local.z)), -34.0, 34.0)
	_add_pose_deg(pose, "spine_02", Vector3(0.0, yaw * 0.18, 0.0))
	_add_pose_deg(pose, "chest", Vector3(0.0, yaw * 0.3, -local.x * 2.0))
	_add_pose_deg(pose, "neck", Vector3(0.0, yaw * 0.16, 0.0))
	_add_pose_deg(pose, "head", Vector3(0.0, yaw * 0.32, 0.0))


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["weapon_language_v4b"] = true
	var classes: Array = data.get("authored_language_classes", []) as Array
	for weapon_class: String in ["bow", "boomerang", "shuriken"]:
		if not classes.has(weapon_class):
			classes.append(weapon_class)
	data["authored_language_classes"] = classes
	data["ranged_live_aim_body_bias"] = true
	return data
