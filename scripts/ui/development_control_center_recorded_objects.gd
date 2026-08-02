extends "res://scripts/ui/development_control_center_field_progression.gd"

const RECORDED_OBJECTS_FEATURE: Dictionary = {
	"id": "recorded_objects_v1",
	"order": 19,
	"display_name": "Recorded Object Proving Ground",
	"category": "Progression and World Tools",
	"version": "v1",
	"status": "vertical_slice",
	"description": "Record and reproduce physical tools through Grace's production runtime, Items menu preparation, save-slot blueprints, field discoveries, camera placement, rotation, mana costs, collision validation, stacking, bridging, launching, explosions, and active-object limits.",
	"scene": "res://scenes/levels/prototypes/prototype_recorded_object_lab_v1.tscn",
	"validation_scenes": [
		"res://scenes/levels/prototypes/prototype_recorded_object_lab_v1.tscn",
		"res://scenes/levels/prototypes/prototype_ruined_village_field_progression_v1.tscn",
	],
	"automated_tests": [
		"res://scenes/tests/recorded_objects_v1_smoke_test.tscn",
		"res://scenes/tests/recorded_objects_production_integration_smoke_test.tscn",
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
		"ITEMS → OBJECTS PREPARE",
		"F1-F4 SELECT",
		"V / Y PLACEMENT",
		"Q/E OR L/R CYCLE",
		"R ROTATE",
		"CLICK / A PLACE",
		"F8 CLEAR",
	],
	"manual_test": "docs/RECORDED_OBJECTS_V1.md",
	"temporary_state": "persistent_save_slot_blueprints_scene_scoped_runtime_objects",
	"story_integrated": true,
	"limitations": [
		"The Ruined Village currently teaches Crate and Platform; Spring and Blast Barrel remain proving-ground discoveries.",
		"The first four actors and natural source props use procedural prototype visuals.",
		"Reproduced objects are scene-scoped and are dismissed on scene changes rather than serialized into saves.",
		"Engineering Builds remain a separate multi-part construction system.",
	],
	"launchable": true,
	"visible_in_launcher": true,
	"ci_validate": true,
	"timeout_seconds": 30,
}

const RECORDED_OBJECT_INTEROPERABILITY_FEATURE: Dictionary = {
	"id": "recorded_object_interoperability_v1",
	"order": 20,
	"display_name": "Recorded Object Interoperability Wing",
	"category": "Progression and World Tools",
	"version": "v1",
	"status": "development_tool",
	"description": "Stress-test recorded tools against Fire, Water, Ice, Lightning, Force, conductive contact, buoyancy, dampened fuses, overcharged launches, frozen shatter, chain explosions, and progression discoveries.",
	"scene": "res://scenes/levels/prototypes/prototype_recorded_object_interoperability_lab_v1.tscn",
	"validation_scenes": [
		"res://scenes/levels/prototypes/prototype_recorded_object_interoperability_lab_v1.tscn",
	],
	"automated_tests": [
		"res://scenes/tests/recorded_object_interoperability_smoke_test.tscn",
		"res://scenes/tests/recorded_objects_v1_smoke_test.tscn",
		"res://scenes/tests/recorded_objects_production_integration_smoke_test.tscn",
	],
	"dependencies": [
		"recorded_objects_v1",
		"progression_challenge_lab",
	],
	"controls": [
		"MOVE",
		"INTERACT CONSOLES",
		"F1-F4 SELECT OBJECT",
		"F5 PLACE ON ELEMENT PAD",
		"F6 DROP CRATE IN BASIN",
		"V / Y FREE PLACEMENT",
		"F8 CLEAR OBJECTS",
		"F9 RECORD ALL",
	],
	"manual_test": "docs/RECORDED_OBJECT_INTEROPERABILITY_V1.md",
	"temporary_state": "persistent_discoveries_scene_scoped_elemental_object_state",
	"story_integrated": false,
	"limitations": [
		"The elemental state machine is production-capable, but the dedicated console wing remains a development fixture.",
		"Conductive contact currently delivers a compact generic Lightning payload rather than participating in the full authored circuit graph.",
		"Buoyancy uses the shared FluidForceVolume API with a lightweight per-object force model.",
		"Prototype state changes recolor procedural materials; authored burn, frost, spark, and fracture VFX remain a later presentation pass.",
	],
	"launchable": true,
	"visible_in_launcher": true,
	"ci_validate": true,
	"timeout_seconds": 32,
}

const ENGINEERING_BUILDS_FEATURE: Dictionary = {
	"id": "engineering_builds_v1",
	"order": 21,
	"display_name": "Engineering Build Yard",
	"category": "Progression and World Tools",
	"version": "v1",
	"status": "vertical_slice",
	"description": "Save and reproduce multi-part constructions assembled from recorded object patterns: Bridge Frame, Launch Tower, Blast Cart, and Conductive Raft.",
	"scene": "res://scenes/levels/prototypes/prototype_engineering_build_yard_v1.tscn",
	"validation_scenes": [
		"res://scenes/levels/prototypes/prototype_engineering_build_yard_v1.tscn",
	],
	"automated_tests": [
		"res://scenes/tests/engineering_builds_v1_smoke_test.tscn",
		"res://scenes/tests/recorded_objects_v1_smoke_test.tscn",
		"res://scenes/tests/full_menu_items_v1_smoke_test.tscn",
		"res://scenes/tests/full_menu_journal_v1_smoke_test.tscn",
	],
	"dependencies": [
		"recorded_objects_v1",
		"recorded_object_interoperability_v1",
	],
	"controls": [
		"MOVE",
		"INTERACT BUILD STATIONS",
		"F1-F4 SELECT BUILD",
		"V / Y PLACEMENT",
		"Q/E OR L/R CYCLE",
		"R ROTATE",
		"CLICK / A PLACE",
		"F5 QUICK-PLACE",
		"F6 RAFT BASIN",
		"F8 CLEAR",
		"F9 SAVE ALL",
	],
	"manual_test": "docs/ENGINEERING_BUILDS_V1.md",
	"temporary_state": "persistent_build_blueprints_scene_scoped_constructions",
	"story_integrated": false,
	"limitations": [
		"Engineering Builds currently use a dedicated manager in the construction yard; production menu-to-field handoff is the next integration layer.",
		"Build blueprints require recorded component patterns but do not consume those patterns or physical objects.",
		"The first four builds use procedural prototype geometry rather than authored modular assets.",
		"Construction state is scene-scoped; saved blueprints persist in Items and Journal.",
	],
	"launchable": true,
	"visible_in_launcher": true,
	"ci_validate": true,
	"timeout_seconds": 36,
}


func _append_supplemental_features() -> void:
	super._append_supplemental_features()
	var supplemental: Array[Dictionary] = [
		RECORDED_OBJECTS_FEATURE,
		RECORDED_OBJECT_INTEROPERABILITY_FEATURE,
		ENGINEERING_BUILDS_FEATURE,
	]
	for definition: Dictionary in supplemental:
		var feature_id: String = str(definition.get("id", ""))
		var already_present: bool = false
		for feature: Dictionary in visible_features:
			if str(feature.get("id", "")) == feature_id:
				already_present = true
				break
		if not already_present:
			visible_features.append(definition.duplicate(true))
	visible_features.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("order", 0)) < int(b.get("order", 0))
	)


func _get_supplemental_feature_count() -> int:
	return super._get_supplemental_feature_count() + 3


func _get_supplemental_feature(feature_id: String) -> Dictionary:
	match feature_id:
		"recorded_objects_v1":
			return RECORDED_OBJECTS_FEATURE
		"recorded_object_interoperability_v1":
			return RECORDED_OBJECT_INTEROPERABILITY_FEATURE
		"engineering_builds_v1":
			return ENGINEERING_BUILDS_FEATURE
	return super._get_supplemental_feature(feature_id)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["recorded_objects_available"] = (
		_get_feature_errors("recorded_objects_v1").is_empty()
	)
	data["recorded_objects_production_integrated"] = true
	data["recorded_object_interoperability_available"] = (
		_get_feature_errors("recorded_object_interoperability_v1").is_empty()
	)
	data["engineering_builds_available"] = (
		_get_feature_errors("engineering_builds_v1").is_empty()
	)
	return data
