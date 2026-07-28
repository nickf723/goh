extends Node
class_name PlayerCombatFootworkController

const CombatFootworkCatalogScript = preload(
	"res://scripts/weapons/combat_footwork_catalog.gd"
)

signal footwork_started(attack_id: String, profile_id: String)
signal footwork_phase_changed(previous_phase: String, next_phase: String)
signal footwork_blocked(attack_id: String, requested_distance: float, actual_distance: float)
signal footwork_finished(attack_id: String, reason: String)

@export var profile: CombatFootworkProfile

var actor: CharacterBody3D
var weapon_controller: WeaponController
var active_attack: WeaponAttackDefinition
var active_profile_id: String = ""
var active_attack_speed: float = 1.0

var root_motion_active: bool = false
var motion_direction: Vector3 = Vector3.FORWARD
var original_motion_direction: Vector3 = Vector3.FORWARD
var motion_elapsed: float = 0.0
var motion_duration: float = 0.0
var motion_progress: float = 0.0
var motion_distance: float = 0.0
var base_motion_speed: float = 0.0
var sampled_velocity: Vector3 = Vector3.ZERO
var motion_phase: String = "idle"

var expected_distance: float = 0.0
var actual_distance: float = 0.0
var last_expected_displacement: Vector3 = Vector3.ZERO
var last_actual_displacement: Vector3 = Vector3.ZERO
var blocked_frame_count: int = 0
var blocked: bool = false
var steering_angle_degrees: float = 0.0
var last_finish_reason: String = "ready"


func _ready() -> void:
	actor = get_parent() as CharacterBody3D
	if actor != null:
		weapon_controller = actor.get_node_or_null("WeaponController") as WeaponController
	if weapon_controller != null:
		if not weapon_controller.attack_started.is_connected(_on_attack_started):
			weapon_controller.attack_started.connect(_on_attack_started)
		if not weapon_controller.attack_finished.is_connected(_on_attack_finished):
			weapon_controller.attack_finished.connect(_on_attack_finished)
	add_to_group("player_combat_footwork_controller")
	add_to_group("debuggable")


func _exit_tree() -> void:
	if weapon_controller == null:
		return
	if weapon_controller.attack_started.is_connected(_on_attack_started):
		weapon_controller.attack_started.disconnect(_on_attack_started)
	if weapon_controller.attack_finished.is_connected(_on_attack_finished):
		weapon_controller.attack_finished.disconnect(_on_attack_finished)


func can_handle_attack(attack: WeaponAttackDefinition) -> bool:
	return CombatFootworkCatalogScript.resolve_profile_id(attack) != ""


func begin_attack(
	attack: WeaponAttackDefinition,
	direction: Vector3,
	attack_speed: float,
	_current_planar_velocity: Vector3 = Vector3.ZERO,
	requested_motion_duration: float = 0.0
) -> bool:
	if attack == null or actor == null:
		return false
	var resolved_profile_id: String = CombatFootworkCatalogScript.resolve_profile_id(attack)
	if resolved_profile_id == "":
		return false

	var planar_direction: Vector3 = direction
	planar_direction.y = 0.0
	if planar_direction.length_squared() <= 0.0001:
		planar_direction = -actor.global_transform.basis.z
		planar_direction.y = 0.0
	if planar_direction.length_squared() <= 0.0001:
		planar_direction = Vector3.FORWARD
	planar_direction = planar_direction.normalized()

	active_attack = attack
	active_profile_id = resolved_profile_id
	active_attack_speed = maxf(attack_speed, 0.05)
	motion_direction = planar_direction
	original_motion_direction = planar_direction
	motion_elapsed = 0.0
	motion_progress = 0.0
	motion_distance = maxf(attack.movement_distance, 0.0)
	var authored_duration: float = requested_motion_duration
	if authored_duration <= 0.0:
		authored_duration = attack.movement_duration
	var minimum_duration: float = profile.minimum_motion_duration if profile != null else 0.05
	var maximum_duration: float = profile.maximum_motion_duration if profile != null else 0.45
	motion_duration = clampf(authored_duration, minimum_duration, maximum_duration)

	var average_multiplier: float = CombatFootworkCatalogScript.get_average_speed_multiplier(
		active_profile_id
	)
	base_motion_speed = (
		motion_distance / maxf(motion_duration * average_multiplier, 0.001)
		if motion_distance > 0.0
		else 0.0
	)
	root_motion_active = motion_distance > 0.0 and motion_duration > 0.0
	sampled_velocity = Vector3.ZERO
	expected_distance = 0.0
	actual_distance = 0.0
	last_expected_displacement = Vector3.ZERO
	last_actual_displacement = Vector3.ZERO
	blocked_frame_count = 0
	blocked = false
	steering_angle_degrees = 0.0
	last_finish_reason = "active"
	_set_motion_phase(
		CombatFootworkCatalogScript.get_motion_phase(active_profile_id, 0.0)
		if root_motion_active
		else "planted"
	)
	footwork_started.emit(active_attack.attack_id, active_profile_id)
	return true


func sample_root_velocity(delta: float) -> Vector3:
	if not root_motion_active or active_attack == null:
		sampled_velocity = Vector3.ZERO
		last_expected_displacement = Vector3.ZERO
		return sampled_velocity
	if not _attack_is_still_current():
		finish_attack("attack_interrupted")
		return Vector3.ZERO
	if delta <= 0.0:
		return sampled_velocity

	var remaining: float = maxf(motion_duration - motion_elapsed, 0.0)
	var active_delta: float = minf(delta, remaining)
	if active_delta <= 0.0:
		root_motion_active = false
		sampled_velocity = Vector3.ZERO
		last_expected_displacement = Vector3.ZERO
		return sampled_velocity

	_apply_late_steering(delta)
	var sample_progress: float = clampf(
		(motion_elapsed + active_delta * 0.5) / maxf(motion_duration, 0.001),
		0.0,
		1.0
	)
	var speed_multiplier: float = CombatFootworkCatalogScript.sample_speed_multiplier(
		active_profile_id,
		sample_progress
	)
	var partial_frame_share: float = active_delta / maxf(delta, 0.001)
	sampled_velocity = motion_direction * base_motion_speed * speed_multiplier * partial_frame_share
	if blocked:
		sampled_velocity = Vector3.ZERO

	last_expected_displacement = sampled_velocity * delta
	motion_elapsed = minf(motion_elapsed + active_delta, motion_duration)
	motion_progress = clampf(motion_elapsed / maxf(motion_duration, 0.001), 0.0, 1.0)
	_set_motion_phase(
		CombatFootworkCatalogScript.get_motion_phase(active_profile_id, motion_progress)
	)
	if motion_elapsed >= motion_duration - 0.0001:
		root_motion_active = false
	return sampled_velocity


func record_post_move(before_position: Vector3, after_position: Vector3, _delta: float) -> void:
	if active_attack == null:
		return
	var actual_displacement: Vector3 = after_position - before_position
	actual_displacement.y = 0.0
	last_actual_displacement = actual_displacement

	var expected_length: float = last_expected_displacement.length()
	if expected_length <= 0.00001:
		return
	expected_distance += expected_length
	var projected_distance: float = maxf(actual_displacement.dot(motion_direction), 0.0)
	actual_distance += projected_distance

	var minimum_expected: float = (
		profile.minimum_expected_displacement
		if profile != null
		else 0.004
	)
	if expected_length < minimum_expected:
		return
	var travelled_ratio: float = projected_distance / maxf(expected_length, 0.0001)
	var blocked_ratio: float = profile.blocked_distance_ratio if profile != null else 0.24
	if travelled_ratio < blocked_ratio:
		blocked_frame_count += 1
	else:
		blocked_frame_count = maxi(blocked_frame_count - 1, 0)

	var blocked_frames_required: int = profile.blocked_frames_to_stop if profile != null else 2
	if (
		not blocked
		and blocked_frame_count >= blocked_frames_required
		and motion_progress < 0.98
	):
		blocked = true
		if profile == null or profile.stop_root_motion_when_blocked:
			root_motion_active = false
			sampled_velocity = Vector3.ZERO
		footwork_blocked.emit(active_attack.attack_id, motion_distance, actual_distance)


func get_visual_pose() -> Dictionary:
	if active_attack == null or active_profile_id == "":
		return {}
	var attack_elapsed: float = 0.0
	if weapon_controller != null and weapon_controller.current_attack == active_attack:
		attack_elapsed = weapon_controller.current_attack_elapsed
	else:
		var total_duration: float = active_attack.get_total_duration(active_attack_speed)
		attack_elapsed = total_duration * motion_progress
	return CombatFootworkCatalogScript.sample_attack_pose(
		active_profile_id,
		active_attack,
		attack_elapsed,
		active_attack_speed
	)


func is_root_motion_active() -> bool:
	return root_motion_active


func is_visual_footwork_active() -> bool:
	return active_attack != null and active_profile_id != ""


func apply_debug_steering(requested_direction: Vector3, delta: float) -> void:
	if requested_direction.length_squared() <= 0.0001:
		return
	_apply_steering_direction(requested_direction.normalized(), delta)


func cancel_footwork(reason: String = "cancelled") -> void:
	if active_attack == null:
		return
	finish_attack(reason)


func finish_attack(reason: String = "completed") -> void:
	if active_attack == null:
		return
	var finished_attack_id: String = active_attack.attack_id
	active_attack = null
	active_profile_id = ""
	active_attack_speed = 1.0
	root_motion_active = false
	motion_elapsed = 0.0
	motion_duration = 0.0
	motion_progress = 0.0
	motion_distance = 0.0
	base_motion_speed = 0.0
	sampled_velocity = Vector3.ZERO
	last_expected_displacement = Vector3.ZERO
	blocked_frame_count = 0
	steering_angle_degrees = 0.0
	last_finish_reason = reason
	_set_motion_phase("idle")
	footwork_finished.emit(finished_attack_id, reason)


func get_debug_data() -> Dictionary:
	return {
		"active": active_attack != null,
		"root_motion_active": root_motion_active,
		"attack_id": active_attack.attack_id if active_attack != null else "",
		"profile_id": active_profile_id,
		"profile_name": CombatFootworkCatalogScript.get_display_name(active_profile_id),
		"phase": motion_phase,
		"progress": snappedf(motion_progress, 0.01),
		"direction": motion_direction,
		"steering_angle_degrees": snappedf(steering_angle_degrees, 0.1),
		"velocity": sampled_velocity,
		"speed": snappedf(sampled_velocity.length(), 0.01),
		"requested_distance": snappedf(motion_distance, 0.01),
		"expected_distance": snappedf(expected_distance, 0.01),
		"actual_distance": snappedf(actual_distance, 0.01),
		"blocked": blocked,
		"blocked_frames": blocked_frame_count,
		"plant_foot": CombatFootworkCatalogScript.get_plant_foot(active_profile_id),
		"last_finish_reason": last_finish_reason,
		"profile_ready": profile != null,
	}


func _on_attack_started(attack: WeaponAttackDefinition) -> void:
	if attack == null or active_attack == attack or not can_handle_attack(attack):
		return
	var direction: Vector3 = -actor.global_transform.basis.z if actor != null else Vector3.FORWARD
	if weapon_controller != null and weapon_controller.has_method("get_attack_forward"):
		direction = weapon_controller.call("get_attack_forward") as Vector3
	var current_velocity: Vector3 = Vector3.ZERO
	if actor != null:
		current_velocity = Vector3(actor.velocity.x, 0.0, actor.velocity.z)
	begin_attack(
		attack,
		direction,
		weapon_controller.get_attack_speed() if weapon_controller != null else 1.0,
		current_velocity,
		attack.movement_duration
	)


func _on_attack_finished(attack_id: String) -> void:
	if active_attack != null and active_attack.attack_id == attack_id:
		finish_attack("completed")


func _attack_is_still_current() -> bool:
	if weapon_controller == null:
		return true
	return weapon_controller.current_attack == active_attack


func _apply_late_steering(delta: float) -> void:
	if profile == null:
		return
	if motion_progress < profile.steering_start or motion_progress > profile.steering_end:
		return
	var input_vector: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_back"
	)
	if input_vector.length() <= 0.08:
		return
	var requested_direction: Vector3 = _direction_from_input(input_vector)
	if requested_direction.length_squared() <= 0.0001:
		return
	_apply_steering_direction(requested_direction, delta)


func _apply_steering_direction(requested_direction: Vector3, delta: float) -> void:
	if profile == null or requested_direction.length_squared() <= 0.0001:
		return
	var style_multiplier: float = CombatFootworkCatalogScript.get_steering_multiplier(
		active_profile_id
	)
	var blend_strength: float = clampf(profile.steering_strength * style_multiplier, 0.0, 1.0)
	var blended_direction: Vector3 = motion_direction.lerp(
		requested_direction.normalized(),
		blend_strength
	)
	if blended_direction.length_squared() <= 0.0001:
		return
	blended_direction = blended_direction.normalized()
	var maximum_total_angle: float = deg_to_rad(profile.maximum_steering_degrees)
	var total_angle: float = original_motion_direction.angle_to(blended_direction)
	if total_angle > maximum_total_angle and total_angle > 0.0001:
		blended_direction = original_motion_direction.slerp(
			blended_direction,
			maximum_total_angle / total_angle
		).normalized()

	var turn_angle: float = motion_direction.angle_to(blended_direction)
	if turn_angle <= 0.0001:
		return
	var maximum_frame_turn: float = deg_to_rad(profile.steering_turn_speed_degrees) * maxf(delta, 0.0)
	var turn_weight: float = minf(1.0, maximum_frame_turn / turn_angle)
	motion_direction = motion_direction.slerp(blended_direction, turn_weight).normalized()
	steering_angle_degrees = rad_to_deg(original_motion_direction.angle_to(motion_direction))


func _direction_from_input(input_vector: Vector2) -> Vector3:
	if actor == null:
		return Vector3.ZERO
	var basis: Basis = actor.global_transform.basis.orthonormalized()
	var direction: Vector3 = basis.x * input_vector.x + basis.z * input_vector.y
	direction.y = 0.0
	return direction.normalized() if direction.length_squared() > 0.0001 else Vector3.ZERO


func _set_motion_phase(next_phase: String) -> void:
	if motion_phase == next_phase:
		return
	var previous_phase: String = motion_phase
	motion_phase = next_phase
	footwork_phase_changed.emit(previous_phase, motion_phase)
