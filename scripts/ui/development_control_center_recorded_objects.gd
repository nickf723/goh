extends "res://scripts/ui/development_control_center_field_progression.gd"

const RECORDED_OBJECTS_FEATURE: Dictionary = {
	"id": "recorded_objects_v1",
	"order": 19,
	"display_name": "Recorded Object Proving Ground",
	"category": "Progression and World Tools",
	"version": "v1",
	"status": "development_tool",
	"description": "Record and reproduce four physical tools with camera placement, rotation, mana costs, collision validation, stacking, bridging, launching, explosions, and active-object limits.",
	"scene": "res://scenes/levels/prototypes/prototype_recorded_object_lab_v1.tscn",
	"validation_scenes": [
		"res://scenes/levels/prototypes/prototype_recorded_object_lab_v1.tscn",
	],
	"automated_tests": [
		"res://scenes/tests/recorded_objects_v1_smoke_test.tscn",
		"res://scenes/tests/full_menu_items_v1_smoke_test.tscn",
		"res://scenes/tests/full_menu_journal_v1_smoke_test.tscn",
	],
	"dependencies": [
		"progression_challenge_lab",
		"ruined_village_field_progression",
	],
	"controls": [
		"MOVE",
		"INTERACT",
		"F1-F4 SELECT",
		"V / Y PLACEMENT",
		"Q/E OR L/R CYCLE",
		"R ROTATE",
		"CLICK / A PLACE",
		"F8 CLEAR",
	],
	"manual_test": "docs/RECORDED_OBJECTS_V1.md",
	"temporary_state": "persistent_save_slot_blueprints_runtime_objects",
	"story_integrated": false,
	"limitations": [
		"Recorded Objects are currently available through the dedicated manager and proving ground rather than every production scene.",
		"The first four actors use procedural prototype visuals.",
		"Object selection from Items is represented in the data model but direct menu-to-placement activation is reserved for the integration pass.",
		"Engineering Builds remain a separate future system for multi-part contraptions.",
	],
	"launchable": true,
	"visible_in_launcher": true,
	"ci_validate": true,
	"timeout_seconds": 24,
}


func _append_supplemental_features() -> void:
	super._append_supplemental_features()
	for feature: Dictionary in visible_features:
		if str(feature.get("id", "")) == "recorded_objects_v1":
			return
	visible_features.append(RECORDED_OBJECTS_FEATURE.duplicate(true))
	visible_features.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("order", 0)) < int(b.get("order", 0))
	)


func _get_supplemental_feature_count() -> int:
	return super._get_supplemental_feature_count() + 1


func _get_supplemental_feature(feature_id: String) -> Dictionary:
	if feature_id == "recorded_objects_v1":
		return RECORDED_OBJECTS_FEATURE
	return super._get_supplemental_feature(feature_id)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["recorded_objects_available"] = (
		_get_feature_errors("recorded_objects_v1").is_empty()
	)
	return data
