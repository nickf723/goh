extends "res://scripts/ui/development_control_center_familiar.gd"

const FIELD_PROGRESSION_FEATURE: Dictionary = {
	"id": "ruined_village_field_progression",
	"order": 17,
	"display_name": "Ruined Village Field Progression",
	"category": "Playable Progression Slice",
	"version": "v1",
	"status": "vertical_slice",
	"description": "A 10-15 minute field route that combines story and side quests, botanical discovery, ingredient gathering, elemental combat opportunities, creature study, travel alchemy, multi-solution traversal, an immediate reward showcase, and a route-end progression summary.",
	"scene": "res://scenes/levels/prototypes/prototype_ruined_village_field_progression_v1.tscn",
	"validation_scenes": [
		"res://scenes/levels/prototypes/prototype_ruined_village_field_progression_v1.tscn",
	],
	"automated_tests": [
		"res://scenes/tests/ruined_village_approach_smoke_test.tscn",
		"res://scenes/tests/ruined_village_field_progression_smoke_test.tscn",
		"res://scenes/tests/progression_feedback_tracking_v1_smoke_test.tscn",
	],
	"dependencies": [
		"ruined_village_approach",
		"progression_challenge_lab",
		"elemental_reaction_lab",
	],
	"controls": [
		"MOVE",
		"INTERACT",
		"COMBAT",
		"FOCUS",
		"CAST",
		"FULL MENU",
		"CODEX PINNING",
		"RESET",
	],
	"manual_test": "docs/RUINED_VILLAGE_FIELD_PROGRESSION_V1.md",
	"temporary_state": "persistent_save_slot_progression",
	"story_integrated": true,
	"limitations": [
		"The route reuses the procedural Ruined Village environment and prototype enemies.",
		"The final encounter showcases current rewards but does not require one specific unlock.",
		"The route summary reports systems advanced during the current scene session rather than lifetime totals.",
		"Final cinematics, voice acting, and production assets remain future work.",
	],
	"launchable": true,
	"visible_in_launcher": true,
	"ci_validate": true,
	"timeout_seconds": 24,
}


func _append_supplemental_features() -> void:
	super._append_supplemental_features()
	for feature: Dictionary in visible_features:
		if str(feature.get("id", "")) == "ruined_village_field_progression":
			return
	visible_features.append(FIELD_PROGRESSION_FEATURE.duplicate(true))
	visible_features.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("order", 0)) < int(b.get("order", 0))
	)


func _get_supplemental_feature_count() -> int:
	return super._get_supplemental_feature_count() + 1


func _get_supplemental_feature(feature_id: String) -> Dictionary:
	if feature_id == "ruined_village_field_progression":
		return FIELD_PROGRESSION_FEATURE
	return super._get_supplemental_feature(feature_id)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["ruined_village_field_progression_available"] = (
		_get_feature_errors("ruined_village_field_progression").is_empty()
	)
	return data
