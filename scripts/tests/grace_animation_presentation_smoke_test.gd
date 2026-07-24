extends Node

const GraceVisualScene: PackedScene = preload("res://scenes/actors/player/grace_visual_v1.tscn")

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	var actor: CharacterBody3D = CharacterBody3D.new()
	actor.name = "AnimationTestActor"
	add_child(actor)

	var action_state: PlayerActionState = PlayerActionState.new()
	action_state.name = "PlayerActionState"
	actor.add_child(action_state)

	var visual: StylizedActorVisual = GraceVisualScene.instantiate() as StylizedActorVisual
	actor.add_child(visual)
	await get_tree().process_frame

	assert_true(visual != null, "Grace visual instantiates")
	if visual != null:
		assert_true(visual.get_node_or_null("VisualRoot/BodyRoot") != null, "body articulation pivot exists")
		assert_true(visual.get_node_or_null("VisualRoot/HeadRoot") != null, "head articulation pivot exists")
		assert_true(visual.get_node_or_null("VisualRoot/LeftShoulderPivot") != null, "left shoulder pivot exists")
		assert_true(visual.get_node_or_null("VisualRoot/RightShoulderPivot") != null, "right shoulder pivot exists")
		assert_true(visual.get_node_or_null("VisualRoot/LeftLegPivot") != null, "left leg pivot exists")
		assert_true(visual.get_node_or_null("VisualRoot/RightLegPivot") != null, "right leg pivot exists")
		assert_true(visual.get_node_or_null("HeadAnchor") != null, "stable head anchor path remains")
		assert_true(visual.get_node_or_null("LeftHandAnchor") != null, "stable left-hand anchor path remains")
		assert_true(visual.get_node_or_null("RightHandAnchor") != null, "stable right-hand anchor path remains")

		action_state.is_guarding = true
		visual.sample_animation_pose(0.1)
		assert_equal(
			str(visual.get_animation_debug_data().get("presentation_state", "")),
			"guard",
			"guard action resolves guard pose"
		)

		action_state.is_guarding = false
		action_state.is_casting = true
		visual.sample_animation_pose(0.1)
		assert_equal(
			str(visual.get_animation_debug_data().get("presentation_state", "")),
			"cast",
			"cast action resolves cast pose"
		)

		action_state.is_casting = false
		action_state.is_staggered = true
		visual.sample_animation_pose(0.1)
		assert_equal(
			str(visual.get_animation_debug_data().get("presentation_state", "")),
			"hit",
			"stagger resolves hit-reaction pose"
		)

		action_state.is_staggered = false
		action_state.is_defeated = true
		visual.sample_animation_pose(0.1)
		var debug_data: Dictionary = visual.get_animation_debug_data()
		assert_equal(
			str(debug_data.get("presentation_state", "")),
			"defeated",
			"defeat resolves defeated pose"
		)
		assert_true(
			int(debug_data.get("articulated_pivots", 0)) >= 10,
			"presentation controller owns the articulated rig"
		)

	actor.queue_free()

	if failures.is_empty():
		print("GRACE_ANIMATION_PRESENTATION_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return

	for failure: String in failures:
		push_error("GRACE_ANIMATION_PRESENTATION_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures.append(label + ": expected " + str(expected) + " but got " + str(actual))


func assert_true(value: bool, label: String) -> void:
	if not value:
		failures.append(label + ": expected true")
