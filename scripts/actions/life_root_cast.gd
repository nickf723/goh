extends Node3D
class_name LifeRootCast

const RootBindingScene: PackedScene = preload(
	"res://scenes/actions/life_root_binding.tscn"
)

@export_group("Targeting")
@export_range(2.0, 40.0, 0.5) var maximum_range: float = 18.0
@export_range(5.0, 80.0, 1.0) var soft_aim_angle_degrees: float = 24.0
@export_range(1.0, 2000.0, 1.0) var maximum_rigidbody_mass: float = 520.0
@export var require_line_of_sight: bool = true

@export_group("Binding")
@export_range(0.5, 12.0, 0.05) var enemy_duration: float = 3.25
@export_range(0.5, 20.0, 0.05) var object_duration: float = 6.0

var source_actor: Node3D = null
var last_target: Node3D = null
var last_target_kind: String = "none"


func _ready() -> void:
	add_to_group("debuggable")


func set_source_actor(actor: Node) -> void:
	if actor is Node3D:
		source_actor = actor as Node3D


func execute(player: Node3D, cast_direction: Vector3) -> void:
	if source_actor == null:
		source_actor = player
	if source_actor == null or not is_instance_valid(source_actor):
		queue_free()
		return

	var result: Dictionary = find_root_target(cast_direction)
	var target: Node3D = _valid_node3d_reference(result.get("target"))
	if target == null:
		show_message("Roots found nothing they can bind.")
		queue_free()
		return

	if not can_root_target(target):
		show_message(target.name.capitalize() + " cannot be rooted.")
		queue_free()
		return

	last_target = target
	last_target_kind = "object" if target is RigidBody3D else "enemy"
	var duration: float = object_duration if target is RigidBody3D else enemy_duration
	if bind_target(target, duration):
		show_message("Roots bind " + get_target_display_name(target) + ".")
	else:
		show_message("The roots fail to take hold.")
	queue_free()


func bind_target(target: Node3D, duration: float) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var existing: Node = target.get_node_or_null("LifeRootBinding")
	if existing != null and is_instance_valid(existing) and existing.has_method("refresh_binding"):
		existing.call("refresh_binding", duration, source_actor)
		return true

	var binding: LifeRootBinding = RootBindingScene.instantiate() as LifeRootBinding
	if binding == null:
		return false
	binding.name = "LifeRootBinding"
	target.add_child(binding)
	if not binding.bind_to_target(target, duration, source_actor):
		binding.queue_free()
		return false
	return true


func find_root_target(cast_direction: Vector3) -> Dictionary:
	if source_actor == null or get_tree() == null:
		return {}

	var hard_target: Node3D = get_hard_target()
	if hard_target != null and can_root_target(hard_target):
		return {"target": hard_target, "source": "hard_lock"}

	var direct: Dictionary = raycast_camera_target()
	if not direct.is_empty():
		return direct

	var assist: Node = source_actor.get_node_or_null("CombatTargetingAssist")
	if assist != null and is_instance_valid(assist):
		var soft_target: Node3D = _valid_node3d_reference(assist.get("soft_target"))
		if soft_target != null and can_root_target(soft_target):
			if not require_line_of_sight or has_line_of_sight(soft_target):
				return {"target": soft_target, "source": "soft_assist"}

	return scan_enemy_target(cast_direction)


func raycast_camera_target() -> Dictionary:
	var camera: Camera3D = source_actor.get_viewport().get_camera_3d()
	var world: World3D = source_actor.get_world_3d()
	if camera == null or world == null:
		return {}
	var viewport_rect: Rect2 = camera.get_viewport().get_visible_rect()
	var screen_center: Vector2 = viewport_rect.position + viewport_rect.size * 0.5
	var origin: Vector3 = camera.project_ray_origin(screen_center)
	var direction: Vector3 = camera.project_ray_normal(screen_center)
	if direction.length_squared() <= 0.0001:
		return {}
	var query := PhysicsRayQueryParameters3D.create(
		origin,
		origin + direction.normalized() * maximum_range
	)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = get_source_collision_exclusions()
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}
	var candidate: Node3D = resolve_root_target(hit.get("collider") as Node)
	if candidate == null or not can_root_target(candidate):
		return {}
	return {"target": candidate, "source": "direct"}


func scan_enemy_target(cast_direction: Vector3) -> Dictionary:
	var origin: Vector3 = get_cast_origin()
	var direction: Vector3 = cast_direction
	if direction.length_squared() <= 0.0001:
		var camera: Camera3D = source_actor.get_viewport().get_camera_3d()
		direction = -camera.global_basis.z if camera != null else -source_actor.global_basis.z
	if direction.length_squared() <= 0.0001:
		return {}
	direction = direction.normalized()
	var minimum_dot: float = cos(deg_to_rad(soft_aim_angle_degrees))
	var best_target: Node3D = null
	var best_score: float = INF

	for raw_candidate: Node in get_tree().get_nodes_in_group("enemy"):
		var candidate: Node3D = _valid_node3d_reference(raw_candidate)
		if candidate == null or not can_root_target(candidate):
			continue
		var point: Vector3 = get_target_point(candidate)
		var offset: Vector3 = point - origin
		var distance: float = offset.length()
		if distance <= 0.1 or distance > maximum_range:
			continue
		var dot: float = direction.dot(offset.normalized())
		if dot < minimum_dot:
			continue
		if require_line_of_sight and not has_line_of_sight(candidate):
			continue
		var score: float = (1.0 - dot) * 18.0 + distance / maximum_range
		if score < best_score:
			best_score = score
			best_target = candidate

	return {"target": best_target, "source": "soft_scan"} if best_target != null else {}


func can_root_target(target: Node3D) -> bool:
	if target == null or not is_instance_valid(target) or target == source_actor:
		return false
	if target.is_in_group("root_trap_immune"):
		return false
	if target.has_method("can_accept_root_trap"):
		return bool(target.call("can_accept_root_trap", source_actor))
	if target.is_in_group("root_trappable"):
		return true
	if target is RigidBody3D:
		return (target as RigidBody3D).mass <= maximum_rigidbody_mass
	if target is CharacterBody3D and target.is_in_group("enemy"):
		return true
	return target.get_node_or_null("StatusReceiver") != null and target.is_in_group("enemy")


func resolve_root_target(start_node: Node) -> Node3D:
	var current: Node = start_node
	while current != null and current != source_actor:
		if current is Node3D and can_root_target(current as Node3D):
			return current as Node3D
		current = current.get_parent()
	return null


func get_hard_target() -> Node3D:
	var lock_target: Node3D = _valid_node3d_reference(source_actor.get("lock_on_target"))
	if lock_target != null:
		return lock_target
	var assist: Node = source_actor.get_node_or_null("CombatTargetingAssist")
	if assist == null or not is_instance_valid(assist):
		return null
	return _valid_node3d_reference(assist.get("hard_target"))


func has_line_of_sight(target: Node3D) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var world: World3D = source_actor.get_world_3d()
	if world == null:
		return false
	var camera: Camera3D = source_actor.get_viewport().get_camera_3d()
	var origin: Vector3 = camera.global_position if camera != null else get_cast_origin()
	var query := PhysicsRayQueryParameters3D.create(origin, get_target_point(target))
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = get_source_collision_exclusions()
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var collider: Node = hit.get("collider") as Node
	var resolved: Node3D = resolve_root_target(collider)
	return resolved == target


func get_target_point(target: Node3D) -> Vector3:
	if target == null or not is_instance_valid(target):
		return get_cast_origin()
	var assist: Node = source_actor.get_node_or_null("CombatTargetingAssist")
	if assist != null and assist.has_method("get_target_aim_point"):
		var point_value: Variant = assist.call("get_target_aim_point", target)
		if point_value is Vector3:
			return point_value as Vector3
	return target.global_position + Vector3.UP * 0.55


func get_cast_origin() -> Vector3:
	for anchor_path: String in [
		"GraceVisualV1/RightHandAnchor",
		"RightHandAnchor",
		"CastingHandAnchor",
	]:
		var anchor: Node3D = source_actor.get_node_or_null(anchor_path) as Node3D
		if anchor != null:
			return anchor.global_position
	return source_actor.global_position + Vector3.UP * 0.72


func get_source_collision_exclusions() -> Array[RID]:
	var exclusions: Array[RID] = []
	collect_collision_rids(source_actor, exclusions)
	return exclusions


func collect_collision_rids(node: Node, exclusions: Array[RID]) -> void:
	if node == null:
		return
	if node is CollisionObject3D:
		var rid: RID = (node as CollisionObject3D).get_rid()
		if rid.is_valid() and not exclusions.has(rid):
			exclusions.append(rid)
	for child: Node in node.get_children():
		collect_collision_rids(child, exclusions)


func _valid_node3d_reference(value: Variant) -> Node3D:
	if typeof(value) != TYPE_OBJECT:
		return null
	if not is_instance_valid(value):
		return null
	return value as Node3D if value is Node3D else null


func get_target_display_name(target: Node) -> String:
	if target == null:
		return "target"
	var display_value: Variant = target.get("display_name")
	if display_value != null and str(display_value).strip_edges() != "":
		return str(display_value)
	return target.name.capitalize()


func show_message(text: String) -> void:
	if get_tree() == null:
		return
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)


func get_debug_data() -> Dictionary:
	return {
		"spell": "root_bind",
		"target": get_target_display_name(last_target) if last_target != null and is_instance_valid(last_target) else "none",
		"target_kind": last_target_kind,
		"enemy_duration": enemy_duration,
		"object_duration": object_duration,
		"maximum_rigidbody_mass": maximum_rigidbody_mass,
		"preserves_enemy_actions": true,
	}
