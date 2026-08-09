extends Node3D
class_name ProjectedCanopyLightDirector3D

signal canopy_light_quality_changed(quality: int, enabled: bool)

@export var profile: ProjectedCanopyLightProfile
@export var enabled: bool = true

var lighting_director: LightingDirector3D = null
var spot_light: SpotLight3D = null
var projector_texture: ImageTexture = null
var active_quality: int = -1
var elapsed: float = 0.0
var initialized: bool = false
var mask_average: float = 0.0
var mask_bright_fraction: float = 0.0
var apply_count: int = 0


func _ready() -> void:
	add_to_group("projected_canopy_light_director")
	add_to_group("debuggable")
	_resolve_lighting_director()
	_build_projector_texture()
	_build_light()
	initialized = profile != null and spot_light != null and projector_texture != null
	set_meta("projected_canopy_light_initialized", initialized)
	if initialized:
		_apply_quality(_current_quality())


func _process(delta: float) -> void:
	if not enabled or profile == null or spot_light == null:
		return
	elapsed += maxf(delta, 0.0)
	if lighting_director == null or not is_instance_valid(lighting_director):
		_resolve_lighting_director()
	var requested_quality: int = _current_quality()
	if requested_quality != active_quality:
		_apply_quality(requested_quality)
	if active_quality >= LightingDirector3D.Quality.BALANCED:
		var amplitude: float = deg_to_rad(profile.rotation_drift_degrees)
		spot_light.rotation.z = sin(
			elapsed * TAU * profile.rotation_drift_speed
		) * amplitude


func set_enabled(value: bool) -> void:
	enabled = value
	if spot_light == null:
		return
	if not enabled:
		spot_light.visible = false
		spot_light.light_energy = 0.0
		spot_light.shadow_enabled = false
		return
	active_quality = -1
	_apply_quality(_current_quality())


func synchronize_now() -> void:
	if lighting_director == null or not is_instance_valid(lighting_director):
		_resolve_lighting_director()
	_apply_quality(_current_quality())


func _resolve_lighting_director() -> void:
	lighting_director = null
	if get_tree() == null:
		return
	var candidate: Node = get_tree().get_first_node_in_group("lighting_director")
	if candidate is LightingDirector3D:
		lighting_director = candidate as LightingDirector3D


func _current_quality() -> int:
	if lighting_director == null:
		return LightingDirector3D.Quality.CINEMATIC
	return clampi(
		lighting_director.quality,
		LightingDirector3D.Quality.PERFORMANCE,
		LightingDirector3D.Quality.CINEMATIC
	)


func _build_projector_texture() -> void:
	if profile == null or projector_texture != null:
		return
	var resolution: int = clampi(profile.projector_resolution, 32, 256)
	var image: Image = Image.create_empty(
		resolution,
		resolution,
		false,
		Image.FORMAT_RGBA8
	)
	var noise := FastNoiseLite.new()
	noise.seed = profile.noise_seed
	noise.frequency = profile.noise_frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = clampi(profile.noise_octaves, 1, 8)
	noise.fractal_lacunarity = 2.05
	noise.fractal_gain = 0.53

	var total_value: float = 0.0
	var bright_count: int = 0
	var softness: float = maxf(profile.opening_softness, 0.01)
	var threshold_low: float = profile.opening_threshold - softness * 0.5
	var threshold_high: float = profile.opening_threshold + softness * 0.5
	for y: int in range(resolution):
		for x: int in range(resolution):
			var sample: float = noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var opening: float = smoothstep(threshold_low, threshold_high, sample)
			var uv := Vector2(
				(float(x) + 0.5) / float(resolution),
				(float(y) + 0.5) / float(resolution)
			)
			var radial: float = (uv - Vector2(0.5, 0.5)).length() / 0.70710678
			var edge: float = 1.0 - smoothstep(
				profile.edge_fade_start,
				1.0,
				radial
			)
			var value: float = lerpf(profile.blocked_floor, 1.0, opening) * edge
			value = clampf(value, 0.0, 1.0)
			total_value += value
			if value >= 0.60:
				bright_count += 1
			image.set_pixel(x, y, Color(value, value, value, 1.0))
	var pixel_count: float = float(resolution * resolution)
	mask_average = total_value / maxf(pixel_count, 1.0)
	mask_bright_fraction = float(bright_count) / maxf(pixel_count, 1.0)
	projector_texture = ImageTexture.create_from_image(image)


func _build_light() -> void:
	if profile == null or spot_light != null:
		return
	spot_light = SpotLight3D.new()
	spot_light.name = "CanopyDappleSpot"
	spot_light.light_color = profile.light_color
	spot_light.light_projector = projector_texture
	spot_light.light_specular = profile.light_specular
	spot_light.light_indirect_energy = 0.0
	spot_light.light_volumetric_fog_energy = 0.0
	spot_light.spot_range = profile.spot_range
	spot_light.spot_angle = profile.spot_angle
	spot_light.spot_attenuation = profile.spot_attenuation
	spot_light.shadow_enabled = false
	spot_light.distance_fade_enabled = true
	spot_light.distance_fade_begin = maxf(profile.spot_range * 1.05, 1.0)
	spot_light.distance_fade_length = maxf(profile.spot_range * 0.25, 1.0)
	add_child(spot_light)


func _apply_quality(quality: int) -> void:
	if spot_light == null or profile == null:
		return
	active_quality = clampi(quality, 0, 2)
	var active: bool = enabled and active_quality >= LightingDirector3D.Quality.BALANCED
	spot_light.visible = active
	# The projector texture already supplies the broken-canopy pattern. A second
	# shadow map multiplied thousands of tiny Green meshes for very little gain.
	spot_light.shadow_enabled = false
	if not active:
		spot_light.light_energy = 0.0
		spot_light.light_volumetric_fog_energy = 0.0
		canopy_light_quality_changed.emit(active_quality, false)
		apply_count += 1
		return
	if active_quality == LightingDirector3D.Quality.CINEMATIC:
		spot_light.light_energy = profile.cinematic_energy
		spot_light.light_volumetric_fog_energy = profile.cinematic_volumetric_energy
	else:
		spot_light.light_energy = profile.balanced_energy
		spot_light.light_volumetric_fog_energy = profile.balanced_volumetric_energy
	canopy_light_quality_changed.emit(active_quality, true)
	apply_count += 1


func get_debug_data() -> Dictionary:
	return {
		"projected_canopy_light_director": true,
		"initialized": initialized,
		"profile_id": profile.profile_id if profile != null else "",
		"enabled": enabled,
		"quality": active_quality,
		"light_visible": spot_light.visible if spot_light != null else false,
		"energy": spot_light.light_energy if spot_light != null else 0.0,
		"volumetric_energy": spot_light.light_volumetric_fog_energy if spot_light != null else 0.0,
		"projector_texture": projector_texture != null,
		"projector_resolution": profile.projector_resolution if profile != null else 0,
		"mask_average": snappedf(mask_average, 0.001),
		"mask_bright_fraction": snappedf(mask_bright_fraction, 0.001),
		"shadow_enabled": false,
		"follows_lighting_quality": true,
		"runtime_generated_projector": true,
		"indirect_energy_zero": spot_light != null and spot_light.light_indirect_energy == 0.0,
		"geometry_unchanged": true,
		"gameplay_authority": false,
		"apply_count": apply_count,
	}
