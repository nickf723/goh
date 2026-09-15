extends "res://scripts/visuals/cinematic_lighting_rig_3d.gd"

## Starting-region daylight. Weather continues through the shared lighting rig.
func _apply_clear_lighting(animate: bool) -> void:
	weather_shaft_multiplier = 0.12
	weather_shaft_color = Color(1.0, 0.88, 0.64)
	_set_dust_for_weather(true)
	_transition_lighting({
		"sky_top": Color(0.19, 0.39, 0.65),
		"sky_horizon": Color(0.70, 0.79, 0.83),
		"ground_horizon": Color(0.42, 0.47, 0.37),
		"ambient_color": Color(0.65, 0.74, 0.84), "ambient_energy": 0.65,
		"fog_color": Color(0.65, 0.74, 0.79), "fog_energy": 0.7,
		"fog_density": 0.0015, "volumetric_density": 0.002,
		"volumetric_albedo": Color(0.84, 0.86, 0.80),
		"volumetric_emission": Color(0.025, 0.035, 0.045),
		"volumetric_anisotropy": 0.3, "glow_intensity": 0.22,
		"sun_color": Color(1.0, 0.91, 0.74), "sun_energy": 1.35,
		"sun_fog_energy": 0.35,
		"fill_color": Color(0.55, 0.67, 0.84), "fill_energy": 0.25,
		"accent_scale": 0.4, "shaft_albedo": Color(1.0, 0.87, 0.65, 0.002),
	}, animate)

func _configure_environment() -> void:
	super._configure_environment()
	environment_node.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment.tonemap_exposure = 1.0
	environment_node.environment.glow_bloom = 0.0
	environment_node.environment.fog_height_density = 0.0

func _configure_directional_lights() -> void:
	super._configure_directional_lights()
	sun.rotation_degrees = Vector3(-48, -32, 0)
