extends Node3D
class_name WaterPresentationDirector3D

signal water_presentation_enabled_changed(enabled: bool)
signal water_surface_registered(role: String, node_name: String)

const WaterSurfaceShader: Shader = preload("res://shaders/water_surface_v1.gdshader")
const WaterfallShader: Shader = preload("res://shaders/waterfall_surface_v1.gdshader")

@export var profile: WaterPresentationProfile
@export var enabled: bool = true
@export var debug_hotkeys_enabled: bool = false

var targets: Dictionary = {}
var role_counts: Dictionary = {}
var shared_materials: Dictionary = {}
var restored_target_count: int = 0


func _ready() -> void:
	add_to_group("water_presentation_director")
	add_to_group("debuggable")
	set_meta("water_presentation_initialized", profile != null)


func _unhandled_input(event: InputEvent) -> void:
	if not debug_hotkeys_enabled:
		return
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo or key_event.keycode != KEY_F2:
		return
	set_enabled(not enabled)
	print("Water Presentation Director: ", "ON" if enabled else "OFF")
	get_viewport().set_input_as_handled()


func register_surface(
	target: MeshInstance3D,
	role: String,
	flow_direction: Vector2 = Vector2.RIGHT,
	flow_speed: float = -1.0
) -> bool:
	if profile == null or target == null or not is_instance_valid(target):
		return false
	var target_id: int = target.get_instance_id()
	if targets.has(target_id):
		return true
	var normalized_role: String = role.strip_edges().to_lower()
	if normalized_role not in ["stream", "basin", "waterfall"]:
		return false
	var original: Material = target.material_override
	var material_key: String = normalized_role
	if normalized_role != "waterfall":
		material_key += ":%.3f:%.3f:%.3f" % [
			flow_direction.x,
			flow_direction.y,
			flow_speed,
		]
	var enhanced: ShaderMaterial = _get_or_create_material(
		material_key,
		normalized_role,
		flow_direction,
		flow_speed
	)
	if enhanced == null:
		return false
	targets[target_id] = {
		"ref": weakref(target),
		"original": original,
		"enhanced": enhanced,
		"role": normalized_role,
		"flow_direction": flow_direction,
		"flow_speed": flow_speed,
	}
	role_counts[normalized_role] = int(role_counts.get(normalized_role, 0)) + 1
	target.add_to_group("water_presentation_target")
	target.set_meta("water_presentation_role", normalized_role)
	if enabled:
		target.material_override = enhanced
	water_surface_registered.emit(normalized_role, target.name)
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
	water_presentation_enabled_changed.emit(enabled)


func unregister_surface(target: MeshInstance3D, restore: bool = true) -> void:
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


func _get_or_create_material(
	material_key: String,
	role: String,
	flow_direction: Vector2,
	flow_speed: float
) -> ShaderMaterial:
	if shared_materials.has(material_key):
		return shared_materials[material_key] as ShaderMaterial
	var material := ShaderMaterial.new()
	if role == "waterfall":
		material.shader = WaterfallShader
		_apply_waterfall_parameters(material)
	else:
		material.shader = WaterSurfaceShader
		_apply_horizontal_parameters(material, role, flow_direction, flow_speed)
	shared_materials[material_key] = material
	return material


func _apply_horizontal_parameters(
	material: ShaderMaterial,
	role: String,
	flow_direction: Vector2,
	flow_speed: float
) -> void:
	var is_stream: bool = role == "stream"
	var resolved_direction: Vector2 = flow_direction
	if resolved_direction.length_squared() <= 0.0001:
		resolved_direction = Vector2.RIGHT
	resolved_direction = resolved_direction.normalized()
	var resolved_speed: float = flow_speed
	if resolved_speed < 0.0:
		resolved_speed = profile.default_flow_speed if is_stream else profile.default_flow_speed * 0.38

	material.set_shader_parameter("shallow_color", profile.stream_shallow_color if is_stream else profile.basin_shallow_color)
	material.set_shader_parameter("deep_color", profile.stream_deep_color if is_stream else profile.basin_deep_color)
	material.set_shader_parameter("foam_color", profile.stream_foam_color if is_stream else profile.basin_foam_color)
	material.set_shader_parameter("reflection_tint", profile.stream_reflection_tint if is_stream else profile.basin_reflection_tint)
	material.set_shader_parameter("electrical_color", Color(0.34, 0.72, 1.0, 1.0))
	material.set_shader_parameter("hot_color", Color(1.0, 0.31, 0.10, 1.0))
	material.set_shader_parameter("wave_amplitude", profile.stream_wave_amplitude if is_stream else profile.basin_wave_amplitude)
	material.set_shader_parameter("wave_speed", profile.stream_wave_speed if is_stream else profile.basin_wave_speed)
	material.set_shader_parameter("large_wave_scale", profile.large_wave_scale)
	material.set_shader_parameter("small_wave_scale", profile.small_wave_scale)
	material.set_shader_parameter("normal_strength", profile.normal_strength)
	material.set_shader_parameter("flow_direction", resolved_direction)
	material.set_shader_parameter("flow_speed", maxf(resolved_speed, 0.0))
	material.set_shader_parameter("flow_band_scale", profile.flow_band_scale)
	material.set_shader_parameter("flow_band_strength", profile.flow_band_strength)
	material.set_shader_parameter("surface_emission", profile.surface_emission)
	material.set_shader_parameter("surface_roughness", profile.surface_roughness)
	material.set_shader_parameter("surface_specular", profile.surface_specular)
	material.set_shader_parameter("turbulence", 0.0)
	material.set_shader_parameter("electrical_intensity", 0.0)
	material.set_shader_parameter("heat_intensity", 0.0)
	material.set_shader_parameter("visibility", 1.0)
	material.set_shader_parameter("fresnel_power", profile.fresnel_power)
	material.set_shader_parameter("refraction_strength", profile.stream_refraction_strength if is_stream else profile.basin_refraction_strength)
	material.set_shader_parameter("refraction_mix", profile.stream_refraction_mix if is_stream else profile.basin_refraction_mix)
	material.set_shader_parameter("depth_tint_distance", profile.stream_depth_tint_distance if is_stream else profile.basin_depth_tint_distance)
	material.set_shader_parameter("shoreline_depth", profile.stream_shoreline_depth if is_stream else profile.basin_shoreline_depth)
	material.set_shader_parameter("shoreline_foam_strength", profile.stream_shoreline_foam if is_stream else profile.basin_shoreline_foam)
	material.set_shader_parameter("reflection_strength", profile.stream_reflection_strength if is_stream else profile.basin_reflection_strength)
	material.set_shader_parameter("micro_wave_strength", profile.stream_micro_wave_strength if is_stream else profile.basin_micro_wave_strength)
	material.set_shader_parameter("micro_wave_scale", profile.stream_micro_wave_scale if is_stream else profile.basin_micro_wave_scale)
	material.set_shader_parameter("micro_wave_speed", (profile.stream_wave_speed if is_stream else profile.basin_wave_speed) * 1.15)
	material.set_shader_parameter("depth_alpha_strength", profile.stream_depth_alpha_strength if is_stream else profile.basin_depth_alpha_strength)


func _apply_waterfall_parameters(material: ShaderMaterial) -> void:
	material.set_shader_parameter("body_color", profile.waterfall_body_color)
	material.set_shader_parameter("highlight_color", profile.waterfall_highlight_color)
	material.set_shader_parameter("foam_color", profile.waterfall_foam_color)
	material.set_shader_parameter("shadow_color", profile.waterfall_shadow_color)
	material.set_shader_parameter("reflection_tint", profile.waterfall_reflection_tint)
	material.set_shader_parameter("flow_speed", profile.waterfall_flow_speed)
	material.set_shader_parameter("streak_scale", profile.waterfall_streak_scale)
	material.set_shader_parameter("cross_streak_scale", profile.waterfall_cross_streak_scale)
	material.set_shader_parameter("turbulence", profile.waterfall_turbulence)
	material.set_shader_parameter("flutter_amplitude", profile.waterfall_flutter_amplitude)
	material.set_shader_parameter("flutter_scale", profile.waterfall_flutter_scale)
	material.set_shader_parameter("refraction_strength", profile.waterfall_refraction_strength)
	material.set_shader_parameter("refraction_mix", profile.waterfall_refraction_mix)
	material.set_shader_parameter("edge_foam_strength", profile.waterfall_edge_foam)
	material.set_shader_parameter("terminal_foam_strength", profile.waterfall_terminal_foam)
	material.set_shader_parameter("fresnel_strength", profile.waterfall_fresnel_strength)
	material.set_shader_parameter("surface_roughness", profile.waterfall_roughness)
	material.set_shader_parameter("surface_specular", profile.waterfall_specular)
	material.set_shader_parameter("surface_emission", profile.waterfall_emission)
	material.set_shader_parameter("visibility", 1.0)


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
		"water_presentation_director": true,
		"initialized": profile != null,
		"profile_id": profile.profile_id if profile != null else "",
		"enabled": enabled,
		"debug_hotkeys": debug_hotkeys_enabled,
		"target_count": live_targets,
		"role_counts": role_counts.duplicate(true),
		"shared_materials": shared_materials.size(),
		"horizontal_shader": WaterSurfaceShader.resource_path,
		"waterfall_shader": WaterfallShader.resource_path,
		"depth_aware": true,
		"screen_refraction": true,
		"physics_authority": false,
		"restored_target_count": restored_target_count,
	}
