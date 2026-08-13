extends RefCounted
class_name GracePresentationAssetAuditor

const HumanoidRigContractScript = preload("res://scripts/visuals/grace_humanoid_rig_contract.gd")
const AnimationLibraryContractScript = preload("res://scripts/visuals/grace_animation_library_contract.gd")


static func audit(root: Node) -> Dictionary:
	var skeleton: Skeleton3D = HumanoidRigContractScript.find_skeleton(root)
	var animation_player: AnimationPlayer = AnimationLibraryContractScript.find_animation_player(root)
	var rig_validation: Dictionary = HumanoidRigContractScript.validate_skeleton(skeleton)
	var animation_validation: Dictionary = AnimationLibraryContractScript.validate_player(animation_player)
	var skeleton_ready: bool = bool(rig_validation.get("compatible", false))
	var core_animation_ready: bool = bool(animation_validation.get("compatible_core", false))
	var sword_animation_ready: bool = bool(animation_validation.get("sword_calibration_ready", false))
	return {
		"presentation_asset_audit": true,
		"skeleton_found": skeleton != null,
		"animation_player_found": animation_player != null,
		"skeleton_ready": skeleton_ready,
		"core_animation_ready": core_animation_ready,
		"sword_animation_ready": sword_animation_ready,
		"migration_stage": _migration_stage(skeleton_ready, core_animation_ready, sword_animation_ready),
		"rig_validation": rig_validation,
		"animation_validation": animation_validation,
	}


static func _migration_stage(
	skeleton_ready: bool,
	core_animation_ready: bool,
	sword_animation_ready: bool
) -> String:
	if not skeleton_ready:
		return "blocked_skeleton"
	if not core_animation_ready:
		return "skeleton_only"
	if not sword_animation_ready:
		return "locomotion_candidate"
	return "sword_candidate"
