extends Node3D
class_name FluidForceVolume

@export var volume_size: Vector3 = Vector3(8.0, 3.0, 8.0)
@export var fluid_density_kg_m3: float = 1000.0
@export var buoyancy_multiplier: float = 1.0
@export var flow_velocity_m_s: Vector3 = Vector3.ZERO
@export var horizontal_drag_coefficient: float = 2.8
@export var vertical_drag_coefficient: float = 3.6
@export var angular_stability: float = 5.0
@export var priority: int = 0

@export_group("Presentation")
@export var create_default_visuals: bool = true
@export var shallow_color: Color = Color(0.08, 0.62, 0.88, 0.68)
@export var deep_color: Color = Color(0.015, 0.12, 0.32, 0.84)
@export var foam_color: Color = Color(0.62, 0.94, 1.0, 0.85)
@export var wave_amplitude: float = 0.08
@export var wave_speed: float = 1.0
@export var surface_emission: float = 0.16
@export var ripple_duration: float = 0.75
@export var ripple_min_speed: float = 0.7

var surface_mesh: MeshInstance3D
var volume_mesh: MeshInstance3D
var ripple_count: int = 0


func _ready() -> void:
	add_to_group("fluid_force_volumes")
	add_to_group("debuggable")
	if create_default_visuals:
		build_default_visuals()


func get_surface_y() -> float:
	return global_position.y + volume_size.y * 0.5


func get_bottom_y() -> float:
	return global_position.y - volume_size.y * 0.5


func contains_horizontal(world_position: Vector3, margin: float = 0.0) -> bool:
	var local_position: Vector3 = to_local(world_position)
	return (
		absf(local_position.x) <= volume_size.x * 0.5 + margin
		and absf(local_position.z) <= volume_size.z * 0.5 + margin
	)


func contains_point(world_position: Vector3, margin: float = 0.0) -> bool:
	if not contains_horizontal(world_position, margin):
		return false
	return (
		world_position.y >= get_bottom_y() - margin
		and world_position.y <= get_surface_y() + margin
	)


func get_submerged_fraction(
	body_center_world: Vector3,
	body_height_m: float,
	horizontal_margin: float = 0.0
) -> float:
	if not contains_horizontal(body_center_world, horizontal_margin):
		return 0.0
	var safe_height: float = max(body_height_m, 0.05)
	var body_bottom: float = body_center_world.y - safe_height * 0.5
	var body_top: float = body_center_world.y + safe_height * 0.5
	var fluid_bottom: float = get_bottom_y()
	var fluid_top: float = get_surface_y()
	var overlap: float = min(body_top, fluid_top) - max(body_bottom, fluid_bottom)
	return clampf(overlap / safe_height, 0.0, 1.0)


func get_flow_velocity_at(_world_position: Vector3) -> Vector3:
	return flow_velocity_m_s


func build_default_visuals() -> void:
	if surface_mesh != null:
		return

	volume_mesh = MeshInstance3D.new()
	volume_mesh.name = "FluidVolumeVisual"
	var box_mesh := BoxMesh.new()
	box_mesh.size = volume_size
	volume_mesh.mesh = box_mesh
	var volume_material := StandardMaterial3D.new()
	volume_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	volume_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	volume_material.albedo_color = Color(deep_color.r, deep_color.g, deep_color.b, 0.14)
	volume_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	volume_mesh.material_override = volume_material
	add_child(volume_mesh)

	surface_mesh = MeshInstance3D.new()
	surface_mesh.name = "FluidSurface"
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2(volume_size.x, volume_size.z)
	plane_mesh.subdivide_width = 32
	plane_mesh.subdivide_depth = 32
	surface_mesh.mesh = plane_mesh
	surface_mesh.position.y = volume_size.y * 0.5
	surface_mesh.material_override = make_surface_material()
	surface_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(surface_mesh)


func make_surface_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_alpha_prepass, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.08, 0.62, 0.88, 0.68);
uniform vec4 deep_color : source_color = vec4(0.015, 0.12, 0.32, 0.84);
uniform vec4 foam_color : source_color = vec4(0.62, 0.94, 1.0, 0.85);
uniform float wave_amplitude = 0.08;
uniform float wave_speed = 1.0;
uniform vec2 flow_direction = vec2(1.0, 0.0);
uniform float flow_speed = 0.0;
uniform float emission_strength = 0.16;

varying float wave_value;

void vertex() {
	vec2 worldish = VERTEX.xz;
	float wave_a = sin(worldish.x * 1.45 + TIME * wave_speed);
	float wave_b = cos(worldish.y * 1.15 - TIME * wave_speed * 0.72);
	float flow_wave = sin(dot(worldish, normalize(flow_direction + vec2(0.0001))) * 2.2 - TIME * flow_speed);
	wave_value = (wave_a + wave_b) * 0.5 + flow_wave * 0.22;
	VERTEX.y += wave_value * wave_amplitude;
}

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	float moving_band = 0.5 + 0.5 * sin((UV.x * flow_direction.x + UV.y * flow_direction.y) * 48.0 - TIME * flow_speed * 2.0);
	float foam = smoothstep(0.76, 1.0, moving_band) * clamp(abs(wave_value), 0.0, 1.0) * 0.28;
	vec3 base_color = mix(deep_color.rgb, shallow_color.rgb, 0.44 + fresnel * 0.42);
	base_color = mix(base_color, foam_color.rgb, foam);
	ALBEDO = base_color;
	EMISSION = base_color * emission_strength + foam_color.rgb * foam * 0.18;
	ROUGHNESS = 0.08;
	SPECULAR = 0.92;
	ALPHA = mix(shallow_color.a, deep_color.a, fresnel * 0.55) + foam * 0.12;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("shallow_color", shallow_color)
	material.set_shader_parameter("deep_color", deep_color)
	material.set_shader_parameter("foam_color", foam_color)
	material.set_shader_parameter("wave_amplitude", max(wave_amplitude, 0.0))
	material.set_shader_parameter("wave_speed", max(wave_speed, 0.0))
	material.set_shader_parameter("emission_strength", max(surface_emission, 0.0))
	var horizontal_flow := Vector2(flow_velocity_m_s.x, flow_velocity_m_s.z)
	var flow_direction := horizontal_flow.normalized() if horizontal_flow.length() > 0.01 else Vector2.RIGHT
	material.set_shader_parameter("flow_direction", flow_direction)
	material.set_shader_parameter("flow_speed", horizontal_flow.length())
	return material


func spawn_ripple(world_position: Vector3, intensity: float = 1.0) -> void:
	if not create_default_visuals or not contains_horizontal(world_position, 0.8):
		return
	var ripple := MeshInstance3D.new()
	ripple.name = "WaterRipple"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.48
	torus.rings = 24
	torus.ring_segments = 8
	ripple.mesh = torus
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = foam_color
	material.emission_enabled = true
	material.emission = foam_color
	material.emission_energy_multiplier = 1.4
	ripple.material_override = material
	ripple.global_position = Vector3(world_position.x, get_surface_y() + 0.035, world_position.z)
	ripple.scale = Vector3.ONE * clampf(0.45 + intensity * 0.12, 0.45, 1.15)
	get_tree().current_scene.add_child(ripple)
	ripple_count += 1
	var duration: float = max(ripple_duration, 0.1)
	var tween := ripple.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ripple, "scale", ripple.scale * (2.4 + clampf(intensity, 0.0, 3.0)), duration)
	tween.tween_property(ripple, "transparency", 1.0, duration)
	tween.set_parallel(false)
	tween.tween_callback(ripple.queue_free)


func get_debug_data() -> Dictionary:
	return {
		"fluid_volume": true,
		"size": volume_size,
		"surface_y": snapped(get_surface_y(), 0.01),
		"density_kg_m3": snapped(fluid_density_kg_m3, 0.1),
		"buoyancy_multiplier": snapped(buoyancy_multiplier, 0.01),
		"flow_velocity": flow_velocity_m_s,
		"horizontal_drag": snapped(horizontal_drag_coefficient, 0.01),
		"vertical_drag": snapped(vertical_drag_coefficient, 0.01),
		"angular_stability": snapped(angular_stability, 0.01),
		"ripple_count": ripple_count,
	}
