extends Node
class_name PlayerStepUpController

@export_group("Step Navigation")
@export_range(0.08, 0.6, 0.01) var maximum_step_height: float = 0.36
@export_range(0.0, 0.2, 0.005) var minimum_step_height: float = 0.035
@export_range(0.01, 0.3, 0.005) var forward_probe_distance: float = 0.11
@export_range(0.01, 0.25, 0.005) var landing_probe_extra: float = 0.08
@export_range(0.0, 0.03, 0.001) var landing_clearance: float = 0.004
@export_range(0.0001, 0.05, 0.0005) var motion_test_margin: float = 0.003
@export_range(0.0, 1.0, 0.01) var maximum_obstacle_up_dot: float = 0.42
@export_range(0.0, 1.0, 0.01) var minimum_landing_up_dot: float = 0.55
@export var enabled: bool = true

var actor: CharacterBody3D
var stepped_this_frame: bool = false
var last_step_height: float = 0.0
var last_failure_reason: String = "idle"


func _ready() -> void:
	actor = get_parent() as CharacterBody3D
	add_to_group("player_step_up_controller")


func try_step_up(horizontal_velocity: Vector3, delta: float) -> bool:
	stepped_this_frame = false
	last_step_height = 0.0
	last_failure_reason = ""

	if not enabled:
		return _fail("disabled")
	if actor == null:
		return _fail("missing actor")
	if delta <= 0.0:
		return _fail("invalid delta")
	if not actor.is_on_floor():
		return _fail("airborne")
	if actor.velocity.y > 0.05:
		return _fail("ascending")

	var horizontal_direction: Vector3 = horizontal_velocity
	horizontal_direction.y = 0.0
	if horizontal_direction.length_squared() <= 0.0001:
		return _fail("no horizontal motion")
	horizontal_direction = horizontal_direction.normalized()

	var frame_motion: Vector3 = horizontal_velocity * delta
	frame_motion.y = 0.0
	var probe_length: float = maxf(frame_motion.length(), forward_probe_distance)
	var probe_motion: Vector3 = horizontal_direction * probe_length

	var obstacle_collision: KinematicCollision3D = KinematicCollision3D.new()
	if not actor.test_move(
		actor.global_transform,
		probe_motion,
		obstacle_collision,
		motion_test_margin,
		false,
		4
	):
		return _fail("clear path")

	var obstacle_normal: Vector3 = obstacle_collision.get_normal(0).normalized()
	if obstacle_normal.dot(Vector3.UP) > maximum_obstacle_up_dot:
		return _fail("walkable slope")

	var upward_motion: Vector3 = Vector3.UP * maximum_step_height
	if actor.test_move(
		actor.global_transform,
		upward_motion,
		null,
		motion_test_margin,
		false,
		4
	):
		return _fail("blocked overhead")

	var raised_transform: Transform3D = actor.global_transform
	raised_transform.origin += upward_motion
	if actor.test_move(
		raised_transform,
		probe_motion,
		null,
		motion_test_margin,
		false,
		4
	):
		return _fail("step top blocked")

	var landing_transform: Transform3D = raised_transform
	landing_transform.origin += probe_motion
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
		4
	):
		return _fail("no landing")

	var landing_normal: Vector3 = landing_collision.get_normal(0).normalized()
	if landing_normal.dot(Vector3.UP) < minimum_landing_up_dot:
		return _fail("landing too steep")

	var step_height: float = maximum_step_height + landing_collision.get_travel().y
	if step_height < minimum_step_height:
		return _fail("rise too small")
	if step_height > maximum_step_height + 0.001:
		return _fail("rise too tall")

	actor.global_position.y += step_height + landing_clearance
	stepped_this_frame = true
	last_step_height = step_height
	last_failure_reason = "stepped"
	return true


func finish_step() -> void:
	if actor == null or not stepped_this_frame:
		return
	if actor.velocity.y <= 0.05:
		actor.apply_floor_snap()


func reset_debug_state() -> void:
	stepped_this_frame = false
	last_step_height = 0.0
	last_failure_reason = "idle"


func get_debug_data() -> Dictionary:
	return {
		"enabled": enabled,
		"stepped": stepped_this_frame,
		"height": snappedf(last_step_height, 0.001),
		"reason": last_failure_reason,
		"maximum_height": maximum_step_height,
	}


func _fail(reason: String) -> bool:
	last_failure_reason = reason
	return false
