extends "res://scripts/player/player_controller_free_aim.gd"
class_name PlayerControllerFreeAimStatus

var player_status_receiver: PlayerStatusReceiver
var preserved_step_velocity: Vector3 = Vector3.ZERO
var restore_step_velocity_after_move: bool = false


func _ready() -> void:
	super._ready()
	player_status_receiver = get_node_or_null(
		"StatusReceiver"
	) as PlayerStatusReceiver


func _get_requested_ground_velocity() -> Vector3:
	var requested: Vector3 = super._get_requested_ground_velocity()
	if player_status_receiver == null:
		return requested
	return requested * clampf(
		player_status_receiver.get_movement_multiplier(),
		0.0,
		1.0
	)


func _try_step_up(horizontal_velocity: Vector3, delta: float) -> bool:
	restore_step_velocity_after_move = false
	preserved_step_velocity = Vector3.ZERO
	if step_up_controller == null:
		return false

	var actual_planar_velocity: Vector3 = Vector3(
		velocity.x,
		0.0,
		velocity.z
	)
	if actual_planar_velocity.length_squared() <= 0.0001:
		actual_planar_velocity = horizontal_velocity
		actual_planar_velocity.y = 0.0

	var stepped: bool = step_up_controller.try_step_up(
		actual_planar_velocity,
		delta
	)
	if not stepped:
		return false

	# PlayerStepUpController already traversed the intended planar frame and settled
	# onto the next tread. Zero the duplicate move_and_slide motion, then restore the
	# authored velocity in _finish_step_up before the ground motor records its handoff.
	preserved_step_velocity = actual_planar_velocity
	velocity.x = 0.0
	velocity.z = 0.0
	restore_step_velocity_after_move = true
	return true


func _finish_step_up() -> void:
	super._finish_step_up()
	if not restore_step_velocity_after_move:
		return
	velocity.x = preserved_step_velocity.x
	velocity.z = preserved_step_velocity.z
	preserved_step_velocity = Vector3.ZERO
	restore_step_velocity_after_move = false
