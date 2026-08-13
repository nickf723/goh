extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_v1.gd"

# Active skeletal combat proxy.
# Keeps authored bone rest translations intact, preserves pelvis rest height,
# and supplies the first deliberately authored Sword combat language.


func _build_skeleton() -> void:
	super._build_skeleton()
	if skeleton == null:
		return
	skeleton.reset_bone_poses()
	for bone_name_variant: Variant in bones.keys():
		var bone_name: String = str(bone_name_variant)
		var index: int = int(bones[bone_name])
		current_rotations[bone_name] = skeleton.get_bone_pose_rotation(index)


func _blend_skeleton_pose(
	targets: Dictionary,
	pelvis_offset: Vector3,
	delta: float
) -> void:
	var blend: float = 1.0 if delta <= 0.0 else 1.0 - exp(-pose_response * delta)
	blend = clampf(blend, 0.0, 1.0)

	for bone_name_variant: Variant in bones.keys():
		var bone_name: String = str(bone_name_variant)
		var index: int = int(bones[bone_name])
		var target_euler: Vector3 = targets.get(bone_name, Vector3.ZERO) as Vector3
		var target_rotation: Quaternion = Basis.from_euler(target_euler).get_rotation_quaternion()
		var current: Quaternion = current_rotations.get(
			bone_name,
			Quaternion.IDENTITY
		) as Quaternion
		current = current.slerp(target_rotation, blend).normalized()
		current_rotations[bone_name] = current
		skeleton.set_bone_pose_rotation(index, current)

	current_pelvis_offset = current_pelvis_offset.lerp(pelvis_offset, blend)
	if bones.has("pelvis"):
		var pelvis_index: int = int(bones["pelvis"])
		var pelvis_rest_position: Vector3 = skeleton.get_bone_rest(pelvis_index).origin
		skeleton.set_bone_pose_position(
			pelvis_index,
			pelvis_rest_position + current_pelvis_offset
		)


# Sword-only authoring layer. Other classes keep the generic skeletal proxy until
# each class earns its own animation language. The Sword establishes the quality
# bar: readable exaggeration, working-space windups, restrained follow-through.
func _build_attack_stage_pose(attack: WeaponAttackDefinition, stage: String) -> Dictionary:
	if not _is_sword_attack(attack):
		return super._build_attack_stage_pose(attack, stage)

	var pose: Dictionary = {}
	if attack == null:
		return pose
	if attack.extra_tags.has("dash_light"):
		_build_sword_dash_pose(pose, stage, false)
		return pose
	if attack.extra_tags.has("dash_heavy"):
		_build_sword_dash_pose(pose, stage, true)
		return pose
	if attack.extra_tags.has("aerial_light"):
		_build_sword_aerial_pose(pose, stage, false)
		return pose
	if attack.extra_tags.has("aerial_heavy"):
		_build_sword_aerial_pose(pose, stage, true)
		return pose

	var profile: String = attack.character_pose_id.to_lower()
	var attack_name: String = attack.attack_id.to_lower()
	var side: float = _attack_side(attack)
	var heavy: bool = attack.input_kind == "heavy"
	var is_thrust: bool = (
		profile.contains("thrust")
		or attack.extra_tags.has("thrust")
		or attack.extra_tags.has("pierce")
	)
	var is_overhead: bool = profile.contains("overhead") or attack_name == "sword_h0"
	var is_rising: bool = profile.contains("rising") or attack.extra_tags.has("launcher")
	var is_wide: bool = (
		profile.contains("spin")
		or profile.contains("orbit")
		or profile.contains("cleave")
		or attack.extra_tags.has("spin")
		or attack.extra_tags.has("cleave")
	)

	if is_thrust:
		_build_refined_sword_thrust_pose(pose, stage, heavy)
	elif is_overhead:
		_build_refined_sword_overhead_pose(pose, stage, heavy)
	elif is_rising:
		_build_refined_sword_rising_pose(pose, stage, side, heavy)
	else:
		_build_refined_sword_cut_pose(pose, stage, side, is_wide, heavy)
	return pose


func _is_sword_attack(attack: WeaponAttackDefinition) -> bool:
	return (
		attack != null
		and weapon_controller != null
		and weapon_controller.equipped_weapon != null
		and weapon_controller.equipped_weapon.weapon_class == "sword"
	)


func _build_refined_sword_cut_pose(
	pose: Dictionary,
	stage: String,
	side: float,
	wide: bool,
	heavy: bool
) -> void:
	var weight: float = 1.1 if heavy else 1.0
	var width: float = 1.14 if wide else 1.0
	match stage:
		"windup":
			_set_pose_deg(pose, "pelvis", Vector3(2.0, -8.0 * side * width, -1.5 * side))
			_set_pose_deg(pose, "spine_01", Vector3(-1.0, -5.0 * side * width, 1.5 * side))
			_set_pose_deg(pose, "spine_02", Vector3(-2.0, -8.0 * side * width, 2.0 * side))
			_set_pose_deg(pose, "chest", Vector3(-3.0, -12.0 * side * width, 3.0 * side))
			_set_pose_deg(pose, "head", Vector3(0.0, 5.0 * side, -1.0 * side))
			_set_pose_deg(pose, "clavicle_r", Vector3(0.0, -5.0 * side, 5.0 * side))
			_set_pose_deg(pose, "upper_arm_r", Vector3(48.0, -12.0 * side, 20.0 * side))
			_set_pose_deg(pose, "forearm_r", Vector3(-28.0, 7.0 * side, -7.0 * side))
			_set_pose_deg(pose, "hand_r", Vector3(-6.0, -8.0 * side, 8.0 * side))
			_set_pose_deg(pose, "upper_arm_l", Vector3(14.0, 5.0 * side, -12.0 * side))
			_set_pose_deg(pose, "forearm_l", Vector3(-14.0, 0.0, 0.0))
			_apply_cut_leg_pose(pose, side, -0.72)
			pose["__pelvis_offset"] = Vector3(0.012 * side, -0.025 * weight, 0.015)
		"contact":
			_set_pose_deg(pose, "pelvis", Vector3(-2.0, 10.0 * side * width * weight, 1.5 * side))
			_set_pose_deg(pose, "spine_01", Vector3(-3.0, 8.0 * side * width * weight, -1.5 * side))
			_set_pose_deg(pose, "spine_02", Vector3(-4.0, 13.0 * side * width * weight, -2.0 * side))
			_set_pose_deg(pose, "chest", Vector3(-5.0, 20.0 * side * width * weight, -3.0 * side))
			_set_pose_deg(pose, "head", Vector3(-1.0, -6.0 * side, 1.0 * side))
			_set_pose_deg(pose, "clavicle_r", Vector3(0.0, 7.0 * side, -5.0 * side))
			_set_pose_deg(pose, "upper_arm_r", Vector3(76.0, 22.0 * side, -18.0 * side))
			_set_pose_deg(pose, "forearm_r", Vector3(-8.0, -8.0 * side, 6.0 * side))
			_set_pose_deg(pose, "hand_r", Vector3(4.0, 9.0 * side, -9.0 * side))
			_set_pose_deg(pose, "upper_arm_l", Vector3(25.0, -7.0 * side, 17.0 * side))
			_set_pose_deg(pose, "forearm_l", Vector3(-20.0, 0.0, 0.0))
			_apply_cut_leg_pose(pose, side, 0.82)
			pose["__pelvis_offset"] = Vector3(-0.014 * side, -0.035 * weight, -0.045 * weight)
		"follow":
			_set_pose_deg(pose, "pelvis", Vector3(-3.0, 14.0 * side * width * weight, 2.0 * side))
			_set_pose_deg(pose, "spine_01", Vector3(-4.0, 11.0 * side * width * weight, -2.0 * side))
			_set_pose_deg(pose, "spine_02", Vector3(-5.0, 16.0 * side * width * weight, -3.0 * side))
			_set_pose_deg(pose, "chest", Vector3(-6.0, 26.0 * side * width * weight, -4.0 * side))
			_set_pose_deg(pose, "head", Vector3(-2.0, -9.0 * side, 1.0 * side))
			_set_pose_deg(pose, "upper_arm_r", Vector3(86.0, 28.0 * side, -22.0 * side))
			_set_pose_deg(pose, "forearm_r", Vector3(2.0, -10.0 * side, 7.0 * side))
			_set_pose_deg(pose, "hand_r", Vector3(7.0, 11.0 * side, -11.0 * side))
			_set_pose_deg(pose, "upper_arm_l", Vector3(30.0, -8.0 * side, 20.0 * side))
			_apply_cut_leg_pose(pose, side, 0.92)
			pose["__pelvis_offset"] = Vector3(-0.018 * side, -0.04 * weight, -0.058 * weight)
		_:
			_set_pose_deg(pose, "pelvis", Vector3(1.0, 2.0 * side, 0.0))
			_set_pose_deg(pose, "spine_01", Vector3(2.0, 1.5 * side, 0.0))
			_set_pose_deg(pose, "spine_02", Vector3(2.0, 2.0 * side, 0.0))
			_set_pose_deg(pose, "chest", Vector3(3.0, 3.5 * side, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(16.0, 3.0 * side, 4.0 * side))
			_set_pose_deg(pose, "forearm_r", Vector3(-14.0, 0.0, 0.0))
			_set_pose_deg(pose, "thigh_l", Vector3(-3.0, 0.0, 0.0))
			_set_pose_deg(pose, "thigh_r", Vector3(4.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.012, -0.008)


func _build_refined_sword_thrust_pose(pose: Dictionary, stage: String, heavy: bool) -> void:
	var weight: float = 1.12 if heavy else 1.0
	match stage:
		"windup":
			_set_pose_deg(pose, "pelvis", Vector3(3.0, -4.0, 0.0))
			_set_pose_deg(pose, "spine_01", Vector3(2.0, -4.0, 0.0))
			_set_pose_deg(pose, "spine_02", Vector3(1.0, -5.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(0.0, -6.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(46.0, -14.0, 12.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-56.0, 6.0, -4.0))
			_set_pose_deg(pose, "hand_r", Vector3(-5.0, -3.0, 0.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(28.0, 6.0, -14.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-28.0, 0.0, 0.0))
			_set_pose_deg(pose, "thigh_l", Vector3(-11.0, 0.0, -2.0))
			_set_pose_deg(pose, "thigh_r", Vector3(15.0, 0.0, 2.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.03, 0.038)
		"contact":
			_set_pose_deg(pose, "pelvis", Vector3(-4.0, 6.0, 0.0))
			_set_pose_deg(pose, "spine_01", Vector3(-5.0, 5.0, 0.0))
			_set_pose_deg(pose, "spine_02", Vector3(-6.0, 5.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(-8.0, 5.0, 0.0))
			_set_pose_deg(pose, "head", Vector3(2.0, -2.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(82.0, 2.0, -4.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-4.0, 0.0, 0.0))
			_set_pose_deg(pose, "hand_r", Vector3(0.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(48.0, -3.0, -8.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-16.0, 0.0, 0.0))
			_set_pose_deg(pose, "thigh_l", Vector3(14.0, 0.0, -1.0))
			_set_pose_deg(pose, "thigh_r", Vector3(-18.0, 0.0, 1.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.025, -0.09 * weight)
		"follow":
			_set_pose_deg(pose, "pelvis", Vector3(-5.0, 7.0, 0.0))
			_set_pose_deg(pose, "spine_01", Vector3(-6.0, 6.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(-10.0, 6.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(88.0, 3.0, -4.0))
			_set_pose_deg(pose, "forearm_r", Vector3(2.0, 0.0, 0.0))
			_set_pose_deg(pose, "thigh_l", Vector3(17.0, 0.0, 0.0))
			_set_pose_deg(pose, "thigh_r", Vector3(-21.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.03, -0.11 * weight)
		_:
			_set_pose_deg(pose, "pelvis", Vector3(2.0, 1.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(3.0, 1.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(15.0, 0.0, 3.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-14.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.012, -0.012)


func _build_refined_sword_overhead_pose(pose: Dictionary, stage: String, heavy: bool) -> void:
	var weight: float = 1.1 if heavy else 1.0
	match stage:
		"windup":
			_set_pose_deg(pose, "pelvis", Vector3(6.0, -3.0, 0.0))
			_set_pose_deg(pose, "spine_01", Vector3(6.0, -2.0, 0.0))
			_set_pose_deg(pose, "spine_02", Vector3(7.0, -2.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(8.0, -2.0, 0.0))
			_set_pose_deg(pose, "head", Vector3(-4.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(118.0, -6.0, 9.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-28.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(104.0, 6.0, -13.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-38.0, 0.0, 0.0))
			_set_pose_deg(pose, "thigh_l", Vector3(-12.0, 0.0, -3.0))
			_set_pose_deg(pose, "thigh_r", Vector3(-10.0, 0.0, 3.0))
			_set_pose_deg(pose, "shin_l", Vector3(18.0, 0.0, 0.0))
			_set_pose_deg(pose, "shin_r", Vector3(16.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.065, 0.018)
		"contact":
			_set_pose_deg(pose, "pelvis", Vector3(-7.0, 3.0, 0.0))
			_set_pose_deg(pose, "spine_01", Vector3(-8.0, 3.0, 0.0))
			_set_pose_deg(pose, "spine_02", Vector3(-10.0, 2.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(-13.0, 2.0, 0.0))
			_set_pose_deg(pose, "head", Vector3(5.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(62.0, 4.0, 9.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-7.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(68.0, -3.0, -10.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-14.0, 0.0, 0.0))
			_set_pose_deg(pose, "thigh_l", Vector3(7.0, 0.0, -2.0))
			_set_pose_deg(pose, "thigh_r", Vector3(6.0, 0.0, 2.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.06, -0.05 * weight)
		"follow":
			_set_pose_deg(pose, "pelvis", Vector3(-9.0, 4.0, 0.0))
			_set_pose_deg(pose, "spine_01", Vector3(-10.0, 3.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(-16.0, 3.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(44.0, 5.0, 10.0))
			_set_pose_deg(pose, "forearm_r", Vector3(5.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(48.0, -4.0, -10.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.065, -0.065 * weight)
		_:
			_set_pose_deg(pose, "pelvis", Vector3(3.0, 0.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(4.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(17.0, 0.0, 4.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-14.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.016, -0.01)


func _build_refined_sword_rising_pose(
	pose: Dictionary,
	stage: String,
	side: float,
	heavy: bool
) -> void:
	var weight: float = 1.1 if heavy else 1.0
	match stage:
		"windup":
			_set_pose_deg(pose, "pelvis", Vector3(6.0, -7.0 * side, 3.0 * side))
			_set_pose_deg(pose, "spine_01", Vector3(5.0, -5.0 * side, 2.0 * side))
			_set_pose_deg(pose, "chest", Vector3(6.0, -9.0 * side, 4.0 * side))
			_set_pose_deg(pose, "upper_arm_r", Vector3(38.0, -16.0 * side, 32.0 * side))
			_set_pose_deg(pose, "forearm_r", Vector3(-36.0, 6.0 * side, -8.0 * side))
			_set_pose_deg(pose, "thigh_l", Vector3(-16.0, 0.0, -3.0))
			_set_pose_deg(pose, "thigh_r", Vector3(-9.0, 0.0, 3.0))
			_set_pose_deg(pose, "shin_l", Vector3(23.0, 0.0, 0.0))
			_set_pose_deg(pose, "shin_r", Vector3(17.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.014 * side, -0.07, 0.022)
		"contact":
			_set_pose_deg(pose, "pelvis", Vector3(-5.0, 9.0 * side, -3.0 * side))
			_set_pose_deg(pose, "spine_01", Vector3(-6.0, 7.0 * side, -2.0 * side))
			_set_pose_deg(pose, "spine_02", Vector3(-7.0, 10.0 * side, -3.0 * side))
			_set_pose_deg(pose, "chest", Vector3(-9.0, 14.0 * side, -4.0 * side))
			_set_pose_deg(pose, "upper_arm_r", Vector3(84.0, 14.0 * side, -24.0 * side))
			_set_pose_deg(pose, "forearm_r", Vector3(-10.0, -6.0 * side, 7.0 * side))
			_set_pose_deg(pose, "thigh_l", Vector3(8.0, 0.0, -2.0))
			_set_pose_deg(pose, "thigh_r", Vector3(5.0, 0.0, 2.0))
			pose["__pelvis_offset"] = Vector3(-0.012 * side, -0.055, -0.045 * weight)
		"follow":
			_set_pose_deg(pose, "pelvis", Vector3(-7.0, 12.0 * side, -3.0 * side))
			_set_pose_deg(pose, "spine_01", Vector3(-8.0, 9.0 * side, -3.0 * side))
			_set_pose_deg(pose, "chest", Vector3(-12.0, 18.0 * side, -5.0 * side))
			_set_pose_deg(pose, "upper_arm_r", Vector3(94.0, 18.0 * side, -28.0 * side))
			_set_pose_deg(pose, "forearm_r", Vector3(2.0, -8.0 * side, 8.0 * side))
			pose["__pelvis_offset"] = Vector3(-0.014 * side, -0.05, -0.055 * weight)
		_:
			_set_pose_deg(pose, "pelvis", Vector3(2.0, 2.0 * side, 0.0))
			_set_pose_deg(pose, "chest", Vector3(3.0, 3.0 * side, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(17.0, 2.0 * side, 5.0 * side))
			_set_pose_deg(pose, "forearm_r", Vector3(-14.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.014, -0.01)


func _build_sword_dash_pose(pose: Dictionary, stage: String, heavy: bool) -> void:
	if heavy:
		match stage:
			"windup":
				_set_pose_deg(pose, "pelvis", Vector3(6.0, -7.0, -2.0))
				_set_pose_deg(pose, "spine_01", Vector3(5.0, -6.0, 2.0))
				_set_pose_deg(pose, "chest", Vector3(4.0, -10.0, 3.0))
				_set_pose_deg(pose, "upper_arm_r", Vector3(42.0, -16.0, 24.0))
				_set_pose_deg(pose, "forearm_r", Vector3(-30.0, 6.0, -6.0))
				_set_pose_deg(pose, "thigh_l", Vector3(-18.0, 0.0, -3.0))
				_set_pose_deg(pose, "thigh_r", Vector3(14.0, 0.0, 3.0))
				pose["__pelvis_offset"] = Vector3(0.0, -0.045, 0.035)
			"contact":
				_set_pose_deg(pose, "pelvis", Vector3(-6.0, 11.0, 2.0))
				_set_pose_deg(pose, "spine_01", Vector3(-8.0, 9.0, -2.0))
				_set_pose_deg(pose, "chest", Vector3(-12.0, 17.0, -3.0))
				_set_pose_deg(pose, "upper_arm_r", Vector3(80.0, 20.0, -20.0))
				_set_pose_deg(pose, "forearm_r", Vector3(-6.0, -8.0, 5.0))
				_set_pose_deg(pose, "thigh_l", Vector3(16.0, 0.0, -2.0))
				_set_pose_deg(pose, "thigh_r", Vector3(-20.0, 0.0, 2.0))
				pose["__pelvis_offset"] = Vector3(0.0, -0.035, -0.1)
			"follow":
				_set_pose_deg(pose, "pelvis", Vector3(-7.0, 14.0, 2.0))
				_set_pose_deg(pose, "chest", Vector3(-14.0, 21.0, -4.0))
				_set_pose_deg(pose, "upper_arm_r", Vector3(88.0, 25.0, -23.0))
				_set_pose_deg(pose, "forearm_r", Vector3(3.0, -9.0, 6.0))
				pose["__pelvis_offset"] = Vector3(0.0, -0.035, -0.12)
			_:
				_build_refined_sword_cut_pose(pose, "recover", 1.0, false, true)
		return

	match stage:
		"windup":
			_set_pose_deg(pose, "pelvis", Vector3(4.0, -5.0, -1.0))
			_set_pose_deg(pose, "spine_01", Vector3(3.0, -4.0, 1.0))
			_set_pose_deg(pose, "chest", Vector3(2.0, -7.0, 2.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(34.0, -12.0, 18.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-24.0, 5.0, -5.0))
			_set_pose_deg(pose, "thigh_l", Vector3(-12.0, 0.0, -2.0))
			_set_pose_deg(pose, "thigh_r", Vector3(10.0, 0.0, 2.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.028, 0.025)
		"contact":
			_set_pose_deg(pose, "pelvis", Vector3(-4.0, 8.0, 1.0))
			_set_pose_deg(pose, "spine_01", Vector3(-5.0, 7.0, -1.0))
			_set_pose_deg(pose, "chest", Vector3(-8.0, 13.0, -2.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(70.0, 17.0, -15.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-7.0, -6.0, 4.0))
			_set_pose_deg(pose, "thigh_l", Vector3(12.0, 0.0, -1.0))
			_set_pose_deg(pose, "thigh_r", Vector3(-15.0, 0.0, 1.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.025, -0.085)
		"follow":
			_set_pose_deg(pose, "pelvis", Vector3(-5.0, 11.0, 1.0))
			_set_pose_deg(pose, "chest", Vector3(-9.0, 17.0, -3.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(78.0, 21.0, -18.0))
			_set_pose_deg(pose, "forearm_r", Vector3(1.0, -7.0, 5.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.025, -0.1)
		_:
			_build_refined_sword_cut_pose(pose, "recover", 1.0, false, false)


func _build_sword_aerial_pose(pose: Dictionary, stage: String, heavy: bool) -> void:
	if heavy:
		match stage:
			"windup":
				_set_pose_deg(pose, "pelvis", Vector3(5.0, -4.0, 0.0))
				_set_pose_deg(pose, "spine_01", Vector3(6.0, -3.0, 0.0))
				_set_pose_deg(pose, "chest", Vector3(8.0, -4.0, 0.0))
				_set_pose_deg(pose, "upper_arm_r", Vector3(108.0, -8.0, 10.0))
				_set_pose_deg(pose, "forearm_r", Vector3(-26.0, 0.0, 0.0))
				_set_pose_deg(pose, "upper_arm_l", Vector3(94.0, 6.0, -12.0))
				_set_pose_deg(pose, "forearm_l", Vector3(-34.0, 0.0, 0.0))
				_set_pose_deg(pose, "thigh_l", Vector3(24.0, 0.0, -3.0))
				_set_pose_deg(pose, "thigh_r", Vector3(17.0, 0.0, 3.0))
				_set_pose_deg(pose, "shin_l", Vector3(32.0, 0.0, 0.0))
				_set_pose_deg(pose, "shin_r", Vector3(26.0, 0.0, 0.0))
				pose["__pelvis_offset"] = Vector3(0.0, 0.015, 0.0)
			"contact":
				_set_pose_deg(pose, "pelvis", Vector3(-8.0, 4.0, 0.0))
				_set_pose_deg(pose, "spine_01", Vector3(-10.0, 3.0, 0.0))
				_set_pose_deg(pose, "chest", Vector3(-15.0, 3.0, 0.0))
				_set_pose_deg(pose, "upper_arm_r", Vector3(56.0, 5.0, 10.0))
				_set_pose_deg(pose, "forearm_r", Vector3(-6.0, 0.0, 0.0))
				_set_pose_deg(pose, "upper_arm_l", Vector3(62.0, -3.0, -10.0))
				_set_pose_deg(pose, "thigh_l", Vector3(12.0, 0.0, -2.0))
				_set_pose_deg(pose, "thigh_r", Vector3(10.0, 0.0, 2.0))
				pose["__pelvis_offset"] = Vector3(0.0, -0.045, -0.035)
			"follow":
				_set_pose_deg(pose, "pelvis", Vector3(-10.0, 5.0, 0.0))
				_set_pose_deg(pose, "chest", Vector3(-18.0, 4.0, 0.0))
				_set_pose_deg(pose, "upper_arm_r", Vector3(42.0, 6.0, 11.0))
				_set_pose_deg(pose, "forearm_r", Vector3(5.0, 0.0, 0.0))
				pose["__pelvis_offset"] = Vector3(0.0, -0.055, -0.045)
			_:
				_build_refined_sword_overhead_pose(pose, "recover", true)
		return

	match stage:
		"windup":
			_set_pose_deg(pose, "pelvis", Vector3(1.0, -7.0, -2.0))
			_set_pose_deg(pose, "spine_01", Vector3(-2.0, -6.0, 2.0))
			_set_pose_deg(pose, "chest", Vector3(-4.0, -10.0, 3.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(46.0, -14.0, 22.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-28.0, 7.0, -6.0))
			_set_pose_deg(pose, "thigh_l", Vector3(22.0, 0.0, -3.0))
			_set_pose_deg(pose, "thigh_r", Vector3(-8.0, 0.0, 3.0))
			_set_pose_deg(pose, "shin_l", Vector3(28.0, 0.0, 0.0))
			_set_pose_deg(pose, "shin_r", Vector3(18.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, 0.02, 0.02)
		"contact":
			_set_pose_deg(pose, "pelvis", Vector3(-4.0, 9.0, 2.0))
			_set_pose_deg(pose, "spine_01", Vector3(-6.0, 7.0, -2.0))
			_set_pose_deg(pose, "chest", Vector3(-9.0, 14.0, -3.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(78.0, 18.0, -18.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-7.0, -7.0, 5.0))
			_set_pose_deg(pose, "thigh_l", Vector3(12.0, 0.0, -2.0))
			_set_pose_deg(pose, "thigh_r", Vector3(-16.0, 0.0, 2.0))
			pose["__pelvis_offset"] = Vector3(0.0, 0.0, -0.055)
		"follow":
			_set_pose_deg(pose, "pelvis", Vector3(-5.0, 12.0, 2.0))
			_set_pose_deg(pose, "chest", Vector3(-11.0, 18.0, -4.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(86.0, 22.0, -21.0))
			_set_pose_deg(pose, "forearm_r", Vector3(2.0, -8.0, 6.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.01, -0.068)
		_:
			_build_refined_sword_cut_pose(pose, "recover", 1.0, false, false)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	if skeleton == null:
		return data

	var foot_height: float = INF
	for foot_name: String in ["foot_l", "foot_r"]:
		if bones.has(foot_name):
			foot_height = minf(
				foot_height,
				skeleton.get_bone_global_pose(int(bones[foot_name])).origin.y
			)
	if foot_height == INF:
		foot_height = 0.0

	var head_height: float = 0.0
	if bones.has("head"):
		head_height = skeleton.get_bone_global_pose(int(bones["head"])).origin.y

	var pelvis_rest_height: float = 0.0
	var pelvis_pose_height: float = 0.0
	if bones.has("pelvis"):
		var pelvis_index: int = int(bones["pelvis"])
		pelvis_rest_height = skeleton.get_bone_rest(pelvis_index).origin.y
		pelvis_pose_height = skeleton.get_bone_pose_position(pelvis_index).y

	var hand_span: float = 0.0
	if bones.has("hand_l") and bones.has("hand_r"):
		var left_hand: Vector3 = skeleton.get_bone_global_pose(int(bones["hand_l"])).origin
		var right_hand: Vector3 = skeleton.get_bone_global_pose(int(bones["hand_r"])).origin
		hand_span = left_hand.distance_to(right_hand)

	var leg_span: float = 0.0
	if bones.has("thigh_l") and bones.has("foot_l"):
		var thigh: Vector3 = skeleton.get_bone_global_pose(int(bones["thigh_l"])).origin
		var foot: Vector3 = skeleton.get_bone_global_pose(int(bones["foot_l"])).origin
		leg_span = thigh.distance_to(foot)

	data["grounding_fix"] = true
	data["rest_pose_initialized"] = true
	data["sword_combo_polish"] = true
	data["sword_working_envelope"] = true
	data["foot_height"] = snappedf(foot_height, 0.001)
	data["head_height"] = snappedf(head_height, 0.001)
	data["head_to_foot_span"] = snappedf(head_height - foot_height, 0.001)
	data["hand_span"] = snappedf(hand_span, 0.001)
	data["leg_span"] = snappedf(leg_span, 0.001)
	data["pelvis_rest_height"] = snappedf(pelvis_rest_height, 0.001)
	data["pelvis_pose_height"] = snappedf(pelvis_pose_height, 0.001)
	data["pelvis_rest_preserved"] = absf(
		pelvis_pose_height - (pelvis_rest_height + current_pelvis_offset.y)
	) < 0.0015
	return data
