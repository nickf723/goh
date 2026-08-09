extends Node3D
class_name LightingDirector3D

signal lighting_state_changed(profile_id: String, active_zones: Array[String])

enum Quality {
	PERFORMANCE,
	BALANCED,
	CINEMATIC,
}

@export var default_profile: LightingProfile
@export var channel: String = "world"
@export_enum("Performance", "Balanced", "Cinematic") var quality: int = Quality.CINEMATIC
@export_range(0.0, 8.0, 0.05) var transition_seconds: float = 1.25
@export var target_group: String = "player"
@export var environment_path: NodePath
@export var sun_path: NodePath
@export var fill_light_path: NodePath
@export var enabled: bool = true
@export var debug_hotkeys_enabled: bool = false

var environment_node: WorldEnvironment = null
var environment: Environment = null
var sun: DirectionalLight3D = null
var fill_light: DirectionalLight3D = null
var sky_material: ProceduralSkyMaterial = null
var camera_attributes: CameraAttributesPractical = null
var target_actor: Node3D = null
var current_state: Dictionary = {}
var target_state: Dictionary = {}
var active_zone_ids: Array[String] = []
var initialized: bool = false
var last_signature: String = ""


func _ready() -> void:
	add_to_group("lighting_director")
	add_to_group("debuggable")
	call_deferred("_initialize")


func _process(delta: float) -> void:
	if not enabled or not initialized or default_profile == null:
		return
	_resolve_target_actor()
	var sample_position: Vector3 = global_position
	if target_actor != null and is_instance_valid(target_actor):
		sample_position = target_actor.global_position
	target_state = sample_state_at(sample_position)
	var alpha: float = 1.0
	if transition_seconds > 0.001:
		alpha = 1.0 - exp(-maxf(delta, 0.0) / transition_seconds * 4.0)
	current_state = _blend_state(current_state, target_state, clampf(alpha, 0.0, 1.0))
	_apply_state(current_state)
	_emit_signature_if_changed()


func _unhandled_input(event: InputEvent) -> void:
	if not debug_hotkeys_enabled or not initialized:
		return
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode != KEY_F7:
		return
	set_quality((quality + 1) % 3)
	print("Lighting Director quality: ", _quality_label())
	get_viewport().set_input_as_handled()


func _initialize() -> void:
	if default_profile == null:
		push_warning("LightingDirector3D has no default profile.")
		return
	_resolve_render_targets()
	if environment_node == null or environment == null or sun == null or fill_light == null:
		push_warning("LightingDirector3D could not resolve its render targets.")
		return
	_install_camera_attributes()
	_install_sky_material()
	_apply_quality_settings()
	current_state = _profile_to_state(default_profile)
	target_state = current_state.duplicate(true)
	_apply_state(current_state)
	_resolve_target_actor()
	initialized = true
	set_meta("lighting_director_initialized", true)
	_emit_signature_if_changed()


func sample_state_at(world_position: Vector3) -> Dictionary:
	if default_profile == null:
		return {}
	var state: Dictionary = _profile_to_state(default_profile)
	active_zone_ids.clear()
	var zones: Array[LightingZone3D] = _get_zones()
	for zone: LightingZone3D in zones:
		if zone.profile == null:
			continue
		var weight: float = zone.get_blend_weight(world_position)
		if weight <= 0.0:
			continue
		state = _blend_state(state, _profile_to_state(zone.profile), weight)
		if weight >= 0.04:
			active_zone_ids.append("%s:%.2f" % [zone.profile.profile_id, weight])
	return state


func set_quality(value: int) -> void:
	quality = clampi(value, Quality.PERFORMANCE, Quality.CINEMATIC)
	if initialized:
		_apply_quality_settings()
		_apply_state(current_state)


func force_profile(profile: LightingProfile) -> void:
	if profile == null:
		return
	default_profile = profile
	current_state = _profile_to_state(profile)
	target_state = current_state.duplicate(true)
	if initialized:
		_apply_quality_settings()
		_apply_state(current_state)


func _resolve_render_targets() -> void:
	environment_node = _resolve_environment_node()
	if environment_node == null:
		environment_node = WorldEnvironment.new()
		environment_node.name = "DirectedWorldEnvironment"
		environment_node.environment = Environment.new()
		add_child(environment_node)
	if environment_node.environment == null:
		environment_node.environment = Environment.new()
	environment = environment_node.environment

	sun = _resolve_directional_light(sun_path, ["CanopySunset", "LateAfternoonSun", "Sun"])
	if sun == null:
		sun = DirectionalLight3D.new()
		sun.name = "DirectedSun"
		add_child(sun)
	fill_light = _resolve_directional_light(fill_light_path, ["GrottoGreenFill", "SkyFill", "Fill"])
	if fill_light == null or fill_light == sun:
		fill_light = DirectionalLight3D.new()
		fill_light.name = "DirectedFill"
		add_child(fill_light)


func _resolve_environment_node() -> WorldEnvironment:
	if not environment_path.is_empty():
		var explicit: Node = get_node_or_null(environment_path)
		if explicit is WorldEnvironment:
			return explicit as WorldEnvironment
	var scene_root: Node = get_tree().current_scene if get_tree() != null else null
	return _find_world_environment_recursive(scene_root)


func _resolve_directional_light(path: NodePath, preferred_names: Array[String]) -> DirectionalLight3D:
	if not path.is_empty():
		var explicit: Node = get_node_or_null(path)
		if explicit is DirectionalLight3D:
			return explicit as DirectionalLight3D
	var scene_root: Node = get_tree().current_scene if get_tree() != null else null
	for preferred_name: String in preferred_names:
		var named: DirectionalLight3D = _find_directional_by_name_recursive(scene_root, preferred_name)
		if named != null:
			return named
	return _find_first_directional_recursive(scene_root)


func _find_world_environment_recursive(node: Node) -> WorldEnvironment:
	if node == null:
		return null
	if node is WorldEnvironment:
		return node as WorldEnvironment
	for child: Node in node.get_children():
		var found: WorldEnvironment = _find_world_environment_recursive(child)
		if found != null:
			return found
	return null


func _find_directional_by_name_recursive(node: Node, preferred_name: String) -> DirectionalLight3D:
	if node == null:
		return null
	if node is DirectionalLight3D and str(node.name) == preferred_name:
		return node as DirectionalLight3D
	for child: Node in node.get_children():
		var found: DirectionalLight3D = _find_directional_by_name_recursive(child, preferred_name)
		if found != null:
			return found
	return null


func _find_first_directional_recursive(node: Node) -> DirectionalLight3D:
	if node == null:
		return null
	if node is DirectionalLight3D:
		return node as DirectionalLight3D
	for child: Node in node.get_children():
		var found: DirectionalLight3D = _find_first_directional_recursive(child)
		if found != null:
			return found
	return null


func _install_sky_material() -> void:
	sky_material = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY


func _install_camera_attributes() -> void:
	if environment_node.camera_attributes is CameraAttributesPractical:
		camera_attributes = environment_node.camera_attributes as CameraAttributesPractical
	else:
		camera_attributes = CameraAttributesPractical.new()
		environment_node.camera_attributes = camera_attributes


func _apply_quality_settings() -> void:
	if environment == null or default_profile == null:
		return
	var gi_allowed: bool = quality >= Quality.BALANCED
	var cinematic: bool = quality == Quality.CINEMATIC
	environment.sdfgi_enabled = gi_allowed and default_profile.sdfgi_enabled
	environment.sdfgi_energy = default_profile.sdfgi_energy
	environment.sdfgi_cascades = default_profile.sdfgi_cascades if cinematic else mini(default_profile.sdfgi_cascades, 2)
	environment.sdfgi_min_cell_size = default_profile.sdfgi_min_cell_size if cinematic else maxf(default_profile.sdfgi_min_cell_size, 0.38)
	environment.sdfgi_use_occlusion = default_profile.sdfgi_use_occlusion
	environment.sdfgi_read_sky_light = default_profile.sdfgi_read_sky_light
	environment.ssil_enabled = gi_allowed and default_profile.ssil_enabled
	environment.ssr_enabled = cinematic and default_profile.ssr_enabled
	environment.ssr_max_steps = default_profile.ssr_max_steps if cinematic else mini(default_profile.ssr_max_steps, 48)


func _apply_state(state: Dictionary) -> void:
	if environment == null or sky_material == null or sun == null or fill_light == null:
		return
	sky_material.sky_top_color = state.get("sky_top_color", Color.BLACK)
	sky_material.sky_horizon_color = state.get("sky_horizon_color", Color.BLACK)
	sky_material.ground_bottom_color = state.get("ground_bottom_color", Color.BLACK)
	sky_material.ground_horizon_color = state.get("ground_horizon_color", Color.BLACK)
	sky_material.sun_angle_max = float(state.get("sky_sun_angle_max", 18.0))
	sky_material.sun_curve = float(state.get("sky_sun_curve", 0.08))
	environment.background_energy_multiplier = float(state.get("background_energy", 0.65))

	sun.rotation_degrees = state.get("sun_rotation_degrees", Vector3(-38.0, 20.0, 0.0))
	sun.light_color = state.get("sun_color", Color.WHITE)
	sun.light_energy = float(state.get("sun_energy", 1.0))
	sun.light_volumetric_fog_energy = float(state.get("sun_volumetric_energy", 1.0))
	sun.directional_shadow_max_distance = float(state.get("sun_shadow_distance", 100.0))
	sun.shadow_enabled = true
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY

	fill_light.rotation_degrees = state.get("fill_rotation_degrees", Vector3(-62.0, 150.0, 0.0))
	fill_light.light_color = state.get("fill_color", Color(0.3, 0.4, 0.6, 1.0))
	fill_light.light_energy = float(state.get("fill_energy", 0.3))
	fill_light.light_volumetric_fog_energy = float(state.get("fill_volumetric_energy", 0.1))
	fill_light.shadow_enabled = false
	fill_light.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY

	environment.ambient_light_color = state.get("ambient_color", Color.WHITE)
	environment.ambient_light_energy = float(state.get("ambient_energy", 0.5))
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = float(state.get("tonemap_exposure", 1.0))
	environment.tonemap_white = float(state.get("tonemap_white", 1.4))

	environment.fog_enabled = bool(state.get("fog_enabled", true))
	environment.fog_light_color = state.get("fog_color", Color.WHITE)
	environment.fog_light_energy = float(state.get("fog_light_energy", 0.5))
	environment.fog_density = float(state.get("fog_density", 0.004))
	environment.fog_height = float(state.get("fog_height", 3.0))
	environment.fog_height_density = float(state.get("fog_height_density", 0.06))
	environment.fog_sun_scatter = float(state.get("fog_sun_scatter", 0.45))
	environment.fog_sky_affect = float(state.get("fog_sky_affect", 0.55))

	var volumetric_allowed: bool = quality >= Quality.BALANCED
	environment.volumetric_fog_enabled = volumetric_allowed and bool(state.get("volumetric_fog_enabled", true))
	environment.volumetric_fog_density = float(state.get("volumetric_fog_density", 0.014))
	environment.volumetric_fog_albedo = state.get("volumetric_fog_albedo", Color.WHITE)
	environment.volumetric_fog_emission = state.get("volumetric_fog_emission", Color.BLACK)
	environment.volumetric_fog_emission_energy = float(state.get("volumetric_fog_emission_energy", 0.05))
	environment.volumetric_fog_anisotropy = float(state.get("volumetric_fog_anisotropy", 0.55))
	environment.volumetric_fog_length = float(state.get("volumetric_fog_length", 64.0))
	environment.volumetric_fog_detail_spread = float(state.get("volumetric_fog_detail_spread", 1.8))
	environment.volumetric_fog_ambient_inject = float(state.get("volumetric_fog_ambient_inject", 0.28))
	environment.volumetric_fog_gi_inject = float(state.get("volumetric_fog_gi_inject", 0.8))
	environment.volumetric_fog_sky_affect = float(state.get("volumetric_fog_sky_affect", 0.75))
	environment.volumetric_fog_temporal_reprojection_enabled = true

	environment.glow_enabled = bool(state.get("glow_enabled", true))
	environment.glow_intensity = float(state.get("glow_intensity", 0.18))
	environment.glow_bloom = float(state.get("glow_bloom", 0.03))
	environment.glow_hdr_threshold = float(state.get("glow_hdr_threshold", 1.4))
	environment.ssao_enabled = bool(state.get("ssao_enabled", true))
	environment.ssao_intensity = float(state.get("ssao_intensity", 1.65))
	environment.ssao_radius = float(state.get("ssao_radius", 2.2))
	if quality >= Quality.BALANCED:
		environment.ssil_intensity = float(state.get("ssil_intensity", 0.85))
		environment.ssil_radius = float(state.get("ssil_radius", 4.0))
	environment.sdfgi_energy = float(state.get("sdfgi_energy", default_profile.sdfgi_energy))

	if camera_attributes != null:
		camera_attributes.exposure_multiplier = float(state.get("camera_exposure_multiplier", 1.0))
		camera_attributes.auto_exposure_enabled = bool(state.get("auto_exposure_enabled", true))
		camera_attributes.auto_exposure_speed = float(state.get("auto_exposure_speed", 0.65))
		camera_attributes.auto_exposure_scale = float(state.get("auto_exposure_scale", 0.42))
		camera_attributes.auto_exposure_min_sensitivity = float(state.get("auto_exposure_min_sensitivity", 60.0))
		camera_attributes.auto_exposure_max_sensitivity = float(state.get("auto_exposure_max_sensitivity", 640.0))


func _resolve_target_actor() -> void:
	if target_actor != null and is_instance_valid(target_actor):
		return
	target_actor = null
	if get_tree() == null:
		return
	var candidate: Node = get_tree().get_first_node_in_group(target_group)
	if candidate is Node3D:
		target_actor = candidate as Node3D


func _get_zones() -> Array[LightingZone3D]:
	var zones: Array[LightingZone3D] = []
	if get_tree() == null:
		return zones
	for candidate: Node in get_tree().get_nodes_in_group("lighting_zone_3d"):
		if candidate is LightingZone3D:
			var zone := candidate as LightingZone3D
			if zone.channel == channel:
				zones.append(zone)
	zones.sort_custom(Callable(self, "_sort_zones"))
	return zones


func _sort_zones(a: LightingZone3D, b: LightingZone3D) -> bool:
	if a.priority == b.priority:
		return str(a.get_path()) < str(b.get_path())
	return a.priority < b.priority


func _profile_to_state(profile: LightingProfile) -> Dictionary:
	return {
		"sky_top_color": profile.sky_top_color,
		"sky_horizon_color": profile.sky_horizon_color,
		"ground_bottom_color": profile.ground_bottom_color,
		"ground_horizon_color": profile.ground_horizon_color,
		"sky_sun_angle_max": profile.sky_sun_angle_max,
		"sky_sun_curve": profile.sky_sun_curve,
		"background_energy": profile.background_energy,
		"sun_rotation_degrees": profile.sun_rotation_degrees,
		"sun_color": profile.sun_color,
		"sun_energy": profile.sun_energy,
		"sun_volumetric_energy": profile.sun_volumetric_energy,
		"sun_shadow_distance": profile.sun_shadow_distance,
		"fill_rotation_degrees": profile.fill_rotation_degrees,
		"fill_color": profile.fill_color,
		"fill_energy": profile.fill_energy,
		"fill_volumetric_energy": profile.fill_volumetric_energy,
		"ambient_color": profile.ambient_color,
		"ambient_energy": profile.ambient_energy,
		"tonemap_exposure": profile.tonemap_exposure,
		"tonemap_white": profile.tonemap_white,
		"camera_exposure_multiplier": profile.camera_exposure_multiplier,
		"auto_exposure_enabled": profile.auto_exposure_enabled,
		"auto_exposure_speed": profile.auto_exposure_speed,
		"auto_exposure_scale": profile.auto_exposure_scale,
		"auto_exposure_min_sensitivity": profile.auto_exposure_min_sensitivity,
		"auto_exposure_max_sensitivity": profile.auto_exposure_max_sensitivity,
		"fog_enabled": profile.fog_enabled,
		"fog_color": profile.fog_color,
		"fog_light_energy": profile.fog_light_energy,
		"fog_density": profile.fog_density,
		"fog_height": profile.fog_height,
		"fog_height_density": profile.fog_height_density,
		"fog_sun_scatter": profile.fog_sun_scatter,
		"fog_sky_affect": profile.fog_sky_affect,
		"volumetric_fog_enabled": profile.volumetric_fog_enabled,
		"volumetric_fog_density": profile.volumetric_fog_density,
		"volumetric_fog_albedo": profile.volumetric_fog_albedo,
		"volumetric_fog_emission": profile.volumetric_fog_emission,
		"volumetric_fog_emission_energy": profile.volumetric_fog_emission_energy,
		"volumetric_fog_anisotropy": profile.volumetric_fog_anisotropy,
		"volumetric_fog_length": profile.volumetric_fog_length,
		"volumetric_fog_detail_spread": profile.volumetric_fog_detail_spread,
		"volumetric_fog_ambient_inject": profile.volumetric_fog_ambient_inject,
		"volumetric_fog_gi_inject": profile.volumetric_fog_gi_inject,
		"volumetric_fog_sky_affect": profile.volumetric_fog_sky_affect,
		"glow_enabled": profile.glow_enabled,
		"glow_intensity": profile.glow_intensity,
		"glow_bloom": profile.glow_bloom,
		"glow_hdr_threshold": profile.glow_hdr_threshold,
		"ssao_enabled": profile.ssao_enabled,
		"ssao_intensity": profile.ssao_intensity,
		"ssao_radius": profile.ssao_radius,
		"ssil_intensity": profile.ssil_intensity,
		"ssil_radius": profile.ssil_radius,
		"sdfgi_energy": profile.sdfgi_energy,
	}


func _blend_state(from_state: Dictionary, to_state: Dictionary, weight: float) -> Dictionary:
	if from_state.is_empty():
		return to_state.duplicate(true)
	var result: Dictionary = from_state.duplicate(true)
	var t: float = clampf(weight, 0.0, 1.0)
	for raw_key: Variant in to_state.keys():
		var key: String = str(raw_key)
		var to_value: Variant = to_state[raw_key]
		if not result.has(key):
			result[key] = to_value
			continue
		result[key] = _blend_value(result[key], to_value, t)
	return result


func _blend_value(from_value: Variant, to_value: Variant, weight: float) -> Variant:
	if from_value is Color and to_value is Color:
		return (from_value as Color).lerp(to_value as Color, weight)
	if from_value is Vector3 and to_value is Vector3:
		return (from_value as Vector3).lerp(to_value as Vector3, weight)
	if typeof(from_value) == TYPE_BOOL and typeof(to_value) == TYPE_BOOL:
		return to_value if weight >= 0.5 else from_value
	if typeof(from_value) in [TYPE_INT, TYPE_FLOAT] and typeof(to_value) in [TYPE_INT, TYPE_FLOAT]:
		return lerpf(float(from_value), float(to_value), weight)
	return to_value if weight >= 0.5 else from_value


func _emit_signature_if_changed() -> void:
	var profile_id: String = default_profile.profile_id if default_profile != null else ""
	var signature: String = profile_id + "|" + ",".join(active_zone_ids)
	if signature == last_signature:
		return
	last_signature = signature
	lighting_state_changed.emit(profile_id, active_zone_ids.duplicate())


func _quality_label() -> String:
	match quality:
		Quality.PERFORMANCE:
			return "Performance"
		Quality.BALANCED:
			return "Balanced"
		_:
			return "Cinematic"


func get_debug_data() -> Dictionary:
	return {
		"lighting_director": true,
		"initialized": initialized,
		"channel": channel,
		"quality": quality,
		"quality_label": _quality_label(),
		"debug_hotkeys": debug_hotkeys_enabled,
		"default_profile": default_profile.profile_id if default_profile != null else "",
		"active_zones": active_zone_ids.duplicate(),
		"target_actor": target_actor.name if target_actor != null and is_instance_valid(target_actor) else "",
		"world_environment": environment_node.name if environment_node != null else "",
		"sun": sun.name if sun != null else "",
		"fill": fill_light.name if fill_light != null else "",
		"camera_attributes": camera_attributes != null,
		"sdfgi": environment.sdfgi_enabled if environment != null else false,
		"ssil": environment.ssil_enabled if environment != null else false,
		"ssr": environment.ssr_enabled if environment != null else false,
		"volumetric_fog": environment.volumetric_fog_enabled if environment != null else false,
	}
