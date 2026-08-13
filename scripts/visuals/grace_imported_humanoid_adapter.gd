extends Node
class_name GraceImportedHumanoidAdapter

const RigContractScript = preload("res://scripts/visuals/grace_humanoid_rig_contract.gd")

@export var skeleton_path: NodePath
@export var require_full_contract: bool = true

var skeleton: Skeleton3D
var semantic_bones: Dictionary = {}
var validation: Dictionary = {}


func _ready() -> void:
	resolve_rig()
	add_to_group("grace_imported_humanoid_adapter")
	add_to_group("debuggable")


func resolve_rig() -> bool:
	skeleton = get_node_or_null(skeleton_path) as Skeleton3D if skeleton_path != NodePath() else null
	if skeleton == null:
		skeleton = RigContractScript.find_skeleton(get_parent())
	semantic_bones = RigContractScript.build_semantic_map(skeleton)
	validation = RigContractScript.validate_skeleton(skeleton)
	return is_compatible()


func is_compatible() -> bool:
	if skeleton == null:
		return false
	return bool(validation.get("compatible", false)) if require_full_contract else not semantic_bones.is_empty()


func get_semantic_bone_index(semantic: String) -> int:
	return int(semantic_bones.get(semantic, -1))


func get_semantic_world_transform(semantic: String) -> Transform3D:
	var index: int = get_semantic_bone_index(semantic)
	if skeleton == null or index < 0:
		return Transform3D.IDENTITY
	return skeleton.global_transform * skeleton.get_bone_global_pose(index)


func get_debug_data() -> Dictionary:
	return {
		"imported_humanoid_adapter": true,
		"compatible": is_compatible(),
		"skeleton_found": skeleton != null,
		"mapped_semantics": semantic_bones.size(),
		"weapon_hand_mapped": semantic_bones.has("hand_r"),
		"support_hand_mapped": semantic_bones.has("hand_l"),
		"feet_mapped": semantic_bones.has("foot_l") and semantic_bones.has("foot_r"),
		"missing_required": validation.get("missing_required", []),
		"hierarchy_errors": validation.get("hierarchy_errors", []),
	}
