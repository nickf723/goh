extends "res://scripts/ui/development_control_center_progression.gd"

const FAMILIAR_TRAINING_YARD_FEATURE: Dictionary = {
	"id": "familiar_training_yard",
	"order": 58,
	"display_name": "Familiar Training Yard",
	"category": "Progression and Combat",
	"version": "v1",
	"status": "development_tool",
	"description": "Encounter and study Gremlins through live combat events, unlock and configure a familiar blueprint, summon the prepared creature, and test friendly target allocation against wild mobs and training dummies.",
	"scene": "res://scenes/levels/prototypes/prototype_familiar_training_yard_v1.tscn",
	"validation_scenes": [
		"res://scenes/levels/prototypes/prototype_familiar_training_yard_v1.tscn",
	],
	"automated_tests": [
		"res://scenes/tests/species_knowledge_smoke_test.tscn",
		"res://scenes/tests/creature_mastery_familiar_smoke_test.tscn",
		"res://scenes/tests/familiar_polish_smoke_test.tscn",
		"res://scenes/tests/creature_observation_smoke_test.tscn",
	],
	"dependencies": [
		"tactical_ai_lab",
		"storm_drain_pack_encounter",
	],
	"controls": [
		"MOVE",
		"INTERACT",
		"FULL MENU",
		"MAGIC TAB",
		"CAST SUMMON",
		"COMBAT",
		"F8 RESET",
	],
	"manual_test": "docs/CREATURE_MASTERY_FAMILIAR_TRAINING_YARD_V1.md",
	"temporary_state": "save_slot_mastery_runtime_combat",
	"story_integrated": false,
	"limitations": [
		"Presence capacity is one in v1.",
		"Only Gremlin has a complete familiar blueprint and live observation catalog.",
		"Study plinths remain available as duplicate-safe developer shortcuts.",
		"Familiar movement does not yet use NavigationAgent pathfinding.",
		"Transformation support is architectural only in this slice.",
	],
	"launchable": true,
	"visible_in_launcher": true,
	"ci_validate": true,
	"timeout_seconds": 20,
}


func _append_supplemental_features() -> void:
	super._append_supplemental_features()
	for feature: Dictionary in visible_features:
		if str(feature.get("id", "")) == "familiar_training_yard":
			return
	visible_features.append(FAMILIAR_TRAINING_YARD_FEATURE.duplicate(true))
	visible_features.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("order", 0)) < int(b.get("order", 0))
	)


func _get_supplemental_feature_count() -> int:
	return super._get_supplemental_feature_count() + 1


func _get_supplemental_feature(feature_id: String) -> Dictionary:
	if feature_id == "familiar_training_yard":
		return FAMILIAR_TRAINING_YARD_FEATURE
	return super._get_supplemental_feature(feature_id)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["familiar_training_yard_available"] = (
		_get_feature_errors("familiar_training_yard").is_empty()
	)
	return data
