extends Node3D
class_name MaterialFidelityDirector3D

signal material_fidelity_enabled_changed(enabled: bool)
signal material_target_registered(category: String, node_name: String)

@export var profile: MaterialFidelityProfile
@export var enabled: bool = true
@export var debug_hotkeys_enabled: bool = false

var targets: Dictionary = {}
var enhanced_materials: Dictionary = {}
var detail_textures: Dictionary = {}
var category_counts: Dictionary = {}
var enhanced_material_count: int = 0
var created_texture_count: int = 0
var restored_target_count: int = 0


func _ready() -> void:
	add_to_group("material_fidelity_director")
	add_to_group("debuggable")
	set_meta("material_fidelity_initialized", profile != null)


func _unhandled_input(event: InputEvent) -> void:
	if not debug_hotkeys_enabled:
		return
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo or key_event.keycode != KEY_F3:
		return
	set_enabled(not enabled)
	print("Material Fidelity Director: ", "ON" if enabled else "OFF")
	get_viewport().set_input_as_handled()


func register_mesh(target: MeshInstance3D, category: String) -> bool:
	if profile == null or target == null or not is_instance_valid(target):
		return false
	var original: StandardMaterial3D = target.material_override as StandardMaterial3D
	if original == null:
		return false
	var normalized_category: String = category.strip_edges().to_lower()
	if normalized_category == "":
		normalized_category = "stone"
	var target_id: int = target.get_instance_id()
	if targets.has(target_id):
		return true

	var enhanced: StandardMaterial3D = _get_or_create_enhanced_material(
		original,
		normalized_category
	)
	if enhanced == null:
		return false
	targets[target_id] = {
		"ref": weakref(target),
		"original": original,
		"enhanced": enhanced,
		"category": normalized_category,
	}
	category_counts[normalized_category] = int(
		category_counts.get(normalized_category, 0)
	) + 1
	target.add_to_group("material_fidelity_target")
	target.set_meta("material_fidelity_category", normalized_category)
	if enabled:
		target.material_override = enhanced
	material_target_registered.emit(normalized_category, target.name)
	return true


func unregister_mesh(target: MeshInstance3D, restore: bool = true) -> void:
	if target == null:
		return
	var target_id: int = target.get_instance_id()
	if not targets.has(target_id):
		return
	var record: Dictionary = targets[target_id] as Dictionary
	if restore and is_instance_valid(target):
		target.material_override = record.get("original") as Material
	var category: String = str(record.get("category", ""))
	if category_counts.has(category):
		category_counts[category] = maxi(int(category_counts[category]) - 1, 0)
	targets.erase(target_id)


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
	material_fidelity_enabled_changed.emit(enabled)


func clear_targets(restore: bool = true) -> void:
	if restore:
		set_enabled(false)
	targets.clear()
	category_counts.clear()


func _get_or_create_enhanced_material(
	original: StandardMaterial3D,
	category: String
) -> StandardMaterial3D:
	var cache_key: String = "%s:%d" % [category, original.get_instance_id()]
	if enhanced_materials.has(cache_key):
		return enhanced_materials[cache_key] as StandardMaterial3D
	if enhanced_materials.size() >= profile.maximum_shared_variants:
		return null

	var enhanced: StandardMaterial3D = original.duplicate(true) as StandardMaterial3D
	if enhanced == null:
		return null
	enhanced.resource_local_to_scene = true
	enhanced.uv1_triplanar = true
	enhanced.uv1_world_triplanar = true
	enhanced.uv1_triplanar_sharpness = profile.triplanar_sharpness
	enhanced.uv1_scale = original.uv1_scale * (
		profile.world_scale_multiplier * _category_uv_multiplier(category)
	)
	enhanced.normal_enabled = true
	enhanced.normal_texture = _get_detail_texture(category, "normal")
	enhanced.normal_scale = profile.normal_scale * _category_normal_multiplier(category)
	enhanced.roughness_texture = _get_detail_texture(category, "roughness")
	enhanced.roughness = clampf(
		original.roughness * _category_roughness_multiplier(category),
		0.04,
		1.0
	)
	enhanced_materials[cache_key] = enhanced
	enhanced_material_count += 1
	return enhanced


func _get_detail_texture(category: String, texture_kind: String) -> NoiseTexture2D:
	var cache_key: String = category + ":" + texture_kind
	if detail_textures.has(cache_key):
		return detail_textures[cache_key] as NoiseTexture2D

	var category_seed: int = abs(category.hash() % 10000)
	var noise := FastNoiseLite.new()
	noise.seed = profile.detail_seed + category_seed + (0 if texture_kind == "normal" else 991)
	noise.frequency = (
		profile.normal_noise_frequency
		if texture_kind == "normal"
		else profile.roughness_noise_frequency
	) * _category_frequency_multiplier(category)
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 5 if texture_kind == "normal" else 4
	noise.fractal_lacunarity = 2.05
	noise.fractal_gain = 0.50

	var texture := NoiseTexture2D.new()
	texture.width = profile.texture_resolution
	texture.height = profile.texture_resolution
	texture.seamless = true
	texture.generate_mipmaps = true
	texture.noise = noise
	if texture_kind == "normal":
		texture.as_normal_map = true
		texture.bump_strength = (
			profile.normal_bump_strength
			* _category_bump_multiplier(category)
		)
	else:
		var variation: float = clampf(profile.roughness_variation, 0.0, 0.48)
		var center: float = _roughness_texture_center(category)
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.46, 1.0])
		gradient.colors = PackedColorArray([
			Color(center - variation, center - variation, center - variation, 1.0),
			Color(center, center, center, 1.0),
			Color(center + variation, center + variation, center + variation, 1.0),
		])
		texture.color_ramp = gradient
	detail_textures[cache_key] = texture
	created_texture_count += 1
	return texture


func _category_uv_multiplier(category: String) -> float:
	match category:
		"rock", "rock_wet":
			return 0.78
		"masonry", "trim":
			return 0.88
		"paving", "paving_wet":
			return 1.0
		"wood", "bark", "root":
			return 0.72
		"roof":
			return 0.92
		"soil", "soil_wet":
			return 0.82
		_:
			return 1.0


func _category_frequency_multiplier(category: String) -> float:
	match category:
		"rock", "rock_wet":
			return 0.72
		"masonry", "trim":
			return 0.88
		"wood", "bark", "root":
			return 1.25
		"soil", "soil_wet":
			return 1.08
		_:
			return 1.0


func _category_normal_multiplier(category: String) -> float:
	match category:
		"rock":
			return 1.18
		"rock_wet":
			return 0.92
		"masonry", "trim":
			return 0.82
		"paving":
			return 0.72
		"paving_wet":
			return 0.58
		"wood", "bark", "root":
			return 0.88
		"roof":
			return 0.64
		"soil", "soil_wet":
			return 0.48
		_:
			return 0.75


func _category_bump_multiplier(category: String) -> float:
	match category:
		"rock":
			return 1.20
		"rock_wet":
			return 0.90
		"masonry", "trim":
			return 0.82
		"wood", "bark", "root":
			return 1.05
		"soil", "soil_wet":
			return 0.68
		_:
			return 0.78


func _category_roughness_multiplier(category: String) -> float:
	match category:
		"rock_wet":
			return 0.78
		"paving_wet":
			return 0.76
		"soil_wet":
			return 0.82
		"trim":
			return 0.92
		"roof":
			return 0.90
		_:
			return 1.0


func _roughness_texture_center(category: String) -> float:
	match category:
		"rock_wet", "paving_wet", "soil_wet":
			return 0.72
		"wood", "bark", "root":
			return 0.88
		"roof", "trim":
			return 0.82
		_:
			return 0.90


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
		"material_fidelity_director": true,
		"initialized": profile != null,
		"profile_id": profile.profile_id if profile != null else "",
		"enabled": enabled,
		"debug_hotkeys": debug_hotkeys_enabled,
		"target_count": live_targets,
		"category_counts": category_counts.duplicate(true),
		"enhanced_materials": enhanced_material_count,
		"detail_textures": created_texture_count,
		"shared_variant_cache": true,
		"world_triplanar": true,
		"procedural_normals": true,
		"procedural_roughness": true,
		"geometry_unchanged": true,
		"restored_target_count": restored_target_count,
	}
