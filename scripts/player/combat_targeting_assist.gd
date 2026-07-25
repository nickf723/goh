extends Node
class_name CombatTargetingAssist

signal soft_target_changed(target: Node3D)
signal hard_target_changed(target: Node3D)

@export_range(4.0, 60.0, 0.5) var hard_lock_range: float = 18.0
@export_range(2.0, 50.0, 0.5) var soft_aim_range: float = 15.0
@export_range(0.05, 0.8, 0.01) var soft_aim_screen_radius: float = 0.24
@export_range(0.02, 0.5, 0.01) var soft_refresh_interval: float = 0.08
@export_range(0.0, 20.0, 0.1) var screen_center_weight: float = 11.0
@export_range(0.0, 2.0, 0.05) var distance_weight: float = 0.42
@export_range(0.0, 20.0, 0.1) var visibility_penalty: float = 9.0
@export_range(-1.0, 1.0, 0.01) var minimum_camera_dot: float = -0.05
@export_range(-1.5, 1.5, 0.05) var camera_side_offset: float = 0.42
@export_range(0.1, 20.0, 0.1) var camera_composition_speed: float = 5.5
@export_range(-35.0, 10.0, 0.5) var dynamic_pitch_min_degrees: float = -19.0
@export_range(-10.0, 35.0, 0.5) var dynamic_pitch_max_degrees: float = 16.0
@export_range(0.0, 12.0, 0.1) var aim_height_fallback: float = 0.82
@export_range(0.1, 1.0, 0.01) var aim_height_ratio: float = 0.48
@export_range(0.1, 4.0, 0.05) var aim_height_minimum: float = 0.5
@export_range(0.2, 8.0, 0.05) var aim_height_maximum: float = 2.8

var actor: Node3D = null
var camera_pivot: Node3D = null
var base_camera_pivot_position: Vector3 = Vector3.ZERO
var soft_target: Node3D = null
var hard_target: Node3D = null
var soft_refresh_timer: float = 0.0
var soft_marker: Node3D = null
var soft_marker_material: StandardMaterial3D = null


func _ready() -> void:
	actor = get_parent() as Node3D
	if actor != null:
		camera_pivot = actor.get_node_or_null("CameraPivot") as Node3D
	if camera_pivot != null:
		base_camera_pivot_position = camera_pivot.position
	add_to_group("combat_targeting_assists")
	add_to_group("debuggable")
	_create_soft_marker()


func _process(delta: float) -> void:
	_update_camera_composition(delta)
	soft_refresh_timer -= max(delta, 0.0)
	if soft_refresh_timer <= 0.0:
		soft_refresh_timer = max(soft_refresh_interval, 0.02)
		_refresh_soft_target()
	_update_soft_marker()


func set_hard_target(target: Node3D) -> void:
	if hard_target == target:
		return
	hard_target = target
	if hard_target != null:
		_set_soft_target(null)
	hard_target_changed.emit(hard_target)


func clear_hard_target() -> void:
	if hard_target == null:
		return
	hard_target = null
	hard_target_changed.emit(null)
	soft_refresh_timer = 0.0


func find_best_hard_target(exclude_target: Node3D = null) -> Node3D:
	return _find_best_target(false, exclude_target)


func find_best_soft_target(exclude_target: Node3D = null) -> Node3D:
	return _find_best_target(true, exclude_target)


func _find_best_target(soft: bool, exclude_target: Node3D) -> Node3D:
	var camera: Camera3D = _get_camera()
	if actor == null or camera == null:
		return null

	var best_target: Node3D = null
	var best_score: float = INF
	var maximum_range: float = soft_aim_range if soft else hard_lock_range
	for candidate: Node3D in _get_candidates(soft, exclude_target):
		var aim_point: Vector3 = get_target_aim_point(candidate)
		var distance: float = actor.global_position.distance_to(aim_point)
		if distance > maximum_range:
			continue
		if camera.is_position_behind(aim_point):
			continue

		var to_target: Vector3 = aim_point - camera.global_position
		if to_target.length_squared() <= 0.0001:
			continue
		var camera_dot: float = (-camera.global_basis.z).normalized().dot(to_target.normalized())
		if camera_dot < minimum_camera_dot:
			continue

		var screen_distance: float = get_normalized_screen_distance(aim_point, camera)
		if soft and screen_distance > soft_aim_screen_radius:
			continue

		var visible: bool = is_target_visible(candidate)
		if soft and not visible:
			continue

		var score: float = (
			screen_distance * screen_center_weight
			+ distance * distance_weight
			+ (0.0 if visible else visibility_penalty)
			+ _get_target_priority_penalty(candidate)
		)
		if score < best_score:
			best_score = score
			best_target = candidate
	return best_target


func find_directional_target(current_target: Node3D, direction: int) -> Node3D:
	if current_target == null or direction == 0:
		return null
	var camera: Camera3D = _get_camera()
	if camera == null or camera.is_position_behind(get_target_aim_point(current_target)):
		return null

	var current_screen: Vector2 = camera.unproject_position(get_target_aim_point(current_target))
	var best_target: Node3D = null
	var best_score: float = INF
	for candidate: Node3D in _get_candidates(false, current_target):
		var aim_point: Vector3 = get_target_aim_point(candidate)
		if camera.is_position_behind(aim_point):
			continue
		var candidate_screen: Vector2 = camera.unproject_position(aim_point)
		var horizontal_delta: float = candidate_screen.x - current_screen.x
		if abs(horizontal_delta) <= 2.0 or sign(horizontal_delta) != sign(float(direction)):
			continue
		var vertical_penalty: float = abs(candidate_screen.y - current_screen.y) * 0.35
		var distance_penalty: float = actor.global_position.distance_to(aim_point) * 3.0
		var score: float = abs(horizontal_delta) + vertical_penalty + distance_penalty
		if score < best_score:
			best_score = score
			best_target = candidate
	return best_target


func get_hard_candidates(exclude_target: Node3D = null) -> Array[Node3D]:
	return _get_candidates(false, exclude_target)


func _get_candidates(soft: bool, exclude_target: Node3D) -> Array[Node3D]:
	var candidates: Array[Node3D] = []
	var seen: Dictionary = {}
	var groups: Array[String] = ["enemy", "combat_targetable", "lock_on_target"]
	if soft:
		var selected_spell_id: String = _get_selected_spell_id()
		if selected_spell_id == "metal_tether":
			groups.append("metal_tether_anchors")
		elif selected_spell_id == "soul_grip":
			groups.append("soul_manipulable")

	for group_name: String in groups:
		for raw_candidate: Node in get_tree().get_nodes_in_group(group_name):
			var candidate: Node3D = _resolve_target_node(raw_candidate)
			if candidate == null or candidate == actor or candidate == exclude_target:
				continue
			if not is_instance_valid(candidate) or _is_target_defeated(candidate):
				continue
			var candidate_id: int = candidate.get_instance_id()
			if seen.has(candidate_id):
				continue
			seen[candidate_id] = true
			candidates.append(candidate)
	return candidates


func _resolve_target_node(candidate: Node) -> Node3D:
	if candidate == null:
		return null
	if candidate is Node3D:
		return candidate as Node3D
	if candidate.has_method("get_targeting_node"):
		var targeting_node: Variant = candidate.call("get_targeting_node")
		if targeting_node is Node3D:
			return targeting_node as Node3D
	var cursor: Node = candidate.get_parent()
	while cursor != null and cursor != get_tree().current_scene:
		if cursor is Node3D:
			return cursor as Node3D
		cursor = cursor.get_parent()
	return null


func get_target_aim_point(target: Node3D) -> Vector3:
	if target == null:
		return actor.global_position if actor != null else Vector3.ZERO
	if target.has_method("get_targeting_aim_point"):
		var custom_point: Variant = target.call("get_targeting_aim_point")
		if custom_point is Vector3:
			return custom_point as Vector3
	if target.has_method("get_tether_anchor_position"):
		var anchor_point: Variant = target.call("get_tether_anchor_position")
		if anchor_point is Vector3:
			return anchor_point as Vector3
	return target.global_position + Vector3.UP * _get_target_center_mass_height(target)


func get_soft_aim_direction(origin: Vector3) -> Vector3:
	if soft_target == null or not is_instance_valid(soft_target):
		return Vector3.ZERO
	var direction: Vector3 = get_target_aim_point(soft_target) - origin
	return direction.normalized() if direction.length_squared() > 0.0001 else Vector3.ZERO


func get_dynamic_camera_pitch(target: Node3D) -> float:
	if target == null or camera_pivot == null:
		return deg_to_rad(-12.0)
	var aim_point: Vector3 = get_target_aim_point(target)
	var offset: Vector3 = aim_point - camera_pivot.global_position
	var horizontal_distance: float = Vector2(offset.x, offset.z).length()
	if horizontal_distance <= 0.01:
		return deg_to_rad(-12.0)
	var pitch: float = atan2(offset.y, horizontal_distance) - deg_to_rad(4.0)
	return clampf(
		pitch,
		deg_to_rad(dynamic_pitch_min_degrees),
		deg_to_rad(dynamic_pitch_max_degrees)
	)


func is_target_visible(target: Node3D) -> bool:
	var camera: Camera3D = _get_camera()
	if target == null or actor == null or camera == null:
		return false
	var world: World3D = actor.get_world_3d()
	if world == null:
		return false
	var query := PhysicsRayQueryParameters3D.create(
		camera.global_position,
		get_target_aim_point(target)
	)
	if actor is CollisionObject3D:
		query.exclude = [(actor as CollisionObject3D).get_rid()]
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var collider: Node = hit.get("collider") as Node
	if collider == null:
		return false
	return (
		collider == target
		or target.is_ancestor_of(collider)
		or collider.is_ancestor_of(target)
	)


func is_target_on_screen(target: Node3D) -> bool:
	var camera: Camera3D = _get_camera()
	if target == null or camera == null:
		return false
	var aim_point: Vector3 = get_target_aim_point(target)
	if camera.is_position_behind(aim_point):
		return false
	var screen: Vector2 = camera.unproject_position(aim_point)
	var viewport_size: Vector2 = camera.get_viewport().get_visible_rect().size
	return Rect2(Vector2.ZERO, viewport_size).grow(48.0).has_point(screen)


func get_normalized_screen_distance(world_position: Vector3, camera: Camera3D = null) -> float:
	var resolved_camera: Camera3D = camera if camera != null else _get_camera()
	if resolved_camera == null:
		return INF
	var viewport_size: Vector2 = resolved_camera.get_viewport().get_visible_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return INF
	var center: Vector2 = viewport_size * 0.5
	var screen: Vector2 = resolved_camera.unproject_position(world_position)
	return (screen - center).length() / max(center.length(), 1.0)


func get_target_display_name(target: Node) -> String:
	if target == null:
		return "Target"
	if "display_name" in target:
		var authored_name: String = str(target.get("display_name")).strip_edges()
		if authored_name != "":
			return authored_name
	var brain: Node = target.get_node_or_null("EnemyBrain")
	if brain != null and brain.has_method("get_definition"):
		var definition: Variant = brain.call("get_definition")
		if definition != null and "display_name" in definition:
			return str(definition.get("display_name"))
	return target.name.capitalize()


func get_target_color(target: Node3D, soft: bool = false) -> Color:
	if target == null:
		return Color(0.62, 0.82, 1.0, 0.7)
	if target.is_in_group("boss") or target.name.to_lower().contains("boss"):
		return Color(1.0, 0.28, 0.68, 0.96)
	if target.is_in_group("metal_tether_anchors"):
		return Color(0.34, 0.86, 1.0, 0.82)
	if _target_has_group_in_tree(target, "soul_manipulable"):
		return Color(0.74, 0.46, 1.0, 0.82)
	if soft:
		return Color(0.48, 0.78, 1.0, 0.68)
	return Color(1.0, 0.76, 0.12, 0.92)


func _refresh_soft_target() -> void:
	if hard_target != null and is_instance_valid(hard_target):
		_set_soft_target(null)
		return
	_set_soft_target(find_best_soft_target())


func _set_soft_target(target: Node3D) -> void:
	if soft_target == target:
		return
	soft_target = target
	soft_target_changed.emit(soft_target)


func _create_soft_marker() -> void:
	if soft_marker != null:
		return
	soft_marker = Node3D.new()
	soft_marker.name = "SoftAimMarker"
	soft_marker.visible = false
	add_child(soft_marker)

	var ring := MeshInstance3D.new()
	ring.name = "AimRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.24
	torus.outer_radius = 0.29
	torus.rings = 20
	torus.ring_segments = 7
	ring.mesh = torus
	ring.rotation_degrees.x = 90.0
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	soft_marker_material = StandardMaterial3D.new()
	soft_marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	soft_marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	soft_marker_material.emission_enabled = true
	soft_marker_material.emission_energy_multiplier = 1.6
	ring.material_override = soft_marker_material
	soft_marker.add_child(ring)


func _update_soft_marker() -> void:
	if soft_marker == null:
		return
	if soft_target == null or not is_instance_valid(soft_target) or hard_target != null:
		soft_marker.visible = false
		return
	var camera: Camera3D = _get_camera()
	if camera == null:
		soft_marker.visible = false
		return
	soft_marker.visible = true
	soft_marker.global_position = get_target_aim_point(soft_target)
	soft_marker.look_at(camera.global_position, Vector3.UP)
	var color: Color = get_target_color(soft_target, true)
	soft_marker_material.albedo_color = color
	soft_marker_material.emission = Color(color.r, color.g, color.b, 1.0)
	var pulse_age: float = float(Time.get_ticks_msec()) * 0.001
	soft_marker.scale = Vector3.ONE * (0.86 + sin(pulse_age * 4.0) * 0.07)


func _update_camera_composition(delta: float) -> void:
	if camera_pivot == null:
		return
	var desired_position: Vector3 = base_camera_pivot_position
	if hard_target != null and is_instance_valid(hard_target):
		desired_position.x += camera_side_offset
	camera_pivot.position = camera_pivot.position.lerp(
		desired_position,
		clampf(camera_composition_speed * max(delta, 0.0), 0.0, 1.0)
	)


func _get_camera() -> Camera3D:
	if actor == null:
		return null
	var viewport_camera: Camera3D = actor.get_viewport().get_camera_3d()
	if viewport_camera != null:
		return viewport_camera
	if camera_pivot != null:
		return camera_pivot.get_node_or_null("SpringArm3D/Camera3D") as Camera3D
	return null


func _get_selected_spell_id() -> String:
	if actor == null:
		return ""
	var caster: Node = actor.get_node_or_null("AbilityCaster")
	if caster == null or not caster.has_method("get_current_ability"):
		return ""
	var ability: Variant = caster.call("get_current_ability")
	if ability == null:
		return ""
	if ability.has_method("get_spell_id"):
		return str(ability.call("get_spell_id"))
	return str(ability.get("spell_id"))


func _get_target_center_mass_height(target: Node3D) -> float:
	var body_height: float = _get_target_collision_height(target)
	if body_height <= 0.01:
		return aim_height_fallback
	return clampf(
		body_height * aim_height_ratio,
		aim_height_minimum,
		aim_height_maximum
	)


func _get_target_collision_height(node: Node) -> float:
	if node == null:
		return 0.0
	var best_height: float = 0.0
	if node is CollisionShape3D:
		best_height = maxf(
			best_height,
			_get_shape_height((node as CollisionShape3D).shape)
		)
	for child: Node in node.get_children():
		best_height = maxf(best_height, _get_target_collision_height(child))
	return best_height


func _get_shape_height(shape: Shape3D) -> float:
	if shape is CapsuleShape3D:
		return maxf((shape as CapsuleShape3D).height, (shape as CapsuleShape3D).radius * 2.0)
	if shape is BoxShape3D:
		return (shape as BoxShape3D).size.y
	if shape is SphereShape3D:
		return (shape as SphereShape3D).radius * 2.0
	if shape is CylinderShape3D:
		return (shape as CylinderShape3D).height
	return 0.0


func _is_target_defeated(target: Node) -> bool:
	if target == null:
		return true
	var hit_receiver: Node = target.get_node_or_null("HitReceiver")
	if hit_receiver == null:
		return false
	var current_health: Variant = hit_receiver.get("current_health")
	return current_health != null and int(current_health) <= 0


func _get_target_priority_penalty(target: Node3D) -> float:
	if target.is_in_group("boss") or target.name.to_lower().contains("boss"):
		return -3.0
	if target.is_in_group("enemy"):
		return -1.0
	if target.is_in_group("metal_tether_anchors"):
		return 0.5
	return 0.0


func _target_has_group_in_tree(target: Node, group_name: String) -> bool:
	if target == null:
		return false
	if target.is_in_group(group_name):
		return true
	for child: Node in target.get_children():
		if _target_has_group_in_tree(child, group_name):
			return true
	return false


func get_debug_data() -> Dictionary:
	return {
		"hard_target": get_target_display_name(hard_target) if hard_target != null else "none",
		"soft_target": get_target_display_name(soft_target) if soft_target != null else "none",
		"hard_candidates": _get_candidates(false, null).size(),
		"soft_candidates": _get_candidates(true, null).size(),
		"hard_visible": is_target_visible(hard_target) if hard_target != null else false,
		"soft_screen_distance": get_normalized_screen_distance(get_target_aim_point(soft_target))
			if soft_target != null else -1.0,
	}
