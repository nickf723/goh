extends Node3D
class_name EnvironmentalMotionInfluencer3D

@export var channel: String = "world"
@export var active: bool = true
@export_range(0.2, 5.0, 0.05) var radius: float = 1.75
@export_range(0.0, 1.5, 0.05) var body_radius: float = 0.35
@export_range(0.5, 5.0, 0.05) var vertical_half_extent: float = 1.55
@export_range(0.0, 2.5, 0.01) var base_strength: float = 0.46
@export_range(0.0, 2.0, 0.01) var velocity_strength: float = 0.52
@export_range(0.5, 16.0, 0.1) var velocity_reference: float = 5.5
@export_range(0.0, 3.0, 0.01) var maximum_strength: float = 1.45
@export_range(0.0, 1.0, 0.01) var wake_direction_influence: float = 0.32

var actor: CharacterBody3D = null
var last_sample_strength: float = 0.0
var last_speed_ratio: float = 0.0
var sample_count: int = 0


func _ready() -> void:
	actor = get_parent() as CharacterBody3D
	add_to_group("environmental_motion_influencer")
	add_to_group("debuggable")
	set_meta("environmental_motion_channel", channel)


func sample_influence(world_position: Vector3) -> Dictionary:
	if not active:
		return _empty_sample()
	var offset: Vector3 = world_position - global_position
	if absf(offset.y) > maxf(vertical_half_extent, 0.05):
		return _empty_sample()

	var horizontal := Vector3(offset.x, 0.0, offset.z)
	var distance: float = horizontal.length()
	var safe_radius: float = maxf(radius, body_radius + 0.05)
	if distance >= safe_radius:
		return _empty_sample()

	var radial_direction: Vector3 = Vector3.RIGHT
	if horizontal.length_squared() > 0.000001:
		radial_direction = horizontal.normalized()
	elif actor != null:
		var fallback: Vector3 = -actor.global_basis.z
		fallback.y = 0.0
		if fallback.length_squared() > 0.000001:
			radial_direction = fallback.normalized()

	var velocity: Vector3 = Vector3.ZERO
	if actor != null and is_instance_valid(actor):
		velocity = Vector3(actor.velocity.x, 0.0, actor.velocity.z)
	var speed_ratio: float = clampf(
		velocity.length() / maxf(velocity_reference, 0.1),
		0.0,
		2.0
	)
	var wake_direction: Vector3 = radial_direction
	if velocity.length_squared() > 0.000001:
		wake_direction = velocity.normalized()
	var wake_mix: float = clampf(
		wake_direction_influence * speed_ratio,
		0.0,
		0.72
	)
	var resolved_direction: Vector3 = radial_direction.lerp(
		wake_direction,
		wake_mix
	)
	if resolved_direction.length_squared() <= 0.000001:
		resolved_direction = radial_direction
	resolved_direction = resolved_direction.normalized()

	var normalized_distance: float = clampf(
		(distance - minf(body_radius, safe_radius - 0.01))
		/ maxf(safe_radius - body_radius, 0.05),
		0.0,
		1.0
	)
	var radial_weight: float = 1.0 - normalized_distance
	radial_weight = radial_weight * radial_weight * (3.0 - 2.0 * radial_weight)
	if distance <= body_radius:
		radial_weight = 1.0

	var vertical_weight: float = 1.0 - clampf(
		absf(offset.y) / maxf(vertical_half_extent, 0.05),
		0.0,
		1.0
	)
	vertical_weight = smoothstep(0.0, 1.0, vertical_weight)
	var strength: float = clampf(
		(base_strength + speed_ratio * velocity_strength)
		* radial_weight
		* vertical_weight,
		0.0,
		maximum_strength
	)
	last_sample_strength = strength
	last_speed_ratio = speed_ratio
	sample_count += 1
	return {
		"direction": resolved_direction,
		"strength": strength,
		"speed_ratio": speed_ratio,
		"distance": distance,
	}


func _empty_sample() -> Dictionary:
	return {
		"direction": Vector3.ZERO,
		"strength": 0.0,
		"speed_ratio": 0.0,
		"distance": INF,
	}


func get_debug_data() -> Dictionary:
	return {
		"environmental_motion_influencer": true,
		"channel": channel,
		"active": active,
		"radius": radius,
		"body_radius": body_radius,
		"velocity_reference": velocity_reference,
		"last_sample_strength": snappedf(last_sample_strength, 0.01),
		"last_speed_ratio": snappedf(last_speed_ratio, 0.01),
		"sample_count": sample_count,
		"presentation_only": true,
		"applies_gameplay_force": false,
	}
