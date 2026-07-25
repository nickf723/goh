extends Node

const GoblinVisualScene: PackedScene = preload("res://scenes/actors/enemies/goblin_visual_v1.tscn")
const GremlinVisualScene: PackedScene = preload("res://scenes/actors/enemies/gremlin_visual_v1.tscn")

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	await test_profile(GoblinVisualScene, "goblin", 9)
	await test_profile(GremlinVisualScene, "gremlin", 11)

	if failures.is_empty():
		print("ENEMY_ANIMATION_PRESENTATION_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return

	for failure: String in failures:
		push_error("ENEMY_ANIMATION_PRESENTATION_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func test_profile(
	scene: PackedScene,
	expected_profile: String,
	minimum_pivots: int
) -> void:
	var actor: CharacterBody3D = CharacterBody3D.new()
	actor.name = expected_profile.capitalize() + "AnimationTestActor"
	add_child(actor)

	var visual: EnemyVisualShell = scene.instantiate() as EnemyVisualShell
	actor.add_child(visual)
	await get_tree().process_frame

	assert_true(visual != null, expected_profile + " visual instantiates")
	if visual == null:
		actor.queue_free()
		return

	assert_equal(visual.profile, expected_profile, expected_profile + " profile is authored")
	assert_true(
		visual.get_node_or_null("PoseRoot/BodyPivot") != null,
		expected_profile + " body pivot exists"
	)
	assert_true(
		visual.get_node_or_null("PoseRoot/HeadPivot") != null,
		expected_profile + " head pivot exists"
	)
	assert_true(
		visual.get_node_or_null("PoseRoot/LeftArmPivot") != null,
		expected_profile + " left arm pivot exists"
	)
	assert_true(
		visual.get_node_or_null("PoseRoot/RightArmPivot") != null,
		expected_profile + " right arm pivot exists"
	)
	assert_true(
		visual.get_node_or_null("HeadAnchor") != null,
		expected_profile + " stable head anchor remains"
	)

	visual.start_windup()
	assert_equal(
		str(visual.get_animation_debug_data().get("presentation_state", "")),
		"windup",
		expected_profile + " resolves windup pose"
	)

	visual.start_active()
	assert_equal(
		str(visual.get_animation_debug_data().get("presentation_state", "")),
		"active",
		expected_profile + " resolves active strike pose"
	)

	visual.start_hit_reaction()
	assert_equal(
		str(visual.get_animation_debug_data().get("presentation_state", "")),
		"hit",
		expected_profile + " resolves hit pose"
	)

	visual.start_stagger()
	assert_equal(
		str(visual.get_animation_debug_data().get("presentation_state", "")),
		"stagger",
		expected_profile + " resolves stagger pose"
	)

	visual.start_defeat()
	var debug_data: Dictionary = visual.get_animation_debug_data()
	assert_equal(
		str(debug_data.get("presentation_state", "")),
		"defeated",
		expected_profile + " resolves defeat pose"
	)
	assert_true(
		int(debug_data.get("articulated_pivots", 0)) >= minimum_pivots,
		expected_profile + " exposes the expected articulated rig"
	)

	actor.queue_free()


func assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures.append(label + ": expected " + str(expected) + " but got " + str(actual))


func assert_true(value: bool, label: String) -> void:
	if not value:
		failures.append(label + ": expected true")
