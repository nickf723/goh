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
@export_range(0.0, 5.0, 0.1) var weather_transition_seconds: float = 1.4

var environment_node: WorldEnvironment
var sun: DirectionalLight3D
var fill_light: DirectionalLight3D
var shaft_root: Node3D
var dust_root: Node3D
var shaft_materials: Array[StandardMaterial3D] = []
var dust_systems: Array[GPUParticles3D] = []
var elapsed: float = 0.0
var sky_material: ProceduralSkyMaterial
var lighting_tween: Tween
var active_weather_id: String = ""
var weather_shaft_multiplier: float = 1.0
var weather_shaft_color: Color = Color(1.0, 0.52, 0.20, 1.0)


func _ready() -> void:
	add_to_group("cinematic_lighting")
	call_deferred("_install_profile")


func _process(delta: float) -> void:
	if not animate_atmosphere or shaft_materials.is_empty():
		return
	elapsed += delta
	for index: int in range(shaft_materials.size()):
		var pulse: float = 0.92 + sin(elapsed * (0.24 + float(index) * 0.035) + float(index) * 1.7) * 0.08
		shaft_materials[index].emission_energy_multiplier = (
			shaft_strength * pulse * weather_shaft_multiplier
		)


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
	_connect_weather_controllers()
	_sync_weather_lighting_from_world()


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

	sky_material = ProceduralSkyMaterial.new()
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
	material.emission = weather_shaft_color
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


func _connect_weather_controllers() -> void:
	for controller: Node in get_tree().get_nodes_in_group("weather_controller"):
		var started: Callable = Callable(self, "_on_weather_started")
		var stopped: Callable = Callable(self, "_on_weather_stopped")
		if controller.has_signal("weather_started") and not controller.is_connected("weather_started", started):
			controller.connect("weather_started", started)
		if controller.has_signal("weather_stopped") and not controller.is_connected("weather_stopped", stopped):
			controller.connect("weather_stopped", stopped)


func _on_weather_started(weather_id: String) -> void:
	set_weather_lighting(weather_id, true)


func _on_weather_stopped(_weather_id: String) -> void:
	active_weather_id = ""
	call_deferred("_sync_weather_lighting_from_world")


func _sync_weather_lighting_from_world() -> void:
	for controller: Node in get_tree().get_nodes_in_group("weather_controller"):
		if not bool(controller.get("active")):
			continue
		var definition: Variant = controller.get("weather_definition")
		if definition != null:
			set_weather_lighting(str(definition.get("effect_id")), false)
			return
	set_weather_lighting("", false)


func set_weather_lighting(weather_id: String, animate: bool = true) -> void:
	active_weather_id = weather_id
	match weather_id:
		"rain_weather":
			_apply_rain_lighting(animate)
		"snow_weather":
			_apply_snow_lighting(animate)
		_:
			_apply_clear_lighting(animate)


func _apply_clear_lighting(animate: bool) -> void:
	weather_shaft_multiplier = 1.0
	weather_shaft_color = Color(1.0, 0.52, 0.20, 1.0)
	_set_dust_for_weather(true)
	_transition_lighting(
		{
			"sky_top": Color(0.075, 0.13, 0.23, 1.0),
			"sky_horizon": Color(0.72, 0.49, 0.31, 1.0),
			"ground_horizon": Color(0.42, 0.34, 0.29, 1.0),
			"ambient_color": Color(0.46, 0.56, 0.72, 1.0),
			"ambient_energy": 0.58,
			"fog_color": Color(0.61, 0.60, 0.62, 1.0),
			"fog_energy": 0.62,
			"fog_density": 0.0035,
			"volumetric_density": 0.021,
			"volumetric_albedo": Color(0.88, 0.82, 0.74, 1.0),
			"volumetric_emission": Color(0.08, 0.095, 0.13, 1.0),
			"volumetric_anisotropy": 0.68,
			"glow_intensity": 0.72,
			"sun_color": Color(1.0, 0.69, 0.42, 1.0),
			"sun_energy": 1.42,
			"sun_fog_energy": 1.7,
			"fill_color": Color(0.33, 0.48, 0.78, 1.0),
			"fill_energy": 0.34,
			"accent_scale": 1.0,
			"shaft_albedo": Color(1.0, 0.71, 0.38, 0.026),
		},
		animate
	)


func _apply_rain_lighting(animate: bool) -> void:
	weather_shaft_multiplier = 0.12
	weather_shaft_color = Color(0.48, 0.66, 0.82, 1.0)
	_set_dust_for_weather(false)
	_transition_lighting(
		{
			"sky_top": Color(0.025, 0.045, 0.075, 1.0),
			"sky_horizon": Color(0.19, 0.27, 0.36, 1.0),
			"ground_horizon": Color(0.11, 0.15, 0.20, 1.0),
			"ambient_color": Color(0.30, 0.41, 0.56, 1.0),
			"ambient_energy": 0.48,
			"fog_color": Color(0.25, 0.33, 0.43, 1.0),
			"fog_energy": 0.48,
			"fog_density": 0.013,
			"volumetric_density": 0.036,
			"volumetric_albedo": Color(0.48, 0.58, 0.68, 1.0),
			"volumetric_emission": Color(0.025, 0.045, 0.075, 1.0),
			"volumetric_anisotropy": 0.24,
			"glow_intensity": 0.38,
			"sun_color": Color(0.56, 0.67, 0.80, 1.0),
			"sun_energy": 0.30,
			"sun_fog_energy": 0.38,
			"fill_color": Color(0.22, 0.38, 0.62, 1.0),
			"fill_energy": 0.48,
			"accent_scale": 0.68,
			"shaft_albedo": Color(0.48, 0.66, 0.82, 0.006),
		},
		animate
	)


func _apply_snow_lighting(animate: bool) -> void:
	weather_shaft_multiplier = 0.48
	weather_shaft_color = Color(0.76, 0.90, 1.0, 1.0)
	_set_dust_for_weather(false)
	_transition_lighting(
		{
			"sky_top": Color(0.18, 0.27, 0.39, 1.0),
			"sky_horizon": Color(0.68, 0.78, 0.88, 1.0),
			"ground_horizon": Color(0.39, 0.47, 0.57, 1.0),
			"ambient_color": Color(0.64, 0.76, 0.92, 1.0),
			"ambient_energy": 0.76,
			"fog_color": Color(0.72, 0.82, 0.94, 1.0),
			"fog_energy": 0.82,
			"fog_density": 0.019,
			"volumetric_density": 0.045,
			"volumetric_albedo": Color(0.80, 0.89, 0.98, 1.0),
			"volumetric_emission": Color(0.10, 0.15, 0.22, 1.0),
			"volumetric_anisotropy": 0.48,
			"glow_intensity": 0.82,
			"sun_color": Color(0.78, 0.88, 1.0, 1.0),
			"sun_energy": 0.64,
			"sun_fog_energy": 0.82,
			"fill_color": Color(0.44, 0.62, 0.90, 1.0),
			"fill_energy": 0.62,
			"accent_scale": 1.12,
			"shaft_albedo": Color(0.76, 0.90, 1.0, 0.016),
		},
		animate
	)


func _transition_lighting(state: Dictionary, animate: bool) -> void:
	if environment_node == null or environment_node.environment == null:
		return
	var environment: Environment = environment_node.environment
	environment.fog_enabled = true
	environment.volumetric_fog_enabled = quality != Quality.LOW

	if lighting_tween != null and lighting_tween.is_valid():
		lighting_tween.kill()

	var duration: float = weather_transition_seconds if animate else 0.0
	if duration <= 0.001:
		_apply_lighting_state_immediately(state)
		return

	lighting_tween = create_tween()
	lighting_tween.set_trans(Tween.TRANS_SINE)
	lighting_tween.set_ease(Tween.EASE_IN_OUT)
	_parallel_property(sky_material, "sky_top_color", state["sky_top"], duration)
	_parallel_property(sky_material, "sky_horizon_color", state["sky_horizon"], duration)
	_parallel_property(sky_material, "ground_horizon_color", state["ground_horizon"], duration)
	_parallel_property(environment, "ambient_light_color", state["ambient_color"], duration)
	_parallel_property(environment, "ambient_light_energy", state["ambient_energy"], duration)
	_parallel_property(environment, "fog_light_color", state["fog_color"], duration)
	_parallel_property(environment, "fog_light_energy", state["fog_energy"], duration)
	_parallel_property(environment, "fog_density", state["fog_density"], duration)
	_parallel_property(environment, "volumetric_fog_density", state["volumetric_density"], duration)
	_parallel_property(environment, "volumetric_fog_albedo", state["volumetric_albedo"], duration)
	_parallel_property(environment, "volumetric_fog_emission", state["volumetric_emission"], duration)
	_parallel_property(environment, "volumetric_fog_anisotropy", state["volumetric_anisotropy"], duration)
	_parallel_property(environment, "glow_intensity", state["glow_intensity"], duration)
	_parallel_property(sun, "light_color", state["sun_color"], duration)
	_parallel_property(sun, "light_energy", state["sun_energy"], duration)
	_parallel_property(sun, "light_volumetric_fog_energy", state["sun_fog_energy"], duration)
	_parallel_property(fill_light, "light_color", state["fill_color"], duration)
	_parallel_property(fill_light, "light_energy", state["fill_energy"], duration)
	_transition_accents(float(state["accent_scale"]), duration)
	for material: StandardMaterial3D in shaft_materials:
		_parallel_property(material, "albedo_color", state["shaft_albedo"], duration)
		_parallel_property(material, "emission", weather_shaft_color, duration)


func _parallel_property(target: Object, property_name: String, value: Variant, duration: float) -> void:
	if lighting_tween == null or target == null:
		return
	lighting_tween.parallel().tween_property(target, NodePath(property_name), value, duration)


func _apply_lighting_state_immediately(state: Dictionary) -> void:
	var environment: Environment = environment_node.environment
	sky_material.sky_top_color = state["sky_top"]
	sky_material.sky_horizon_color = state["sky_horizon"]
	sky_material.ground_horizon_color = state["ground_horizon"]
	environment.ambient_light_color = state["ambient_color"]
	environment.ambient_light_energy = state["ambient_energy"]
	environment.fog_light_color = state["fog_color"]
	environment.fog_light_energy = state["fog_energy"]
	environment.fog_density = state["fog_density"]
	environment.volumetric_fog_density = state["volumetric_density"]
	environment.volumetric_fog_albedo = state["volumetric_albedo"]
	environment.volumetric_fog_emission = state["volumetric_emission"]
	environment.volumetric_fog_anisotropy = state["volumetric_anisotropy"]
	environment.glow_intensity = state["glow_intensity"]
	sun.light_color = state["sun_color"]
	sun.light_energy = state["sun_energy"]
	sun.light_volumetric_fog_energy = state["sun_fog_energy"]
	fill_light.light_color = state["fill_color"]
	fill_light.light_energy = state["fill_energy"]
	_set_accent_scale(float(state["accent_scale"]))
	for material: StandardMaterial3D in shaft_materials:
		material.albedo_color = state["shaft_albedo"]
		material.emission = weather_shaft_color


func _transition_accents(scale_value: float, duration: float) -> void:
	for node_name: String in ["ChurchThresholdGlow", "MemoryTrailGlow", "RavineMoonFill"]:
		var light: OmniLight3D = get_node_or_null(node_name) as OmniLight3D
		if light == null:
			continue
		var base_energy: float = 1.5 if node_name == "ChurchThresholdGlow" else (0.72 if node_name == "MemoryTrailGlow" else 0.48)
		_parallel_property(light, "light_energy", base_energy * scale_value, duration)


func _set_accent_scale(scale_value: float) -> void:
	for node_name: String in ["ChurchThresholdGlow", "MemoryTrailGlow", "RavineMoonFill"]:
		var light: OmniLight3D = get_node_or_null(node_name) as OmniLight3D
		if light == null:
			continue
		var base_energy: float = 1.5 if node_name == "ChurchThresholdGlow" else (0.72 if node_name == "MemoryTrailGlow" else 0.48)
		light.light_energy = base_energy * scale_value


func _set_dust_for_weather(clear_weather: bool) -> void:
	if not clear_weather:
		for particles: GPUParticles3D in dust_systems:
			particles.emitting = false
		return
	var amount_value: int = 18 if quality == Quality.LOW else (42 if quality == Quality.BALANCED else 72)
	_set_dust_amount(amount_value)


func get_debug_data() -> Dictionary:
	return {
		"profile": profile,
		"quality": quality,
		"shafts": shaft_materials.size(),
		"dust_volumes": dust_systems.size(),
		"volumetric_fog": environment_node != null
			and environment_node.environment != null
			and environment_node.environment.volumetric_fog_enabled,
		"weather": active_weather_id if active_weather_id != "" else "clear",
	}
