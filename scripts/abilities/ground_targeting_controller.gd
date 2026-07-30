extends RefCounted
class_name GroundTargetingController


const TargetingCatalog = preload(
	"res://scripts/abilities/spell_targeting_catalog.gd"
)
const TargetingPreview = preload(
	"res://scripts/abilities/spell_targeting_preview.gd"
)

var owner_node: Node = null
var source_player: Node3D = null
var ability: Resource = null
var config: Dictionary = {}
var targeting_profile: SpellTargetingProfile = null
var target_position: Vector3 = Vector3.ZERO
var marker: Node3D = null
var preview: SpellTargetingPreview = null
var active: bool = false
var target_valid: bool = false
var invalid_reason: String = ""
var ground_hit_valid: bool = false


func start(
	new_owner: Node,
	new_player: Node3D,
	new_ability: Resource,
	new_config: Dictionary
) -> bool:
	cancel()
	owner_node = new_owner
	source_player = new_player
	ability = new_ability
	config = new_config.duplicate(true)
	if owner_node == null or source_player == null or ability == null:
		return false
	var ability_definition: AbilityDefinition = (
		ability as AbilityDefinition if ability is AbilityDefinition else null
	)
	targeting_profile = TargetingCatalog.build_profile(
		ability_definition,
		config
	)
	if targeting_profile == null or not targeting_profile.validate_profile().is_empty():
		return false
	target_position = resolve_ground(clamp_to_range(initial_position()))
	active = true
	_evaluate_target_validity()
	ensure_marker()
	update_marker()
	return true


func update(delta: float) -> void:
	if not active:
		return
	if source_player == null or not is_instance_valid(source_player):
		cancel()
		return
	var input_vector: Vector2 = Input.get_vector(
		"camera_left",
		"camera_right",
		"camera_up",
		"camera_down"
	)
	if input_vector.length() >= get_float("deadzone", 0.18):
		var move: Vector3 = move_direction(input_vector)
		if move.length() > 0.01:
			target_position += move * get_float("speed", 8.0) * delta
			target_position = resolve_ground(clamp_to_range(target_position))
	_evaluate_target_validity()
	update_marker()


func cancel() -> void:
	if marker != null and is_instance_valid(marker):
		marker.queue_free()
	marker = null
	preview = null
	active = false
	owner_node = null
	source_player = null
	ability = null
	config = {}
	targeting_profile = null
	target_position = Vector3.ZERO
	target_valid = false
	invalid_reason = ""
	ground_hit_valid = false


func is_active() -> bool:
	return active


func is_target_valid() -> bool:
	return active and target_valid


func get_invalid_reason() -> String:
	return invalid_reason


func get_spell_key() -> String:
	return str(config.get("spell_key", ""))


func get_target_position() -> Vector3:
	return target_position


func get_ability() -> Resource:
	return ability


func get_source_player() -> Node3D:
	return source_player


func get_targeting_profile() -> SpellTargetingProfile:
	return targeting_profile


func get_target_radius() -> float:
	if targeting_profile != null:
		return targeting_profile.radius
	return get_float("radius", 2.0)


func get_cast_lock_duration(fallback: float) -> float:
	return get_float("cast_lock_duration", fallback)


func initial_position() -> Vector3:
	var forward: Vector3 = -source_player.global_transform.basis.z
	forward.y = 0.0
	if forward.length() <= 0.01:
		forward = Vector3.FORWARD
	var initial_distance: float = (
		targeting_profile.initial_distance
		if targeting_profile != null
		else get_float("initial_distance", 6.0)
	)
	return source_player.global_position + forward.normalized() * initial_distance


func clamp_to_range(raw_position: Vector3) -> Vector3:
	if source_player == null:
		return raw_position
	if targeting_profile != null and not targeting_profile.clamp_to_range:
		return raw_position
	var origin: Vector3 = source_player.global_position
	var offset: Vector3 = raw_position - origin
	offset.y = 0.0
	var target_range: float = (
		targeting_profile.maximum_range
		if targeting_profile != null
		else get_float("range", 12.0)
	)
	if target_range > 0.0 and offset.length() > target_range:
		offset = offset.normalized() * target_range
	var minimum_range: float = (
		targeting_profile.minimum_range
		if targeting_profile != null
		else 0.0
	)
	if minimum_range > 0.0 and offset.length() < minimum_range:
		var direction: Vector3 = offset.normalized()
		if direction.length() <= 0.01:
			direction = -source_player.global_transform.basis.z
			direction.y = 0.0
			direction = direction.normalized()
		offset = direction * minimum_range
	return origin + offset


func resolve_ground(raw_position: Vector3) -> Vector3:
	var resolved: Vector3 = raw_position
	ground_hit_valid = false
	var owner_3d: Node3D = owner_node as Node3D
	if owner_3d != null:
		var world_3d: World3D = owner_3d.get_world_3d()
		if world_3d != null:
			var query: PhysicsRayQueryParameters3D = (
				PhysicsRayQueryParameters3D.create(
					raw_position + Vector3.UP * 8.0,
					raw_position + Vector3.DOWN * 18.0
				)
			)
			if source_player is CollisionObject3D:
				query.exclude = [(source_player as CollisionObject3D).get_rid()]
			var result: Dictionary = world_3d.direct_space_state.intersect_ray(query)
			if result.has("position"):
				resolved = result["position"] as Vector3
				ground_hit_valid = true
	var ground_offset: float = (
		targeting_profile.ground_y_offset
		if targeting_profile != null
		else get_float("ground_y_offset", 0.05)
	)
	resolved.y += ground_offset
	return resolved


func move_direction(input_vector: Vector2) -> Vector3:
	var camera: Camera3D = null
	if owner_node != null and owner_node.get_viewport() != null:
		camera = owner_node.get_viewport().get_camera_3d()
	var right: Vector3 = Vector3.RIGHT
	var forward: Vector3 = Vector3.FORWARD
	if camera != null:
		right = camera.global_transform.basis.x
		forward = -camera.global_transform.basis.z
	elif source_player != null:
		right = source_player.global_transform.basis.x
		forward = -source_player.global_transform.basis.z
	right.y = 0.0
	forward.y = 0.0
	if right.length() <= 0.01:
		right = Vector3.RIGHT
	if forward.length() <= 0.01:
		forward = Vector3.FORWARD
	var move: Vector3 = (
		right.normalized() * input_vector.x
		+ forward.normalized() * -input_vector.y
	)
	return move.normalized() if move.length() > 0.01 else Vector3.ZERO


func ensure_marker() -> void:
	if marker != null and is_instance_valid(marker):
		return
	if (
		owner_node == null
		or owner_node.get_tree() == null
		or owner_node.get_tree().current_scene == null
		or targeting_profile == null
	):
		return
	preview = TargetingPreview.new() as SpellTargetingPreview
	preview.name = str(config.get("marker_name", "SpellTargetingPreview"))
	owner_node.get_tree().current_scene.add_child(preview)
	preview.configure(targeting_profile, source_player)
	marker = preview


func update_marker() -> void:
	if preview == null or not is_instance_valid(preview):
		return
	var direction: Vector3 = target_position - source_player.global_position
	direction.y = 0.0
	if direction.length() <= 0.01:
		direction = -source_player.global_transform.basis.z
	preview.set_preview_state(
		target_position,
		direction.normalized(),
		target_valid,
		invalid_reason
	)


func _evaluate_target_validity() -> void:
	target_valid = true
	invalid_reason = ""
	if targeting_profile == null or source_player == null:
		target_valid = false
		invalid_reason = "Targeting profile is unavailable."
		return
	if targeting_profile.require_ground and not ground_hit_valid:
		target_valid = false
		invalid_reason = "No stable ground under the target."
		return
	var flat_offset: Vector3 = target_position - source_player.global_position
	flat_offset.y = 0.0
	var distance: float = flat_offset.length()
	if (
		targeting_profile.maximum_range > 0.0
		and distance > targeting_profile.maximum_range + 0.05
	):
		target_valid = false
		invalid_reason = "Target is out of range."
		return
	if distance + 0.05 < targeting_profile.minimum_range:
		target_valid = false
		invalid_reason = "Target is too close."
		return
	if (
		targeting_profile.require_line_of_sight
		and not targeting_profile.allow_through_obstacles
		and not _has_clear_line_of_sight()
	):
		target_valid = false
		invalid_reason = "Target is obstructed."


func _has_clear_line_of_sight() -> bool:
	var owner_3d: Node3D = owner_node as Node3D
	if owner_3d == null or source_player == null:
		return false
	var world_3d: World3D = owner_3d.get_world_3d()
	if world_3d == null:
		return false
	var start: Vector3 = source_player.global_position + Vector3.UP * 0.8
	var finish: Vector3 = target_position + Vector3.UP * 0.16
	var query: PhysicsRayQueryParameters3D = (
		PhysicsRayQueryParameters3D.create(start, finish)
	)
	if source_player is CollisionObject3D:
		query.exclude = [(source_player as CollisionObject3D).get_rid()]
	var result: Dictionary = world_3d.direct_space_state.intersect_ray(query)
	if result.is_empty():
		return true
	if not result.has("position"):
		return false
	return (result["position"] as Vector3).distance_to(finish) <= 0.35


func get_float(key: String, fallback: float) -> float:
	if targeting_profile != null:
		match key:
			"radius":
				return targeting_profile.radius
			"range":
				return targeting_profile.maximum_range
			"initial_distance":
				return targeting_profile.initial_distance
			"speed":
				return targeting_profile.cursor_speed
			"deadzone":
				return targeting_profile.input_deadzone
			"ground_y_offset":
				return targeting_profile.ground_y_offset
	var value: Variant = config.get(key, fallback)
	return fallback if value == null else float(value)


func get_color(key: String, fallback: Color) -> Color:
	var value: Variant = config.get(key, fallback)
	return value as Color if value is Color else fallback


func get_debug_data() -> Dictionary:
	return {
		"active": active,
		"spell_key": get_spell_key(),
		"profile": (
			targeting_profile.get_summary()
			if targeting_profile != null
			else "none"
		),
		"shape": (
			targeting_profile.get_shape_name()
			if targeting_profile != null
			else "none"
		),
		"target_position": target_position,
		"valid": target_valid,
		"invalid_reason": invalid_reason,
		"ground_hit": ground_hit_valid,
		"preview": (
			preview.get_debug_data()
			if preview != null and is_instance_valid(preview)
			else {}
		),
	}
