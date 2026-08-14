extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_weapon_languages_v4l.gd"

# V4M gives the authored blue Axe its own body language. Side hews are driven by
# hips and recovery momentum; vertical attacks roll the wrists so the blade edge
# remains in the swing plane; the charged lever-vault is compressed into one
# smooth plant, rise, extraction, corkscrew, and second downstroke.


func _build_attack_stage_pose(
	attack: WeaponAttackDefinition,
	stage: String
) -> Dictionary:
	if _get_equipped_weapon_class() != "axe" or attack == null:
		return super._build_attack_stage_pose(attack, stage)
	if attack.extra_tags.has("axe_charge_ready"):
		return _build_axe_focus_charge_ready_pose()
	if attack.extra_tags.has("axe_lever_vault"):
		return _build_axe_focus_lever_pose(attack, stage)
	if attack.extra_tags.has("axe_rising"):
		return _build_axe_focus_rising_pose(stage)
	if (
		attack.extra_tags.has("axe_overhead")
		or attack.extra_tags.has("axe_edge_aligned")
		or attack.extra_tags.has("ground_slam")
	):
		return _build_axe_focus_overhead_pose(stage, attack.extra_tags.has("execution"))
	return _build_axe_focus_side_pose(
		stage,
		_attack_side(attack),
		attack.input_kind == "heavy",
		attack.extra_tags.has("axe_broad_hew")
	)


func _build_axe_focus_side_pose(
	stage: String,
	side: float,
	heavy: bool,
	broad: bool
) -> Dictionary:
	var pose: Dictionary = {}
	var weight: float = 1.17 if heavy else 1.0
	var width: float = 1.2 if broad else 1.0
	match stage:
		"windup":
			_set_pose_deg(pose, "pelvis", Vector3(7.0, -18.0 * side * width, 3.0 * side))
			_set_pose_deg(pose, "spine_01", Vector3(6.0, -12.0 * side * width, -2.0 * side))
			_set_pose_deg(pose, "spine_02", Vector3(7.0, -17.0 * side * width, -3.0 * side))
			_set_pose_deg(pose, "chest", Vector3(9.0, -24.0 * side * width, -4.0 * side))
			_set_pose_deg(pose, "head", Vector3(-3.0, 9.0 * side, 1.0 * side))
			_set_pose_deg(pose, "upper_arm_r", Vector3(66.0, -21.0 * side, 27.0 * side))
			_set_pose_deg(pose, "forearm_r", Vector3(-46.0, 8.0 * side, -7.0 * side))
			_set_pose_deg(pose, "hand_r", Vector3(-7.0, -4.0 * side, 8.0 * side))
			_set_pose_deg(pose, "upper_arm_l", Vector3(28.0, 8.0 * side, -22.0 * side))
			_set_pose_deg(pose, "forearm_l", Vector3(-25.0, 0.0, 0.0))
			_set_pose_deg(pose, "thigh_l", Vector3(-17.0 * weight, 0.0, -6.0))
			_set_pose_deg(pose, "thigh_r", Vector3(19.0 * weight, 0.0, 6.0))
			_set_pose_deg(pose, "shin_l", Vector3(24.0 * weight, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.02 * side, -0.06 * weight, 0.03)
		"contact":
			_set_pose_deg(pose, "pelvis", Vector3(-9.0, 22.0 * side * width * weight, -3.0 * side))
			_set_pose_deg(pose, "spine_01", Vector3(-11.0, 16.0 * side * width * weight, 2.0 * side))
			_set_pose_deg(pose, "spine_02", Vector3(-13.0, 22.0 * side * width * weight, 3.0 * side))
			_set_pose_deg(pose, "chest", Vector3(-17.0, 32.0 * side * width * weight, 4.0 * side))
			_set_pose_deg(pose, "head", Vector3(4.0, -10.0 * side, -1.0 * side))
			_set_pose_deg(pose, "upper_arm_r", Vector3(96.0, 28.0 * side, -24.0 * side))
			_set_pose_deg(pose, "forearm_r", Vector3(-11.0, -8.0 * side, 6.0 * side))
			_set_pose_deg(pose, "hand_r", Vector3(5.0, 4.0 * side, -8.0 * side))
			_set_pose_deg(pose, "upper_arm_l", Vector3(38.0, -10.0 * side, 24.0 * side))
			_set_pose_deg(pose, "forearm_l", Vector3(-20.0, 0.0, 0.0))
			_set_pose_deg(pose, "thigh_l", Vector3(17.0 * weight, 0.0, -5.0))
			_set_pose_deg(pose, "thigh_r", Vector3(-21.0 * weight, 0.0, 5.0))
			_set_pose_deg(pose, "shin_r", Vector3(27.0 * weight, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(-0.025 * side, -0.065 * weight, -0.075 * weight)
		"follow":
			_set_pose_deg(pose, "pelvis", Vector3(-12.0, 30.0 * side * width * weight, -4.0 * side))
			_set_pose_deg(pose, "chest", Vector3(-21.0, 43.0 * side * width * weight, 5.0 * side))
			_set_pose_deg(pose, "upper_arm_r", Vector3(110.0, 39.0 * side, -30.0 * side))
			_set_pose_deg(pose, "forearm_r", Vector3(2.0, -11.0 * side, 8.0 * side))
			_set_pose_deg(pose, "upper_arm_l", Vector3(45.0, -14.0 * side, 29.0 * side))
			pose["__pelvis_offset"] = Vector3(-0.032 * side, -0.067 * weight, -0.105 * weight)
		_:
			_set_pose_deg(pose, "pelvis", Vector3(4.0, 3.0 * side, 0.0))
			_set_pose_deg(pose, "chest", Vector3(6.0, 5.0 * side, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(27.0, 4.0 * side, 9.0 * side))
			_set_pose_deg(pose, "forearm_r", Vector3(-24.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(18.0, -2.0 * side, -8.0 * side))
			pose["__pelvis_offset"] = Vector3(0.0, -0.025, -0.015)
	return pose


func _build_axe_focus_overhead_pose(
	stage: String,
	finisher: bool
) -> Dictionary:
	var pose: Dictionary = {}
	var power: float = 1.16 if finisher else 1.0
	match stage:
		"windup":
			_set_pose_deg(pose, "pelvis", Vector3(11.0, -4.0, 0.0))
			_set_pose_deg(pose, "spine_01", Vector3(12.0, -3.0, 0.0))
			_set_pose_deg(pose, "spine_02", Vector3(15.0, -3.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(19.0, -3.0, 0.0))
			_set_pose_deg(pose, "head", Vector3(-7.0, 1.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(124.0, -5.0, 13.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-31.0, 0.0, 0.0))
			# The support hand closes toward the lower haft while both wrists roll the
			# blade edge into the vertical plane.
			_set_pose_deg(pose, "upper_arm_l", Vector3(101.0, 7.0, -15.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-48.0, 0.0, 0.0))
			_set_pose_deg(pose, "hand_r", Vector3(-4.0, 0.0, 34.0))
			_set_pose_deg(pose, "hand_l", Vector3(-6.0, 0.0, 30.0))
			_set_pose_deg(pose, "thigh_l", Vector3(-21.0 * power, 0.0, -6.0))
			_set_pose_deg(pose, "thigh_r", Vector3(-17.0 * power, 0.0, 6.0))
			_set_pose_deg(pose, "shin_l", Vector3(37.0 * power, 0.0, 0.0))
			_set_pose_deg(pose, "shin_r", Vector3(31.0 * power, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.105 * power, 0.045)
		"contact":
			_set_pose_deg(pose, "pelvis", Vector3(-14.0, 2.0, 0.0))
			_set_pose_deg(pose, "spine_01", Vector3(-17.0, 2.0, 0.0))
			_set_pose_deg(pose, "spine_02", Vector3(-21.0, 2.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(-28.0, 2.0, 0.0))
			_set_pose_deg(pose, "head", Vector3(9.0, -1.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(61.0, 4.0, 12.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-3.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(55.0, -4.0, -12.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-7.0, 0.0, 0.0))
			_set_pose_deg(pose, "hand_r", Vector3(0.0, 0.0, 32.0))
			_set_pose_deg(pose, "hand_l", Vector3(0.0, 0.0, 28.0))
			_set_pose_deg(pose, "thigh_l", Vector3(23.0 * power, 0.0, -5.0))
			_set_pose_deg(pose, "thigh_r", Vector3(-29.0 * power, 0.0, 5.0))
			_set_pose_deg(pose, "shin_r", Vector3(43.0 * power, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.12 * power, -0.12 * power)
		"follow":
			_set_pose_deg(pose, "pelvis", Vector3(-18.0, 3.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(-35.0, 3.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(42.0, 5.0, 13.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(38.0, -5.0, -13.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.13 * power, -0.17 * power)
		_:
			_set_pose_deg(pose, "pelvis", Vector3(5.0, 0.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(8.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(28.0, 0.0, 8.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-25.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(20.0, 0.0, -8.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.032, -0.018)
	return pose


func _build_axe_focus_rising_pose(stage: String) -> Dictionary:
	var pose: Dictionary = {}
	match stage:
		"windup":
			_set_pose_deg(pose, "pelvis", Vector3(18.0, -7.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(22.0, -8.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(36.0, -7.0, 15.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-54.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(30.0, 7.0, -15.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-50.0, 0.0, 0.0))
			_set_pose_deg(pose, "hand_r", Vector3(0.0, 0.0, 30.0))
			_set_pose_deg(pose, "hand_l", Vector3(0.0, 0.0, 27.0))
			_set_pose_deg(pose, "thigh_l", Vector3(-27.0, 0.0, -5.0))
			_set_pose_deg(pose, "thigh_r", Vector3(-23.0, 0.0, 5.0))
			_set_pose_deg(pose, "shin_l", Vector3(44.0, 0.0, 0.0))
			_set_pose_deg(pose, "shin_r", Vector3(39.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.14, -0.02)
		"contact":
			_set_pose_deg(pose, "pelvis", Vector3(-15.0, 6.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(-23.0, 7.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(102.0, 5.0, 12.0))
			_set_pose_deg(pose, "forearm_r", Vector3(-8.0, 0.0, 0.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(87.0, -5.0, -12.0))
			_set_pose_deg(pose, "forearm_l", Vector3(-14.0, 0.0, 0.0))
			_set_pose_deg(pose, "hand_r", Vector3(0.0, 0.0, 31.0))
			_set_pose_deg(pose, "hand_l", Vector3(0.0, 0.0, 28.0))
			_set_pose_deg(pose, "thigh_l", Vector3(25.0, 0.0, -4.0))
			_set_pose_deg(pose, "thigh_r", Vector3(-28.0, 0.0, 4.0))
			_set_pose_deg(pose, "shin_r", Vector3(38.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, 0.02, -0.12)
		"follow":
			_set_pose_deg(pose, "pelvis", Vector3(-19.0, 8.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(-29.0, 9.0, 0.0))
			_set_pose_deg(pose, "upper_arm_r", Vector3(116.0, 7.0, 12.0))
			_set_pose_deg(pose, "upper_arm_l", Vector3(98.0, -7.0, -12.0))
			pose["__pelvis_offset"] = Vector3(0.0, 0.08, -0.14)
		_:
			_set_pose_deg(pose, "pelvis", Vector3(4.0, 0.0, 0.0))
			_set_pose_deg(pose, "chest", Vector3(7.0, 0.0, 0.0))
			pose["__pelvis_offset"] = Vector3(0.0, -0.025, -0.015)
	return pose


func _build_axe_focus_charge_ready_pose() -> Dictionary:
	var pose: Dictionary = _build_axe_focus_overhead_pose("windup", true)
	var charge: float = 0.0
	if weapon_controller != null and weapon_controller.has_method("get_weapon_charge_ratio"):
		charge = clampf(float(weapon_controller.call("get_weapon_charge_ratio")), 0.0, 1.0)
	var breath: float = sin(elapsed * 5.0) * lerpf(0.5, 1.5, charge)
	_add_pose_deg(pose, "pelvis", Vector3(0.0, breath, 0.0))
	_add_pose_deg(pose, "chest", Vector3(-breath * 0.5, -breath, 0.0))
	var offset: Vector3 = pose.get("__pelvis_offset", Vector3.ZERO) as Vector3
	offset.y -= charge * 0.015
	pose["__pelvis_offset"] = offset
	return pose


func _build_axe_focus_lever_pose(
	attack: WeaponAttackDefinition,
	stage: String
) -> Dictionary:
	if weapon_controller == null:
		return {}
	var speed: float = weapon_controller.get_attack_speed()
	var startup: float = maxf(attack.get_startup_duration(speed), 0.01)
	var p: float = clampf(weapon_controller.current_attack_elapsed / startup, 0.0, 1.0)
	if weapon_controller.current_attack_elapsed >= startup:
		return _build_axe_focus_overhead_pose(stage, true)
	if p < 0.16:
		var plant: float = smoothstep(0.0, 1.0, p / 0.16)
		return _blend_pose(
			_build_axe_focus_charge_ready_pose(),
			_build_axe_focus_overhead_pose("contact", false),
			plant
		)
	if p < 0.42:
		var lever: float = smoothstep(0.0, 1.0, (p - 0.16) / 0.26)
		var planted: Dictionary = _build_axe_focus_overhead_pose("contact", false)
		var rise: Dictionary = _build_axe_focus_rising_pose("contact")
		var result: Dictionary = _blend_pose(planted, rise, lever)
		result["__pelvis_offset"] = Vector3(
			0.0,
			lerpf(-0.13, 0.18, lever),
			lerpf(-0.12, -0.2, lever)
		)
		return result
	if p < 0.62:
		var extract: float = smoothstep(0.0, 1.0, (p - 0.42) / 0.2)
		var pose: Dictionary = _build_axe_focus_rising_pose("follow")
		_add_pose_deg(pose, "pelvis", Vector3(-18.0 * extract, 0.0, 18.0 * extract))
		_add_pose_deg(pose, "chest", Vector3(-12.0 * extract, 0.0, 12.0 * extract))
		_set_pose_deg(pose, "thigh_l", Vector3(lerpf(25.0, 46.0, extract), 0.0, -8.0))
		_set_pose_deg(pose, "thigh_r", Vector3(lerpf(-28.0, 40.0, extract), 0.0, 8.0))
		_set_pose_deg(pose, "shin_l", Vector3(lerpf(0.0, -54.0, extract), 0.0, 0.0))
		_set_pose_deg(pose, "shin_r", Vector3(lerpf(38.0, -48.0, extract), 0.0, 0.0))
		pose["__pelvis_offset"] = Vector3(0.02, lerpf(0.18, 0.3, extract), -0.24)
		return pose
	if p < 0.84:
		var twist: float = smoothstep(0.0, 1.0, (p - 0.62) / 0.22)
		var pose: Dictionary = {}
		_set_pose_deg(pose, "pelvis", Vector3(-18.0 * sin(twist * PI), 0.0, 28.0 * sin(twist * PI)))
		_set_pose_deg(pose, "spine_01", Vector3(-11.0 * sin(twist * PI), 0.0, 12.0 * sin(twist * PI)))
		_set_pose_deg(pose, "spine_02", Vector3(-8.0 * sin(twist * PI), 0.0, 10.0 * sin(twist * PI)))
		_set_pose_deg(pose, "chest", Vector3(-6.0 * sin(twist * PI), 0.0, 8.0 * sin(twist * PI)))
		_set_pose_deg(pose, "upper_arm_r", Vector3(lerpf(112.0, 136.0, twist), -4.0, 12.0))
		_set_pose_deg(pose, "forearm_r", Vector3(lerpf(-5.0, 8.0, twist), 0.0, 0.0))
		_set_pose_deg(pose, "upper_arm_l", Vector3(lerpf(98.0, 126.0, twist), 4.0, -12.0))
		_set_pose_deg(pose, "forearm_l", Vector3(lerpf(-10.0, 5.0, twist), 0.0, 0.0))
		_set_pose_deg(pose, "thigh_l", Vector3(42.0, 0.0, -9.0))
		_set_pose_deg(pose, "thigh_r", Vector3(36.0, 0.0, 9.0))
		_set_pose_deg(pose, "shin_l", Vector3(-50.0, 0.0, 0.0))
		_set_pose_deg(pose, "shin_r", Vector3(-45.0, 0.0, 0.0))
		pose["__pelvis_offset"] = Vector3(0.04, lerpf(0.3, 0.2, twist), lerpf(-0.24, -0.32, twist))
		return pose
	var descend: float = smoothstep(0.0, 1.0, (p - 0.84) / 0.16)
	return _blend_pose(
		_build_axe_focus_charge_ready_pose(),
		_build_axe_focus_overhead_pose("contact", true),
		descend
	)


func _update_axe_charge_root_twist() -> void:
	if weapon_controller == null or weapon_controller.current_attack == null:
		rotation = Vector3.ZERO
		return
	var attack: WeaponAttackDefinition = weapon_controller.current_attack
	if not attack.extra_tags.has("axe_lever_vault"):
		rotation = Vector3.ZERO
		return
	var startup: float = maxf(
		attack.get_startup_duration(weapon_controller.get_attack_speed()),
		0.01
	)
	var p: float = clampf(
		weapon_controller.current_attack_elapsed / startup,
		0.0,
		1.0
	)
	if p < 0.52:
		rotation = Vector3.ZERO
		return
	if p < 0.84:
		var twist: float = smoothstep(0.0, 1.0, (p - 0.52) / 0.32)
		rotation = Vector3(
			deg_to_rad(-20.0 * sin(twist * PI)),
			deg_to_rad(360.0 * twist),
			deg_to_rad(34.0 * sin(twist * PI))
		)
		return
	var settle: float = smoothstep(0.0, 1.0, (p - 0.84) / 0.16)
	rotation = Vector3(
		deg_to_rad(lerpf(-3.0, 0.0, settle)),
		deg_to_rad(360.0),
		deg_to_rad(lerpf(8.0, 0.0, settle))
	)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["weapon_language_v4m"] = true
	data["axe_focus_language"] = true
	data["axe_edge_aligned_overheads"] = true
	data["axe_fast_lever_twist"] = true
	data["axe_playstyle"] = "power_momentum_openings"
	return data
