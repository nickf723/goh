extends Node

const SkeletalGraceScene: PackedScene = preload(
	"res://scenes/actors/player/grace_humanoid_skeletal_proxy_v1.tscn"
)
const HumanoidRigContractScript = preload(
	"res://scripts/visuals/grace_humanoid_rig_contract.gd"
)

const EXPECTED_WEAPON_LANGUAGES: Array[String] = [
	"sword", "lance", "axe", "bow", "hammer", "mace", "daggers", "whip",
	"chains", "gauntlets", "flail", "halberd", "boomerang", "scythe", "staff", "shuriken",
]

var failures: Array[String] = []


func _ready() -> void:
	var rig: Node = SkeletalGraceScene.instantiate()
	add_child(rig)
	await get_tree().process_frame

	var data: Dictionary = {}
	if rig != null and rig.has_method("get_debug_data"):
		data = rig.call("get_debug_data") as Dictionary
	else:
		failures.append("skeletal Grace exposes debug data")

	_expect(bool(data.get("grounding_fix", false)), "grounding correction is active")
	_expect(bool(data.get("rest_pose_initialized", false)), "child bone pose translations initialize from rest")
	_expect(bool(data.get("pelvis_rest_preserved", false)), "pelvis animation preserves authored rest height")
	_expect(bool(data.get("weapon_language_v2", false)), "skeletal Grace owns diversified weapon language layer")
	_expect(bool(data.get("all_weapon_languages_candidate", false)), "active rig reports complete sixteen-class candidate coverage")

	var language_classes: Array = data.get("authored_language_classes", []) as Array
	_expect(language_classes.size() >= EXPECTED_WEAPON_LANGUAGES.size(), "active rig reports at least sixteen weapon languages")
	for weapon_class: String in EXPECTED_WEAPON_LANGUAGES:
		_expect(language_classes.has(weapon_class), weapon_class + " has intentional skeletal combat language")

	var foot_height: float = float(data.get("foot_height", 999.0))
	var span: float = float(data.get("head_to_foot_span", 0.0))
	var hand_span: float = float(data.get("hand_span", 0.0))
	var leg_span: float = float(data.get("leg_span", 0.0))
	_expect(absf(foot_height) < 0.16, "feet remain near the skeletal ground plane")
	_expect(span > 1.45, "head remains a full humanoid height above the feet")
	_expect(hand_span > 0.55, "left and right hands remain separated by articulated arms")
	_expect(leg_span > 0.6, "thigh-to-foot chain preserves articulated leg length")

	_validate_current_rig_contract(rig)
	_validate_godot_humanoid_profile_aliases()

	if rig != null and is_instance_valid(rig):
		rig.queue_free()
	await get_tree().process_frame
	_finish()


func _validate_current_rig_contract(rig: Node) -> void:
	var skeleton: Skeleton3D = rig.get_node_or_null("Skeleton3D") as Skeleton3D if rig != null else null
	_expect(skeleton != null, "current Grace exposes Skeleton3D for import contract validation")
	if skeleton == null:
		return
	var contract: Dictionary = HumanoidRigContractScript.validate_skeleton(skeleton)
	_expect(bool(contract.get("compatible", false)), "current Grace satisfies humanoid rig semantic contract")
	_expect(int(contract.get("mapped_count", 0)) >= 17, "current Grace maps all required humanoid semantics")
	var semantic_map: Dictionary = contract.get("semantic_map", {}) as Dictionary
	_expect(semantic_map.has("hand_r"), "rig contract resolves weapon hand semantic")
	_expect(semantic_map.has("hand_l"), "rig contract resolves support hand semantic")
	_expect(semantic_map.has("head"), "rig contract resolves head semantic")
	_expect(semantic_map.has("foot_l") and semantic_map.has("foot_r"), "rig contract resolves both foot semantics")
	_expect((contract.get("hierarchy_errors", []) as Array).is_empty(), "current Grace semantic chains preserve hierarchy")


func _validate_godot_humanoid_profile_aliases() -> void:
	var skeleton: Skeleton3D = Skeleton3D.new()
	skeleton.name = "GodotHumanoidProfileSkeleton"
	add_child(skeleton)

	var parents: Dictionary = {
		"Root": "",
		"Hips": "Root",
		"Spine": "Hips",
		"Chest": "Spine",
		"UpperChest": "Chest",
		"Neck": "UpperChest",
		"Head": "Neck",
		"LeftShoulder": "UpperChest",
		"LeftUpperArm": "LeftShoulder",
		"LeftLowerArm": "LeftUpperArm",
		"LeftHand": "LeftLowerArm",
		"RightShoulder": "UpperChest",
		"RightUpperArm": "RightShoulder",
		"RightLowerArm": "RightUpperArm",
		"RightHand": "RightLowerArm",
		"LeftUpperLeg": "Hips",
		"LeftLowerLeg": "LeftUpperLeg",
		"LeftFoot": "LeftLowerLeg",
		"LeftToes": "LeftFoot",
		"RightUpperLeg": "Hips",
		"RightLowerLeg": "RightUpperLeg",
		"RightFoot": "RightLowerLeg",
		"RightToes": "RightFoot",
	}
	var indices: Dictionary = {}
	for bone_name_variant: Variant in parents.keys():
		var bone_name: String = str(bone_name_variant)
		skeleton.add_bone(bone_name)
		var index: int = skeleton.find_bone(bone_name)
		indices[bone_name] = index
		var parent_name: String = str(parents[bone_name])
		if parent_name != "" and indices.has(parent_name):
			skeleton.set_bone_parent(index, int(indices[parent_name]))
		skeleton.set_bone_rest(index, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.1, 0.0)))

	var contract: Dictionary = HumanoidRigContractScript.validate_skeleton(skeleton)
	_expect(bool(contract.get("compatible", false)), "Godot humanoid-profile bone names satisfy Grace semantic contract")
	var semantic_map: Dictionary = contract.get("semantic_map", {}) as Dictionary
	_expect(int(semantic_map.get("pelvis", -1)) == skeleton.find_bone("Hips"), "Hips maps to Grace pelvis semantic")
	_expect(int(semantic_map.get("hand_r", -1)) == skeleton.find_bone("RightHand"), "RightHand maps to weapon hand semantic")
	_expect(int(semantic_map.get("forearm_l", -1)) == skeleton.find_bone("LeftLowerArm"), "LeftLowerArm maps to support forearm semantic")
	_expect(int(semantic_map.get("foot_r", -1)) == skeleton.find_bone("RightFoot"), "RightFoot maps to Grace foot semantic")

	skeleton.queue_free()


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("GRACE_SKELETAL_GROUNDING_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("GRACE_SKELETAL_GROUNDING_SMOKE_TEST: " + failure)
	get_tree().quit(1)
