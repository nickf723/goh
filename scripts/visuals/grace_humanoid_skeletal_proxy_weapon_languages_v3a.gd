extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_weapon_languages_v2.gd"

# Weapon Language V3A: committed one-handed impact family.
# Axe inherits Hammer's whole-body commitment but releases sooner and follows
# through farther. Mace keeps the same planted power source with tighter arcs so
# repeated stagger pressure reads compact rather than like a miniature Hammer.


func _build_attack_stage_pose(attack: WeaponAttackDefinition, stage: String) -> Dictionary:
	var weapon_class: String = _get_equipped_weapon_class()
	if weapon_class == "axe":
		return _build_axe_attack_pose(attack, stage)
	if weapon_class == "mace":
		return _build_mace_attack_pose(attack, stage)
	return super._build_attack_stage_pose(attack, stage)


func _build_axe_attack_pose(attack: WeaponAttackDefinition, stage: String) -> Dictionary:
	var pose: Dictionary = {}
	if attack == null:
		return pose
	var index: int = _proxy_attack_index(attack.attack_id)
	var heavy: bool = attack.input_kind == "heavy"
	if attack.extra_tags.has("aerial_heavy") or (heavy and index in [0, 3]):
		_build_axe_drop_pose(pose, stage, index == 3)
	elif attack.extra_tags.has("aerial_light") or attack.extra_tags.has("dash_light"):
		_build_axe_hew_pose(pose, stage, _attack_side(attack), false, true)
	elif attack.extra_tags.has("dash_heavy") or (heavy and index in [1, 2]):
		_build_axe_hew_pose(pose, stage, _attack_side(attack), true, index == 2)
	else:
		_build_axe_hew_pose(pose, stage, _attack_side(attack), heavy, index >= 2)
	return pose


func _build_mace_attack_pose(attack: WeaponAttackDefinition, stage: String) -> Dictionary:
	var pose: Dictionary = {}
	if attack == null:
		return pose
	var index: int = _proxy_attack_index(attack.attack_id)
	var heavy: bool = attack.input_kind == "heavy"
	if attack.extra_tags.has("aerial_heavy") or (heavy and index in [0, 3]):
		_build_mace_crush_pose(pose, stage, index == 3)
	else:
		_build_mace_arc_pose(pose, stage, _attack_side(attack), heavy, index >= 2)
	return pose


func _build_axe_hew_pose(
	pose: Dictionary,
	stage: String,
	side: float,
	heavy: bool,
	broad: bool
) -> void:
	var w: float = 1.12 if heavy else 1.0
	var width: float = 1.14 if broad else 1.0
	match stage:
		"windup":
			_set_pose_deg(pose, "pelvis", Vector3(6.0, -14.0 * side * width, 2.0 * side))
			_set_pose_deg(pose, "spine_01", Vector3(6.0, -11.0 * side * width, -2.0 * side))
			_set_pose_deg(pose, "chest", Vector3(8.0, -20.0 * side * width, -3.0 * side))
			_set_pose_deg(pose, "upper_arm_r", Vector3(74.0, -20.0 * side, 28.0 * side))
			_set_pose_deg(pose, "forearm_r", Vector3(-42.0, 8.0 * side, -7.0 * side))
			_set_pose_deg(pose, "upper_arm_l", Vector3(24.0, 6.0 * side, -18.0 * side))
			_set_impact_stance(pose, side, -1.0, heavy)
			pose["__pelvis_offset"] = Vector3(0.015 * side, -0.05 * w, 0.025)
		"contact":
			_set_pose_deg(pose, "pelvis", Vector3(-8.0, 18.0 * side * width * w, -2.0 * side))
			_set_pose_deg(pose, "spine_01", Vector3(-10.0, 14.0 * side * width * w, 2.0 * side))
			_set_pose_deg(pose, "chest", Vector3(-14.0, 27.0 * side * width * w, 3.0 * side))
			_set_pose_deg(pose, "upper_arm_r", Vector3(102.0, 26.0 * side, -24.0 * side))
			_set_pose_deg(pose, "forearm_r", Vector3(-8.0, -7.0 * side, 5.0 * side))
			_set_pose_deg(pose, "upper_arm_l", Vector3(34.0, -8.0 * side, 22.0 * side))
			_set_impact_stance(pose, side, 1.0, heavy)
			pose["__pelvis_offset"] = Vector3(-0.02 * side, -0.055 * w, -0.06 * w)
		"follow":
			_set_pose_deg(pose, "pelvis", Vector3(-10.0, 24.0 * side * width * w, -3.0 * side))
			_set_pose_deg(pose, "chest", Vector3(-18.0, 34.0 * side * width * w, 4.0 * side))
			_set_pose_deg(pose, "upper_arm_r", Vector3(112.0, 34.0 * side, -28.0 * side))
			_set_pose_deg(pose, "forearm_r", Vector3(3.0, -10.0 * side, 7.0 * side))
			_set_impact_stance(pose, side, 1.12, heavy)
			pose["__pelvis_offset"] = Vector3(-0.025 * side, -0.06 * w, -0.085 * w)
		_:
			_set_pose_deg(pose, "pelvis", Vector3(3.0, 2.0 * side, 0.0))
			_set_pose_deg(pose, "chest", Vector3(5.0, 3.0 * side, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(24.0, 3.0 * side, 8.0 * side))
			_set_pose_deg(pose, "forearm_r", Vector3(-22.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.022, -0.012)


func _build_axe_drop_pose(pose: Dictionary, stage: String, finisher: bool) -> void:
	var w: float = 1.15 if finisher else 1.0
	match stage:
		"windup":
			_set_pose_deg(pose, "pelvis", Vector3(9.0, -4.0, 0.0))
			_set_pose_deg(pose, "spine_01", Vector3(10.0, -3.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(14.0, -3.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(128.0, -7.0, 14.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-44.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(38.0, 5.0, -16.0))
			_set_impact_stance(pose, 1.0, -1.0, true)
			pose["__pelvis_offset"] = Vector3(0.0, -0.09 * w, 0.03)
		"contact":
			_set_pose_deg(pose, "pelvis", Vector3(-10.0, 2.0, 0.0))
			_set_pose_deg(pose, "spine_01", Vector3(-13.0, 2.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(-20.0, 2.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(58.0, 5.0, 12.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-5.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.08 * w, -0.075 * w)
		"follow":
			_set_pose_deg(pose, "pelvis", Vector3(-13.0, 2.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(-24.0, 2.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(40.0, 6.0, 14.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.085 * w, -0.095 * w)
		_:
			_set_pose_deg(pose, "pelvis", Vector3(4.0, 0.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(7.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(24.0, 0.0, 7.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.028, -0.01)


func _build_mace_arc_pose(
	pose: Dictionary,
	stage: String,
	side: float,
	heavy: bool,
	broad: bool
) -> void:
	var w: float = 1.08 if heavy else 1.0
	var width: float = 1.10 if broad else 1.0
	match stage:
		"windup":
			_set_pose_deg(pose, "pelvis", Vector3(2.0, -8.0 * side, 1.0 * side))
			_set_pose_deg(pose, "spine_01", Vector3(1.0, -7.0 * side, -1.0 * side))
			_set_pose_deg(pose, "chest", Vector3(2.0, -13.0 * side * width, -2.0 * side))
			_set_pose_deg(pose, "upper_arm_r", Vector3(58.0, -16.0 * side, 24.0 * side))
			_set_pose_deg(pose, "forearm_r", Vector3(-42.0, 7.0 * side, -6.0 * side))
			_set_impact_stance(pose, side, -0.8, heavy)
			pose["__pelvis_offset"] = Vector3(0.01 * side, -0.04 * w, 0.015)
		"contact":
			_set_pose_deg(pose, "pelvis", Vector3(-5.0, 10.0 * side * w, -1.0 * side))
			_set_pose_deg(pose, "spine_01", Vector3(-6.0, 8.0 * side * w, 1.0 * side))
			_set_pose_deg(pose, "chest", Vector3(-9.0, 18.0 * side * width * w, 2.0 * side))
			_set_pose_deg(pose, "upper_arm_r", Vector3(88.0, 20.0 * side, -20.0 * side))
			_set_pose_deg(pose, "forearm_r", Vector3(-15.0, -6.0 * side, 4.0 * side))
			_set_impact_stance(pose, side, 0.8, heavy)
			pose["__pelvis_offset"] = Vector3(-0.012 * side, -0.045 * w, -0.04 * w)
		"follow":
			_set_pose_deg(pose, "pelvis", Vector3(-6.0, 13.0 * side * w, -1.5 * side))
			_set_pose_deg(pose, "chest", Vector3(-11.0, 22.0 * side * width * w, 2.5 * side))
			_set_pose_deg(pose, "upper_arm_r", Vector3(96.0, 25.0 * side, -23.0 * side))
			_set_pose_deg(pose, "forearm_r", Vector3(-7.0, -7.0 * side, 5.0 * side))
			pose["__pelvis_offset"] = Vector3(-0.015 * side, -0.048 * w, -0.052 * w)
		_:
			_set_pose_deg(pose, "pelvis", Vector3(2.0, 1.0 * side, 0.0))
			_set_pose_deg(pose, "chest", Vector3(3.0, 2.0 * side, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(22.0, 2.0 * side, 7.0 * side))
			_set_pose_deg(pose, "forearm_r", Vector3(-21.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.02, -0.01)


func _build_mace_crush_pose(pose: Dictionary, stage: String, finisher: bool) -> void:
	var w: float = 1.10 if finisher else 1.0
	match stage:
		"windup":
			_set_pose_deg(pose, "pelvis", Vector3(6.0, -3.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(9.0, -3.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(106.0, -7.0, 13.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-46.0, 0.0, 0.0))
			_set_impact_stance(pose, 1.0, -0.9, true)
			pose["__pelvis_offset"] = Vector3(0.0, -0.07 * w, 0.02)
		"contact":
			_set_pose_deg(pose, "pelvis", Vector3(-7.0, 2.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(-13.0, 2.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(54.0, 5.0, 12.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-8.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.065 * w, -0.05 * w)
		"follow":
			_set_pose_deg(pose, "pelvis", Vector3(-9.0, 2.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(-16.0, 2.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(42.0, 6.0, 13.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.068 * w, -0.065 * w)
		_:
			_set_pose_deg(pose, "pelvis", Vector3(3.0, 0.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(5.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(22.0, 0.0, 7.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.024, -0.01)


func _impact_stance_phase(phase: float) -> float:
	return clampf(phase, -1.2, 1.2)


func _set_impact_stance(pose: Dictionary, side: float, phase: float, heavy: bool) -> void:
	var p: float = _impact_stance_phase(phase)
	var weight: float = 1.12 if heavy else 1.0
	_set_pose_deg(pose, "thigh_l", Vector3(12.0 * p * weight, 0.0, -4.0 - side * 2.0))
	_set_pose_deg(pose, "thigh_r", Vector3(-14.0 * p * weight, 0.0, 4.0 - side * 2.0))
	_set_pose_deg(pose, "shin_l", Vector3(18.0 + maxf(p, 0.0) * 6.0, 0.0, 0.0))
	_set_pose_deg(pose, "shin_r", Vector3(20.0 + maxf(-p, 0.0) * 6.0, 0.0, 0.0))


func _proxy_attack_index(attack_id: String) -> int:
	for marker: String in ["_h", "_l"]:
		var position: int = attack_id.rfind(marker)
		if position >= 0:
			var suffix: String = attack_id.substr(position + marker.length())
			if suffix.is_valid_int():
				return int(suffix)
	return 0


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["weapon_language_v3a"] = true
	var classes: Array = data.get("authored_language_classes", []) as Array
	for weapon_class: String in ["axe", "mace"]:
		if not classes.has(weapon_class):
			classes.append(weapon_class)
	data["authored_language_classes"] = classes
	data["axe_language"] = true
	data["mace_language"] = true
	return data
