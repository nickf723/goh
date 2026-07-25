extends Node

const PlayerScene: PackedScene = preload("res://scenes/actors/player/player.tscn")

const EXPECTED_STATES: Array[String] = [
	"idle", "locomotion", "jump", "fall", "landing", "swim_surface", "swim_underwater", "climb", "mantle",
	"attack", "guard", "dodge", "hit", "cast", "flight", "exhausted", "defeated",
]


func _ready() -> void:
	var player := PlayerScene.instantiate() as CharacterBody3D
	add_child(player)
	await get_tree().process_frame
	var visual := player.get_node_or_null("GraceVisualV1") as StylizedActorVisual
	var feedback := player.get_node_or_null("PlayerMotionFeedback") as PlayerMotionFeedback
	var climbing := player.get_node_or_null("ClimbingController") as PlayerClimbingController
	assert(visual != null)
	assert(feedback != null)
	assert(climbing != null)
	assert(visual.get_pose_nodes().size() >= 15)
	assert(visual.left_eye != null and visual.right_eye != null)
	assert(visual.left_brow != null and visual.right_brow != null)

	for state_name: String in EXPECTED_STATES:
		visual.set_debug_forced_state(state_name)
		visual.sample_animation_pose(0.016)
		assert(visual.presentation_state == state_name)

	visual.clear_debug_forced_state()
	climbing.climbing = true
	visual.sample_animation_pose(0.016)
	assert(visual.presentation_state == "climb")
	climbing.climbing = false
	climbing.mantling = true
	climbing.mantle_remaining = climbing.mantle_duration * 0.5
	visual.sample_animation_pose(0.016)
	assert(visual.presentation_state == "mantle")
	assert(visual.get_mantle_progress() > 0.0)
	climbing.mantling = false

	var debug_data: Dictionary = visual.get_animation_debug_data()
	assert(debug_data.has("acceleration"))
	assert(debug_data.has("turn_velocity"))
	assert(debug_data.has("state_elapsed"))
	assert(feedback.get_debug_data().has("live_effects"))

	print("GraceAnimationSmokeTest: PASS")
	get_tree().quit()
