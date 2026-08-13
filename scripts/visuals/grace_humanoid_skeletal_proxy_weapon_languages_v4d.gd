extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_weapon_languages_v4c.gd"

# Weapon Language V4D: Flail + Chains candidates.
# Their controlled runtime rigs remain authoritative for the actual flexible path.
# This layer only gives Grace distinct body language for stored momentum vs tension.


func _build_attack_stage_pose(attack: WeaponAttackDefinition, stage: String) -> Dictionary:
	var weapon_class: String = _get_equipped_weapon_class()
	if weapon_class == "flail":
		return _build_flail_attack_pose(attack, stage)
	if weapon_class == "chains":
		return _build_chain_attack_pose(attack, stage)
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


func _build_chain_attack_pose(attack: WeaponAttackDefinition, stage: String) -> Dictionary:
	var pose: Dictionary = {}
	if attack == null:
		return pose
	var side: float = _attack_side(attack)
	var heavy: bool = attack.input_kind == "heavy"
	_build_hammer_sweep_pose(pose, stage, side, heavy, true)

	# Chains differ from Flail by keeping more tension in the torso and support arm.
	# The contact extends outward, then the recovery visibly reels Grace back toward
	# a braced stance rather than simply following the weighted end around.
	if stage == "windup":
		_add_pose_deg(pose, "pelvis", Vector3(2.0, -4.0 * side, 0.0))
		_add_pose_deg(pose, "chest", Vector3(3.0, -6.0 * side, 0.0))
		_add_pose_deg(pose, "upper_arm_r", Vector3(-8.0, -5.0 * side, 7.0 * side))
		_add_pose_deg(pose, "forearm_r", Vector3(10.0, 4.0 * side, -4.0 * side))
		_add_pose_deg(pose, "upper_arm_l", Vector3(8.0, 5.0 * side, -7.0 * side))
		pose["__pelvis_offset"] = Vector3(0.01 * side, -0.045, 0.025)
	elif stage == "contact":
		_add_pose_deg(pose, "chest", Vector3(-2.0, 4.0 * side, 0.0))
		_add_pose_deg(pose, "upper_arm_r", Vector3(8.0, 7.0 * side, -8.0 * side))
		_add_pose_deg(pose, "forearm_r", Vector3(14.0, -5.0 * side, 5.0 * side))
		_add_pose_deg(pose, "upper_arm_l", Vector3(-5.0, -4.0 * side, 6.0 * side))
		pose["__pelvis_offset"] = Vector3(-0.012 * side, -0.052, -0.045)
	elif stage == "follow":
		_add_pose_deg(pose, "pelvis", Vector3(4.0, -8.0 * side, 0.0))
		_add_pose_deg(pose, "chest", Vector3(7.0, -11.0 * side, 0.0))
		_add_pose_deg(pose, "upper_arm_r", Vector3(-12.0, -10.0 * side, 10.0 * side))
		_add_pose_deg(pose, "forearm_r", Vector3(-8.0, 7.0 * side, -6.0 * side))
		_add_pose_deg(pose, "upper_arm_l", Vector3(12.0, 8.0 * side, -9.0 * side))
		pose["__pelvis_offset"] = Vector3(0.016 * side, -0.055, -0.025 if heavy else -0.018)
	return pose


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["weapon_language_v4d"] = true
	var classes: Array = data.get("authored_language_classes", []) as Array
	for weapon_class: String in ["flail", "chains"]:
		if not classes.has(weapon_class):
			classes.append(weapon_class)
	data["authored_language_classes"] = classes
	data["flail_language"] = true
	data["chain_language"] = true
	data["all_weapon_languages_candidate"] = classes.size() >= 16
	return data
