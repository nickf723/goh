extends Node3D
class_name FluidForceVolume

const WaterSurfaceShader: Shader = preload("res://shaders/water_surface_v1.gdshader")

signal disturbance_emitted(event: FluidDisturbanceEvent)

@export var volume_size: Vector3 = Vector3(8.0, 3.0, 8.0)
@export var fluid_density_kg_m3: float = 1000.0
@export var buoyancy_multiplier: float = 1.0
@export var flow_velocity_m_s: Vector3 = Vector3.ZERO
@export var horizontal_drag_coefficient: float = 2.8
@export var vertical_drag_coefficient: float = 3.6
@export var angular_stability: float = 5.0
@export var priority: int = 0

@export_group("Presentation")
@export var presentation_enabled: bool = true
@export var create_default_visuals: bool = true
@export var presentation_profile: FluidPresentationProfile
@export var shallow_color: Color = Color(0.08, 0.62, 0.88, 0.68)
@export var deep_color: Color = Color(0.015, 0.12, 0.32, 0.84)
@export var foam_color: Color = Color(0.62, 0.94, 1.0, 0.85)
@export var wave_amplitude: float = 0.08
@export var wave_speed: float = 1.0
@export var surface_emission: float = 0.16
@export var ripple_duration: float = 0.75
@export var ripple_min_speed: float = 0.7
@export var starting_temperature_c: float = 20.0
@export_range(0.0, 1.0, 0.01) var starting_electrical_intensity: float = 0.0
@export_range(0.0, 1.0, 0.01) var starting_turbulence: float = 0.0

var surface_mesh: MeshInstance3D
var volume_mesh: MeshInstance3D
var surface_material: ShaderMaterial
var presentation_renderer: FluidDisturbanceRenderer
var runtime_profile: FluidPresentationProfile
var ripple_count: int = 0
var disturbance_count: int = 0
var disturbance_counts: Dictionary = {}
var visual_temperature_c: float = 20.0
var visual_electrical_intensity: float = 0.0
var visual_turbulence: float = 0.0
var last_disturbance: Dictionary = {}


func _ready() -> void:
	add_to_group("fluid_force_volumes")
	add_to_group("debuggable")
	add_to_group("lab_resettable")
	visual_temperature_c = starting_temperature_c
	visual_electrical_intensity = clampf(starting_electrical_intensity, 0.0, 1.0)
	visual_turbulence = clampf(starting_turbulence, 0.0, 1.0)
	if create_default_visuals:
		build_default_visuals()
	ensure_presentation_renderer()
	refresh_presentation()


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


func get_presentation_profile() -> FluidPresentationProfile:
	if presentation_profile != null:
		return presentation_profile
	if runtime_profile == null:
		runtime_profile = FluidPresentationProfile.new()
	sync_runtime_profile()
	return runtime_profile


func sync_runtime_profile() -> void:
	if runtime_profile == null:
		return
	runtime_profile.shallow_color = shallow_color
	runtime_profile.deep_color = deep_color
	runtime_profile.foam_color = foam_color
	runtime_profile.wave_amplitude = wave_amplitude
	runtime_profile.wave_speed = wave_speed
	runtime_profile.surface_emission = surface_emission
	runtime_profile.ripple_duration = ripple_duration


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
	volume_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	volume_mesh.material_override = volume_material
	add_child(volume_mesh)

	surface_mesh = MeshInstance3D.new()
	surface_mesh.name = "FluidSurface"
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2(volume_size.x, volume_size.z)
	plane_mesh.subdivide_width = 56
	plane_mesh.subdivide_depth = 56
	surface_mesh.mesh = plane_mesh
	surface_mesh.position.y = volume_size.y * 0.5
	surface_material = make_surface_material()
	surface_mesh.material_override = surface_material
	surface_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(surface_mesh)


func make_surface_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = WaterSurfaceShader
	return material


func ensure_presentation_renderer() -> void:
	if not presentation_enabled or presentation_renderer != null:
		return
	presentation_renderer = FluidDisturbanceRenderer.new()
	presentation_renderer.name = "FluidDisturbanceRenderer"
	add_child(presentation_renderer)
	presentation_renderer.configure(self, get_presentation_profile())


func refresh_presentation() -> void:
	var profile: FluidPresentationProfile = get_presentation_profile()
	if presentation_renderer != null:
		presentation_renderer.configure(self, profile)
	if surface_mesh != null:
		var plane := surface_mesh.mesh as PlaneMesh
		if plane != null:
			plane.size = Vector2(volume_size.x, volume_size.z)
		surface_mesh.position.y = volume_size.y * 0.5
	if volume_mesh != null:
		var box := volume_mesh.mesh as BoxMesh
		if box != null:
			box.size = volume_size
		var volume_material := volume_mesh.material_override as StandardMaterial3D
		if volume_material != null:
			volume_material.albedo_color = Color(
				profile.deep_color.r,
				profile.deep_color.g,
				profile.deep_color.b,
				0.12 + profile.deep_color.a * 0.08
			)
	if surface_material == null and surface_mesh != null:
		surface_material = make_surface_material()
		surface_mesh.material_override = surface_material
	apply_surface_parameters(profile)


func apply_surface_parameters(profile: FluidPresentationProfile) -> void:
	if surface_material == null or profile == null:
		return
	var horizontal_flow := Vector2(flow_velocity_m_s.x, flow_velocity_m_s.z)
	var flow_direction := horizontal_flow.normalized() if horizontal_flow.length() > 0.01 else Vector2.RIGHT
	var heat_intensity: float = clampf((visual_temperature_c - 45.0) / 75.0, 0.0, 1.0)
	surface_material.set_shader_parameter("shallow_color", profile.shallow_color)
	surface_material.set_shader_parameter("deep_color", profile.deep_color)
	surface_material.set_shader_parameter("foam_color", profile.foam_color)
	surface_material.set_shader_parameter("electrical_color", profile.electrical_color)
	surface_material.set_shader_parameter("hot_color", profile.hot_color)
	surface_material.set_shader_parameter("wave_amplitude", max(profile.wave_amplitude, 0.0))
	surface_material.set_shader_parameter("wave_speed", max(profile.wave_speed, 0.0))
	surface_material.set_shader_parameter("large_wave_scale", max(profile.large_wave_scale, 0.01))
	surface_material.set_shader_parameter("small_wave_scale", max(profile.small_wave_scale, 0.01))
	surface_material.set_shader_parameter("normal_strength", max(profile.normal_strength, 0.0))
	surface_material.set_shader_parameter("flow_direction", flow_direction)
	surface_material.set_shader_parameter("flow_speed", horizontal_flow.length())
	surface_material.set_shader_parameter("flow_band_scale", max(profile.flow_band_scale, 0.01))
	surface_material.set_shader_parameter("flow_band_strength", max(profile.flow_band_strength, 0.0))
	surface_material.set_shader_parameter("surface_emission", max(profile.surface_emission, 0.0))
	surface_material.set_shader_parameter("surface_roughness", clampf(profile.roughness, 0.0, 1.0))
	surface_material.set_shader_parameter("surface_specular", clampf(profile.specular, 0.0, 1.0))
	surface_material.set_shader_parameter("turbulence", clampf(visual_turbulence, 0.0, 1.0))
	surface_material.set_shader_parameter("electrical_intensity", clampf(visual_electrical_intensity, 0.0, 1.0))
	surface_material.set_shader_parameter("heat_intensity", heat_intensity)
	surface_material.set_shader_parameter("visibility", 1.0)


func set_visual_state(
	temperature_c: float,
	electrical_intensity: float = 0.0,
	turbulence: float = 0.0
) -> void:
	visual_temperature_c = clampf(temperature_c, -273.15, 2000.0)
	visual_electrical_intensity = clampf(electrical_intensity, 0.0, 1.0)
	visual_turbulence = clampf(turbulence, 0.0, 1.0)
	apply_surface_parameters(get_presentation_profile())


func emit_disturbance(
	kind: String,
	world_position: Vector3,
	direction: Vector3 = Vector3.ZERO,
	velocity: Vector3 = Vector3.ZERO,
	strength: float = 1.0,
	radius: float = 0.5,
	source_id: String = "unknown",
	tags: Array[String] = [],
	metadata: Dictionary = {}
) -> FluidDisturbanceEvent:
	var event := FluidDisturbanceEvent.make(
		kind,
		world_position,
		direction,
		velocity,
		strength,
		radius,
		source_id,
		tags
	)
	event.metadata = metadata.duplicate(true)
	emit_disturbance_event(event)
	return event


func emit_disturbance_event(event: FluidDisturbanceEvent) -> void:
	if event == null or not event.is_finite_event():
		return
	ensure_presentation_renderer()
	disturbance_count += 1
	disturbance_counts[event.kind] = int(disturbance_counts.get(event.kind, 0)) + 1
	last_disturbance = event.get_debug_data()
	if event.kind in [
		FluidDisturbanceEvent.KIND_RIPPLE,
		FluidDisturbanceEvent.KIND_ENTRY,
		FluidDisturbanceEvent.KIND_IMPACT,
		FluidDisturbanceEvent.KIND_WAKE,
		FluidDisturbanceEvent.KIND_CHURN,
	]:
		ripple_count += 1
	disturbance_emitted.emit(event)
	if presentation_enabled and presentation_renderer != null:
		presentation_renderer.render_disturbance(event)


func spawn_ripple(world_position: Vector3, intensity: float = 1.0) -> void:
	if not contains_horizontal(world_position, 0.8):
		return
	emit_disturbance(
		FluidDisturbanceEvent.KIND_RIPPLE,
		world_position,
		flow_velocity_m_s,
		Vector3.ZERO,
		clampf(intensity, 0.0, 4.0),
		clampf(0.35 + intensity * 0.1, 0.25, 1.2),
		"legacy_ripple"
	)


func reset_target() -> void:
	if presentation_renderer != null:
		presentation_renderer.reset_target()
	ripple_count = 0
	disturbance_count = 0
	disturbance_counts.clear()
	last_disturbance.clear()
	set_visual_state(starting_temperature_c, starting_electrical_intensity, starting_turbulence)


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
		"visual_temperature_c": snapped(visual_temperature_c, 0.1),
		"electrical_intensity": snapped(visual_electrical_intensity, 0.01),
		"turbulence": snapped(visual_turbulence, 0.01),
		"ripple_count": ripple_count,
		"disturbance_count": disturbance_count,
		"disturbance_kinds": disturbance_counts.duplicate(),
		"last_disturbance": last_disturbance.duplicate(true),
		"profile": get_presentation_profile().get_debug_data(),
		"renderer": presentation_renderer.get_debug_data() if presentation_renderer != null else {},
	}
