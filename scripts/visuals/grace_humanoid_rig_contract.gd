extends RefCounted
class_name GraceHumanoidRigContract

# Godot's BoneMap + SkeletonProfileHumanoid owns retargeting. This contract maps
# imported bone names onto the semantic roles used by Grace presentation code.

const SEMANTIC_ALIASES: Dictionary = {
	"root": ["root", "Root"],
	"pelvis": ["pelvis", "Hips"],
	"spine_01": ["spine_01", "Spine"],
	"spine_02": ["spine_02", "Chest", "Spine1"],
	"chest": ["chest", "UpperChest", "Spine2"],
	"neck": ["neck", "Neck"],
	"head": ["head", "Head"],
	"clavicle_l": ["clavicle_l", "LeftShoulder", "Clavicle_L"],
	"upper_arm_l": ["upper_arm_l", "LeftUpperArm", "UpperArm_L"],
	"forearm_l": ["forearm_l", "LeftLowerArm", "ForeArm_L"],
	"hand_l": ["hand_l", "LeftHand", "Hand_L"],
	"clavicle_r": ["clavicle_r", "RightShoulder", "Clavicle_R"],
	"upper_arm_r": ["upper_arm_r", "RightUpperArm", "UpperArm_R"],
	"forearm_r": ["forearm_r", "RightLowerArm", "ForeArm_R"],
	"hand_r": ["hand_r", "RightHand", "Hand_R"],
	"thigh_l": ["thigh_l", "LeftUpperLeg", "Thigh_L"],
	"shin_l": ["shin_l", "LeftLowerLeg", "Shin_L"],
	"foot_l": ["foot_l", "LeftFoot", "Foot_L"],
	"toe_l": ["toe_l", "LeftToes", "Toe_L"],
	"thigh_r": ["thigh_r", "RightUpperLeg", "Thigh_R"],
	"shin_r": ["shin_r", "RightLowerLeg", "Shin_R"],
	"foot_r": ["foot_r", "RightFoot", "Foot_R"],
	"toe_r": ["toe_r", "RightToes", "Toe_R"],
}

const REQUIRED_SEMANTICS: Array[String] = [
	"pelvis", "spine_01", "chest", "neck", "head",
	"upper_arm_l", "forearm_l", "hand_l",
	"upper_arm_r", "forearm_r", "hand_r",
	"thigh_l", "shin_l", "foot_l",
	"thigh_r", "shin_r", "foot_r",
]

const OPTIONAL_SEMANTICS: Array[String] = [
	"root", "spine_02", "clavicle_l", "clavicle_r", "toe_l", "toe_r",
]


static func find_skeleton(root_node: Node) -> Skeleton3D:
	if root_node == null:
		return null
	if root_node is Skeleton3D:
		return root_node as Skeleton3D
	for child: Node in root_node.get_children():
		var found: Skeleton3D = find_skeleton(child)
		if found != null:
			return found
	return null


static func build_semantic_map(skeleton: Skeleton3D) -> Dictionary:
	var result: Dictionary = {}
	if skeleton == null:
		return result
	var lookup: Dictionary = {}
	for index: int in range(skeleton.get_bone_count()):
		lookup[_normalize(str(skeleton.get_bone_name(index)))] = index
	for semantic_variant: Variant in SEMANTIC_ALIASES.keys():
		var semantic: String = str(semantic_variant)
		for alias_variant: Variant in SEMANTIC_ALIASES[semantic] as Array:
			var normalized: String = _normalize(str(alias_variant))
			if lookup.has(normalized):
				result[semantic] = int(lookup[normalized])
				break
	return result


static func validate_skeleton(skeleton: Skeleton3D) -> Dictionary:
	var semantic_map: Dictionary = build_semantic_map(skeleton)
	var missing_required: Array[String] = []
	var missing_optional: Array[String] = []
	for semantic: String in REQUIRED_SEMANTICS:
		if not semantic_map.has(semantic):
			missing_required.append(semantic)
	for semantic: String in OPTIONAL_SEMANTICS:
		if not semantic_map.has(semantic):
			missing_optional.append(semantic)

	var hierarchy_errors: Array[String] = []
	if skeleton != null:
		_validate_chain(skeleton, semantic_map, ["pelvis", "spine_01", "chest", "neck", "head"], hierarchy_errors)
		_validate_chain(skeleton, semantic_map, ["upper_arm_l", "forearm_l", "hand_l"], hierarchy_errors)
		_validate_chain(skeleton, semantic_map, ["upper_arm_r", "forearm_r", "hand_r"], hierarchy_errors)
		_validate_chain(skeleton, semantic_map, ["thigh_l", "shin_l", "foot_l"], hierarchy_errors)
		_validate_chain(skeleton, semantic_map, ["thigh_r", "shin_r", "foot_r"], hierarchy_errors)

	return {
		"compatible": skeleton != null and missing_required.is_empty() and hierarchy_errors.is_empty(),
		"bone_count": skeleton.get_bone_count() if skeleton != null else 0,
		"semantic_map": semantic_map,
		"mapped_count": semantic_map.size(),
		"missing_required": missing_required,
		"missing_optional": missing_optional,
		"hierarchy_errors": hierarchy_errors,
		"weapon_hand_semantic": "hand_r",
		"support_hand_semantic": "hand_l",
		"godot_humanoid_profile_ready": missing_required.is_empty(),
	}


static func get_bone_index(skeleton: Skeleton3D, semantic: String) -> int:
	return int(build_semantic_map(skeleton).get(semantic, -1))


static func get_bone_global_pose(skeleton: Skeleton3D, semantic: String) -> Transform3D:
	var index: int = get_bone_index(skeleton, semantic)
	return skeleton.get_bone_global_pose(index) if skeleton != null and index >= 0 else Transform3D.IDENTITY


static func _validate_chain(
	skeleton: Skeleton3D,
	semantic_map: Dictionary,
	chain: Array[String],
	errors: Array[String]
) -> void:
	for index: int in range(chain.size() - 1):
		var parent_semantic: String = chain[index]
		var child_semantic: String = chain[index + 1]
		if not semantic_map.has(parent_semantic) or not semantic_map.has(child_semantic):
			continue
		if not _is_descendant_of(skeleton, int(semantic_map[child_semantic]), int(semantic_map[parent_semantic])):
			errors.append(child_semantic + " is not descended from " + parent_semantic)


static func _is_descendant_of(skeleton: Skeleton3D, child_index: int, ancestor_index: int) -> bool:
	var current: int = child_index
	while current >= 0:
		if current == ancestor_index:
			return true
		current = skeleton.get_bone_parent(current)
	return false


static func _normalize(value: String) -> String:
	return value.to_lower().replace("mixamorig:", "").replace("_", "").replace("-", "").replace(" ", "")
