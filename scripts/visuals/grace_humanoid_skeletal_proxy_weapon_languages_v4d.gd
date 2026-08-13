extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_weapon_languages_v4c.gd"

# Weapon Language V4D: Flail candidate. The controlled weighted-head rig keeps
# path authority; Grace stores momentum in the hips and shoulder before release.


func _build_attack_stage_pose(attack: WeaponAttackDefinition, stage: String) -> Dictionary:
	if _get_equipped_weapon_class() == "flail":
		return _build_flail_attack_pose(attack, stage)
	return super._build_attack_stage_pose(attack, stage)


func _build_flail_attack_pose(attack: WeaponAttackDefinition, stage: String) -> Dictionary:
	var pose: Dictionary = {}
	if attack == null:
		return pose
	var side: float = _attack_side(attack)
	var heavy: bool = attack.input_kind == "heavy"
	_build_hammer_sweep_pose(pose, stage, side, heavy, true)
	if stage == "windup":
		_add_pose_deg(pose, "pelvis", Vector3(-1.0, -7.0 * side, 0.0))
		_add_pose_deg(pose, "chest", Vector3(-2.0, -10.0 * side, 0.0))
		_add_pose_deg(pose, "upper_arm_r", Vector3(-12.0, -6.0 * side, 10.0 * side))
		pose["__pelvis_offset"] = Vector3(0.012 * side, -0.05, 0.035)
	elif stage == "contact":
		pose["__pelvis_offset"] = Vector3(-0.015 * side, -0.06, -0.045)
	elif stage == "follow":
		_add_pose_deg(pose, "pelvis", Vector3(-3.0, 6.0 * side, 0.0))
		_add_pose_deg(pose, "chest", Vector3(-5.0, 9.0 * side, 0.0))
		pose["__pelvis_offset"] = Vector3(-0.02 * side, -0.065, -0.07 if heavy else -0.055)
	return pose


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["weapon_language_v4d"] = true
	var classes: Array = data.get("authored_language_classes", []) as Array
	if not classes.has("flail"):
		classes.append("flail")
	data["authored_language_classes"] = classes
	data["flail_language"] = true
	return data
