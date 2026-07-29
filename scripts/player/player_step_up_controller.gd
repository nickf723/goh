extends Node
class_name PlayerStepUpController

@export_group("Step Navigation")
@export_range(0.08, 0.6, 0.01) var maximum_step_height: float = 0.42
@export_range(0.0, 0.2, 0.005) var minimum_step_height: float = 0.025
@export_range(0.01, 0.3, 0.005) var forward_probe_distance: float = 0.16
@export_range(0.0, 0.12, 0.002) var step_forward_clearance: float = 0.028
@export_range(0.01, 0.25, 0.005) var landing_probe_extra: float = 0.1
@export_range(0.0, 0.03, 0.001) var landing_clearance: float = 0.006
@export_range(0.0001, 0.05, 0.0005) var motion_test_margin: float = 0.003
@export_range(0.0, 1.0, 0.01) var maximum_obstacle_up_dot: float = 0.88
@export_range(0.0, 1.0, 0.01) var minimum_landing_up_dot: float = 0.5
@export_range(0.0, 0.3, 0.01) var grounded_grace_seconds: float = 0.12
@export var enabled: bool = true

var actor: CharacterBody3D
var stepped_this_frame: bool = false
var stepped_last_frame: bool = false
var last_step_height: float = 0.0
var last_failure_reason: String = "idle"
var last_obstacle_up_dot: float = 0.0
var last_landing_up_dot: float = 0.0
var last_forward_distance: float = 0.0
var last_consumed_motion: Vector3 = Vector3.ZERO
var last_step_origin: Vector3 = Vector3.ZERO
var last_landing_position: Vector3 = Vector3.ZERO
var grounded_grace_remaining: float = 0.0


func _ready() -> void:
	actor = get_parent() as CharacterBody3D
	add_to_group("player_step_up_controller")


func try_step_up(horizontal_velocity: Vector3, delta: float) -> bool:
	var recently_stepped: bool = stepped_last_frame
	stepped_last_frame = false
	_reset_frame_debug()

	if not enabled:
		return _fail("disabled")
	if actor == null:
		return _fail("missing actor")
	if delta <= 0.0:
		return _fail("invalid delta")

	if actor.is_on_floor() or recently_stepped:
		grounded_grace_remaining = grounded_grace_seconds
	else:
		grounded_grace_remaining = maxf(grounded_grace_remaining - delta, 0.0)

	if not actor.is_on_floor() and grounded_grace_remaining <= 0.0:
		return _fail("airborne")
	if actor.velocity.y > 0.05:
		return _fail("ascending")
	if not actor.is_on_floor() and actor.velocity.y < -2.0:
		return _fail("descending")

	var horizontal_direction: Vector3 = horizontal_velocity
	horizontal_direction.y = 0.0
	if horizontal_direction.length_squared() <= 0.0001:
		return _fail("no horizontal motion")
	horizontal_direction = horizontal_direction.normalized()

	var frame_motion: Vector3 = horizontal_velocity * delta
	frame_motion.y = 0.0
	var intended_distance: float = frame_motion.length()
	var probe_length: float = maxf(intended_distance, forward_probe_distance)
	var probe_motion: Vector3 = horizontal_direction * probe_length

	var obstacle_collision: KinematicCollision3D = KinematicCollision3D.new()
	if not actor.test_move(
		actor.global_transform,
		probe_motion,
		obstacle_collision,
		motion_test_margin,
		false,
		8
	):
		return _fail("clear path")

	var obstacle_normal: Vector3 = _get_most_wall_like_normal(obstacle_collision)
	last_obstacle_up_dot = obstacle_normal.dot(Vector3.UP)
	if last_obstacle_up_dot > maximum_obstacle_up_dot:
		return _fail("walkable slope")

	var obstacle_travel: Vector3 = obstacle_collision.get_travel()
	obstacle_travel.y = 0.0
	var obstacle_distance: float = maxf(
		obstacle_travel.dot(horizontal_direction),
		0.0
	)
	if obstacle_distance > intended_distance + step_forward_clearance:
		return _fail("obstacle ahead")

	var traversal_distance: float = maxf(
		intended_distance,
		obstacle_distance + step_forward_clearance
	)
	traversal_distance = clampf(
		traversal_distance,
		minf(step_forward_clearance, probe_length),
		probe_length
	)
	var traversal_motion: Vector3 = horizontal_direction * traversal_distance

	var upward_motion: Vector3 = Vector3.UP * maximum_step_height
	if actor.test_move(
		actor.global_transform,
		upward_motion,
		null,
		motion_test_margin,
		false,
		8
	):
		return _fail("blocked overhead")

	var raised_transform: Transform3D = actor.global_transform
	raised_transform.origin += upward_motion
	if actor.test_move(
		raised_transform,
		traversal_motion,
		null,
		motion_test_margin,
		false,
		8
	):
		return _fail("step top blocked")

	var landing_transform: Transform3D = raised_transform
	landing_transform.origin += traversal_motion
	var landing_collision: KinematicCollision3D = KinematicCollision3D.new()
	var downward_motion: Vector3 = Vector3.DOWN * (
		maximum_step_height + landing_probe_extra
	)
	if not actor.test_move(
		landing_transform,
		downward_motion,
		landing_collision,
		motion_test_margin,
		false,
		8
	):
		return _fail("no landing")

	var landing_normal: Vector3 = _get_most_floor_like_normal(landing_collision)
	last_landing_up_dot = landing_normal.dot(Vector3.UP)
	if last_landing_up_dot < minimum_landing_up_dot:
		return _fail("landing too steep")

	var step_height: float = maximum_step_height + landing_collision.get_travel().y
	if step_height < minimum_step_height:
		return _fail("rise too small")
	if step_height > maximum_step_height + 0.001:
		return _fail("rise too tall")

	last_step_origin = actor.global_position
	var resolved_transform: Transform3D = landing_transform
	resolved_transform.origin += landing_collision.get_travel()
	resolved_transform.origin.y += landing_clearance
	actor.global_transform = resolved_transform
	if actor.velocity.y <= 0.05:
		actor.velocity.y = -0.1

	stepped_this_frame = true
	stepped_last_frame = true
	last_step_height = step_height
	last_forward_distance = traversal_distance
	last_consumed_motion = traversal_motion
	last_landing_position = actor.global_position
	last_failure_reason = "stepped"
	grounded_grace_remaining = grounded_grace_seconds
	return true


func finish_step() -> void:
	if actor == null or not stepped_this_frame:
		return
	if actor.velocity.y <= 0.05:
		actor.apply_floor_snap()


func reset_debug_state() -> void:
	stepped_this_frame = false
	stepped_last_frame = false
	last_step_height = 0.0
	last_failure_reason = "idle"
	last_obstacle_up_dot = 0.0
	last_landing_up_dot = 0.0
	last_forward_distance = 0.0
	last_consumed_motion = Vector3.ZERO
	last_step_origin = Vector3.ZERO
	last_landing_position = Vector3.ZERO
	grounded_grace_remaining = 0.0


func get_debug_data() -> Dictionary:
	return {
		"enabled": enabled,
		"stepped": stepped_this_frame,
		"height": snappedf(last_step_height, 0.001),
		"reason": last_failure_reason,
		"maximum_height": maximum_step_height,
		"obstacle_up_dot": snappedf(last_obstacle_up_dot, 0.001),
		"landing_up_dot": snappedf(last_landing_up_dot, 0.001),
		"forward_distance": snappedf(last_forward_distance, 0.001),
		"consumed_motion": last_consumed_motion,
		"step_origin": last_step_origin,
		"landing_position": last_landing_position,
		"ground_grace": snappedf(grounded_grace_remaining, 0.001),
		"direct_traversal": stepped_this_frame,
	}


func _reset_frame_debug() -> void:
	stepped_this_frame = false
	last_step_height = 0.0
	last_failure_reason = ""
	last_obstacle_up_dot = 0.0
	last_landing_up_dot = 0.0
	last_forward_distance = 0.0
	last_consumed_motion = Vector3.ZERO
	last_step_origin = Vector3.ZERO
	last_landing_position = Vector3.ZERO


func _get_most_wall_like_normal(collision: KinematicCollision3D) -> Vector3:
	if collision == null or collision.get_collision_count() <= 0:
		return Vector3.ZERO
	var best_normal: Vector3 = collision.get_normal(0).normalized()
	var best_up_abs: float = absf(best_normal.dot(Vector3.UP))
	for collision_index: int in range(1, collision.get_collision_count()):
		var candidate: Vector3 = collision.get_normal(collision_index).normalized()
		var candidate_up_abs: float = absf(candidate.dot(Vector3.UP))
		if candidate_up_abs < best_up_abs:
			best_normal = candidate
			best_up_abs = candidate_up_abs
	return best_normal


func _get_most_floor_like_normal(collision: KinematicCollision3D) -> Vector3:
	if collision == null or collision.get_collision_count() <= 0:
		return Vector3.ZERO
	var best_normal: Vector3 = collision.get_normal(0).normalized()
	var best_up_dot: float = best_normal.dot(Vector3.UP)
	for collision_index: int in range(1, collision.get_collision_count()):
		var candidate: Vector3 = collision.get_normal(collision_index).normalized()
		var candidate_up_dot: float = candidate.dot(Vector3.UP)
		if candidate_up_dot > best_up_dot:
			best_normal = candidate
			best_up_dot = candidate_up_dot
	return best_normal


func _fail(reason: String) -> bool:
	last_failure_reason = reason
	return false
