extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_weapon_languages_v4c.gd"

# Weapon Language V4D: Flail + Chains candidates and two-handed grip integrity.
# Flexible runtime rigs remain authoritative for their paths. Two-handed rigid
# classes use a final left-arm IK layer against WeaponSupportGripContract.
# The final pose layer also keeps ordinary attacks near a forward contact plane.

const SUPPORT_HAND_CLASSES: Array[String] = ["hammer", "lance", "halberd", "staff", "scythe"]
const FORWARD_PLANE_EXEMPT_CLASSES: Array[String] = ["bow", "boomerang", "shuriken"]

var support_grip_contract: Node
var support_hand_ik: TwoBoneIK3D
var support_hand_pole: Marker3D
var support_hand_target: Node3D
var support_hand_error: float = 0.0
var support_hand_ik_ready: bool = false


func _ready() -> void:
	super._ready()
	_ensure_support_hand_ik()


func _process(delta: float) -> void:
	super._process(delta)
	_ensure_support_hand_ik()
	_update_support_hand_ik_state()


func _build_attack_stage_pose(attack: WeaponAttackDefinition, stage: String) -> Dictionary:
	var weapon_class: String = _get_equipped_weapon_class()
	var pose: Dictionary
	if weapon_class == "flail":
		pose = _build_flail_attack_pose(attack, stage)
	elif weapon_class == "chains":
		pose = _build_chain_attack_pose(attack, stage)
	else:
		pose = super._build_attack_stage_pose(attack, stage)
	_apply_forward_contact_plane_pose(pose, attack, stage, weapon_class)
	return pose


func _apply_forward_contact_plane_pose(
	pose: Dictionary,
	attack: WeaponAttackDefinition,
	stage: String,
	weapon_class: String
) -> void:
	if attack == null or pose.is_empty() or FORWARD_PLANE_EXEMPT_CLASSES.has(weapon_class):
		return
	if not attack.extra_tags.has("forward_contact_plane"):
		return
	if (
		attack.extra_tags.has("plunging")
		or attack.extra_tags.has("launcher")
		or attack.extra_tags.has("ground_slam")
		or attack.extra_tags.has("pole_vault")
	):
		return

	# The procedural body's local +X arm rotation moves from hanging at the side
	# toward overhead. Generic cuts could drift well past horizontal, making the
	# weapon look skyward even while the gameplay query remained level. Cap only
	# ordinary forward strikes, and leave deliberate vertical techniques alone.
	match stage:
		"windup":
			_cap_pose_bone_x(pose, "upper_arm_r", 112.0)
			_cap_pose_bone_x(pose, "hand_r", 20.0)
		"contact":
			_cap_pose_bone_x(pose, "upper_arm_r", 98.0)
			_clamp_pose_bone_x(pose, "hand_r", -14.0, 14.0)
			_add_pose_deg(pose, "chest", Vector3(-4.0, 0.0, 0.0))
			var contact_offset: Vector3 = pose.get("__pelvis_offset", Vector3.ZERO) as Vector3
			contact_offset.z = minf(contact_offset.z, -0.055)
			pose["__pelvis_offset"] = contact_offset
		"follow":
			_cap_pose_bone_x(pose, "upper_arm_r", 104.0)
			_clamp_pose_bone_x(pose, "hand_r", -18.0, 18.0)
			_add_pose_deg(pose, "chest", Vector3(-3.0, 0.0, 0.0))
			var follow_offset: Vector3 = pose.get("__pelvis_offset", Vector3.ZERO) as Vector3
			follow_offset.z = minf(follow_offset.z, -0.07)
			pose["__pelvis_offset"] = follow_offset


func _cap_pose_bone_x(pose: Dictionary, bone_name: String, maximum_degrees: float) -> void:
	if not pose.has(bone_name):
		return
	var rotation: Vector3 = pose.get(bone_name, Vector3.ZERO) as Vector3
	rotation.x = minf(rotation.x, deg_to_rad(maximum_degrees))
	pose[bone_name] = rotation


func _clamp_pose_bone_x(
	pose: Dictionary,
	bone_name: String,
	minimum_degrees: float,
	maximum_degrees: float
) -> void:
	if not pose.has(bone_name):
		return
	var rotation: Vector3 = pose.get(bone_name, Vector3.ZERO) as Vector3
	rotation.x = clampf(
		rotation.x,
		deg_to_rad(minimum_degrees),
		deg_to_rad(maximum_degrees)
	)
	pose[bone_name] = rotation


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


func _ensure_support_hand_ik() -> void:
	if support_hand_ik_ready or skeleton == null or actor == null:
		return
	support_grip_contract = actor.get_node_or_null("WeaponController/WeaponSupportGripContract")
	if support_grip_contract == null or not support_grip_contract.has_method("get_support_grip_target"):
		return
	var target_value: Variant = support_grip_contract.call("get_support_grip_target")
	if target_value is Node3D:
		support_hand_target = target_value as Node3D
	else:
		# The target exists as a child of the contract even when the currently held
		# class is one-handed. Resolve it directly so the IK NodePath stays stable.
		support_hand_target = support_grip_contract.get_node_or_null("SupportGripTarget") as Node3D
	if support_hand_target == null:
		return

	support_hand_pole = Marker3D.new()
	support_hand_pole.name = "SupportHandPole"
	add_child(support_hand_pole)

	support_hand_ik = TwoBoneIK3D.new()
	support_hand_ik.name = "SupportHandTwoBoneIK"
	skeleton.add_child(support_hand_ik)
	support_hand_ik.setting_count = 1
	support_hand_ik.set_root_bone_name(0, "upper_arm_l")
	support_hand_ik.set_middle_bone_name(0, "forearm_l")
	support_hand_ik.set_end_bone_name(0, "hand_l")
	support_hand_ik.set_target_node(0, support_hand_ik.get_path_to(support_hand_target))
	support_hand_ik.set_pole_node(0, support_hand_ik.get_path_to(support_hand_pole))
	support_hand_ik.influence = 0.0
	support_hand_ik.active = true
	support_hand_ik.modification_processed.connect(_on_support_hand_ik_processed)
	support_hand_ik_ready = true


func _update_support_hand_ik_state() -> void:
	if not support_hand_ik_ready or support_hand_ik == null or support_hand_pole == null:
		return
	var weapon_class: String = _get_equipped_weapon_class()
	var should_grip: bool = SUPPORT_HAND_CLASSES.has(weapon_class)
	var target_influence: float = 0.0
	if should_grip and support_grip_contract != null and support_grip_contract.has_method("get_support_influence"):
		target_influence = float(support_grip_contract.call("get_support_influence"))
	# Slightly relax outside attacks so locomotion still breathes, while keeping a
	# believable two-handed carry. Attacks get the strongest constraint.
	if should_grip and animation_state != "attack":
		target_influence *= 0.72
	support_hand_ik.influence = clampf(target_influence, 0.0, 1.0)
	if support_hand_ik.influence <= 0.001 or not bones.has("upper_arm_l"):
		return

	var shoulder_pose: Transform3D = skeleton.get_bone_global_pose(int(bones["upper_arm_l"]))
	var shoulder_world: Vector3 = global_transform * shoulder_pose.origin
	var actor_basis: Basis = actor.global_transform.basis.orthonormalized()
	var left: Vector3 = -actor_basis.x.normalized()
	var forward: Vector3 = -actor_basis.z.normalized()
	support_hand_pole.global_position = shoulder_world + left * 0.48 + Vector3.UP * 0.035 + forward * 0.08


func _on_support_hand_ik_processed() -> void:
	if support_hand_ik == null or support_hand_ik.influence <= 0.001 or skeleton == null:
		support_hand_error = 0.0
		return
	# The proxy body is procedural geometry rather than a skinned mesh, so refresh
	# it once more from the final post-IK bone poses.
	_update_proxy_geometry()
	if support_hand_target == null or not bones.has("hand_l"):
		return
	var hand_pose: Transform3D = skeleton.get_bone_global_pose(int(bones["hand_l"]))
	var hand_world: Vector3 = global_transform * hand_pose.origin
	support_hand_error = hand_world.distance_to(support_hand_target.global_position)


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
	data["support_hand_ik"] = support_hand_ik_ready
	data["support_hand_ik_active"] = support_hand_ik != null and support_hand_ik.influence > 0.001
	data["support_hand_error"] = snappedf(support_hand_error, 0.001)
	data["forward_contact_plane_pose"] = true
	return data
