extends Node

const LightProfile: AirbornePresentationProfile = preload("res://data/combat/airborne_presentation_light.tres")
const MediumProfile: AirbornePresentationProfile = preload("res://data/combat/airborne_presentation_medium.tres")
const HeavyProfile: AirbornePresentationProfile = preload("res://data/combat/airborne_presentation_heavy.tres")
const AirborneReactionControllerScript = preload("res://scripts/combat/airborne_reaction_controller.gd")
const AirbornePresentationControllerScript = preload("res://scripts/visuals/airborne_presentation_controller.gd")


func _ready() -> void:
	assert(LightProfile.spin_degrees_per_second.length() > MediumProfile.spin_degrees_per_second.length())
	assert(MediumProfile.spin_degrees_per_second.length() > HeavyProfile.spin_degrees_per_second.length())
	assert(LightProfile.bounce_height_multiplier > MediumProfile.bounce_height_multiplier)
	assert(MediumProfile.bounce_height_multiplier > HeavyProfile.bounce_height_multiplier)
	assert(LightProfile.landing_recover_time < HeavyProfile.landing_recover_time)

	var actor := CharacterBody3D.new()
	actor.name = "AirbornePresentationContractActor"
	var visual_root := Node3D.new()
	visual_root.name = "VisualRoot"
	actor.add_child(visual_root)
	var reaction_controller := AirborneReactionControllerScript.new()
	reaction_controller.name = "AirborneReactionController"
	actor.add_child(reaction_controller)
	var presentation_controller := AirbornePresentationControllerScript.new()
	presentation_controller.name = "AirbornePresentationController"
	presentation_controller.profile = LightProfile
	actor.add_child(presentation_controller)
	add_child(actor)

	await get_tree().process_frame
	await get_tree().process_frame
	reaction_controller.set_physics_process(false)

	var initial_rotation: Vector3 = visual_root.rotation
	reaction_controller.set_air_state(reaction_controller.AirState.LAUNCHED, 0.2)
	presentation_controller._process(0.1)
	assert(presentation_controller.presentation_state == "launched")
	assert(visual_root.rotation.distance_to(initial_rotation) > 0.001)

	reaction_controller.plunge_started.emit()
	presentation_controller._process(0.05)
	assert(presentation_controller.presentation_state == "plunge")

	reaction_controller.ground_bounced.emit(1)
	assert(presentation_controller.presentation_state == "bounce")
	await get_tree().create_timer(LightProfile.bounce_pose_time + 0.08).timeout
	assert(presentation_controller.presentation_state == "launched")

	reaction_controller.landed.emit(0.1)
	assert(presentation_controller.presentation_state == "landing")
	await get_tree().create_timer(LightProfile.landing_recover_time + 0.08).timeout
	assert(presentation_controller.presentation_state == "grounded")
	assert(visual_root.scale.distance_to(Vector3.ONE) < 0.01)

	actor.queue_free()
	print("AIRBORNE_PRESENTATION_SMOKE_TEST: PASS")
	get_tree().quit()
