extends Node
class_name RenderImageQualityDirector

signal image_quality_changed(quality: int, tier_name: String)

@export var profile: RenderImageQualityProfile
@export var enabled: bool = true

var lighting_director: LightingDirector3D = null
var target_viewport: Viewport = null
var active_quality: int = -1
var original_state: Dictionary = {}
var initialized: bool = false
var apply_count: int = 0


func _ready() -> void:
	process_priority = 55
	add_to_group("render_image_quality_director")
	add_to_group("debuggable")
	_resolve_dependencies()
	_capture_original_state()
	initialized = profile != null and target_viewport != null
	set_meta("render_image_quality_initialized", initialized)
	if initialized:
		_apply_quality(_current_quality())


func _process(_delta: float) -> void:
	if not enabled or profile == null:
		return
	if target_viewport == null or not is_instance_valid(target_viewport):
		_resolve_dependencies()
	if target_viewport == null:
		return
	var requested: int = _current_quality()
	if requested != active_quality:
		_apply_quality(requested)


func set_enabled(value: bool) -> void:
	if enabled == value:
		return
	enabled = value
	if not enabled:
		_restore_original_state()
		return
	active_quality = -1
	_apply_quality(_current_quality())


func synchronize_now() -> void:
	if target_viewport == null or not is_instance_valid(target_viewport):
		_resolve_dependencies()
	if target_viewport == null or profile == null:
		return
	_apply_quality(_current_quality())


func _resolve_dependencies() -> void:
	target_viewport = get_viewport()
	lighting_director = null
	if get_tree() == null:
		return
	var candidate: Node = get_tree().get_first_node_in_group("lighting_director")
	if candidate is LightingDirector3D:
		lighting_director = candidate as LightingDirector3D


func _capture_original_state() -> void:
	if target_viewport == null or not original_state.is_empty():
		return
	original_state = {
		"use_taa": target_viewport.use_taa,
		"screen_space_aa": target_viewport.screen_space_aa,
		"msaa_3d": target_viewport.msaa_3d,
		"use_debanding": target_viewport.use_debanding,
	}


func _current_quality() -> int:
	if lighting_director == null:
		return 2
	return clampi(lighting_director.quality, 0, 2)


func _apply_quality(quality: int) -> void:
	if target_viewport == null or profile == null:
		return
	active_quality = clampi(quality, 0, 2)
	var tier: Dictionary = profile.get_tier(active_quality)
	target_viewport.use_taa = bool(tier.get("taa", false))
	target_viewport.screen_space_aa = clampi(
		int(tier.get("screen_space_aa", 0)),
		Viewport.SCREEN_SPACE_AA_DISABLED,
		Viewport.SCREEN_SPACE_AA_SMAA
	)
	target_viewport.msaa_3d = clampi(
		int(tier.get("msaa_3d", 0)),
		Viewport.MSAA_DISABLED,
		Viewport.MSAA_8X
	)
	target_viewport.use_debanding = bool(tier.get("debanding", false))
	apply_count += 1
	image_quality_changed.emit(active_quality, _tier_name(active_quality))


func _restore_original_state() -> void:
	if target_viewport == null or original_state.is_empty():
		return
	target_viewport.use_taa = bool(original_state.get("use_taa", false))
	target_viewport.screen_space_aa = int(original_state.get(
		"screen_space_aa",
		Viewport.SCREEN_SPACE_AA_DISABLED
	))
	target_viewport.msaa_3d = int(original_state.get(
		"msaa_3d",
		Viewport.MSAA_DISABLED
	))
	target_viewport.use_debanding = bool(original_state.get(
		"use_debanding",
		false
	))
	active_quality = -1


func _tier_name(quality: int) -> String:
	match quality:
		0:
			return "Performance"
		1:
			return "Balanced"
		_:
			return "Cinematic"


func _screen_space_label(value: int) -> String:
	match value:
		Viewport.SCREEN_SPACE_AA_FXAA:
			return "FXAA"
		Viewport.SCREEN_SPACE_AA_SMAA:
			return "SMAA"
		_:
			return "Off"


func _msaa_label(value: int) -> String:
	match value:
		Viewport.MSAA_2X:
			return "2x"
		Viewport.MSAA_4X:
			return "4x"
		Viewport.MSAA_8X:
			return "8x"
		_:
			return "Off"


func get_debug_data() -> Dictionary:
	return {
		"render_image_quality_director": true,
		"initialized": initialized,
		"profile_id": profile.profile_id if profile != null else "",
		"enabled": enabled,
		"quality": active_quality,
		"tier": _tier_name(active_quality),
		"taa": target_viewport.use_taa if target_viewport != null else false,
		"screen_space_aa": int(target_viewport.screen_space_aa) if target_viewport != null else -1,
		"screen_space_aa_label": _screen_space_label(int(target_viewport.screen_space_aa)) if target_viewport != null else "?",
		"msaa_3d": int(target_viewport.msaa_3d) if target_viewport != null else -1,
		"msaa_label": _msaa_label(int(target_viewport.msaa_3d)) if target_viewport != null else "?",
		"debanding": target_viewport.use_debanding if target_viewport != null else false,
		"apply_count": apply_count,
		"follows_lighting_quality": true,
		"root_viewport_only": true,
		"project_settings_unchanged": true,
		"geometry_unchanged": true,
		"gameplay_authority": false,
	}
