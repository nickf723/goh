extends Node3D
class_name CinematicLightingRig3D

## Reusable art-direction layer for authored scenes.
## It upgrades an existing WorldEnvironment and sun when present, then adds
## inexpensive stylized shafts and particles that remain visible at lower quality.

enum Quality {
	LOW,
	BALANCED,
	CINEMATIC,
}

@export_enum("Low", "Balanced", "Cinematic") var quality: int = Quality.CINEMATIC
@export var profile: String = "ruined_village"
@export var animate_atmosphere: bool = true
@export var shaft_strength: float = 1.0
@export var dust_strength: float = 1.0

var environment_node: WorldEnvironment
var sun: DirectionalLight3D
var fill_light: DirectionalLight3D
var shaft_root: Node3D
var dust_root: Node3D
var shaft_materials: Array[StandardMaterial3D] = []
var dust_systems: Array[GPUParticles3D] = []
var elapsed: float = 0.0


func _ready() -> void:
	add_to_group("cinematic_lighting")
	call_deferred("_install_profile")


func _process(delta: float) -> void:
	if not animate_atmosphere or shaft_materials.is_empty():
		return
	elapsed += delta
	for index: int in range(shaft_materials.size()):
		var pulse: float = 0.92 + sin(elapsed * (0.24 + float(index) * 0.035) + float(index) * 1.7) * 0.08
		shaft_materials[index].emission_energy_multiplier = shaft_strength * pulse


func _install_profile() -> void:
	environment_node = _find_or_create_environment()
	sun = _find_or_create_directional_light("LateAfternoonSun")
	fill_light = _find_or_create_directional_light("SkyFill")
	_configure_environment()
	_configure_directional_lights()

	shaft_root = Node3D.new()
	shaft_root.name = "LightShafts"
	add_child(shaft_root)

	dust_root = Node3D.new()
	dust_root.name = "AtmosphericDust"
	add_child(dust_root)

	match profile:
		"ruined_village":
			_build_ruined_village_profile()
		_:
			_build_neutral_profile()

	set_quality(quality)


func _find_or_create_environment() -> WorldEnvironment:
	var scene_root: Node = get_parent()
	if scene_root != null:
		var existing: Node = scene_root.get_node_or_null("VillageEnvironment")
		if existing is WorldEnvironment:
			return existing as WorldEnvironment

	var created: WorldEnvironment = WorldEnvironment.new()
	created.name = "CinematicWorldEnvironment"
	created.environment = Environment.new()
	add_child(created)
	return created


func _find_or_create_directional_light(node_name: String) -> DirectionalLight3D:
	var scene_root: Node = get_parent()
	if scene_root != null:
		var existing: Node = scene_root.get_node_or_null(node_name)
		if existing is DirectionalLight3D:
			return existing as DirectionalLight3D

	var created: DirectionalLight3D = DirectionalLight3D.new()
	created.name = node_name
	add_child(created)
	return created


func _configure_environment() -> void:
	if environment_node.environment == null:
		environment_node.environment = Environment.new()
	var environment: Environment = environment_node.environment

	var sky_material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.075, 0.13, 0.23, 1.0)
	sky_material.sky_horizon_color = Color(0.72, 0.49, 0.31, 1.0)
	sky_material.ground_bottom_color = Color(0.035, 0.045, 0.065, 1.0)
	sky_material.ground_horizon_color = Color(0.42, 0.34, 0.29, 1.0)
	sky_material.sun_angle_max = 18.0
	sky_material.sun_curve = 0.08

	var sky: Sky = Sky.new()
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.background_energy_multiplier = 0.72
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_color = Color(0.46, 0.56, 0.72, 1.0)
	environment.ambient_light_energy = 0.58
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.08
	environment.tonemap_white = 1.35

	environment.fog_enabled = true
	environment.fog_light_color = Color(0.61, 0.60, 0.62, 1.0)
	environment.fog_light_energy = 0.62
	environment.fog_density = 0.0035
	environment.fog_height = 4.0
	environment.fog_height_density = 0.065
	environment.fog_sun_scatter = 0.42
	environment.fog_sky_affect = 0.62

	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.021
	environment.volumetric_fog_albedo = Color(0.88, 0.82, 0.74, 1.0)
	environment.volumetric_fog_emission = Color(0.08, 0.095, 0.13, 1.0)
	environment.volumetric_fog_emission_energy = 0.18
	environment.volumetric_fog_length = 82.0
	environment.volumetric_fog_detail_spread = 1.65
	environment.volumetric_fog_ambient_inject = 0.34
	environment.volumetric_fog_anisotropy = 0.68
	environment.volumetric_fog_temporal_reprojection_enabled = true

	environment.glow_enabled = true
	environment.glow_intensity = 0.72
	environment.glow_bloom = 0.12
	environment.glow_hdr_threshold = 1.05
	environment.ssao_enabled = true
	environment.ssao_intensity = 1.45
	environment.ssao_radius = 2.3


func _configure_directional_lights() -> void:
	sun.rotation_degrees = Vector3(-42.0, -31.0, -4.0)
	sun.light_color = Color(1.0, 0.69, 0.42, 1.0)
	sun.light_energy = 1.42
	sun.light_volumetric_fog_energy = 1.7
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 115.0
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY

	fill_light.rotation_degrees = Vector3(-62.0, 138.0, 0.0)
	fill_light.light_color = Color(0.33, 0.48, 0.78, 1.0)
	fill_light.light_energy = 0.34
	fill_light.light_volumetric_fog_energy = 0.18
	fill_light.shadow_enabled = false
	fill_light.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY


func _build_ruined_village_profile() -> void:
	# Each shaft is an intentionally broad, additive volume. Real volumetric fog
	# supplies the occlusion; the mesh keeps the composition legible on lower tiers.
	_create_light_shaft("ArrivalRayLeft", Vector3(-12.0, 10.5, 54.0), 23.0, 2.7, 6.2, Vector3(10.0, 0.0, -16.0))
	_create_light_shaft("ArrivalRayRight", Vector3(11.0, 12.0, 45.0), 27.0, 2.2, 5.4, Vector3(7.0, 0.0, -13.0))
	_create_light_shaft("SquareRayLeft", Vector3(-10.0, 15.0, 1.0), 31.0, 3.0, 7.2, Vector3(9.0, 0.0, -18.0))
	_create_light_shaft("SquareRayRight", Vector3(12.0, 14.0, -5.0), 26.0, 2.0, 5.8, Vector3(8.0, 0.0, -15.0))
	_create_light_shaft("ChurchRay", Vector3(0.0, 22.0, -63.0), 36.0, 3.5, 8.5, Vector3(10.0, 0.0, -17.0), 1.22)
	_create_light_shaft("ChurchTowerRay", Vector3(-12.0, 23.0, -68.0), 30.0, 2.2, 5.5, Vector3(8.0, 0.0, -15.0))

	_create_dust_volume("ArrivalDust", Vector3(0.0, 5.0, 53.0), Vector3(18.0, 6.0, 18.0))
	_create_dust_volume("SquareDust", Vector3(0.0, 7.0, -1.0), Vector3(22.0, 8.0, 15.0))
	_create_dust_volume("ChurchDust", Vector3(0.0, 14.0, -61.0), Vector3(23.0, 10.0, 17.0))

	_create_warm_accent("ChurchThresholdGlow", Vector3(0.0, 12.0, -66.0), 11.0, 1.5)
	_create_warm_accent("MemoryTrailGlow", Vector3(-10.5, 5.0, 4.8), 7.0, 0.72)
	_create_cool_accent("RavineMoonFill", Vector3(0.0, -1.0, -25.0), 24.0, 0.48)


func _build_neutral_profile() -> void:
	_create_light_shaft("HeroRay", Vector3(0.0, 9.0, 0.0), 18.0, 2.0, 5.0, Vector3(8.0, 0.0, -14.0))
	_create_dust_volume("HeroDust", Vector3.ZERO, Vector3(12.0, 7.0, 12.0))


func _create_light_shaft(
	node_name: String,
	position_value: Vector3,
	length: float,
	narrow_radius: float,
	wide_radius: float,
	rotation_value: Vector3,
	energy_scale: float = 1.0
) -> void:
	var shaft: MeshInstance3D = MeshInstance3D.new()
	shaft.name = node_name
	shaft.position = position_value
	shaft.rotation_degrees = rotation_value

	var cone: CylinderMesh = CylinderMesh.new()
	cone.height = length
	cone.top_radius = narrow_radius
	cone.bottom_radius = wide_radius
	cone.radial_segments = 20
	cone.rings = 1
	shaft.mesh = cone

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(1.0, 0.71, 0.38, 0.026 * energy_scale)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.52, 0.20, 1.0)
	material.emission_energy_multiplier = shaft_strength * energy_scale
	shaft.material_override = material
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shaft_root.add_child(shaft)
	shaft_materials.append(material)


func _create_dust_volume(node_name: String, position_value: Vector3, extents: Vector3) -> void:
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.name = node_name
	particles.position = position_value
	particles.amount = 72
	particles.lifetime = 9.0
	particles.randomness = 0.82
	particles.visibility_aabb = AABB(-extents, extents * 2.0)

	var process_material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_material.emission_box_extents = extents
	process_material.direction = Vector3(0.18, 1.0, -0.12)
	process_material.spread = 180.0
	process_material.initial_velocity_min = 0.025
	process_material.initial_velocity_max = 0.12
	process_material.gravity = Vector3(0.018, 0.032, -0.012)
	process_material.scale_min = 0.45
	process_material.scale_max = 1.35
	particles.process_material = process_material

	var mote: QuadMesh = QuadMesh.new()
	mote.size = Vector2(0.035, 0.035)
	var mote_material: StandardMaterial3D = StandardMaterial3D.new()
	mote_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mote_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mote_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mote_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mote_material.albedo_color = Color(1.0, 0.78, 0.44, 0.46 * dust_strength)
	mote_material.emission_enabled = true
	mote_material.emission = Color(1.0, 0.58, 0.24, 1.0)
	mote_material.emission_energy_multiplier = 1.25
	mote.material = mote_material
	particles.draw_pass_1 = mote

	dust_root.add_child(particles)
	dust_systems.append(particles)


func _create_warm_accent(node_name: String, position_value: Vector3, range_value: float, energy: float) -> void:
	var light: OmniLight3D = OmniLight3D.new()
	light.name = node_name
	light.position = position_value
	light.light_color = Color(1.0, 0.48, 0.18, 1.0)
	light.light_energy = energy
	light.omni_range = range_value
	light.omni_attenuation = 1.45
	light.light_volumetric_fog_energy = 1.15
	light.shadow_enabled = false
	add_child(light)


func _create_cool_accent(node_name: String, position_value: Vector3, range_value: float, energy: float) -> void:
	var light: OmniLight3D = OmniLight3D.new()
	light.name = node_name
	light.position = position_value
	light.light_color = Color(0.22, 0.46, 0.88, 1.0)
	light.light_energy = energy
	light.omni_range = range_value
	light.omni_attenuation = 1.25
	light.light_volumetric_fog_energy = 0.32
	light.shadow_enabled = false
	add_child(light)


func set_quality(value: int) -> void:
	quality = clampi(value, Quality.LOW, Quality.CINEMATIC)
	if environment_node == null or environment_node.environment == null:
		return

	var environment: Environment = environment_node.environment
	match quality:
		Quality.LOW:
			environment.volumetric_fog_enabled = false
			environment.ssao_enabled = false
			environment.glow_intensity = 0.48
			_set_dust_amount(18)
		Quality.BALANCED:
			environment.volumetric_fog_enabled = true
			environment.volumetric_fog_density = 0.016
			environment.volumetric_fog_length = 58.0
			environment.ssao_enabled = true
			environment.ssao_intensity = 1.1
			environment.glow_intensity = 0.62
			_set_dust_amount(42)
		Quality.CINEMATIC:
			environment.volumetric_fog_enabled = true
			environment.volumetric_fog_density = 0.021
			environment.volumetric_fog_length = 82.0
			environment.ssao_enabled = true
			environment.ssao_intensity = 1.45
			environment.glow_intensity = 0.72
			_set_dust_amount(72)


func _set_dust_amount(amount_value: int) -> void:
	for particles: GPUParticles3D in dust_systems:
		particles.amount = amount_value
		particles.emitting = amount_value > 0


func get_debug_data() -> Dictionary:
	return {
		"profile": profile,
		"quality": quality,
		"shafts": shaft_materials.size(),
		"dust_volumes": dust_systems.size(),
		"volumetric_fog": environment_node != null
			and environment_node.environment != null
			and environment_node.environment.volumetric_fog_enabled,
	}
