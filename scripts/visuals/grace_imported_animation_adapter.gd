extends Node
class_name GraceImportedAnimationAdapter

const AnimationContractScript = preload("res://scripts/visuals/grace_animation_library_contract.gd")

@export var animation_player_path: NodePath
@export var require_core_library: bool = true

var animation_player: AnimationPlayer
var semantic_clips: Dictionary = {}
var validation: Dictionary = {}


func _ready() -> void:
	resolve_library()
	add_to_group("grace_imported_animation_adapter")
	add_to_group("debuggable")


func resolve_library() -> bool:
	animation_player = get_node_or_null(animation_player_path) as AnimationPlayer if animation_player_path != NodePath() else null
	if animation_player == null:
		animation_player = AnimationContractScript.find_animation_player(get_parent())
	semantic_clips = AnimationContractScript.build_semantic_map(animation_player)
	validation = AnimationContractScript.validate_player(animation_player)
	return is_compatible()


func is_compatible() -> bool:
	if animation_player == null:
		return false
	if require_core_library:
		return bool(validation.get("compatible_core", false))
	return not semantic_clips.is_empty()


func has_semantic(semantic: String) -> bool:
	return semantic_clips.has(semantic)


func get_animation_name(semantic: String) -> StringName:
	if not semantic_clips.has(semantic):
		return StringName()
	return StringName(semantic_clips[semantic])


func get_animation(semantic: String) -> Animation:
	var animation_name: StringName = get_animation_name(semantic)
	if animation_player == null or animation_name == StringName():
		return null
	return animation_player.get_animation(animation_name)


func get_debug_data() -> Dictionary:
	return {
		"imported_animation_adapter": true,
		"compatible": is_compatible(),
		"animation_player_found": animation_player != null,
		"mapped_semantics": semantic_clips.size(),
		"core_ready": bool(validation.get("compatible_core", false)),
		"sword_calibration_ready": bool(validation.get("sword_calibration_ready", false)),
		"missing_core": validation.get("missing_core", []),
		"missing_sword": validation.get("missing_sword", []),
	}
