extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_weapon_languages_v3a.gd"

# Weapon Language V3B: hand-to-hand pressure family.
# Gauntlets inherit Daggers' compact close-range rhythm, but replace evasive
# cutting with lead/cross/hook pressure and rising Heavy launchers.

var offhand_gauntlet_root: Node3D
var offhand_gauntlet_signature: String = ""


func _process(delta: float) -> void:
	super._process(delta)
	_update_offhand_gauntlet()


func _build_attack_stage_pose(attack: WeaponAttackDefinition, stage: String) -> Dictionary:
	if _get_equipped_weapon_class() == "gauntlets":
		return _build_gauntlet_attack_pose(attack, stage)
	return super._build_attack_stage_pose(attack, stage)


func _build_gauntlet_attack_pose(attack: WeaponAttackDefinition, stage: String) -> Dictionary:
	var pose: Dictionary = {}
	if attack == null:
		return pose
	var index: int = _proxy_attack_index(attack.attack_id)
	var heavy: bool = attack.input_kind == "heavy"
	if attack.extra_tags.has("aerial_heavy") or (heavy and index in [1, 3]):
		_build_gauntlet_rising_pose(pose, stage, index == 3)
	elif attack.extra_tags.has("dash_heavy") or (heavy and index == 0):
		_build_gauntlet_drive_pose(pose, stage, true)
	elif heavy and index == 2:
		_build_gauntlet_hook_pose(pose, stage, true)
	elif index == 2:
		_build_gauntlet_hook_pose(pose, stage, false)
	else:
		_build_gauntlet_straight_pose(pose, stage, index, heavy)
	return pose


func _build_gauntlet_straight_pose(
	pose: Dictionary,
	stage: String,
	index: int,
	heavy: bool
) -> void:
	var right: bool = index % 2 == 1
	var side: float = 1.0 if right else -1.0
	var w: float = 1.08 if heavy else 1.0
	match stage:
		"windup":
			_set_pose_deg(pose, "pelvis", Vector3(-4.0, -7.0 * side, 1.0 * side))
			_set_pose_deg(pose, "spine_01", Vector3(-5.0, -5.0 * side, -1.0 * side))
			_set_pose_deg(pose, "chest", Vector3(-7.0, -9.0 * side, -2.0 * side))
			_set_boxing_guard(pose, side, -1.0)
			_set_gauntlet_stance(pose, side, -1.0)
			pose["__pelvis_offset"] = Vector3(0.015 * side, -0.05, 0.02)
		"contact":
			_set_pose_deg(pose, "pelvis", Vector3(-8.0, 10.0 * side * w, -1.0 * side))
			_set_pose_deg(pose, "spine_01", Vector3(-10.0, 8.0 * side * w, 1.0 * side))
			_set_pose_deg(pose, "chest", Vector3(-13.0, 13.0 * side * w, 2.0 * side))
			_set_boxing_guard(pose, side, 1.0)
			_set_gauntlet_stance(pose, side, 1.0)
			pose["__pelvis_offset"] = Vector3(-0.018 * side, -0.045, -0.1 * w)
		"follow":
			_set_pose_deg(pose, "pelvis", Vector3(-9.0, 12.0 * side * w, -1.5 * side))
			_set_pose_deg(pose, "chest", Vector3(-15.0, 16.0 * side * w, 2.5 * side))
			_set_boxing_guard(pose, side, 1.12)
			pose["__pelvis_offset"] = Vector3(-0.02 * side, -0.04, -0.115 * w)
		_:
			_set_pose_deg(pose, "pelvis", Vector3(-2.0, 0.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(-3.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(18.0, 0.0, 12.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-46.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(18.0, 0.0, -12.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-46.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.025, -0.012)


func _build_gauntlet_hook_pose(pose: Dictionary, stage: String, heavy: bool) -> void:
	var w: float = 1.10 if heavy else 1.0
	match stage:
		"windup":
			_set_pose_deg(pose, "pelvis", Vector3(-5.0, -13.0, -2.0))
			_set_pose_deg(pose, "chest", Vector3(-7.0, -18.0, -3.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(54.0, -18.0, 38.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-68.0, 8.0, -10.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(20.0, 0.0, -14.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-50.0, 0.0, 0.0))
			_set_gauntlet_stance(pose, 1.0, -1.0)
			pose["__pelvis_offset"] = Vector3(0.025, -0.055, 0.025)
		"contact":
			_set_pose_deg(pose, "pelvis", Vector3(-10.0, 17.0 * w, 2.0))
			_set_pose_deg(pose, "chest", Vector3(-15.0, 25.0 * w, 4.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(88.0, 32.0, -22.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-36.0, -16.0, 8.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(18.0, 0.0, -14.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-48.0, 0.0, 0.0))
			_set_gauntlet_stance(pose, 1.0, 1.0)
			pose["__pelvis_offset"] = Vector3(-0.025, -0.05, -0.075 * w)
		"follow":
			_set_pose_deg(pose, "pelvis", Vector3(-11.0, 21.0 * w, 2.5))
			_set_pose_deg(pose, "chest", Vector3(-17.0, 30.0 * w, 5.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(95.0, 38.0, -25.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-28.0, -18.0, 10.0))
			pose["__pelvis_offset"] = Vector3(-0.03, -0.045, -0.09 * w)
		_:
			_build_gauntlet_straight_pose(pose, stage, 0, heavy)


func _build_gauntlet_rising_pose(pose: Dictionary, stage: String, finisher: bool) -> void:
	var w: float = 1.14 if finisher else 1.0
	match stage:
		"windup":
			_set_pose_deg(pose, "pelvis", Vector3(10.0, -5.0, 0.0))
			_set_pose_deg(pose, "spine_01", Vector3(11.0, -4.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(13.0, -6.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(28.0, -8.0, 18.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-72.0, 4.0, -5.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(20.0, 0.0, -14.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-50.0, 0.0, 0.0))
			_set_pose_deg(pose, "thigh_l", Vector3(-22.0, 0.0, -4.0))
			_set_pose_deg(pose, "thigh_r", Vector3(-18.0, 0.0, 4.0))
			_set_pose_deg(pose, "shin_l", Vector3(30.0, 0.0, 0.0))
			_set_pose_deg(pose, "shin_r", Vector3(27.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.095 * w, 0.025)
		"contact":
			_set_pose_deg(pose, "pelvis", Vector3(-9.0, 7.0, 0.0))
			_set_pose_deg(pose, "spine_01", Vector3(-12.0, 6.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(-17.0, 9.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(118.0, 8.0, -12.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-8.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(24.0, 0.0, -14.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-46.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.035, -0.08 * w)
		"follow":
			_set_pose_deg(pose, "pelvis", Vector3(-11.0, 8.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(-20.0, 11.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(132.0, 10.0, -14.0))
			_set_pose_deg(pose, "forearm_r", Vector3(4.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.025, -0.095 * w)
		_:
			_build_gauntlet_straight_pose(pose, stage, 0, true)


func _build_gauntlet_drive_pose(pose: Dictionary, stage: String, heavy: bool) -> void:
	_build_gauntlet_straight_pose(pose, stage, 1, heavy)
	if stage in ["contact", "follow"]:
		pose["__pelvis_offset"] = Vector3(0.0, -0.045, -0.15 if heavy else -0.12)


func _set_boxing_guard(pose: Dictionary, side: float, phase: float) -> void:
	var lead_right: bool = side > 0.0
	var lead_arm: String = "upper_arm_r" if lead_right else "upper_arm_l"
	var lead_forearm: String = "forearm_r" if lead_right else "forearm_l"
	var guard_arm: String = "upper_arm_l" if lead_right else "upper_arm_r"
	var guard_forearm: String = "forearm_l" if lead_right else "forearm_r"
	_set_pose_deg(pose, lead_arm, Vector3(50.0 + phase * 42.0, side * phase * 8.0, side * -12.0))
	_set_pose_deg(pose, lead_forearm, Vector3(-58.0 + phase * 48.0, 0.0, 0.0))
	_set_pose_deg(pose, guard_arm, Vector3(22.0, -side * 4.0, -side * 16.0))
	_set_pose_deg(pose, guard_forearm, Vector3(-55.0, 0.0, 0.0))


func _set_gauntlet_stance(pose: Dictionary, side: float, phase: float) -> void:
	_set_pose_deg(pose, "thigh_l", Vector3(14.0 * phase, 0.0, -5.0 - side * 2.0))
	_set_pose_deg(pose, "thigh_r", Vector3(-18.0 * phase, 0.0, 5.0 - side * 2.0))
	_set_pose_deg(pose, "shin_l", Vector3(22.0 + maxf(phase, 0.0) * 5.0, 0.0, 0.0))
	_set_pose_deg(pose, "shin_r", Vector3(25.0 + maxf(-phase, 0.0) * 5.0, 0.0, 0.0))


func _update_offhand_gauntlet() -> void:
	var active: bool = (
		_get_equipped_weapon_class() == "gauntlets"
		and skeleton != null
		and bones.has("hand_l")
	)
	if not active:
		if offhand_gauntlet_root != null:
			offhand_gauntlet_root.visible = false
		return
	_ensure_offhand_gauntlet()
	if offhand_gauntlet_root == null:
		return
	offhand_gauntlet_root.visible = true
	var hand_pose: Transform3D = skeleton.get_bone_global_pose(int(bones["hand_l"]))
	offhand_gauntlet_root.transform = hand_pose * Transform3D(Basis.IDENTITY, Vector3(0.0, -0.02, -0.035))


func _ensure_offhand_gauntlet() -> void:
	if weapon_controller == null or weapon_controller.equipped_weapon == null:
		return
	var weapon: WeaponDefinition = weapon_controller.equipped_weapon
	var signature: String = str(weapon.visual_primary_color) + str(weapon.visual_accent_color)
	if offhand_gauntlet_root != null and signature == offhand_gauntlet_signature:
		return
	if offhand_gauntlet_root != null:
		offhand_gauntlet_root.queue_free()
	offhand_gauntlet_root = Node3D.new()
	offhand_gauntlet_root.name = "SkeletalOffhandGauntlet"
	add_child(offhand_gauntlet_root)
	offhand_gauntlet_signature = signature

	var forearm := MeshInstance3D.new()
	var forearm_mesh := BoxMesh.new()
	forearm_mesh.size = Vector3(0.28, 0.28, 0.46)
	forearm.mesh = forearm_mesh
	forearm.position = Vector3(0.0, 0.0, 0.1)
	forearm.material_override = _dagger_material(weapon.visual_secondary_color, false)
	offhand_gauntlet_root.add_child(forearm)

	var fist := MeshInstance3D.new()
	var fist_mesh := BoxMesh.new()
	fist_mesh.size = Vector3(0.38, 0.34, 0.38)
	fist.mesh = fist_mesh
	fist.position = Vector3(0.0, 0.0, -0.3)
	fist.material_override = _dagger_material(weapon.visual_primary_color, true)
	offhand_gauntlet_root.add_child(fist)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["weapon_language_v3b"] = true
	var classes: Array = data.get("authored_language_classes", []) as Array
	if not classes.has("gauntlets"):
		classes.append("gauntlets")
	data["authored_language_classes"] = classes
	data["gauntlet_language"] = true
	data["gauntlet_offhand_socket"] = offhand_gauntlet_root != null
	return data
