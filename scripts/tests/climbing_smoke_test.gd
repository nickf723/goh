extends Node

const PlayerScene: PackedScene = preload("res://scenes/actors/player/player.tscn")


func _ready() -> void:
	var player := PlayerScene.instantiate() as CharacterBody3D
	add_child(player)
	await get_tree().process_frame
	var climbing := player.get_node_or_null("ClimbingController") as PlayerClimbingController
	assert(climbing != null)
	assert(not climbing.should_handle_locomotion())

	var stone := Node.new()
	stone.set_meta("climb_surface", "stone")
	var wood := Node.new()
	wood.set_meta("climb_surface", "wood")
	var metal := Node.new()
	metal.set_meta("climb_surface", "metal")
	var wet := Node.new()
	wet.set_meta("climb_surface", "wet")
	var ice := Node.new()
	ice.set_meta("climb_surface", "ice")

	var stone_profile: Dictionary = climbing._get_surface_profile(stone)
	var wood_profile: Dictionary = climbing._get_surface_profile(wood)
	var metal_profile: Dictionary = climbing._get_surface_profile(metal)
	var wet_profile: Dictionary = climbing._get_surface_profile(wet)
	var ice_profile: Dictionary = climbing._get_surface_profile(ice)
	assert(bool(stone_profile.get("climbable", false)))
	assert(float(wood_profile.get("drain", 99.0)) < float(stone_profile.get("drain", 0.0)))
	assert(float(metal_profile.get("drain", 0.0)) > float(stone_profile.get("drain", 0.0)))
	assert(float(wet_profile.get("slide", 0.0)) > 0.0)
	assert(not bool(ice_profile.get("climbable", true)))

	GameState.set_stat("max_stamina", 20)
	GameState.set_stat("stamina", 10)
	climbing.surface_drain_multiplier = 1.0
	climbing.stamina_drain_progress = 0.95
	climbing._update_stamina(0.1, 1.0)
	assert(GameState.get_stat("stamina") == 9)

	climbing.climbing = true
	assert(climbing.should_handle_locomotion())
	climbing.reset_climbing()
	assert(not climbing.should_handle_locomotion())

	print("ClimbingSmokeTest: PASS")
	get_tree().quit()
