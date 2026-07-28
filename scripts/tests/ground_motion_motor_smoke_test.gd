extends Node

const GraceMotionProfile: GroundMotionProfile = preload(
	"res://data/player/grace_ground_motion_profile.tres"
)
const PlayerScene: PackedScene = preload("res://scenes/actors/player/player.tscn")


func _ready() -> void:
	var actor: CharacterBody3D = CharacterBody3D.new()
	actor.name = "MotionActor"
	var motor: PlayerGroundMotionMotor = PlayerGroundMotionMotor.new()
	motor.name = "GroundMotionMotor"
	motor.profile = GraceMotionProfile
	actor.add_child(motor)
	add_child(actor)
	await get_tree().process_frame

	assert(motor.actor == actor)
	assert(motor.is_in_group("player_ground_motion_motor"))
	assert(GraceMotionProfile.validate_profile().is_empty())
	assert(is_equal_approx(motor.get_configured_maximum_speed(), 5.0))

	var full_forward: Vector3 = motor.get_desired_velocity(Vector2(0.0, -1.0), 5.0, false)
	var half_forward: Vector3 = motor.get_desired_velocity(Vector2(0.0, -0.5), 5.0, false)
	var locked_strafe: Vector3 = motor.get_desired_velocity(Vector2(1.0, 0.0), 5.0, true)
	assert(is_equal_approx(full_forward.length(), 5.0))
	assert(half_forward.length() > 1.0 and half_forward.length() < full_forward.length())
	assert(locked_strafe.length() < full_forward.length())
	assert(full_forward.z < 0.0)

	var velocity: Vector3 = Vector3.ZERO
	for _frame: int in range(4):
		velocity = motor.resolve_planar_velocity(velocity, full_forward, true, 1.0 / 60.0)
	assert(velocity.length() > 1.0 and velocity.length() < 5.0)
	assert(motor.motion_state == "accelerating")
	for _frame: int in range(12):
		velocity = motor.resolve_planar_velocity(velocity, full_forward, true, 1.0 / 60.0)
	assert(velocity.length() > 4.9)
	assert(motor.motion_state in ["accelerating", "cruising"])

	var pre_brake_speed: float = velocity.length()
	velocity = motor.resolve_planar_velocity(velocity, Vector3.ZERO, true, 1.0 / 60.0)
	assert(velocity.length() < pre_brake_speed)
	assert(motor.motion_state == "braking")
	for _frame: int in range(10):
		velocity = motor.resolve_planar_velocity(velocity, Vector3.ZERO, true, 1.0 / 60.0)
	assert(velocity.length() <= GraceMotionProfile.stop_speed)
	assert(motor.motion_state == "idle")

	velocity = Vector3(0.0, 0.0, -5.0)
	var reverse_target: Vector3 = Vector3(0.0, 0.0, 5.0)
	velocity = motor.resolve_planar_velocity(velocity, reverse_target, true, 1.0 / 60.0)
	assert(motor.motion_state == "reversing")
	assert(velocity.z > -5.0 and velocity.z < 0.0)
	for _frame: int in range(12):
		velocity = motor.resolve_planar_velocity(velocity, reverse_target, true, 1.0 / 60.0)
	assert(velocity.z > 4.5)

	velocity = motor.resolve_planar_velocity(
		Vector3(0.0, 0.0, -5.0),
		Vector3(5.0, 0.0, 0.0),
		true,
		1.0 / 60.0
	)
	assert(motor.motion_state == "turning")
	assert(velocity.x > 0.0 and velocity.z < 0.0)

	var airborne: Vector3 = motor.resolve_planar_velocity(
		Vector3(0.0, 0.0, -5.0),
		Vector3.ZERO,
		false,
		1.0 / 60.0
	)
	assert(motor.motion_state == "airborne_coast")
	assert(airborne.length() > 4.9)

	motor.capture_external_velocity(Vector3(8.0, 0.0, 0.0), "dodge")
	assert(motor.motion_state == "external_dodge")
	assert(is_equal_approx(float(motor.get_debug_data().get("actual_speed", 0.0)), 8.0))
	assert(is_equal_approx(motor.get_attack_momentum_retention(), 0.32))
	assert(is_equal_approx(motor.get_dodge_exit_momentum_retention(), 0.68))

	motor.reset_motion()
	assert(motor.motion_state == "idle")
	assert(motor.get_debug_data().has("reversal_weight"))
	assert(motor.get_debug_data().has("turn_angle_degrees"))

	var shared_player: CharacterBody3D = PlayerScene.instantiate() as CharacterBody3D
	shared_player.name = "SharedPlayer"
	shared_player.position = Vector3(0.0, 3.0, 0.0)
	add_child(shared_player)
	await get_tree().process_frame
	var shared_motor: PlayerGroundMotionMotor = (
		shared_player.get_node_or_null("GroundMotionMotor") as PlayerGroundMotionMotor
	)
	var shared_visual: GraceWireMotionVisual = (
		shared_player.get_node_or_null("GraceVisualV1") as GraceWireMotionVisual
	)
	assert(shared_motor != null)
	assert(shared_motor.profile != null)
	assert(is_equal_approx(shared_motor.profile.maximum_speed, 5.0))
	assert(shared_visual != null)
	shared_motor.get_desired_velocity(Vector2(0.0, -1.0), 5.0, false)
	shared_motor.resolve_planar_velocity(Vector3.ZERO, Vector3(0.0, 0.0, -5.0), true, 1.0 / 60.0)
	shared_motor.record_post_move(shared_motor.resolved_velocity)
	shared_visual.sample_animation_pose(1.0 / 60.0)
	var visual_debug: Dictionary = shared_visual.get_animation_debug_data()
	assert(visual_debug.has("ground_motion_state"))
	assert(visual_debug.has("ground_target_speed"))
	assert(visual_debug.has("ground_braking_weight"))
	assert(shared_player.has_method("get_combat_motion_debug_data"))
	var controller_debug: Dictionary = shared_player.call("get_combat_motion_debug_data") as Dictionary
	assert(controller_debug.has("ground_motion"))

	print("GROUND_MOTION_MOTOR_SMOKE_TEST: PASS")
	get_tree().quit(0)
