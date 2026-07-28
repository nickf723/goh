extends "res://scripts/player/player_aerial_locomotion.gd"
class_name PlayerAerialLocomotionVertical

@onready var vertical_motion_controller: PlayerVerticalMotionController = (
	get_parent().get_node_or_null("VerticalMotionController") as PlayerVerticalMotionController
)
@onready var ground_motion_motor: PlayerGroundMotionMotor = (
	get_parent().get_node_or_null("GroundMotionMotor") as PlayerGroundMotionMotor
)
@onready var step_up_controller: PlayerStepUpController = (
	get_parent().get_node_or_null("StepUpController") as PlayerStepUpController
)


func _ready() -> void:
	super._ready()
	add_to_group("player_aerial_vertical_integration")


func should_handle_locomotion() -> bool:
	if flight_active or controlled_descent_active:
		return true
	if actor == null:
		return false
	if not actor.is_on_floor() and (double_jump_unlocked or hover_unlocked):
		return true
	return airflow_response != null and airflow_response.has_active_airflow(actor.global_position)


func process_jump_hover(delta: float) -> void:
	if actor == null:
		return
	var was_on_floor: bool = actor.is_on_floor()
	var move_input: Vector2 = get_move_input()
	var requested_direction: Vector3 = get_camera_relative_horizontal_direction(move_input)
	var move_speed: float = float(actor.get("move_speed"))
	var gravity_value: float = float(actor.get("gravity"))
	var jump_speed: float = float(actor.get("jump_velocity"))
	var can_move: bool = action_state == null or action_state.can_move()
	if not can_move:
		requested_direction = Vector3.ZERO

	_resolve_horizontal_motion(
		requested_direction,
		move_speed,
		was_on_floor,
		delta
	)

	var ground_jump_started: bool = false
	var air_jump_started: bool = false
	if vertical_motion_controller != null:
		vertical_motion_controller.prepare_frame(delta, was_on_floor, can_move)
		ground_jump_started = vertical_motion_controller.try_consume_ground_jump(
			jump_speed,
			"jump"
		)
		if (
			not ground_jump_started
			and double_jump_unlocked
			and air_jumps_used < maximum_air_jumps
			and vertical_motion_controller.has_buffered_jump_request()
		):
			air_jump_started = vertical_motion_controller.try_consume_air_jump(
				double_jump_velocity,
				"double_jump"
			)
			if air_jump_started:
				air_jumps_used += 1
				hover_armed = hover_unlocked
				hover_remaining = hover_duration
	else:
		if was_on_floor:
			coyote_timer = coyote_time
		else:
			coyote_timer = maxf(coyote_timer - delta, 0.0)
		if can_move and Input.is_action_just_pressed("jump"):
			if was_on_floor or coyote_timer > 0.0:
				actor.velocity.y = jump_speed
				coyote_timer = 0.0
				ground_jump_started = true
			elif double_jump_unlocked and air_jumps_used < maximum_air_jumps:
				actor.velocity.y = double_jump_velocity
				air_jumps_used += 1
				hover_armed = hover_unlocked
				hover_remaining = hover_duration
				air_jump_started = true

	if was_on_floor and not ground_jump_started:
		air_jumps_used = 0
		hover_remaining = hover_duration
		hover_armed = false
		controlled_descent_active = false
		was_hovering = false

	var hover_requested: bool = (
		hover_unlocked
		and hover_armed
		and Input.is_action_pressed("jump")
		and hover_remaining > 0.0
		and actor.velocity.y <= hover_activation_upward_speed
	)

	if hover_requested:
		hover_remaining = maxf(hover_remaining - delta, 0.0)
		actor.velocity.y = move_toward(
			actor.velocity.y,
			hover_target_fall_speed,
			hover_vertical_response * delta
		)
		was_hovering = true
		set_traversal_state("hovering")
		if vertical_motion_controller != null:
			vertical_motion_controller.set_external_state("hovering", false)
		hover_updated.emit(hover_remaining, hover_duration)
	else:
		if was_hovering and not Input.is_action_pressed("jump"):
			hover_armed = false
		was_hovering = false
		if controlled_descent_active:
			actor.velocity.y = move_toward(
				actor.velocity.y,
				-controlled_descent_speed,
				controlled_descent_acceleration * delta
			)
			set_traversal_state("controlled_descent")
			if vertical_motion_controller != null:
				vertical_motion_controller.set_external_state("controlled_descent", false)
		elif not ground_jump_started and not air_jump_started:
			if vertical_motion_controller != null:
				vertical_motion_controller.apply_gravity(delta, gravity_value)
			else:
				actor.velocity.y -= gravity_value * delta

	if vertical_motion_controller != null:
		coyote_timer = vertical_motion_controller.coyote_remaining

	apply_airflow(delta, grounded_airflow_response if was_on_floor else airborne_airflow_response)
	# Airflow can alter vertical speed immediately before collision. Capture the final
	# pre-move value so landing class, feedback, and hard-impact presentation agree
	# with the velocity that actually reached the floor.
	if vertical_motion_controller != null:
		vertical_motion_controller.note_pre_move_velocity()
	if was_on_floor and step_up_controller != null:
		step_up_controller.try_step_up(
			Vector3(actor.velocity.x, 0.0, actor.velocity.z),
			delta
		)
	actor.move_and_slide()
	if step_up_controller != null:
		step_up_controller.finish_step()
	if vertical_motion_controller != null:
		vertical_motion_controller.record_post_move(was_on_floor)
	if ground_motion_motor != null:
		ground_motion_motor.record_post_move(Vector3(actor.velocity.x, 0.0, actor.velocity.z))

	if actor.is_on_floor():
		air_jumps_used = 0
		hover_remaining = hover_duration
		hover_armed = false
		controlled_descent_active = false
		set_traversal_state("grounded")
	elif hover_requested or controlled_descent_active:
		pass
	elif air_jump_started or (
		vertical_motion_controller != null
		and vertical_motion_controller.active_jump_kind == "double_jump"
		and vertical_motion_controller.vertical_state in ["launch", "rising", "apex"]
	):
		set_traversal_state("double_jump")
	elif vertical_motion_controller != null:
		if vertical_motion_controller.vertical_state in ["launch", "rising", "apex"]:
			set_traversal_state("jumping")
		else:
			set_traversal_state("falling")
	else:
		set_traversal_state("jumping" if actor.velocity.y > 0.0 else "falling")


func process_flight(delta: float) -> void:
	if vertical_motion_controller != null:
		vertical_motion_controller.set_external_state("flight", true)
	super.process_flight(delta)
	if ground_motion_motor != null and actor != null:
		ground_motion_motor.record_post_move(Vector3(actor.velocity.x, 0.0, actor.velocity.z))


func get_debug_data() -> Dictionary:
	var debug_data: Dictionary = super.get_debug_data()
	debug_data["vertical_integration"] = vertical_motion_controller != null
	debug_data["vertical_motion"] = (
		vertical_motion_controller.get_debug_data()
		if vertical_motion_controller != null
		else {}
	)
	return debug_data


func _resolve_horizontal_motion(
	requested_direction: Vector3,
	move_speed: float,
	was_on_floor: bool,
	delta: float
) -> void:
	if actor == null:
		return
	var requested_velocity: Vector3 = requested_direction * move_speed
	if actor.has_method("_get_requested_ground_velocity"):
		requested_velocity = actor.call("_get_requested_ground_velocity") as Vector3
	var current_velocity := Vector3(actor.velocity.x, 0.0, actor.velocity.z)
	if ground_motion_motor != null:
		var resolved: Vector3 = ground_motion_motor.resolve_planar_velocity(
			current_velocity,
			requested_velocity,
			was_on_floor,
			delta
		)
		actor.velocity.x = resolved.x
		actor.velocity.z = resolved.z
		return

	var acceleration: float = ground_acceleration if was_on_floor else air_acceleration
	actor.velocity.x = move_toward(
		actor.velocity.x,
		requested_velocity.x,
		acceleration * delta
	)
	actor.velocity.z = move_toward(
		actor.velocity.z,
		requested_velocity.z,
		acceleration * delta
	)
