extends Node3D
class_name FaunaMaterialPresentationDirector3D

signal fauna_material_quality_changed(quality: int, target_count: int)

@export var profile: FaunaMaterialPresentationProfile
@export var enabled: bool = true

var lighting_director: LightingDirector3D = null
var targets: Dictionary = {}
var role_counts: Dictionary = {}
var enhanced_materials: Dictionary = {}
var normal_textures: Dictionary = {}
var registered_fauna: Dictionary = {}
var active_quality: int = -1
var refresh_timer: float = 0.0
var restored_target_count: int = 0
var initialized: bool = false


func _ready() -> void:
	add_to_group("fauna_material_presentation_director")
	add_to_group("debuggable")
	_resolve_lighting_director()
	_refresh_fauna_targets()
	_refresh_initialized_state()
	if initialized:
		_apply_quality(_current_quality())


func _process(delta: float) -> void:
	if profile == null:
		return
	if lighting_director == null or not is_instance_valid(lighting_director):
		_resolve_lighting_director()
	refresh_timer -= maxf(delta, 0.0)
	if refresh_timer <= 0.0:
		refresh_timer = 0.65
		_refresh_fauna_targets()
		_refresh_initialized_state()
	var requested: int = _current_quality()
	if enabled and requested != active_quality:
		_apply_quality(requested)


func set_enabled(value: bool) -> void:
	if enabled == value:
		return
	enabled = value
	if not enabled:
		_restore_original_materials()
		return
	active_quality = -1
	_refresh_fauna_targets()
	_apply_quality(_current_quality())


func synchronize_now() -> void:
	_refresh_fauna_targets()
	_refresh_initialized_state()
	if enabled:
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
	return clampi(lighting_director.quality, 0, 2)


func _refresh_initialized_state() -> void:
	initialized = profile != null and not targets.is_empty()
	set_meta("fauna_material_presentation_initialized", initialized)


func _refresh_fauna_targets() -> void:
	if profile == null or get_tree() == null:
		return
	for candidate: Node in get_tree().get_nodes_in_group("environmental_fauna"):
		if not candidate is GreenGrottoFaunaVisual:
			continue
		var creature: GreenGrottoFaunaVisual = candidate as GreenGrottoFaunaVisual
		var creature_id: int = creature.get_instance_id()
		if registered_fauna.has(creature_id):
			continue
		_register_creature_recursive(creature, creature, creature.species)
		registered_fauna[creature_id] = weakref(creature)
	if enabled and active_quality >= 0:
		_apply_quality(active_quality)


func _register_creature_recursive(
	node: Node,
	creature: GreenGrottoFaunaVisual,
	species: String
) -> void:
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		var role: String = _resolve_role(mesh_instance, species)
		if role != "":
			_register_mesh(mesh_instance, role, creature)
	for child: Node in node.get_children():
		_register_creature_recursive(child, creature, species)


func _resolve_role(mesh_instance: MeshInstance3D, species: String) -> String:
	var node_name: String = str(mesh_instance.name)
	if node_name.begins_with("Eye"):
		return "eye"
	if species == "raptor":
		if (
			node_name.begins_with("Crest")
			or node_name.begins_with("BodyFeather")
			or node_name == "Snout"
			or node_name == "LowerLeg"
			or node_name == "Arm"
		):
			return "feather"
		return "hide"
	if species == "sauropod":
		if node_name == "Head" or node_name == "Foot":
			return "accent_hide"
		return "hide"
	return ""


func _register_mesh(
	mesh_instance: MeshInstance3D,
	role: String,
	creature: GreenGrottoFaunaVisual
) -> void:
	if mesh_instance == null:
		return
	var original: StandardMaterial3D = (
		mesh_instance.material_override as StandardMaterial3D
	)
	if original == null:
		return
	var target_id: int = mesh_instance.get_instance_id()
	if targets.has(target_id):
		return
	targets[target_id] = {
		"ref": weakref(mesh_instance),
		"original": original,
		"role": role,
		"species": creature.species,
		"creature": creature.name,
		"mesh": mesh_instance.mesh,
	}
	role_counts[role] = int(role_counts.get(role, 0)) + 1
	mesh_instance.add_to_group("fauna_material_presentation_target")
	mesh_instance.set_meta("fauna_material_role", role)


func _apply_quality(quality: int) -> void:
	active_quality = clampi(quality, 0, 2)
	if active_quality == LightingDirector3D.Quality.PERFORMANCE:
		_restore_original_materials()
		fauna_material_quality_changed.emit(active_quality, targets.size())
		return
	var invalid_ids: Array[int] = []
	for raw_id: Variant in targets.keys():
		var target_id: int = int(raw_id)
		var record: Dictionary = targets[target_id] as Dictionary
		var mesh_instance: MeshInstance3D = _mesh_from_record(record)
		if mesh_instance == null:
			invalid_ids.append(target_id)
			continue
		var original: StandardMaterial3D = (
			record.get("original") as StandardMaterial3D
		)
		var role: String = str(record.get("role", "hide"))
		var enhanced: StandardMaterial3D = _get_or_create_variant(
			original,
			role,
			active_quality
		)
		if enhanced != null:
			mesh_instance.material_override = enhanced
	for target_id: int in invalid_ids:
		targets.erase(target_id)
	fauna_material_quality_changed.emit(active_quality, targets.size())


func _get_or_create_variant(
	original: StandardMaterial3D,
	role: String,
	quality: int
) -> StandardMaterial3D:
	if original == null or profile == null:
		return null
	var cache_key: String = "%d:%s:%d" % [
		quality,
		role,
		original.get_instance_id(),
	]
	if enhanced_materials.has(cache_key):
		return enhanced_materials[cache_key] as StandardMaterial3D
	if enhanced_materials.size() >= profile.maximum_shared_variants:
		return null
	var material: StandardMaterial3D = original.duplicate(true) as StandardMaterial3D
	if material == null:
		return null
	material.resource_local_to_scene = true
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	if role != "eye":
		material.normal_enabled = true
		material.normal_texture = _get_normal_texture(role)
		material.normal_scale = (
			profile.cinematic_normal_scale
			if quality == LightingDirector3D.Quality.CINEMATIC
			else profile.balanced_normal_scale
		) * _normal_role_multiplier(role)
		material.roughness = clampf(
			original.roughness * _roughness_scale(role, quality),
			0.04,
			1.0
		)
		_apply_backlight(material, role, quality)
	else:
		material.normal_enabled = false
		material.roughness = (
			profile.cinematic_eye_roughness
			if quality == LightingDirector3D.Quality.CINEMATIC
			else profile.balanced_eye_roughness
		)
		if quality == LightingDirector3D.Quality.CINEMATIC:
			material.metallic = maxf(
				original.metallic,
				profile.cinematic_eye_metallic
			)
	enhanced_materials[cache_key] = material
	return material


func _get_normal_texture(role: String) -> NoiseTexture2D:
	if normal_textures.has(role):
		return normal_textures[role] as NoiseTexture2D
	var noise := FastNoiseLite.new()
	noise.seed = profile.detail_seed + abs(role.hash() % 10000)
	noise.frequency = profile.normal_noise_frequency * _frequency_multiplier(role)
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise.fractal_lacunarity = 2.05
	noise.fractal_gain = 0.50
	var texture := NoiseTexture2D.new()
	texture.width = profile.texture_resolution
	texture.height = profile.texture_resolution
	texture.seamless = true
	texture.generate_mipmaps = true
	texture.noise = noise
	texture.as_normal_map = true
	texture.bump_strength = profile.normal_bump_strength * _normal_role_multiplier(role)
	normal_textures[role] = texture
	return texture


func _normal_role_multiplier(role: String) -> float:
	match role:
		"feather":
			return 0.82
		"accent_hide":
			return 0.90
		_:
			return 1.0


func _frequency_multiplier(role: String) -> float:
	match role:
		"feather":
			return 1.32
		"accent_hide":
			return 0.88
		_:
			return 1.0


func _roughness_scale(role: String, quality: int) -> float:
	var cinematic: bool = quality == LightingDirector3D.Quality.CINEMATIC
	match role:
		"feather":
			return (
				profile.cinematic_feather_roughness_scale
				if cinematic
				else profile.balanced_feather_roughness_scale
			)
		"accent_hide":
			return (
				profile.cinematic_accent_roughness_scale
				if cinematic
				else profile.balanced_accent_roughness_scale
			)
		_:
			return (
				profile.cinematic_hide_roughness_scale
				if cinematic
				else profile.balanced_hide_roughness_scale
			)


func _apply_backlight(
	material: StandardMaterial3D,
	role: String,
	quality: int
) -> void:
	var strength: float = 0.0
	var color: Color = Color.BLACK
	match role:
		"feather":
			color = profile.feather_backlight_color
			strength = (
				profile.cinematic_feather_backlight_strength
				if quality == LightingDirector3D.Quality.CINEMATIC
				else profile.balanced_feather_backlight_strength
			)
		"accent_hide":
			color = profile.accent_backlight_color
			if quality == LightingDirector3D.Quality.CINEMATIC:
				strength = profile.cinematic_accent_backlight_strength
		"hide":
			color = profile.hide_backlight_color
			if quality == LightingDirector3D.Quality.CINEMATIC:
				strength = profile.cinematic_hide_backlight_strength
	material.backlight_enabled = strength > 0.001
	if strength > 0.001:
		material.backlight = color * strength


func _restore_original_materials() -> void:
	restored_target_count = 0
	var invalid_ids: Array[int] = []
	for raw_id: Variant in targets.keys():
		var target_id: int = int(raw_id)
		var record: Dictionary = targets[target_id] as Dictionary
		var mesh_instance: MeshInstance3D = _mesh_from_record(record)
		if mesh_instance == null:
			invalid_ids.append(target_id)
			continue
		mesh_instance.material_override = record.get("original") as Material
		restored_target_count += 1
	for target_id: int in invalid_ids:
		targets.erase(target_id)


func _mesh_from_record(record: Dictionary) -> MeshInstance3D:
	var weak_value: Variant = record.get("ref", null)
	if not weak_value is WeakRef:
		return null
	var value: Variant = (weak_value as WeakRef).get_ref()
	return value as MeshInstance3D if value is MeshInstance3D else null


func get_debug_data() -> Dictionary:
	return {
		"fauna_material_presentation_director": true,
		"initialized": initialized,
		"profile_id": profile.profile_id if profile != null else "",
		"enabled": enabled,
		"quality": active_quality,
		"target_count": targets.size(),
		"registered_fauna": registered_fauna.size(),
		"role_counts": role_counts.duplicate(true),
		"shared_variants": enhanced_materials.size(),
		"normal_textures": normal_textures.size(),
		"restored_target_count": restored_target_count,
		"object_uv_detail": true,
		"follows_lighting_quality": true,
		"behavior_authority": false,
		"geometry_unchanged": true,
		"gameplay_authority": false,
	}
