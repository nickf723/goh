extends "res://scripts/ui/development_control_center.gd"

const PROGRESSION_CHALLENGE_LAB_FEATURE: Dictionary = {
	"id": "progression_challenge_lab",
	"order": 57,
	"display_name": "Progression Challenge Laboratory",
	"category": "Progression and Combat",
	"version": "v1",
	"status": "development_tool",
	"description": "One-room laboratory for the five starter Codex challenges, their real reaction, alchemy, and creature-study triggers, live progress reporting, and runtime reward verification.",
	"scene": "res://scenes/levels/prototypes/prototype_progression_challenge_lab_v1.tscn",
	"validation_scenes": [
		"res://scenes/levels/prototypes/prototype_progression_challenge_lab_v1.tscn",
	],
	"automated_tests": [
		"res://scenes/tests/progression_backbone_v1_smoke_test.tscn",
		"res://scenes/tests/progression_rewards_v1_smoke_test.tscn",
		"res://scenes/tests/progression_challenge_lab_smoke_test.tscn",
	],
	"dependencies": [
		"elemental_reaction_lab",
		"familiar_training_yard",
	],
	"controls": [
		"MOVE",
		"INTERACT",
		"FULL MENU",
		"F1-F5 STATIONS",
		"F8 RESET",
		"F9 CLEAR PROGRESS",
		"F10 COMPLETE ALL",
	],
	"manual_test": "docs/PROGRESSION_CHALLENGE_LAB_V1.md",
	"temporary_state": "developer_managed_save_state",
	"story_integrated": false,
	"limitations": [
		"The laboratory intentionally uses explicit labels and debug consoles.",
		"Challenge progress mutates the active runtime save state until Clear Progress is used or the save is reloaded.",
		"The room covers the five starter challenges rather than the future full achievement catalog.",
	],
	"launchable": true,
	"visible_in_launcher": true,
	"ci_validate": true,
	"timeout_seconds": 20,
}


func _append_supplemental_features() -> void:
	super._append_supplemental_features()
	for feature: Dictionary in visible_features:
		if str(feature.get("id", "")) == "progression_challenge_lab":
			return
	visible_features.append(PROGRESSION_CHALLENGE_LAB_FEATURE.duplicate(true))
	visible_features.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("order", 0)) < int(b.get("order", 0))
	)


func _get_supplemental_feature_count() -> int:
	return super._get_supplemental_feature_count() + 1


func _get_supplemental_feature(feature_id: String) -> Dictionary:
	if feature_id == "progression_challenge_lab":
		return PROGRESSION_CHALLENGE_LAB_FEATURE
	return super._get_supplemental_feature(feature_id)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["progression_challenge_lab_available"] = (
		_get_feature_errors("progression_challenge_lab").is_empty()
	)
	return data
