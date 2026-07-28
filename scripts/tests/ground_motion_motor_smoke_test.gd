extends Node

const GraceMotionProfile: GroundMotionProfile = preload(
	"res://data/player/grace_ground_motion_profile.tres"
)


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
	assert(is_equal_approx(motor.get_debug_data().get("actual_speed", 0.0), 8.0))
	assert(is_equal_approx(motor.get_attack_momentum_retention(), 0.32))
	assert(is_equal_approx(motor.get_dodge_exit_momentum_retention(), 0.68))

	motor.reset_motion()
	assert(motor.motion_state == "idle")
	assert(motor.get_debug_data().has("reversal_weight"))
	assert(motor.get_debug_data().has("turn_angle_degrees"))

	print("GROUND_MOTION_MOTOR_SMOKE_TEST: PASS")
	get_tree().quit(0)
