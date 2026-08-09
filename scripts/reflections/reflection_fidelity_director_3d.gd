extends Node3D
class_name ReflectionFidelityDirector3D

signal reflection_tier_changed(quality: int, tier_name: String)

@export var profile: ReflectionFidelityProfile
@export var lighting_director_path: NodePath
@export var enabled: bool = true

var lighting_director: LightingDirector3D = null
var regions: Array[ReflectionRegion3D] = []
var active_quality: int = -1
var active_tier: Dictionary = {}
var initialized: bool = false
var refresh_timer: float = 0.0
var active_probe_count: int = 0
var shadowed_probe_count: int = 0


func _ready() -> void:
	process_priority = 45
	add_to_group("reflection_fidelity_director")
	add_to_group("debuggable")
	call_deferred("_initialize")


func _process(delta: float) -> void:
	if not enabled or profile == null:
		return
	if not initialized:
		_try_initialize()
		if not initialized:
			return
	refresh_timer -= maxf(delta, 0.0)
	if refresh_timer <= 0.0:
		refresh_timer = 1.0
		_refresh_regions()
	var requested_quality: int = _current_lighting_quality()
	if requested_quality != active_quality:
		_apply_quality(requested_quality)


func _initialize() -> void:
	_try_initialize()


func _try_initialize() -> void:
	if profile == null:
		return
	_resolve_lighting_director()
	if lighting_director == null:
		return
	_refresh_regions()
	if regions.is_empty():
		return
	initialized = true
	set_meta("reflection_fidelity_initialized", true)
	_apply_quality(_current_lighting_quality())


func synchronize_now() -> void:
	if not initialized:
		_try_initialize()
	if not initialized:
		return
	_refresh_regions()
	_apply_quality(_current_lighting_quality())


func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		for region: ReflectionRegion3D in regions:
			if region.probe != null and is_instance_valid(region.probe):
				region.probe.visible = false
				region.probe.intensity = 0.0
		active_probe_count = 0
		shadowed_probe_count = 0
		return
	active_quality = -1
	synchronize_now()


func _resolve_lighting_director() -> void:
	lighting_director = null
	if not lighting_director_path.is_empty():
		var explicit: Node = get_node_or_null(lighting_director_path)
		if explicit is LightingDirector3D:
			lighting_director = explicit as LightingDirector3D
			return
	if get_tree() == null:
		return
	var candidate: Node = get_tree().get_first_node_in_group("lighting_director")
	if candidate is LightingDirector3D:
		lighting_director = candidate as LightingDirector3D


func _current_lighting_quality() -> int:
	if lighting_director == null:
		return 2
	return clampi(lighting_director.quality, 0, 2)


func _refresh_regions() -> void:
	var refreshed: Array[ReflectionRegion3D] = []
	if get_tree() == null:
		regions = refreshed
		return
	for candidate: Node in get_tree().get_nodes_in_group("reflection_region_3d"):
		if candidate is ReflectionRegion3D:
			var region: ReflectionRegion3D = candidate as ReflectionRegion3D
			if region.probe != null and is_instance_valid(region.probe):
				refreshed.append(region)
	regions = refreshed


func _apply_quality(quality: int) -> void:
	if profile == null:
		return
	active_quality = clampi(quality, 0, 2)
	active_tier = profile.get_tier(active_quality)
	active_probe_count = 0
	shadowed_probe_count = 0
	var tier_enabled: bool = bool(active_tier.get("enabled", false))
	var intensity_scale: float = maxf(
		float(active_tier.get("intensity_scale", 1.0)),
		0.0
	)
	var lod_threshold: float = maxf(
		float(active_tier.get("mesh_lod_threshold", 1.0)),
		0.1
	)
	var enable_shadows: bool = bool(active_tier.get("enable_shadows", false))

	for region: ReflectionRegion3D in regions:
		var probe: ReflectionProbe = region.probe
		if probe == null or not is_instance_valid(probe):
			continue
		var region_enabled: bool = (
			tier_enabled
			and active_quality >= region.minimum_quality
		)
		probe.visible = region_enabled
		probe.intensity = clampf(
			region.intensity * intensity_scale,
			0.0,
			profile.maximum_intensity
		) if region_enabled else 0.0
		probe.mesh_lod_threshold = lod_threshold
		probe.enable_shadows = region_enabled and enable_shadows
		probe.max_distance = minf(
			maxf(region.max_distance, 1.0),
			profile.maximum_capture_distance
		)
		probe.update_mode = ReflectionProbe.UPDATE_ONCE
		if region_enabled:
			active_probe_count += 1
			if probe.enable_shadows:
				shadowed_probe_count += 1
	reflection_tier_changed.emit(active_quality, _tier_name(active_quality))


func _tier_name(quality: int) -> String:
	match quality:
		0:
			return "Performance"
		1:
			return "Balanced"
		_:
			return "Cinematic"


func get_debug_data() -> Dictionary:
	var region_ids: Array[String] = []
	var box_projection_count: int = 0
	for region: ReflectionRegion3D in regions:
		region_ids.append(region.region_id)
		if region.probe != null and region.probe.box_projection:
			box_projection_count += 1
	return {
		"reflection_fidelity_director": true,
		"initialized": initialized,
		"profile_id": profile.profile_id if profile != null else "",
		"enabled": enabled,
		"quality": active_quality,
		"tier": _tier_name(active_quality),
		"region_count": regions.size(),
		"region_ids": region_ids,
		"active_probes": active_probe_count,
		"shadowed_probes": shadowed_probe_count,
		"box_projection_probes": box_projection_count,
		"update_once": true,
		"follows_lighting_quality": true,
		"geometry_unchanged": true,
		"physics_authority": false,
	}
