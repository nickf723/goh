extends Resource
class_name EnvironmentKitDefinition

@export var kit_id: String = "environment_kit"
@export var display_name: String = "Environment Kit"
@export var dialect_id: String = "global"
@export var global_art_bible_path: String = "res://docs/GLOBAL_ART_BIBLE_V0_1.md"
@export var dialect_doc_path: String = ""
@export var calibration_scene_path: String = ""
@export var module_scene_paths: Array[String] = []
@export var authoring_dcc: String = "Blender"
@export var unit_scale_meters: float = 1.0
@export var placeholder_only: bool = true


func get_module_count() -> int:
	return module_scene_paths.size()


func get_debug_data() -> Dictionary:
	return {
		"environment_kit_definition": true,
		"kit_id": kit_id,
		"display_name": display_name,
		"dialect_id": dialect_id,
		"global_art_bible_path": global_art_bible_path,
		"dialect_doc_path": dialect_doc_path,
		"calibration_scene_path": calibration_scene_path,
		"module_count": module_scene_paths.size(),
		"module_scene_paths": module_scene_paths.duplicate(),
		"authoring_dcc": authoring_dcc,
		"unit_scale_meters": unit_scale_meters,
		"placeholder_only": placeholder_only,
	}
