extends Node3D
class_name CharacterMaterialPresentationDirector3D

signal character_material_quality_changed(quality: int)

@export var profile: CharacterMaterialPresentationProfile
@export var enabled: bool = true

var lighting_director: LightingDirector3D = null
var targets: Dictionary = {}
var role_counts: Dictionary = {}
var enhanced_materials: Dictionary = {}
var normal_textures: Dictionary = {}
var active_quality: int = -1
var restored_target_count: int = 0


func _ready() -> void:
	add_to_group("character_material_presentation_director")
	add_to_group("debuggable")
	_resolve_lighting_director()
	_apply_quality(_current_quality())
	set_meta("character_material_presentation_initialized", profile != null)


func _process(_delta: float) -> void:
	if not enabled or profile == null:
		return
	if lighting_director == null or not is_instance_valid(lighting_director):
		_resolve_lighting_director()
	var requested_quality: int = _current_quality()
	if requested_quality != active_quality:
		_apply_quality(requested_quality)


func register_mesh(target: MeshInstance3D, role: String) -> bool:
	if profile == null or target == null or not is_instance_valid(target):
		return false
	var original: StandardMaterial3D = target.material_override as StandardMaterial3D
	if original == null:
		return false
	var normalized_role: String = role.strip_edges().to_lower()
	if normalized_role == "":
		return false
	var target_id: int = target.get_instance_id()
	if targets.has(target_id):
		return true
	targets[target_id] = {
		"ref": weakref(target),
		"original": original,
		"role": normalized_role,
		"mesh": target.mesh,
	}
	role_counts[normalized_role] = int(role_counts.get(normalized_role, 0)) + 1
	target.add_to_group("character_material_presentation_target")
	target.set_meta("character_material_role", normalized_role)
	_apply_target_quality(target, targets[target_id] as Dictionary, _current_quality())
	return true


func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		_restore_originals()
		return
	active_quality = -1
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
		return 2
	return clampi(lighting_director.quality, 0, 2)


func _apply_quality(quality: int) -> void:
	if profile == null:
		return
	active_quality = clampi(quality, 0, 2)
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
		_apply_target_quality(
			target_value as MeshInstance3D,
			record,
			active_quality
		)
	for target_id: int in invalid_ids:
		targets.erase(target_id)
	character_material_quality_changed.emit(active_quality)


func _apply_target_quality(
	target: MeshInstance3D,
	record: Dictionary,
	quality: int
) -> void:
	if target == null:
		return
	var original: StandardMaterial3D = record.get("original") as StandardMaterial3D
	if original == null:
		return
	if not enabled or quality <= 0:
		target.material_override = original
		restored_target_count += 1
		return
	var role: String = str(record.get("role", "generic"))
	var enhanced: StandardMaterial3D = _get_or_create_enhanced_material(
		original,
		role,
		quality
	)
	if enhanced != null:
		target.material_override = enhanced


func _get_or_create_enhanced_material(
	original: StandardMaterial3D,
	role: String,
	quality: int
) -> StandardMaterial3D:
	var cache_key: String = "%s:%d:q%d" % [
		role,
		original.get_instance_id(),
		quality,
	]
	if enhanced_materials.has(cache_key):
		return enhanced_materials[cache_key] as StandardMaterial3D
	if enhanced_materials.size() >= profile.maximum_shared_variants:
		return null
	var enhanced: StandardMaterial3D = original.duplicate(true) as StandardMaterial3D
	if enhanced == null:
		return null
	enhanced.resource_local_to_scene = true
	_apply_role_material(enhanced, role, quality)
	enhanced_materials[cache_key] = enhanced
	return enhanced


func _apply_role_material(
	material: StandardMaterial3D,
	role: String,
	quality: int
) -> void:
	var cinematic: bool = quality >= 2
	var normal_scale: float = (
		profile.cinematic_normal_scale
		if cinematic
		else profile.balanced_normal_scale
	)
	var role_normal: float = _role_normal_multiplier(role)
	if role_normal > 0.001:
		material.normal_enabled = true
		material.normal_texture = _get_normal_texture(role)
		material.normal_scale = normal_scale * role_normal
		material.uv1_scale = material.uv1_scale * _role_uv_scale(role)

	match role:
		"skin":
			material.roughness = 0.66 if cinematic else 0.72
			material.backlight_enabled = true
			var backlight_strength: float = (
				profile.cinematic_skin_backlight
				if cinematic
				else profile.balanced_skin_backlight
			)
			material.backlight = Color(0.88, 0.36, 0.24, 1.0) * backlight_strength
			material.subsurf_scatter_enabled = cinematic
			material.subsurf_scatter_strength = (
				profile.cinematic_skin_sss_strength if cinematic else 0.0
			)
			material.subsurf_scatter_skin_mode = cinematic
			material.subsurf_scatter_transmittance_enabled = cinematic
			material.subsurf_scatter_transmittance_color = profile.skin_transmittance_color
			material.subsurf_scatter_transmittance_boost = profile.skin_transmittance_boost
			material.subsurf_scatter_transmittance_depth = profile.skin_transmittance_depth
		"hair":
			material.roughness = 0.54 if cinematic else 0.61
			material.backlight_enabled = true
			var hair_strength: float = (
				profile.cinematic_hair_backlight
				if cinematic
				else profile.balanced_hair_backlight
			)
			material.backlight = Color(0.24, 0.10, 0.16, 1.0) * hair_strength
		"robe":
			material.roughness = 0.84 if cinematic else 0.89
		"sash":
			material.roughness = 0.70 if cinematic else 0.78
		"gold":
			material.roughness = 0.28 if cinematic else 0.34
			material.metallic = maxf(material.metallic, 0.58 if cinematic else 0.55)
		"leather":
			material.roughness = 0.76 if cinematic else 0.82
		"eye":
			material.roughness = 0.20 if cinematic else 0.28
			material.metallic = 0.06
		"mouth":
			material.roughness = 0.58
		_:
			material.roughness = minf(material.roughness, 0.86)


func _get_normal_texture(role: String) -> NoiseTexture2D:
	if normal_textures.has(role):
		return normal_textures[role] as NoiseTexture2D
	var noise := FastNoiseLite.new()
	noise.seed = profile.detail_seed + abs(role.hash() % 10000)
	noise.frequency = profile.detail_frequency * _role_frequency_multiplier(role)
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
	texture.bump_strength = 2.2 * _role_normal_multiplier(role)
	normal_textures[role] = texture
	return texture


func _role_normal_multiplier(role: String) -> float:
	match role:
		"skin":
			return 0.28
		"hair":
			return 0.58
		"robe":
			return 0.72
		"sash":
			return 0.62
		"gold":
			return 0.20
		"leather":
			return 0.74
		"eye", "mouth":
			return 0.0
		_:
			return 0.45


func _role_frequency_multiplier(role: String) -> float:
	match role:
		"skin":
			return 1.35
		"hair":
			return 0.86
		"robe", "sash":
			return 1.12
		"leather":
			return 0.72
		_:
			return 1.0


func _role_uv_scale(role: String) -> Vector3:
	match role:
		"skin":
			return Vector3(5.0, 5.0, 5.0)
		"hair":
			return Vector3(3.2, 3.2, 3.2)
		"robe":
			return Vector3(6.5, 6.5, 6.5)
		"sash":
			return Vector3(7.0, 7.0, 7.0)
		"gold":
			return Vector3(4.5, 4.5, 4.5)
		"leather":
			return Vector3(4.0, 4.0, 4.0)
		_:
			return Vector3.ONE


func _restore_originals() -> void:
	restored_target_count = 0
	for raw_id: Variant in targets.keys():
		var record: Dictionary = targets[int(raw_id)] as Dictionary
		var weak_value: Variant = record.get("ref", null)
		if not weak_value is WeakRef:
			continue
		var target_value: Variant = (weak_value as WeakRef).get_ref()
		if target_value is MeshInstance3D:
			(target_value as MeshInstance3D).material_override = (
				record.get("original") as Material
			)
			restored_target_count += 1


func get_debug_data() -> Dictionary:
	var live_targets: int = 0
	var geometry_unchanged: bool = true
	for raw_id: Variant in targets.keys():
		var record: Dictionary = targets[int(raw_id)] as Dictionary
		var weak_value: Variant = record.get("ref", null)
		if not weak_value is WeakRef:
			continue
		var target_value: Variant = (weak_value as WeakRef).get_ref()
		if target_value is MeshInstance3D:
			live_targets += 1
			if (target_value as MeshInstance3D).mesh != record.get("mesh"):
				geometry_unchanged = false
	return {
		"character_material_presentation_director": true,
		"initialized": profile != null,
		"profile_id": profile.profile_id if profile != null else "",
		"enabled": enabled,
		"quality": active_quality,
		"target_count": live_targets,
		"role_counts": role_counts.duplicate(true),
		"shared_variants": enhanced_materials.size(),
		"normal_textures": normal_textures.size(),
		"follows_lighting_quality": true,
		"performance_restores_originals": true,
		"geometry_unchanged": geometry_unchanged,
		"restored_target_count": restored_target_count,
		"gameplay_authority": false,
	}
