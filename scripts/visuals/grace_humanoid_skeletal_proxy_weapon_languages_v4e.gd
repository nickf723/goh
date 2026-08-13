extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_weapon_languages_v4d.gd"

# V4E follows mechanical identity tags instead of guessing only from attack index.
# It gives the Boomerang a held melee language, Gauntlets readable boxing punches,
# and the colossal Chain a low body posture while the weight drags on the floor.


func _build_attack_stage_pose(attack: WeaponAttackDefinition, stage: String) -> Dictionary:
	var weapon_class: String = _get_equipped_weapon_class()
	if weapon_class == "boomerang" and attack != null and attack.extra_tags.has("boomerang_melee"):
		var melee_pose: Dictionary = _build_boomerang_melee_pose(attack, stage)
		_apply_forward_contact_plane_pose(melee_pose, attack, stage, weapon_class)
		return melee_pose
	if weapon_class == "gauntlets" and _has_boxing_identity(attack):
		var boxing_pose: Dictionary = _build_tagged_boxing_pose(attack, stage)
		_apply_forward_contact_plane_pose(boxing_pose, attack, stage, weapon_class)
		return boxing_pose
	var pose: Dictionary = super._build_attack_stage_pose(attack, stage)
	if weapon_class == "chains" and attack != null and attack.extra_tags.has("chain_ground_drag"):
		_apply_colossal_chain_body_pose(pose, attack, stage)
	return pose


func _build_boomerang_melee_pose(attack: WeaponAttackDefinition, stage: String) -> Dictionary:
	var pose: Dictionary = {}
	var side: float = _attack_side(attack)
	var wide: bool = attack.display_name.contains("Backhand") or attack.display_name.contains("Rising")
	_build_cut_pose(pose, stage, side, wide, false)
	# Keep the free hand near the torso and let the weapon hand carve short arcs.
	if stage == "windup":
		_add_pose_deg(pose, "chest", Vector3(-2.0, -5.0 * side, 0.0))
		_add_pose_deg(pose, "upper_arm_r", Vector3(-12.0, 0.0, -5.0 * side))
		pose["__pelvis_offset"] = Vector3(0.01 * side, -0.035, 0.015)
	elif stage == "contact":
		_add_pose_deg(pose, "chest", Vector3(-4.0, 7.0 * side, 0.0))
		_add_pose_deg(pose, "upper_arm_r", Vector3(-8.0, 0.0, 6.0 * side))
		pose["__pelvis_offset"] = Vector3(-0.012 * side, -0.035, -0.07)
	elif stage == "follow":
		_add_pose_deg(pose, "chest", Vector3(-5.0, 10.0 * side, 0.0))
		pose["__pelvis_offset"] = Vector3(-0.016 * side, -0.032, -0.085)
	return pose


func _has_boxing_identity(attack: WeaponAttackDefinition) -> bool:
	if attack == null:
		return false
	for tag: String in [
		"boxing_jab", "boxing_cross", "boxing_hook", "boxing_body_hook",
		"boxing_overhand", "boxing_uppercut",
	]:
		if attack.extra_tags.has(tag):
			return true
	return false


func _build_tagged_boxing_pose(attack: WeaponAttackDefinition, stage: String) -> Dictionary:
	var pose: Dictionary = {}
	if attack.extra_tags.has("boxing_uppercut"):
		_build_gauntlet_rising_pose(pose, stage, attack.extra_tags.has("boxing_finisher"))
	elif attack.extra_tags.has("boxing_body_hook"):
		_build_gauntlet_hook_pose(pose, stage, true)
		_apply_body_hook_bias(pose, stage)
	elif attack.extra_tags.has("boxing_overhand"):
		_build_overhand_pose(pose, stage)
	elif attack.extra_tags.has("boxing_hook"):
		_build_gauntlet_hook_pose(pose, stage, false)
	elif attack.extra_tags.has("boxing_cross"):
		_build_gauntlet_straight_pose(pose, stage, 1, false)
	else:
		_build_gauntlet_straight_pose(pose, stage, 0, false)
	return pose


func _build_overhand_pose(pose: Dictionary, stage: String) -> void:
	_build_gauntlet_straight_pose(pose, stage, 1, true)
	match stage:
		"windup":
			_add_pose_deg(pose, "pelvis", Vector3(5.0, -8.0, 0.0))
			_add_pose_deg(pose, "chest", Vector3(8.0, -12.0, 0.0))
			_add_pose_deg(pose, "upper_arm_r", Vector3(34.0, -8.0, 14.0))
			_add_pose_deg(pose, "forearm_r", Vector3(-18.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.02, -0.06, 0.035)
		"contact":
			_add_pose_deg(pose, "pelvis", Vector3(-8.0, 12.0, 0.0))
			_add_pose_deg(pose, "chest", Vector3(-15.0, 18.0, 0.0))
			_add_pose_deg(pose, "upper_arm_r", Vector3(-18.0, 8.0, -8.0))
			pose["__pelvis_offset"] = Vector3(-0.02, -0.045, -0.14)
		"follow":
			_add_pose_deg(pose, "chest", Vector3(-18.0, 22.0, 0.0))
			pose["__pelvis_offset"] = Vector3(-0.025, -0.04, -0.16)


func _apply_body_hook_bias(pose: Dictionary, stage: String) -> void:
	match stage:
		"windup":
			_add_pose_deg(pose, "pelvis", Vector3(8.0, 0.0, 0.0))
			_add_pose_deg(pose, "chest", Vector3(10.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.02, -0.075, 0.02)
		"contact":
			_add_pose_deg(pose, "pelvis", Vector3(6.0, 0.0, 0.0))
			_add_pose_deg(pose, "chest", Vector3(8.0, 0.0, 0.0))
			_add_pose_deg(pose, "upper_arm_r", Vector3(-18.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(-0.02, -0.07, -0.07)
		"follow":
			_add_pose_deg(pose, "chest", Vector3(6.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(-0.025, -0.065, -0.08)


func _apply_colossal_chain_body_pose(
	pose: Dictionary,
	attack: WeaponAttackDefinition,
	stage: String
) -> void:
	var heavy: bool = attack.input_kind == "heavy"
	var weight: float = 1.35 if heavy else 1.0
	match stage:
		"windup":
			_add_pose_deg(pose, "pelvis", Vector3(12.0 * weight, 0.0, 0.0))
			_add_pose_deg(pose, "chest", Vector3(10.0 * weight, 0.0, 0.0))
			_add_pose_deg(pose, "upper_arm_r", Vector3(-22.0, 0.0, 0.0))
			_add_pose_deg(pose, "upper_arm_l", Vector3(-14.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.09 * weight, 0.02)
		"contact":
			_add_pose_deg(pose, "pelvis", Vector3(-8.0 * weight, 0.0, 0.0))
			_add_pose_deg(pose, "chest", Vector3(-12.0 * weight, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.07 * weight, -0.08 * weight)
		"follow":
			_add_pose_deg(pose, "chest", Vector3(-15.0 * weight, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.065 * weight, -0.1 * weight)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["weapon_language_v4e"] = true
	data["boomerang_melee_pose"] = true
	data["tagged_boxing_pose"] = true
	data["colossal_chain_body_pose"] = true
	return data
