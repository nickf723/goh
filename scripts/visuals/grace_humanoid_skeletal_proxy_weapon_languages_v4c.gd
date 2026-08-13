extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_weapon_languages_v4b.gd"

# Weapon Language V4C: Whip body language.
# The controlled line owns the whip path. Grace supplies a compact coil, hand-led
# release, and delayed torso follow-through so the crack reads as propagated force.


func _build_attack_stage_pose(attack: WeaponAttackDefinition, stage: String) -> Dictionary:
	if _get_equipped_weapon_class() == "whip":
		return _build_whip_attack_pose(attack, stage)
	return super._build_attack_stage_pose(attack, stage)


func _build_whip_attack_pose(attack: WeaponAttackDefinition, stage: String) -> Dictionary:
	var pose: Dictionary = {}
	if attack == null:
		return pose
	var side: float = _attack_side(attack)
	_build_lance_sweep_pose(pose, stage, side, attack.input_kind == "heavy", false)
	if stage == "windup":
		_add_pose_deg(pose, "pelvis", Vector3(-2.0, -8.0 * side, 0.0))
		_add_pose_deg(pose, "chest", Vector3(-3.0, -12.0 * side, 2.0 * side))
		_add_pose_deg(pose, "upper_arm_r", Vector3(-18.0, -10.0 * side, 12.0 * side))
		_add_pose_deg(pose, "forearm_r", Vector3(14.0, 6.0 * side, -5.0 * side))
		pose["__pelvis_offset"] = Vector3(0.012 * side, -0.04, 0.025)
	elif stage == "contact":
		_add_pose_deg(pose, "chest", Vector3(-2.0, -5.0 * side, 0.0))
		_add_pose_deg(pose, "upper_arm_r", Vector3(12.0, 9.0 * side, -10.0 * side))
		_add_pose_deg(pose, "forearm_r", Vector3(18.0, -7.0 * side, 6.0 * side))
		pose["__pelvis_offset"] = Vector3(-0.015 * side, -0.035, -0.04)
	elif stage == "follow":
		_add_pose_deg(pose, "chest", Vector3(-4.0, 8.0 * side, 0.0))
		_add_pose_deg(pose, "upper_arm_r", Vector3(18.0, 14.0 * side, -13.0 * side))
		_add_pose_deg(pose, "forearm_r", Vector3(22.0, -10.0 * side, 8.0 * side))
		pose["__pelvis_offset"] = Vector3(-0.02 * side, -0.035, -0.055)
	return pose


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["weapon_language_v4c"] = true
	var classes: Array = data.get("authored_language_classes", []) as Array
	if not classes.has("whip"):
		classes.append("whip")
	data["authored_language_classes"] = classes
	data["whip_language"] = true
	return data
