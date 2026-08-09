extends Node3D
class_name ShadowFidelityDirector3D

signal shadow_tier_changed(quality: int, tier_name: String)

@export var profile: ShadowFidelityProfile
@export var lighting_director_path: NodePath
@export var enabled: bool = true

var lighting_director: LightingDirector3D = null
var sun: DirectionalLight3D = null
var active_quality: int = -1
var active_tier: Dictionary = {}
var managed_foliage: Dictionary = {}
var accent_lights: Array[OmniLight3D] = []
var refresh_timer: float = 0.0
var initialized: bool = false
var last_directional_atlas_size: int = 0
var last_positional_atlas_size: int = 0
var last_filter_quality: int = -1


func _ready() -> void:
	process_priority = 40
	add_to_group("shadow_fidelity_director")
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
		refresh_timer = 0.75
		_refresh_managed_nodes()

	var requested_quality: int = _current_lighting_quality()
	if requested_quality != active_quality:
		_apply_quality(requested_quality)
	else:
		# LightingDirector updates its authored sun state every frame. Reassert the
		# shadow-specific distance afterward so the two systems never fight.
		_apply_sun_shadow_distance()


func _initialize() -> void:
	_try_initialize()


func _try_initialize() -> void:
	if profile == null:
		return
	_resolve_lighting_director()
	if lighting_director == null:
		return
	if lighting_director.sun == null:
		return
	sun = lighting_director.sun
	_refresh_managed_nodes()
	initialized = true
	set_meta("shadow_fidelity_initialized", true)
	_apply_quality(_current_lighting_quality())


func synchronize_now() -> void:
	if not initialized:
		_try_initialize()
	if not initialized:
		return
	_refresh_managed_nodes()
	_apply_quality(_current_lighting_quality())


func set_enabled(value: bool) -> void:
	if enabled == value:
		return
	enabled = value
	if not enabled:
		_restore_managed_nodes()
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


func _apply_quality(quality: int) -> void:
	if profile == null or sun == null:
		return
	active_quality = clampi(quality, 0, 2)
	active_tier = profile.get_tier(active_quality)

	last_directional_atlas_size = int(active_tier.get("atlas", 4096))
	last_positional_atlas_size = int(active_tier.get("positional_atlas", 2048))
	last_filter_quality = clampi(int(active_tier.get("filter", 2)), 0, 5)
	RenderingServer.directional_shadow_atlas_set_size(
		last_directional_atlas_size,
		false
	)
	RenderingServer.directional_soft_shadow_filter_set_quality(
		last_filter_quality
	)
	var viewport: Viewport = get_viewport()
	if viewport != null:
		viewport.positional_shadow_atlas_size = last_positional_atlas_size
		viewport.positional_shadow_atlas_16_bits = active_quality == 0

	_apply_sun_parameters()
	_apply_accent_shadow_policy()
	_apply_foliage_shadow_policy()
	shadow_tier_changed.emit(active_quality, _tier_name(active_quality))


func _apply_sun_parameters() -> void:
	if sun == null or active_tier.is_empty():
		return
	sun.shadow_enabled = true
	sun.directional_shadow_mode = int(active_tier.get(
		"mode",
		DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	))
	sun.directional_shadow_blend_splits = bool(active_tier.get("blend_splits", true))
	sun.directional_shadow_fade_start = clampf(
		float(active_tier.get("fade_start", 0.85)),
		0.0,
		1.0
	)
	sun.directional_shadow_split_1 = profile.split_1
	sun.directional_shadow_split_2 = profile.split_2
	sun.directional_shadow_split_3 = profile.split_3
	sun.directional_shadow_pancake_size = maxf(
		float(active_tier.get("pancake", 10.0)),
		0.0
	)
	sun.shadow_bias = maxf(float(active_tier.get("bias", 0.06)), 0.0)
	sun.shadow_normal_bias = maxf(
		float(active_tier.get("normal_bias", 1.0)),
		0.0
	)
	sun.shadow_blur = maxf(float(active_tier.get("blur", 1.0)), 0.0)
	sun.shadow_opacity = clampf(
		float(active_tier.get("opacity", 1.0)),
		0.0,
		1.0
	)
	sun.shadow_transmittance_bias = maxf(profile.transmittance_bias, 0.0)
	sun.light_angular_distance = maxf(
		float(active_tier.get("angular_distance", 0.0)),
		0.0
	)
	_apply_sun_shadow_distance()


func _apply_sun_shadow_distance() -> void:
	if sun == null or active_tier.is_empty():
		return
	sun.directional_shadow_max_distance = maxf(
		float(active_tier.get("distance", 80.0)),
		1.0
	)


func _refresh_managed_nodes() -> void:
	_refresh_accent_lights()
	_refresh_foliage_targets()
	if not active_tier.is_empty():
		_apply_accent_shadow_policy()
		_apply_foliage_shadow_policy()


func _refresh_accent_lights() -> void:
	var refreshed: Array[OmniLight3D] = []
	if get_tree() == null:
		accent_lights = refreshed
		return
	for candidate: Node in get_tree().get_nodes_in_group("lighting_zone_3d"):
		if not candidate is LightingZone3D:
			continue
		var zone: LightingZone3D = candidate as LightingZone3D
		if lighting_director != null and zone.channel != lighting_director.channel:
			continue
		if zone.accent_light != null and is_instance_valid(zone.accent_light):
			refreshed.append(zone.accent_light)
	accent_lights = refreshed


func _refresh_foliage_targets() -> void:
	if get_tree() == null:
		return
	for candidate: Node in get_tree().get_nodes_in_group("vegetation_presentation_target"):
		if not candidate is MeshInstance3D:
			continue
		var mesh_instance: MeshInstance3D = candidate as MeshInstance3D
		var target_id: int = mesh_instance.get_instance_id()
		if managed_foliage.has(target_id):
			continue
		managed_foliage[target_id] = {
			"ref": weakref(mesh_instance),
			"original_cast_shadow": mesh_instance.cast_shadow,
			"role": str(mesh_instance.get_meta("vegetation_presentation_role", "ground")),
		}


func _apply_accent_shadow_policy() -> void:
	var allow_shadows: bool = bool(active_tier.get("accent_shadows", false))
	for light: OmniLight3D in accent_lights:
		if light == null or not is_instance_valid(light):
			continue
		light.shadow_enabled = allow_shadows
		if allow_shadows:
			light.shadow_bias = 0.075 if active_quality == 2 else 0.10
			light.shadow_normal_bias = 1.0 if active_quality == 2 else 1.25
			light.shadow_blur = 1.05
			light.shadow_opacity = 0.92


func _apply_foliage_shadow_policy() -> void:
	var invalid_ids: Array[int] = []
	var double_close: bool = bool(active_tier.get("double_sided_close", false))
	var double_canopy: bool = bool(active_tier.get("double_sided_canopy", false))
	for raw_id: Variant in managed_foliage.keys():
		var target_id: int = int(raw_id)
		var record: Dictionary = managed_foliage[target_id] as Dictionary
		var weak_value: Variant = record.get("ref", null)
		if not weak_value is WeakRef:
			invalid_ids.append(target_id)
			continue
		var target_value: Variant = (weak_value as WeakRef).get_ref()
		if not target_value is MeshInstance3D:
			invalid_ids.append(target_id)
			continue
		var mesh_instance: MeshInstance3D = target_value as MeshInstance3D
		var role: String = str(record.get("role", "ground"))
		var use_double_sided: bool = double_canopy if role == "canopy" else double_close
		if use_double_sided:
			mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
		else:
			mesh_instance.cast_shadow = int(record.get(
				"original_cast_shadow",
				GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			))
	for target_id: int in invalid_ids:
		managed_foliage.erase(target_id)


func _restore_managed_nodes() -> void:
	for raw_id: Variant in managed_foliage.keys():
		var record: Dictionary = managed_foliage[int(raw_id)] as Dictionary
		var weak_value: Variant = record.get("ref", null)
		if not weak_value is WeakRef:
			continue
		var target_value: Variant = (weak_value as WeakRef).get_ref()
		if target_value is MeshInstance3D:
			(target_value as MeshInstance3D).cast_shadow = int(record.get(
				"original_cast_shadow",
				GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			))
	for light: OmniLight3D in accent_lights:
		if light != null and is_instance_valid(light):
			light.shadow_enabled = false


func _tier_name(quality: int) -> String:
	match quality:
		0:
			return "Performance"
		1:
			return "Balanced"
		_:
			return "Cinematic"


func get_debug_data() -> Dictionary:
	var double_sided_count: int = 0
	for raw_id: Variant in managed_foliage.keys():
		var record: Dictionary = managed_foliage[int(raw_id)] as Dictionary
		var weak_value: Variant = record.get("ref", null)
		if weak_value is WeakRef:
			var target_value: Variant = (weak_value as WeakRef).get_ref()
			if (
				target_value is MeshInstance3D
				and (target_value as MeshInstance3D).cast_shadow
				== GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
			):
				double_sided_count += 1
	var accent_shadow_count: int = 0
	for light: OmniLight3D in accent_lights:
		if light != null and is_instance_valid(light) and light.shadow_enabled:
			accent_shadow_count += 1
	return {
		"shadow_fidelity_director": true,
		"initialized": initialized,
		"profile_id": profile.profile_id if profile != null else "",
		"enabled": enabled,
		"quality": active_quality,
		"tier": _tier_name(active_quality),
		"directional_atlas_size": last_directional_atlas_size,
		"positional_atlas_size": last_positional_atlas_size,
		"filter_quality": last_filter_quality,
		"sun": sun.name if sun != null and is_instance_valid(sun) else "",
		"sun_shadow_distance": sun.directional_shadow_max_distance if sun != null else 0.0,
		"sun_shadow_mode": sun.directional_shadow_mode if sun != null else -1,
		"sun_bias": sun.shadow_bias if sun != null else 0.0,
		"sun_normal_bias": sun.shadow_normal_bias if sun != null else 0.0,
		"sun_angular_distance": sun.light_angular_distance if sun != null else 0.0,
		"accent_lights": accent_lights.size(),
		"accent_shadow_lights": accent_shadow_count,
		"managed_foliage": managed_foliage.size(),
		"double_sided_foliage_shadows": double_sided_count,
		"follows_lighting_quality": true,
		"geometry_unchanged": true,
	}
