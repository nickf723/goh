extends Node

const ProductionContractScript = preload(
	"res://scripts/visuals/grace_production_skeleton_contract.gd"
)
const PoseMirrorScript = preload(
	"res://scripts/visuals/grace_skeleton_pose_mirror.gd"
)
const PresentationControllerScene: PackedScene = preload(
	"res://scenes/actors/player/grace_production_presentation_controller.tscn"
)
const CombatPlayerScene: PackedScene = preload(
	"res://scenes/actors/player/player_combat_v2.tscn"
)

var failures: Array[String] = []


func _ready() -> void:
	_validate_production_contract()
	_validate_pose_mirror()
	await _validate_fallback_controller()
	_finish()


func _validate_production_contract() -> void:
	var skeleton: Skeleton3D = _build_reference_skeleton(false)
	add_child(skeleton)
	var validation: Dictionary = (
		ProductionContractScript.validate_production_skeleton(skeleton)
	)
	_expect(
		bool(validation.get("production_ready", false)),
		"canonical 23-bone Grace skeleton is production-ready"
	)
	_expect(
		int(validation.get("mapped_count", 0)) == 23,
		"production skeleton maps all 23 canonical semantics"
	)
	_expect(
		absf(
			float(validation.get("head_to_foot_span", 0.0))
			- ProductionContractScript.REFERENCE_HEAD_TO_FOOT_SPAN
		) < 0.02,
		"production skeleton preserves the approved Grace rest span"
	)
	_expect(
		ProductionContractScript.VIRTUAL_SOCKET_SPECS.has("weapon_hand")
		and ProductionContractScript.VIRTUAL_SOCKET_SPECS.has("head_aim")
		and ProductionContractScript.VIRTUAL_SOCKET_SPECS.has("foot_l")
		and ProductionContractScript.VIRTUAL_SOCKET_SPECS.has("foot_r"),
		"production skeleton exposes stable virtual presentation sockets"
	)
	skeleton.queue_free()


func _validate_pose_mirror() -> void:
	var source: Skeleton3D = _build_reference_skeleton(false)
	var target: Skeleton3D = _build_reference_skeleton(true)
	add_child(source)
	add_child(target)
	var source_chest: int = source.find_bone("chest")
	var source_pelvis: int = source.find_bone("pelvis")
	var source_hand: int = source.find_bone("hand_r")
	var chest_rotation: Quaternion = Quaternion(
		Vector3.UP,
		deg_to_rad(27.0)
	)
	var hand_rotation: Quaternion = Quaternion(
		Vector3.FORWARD,
		deg_to_rad(-19.0)
	)
	source.set_bone_pose_rotation(source_chest, chest_rotation)
	source.set_bone_pose_rotation(source_hand, hand_rotation)
	source.set_bone_pose_position(
		source_pelvis,
		Vector3(0.04, -0.08, -0.12)
	)

	var mirror: GraceSkeletonPoseMirror = PoseMirrorScript.new()
	add_child(mirror)
	_expect(
		mirror.configure(source, target),
		"production pose mirror accepts canonical source and humanoid alias target"
	)
	mirror.mirror_pose()
	var target_chest: int = target.find_bone("UpperChest")
	var target_pelvis: int = target.find_bone("Hips")
	var target_hand: int = target.find_bone("RightHand")
	_expect(
		chest_rotation.angle_to(
			target.get_bone_pose_rotation(target_chest)
		) < 0.001,
		"pose mirror copies torso rotation by semantic role"
	)
	_expect(
		hand_rotation.angle_to(
			target.get_bone_pose_rotation(target_hand)
		) < 0.001,
		"pose mirror copies weapon-hand rotation by semantic role"
	)
	_expect(
		target.get_bone_pose_position(target_pelvis).distance_to(
			source.get_bone_pose_position(source_pelvis)
		) < 0.001,
		"pose mirror copies scaled pelvis motion"
	)
	mirror.queue_free()
	source.queue_free()
	target.queue_free()


func _validate_fallback_controller() -> void:
	_expect(
		CombatPlayerScene != null,
		"combat player preloads with production presentation bridge"
	)
	var actor: CharacterBody3D = CharacterBody3D.new()
	actor.name = "ProductionPresentationTestActor"
	add_child(actor)
	var procedural_visual: Node3D = Node3D.new()
	procedural_visual.name = "GraceSkeletalVisualV1"
	actor.add_child(procedural_visual)
	var source_skeleton: Skeleton3D = _build_reference_skeleton(false)
	procedural_visual.add_child(source_skeleton)
	var weapon_controller: Node3D = Node3D.new()
	weapon_controller.name = "WeaponController"
	actor.add_child(weapon_controller)
	var hand_anchor: Node3D = Node3D.new()
	hand_anchor.name = "HandAnchor"
	weapon_controller.add_child(hand_anchor)
	var controller: Node3D = PresentationControllerScene.instantiate() as Node3D
	actor.add_child(controller)
	await get_tree().process_frame
	var data: Dictionary = controller.call("get_debug_data") as Dictionary
	_expect(
		str(data.get("active_presentation", "")) == "procedural",
		"presentation controller remains on procedural fallback without an imported model"
	)
	_expect(
		bool(data.get("source_skeleton_found", false)),
		"presentation controller resolves the live calibration skeleton"
	)
	_expect(
		controller.has_method("install_imported_scene")
		and controller.has_method("activate_imported")
		and controller.has_method("get_socket_world_transform"),
		"presentation controller exposes the production promotion API"
	)
	actor.queue_free()


func _build_reference_skeleton(use_humanoid_aliases: bool) -> Skeleton3D:
	var skeleton: Skeleton3D = Skeleton3D.new()
	skeleton.name = (
		"HumanoidAliasSkeleton"
		if use_humanoid_aliases
		else "GraceCanonicalSkeleton"
	)
	var names: Dictionary = _get_bone_names(use_humanoid_aliases)
	var indices: Dictionary = {}
	_add_bone(skeleton, indices, str(names["root"]), "", Vector3.ZERO)
	_add_bone(skeleton, indices, str(names["pelvis"]), str(names["root"]), Vector3(0.0, 0.88, 0.0))
	_add_bone(skeleton, indices, str(names["spine_01"]), str(names["pelvis"]), Vector3(0.0, 0.16, 0.0))
	_add_bone(skeleton, indices, str(names["spine_02"]), str(names["spine_01"]), Vector3(0.0, 0.15, 0.0))
	_add_bone(skeleton, indices, str(names["chest"]), str(names["spine_02"]), Vector3(0.0, 0.17, 0.0))
	_add_bone(skeleton, indices, str(names["neck"]), str(names["chest"]), Vector3(0.0, 0.17, -0.005))
	_add_bone(skeleton, indices, str(names["head"]), str(names["neck"]), Vector3(0.0, 0.18, -0.01))
	_add_bone(skeleton, indices, str(names["clavicle_l"]), str(names["chest"]), Vector3(-0.12, 0.11, 0.0))
	_add_bone(skeleton, indices, str(names["upper_arm_l"]), str(names["clavicle_l"]), Vector3(-0.14, -0.02, 0.0))
	_add_bone(skeleton, indices, str(names["forearm_l"]), str(names["upper_arm_l"]), Vector3(-0.02, -0.30, 0.0))
	_add_bone(skeleton, indices, str(names["hand_l"]), str(names["forearm_l"]), Vector3(-0.015, -0.27, 0.0))
	_add_bone(skeleton, indices, str(names["clavicle_r"]), str(names["chest"]), Vector3(0.12, 0.11, 0.0))
	_add_bone(skeleton, indices, str(names["upper_arm_r"]), str(names["clavicle_r"]), Vector3(0.14, -0.02, 0.0))
	_add_bone(skeleton, indices, str(names["forearm_r"]), str(names["upper_arm_r"]), Vector3(0.02, -0.30, 0.0))
	_add_bone(skeleton, indices, str(names["hand_r"]), str(names["forearm_r"]), Vector3(0.015, -0.27, 0.0))
	_add_bone(skeleton, indices, str(names["thigh_l"]), str(names["pelvis"]), Vector3(-0.145, -0.08, 0.0))
	_add_bone(skeleton, indices, str(names["shin_l"]), str(names["thigh_l"]), Vector3(0.0, -0.40, 0.0))
	_add_bone(skeleton, indices, str(names["foot_l"]), str(names["shin_l"]), Vector3(0.0, -0.37, -0.035))
	_add_bone(skeleton, indices, str(names["toe_l"]), str(names["foot_l"]), Vector3(0.0, -0.04, -0.20))
	_add_bone(skeleton, indices, str(names["thigh_r"]), str(names["pelvis"]), Vector3(0.145, -0.08, 0.0))
	_add_bone(skeleton, indices, str(names["shin_r"]), str(names["thigh_r"]), Vector3(0.0, -0.40, 0.0))
	_add_bone(skeleton, indices, str(names["foot_r"]), str(names["shin_r"]), Vector3(0.0, -0.37, -0.035))
	_add_bone(skeleton, indices, str(names["toe_r"]), str(names["foot_r"]), Vector3(0.0, -0.04, -0.20))
	return skeleton


func _get_bone_names(use_humanoid_aliases: bool) -> Dictionary:
	if not use_humanoid_aliases:
		return {
			"root": "root", "pelvis": "pelvis", "spine_01": "spine_01", "spine_02": "spine_02", "chest": "chest", "neck": "neck", "head": "head",
			"clavicle_l": "clavicle_l", "upper_arm_l": "upper_arm_l", "forearm_l": "forearm_l", "hand_l": "hand_l",
			"clavicle_r": "clavicle_r", "upper_arm_r": "upper_arm_r", "forearm_r": "forearm_r", "hand_r": "hand_r",
			"thigh_l": "thigh_l", "shin_l": "shin_l", "foot_l": "foot_l", "toe_l": "toe_l",
			"thigh_r": "thigh_r", "shin_r": "shin_r", "foot_r": "foot_r", "toe_r": "toe_r",
		}
	return {
		"root": "Root", "pelvis": "Hips", "spine_01": "Spine", "spine_02": "Spine1", "chest": "UpperChest", "neck": "Neck", "head": "Head",
		"clavicle_l": "LeftShoulder", "upper_arm_l": "LeftUpperArm", "forearm_l": "LeftLowerArm", "hand_l": "LeftHand",
		"clavicle_r": "RightShoulder", "upper_arm_r": "RightUpperArm", "forearm_r": "RightLowerArm", "hand_r": "RightHand",
		"thigh_l": "LeftUpperLeg", "shin_l": "LeftLowerLeg", "foot_l": "LeftFoot", "toe_l": "LeftToes",
		"thigh_r": "RightUpperLeg", "shin_r": "RightLowerLeg", "foot_r": "RightFoot", "toe_r": "RightToes",
	}


func _add_bone(
	skeleton: Skeleton3D,
	indices: Dictionary,
	bone_name: String,
	parent_name: String,
	rest_origin: Vector3
) -> void:
	skeleton.add_bone(bone_name)
	var index: int = skeleton.find_bone(bone_name)
	if parent_name != "" and indices.has(parent_name):
		skeleton.set_bone_parent(index, int(indices[parent_name]))
	skeleton.set_bone_rest(
		index,
		Transform3D(Basis.IDENTITY, rest_origin)
	)
	indices[bone_name] = index


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("GRACE_PRODUCTION_PRESENTATION_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error(
			"GRACE_PRODUCTION_PRESENTATION_SMOKE_TEST: " + failure
		)
	get_tree().quit(1)
