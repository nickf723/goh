extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_weapon_languages_v3c.gd"

# Weapon Language V4A: Scythe candidate.
# Long leverage comes from the Lance family; committed follow-through comes from
# Axe. The distinctive bias is low reaping posture rather than giant orbiting arcs.


func _build_attack_stage_pose(attack: WeaponAttackDefinition, stage: String) -> Dictionary:
	if _get_equipped_weapon_class() == "scythe":
		return _build_scythe_attack_pose(attack, stage)
	return super._build_attack_stage_pose(attack, stage)


func _build_scythe_attack_pose(attack: WeaponAttackDefinition, stage: String) -> Dictionary:
	var pose: Dictionary = {}
	if attack == null:
		return pose
	var heavy: bool = attack.input_kind == "heavy"
	var index: int = _proxy_attack_index(attack.attack_id)
	if attack.extra_tags.has("aerial_heavy") or heavy and index == 0:
		_build_axe_drop_pose(pose, stage, false)
		_add_pose_deg(pose, "chest", Vector3(3.0, -5.0, 0.0))
		return pose

	var side: float = _attack_side(attack)
	_build_lance_sweep_pose(pose, stage, side, heavy, index >= 2)
	if stage == "windup":
		_add_pose_deg(pose, "pelvis", Vector3(7.0, -7.0 * side, 3.0))
		_add_pose_deg(pose, "chest", Vector3(8.0, -10.0 * side, 4.0))
		_add_pose_deg(pose, "upper_arm_r", Vector3(-8.0, -5.0 * side, 8.0))
		pose["__pelvis_offset"] = Vector3(0.014 * side, -0.055, 0.02)
	elif stage == "contact":
		_add_pose_deg(pose, "pelvis", Vector3(-4.0, 7.0 * side, -3.0))
		_add_pose_deg(pose, "chest", Vector3(-7.0, 11.0 * side, -4.0))
		pose["__pelvis_offset"] = Vector3(-0.015 * side, -0.055, -0.055 if heavy else -0.045)
	elif stage == "follow":
		_add_pose_deg(pose, "pelvis", Vector3(-6.0, 12.0 * side, -4.0))
		_add_pose_deg(pose, "chest", Vector3(-10.0, 17.0 * side, -5.0))
		pose["__pelvis_offset"] = Vector3(-0.02 * side, -0.058, -0.075 if heavy else -0.06)
	return pose


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["weapon_language_v4a"] = true
	var classes: Array = data.get("authored_language_classes", []) as Array
	if not classes.has("scythe"):
		classes.append("scythe")
	data["authored_language_classes"] = classes
	data["scythe_language"] = true
	return data
