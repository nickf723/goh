extends Node

const GreenScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_green_grotto_art_target_v1.tscn"
)

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	var target: Node = GreenScene.instantiate()
	add_child(target)
	for _index: int in range(5):
		await get_tree().process_frame

	var polish: GraceLocomotionPolish = target.get_node_or_null(
		"GraceLocomotionPolish"
	) as GraceLocomotionPolish
	var lighting: LightingDirector3D = target.get_node_or_null(
		"LightingDirector"
	) as LightingDirector3D
	var player: CharacterBody3D = target.get_node_or_null(
		"Player"
	) as CharacterBody3D
	var visual: StylizedActorVisual = target.get_node_or_null(
		"Player/GraceVisualV1"
	) as StylizedActorVisual
	_expect(polish != null, "Green installs GraceLocomotionPolish")
	_expect(lighting != null, "locomotion polish test resolves LightingDirector")
	_expect(player != null and visual != null, "locomotion polish test resolves Grace visual")
	if polish != null and lighting != null and player != null and visual != null:
		polish.set_process(false)
		polish.call("_remove_previous_offsets")
		_validate_contract(polish)
		await _validate_quality_ladder(polish, lighting, visual)
		_validate_action_state_exclusion(polish, visual)

	target.queue_free()
	await get_tree().process_frame
	_finish()


func _validate_contract(polish: GraceLocomotionPolish) -> void:
	var data: Dictionary = polish.get_debug_data()
	_expect(bool(data.get("grace_locomotion_polish", false)), "locomotion polish publishes debug contract")
	_expect(bool(data.get("initialized", false)), "locomotion polish resolves Grace")
	_expect(bool(data.get("additive_after_base_pose", false)), "polish declares additive-after-base ownership")
	_expect(bool(data.get("grounded_states_only", false)), "polish declares grounded-state scope")
	_expect(not bool(data.get("combat_pose_authority", true)), "polish owns no combat pose authority")
	_expect(not bool(data.get("gameplay_authority", true)), "polish owns no gameplay authority")


func _validate_quality_ladder(
	polish: GraceLocomotionPolish,
	lighting: LightingDirector3D,
	visual: StylizedActorVisual
) -> void:
	var body: Node3D = visual.get_node_or_null("VisualRoot/BodyRoot") as Node3D
	var head: Node3D = visual.get_node_or_null("VisualRoot/HeadRoot") as Node3D
	var left_leg: Node3D = visual.get_node_or_null("VisualRoot/LeftLegPivot") as Node3D
	var right_leg: Node3D = visual.get_node_or_null("VisualRoot/RightLegPivot") as Node3D
	_expect(body != null and head != null and left_leg != null and right_leg != null, "polish test resolves pose nodes")
	if body == null or head == null or left_leg == null or right_leg == null:
		return

	visual.presentation_state = "locomotion"
	visual.movement_weight = 1.0
	visual.stride_phase = 0.0
	visual.turn_velocity = 1.25
	visual.smoothed_acceleration = Vector3(0.0, 0.0, 4.0)

	var base_body_position: Vector3 = body.position
	var base_body_rotation: Vector3 = body.rotation
	var base_head_rotation: Vector3 = head.rotation
	var base_left_position: Vector3 = left_leg.position
	var base_right_position: Vector3 = right_leg.position

	lighting.set_quality(LightingDirector3D.Quality.PERFORMANCE)
	polish.call("_apply_after_base_pose")
	_expect(body.position.is_equal_approx(base_body_position), "Performance leaves body position untouched")
	_expect(body.rotation.is_equal_approx(base_body_rotation), "Performance leaves body rotation untouched")
	_expect(left_leg.position.is_equal_approx(base_left_position), "Performance leaves left leg untouched")
	polish.call("_remove_previous_offsets")

	lighting.set_quality(LightingDirector3D.Quality.BALANCED)
	polish.call("_apply_after_base_pose")
	var balanced_shift: float = absf(body.position.x - base_body_position.x)
	var balanced_turn: float = absf(body.rotation.y - base_body_rotation.y)
	_expect(balanced_shift > 0.005, "Balanced adds visible planted-leg weight transfer")
	_expect(balanced_turn > 0.01, "Balanced adds torso turn anticipation")
	_expect(absf(left_leg.position.y - base_left_position.y) > 0.001, "Balanced adjusts planted left leg height")
	_expect(absf(right_leg.position.y - base_right_position.y) > 0.001, "Balanced lifts swing right leg")
	_expect(absf(head.rotation.y - base_head_rotation.y) > balanced_turn, "head anticipates turn more strongly than torso")
	polish.call("_remove_previous_offsets")
	_expect(body.position.is_equal_approx(base_body_position), "removing Balanced polish restores exact body position")
	_expect(body.rotation.is_equal_approx(base_body_rotation), "removing Balanced polish restores exact body rotation")
	_expect(left_leg.position.is_equal_approx(base_left_position), "removing Balanced polish restores exact left leg position")
	_expect(right_leg.position.is_equal_approx(base_right_position), "removing Balanced polish restores exact right leg position")

	lighting.set_quality(LightingDirector3D.Quality.CINEMATIC)
	polish.call("_apply_after_base_pose")
	var cinematic_shift: float = absf(body.position.x - base_body_position.x)
	var cinematic_turn: float = absf(body.rotation.y - base_body_rotation.y)
	_expect(cinematic_shift > balanced_shift, "Cinematic increases stance weight transfer over Balanced")
	_expect(cinematic_turn > balanced_turn, "Cinematic increases turn anticipation over Balanced")
	var data: Dictionary = polish.get_debug_data()
	_expect(float(data.get("quality_scale", 0.0)) > 0.99, "Cinematic publishes full polish scale")
	_expect(absf(float(data.get("left_stance", 0.0)) + float(data.get("right_stance", 0.0)) - 1.0) < 0.01, "left/right stance weights remain complementary")
	polish.call("_remove_previous_offsets")


func _validate_action_state_exclusion(
	polish: GraceLocomotionPolish,
	visual: StylizedActorVisual
) -> void:
	var body: Node3D = visual.get_node_or_null("VisualRoot/BodyRoot") as Node3D
	if body == null:
		return
	var before_position: Vector3 = body.position
	var before_rotation: Vector3 = body.rotation
	visual.presentation_state = "attack"
	polish.call("_apply_after_base_pose")
	_expect(body.position.is_equal_approx(before_position), "attack state rejects locomotion position polish")
	_expect(body.rotation.is_equal_approx(before_rotation), "attack state rejects locomotion rotation polish")
	polish.call("_remove_previous_offsets")


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("GRACE_LOCOMOTION_POLISH_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("GRACE_LOCOMOTION_POLISH_SMOKE_TEST: " + failure)
	get_tree().quit(1)
