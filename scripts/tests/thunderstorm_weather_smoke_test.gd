extends Node

const ThunderstormControllerScript = preload("res://scripts/weather/thunderstorm_weather_controller.gd")
const StormAttractorScript = preload("res://scripts/weather/storm_lightning_attractor.gd")
const LightningRendererScript = preload("res://scripts/presentation/lightning_arc_renderer.gd")


func _ready() -> void:
	var world_root := Node3D.new()
	world_root.name = "ThunderstormSmokeWorld"
	add_child(world_root)

	var renderer := Node3D.new()
	renderer.name = "LightningArcRenderer"
	renderer.set_script(LightningRendererScript)
	world_root.add_child(renderer)
	renderer.add_to_group("lightning_arc_renderer")

	var player := Node3D.new()
	player.name = "Player"
	player.add_to_group("player")
	player.position = Vector3(0, 1, 8)
	world_root.add_child(player)

	var primary := Node3D.new()
	primary.name = "WetCopperRod"
	primary.set_script(StormAttractorScript)
	primary.set("starts_wet", true)
	primary.position = Vector3.ZERO
	world_root.add_child(primary)

	var secondary := Node3D.new()
	secondary.name = "ChainRod"
	secondary.set_script(StormAttractorScript)
	secondary.position = Vector3(5, 0, 0)
	world_root.add_child(secondary)

	var controller := Node3D.new()
	controller.name = "ThunderstormWeatherController"
	controller.set_script(ThunderstormControllerScript)
	controller.set("player", player)
	world_root.add_child(controller)

	await get_tree().process_frame
	await get_tree().process_frame

	var affected: int = int(controller.call(
		"force_storm_strike",
		primary.call("get_lightning_target_position"),
		primary
	))
	var debug: Dictionary = controller.call("get_debug_data")
	assert(affected >= 2)
	assert(int(debug.get("strike_count", 0)) == 1)
	assert(int(debug.get("chain_count", 0)) >= 1)
	assert(int(primary.get("strike_count")) == 1)
	assert(int(secondary.get("strike_count")) >= 1)
	assert(int(renderer.get("rendered_count")) >= 2)

	print("ThunderstormWeatherSmokeTest: PASS")
	get_tree().quit()
