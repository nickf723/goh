extends Node

const PlayerScene: PackedScene = preload("res://scenes/actors/player/player.tscn")


func _ready() -> void:
	var player := PlayerScene.instantiate() as CharacterBody3D
	add_child(player)
	var volume := SwimmingWaterVolume.new()
	volume.position = Vector3(0, -4, 0)
	volume.surface_height_offset = 4.0
	volume.current_velocity = Vector3(2.0, 0.0, -1.0)
	volume.swirl_strength = 1.0
	add_child(volume)
	await get_tree().process_frame

	var swimming := player.get_node_or_null("SwimmingController") as PlayerSwimmingController
	var visual := player.get_node_or_null("GraceVisualV1") as StylizedActorVisual
	assert(swimming != null)
	assert(visual != null)
	swimming.enter_water(volume)
	assert(swimming.swimming)
	assert(swimming.should_handle_locomotion())
	assert(is_equal_approx(swimming.get_surface_y(), 0.0))
	assert(swimming.sample_total_current().length() > 0.0)

	swimming.underwater = false
	visual.sample_animation_pose(0.016)
	assert(visual.presentation_state == "swim_surface")
	swimming.underwater = true
	visual.sample_animation_pose(0.016)
	assert(visual.presentation_state == "swim_underwater")

	swimming.breath_seconds = 1.0
	swimming._update_breath(0.25)
	assert(swimming.breath_seconds < 1.0)
	swimming.breath_seconds = 0.05
	swimming._update_breath(0.1)
	assert(swimming.exhausted)

	swimming.exit_water(volume)
	assert(not swimming.swimming)
	assert(not swimming.should_handle_locomotion())
	assert(swimming.wetness_remaining > 0.0)

	var debug_data: Dictionary = swimming.get_debug_data()
	assert(debug_data.has("breath"))
	assert(debug_data.has("current"))
	assert(debug_data.has("wetness"))

	print("SwimmingSmokeTest: PASS")
	get_tree().quit()
