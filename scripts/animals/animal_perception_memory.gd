extends RefCounted
class_name AnimalPerceptionMemory

var species_id: String = ""
var sight_range: float = 12.0
var hearing_range: float = 10.0
var field_of_view_degrees: float = 180.0
var memory_duration: float = 4.0
var can_see_target: bool = false
var can_hear_target: bool = false
var remembers_target: bool = false
var last_known_position: Vector3 = Vector3.ZERO
var last_seen_position: Vector3 = Vector3.ZERO
var last_heard_position: Vector3 = Vector3.ZERO
var memory_remaining: float = 0.0
var awareness: float = 0.0
var stimulus_kind: String = "none"
var social_alert_remaining: float = 0.0
var social_alert_position: Vector3 = Vector3.ZERO
var social_alert_severity: float = 0.0


static func create_for_species(
	new_species_id: String,
	traits: Dictionary = {}
) -> AnimalPerceptionMemory:
	var state := AnimalPerceptionMemory.new()
	state.configure(new_species_id, traits)
	return state


func configure(new_species_id: String, traits: Dictionary = {}) -> void:
	species_id = new_species_id.to_lower().strip_edges()
	var species: MobSpeciesDefinition = MobSpeciesCatalog.get_definition(species_id)
	var stats: Dictionary = species.base_stats if species != null else {}
	sight_range = maxf(float(stats.get("sight", 12.0)), 2.0)
	hearing_range = maxf(float(stats.get("hearing", 10.0)), 2.0)
	var curiosity: float = clampf(float(traits.get("curiosity", 0.5)), 0.0, 1.0)
	var courage: float = clampf(float(traits.get("courage", 0.5)), 0.0, 1.0)
	var patience: float = clampf(float(traits.get("patience", 0.5)), 0.0, 1.0)
	match species_id:
		"sheep":
			field_of_view_degrees = 292.0
		"capybara":
			field_of_view_degrees = 248.0
		"wolf":
			field_of_view_degrees = 168.0
		_:
			field_of_view_degrees = 190.0
	field_of_view_degrees = clampf(
		field_of_view_degrees + (curiosity - 0.5) * 18.0,
		90.0,
		330.0
	)
	memory_duration = 2.5 + patience * 3.0 + (1.0 - courage) * 1.5
	reset()


func reset() -> void:
	can_see_target = false
	can_hear_target = false
	remembers_target = false
	last_known_position = Vector3.ZERO
	last_seen_position = Vector3.ZERO
	last_heard_position = Vector3.ZERO
	memory_remaining = 0.0
	awareness = 0.0
	stimulus_kind = "none"
	social_alert_remaining = 0.0
	social_alert_position = Vector3.ZERO
	social_alert_severity = 0.0


func update(
	observer: Node3D,
	target: Node3D,
	delta: float,
	noise_position: Vector3 = Vector3.ZERO,
	noise_strength: float = 0.0,
	target_speed: float = 0.0
) -> Dictionary:
	memory_remaining = maxf(memory_remaining - delta, 0.0)
	social_alert_remaining = maxf(social_alert_remaining - delta, 0.0)
	if social_alert_remaining <= 0.0:
		social_alert_severity = 0.0
	can_see_target = false
	can_hear_target = false
	if observer != null and target != null:
		var distance: float = observer.global_position.distance_to(target.global_position)
		can_see_target = (
			distance <= sight_range
			and _inside_view_cone(observer, target.global_position)
			and _has_line_of_sight(observer, target)
		)
		var movement_noise: float = clampf(target_speed / 5.0, 0.0, 1.0)
		var audible_range: float = hearing_range * (0.32 + movement_noise * 0.68)
		if target_speed >= 0.45 and distance <= audible_range:
			can_hear_target = true
			last_heard_position = target.global_position
		if noise_strength > 0.0:
			var noise_distance: float = observer.global_position.distance_to(noise_position)
			if noise_distance <= hearing_range * clampf(noise_strength, 0.2, 2.0):
				can_hear_target = true
				last_heard_position = noise_position
		if can_see_target:
			last_seen_position = target.global_position
			last_known_position = target.global_position
			memory_remaining = memory_duration
			stimulus_kind = "sight"
		elif can_hear_target:
			last_known_position = last_heard_position
			memory_remaining = maxf(memory_remaining, memory_duration * 0.72)
			stimulus_kind = "hearing"
	elif noise_strength > 0.0 and observer != null:
		var noise_distance: float = observer.global_position.distance_to(noise_position)
		if noise_distance <= hearing_range * clampf(noise_strength, 0.2, 2.0):
			can_hear_target = true
			last_heard_position = noise_position
			last_known_position = noise_position
			memory_remaining = maxf(memory_remaining, memory_duration * 0.72)
			stimulus_kind = "hearing"

	if not can_see_target and not can_hear_target and social_alert_remaining > 0.0:
		last_known_position = social_alert_position
		memory_remaining = maxf(memory_remaining, social_alert_remaining)
		stimulus_kind = "social_alert"
	remembers_target = memory_remaining > 0.0
	if not can_see_target and not can_hear_target and social_alert_remaining <= 0.0:
		stimulus_kind = "memory" if remembers_target else "none"
	var awareness_target: float = 0.0
	if can_see_target:
		awareness_target = 1.0
	elif can_hear_target:
		awareness_target = 0.78
	elif social_alert_remaining > 0.0:
		awareness_target = clampf(0.45 + social_alert_severity * 0.45, 0.0, 1.0)
	elif remembers_target:
		awareness_target = clampf(memory_remaining / maxf(memory_duration, 0.01), 0.0, 0.7)
	awareness = move_toward(
		awareness,
		awareness_target,
		delta * (2.6 if awareness_target > awareness else 0.42)
	)
	return to_dictionary()


func receive_social_alert(
	position: Vector3,
	severity: float = 0.65,
	duration: float = 3.0
) -> void:
	social_alert_position = position
	social_alert_severity = maxf(social_alert_severity, clampf(severity, 0.0, 1.0))
	social_alert_remaining = maxf(social_alert_remaining, maxf(duration, 0.0))
	last_known_position = position
	memory_remaining = maxf(memory_remaining, social_alert_remaining)
	remembers_target = memory_remaining > 0.0
	stimulus_kind = "social_alert"
	awareness = maxf(awareness, 0.45 + social_alert_severity * 0.4)


func get_target_position(fallback: Vector3 = Vector3.ZERO) -> Vector3:
	return last_known_position if remembers_target else fallback


func to_dictionary() -> Dictionary:
	return {
		"species_id": species_id,
		"sight_range": sight_range,
		"hearing_range": hearing_range,
		"field_of_view_degrees": field_of_view_degrees,
		"memory_duration": memory_duration,
		"can_see_target": can_see_target,
		"can_hear_target": can_hear_target,
		"remembers_target": remembers_target,
		"last_known_position": last_known_position,
		"last_seen_position": last_seen_position,
		"last_heard_position": last_heard_position,
		"memory_remaining": memory_remaining,
		"awareness": awareness,
		"stimulus_kind": stimulus_kind,
		"social_alert_remaining": social_alert_remaining,
		"social_alert_severity": social_alert_severity,
	}


func _inside_view_cone(observer: Node3D, target_position: Vector3) -> bool:
	if field_of_view_degrees >= 359.0:
		return true
	var offset: Vector3 = target_position - observer.global_position
	offset.y = 0.0
	if offset.length_squared() <= 0.0001:
		return true
	var forward: Vector3 = -observer.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.0001:
		return true
	forward = forward.normalized()
	var direction: Vector3 = offset.normalized()
	var threshold: float = cos(deg_to_rad(field_of_view_degrees * 0.5))
	return forward.dot(direction) >= threshold


func _has_line_of_sight(observer: Node3D, target: Node3D) -> bool:
	var world: World3D = observer.get_world_3d()
	if world == null:
		return true
	var start: Vector3 = observer.global_position + Vector3.UP * 1.0
	var finish: Vector3 = target.global_position + Vector3.UP * 0.9
	var query := PhysicsRayQueryParameters3D.create(start, finish)
	if observer is CollisionObject3D:
		query.exclude = [(observer as CollisionObject3D).get_rid()]
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var result: Dictionary = world.direct_space_state.intersect_ray(query)
	if result.is_empty():
		return true
	var collider: Variant = result.get("collider")
	if collider == target:
		return true
	if collider is Node and target.is_ancestor_of(collider as Node):
		return true
	return false
