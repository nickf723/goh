extends Node

const LightingRigScript = preload("res://scripts/visuals/cinematic_lighting_rig_3d.gd")


func _ready() -> void:
	var scene_root: Node3D = Node3D.new()
	scene_root.name = "LightingSmokeTestRoot"
	add_child(scene_root)

	var environment_node: WorldEnvironment = WorldEnvironment.new()
	environment_node.name = "VillageEnvironment"
	environment_node.environment = Environment.new()
	scene_root.add_child(environment_node)

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "LateAfternoonSun"
	scene_root.add_child(sun)

	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.name = "SkyFill"
	scene_root.add_child(fill)

	var rig: Node3D = Node3D.new()
	rig.name = "CinematicLighting"
	rig.set_script(LightingRigScript)
	rig.set("profile", "ruined_village")
	rig.set("quality", 2)
	scene_root.add_child(rig)

	await get_tree().process_frame
	await get_tree().process_frame

	assert(environment_node.environment.volumetric_fog_enabled)
	assert(environment_node.environment.glow_enabled)
	assert(environment_node.environment.ssao_enabled)
	assert(sun.shadow_enabled)
	assert(rig.get_node_or_null("LightShafts") != null)
	assert(rig.get_node("LightShafts").get_child_count() == 6)
	assert(rig.get_node_or_null("AtmosphericDust") != null)
	assert(rig.get_node("AtmosphericDust").get_child_count() == 3)

	rig.call("set_quality", 0)
	assert(not environment_node.environment.volumetric_fog_enabled)
	assert(not environment_node.environment.ssao_enabled)

	rig.call("set_quality", 2)
	assert(environment_node.environment.volumetric_fog_enabled)
	assert(environment_node.environment.ssao_enabled)

	rig.call("set_weather_lighting", "rain_weather", false)
	assert(is_equal_approx(sun.light_energy, 0.30))
	assert(is_equal_approx(environment_node.environment.fog_density, 0.013))
	assert(rig.call("get_debug_data").get("weather") == "rain_weather")

	rig.call("set_weather_lighting", "snow_weather", false)
	assert(is_equal_approx(sun.light_energy, 0.64))
	assert(is_equal_approx(environment_node.environment.fog_density, 0.019))
	assert(rig.call("get_debug_data").get("weather") == "snow_weather")

	rig.call("set_weather_lighting", "thunderstorm_weather", false)
	assert(is_equal_approx(sun.light_energy, 0.10))
	assert(is_equal_approx(environment_node.environment.fog_density, 0.020))
	assert(rig.call("get_debug_data").get("weather") == "thunderstorm_weather")
	rig.call("flash_lightning", 1.0, Vector3.ZERO)
	assert(int(rig.call("get_debug_data").get("lightning_flashes", 0)) == 1)

	rig.call("set_weather_lighting", "", false)
	assert(is_equal_approx(sun.light_energy, 1.42))
	assert(is_equal_approx(environment_node.environment.fog_density, 0.0035))
	assert(rig.call("get_debug_data").get("weather") == "clear")

	print("CinematicLightingSmokeTest: PASS")
	get_tree().quit()
