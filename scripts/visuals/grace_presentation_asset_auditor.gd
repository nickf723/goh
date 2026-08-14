extends RefCounted
class_name GracePresentationAssetAuditor

const HumanoidRigContractScript = preload(
	"res://scripts/visuals/grace_humanoid_rig_contract.gd"
)
const ProductionSkeletonContractScript = preload(
	"res://scripts/visuals/grace_production_skeleton_contract.gd"
)
const AnimationLibraryContractScript = preload(
	"res://scripts/visuals/grace_animation_library_contract.gd"
)


static func audit(root: Node) -> Dictionary:
	var skeleton: Skeleton3D = HumanoidRigContractScript.find_skeleton(root)
	var animation_player: AnimationPlayer = AnimationLibraryContractScript.find_animation_player(root)
	var rig_validation: Dictionary = HumanoidRigContractScript.validate_skeleton(skeleton)
	var production_validation: Dictionary = (
		ProductionSkeletonContractScript.validate_production_skeleton(skeleton)
	)
	var animation_validation: Dictionary = AnimationLibraryContractScript.validate_player(animation_player)
	var skeleton_ready: bool = bool(rig_validation.get("compatible", false))
	var mirror_ready: bool = bool(production_validation.get("mirror_ready", false))
	var production_skeleton_ready: bool = bool(
		production_validation.get("production_ready", false)
	)
	var core_animation_ready: bool = bool(animation_validation.get("compatible_core", false))
	var sword_animation_ready: bool = bool(animation_validation.get("sword_calibration_ready", false))
	var mesh_count: int = _count_type(root, "MeshInstance3D")
	var animation_tree_count: int = _count_type(root, "AnimationTree")
	return {
		"presentation_asset_audit": true,
		"skeleton_found": skeleton != null,
		"animation_player_found": animation_player != null,
		"skeleton_ready": skeleton_ready,
		"mirror_ready": mirror_ready,
		"production_skeleton_ready": production_skeleton_ready,
		"core_animation_ready": core_animation_ready,
		"sword_animation_ready": sword_animation_ready,
		"mesh_count": mesh_count,
		"animation_tree_count": animation_tree_count,
		"has_visible_geometry": mesh_count > 0,
		"migration_stage": _migration_stage(
			skeleton_ready,
			mirror_ready,
			production_skeleton_ready,
			core_animation_ready,
			sword_animation_ready,
			mesh_count > 0
		),
		"rig_validation": rig_validation,
		"production_validation": production_validation,
		"animation_validation": animation_validation,
	}


static func _migration_stage(
	skeleton_ready: bool,
	mirror_ready: bool,
	production_skeleton_ready: bool,
	core_animation_ready: bool,
	sword_animation_ready: bool,
	has_visible_geometry: bool
) -> String:
	if not skeleton_ready or not mirror_ready:
		return "blocked_skeleton"
	if not has_visible_geometry:
		return "skeleton_only"
	if not production_skeleton_ready:
		return "pose_mirror_candidate"
	if not core_animation_ready:
		# A clean model can already inherit every current procedural move through
		# GraceSkeletonPoseMirror before its authored clip library exists.
		return "production_model_candidate"
	if not sword_animation_ready:
		return "locomotion_candidate"
	return "sword_candidate"


static func _count_type(root: Node, class_name_value: String) -> int:
	if root == null:
		return 0
	var count: int = 1 if root.is_class(class_name_value) else 0
	for child: Node in root.get_children():
		count += _count_type(child, class_name_value)
	return count
