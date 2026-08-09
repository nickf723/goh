extends Node3D
class_name VegetationPresentationDirector3D

signal vegetation_presentation_enabled_changed(enabled: bool)
signal vegetation_target_registered(role: String, node_name: String)

@export var profile: VegetationPresentationProfile
@export var enabled: bool = true
@export var debug_hotkeys_enabled: bool = false

var targets: Dictionary = {}
var role_counts: Dictionary = {}
var enhanced_materials: Dictionary = {}
var normal_textures: Dictionary = {}
var restored_target_count: int = 0


func _ready() -> void:
	add_to_group("vegetation_presentation_director")
	add_to_group("debuggable")
	set_meta("vegetation_presentation_initialized", profile != null)


func _unhandled_input(event: InputEvent) -> void:
	if not debug_hotkeys_enabled:
		return
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo or key_event.keycode != KEY_F1:
		return
	set_enabled(not enabled)
	print("Vegetation Presentation Director: ", "ON" if enabled else "OFF")
	get_viewport().set_input_as_handled()


func register_mesh(target: MeshInstance3D, role: String) -> bool:
	if profile == null or target == null or not is_instance_valid(target):
		return false
	var original: StandardMaterial3D = target.material_override as StandardMaterial3D
	if original == null:
		return false
	var normalized_role: String = role.strip_edges().to_lower()
	if normalized_role not in ["ground", "sunlit", "canopy"]:
		return false
	var target_id: int = target.get_instance_id()
	if targets.has(target_id):
		return true

	var enhanced: StandardMaterial3D = _get_or_create_enhanced_material(
		original,
		normalized_role
	)
	if enhanced == null:
		return false
	targets[target_id] = {
		"ref": weakref(target),
		"original": original,
		"enhanced": enhanced,
		"role": normalized_role,
	}
	role_counts[normalized_role] = int(role_counts.get(normalized_role, 0)) + 1
	target.add_to_group("vegetation_presentation_target")
	target.set_meta("vegetation_presentation_role", normalized_role)
	if enabled:
		target.material_override = enhanced
	vegetation_target_registered.emit(normalized_role, target.name)
	return true


func set_enabled(value: bool) -> void:
	enabled = value
	restored_target_count = 0
	var invalid_ids: Array[int] = []
	for raw_id: Variant in targets.keys():
		var target_id: int = int(raw_id)
		var record: Dictionary = targets[target_id] as Dictionary
		var weak_value: Variant = record.get("ref", null)
		if not weak_value is WeakRef:
			invalid_ids.append(target_id)
			continue
		var target_value: Variant = (weak_value as WeakRef).get_ref()
		if not target_value is MeshInstance3D:
			invalid_ids.append(target_id)
			continue
		var mesh_instance: MeshInstance3D = target_value as MeshInstance3D
		if enabled:
			mesh_instance.material_override = record.get("enhanced") as Material
		else:
			mesh_instance.material_override = record.get("original") as Material
			restored_target_count += 1
	for target_id: int in invalid_ids:
		targets.erase(target_id)
	vegetation_presentation_enabled_changed.emit(enabled)


func unregister_mesh(target: MeshInstance3D, restore: bool = true) -> void:
	if target == null:
		return
	var target_id: int = target.get_instance_id()
	if not targets.has(target_id):
		return
	var record: Dictionary = targets[target_id] as Dictionary
	if restore and is_instance_valid(target):
		target.material_override = record.get("original") as Material
	var role: String = str(record.get("role", ""))
	role_counts[role] = maxi(int(role_counts.get(role, 0)) - 1, 0)
	targets.erase(target_id)


func _get_or_create_enhanced_material(
	original: StandardMaterial3D,
	role: String
) -> StandardMaterial3D:
	var cache_key: String = "%s:%d" % [role, original.get_instance_id()]
	if enhanced_materials.has(cache_key):
		return enhanced_materials[cache_key] as StandardMaterial3D
	if enhanced_materials.size() >= profile.maximum_shared_variants:
		return null

	var enhanced: StandardMaterial3D = original.duplicate(true) as StandardMaterial3D
	if enhanced == null:
		return null
	enhanced.resource_local_to_scene = true
	enhanced.cull_mode = BaseMaterial3D.CULL_DISABLED
	enhanced.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	enhanced.uv1_triplanar = true
	enhanced.uv1_world_triplanar = true
	enhanced.uv1_triplanar_sharpness = profile.triplanar_sharpness
	enhanced.uv1_scale = original.uv1_scale * profile.world_scale_multiplier
	enhanced.normal_enabled = true
	enhanced.normal_texture = _get_normal_texture(role)
	enhanced.normal_scale = profile.normal_scale * _normal_multiplier(role)
	enhanced.backlight_enabled = true
	enhanced.backlight = _backlight_color(role) * _backlight_strength(role)
	enhanced.roughness = _roughness(role)

	var sss_strength: float = _sss_strength(role)
	enhanced.subsurf_scatter_enabled = sss_strength > 0.001
	enhanced.subsurf_scatter_strength = sss_strength
	enhanced.subsurf_scatter_skin_mode = false
	enhanced.subsurf_scatter_transmittance_enabled = sss_strength > 0.001
	enhanced.subsurf_scatter_transmittance_color = _transmittance_color(role)
	enhanced.subsurf_scatter_transmittance_boost = _transmittance_boost(role)
	enhanced.subsurf_scatter_transmittance_depth = _transmittance_depth(role)

	enhanced_materials[cache_key] = enhanced
	return enhanced


func _get_normal_texture(role: String) -> NoiseTexture2D:
	if normal_textures.has(role):
		return normal_textures[role] as NoiseTexture2D
	var noise := FastNoiseLite.new()
	noise.seed = profile.detail_seed + abs(role.hash() % 10000)
	noise.frequency = profile.normal_noise_frequency * _noise_frequency_multiplier(role)
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise.fractal_lacunarity = 2.05
	noise.fractal_gain = 0.48

	var texture := NoiseTexture2D.new()
	texture.width = profile.texture_resolution
	texture.height = profile.texture_resolution
	texture.seamless = true
	texture.generate_mipmaps = true
	texture.noise = noise
	texture.as_normal_map = true
	texture.bump_strength = 3.1 * _normal_multiplier(role)
	normal_textures[role] = texture
	return texture


func _normal_multiplier(role: String) -> float:
	match role:
		"sunlit":
			return 0.92
		"canopy":
			return 0.62
		_:
			return 0.82


func _noise_frequency_multiplier(role: String) -> float:
	match role:
		"canopy":
			return 0.58
		"sunlit":
			return 1.08
		_:
			return 1.0


func _backlight_color(role: String) -> Color:
	match role:
		"sunlit":
			return profile.sunlit_backlight_color
		"canopy":
			return profile.canopy_backlight_color
		_:
			return profile.ground_backlight_color


func _backlight_strength(role: String) -> float:
	match role:
		"sunlit":
			return profile.sunlit_backlight_strength
		"canopy":
			return profile.canopy_backlight_strength
		_:
			return profile.ground_backlight_strength


func _sss_strength(role: String) -> float:
	match role:
		"sunlit":
			return profile.sunlit_sss_strength
		"canopy":
			return profile.canopy_sss_strength
		_:
			return profile.ground_sss_strength


func _transmittance_color(role: String) -> Color:
	match role:
		"sunlit":
			return profile.sunlit_transmittance_color
		"canopy":
			return profile.canopy_transmittance_color
		_:
			return profile.ground_transmittance_color


func _transmittance_boost(role: String) -> float:
	match role:
		"sunlit":
			return profile.sunlit_transmittance_boost
		"canopy":
			return profile.canopy_transmittance_boost
		_:
			return profile.ground_transmittance_boost


func _transmittance_depth(role: String) -> float:
	match role:
		"sunlit":
			return profile.sunlit_transmittance_depth
		"canopy":
			return profile.canopy_transmittance_depth
		_:
			return profile.ground_transmittance_depth


func _roughness(role: String) -> float:
	match role:
		"sunlit":
			return profile.sunlit_roughness
		"canopy":
			return profile.canopy_roughness
		_:
			return profile.ground_roughness


func get_debug_data() -> Dictionary:
	var live_targets: int = 0
	for raw_id: Variant in targets.keys():
		var record: Dictionary = targets[int(raw_id)] as Dictionary
		var weak_value: Variant = record.get("ref", null)
		if weak_value is WeakRef:
			var target_value: Variant = (weak_value as WeakRef).get_ref()
			if target_value is MeshInstance3D:
				live_targets += 1
	return {
		"vegetation_presentation_director": true,
		"initialized": profile != null,
		"profile_id": profile.profile_id if profile != null else "",
		"enabled": enabled,
		"debug_hotkeys": debug_hotkeys_enabled,
		"target_count": live_targets,
		"role_counts": role_counts.duplicate(true),
		"shared_materials": enhanced_materials.size(),
		"normal_textures": normal_textures.size(),
		"two_sided": true,
		"lambert_wrap": true,
		"backlight": true,
		"subsurface_transmittance": true,
		"world_triplanar": true,
		"geometry_unchanged": true,
		"physics_authority": false,
		"restored_target_count": restored_target_count,
	}
