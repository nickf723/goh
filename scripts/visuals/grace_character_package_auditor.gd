extends RefCounted
class_name GraceCharacterPackageAuditor

const CharacterAssetAuditorScript = preload("res://scripts/visuals/grace_presentation_asset_auditor.gd")


static func audit(root: Node, material_enroller: Node = null) -> Dictionary:
	var presentation: Dictionary = CharacterAssetAuditorScript.audit(root)
	var materials: Dictionary = {}
	if material_enroller != null and material_enroller.has_method("get_debug_data"):
		materials = material_enroller.call("get_debug_data") as Dictionary

	var skeleton_ready: bool = bool(presentation.get("skeleton_ready", false))
	var core_animation_ready: bool = bool(presentation.get("core_animation_ready", false))
	var sword_animation_ready: bool = bool(presentation.get("sword_animation_ready", false))
	var material_report_available: bool = not materials.is_empty()
	var director_found: bool = bool(materials.get("director_found", false))
	var character_root_found: bool = bool(materials.get("character_root_found", false))
	var enrolled_surface_count: int = (
		int(materials.get("enrolled_surfaces", 0))
		+ int(materials.get("enrolled_meshes", 0))
	)
	var unresolved_surfaces: int = int(materials.get("unresolved_surface_count", 0))
	var material_enrollment_active: bool = (
		material_report_available
		and director_found
		and character_root_found
		and enrolled_surface_count > 0
	)
	var material_ready: bool = material_enrollment_active and unresolved_surfaces == 0

	return {
		"character_package_audit": true,
		"skeleton_ready": skeleton_ready,
		"core_animation_ready": core_animation_ready,
		"sword_animation_ready": sword_animation_ready,
		"material_report_available": material_report_available,
		"material_enrollment_active": material_enrollment_active,
		"material_ready": material_ready,
		"enrolled_material_surfaces": enrolled_surface_count,
		"unresolved_material_surfaces": unresolved_surfaces,
		"functional_migration_stage": presentation.get("migration_stage", "blocked_skeleton"),
		"production_visual_ready": sword_animation_ready and material_ready,
		"next_step": _next_step(
			skeleton_ready,
			core_animation_ready,
			sword_animation_ready,
			material_report_available,
			material_enrollment_active,
			material_ready
		),
		"presentation": presentation,
		"materials": materials,
	}


static func _next_step(
	skeleton_ready: bool,
	core_animation_ready: bool,
	sword_animation_ready: bool,
	material_report_available: bool,
	material_enrollment_active: bool,
	material_ready: bool
) -> String:
	if not skeleton_ready:
		return "map_humanoid_skeleton"
	if not core_animation_ready:
		return "supply_core_animation_library"
	if not sword_animation_ready:
		return "supply_sword_calibration_library"
	if not material_report_available or not material_enrollment_active:
		return "enroll_imported_material_surfaces"
	if not material_ready:
		return "resolve_material_surface_roles"
	return "ready_for_character_playtest"
