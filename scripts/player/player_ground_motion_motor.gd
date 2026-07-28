extends Node
class_name PlayerGroundMotionMotor

signal motion_state_changed(previous_state: String, next_state: String)

@export var profile: GroundMotionProfile

var actor: CharacterBody3D
var motion_state: String = "idle"
var desired_velocity: Vector3 = Vector3.ZERO
var resolved_velocity: Vector3 = Vector3.ZERO
var post_move_velocity: Vector3 = Vector3.ZERO
var requested_local_direction: Vector3 = Vector3.ZERO
var input_strength: float = 0.0
var shaped_input_strength: float = 0.0
var alignment_dot: float = 1.0
var turn_angle_degrees: float = 0.0
var acceleration_weight: float = 0.0
var braking_weight: float = 0.0
var reversal_weight: float = 0.0
var turning_weight: float = 0.0
var external_source: String = ""


func _ready() -> void:
	actor = get_parent() as CharacterBody3D
	add_to_group("player_ground_motion_motor")


func get_configured_maximum_speed(fallback: float = 5.0) -> float:
	if profile == null:
		return maxf(fallback, 0.0)
	return maxf(profile.maximum_speed, 0.0)


func get_attack_momentum_retention() -> float:
	if profile == null:
		return 0.32
	return clampf(profile.attack_momentum_retention, 0.0, 1.0)


func get_dodge_exit_momentum_retention() -> float:
	if profile == null:
		return 0.68
	return clampf(profile.dodge_exit_momentum_retention, 0.0, 1.0)


func get_desired_velocity(
	input_vector: Vector2,
	effective_maximum_speed: float,
	lock_on_active: bool = false
) -> Vector3:
	input_strength = clampf(input_vector.length(), 0.0, 1.0)
	var deadzone: float = profile.input_deadzone if profile != null else 0.08
	if input_strength <= deadzone or actor == null:
		requested_local_direction = Vector3.ZERO
		shaped_input_strength = 0.0
		desired_velocity = Vector3.ZERO
		return desired_velocity

	var normalized_strength: float = inverse_lerp(deadzone, 1.0, input_strength)
	var exponent: float = profile.analog_exponent if profile != null else 1.0
	shaped_input_strength = pow(clampf(normalized_strength, 0.0, 1.0), maxf(exponent, 0.01))

	requested_local_direction = Vector3(input_vector.x, 0.0, input_vector.y)
	if requested_local_direction.length_squared() <= 0.0001:
		desired_velocity = Vector3.ZERO
		return desired_velocity
	requested_local_direction = requested_local_direction.normalized()

	var basis: Basis = actor.global_transform.basis.orthonormalized()
	var world_direction: Vector3 = (
		basis.x * requested_local_direction.x
		+ basis.z * requested_local_direction.z
	)
	world_direction.y = 0.0
	if world_direction.length_squared() <= 0.0001:
		desired_velocity = Vector3.ZERO
		return desired_velocity
	world_direction = world_direction.normalized()

	var directional_multiplier: float = 1.0
	if lock_on_active and profile != null:
		var lateral_share: float = absf(requested_local_direction.x)
		var backward_share: float = maxf(requested_local_direction.z, 0.0)
		directional_multiplier *= lerpf(
			1.0,
			profile.lock_on_strafe_multiplier,
			lateral_share
		)
		directional_multiplier *= lerpf(
			1.0,
			profile.lock_on_backward_multiplier,
			backward_share
		)

	var target_speed: float = maxf(effective_maximum_speed, 0.0)
	target_speed *= shaped_input_strength * directional_multiplier
	desired_velocity = world_direction * target_speed
	return desired_velocity


func resolve_planar_velocity(
	current_velocity: Vector3,
	requested_velocity: Vector3,
	grounded: bool,
	delta: float
) -> Vector3:
	var current: Vector3 = Vector3(current_velocity.x, 0.0, current_velocity.z)
	var requested: Vector3 = Vector3(requested_velocity.x, 0.0, requested_velocity.z)
	desired_velocity = requested
	external_source = ""

	if delta <= 0.0:
		resolved_velocity = current
		return resolved_velocity

	if profile == null:
		resolved_velocity = requested
		_set_motion_state("legacy")
		_update_feedback_weights(delta)
		return resolved_velocity

	var current_speed: float = current.length()
	var requested_speed: float = requested.length()
	alignment_dot = 1.0
	turn_angle_degrees = 0.0
	if current_speed > profile.stop_speed and requested_speed > profile.stop_speed:
		alignment_dot = clampf(
			current.normalized().dot(requested.normalized()),
			-1.0,
			1.0
		)
		turn_angle_degrees = rad_to_deg(acos(alignment_dot))

	if not grounded:
		var air_target: Vector3 = requested if requested_speed > profile.stop_speed else Vector3.ZERO
		var air_rate: float = profile.air_acceleration if requested_speed > profile.stop_speed else profile.air_drag
		resolved_velocity = current.move_toward(air_target, maxf(air_rate, 0.0) * delta)
		_set_motion_state("airborne_control" if requested_speed > profile.stop_speed else "airborne_coast")
		_update_feedback_weights(delta)
		return resolved_velocity

	var response_rate: float = profile.acceleration
	var next_state: String = "accelerating"

	if requested_speed <= profile.stop_speed:
		if current_speed <= profile.stop_speed:
			resolved_velocity = Vector3.ZERO
			next_state = "idle"
		else:
			response_rate = profile.braking
			if current_speed > profile.maximum_speed + profile.cruise_speed_tolerance:
				response_rate = profile.overspeed_braking
			resolved_velocity = current.move_toward(Vector3.ZERO, response_rate * delta)
			next_state = "braking"
	elif current_speed <= profile.stop_speed:
		resolved_velocity = current.move_toward(requested, profile.acceleration * delta)
		var response_floor: float = minf(profile.initial_response_speed, requested_speed)
		if resolved_velocity.length() < response_floor and requested_speed > 0.0:
			resolved_velocity = requested.normalized() * response_floor
		next_state = "accelerating"
	else:
		if alignment_dot <= profile.reversal_dot:
			response_rate = profile.reversal_acceleration
			next_state = "reversing"
		elif alignment_dot <= profile.sharp_turn_dot:
			response_rate = profile.turn_acceleration
			next_state = "turning"
		elif current_speed > requested_speed + profile.cruise_speed_tolerance:
			response_rate = profile.braking
			if current_speed > profile.maximum_speed + profile.cruise_speed_tolerance:
				response_rate = profile.overspeed_braking
			next_state = "braking"
		elif (
			absf(current_speed - requested_speed) <= profile.cruise_speed_tolerance
			and alignment_dot >= 0.985
		):
			response_rate = profile.acceleration
			next_state = "cruising"
		else:
			response_rate = profile.acceleration
			next_state = "accelerating"
		resolved_velocity = current.move_toward(requested, maxf(response_rate, 0.0) * delta)

	if resolved_velocity.length() <= profile.stop_speed and requested_speed <= profile.stop_speed:
		resolved_velocity = Vector3.ZERO
		next_state = "idle"

	_set_motion_state(next_state)
	_update_feedback_weights(delta)
	return resolved_velocity


func capture_external_velocity(planar_velocity: Vector3, source: String) -> void:
	resolved_velocity = Vector3(planar_velocity.x, 0.0, planar_velocity.z)
	post_move_velocity = resolved_velocity
	external_source = source
	_set_motion_state("external_" + source if source != "" else "external")


func record_post_move(planar_velocity: Vector3) -> void:
	post_move_velocity = Vector3(planar_velocity.x, 0.0, planar_velocity.z)


func reset_motion() -> void:
	desired_velocity = Vector3.ZERO
	resolved_velocity = Vector3.ZERO
	post_move_velocity = Vector3.ZERO
	requested_local_direction = Vector3.ZERO
	input_strength = 0.0
	shaped_input_strength = 0.0
	alignment_dot = 1.0
	turn_angle_degrees = 0.0
	acceleration_weight = 0.0
	braking_weight = 0.0
	reversal_weight = 0.0
	turning_weight = 0.0
	external_source = ""
	_set_motion_state("idle")


func get_debug_data() -> Dictionary:
	var actual_speed: float = post_move_velocity.length()
	if actual_speed <= 0.0001:
		actual_speed = resolved_velocity.length()
	var maximum_speed: float = get_configured_maximum_speed(1.0)
	return {
		"state": motion_state,
		"desired_velocity": desired_velocity,
		"resolved_velocity": resolved_velocity,
		"post_move_velocity": post_move_velocity,
		"target_speed": snappedf(desired_velocity.length(), 0.01),
		"actual_speed": snappedf(actual_speed, 0.01),
		"speed_ratio": snappedf(actual_speed / maxf(maximum_speed, 0.01), 0.01),
		"input_strength": snappedf(input_strength, 0.01),
		"shaped_input_strength": snappedf(shaped_input_strength, 0.01),
		"local_direction": requested_local_direction,
		"alignment_dot": snappedf(alignment_dot, 0.01),
		"turn_angle_degrees": snappedf(turn_angle_degrees, 0.1),
		"acceleration_weight": snappedf(acceleration_weight, 0.01),
		"braking_weight": snappedf(braking_weight, 0.01),
		"reversal_weight": snappedf(reversal_weight, 0.01),
		"turning_weight": snappedf(turning_weight, 0.01),
		"external_source": external_source,
		"profile_ready": profile != null,
	}


func _set_motion_state(next_state: String) -> void:
	if next_state == motion_state:
		return
	var previous_state: String = motion_state
	motion_state = next_state
	motion_state_changed.emit(previous_state, motion_state)


func _update_feedback_weights(delta: float) -> void:
	var response: float = profile.feedback_response if profile != null else 14.0
	var blend: float = 1.0 - exp(-maxf(response, 0.0) * maxf(delta, 0.0))
	acceleration_weight = lerpf(
		acceleration_weight,
		1.0 if motion_state == "accelerating" else 0.0,
		blend
	)
	braking_weight = lerpf(
		braking_weight,
		1.0 if motion_state == "braking" else 0.0,
		blend
	)
	reversal_weight = lerpf(
		reversal_weight,
		1.0 if motion_state == "reversing" else 0.0,
		blend
	)
	turning_weight = lerpf(
		turning_weight,
		1.0 if motion_state == "turning" else 0.0,
		blend
	)
