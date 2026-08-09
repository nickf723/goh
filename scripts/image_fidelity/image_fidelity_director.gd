extends Node
class_name ImageFidelityDirector

signal image_quality_changed(quality: int)

@export var profile: ImageFidelityProfile
@export var enabled: bool = true

var lighting_director: LightingDirector3D = null
var viewport: Viewport = null
var active_quality: int = -1
var original_taa: bool = false
var original_debanding: bool = false
var original_msaa_3d: int = Viewport.MSAA_DISABLED
var original_screen_space_aa: int = Viewport.SCREEN_SPACE_AA_DISABLED
var original_roughness_enabled: bool = true
var original_roughness_amount: float = 0.25
var original_roughness_limit: float = 0.18
var initialized: bool = false


func _ready() -> void:
	add_to_group("image_fidelity_director")
	add_to_group("debuggable")
	viewport = get_viewport()
	_capture_original_state()
	_resolve_lighting_director()
	initialized = profile != null and viewport != null
	set_meta("image_fidelity_initialized", initialized)
	if initialized:
		_apply_quality(_current_quality())


func _exit_tree() -> void:
	if initialized:
		_restore_original_state()


func _process(_delta: float) -> void:
	if not enabled or not initialized:
		return
	if lighting_director == null or not is_instance_valid(lighting_director):
		_resolve_lighting_director()
	var requested_quality: int = _current_quality()
	if requested_quality != active_quality:
		_apply_quality(requested_quality)


func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		_restore_original_state()
		return
	active_quality = -1
	_apply_quality(_current_quality())


func synchronize_now() -> void:
	if not initialized:
		return
	_apply_quality(_current_quality())


func _capture_original_state() -> void:
	if viewport == null:
		return
	original_taa = viewport.use_taa
	original_debanding = viewport.use_debanding
	original_msaa_3d = int(viewport.msaa_3d)
	original_screen_space_aa = int(viewport.screen_space_aa)
	original_roughness_enabled = bool(ProjectSettings.get_setting(
		"rendering/anti_aliasing/screen_space_roughness_limiter/enabled",
		true
	))
	original_roughness_amount = float(ProjectSettings.get_setting(
		"rendering/anti_aliasing/screen_space_roughness_limiter/amount",
		0.25
	))
	original_roughness_limit = float(ProjectSettings.get_setting(
		"rendering/anti_aliasing/screen_space_roughness_limiter/limit",
		0.18
	))


func _resolve_lighting_director() -> void:
	lighting_director = null
	if get_tree() == null:
		return
	var candidate: Node = get_tree().get_first_node_in_group("lighting_director")
	if candidate is LightingDirector3D:
		lighting_director = candidate as LightingDirector3D


func _current_quality() -> int:
	if lighting_director == null:
		return 2
	return clampi(lighting_director.quality, 0, 2)


func _apply_quality(quality: int) -> void:
	if profile == null or viewport == null:
		return
	active_quality = clampi(quality, 0, 2)
	var tier: Dictionary = profile.get_tier(active_quality)
	viewport.use_taa = bool(tier.get("taa", false))
	viewport.use_debanding = bool(tier.get("debanding", false))
	viewport.msaa_3d = (
		Viewport.MSAA_2X
		if bool(tier.get("msaa_2x", false))
		else Viewport.MSAA_DISABLED
	)
	# The profile owns the final anti-aliasing policy. Green Grotto's Balanced and
	# Hero tiers intentionally prefer non-temporal MSAA so camera motion stays crisp
	# instead of accumulating the soft ghosting that TAA introduced in the lab.
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	RenderingServer.screen_space_roughness_limiter_set_active(
		bool(tier.get("roughness_limiter", false)),
		clampf(float(tier.get("roughness_amount", 0.25)), 0.0, 1.0),
		clampf(float(tier.get("roughness_limit", 0.18)), 0.0, 1.0)
	)
	image_quality_changed.emit(active_quality)


func _restore_original_state() -> void:
	if viewport == null:
		return
	viewport.use_taa = original_taa
	viewport.use_debanding = original_debanding
	viewport.msaa_3d = original_msaa_3d
	viewport.screen_space_aa = original_screen_space_aa
	RenderingServer.screen_space_roughness_limiter_set_active(
		original_roughness_enabled,
		original_roughness_amount,
		original_roughness_limit
	)


func get_debug_data() -> Dictionary:
	return {
		"image_fidelity_director": true,
		"initialized": initialized,
		"profile_id": profile.profile_id if profile != null else "",
		"enabled": enabled,
		"quality": active_quality,
		"taa": viewport.use_taa if viewport != null else false,
		"debanding": viewport.use_debanding if viewport != null else false,
		"msaa_3d": int(viewport.msaa_3d) if viewport != null else -1,
		"screen_space_aa": int(viewport.screen_space_aa) if viewport != null else -1,
		"follows_lighting_quality": true,
		"performance_is_raw": true,
		"balanced_temporal_aa": false,
		"cinematic_temporal_plus_msaa": false,
		"motion_clarity_non_temporal": true,
		"restores_on_exit": true,
		"gameplay_authority": false,
	}
