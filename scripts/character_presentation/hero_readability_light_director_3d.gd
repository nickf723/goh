extends Node3D
class_name HeroReadabilityLightDirector3D

signal readability_quality_changed(quality: int, energy: float)

@export var profile: HeroReadabilityLightProfile
@export var enabled: bool = true

var lighting_director: LightingDirector3D = null
var player: Node3D = null
var grace_visual: Node = null
var readability_light: DirectionalLight3D = null
var original_layers: Dictionary = {}
var active_quality: int = -1
var initialized: bool = false
var target_mesh_count: int = 0
var smoothed_source_direction: Vector3 = Vector3(0.0, 0.3, 1.0)


func _ready() -> void:
	add_to_group("hero_readability_light_director")
	add_to_group("debuggable")
	_resolve_dependencies()
	_build_light()
	_register_character_layers()
	initialized = profile != null and readability_light != null and target_mesh_count > 0
	set_meta("hero_readability_light_initialized", initialized)
	if initialized:
		_apply_quality(_current_quality())


func _exit_tree() -> void:
	_restore_character_layers()


func _process(delta: float) -> void:
	if not enabled or profile == null or readability_light == null:
		return
	if lighting_director == null or not is_instance_valid(lighting_director):
		_resolve_lighting_director()
	var quality: int = _current_quality()
	if quality != active_quality:
		_apply_quality(quality)
	_update_light_direction(maxf(delta, 0.0))


func set_enabled(value: bool) -> void:
	if enabled == value:
		return
	enabled = value
	if not enabled:
		if readability_light != null:
			readability_light.visible = false
			readability_light.light_energy = 0.0
		_restore_character_layers()
		return
	_register_character_layers()
	active_quality = -1
	_apply_quality(_current_quality())


func synchronize_now() -> void:
	if lighting_director == null or not is_instance_valid(lighting_director):
		_resolve_lighting_director()
	_apply_quality(_current_quality())
	_update_light_direction(1.0)


func _resolve_dependencies() -> void:
	_resolve_lighting_director()
	player = null
	grace_visual = null
	if get_tree() == null:
		return
	var candidate: Node = get_tree().get_first_node_in_group("player")
	if candidate is Node3D:
		player = candidate as Node3D
		grace_visual = player.get_node_or_null("GraceVisualV1")


func _resolve_lighting_director() -> void:
	lighting_director = null
	if get_tree() == null:
		return
	var candidate: Node = get_tree().get_first_node_in_group("lighting_director")
	if candidate is LightingDirector3D:
		lighting_director = candidate as LightingDirector3D


func _build_light() -> void:
	if profile == null or readability_light != null:
		return
	readability_light = DirectionalLight3D.new()
	readability_light.name = "GraceReadabilityRim"
	readability_light.light_color = profile.light_color
	readability_light.light_specular = profile.light_specular
	readability_light.light_indirect_energy = 0.0
	readability_light.light_volumetric_fog_energy = 0.0
	readability_light.shadow_enabled = false
	readability_light.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	readability_light.light_cull_mask = 1 << (profile.character_render_layer - 1)
	add_child(readability_light)


func _register_character_layers() -> void:
	if profile == null:
		return
	if player == null or not is_instance_valid(player):
		_resolve_dependencies()
	if grace_visual == null:
		return
	target_mesh_count = 0
	_register_layers_recursive(grace_visual)


func _register_layers_recursive(node: Node) -> void:
	if node is VisualInstance3D:
		var visual_instance: VisualInstance3D = node as VisualInstance3D
		var instance_id: int = visual_instance.get_instance_id()
		if not original_layers.has(instance_id):
			original_layers[instance_id] = {
				"ref": weakref(visual_instance),
				"layers": visual_instance.layers,
			}
		visual_instance.set_layer_mask_value(
			profile.character_render_layer,
			true
		)
		target_mesh_count += 1
	for child: Node in node.get_children():
		_register_layers_recursive(child)


func _restore_character_layers() -> void:
	for raw_id: Variant in original_layers.keys():
		var record: Dictionary = original_layers[int(raw_id)] as Dictionary
		var weak_value: Variant = record.get("ref", null)
		if not weak_value is WeakRef:
			continue
		var instance_value: Variant = (weak_value as WeakRef).get_ref()
		if instance_value is VisualInstance3D:
			(instance_value as VisualInstance3D).layers = int(
				record.get("layers", 1)
			)
	original_layers.clear()
	target_mesh_count = 0


func _current_quality() -> int:
	if lighting_director == null:
		return LightingDirector3D.Quality.CINEMATIC
	return clampi(lighting_director.quality, 0, 2)


func _apply_quality(quality: int) -> void:
	if profile == null or readability_light == null:
		return
	active_quality = clampi(quality, 0, 2)
	var energy: float = 0.0
	match active_quality:
		LightingDirector3D.Quality.BALANCED:
			energy = profile.balanced_energy
		LightingDirector3D.Quality.CINEMATIC:
			energy = profile.cinematic_energy
	readability_light.light_energy = energy
	readability_light.visible = enabled and energy > 0.001
	readability_quality_changed.emit(active_quality, energy)


func _update_light_direction(delta: float) -> void:
	if (
		player == null
		or not is_instance_valid(player)
		or readability_light == null
	):
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var target_position: Vector3 = (
		player.global_position + Vector3.UP * profile.target_height
	)
	var to_camera: Vector3 = camera.global_position - target_position
	if to_camera.length_squared() <= 0.0001:
		to_camera = -camera.global_basis.z
	to_camera = to_camera.normalized()
	var camera_right: Vector3 = camera.global_basis.x.normalized()
	var desired_source: Vector3 = (
		-to_camera * profile.behind_distance
		+ camera_right * profile.side_offset
		+ Vector3.UP * profile.height_offset
	)
	if desired_source.length_squared() <= 0.0001:
		desired_source = Vector3(1.0, 1.0, 1.0)
	desired_source = desired_source.normalized()
	var alpha: float = 1.0 - exp(
		-maxf(delta, 0.0) * profile.direction_smoothing
	)
	smoothed_source_direction = smoothed_source_direction.lerp(
		desired_source,
		clampf(alpha, 0.0, 1.0)
	).normalized()
	var source_position: Vector3 = (
		target_position + smoothed_source_direction * 4.0
	)
	readability_light.look_at_from_position(
		source_position,
		target_position,
		Vector3.UP
	)


func get_debug_data() -> Dictionary:
	return {
		"hero_readability_light_director": true,
		"initialized": initialized,
		"profile_id": profile.profile_id if profile != null else "",
		"enabled": enabled,
		"quality": active_quality,
		"energy": readability_light.light_energy if readability_light != null else 0.0,
		"light_visible": readability_light.visible if readability_light != null else false,
		"character_render_layer": profile.character_render_layer if profile != null else 0,
		"light_cull_mask": readability_light.light_cull_mask if readability_light != null else 0,
		"target_mesh_count": target_mesh_count,
		"indirect_energy_zero": readability_light != null and readability_light.light_indirect_energy == 0.0,
		"volumetric_energy_zero": readability_light != null and readability_light.light_volumetric_fog_energy == 0.0,
		"shadow_free": readability_light != null and not readability_light.shadow_enabled,
		"camera_relative": true,
		"follows_lighting_quality": true,
		"world_lighting_isolated_by_cull_mask": true,
		"geometry_unchanged": true,
		"gameplay_authority": false,
	}
