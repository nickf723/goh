extends Node

const GraceVerticalProfile: VerticalMotionProfile = preload(
	"res://data/player/grace_vertical_motion_profile.tres"
)
const PlayerScene: PackedScene = preload("res://scenes/actors/player/player.tscn")


func _ready() -> void:
	for profile_error: String in GraceVerticalProfile.validate_profile():
		assert(false, profile_error)
	assert(GraceVerticalProfile.get_gravity_scale(3.0) > GraceVerticalProfile.get_gravity_scale(0.1))
	assert(GraceVerticalProfile.get_gravity_scale(-3.0) > GraceVerticalProfile.get_gravity_scale(0.1))
	assert(GraceVerticalProfile.classify_landing(3.0) == "light")
	assert(GraceVerticalProfile.classify_landing(6.0) == "firm")
	assert(GraceVerticalProfile.classify_landing(10.0) == "hard")

	var actor: CharacterBody3D = CharacterBody3D.new()
	actor.name = "VerticalMotionActor"
	var action_state: PlayerActionState = PlayerActionState.new()
	action_state.name = "PlayerActionState"
	actor.add_child(action_state)
	var vertical: PlayerVerticalMotionController = PlayerVerticalMotionController.new()
	vertical.name = "VerticalMotionController"
	vertical.profile = GraceVerticalProfile
	actor.add_child(vertical)
	add_child(actor)
	await get_tree().process_frame

	assert(vertical.actor == actor)
	assert(vertical.action_state == action_state)
	assert(vertical.is_in_group("player_vertical_motion_controller"))

	vertical.prepare_frame(1.0 / 60.0, true, false)
	vertical.queue_jump_request()
	assert(vertical.try_consume_ground_jump(4.5))
	assert(is_equal_approx(actor.velocity.y, 4.5))
	assert(vertical.vertical_state == "launch")
	assert(vertical.last_jump_kind == "jump")
	assert(not vertical.has_buffered_jump_request())

	vertical.launch_remaining = 0.0
	vertical.apply_gravity(1.0 / 60.0, 18.0)
	assert(vertical.vertical_state == "rising")
	assert(is_equal_approx(vertical.last_gravity_scale, GraceVerticalProfile.rising_gravity_scale))

	actor.velocity.y = 0.2
	vertical.prepare_frame(1.0 / 60.0, false, false)
	vertical.apply_gravity(1.0 / 60.0, 18.0)
	assert(vertical.vertical_state == "apex")
	assert(is_equal_approx(vertical.last_gravity_scale, GraceVerticalProfile.apex_gravity_scale))

	actor.velocity.y = -3.0
	vertical.prepare_frame(1.0 / 60.0, false, false)
	vertical.apply_gravity(1.0 / 60.0, 18.0)
	assert(vertical.vertical_state == "falling")
	assert(is_equal_approx(vertical.last_gravity_scale, GraceVerticalProfile.falling_gravity_scale))

	actor.velocity.y = -40.0
	vertical.apply_gravity(1.0 / 60.0, 18.0)
	assert(actor.velocity.y >= -GraceVerticalProfile.terminal_fall_speed)

	# A ledge departure has no authored jump apex. Near-zero airborne velocity should
	# enter a fall immediately so coyote time remains forgiving without adding float.
	vertical.reset_motion()
	actor.velocity.y = 0.0
	vertical.prepare_frame(1.0 / 60.0, false, false)
	assert(vertical.vertical_state == "falling")

	vertical.reset_motion()
	assert(vertical.begin_debug_jump(4.5))
	vertical.jump_hold_elapsed = GraceVerticalProfile.minimum_hold_seconds
	var full_jump_velocity: float = actor.velocity.y
	assert(vertical.apply_jump_release(true))
	assert(actor.velocity.y < full_jump_velocity)
	assert(vertical.jump_cut_applied)
	assert(
		is_equal_approx(
			actor.velocity.y,
			full_jump_velocity * GraceVerticalProfile.jump_release_velocity_multiplier
		)
	)

	vertical.reset_motion()
	vertical.prepare_frame(0.0, true, false)
	vertical.prepare_frame(0.05, false, false)
	assert(vertical.coyote_remaining > 0.0)
	vertical.queue_jump_request()
	assert(vertical.try_consume_ground_jump(4.5, "coyote_jump"))
	assert(vertical.last_jump_kind == "coyote_jump")

	vertical.reset_motion()
	vertical.prepare_frame(GraceVerticalProfile.coyote_seconds + 0.02, false, false)
	vertical.queue_jump_request()
	assert(not vertical.try_consume_ground_jump(4.5))
	assert(vertical.has_buffered_jump_request())
	vertical.prepare_frame(0.01, true, false)
	assert(vertical.try_consume_ground_jump(4.5, "buffered_landing_jump"))
	assert(vertical.last_jump_kind == "buffered_landing_jump")

	vertical.reset_motion()
	vertical._register_landing(10.0)
	assert(vertical.last_landing_kind == "hard")
	assert(vertical.last_landing_strength > 0.8)
	assert(vertical.vertical_state == "landing")
	assert(vertical.get_landing_wave() >= 0.0)
	assert(vertical.get_debug_data().has("jump_buffer"))
	assert(vertical.get_debug_data().has("gravity_scale"))
	assert(vertical.get_debug_data().has("landing_strength"))

	var floor: StaticBody3D = _make_floor()
	add_child(floor)
	var player: CharacterBody3D = PlayerScene.instantiate() as CharacterBody3D
	player.name = "SharedVerticalPlayer"
	player.position = Vector3(0.0, 0.96, 0.0)
	add_child(player)
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame

	var shared_vertical: PlayerVerticalMotionController = (
		player.get_node_or_null("VerticalMotionController") as PlayerVerticalMotionController
	)
	var shared_aerial: PlayerAerialLocomotionVertical = (
		player.get_node_or_null("AerialLocomotion") as PlayerAerialLocomotionVertical
	)
	var visual: GraceVerticalMotionVisual = (
		player.get_node_or_null("GraceVisualV1") as GraceVerticalMotionVisual
	)
	var wire: GraceWireSkeletonRenderer = (
		player.get_node_or_null("GraceVisualV1/WireSkeletonRenderer") as GraceWireSkeletonRenderer
	)
	var feedback: PlayerMotionFeedback = (
		player.get_node_or_null("PlayerMotionFeedback") as PlayerMotionFeedback
	)
	assert(player.is_on_floor())
	assert(shared_vertical != null)
	assert(shared_vertical.profile == GraceVerticalProfile)
	assert(shared_aerial != null)
	assert(shared_aerial.is_in_group("player_aerial_vertical_integration"))
	assert(visual != null)
	assert(visual.is_in_group("grace_vertical_motion_visual"))
	assert(wire != null)
	assert(feedback != null)

	player.set_physics_process(false)
	visual.set_process(false)
	wire.set_process(false)
	shared_vertical.queue_jump_request()
	player.call("_process_standard_motion", 1.0 / 60.0)
	assert(player.velocity.y > 0.0)
	assert(not player.is_on_floor())
	assert(shared_vertical.vertical_state in ["launch", "rising"])
	visual.sample_animation_pose(1.0)
	wire.sample_now(1.0)
	assert(visual.presentation_state == "jump")
	assert(wire.has_finite_pose())
	var launch_debug: Dictionary = visual.get_animation_debug_data()
	assert(str(launch_debug.get("vertical_motion_state", "")) in ["launch", "rising"])
	assert(float(launch_debug.get("vertical_velocity", 0.0)) > 0.0)
	assert(bool(launch_debug.get("vertical_visual_override", false)))

	player.position = Vector3(0.0, 3.2, 0.0)
	player.velocity = Vector3(0.0, -7.5, 0.0)
	shared_vertical.launch_remaining = 0.0
	shared_vertical.active_jump_kind = ""
	shared_vertical.vertical_state = "falling"
	var landed: bool = false
	for _frame: int in range(180):
		player.call("_process_standard_motion", 1.0 / 60.0)
		if player.is_on_floor():
			landed = true
			break
	assert(landed)
	assert(shared_vertical.last_landing_speed >= GraceVerticalProfile.soft_landing_speed)
	assert(shared_vertical.last_landing_kind in ["firm", "hard"])
	assert(shared_vertical.last_landing_strength > 0.0)
	assert(feedback.last_landing_kind == shared_vertical.last_landing_kind)
	assert(feedback.last_landing_strength == shared_vertical.last_landing_strength)

	visual.sample_animation_pose(1.0 / 60.0)
	wire.sample_now(1.0)
	assert(visual.presentation_state == "landing")
	var landing_debug: Dictionary = visual.get_animation_debug_data()
	assert(landing_debug.has("vertical_landing_kind"))
	assert(landing_debug.has("vertical_landing_strength"))
	assert(bool(landing_debug.get("vertical_visual_override", false)))
	assert(wire.has_finite_pose())
	var controller_debug: Dictionary = player.call("get_combat_motion_debug_data") as Dictionary
	assert(controller_debug.has("vertical_motion"))

	print("VERTICAL_MOTION_SMOKE_TEST: PASS")
	get_tree().quit(0)


func _make_floor() -> StaticBody3D:
	var floor: StaticBody3D = StaticBody3D.new()
	floor.name = "VerticalMotionFloor"
	floor.position = Vector3(0.0, -0.1, 0.0)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(12.0, 0.2, 12.0)
	collision.shape = shape
	floor.add_child(collision)
	return floor
