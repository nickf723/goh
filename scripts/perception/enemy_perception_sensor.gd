extends Node
class_name EnemyPerceptionSensor

signal visibility_changed(is_visible: bool, strength: float)
signal stimulus_heard(stimulus_id: int, category: String, world_position: Vector3, intensity: float)

@export_group("Target")
@export var target_group: String = "player"
@export var eye_offset: Vector3 = Vector3(0.0, 0.85, 0.0)
@export var target_offset: Vector3 = Vector3(0.0, 0.8, 0.0)
@export_range(1.0, 40.0, 0.25) var vision_range: float = 13.0
@export_range(10.0, 180.0, 1.0) var field_of_view_degrees: float = 92.0
@export_flags_3d_physics var occlusion_collision_mask: int = 1

@export_group("Hearing")
@export_range(0.1, 4.0, 0.05) var hearing_sensitivity: float = 1.0
@export_range(0.0, 1.0, 0.01) var occluded_sound_multiplier: float = 0.38
@export_range(0.0, 1.0, 0.01) var minimum_audible_intensity: float = 0.05

@export_group("Atmosphere")
@export var obscuring_gas_id: String = "smoke"
@export_range(0.0, 4.0, 0.05) var smoke_visibility_penalty: float = 1.35
@export_range(0.05, 1.0, 0.01) var minimum_smoke_visibility_multiplier: float = 0.18

@export_group("Sampling")
@export_range(0.02, 1.0, 0.01) var sample_interval: float = 0.1
@export var show_debug_prints: bool = false

var actor: Node3D = null
var target: Node3D = null
var stimulus_manager: PerceptionStimulusManager = null
var gas_manager: Node = null
var sample_timer: float = 0.0
var vision_multiplier: float = 1.0
var hearing_multiplier: float = 1.0

var target_visible: bool = false
var visibility_strength: float = 0.0
var target_distance: float = INF
var target_angle_degrees: float = 180.0
var line_of_sight_clear: bool = false
var smoke_density: float = 0.0
var smoke_visibility_multiplier: float = 1.0
var target_stealth_multiplier: float = 1.0
var last_heard_data: Dictionary = {}
var last_processed_sample_time: float = 0.0


func _ready() -> void:
	add_to_group("enemy_perception_sensors")
	add_to_group("debuggable")
	actor = get_parent() as Node3D
	resolve_target()
	resolve_managers()


func sample_now(delta: float = 0.0, force: bool = false) -> Dictionary:
	sample_timer -= max(delta, 0.0)
	if not force and sample_timer > 0.0:
		return get_observation()
	sample_timer = max(sample_interval, 0.02)
	last_processed_sample_time = Time.get_ticks_msec() / 1000.0
	resolve_target()
	resolve_managers()
	sample_vision()
	sample_hearing()
	return get_observation()


func resolve_target() -> Node3D:
	if target != null and is_instance_valid(target):
		return target
	var found: Node = get_tree().get_first_node_in_group(target_group)
	target = found as Node3D if found is Node3D else null
	return target


func set_target(new_target: Node3D) -> void:
	target = new_target


func resolve_managers() -> void:
	if stimulus_manager == null or not is_instance_valid(stimulus_manager):
		stimulus_manager = get_tree().get_first_node_in_group("perception_stimulus_manager") as PerceptionStimulusManager
	if gas_manager == null or not is_instance_valid(gas_manager):
		gas_manager = get_tree().get_first_node_in_group("gas_manager")


func get_eye_position() -> Vector3:
	if actor == null:
		return Vector3.ZERO
	return actor.global_position + actor.global_transform.basis * eye_offset


func get_target_position() -> Vector3:
	if target == null:
		return Vector3.ZERO
	return target.global_position + target.global_transform.basis * target_offset


func sample_vision() -> void:
	var previous_visible: bool = target_visible
	target_visible = false
	visibility_strength = 0.0
	target_distance = INF
	target_angle_degrees = 180.0
	line_of_sight_clear = false
	smoke_density = 0.0
	smoke_visibility_multiplier = 1.0
	target_stealth_multiplier = 1.0

	if actor == null or target == null:
		emit_visibility_boundary(previous_visible)
		return

	var eye_position: Vector3 = get_eye_position()
	var target_position: Vector3 = get_target_position()
	var to_target: Vector3 = target_position - eye_position
	target_distance = to_target.length()
	if target_distance <= 0.01:
		target_visible = true
		visibility_strength = 1.0
		line_of_sight_clear = true
		emit_visibility_boundary(previous_visible)
		return

	smoke_density = sample_smoke_between(eye_position, target_position)
	smoke_visibility_multiplier = clampf(
		1.0 - smoke_density * smoke_visibility_penalty,
		minimum_smoke_visibility_multiplier,
		1.0
	)
	target_stealth_multiplier = get_target_stealth_multiplier()
	var effective_range: float = vision_range * max(vision_multiplier, 0.05) * smoke_visibility_multiplier * target_stealth_multiplier
	if target_distance > effective_range:
		emit_visibility_boundary(previous_visible)
		return

	var forward: Vector3 = -actor.global_transform.basis.z
	forward.y = 0.0
	var horizontal_target: Vector3 = to_target
	horizontal_target.y = 0.0
	if forward.length_squared() <= 0.0001 or horizontal_target.length_squared() <= 0.0001:
		target_angle_degrees = 0.0
	else:
		forward = forward.normalized()
		horizontal_target = horizontal_target.normalized()
		target_angle_degrees = rad_to_deg(acos(clampf(forward.dot(horizontal_target), -1.0, 1.0)))
	if target_angle_degrees > field_of_view_degrees * 0.5:
		emit_visibility_boundary(previous_visible)
		return

	line_of_sight_clear = has_clear_line(eye_position, target_position, target)
	if not line_of_sight_clear:
		emit_visibility_boundary(previous_visible)
		return

	var distance_factor: float = 1.0 - clampf(target_distance / max(effective_range, 0.01), 0.0, 1.0)
	var angle_factor: float = 1.0 - clampf(target_angle_degrees / max(field_of_view_degrees * 0.5, 0.01), 0.0, 1.0)
	visibility_strength = clampf(
		(0.25 + distance_factor * 0.55 + angle_factor * 0.2)
		* smoke_visibility_multiplier
		* target_stealth_multiplier,
		0.0,
		1.0
	)
	target_visible = visibility_strength > 0.02
	emit_visibility_boundary(previous_visible)


func get_target_stealth_multiplier() -> float:
	if target == null:
		return 1.0
	if target.has_method("get_stealth_visibility_multiplier"):
		return clampf(float(target.call("get_stealth_visibility_multiplier")), 0.05, 1.5)
	var stealth: Node = target.get_node_or_null("StealthController")
	if stealth != null and stealth.has_method("get_visibility_multiplier"):
		return clampf(float(stealth.call("get_visibility_multiplier")), 0.05, 1.5)
	return 1.0


func emit_visibility_boundary(previous_visible: bool) -> void:
	if previous_visible != target_visible:
		visibility_changed.emit(target_visible, visibility_strength)
		if show_debug_prints:
			print(actor.name if actor != null else "Enemy", " visibility: ", target_visible, " strength=", snapped(visibility_strength, 0.01))


func sample_smoke_between(start: Vector3, finish: Vector3) -> float:
	if gas_manager == null or not gas_manager.has_method("sample_density"):
		return 0.0
	var midpoint: Vector3 = start.lerp(finish, 0.5)
	var first_third: Vector3 = start.lerp(finish, 0.33)
	var second_third: Vector3 = start.lerp(finish, 0.67)
	var total: float = 0.0
	for position_value: Vector3 in [start, first_third, midpoint, second_third, finish]:
		total += float(gas_manager.call("sample_density", position_value, obscuring_gas_id))
	return total / 5.0


func sample_hearing() -> void:
	last_heard_data = {}
	if actor == null or stimulus_manager == null:
		return
	var listener_position: Vector3 = get_eye_position()
	var best_score: float = -INF
	for stimulus: PerceptionStimulus in stimulus_manager.get_active_stimuli():
		if stimulus == null:
			continue
		if stimulus.get_source() == actor:
			continue
		var audible_radius: float = stimulus.loudness * max(hearing_sensitivity * hearing_multiplier, 0.05)
		var distance: float = listener_position.distance_to(stimulus.world_position)
		if distance > audible_radius:
			continue
		var intensity: float = 1.0 - clampf(distance / max(audible_radius, 0.01), 0.0, 1.0)
		var occluded: bool = not has_clear_line(listener_position, stimulus.world_position, stimulus.get_source())
		if occluded:
			intensity *= occluded_sound_multiplier
		intensity *= stimulus.priority
		if intensity < minimum_audible_intensity:
			continue
		var score: float = intensity + stimulus.priority * 0.1
		if score <= best_score:
			continue
		best_score = score
		last_heard_data = {
			"id": stimulus.stimulus_id,
			"category": stimulus.category,
			"display_name": stimulus.display_name,
			"position": stimulus.world_position,
			"distance": distance,
			"intensity": intensity,
			"occluded": occluded,
			"source": stimulus.source_name,
		}
	if not last_heard_data.is_empty():
		stimulus_heard.emit(
			int(last_heard_data.get("id", 0)),
			str(last_heard_data.get("category", "sound")),
			last_heard_data.get("position", Vector3.ZERO) as Vector3,
			float(last_heard_data.get("intensity", 0.0))
		)


func has_clear_line(start: Vector3, finish: Vector3, intended_target: Node = null) -> bool:
	if actor == null or actor.get_world_3d() == null:
		return true
	var query := PhysicsRayQueryParameters3D.create(start, finish, occlusion_collision_mask)
	if actor is CollisionObject3D:
		query.exclude = [(actor as CollisionObject3D).get_rid()]
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var result: Dictionary = actor.get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return true
	var collider: Variant = result.get("collider")
	if intended_target != null and collider == intended_target:
		return true
	if intended_target != null and collider is Node and intended_target.is_ancestor_of(collider as Node):
		return true
	return false


func get_observation() -> Dictionary:
	return {
		"target_visible": target_visible,
		"visibility_strength": visibility_strength,
		"target_distance": target_distance,
		"target_angle_degrees": target_angle_degrees,
		"line_of_sight_clear": line_of_sight_clear,
		"smoke_density": smoke_density,
		"smoke_visibility_multiplier": smoke_visibility_multiplier,
		"stealth_visibility_multiplier": target_stealth_multiplier,
		"heard": last_heard_data.duplicate(true),
	}


func get_debug_data() -> Dictionary:
	var data: Dictionary = get_observation()
	data["enemy_perception_sensor"] = true
	data["vision_range"] = vision_range
	data["field_of_view"] = field_of_view_degrees
	data["hearing_sensitivity"] = hearing_sensitivity * hearing_multiplier
	data["target"] = target.name if target != null else "none"
	return data
