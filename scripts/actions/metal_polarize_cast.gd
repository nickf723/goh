extends Node3D
class_name MetalPolarizeCast

signal polarize_link_created(first: Node3D, second: Node3D)
signal polarize_link_broken(reason: String)

@export_group("Targeting")
@export_range(2.0, 40.0, 0.5) var maximum_range: float = 18.0
@export_range(1.0, 20.0, 0.25) var secondary_search_radius: float = 7.0
@export_range(3.0, 50.0, 1.0) var soft_aim_angle_degrees: float = 14.0
@export_range(1.0, 5000.0, 1.0) var maximum_rigidbody_mass: float = 900.0
@export_flags_3d_physics var collision_mask: int = 1

@export_group("Magnetic Bond")
@export_range(0.25, 4.0, 0.05) var target_separation: float = 0.75
@export_range(1.0, 120.0, 1.0) var spring_strength: float = 34.0
@export_range(0.0, 30.0, 0.5) var damping_strength: float = 6.0
@export_range(1.0, 400.0, 1.0) var maximum_force: float = 110.0
@export_range(1.0, 30.0, 0.5) var break_distance: float = 16.0
@export_range(0.5, 30.0, 0.25) var duration: float = 10.0

@export_group("Presentation")
@export var bond_color: Color = Color(1.0, 0.82, 0.16, 0.82)
@export var show_debug_messages: bool = false

var source_actor: Node3D = null
var first_target: Node3D = null
var second_target: Node3D = null
var elapsed: float = 0.0
var active: bool = false
var last_force: float = 0.0
var last_distance: float = 0.0
var target_source: String = "none"
var beam: MeshInstance3D = null
var beam_material: StandardMaterial3D = null
var source_exclusions: Array[RID] = []


func _ready() -> void:
	add_to_group("polarize_bonds")
	add_to_group("debuggable")
	set_physics_process(false)


func set_source_actor(actor: Node) -> void:
	if actor is Node3D and is_instance_valid(actor):
		source_actor = actor as Node3D


func execute(player: Node3D, cast_direction: Vector3) -> void:
	if source_actor == null:
		source_actor = player
	if source_actor == null or not is_instance_valid(source_actor):
		queue_free()
		return

	source_exclusions.clear()
	_collect_collision_rids(source_actor, source_exclusions)
	var primary_result: Dictionary = _find_primary_target(cast_direction)
	first_target = _valid_node3d(primary_result.get("target"))
	target_source = str(primary_result.get("source", "none"))
	if first_target == null:
		_show_message("Aim Polarize at a movable or polarizable object.")
		queue_free()
		return

	second_target = _find_secondary_target(first_target)
	if second_target == null:
		_show_message("Polarize needs a second nearby object to form a magnetic bond.")
		queue_free()
		return

	elapsed = 0.0
	active = true
	_build_beam()
	_notify_link(first_target, second_target, true)
	_notify_link(second_target, first_target, true)
	polarize_link_created.emit(first_target, second_target)
	set_physics_process(true)
	_update_beam()
	_show_message(
		"Polarized " + _display_name(first_target)
		+ " ↔ " + _display_name(second_target) + "."
	)


func _physics_process(delta: float) -> void:
	if not active:
		return
	if not _targets_are_valid():
		_finish_link("target_lost")
		return

	elapsed += maxf(delta, 0.0)
	if elapsed >= duration:
		_finish_link("expired")
		return

	var offset: Vector3 = second_target.global_position - first_target.global_position
	last_distance = offset.length()
	if last_distance > break_distance:
		_finish_link("overstretched")
		return
	if last_distance <= 0.001:
		last_force = 0.0
		_update_beam()
		return

	var direction: Vector3 = offset / last_distance
	var relative_velocity: Vector3 = _target_velocity(second_target) - _target_velocity(first_target)
	var separation_speed: float = relative_velocity.dot(direction)
	var extension: float = maxf(last_distance - target_separation, 0.0)
	var force_amount: float = (
		spring_strength * extension
		+ damping_strength * separation_speed
	)
	force_amount = clampf(force_amount, 0.0, maximum_force)
	last_force = force_amount
	var force: Vector3 = direction * force_amount
	_apply_magnetic_force(first_target, force, second_target)
	_apply_magnetic_force(second_target, -force, first_target)
	_update_beam()


func _find_primary_target(cast_direction: Vector3) -> Dictionary:
	var direct: Dictionary = _raycast_camera_target()
	if not direct.is_empty():
		return direct
	return _scan_aimed_targets(cast_direction)


func _raycast_camera_target() -> Dictionary:
	var camera: Camera3D = source_actor.get_viewport().get_camera_3d()
	var world: World3D = source_actor.get_world_3d()
	if camera == null or world == null:
		return {}
	var viewport_rect: Rect2 = camera.get_viewport().get_visible_rect()
	var center: Vector2 = viewport_rect.position + viewport_rect.size * 0.5
	var origin: Vector3 = camera.project_ray_origin(center)
	var direction: Vector3 = camera.project_ray_normal(center)
	if direction.length_squared() <= 0.0001:
		return {}
	var query := PhysicsRayQueryParameters3D.create(
		origin,
		origin + direction.normalized() * maximum_range
	)
	query.collision_mask = collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = source_exclusions
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}
	var candidate: Node3D = _resolve_polarize_target(hit.get("collider") as Node)
	if candidate == null or not _in_range(candidate):
		return {}
	return {"target": candidate, "source": "camera_center"}


func _scan_aimed_targets(cast_direction: Vector3) -> Dictionary:
	var world: World3D = source_actor.get_world_3d()
	if world == null:
		return {}
	var direction: Vector3 = cast_direction
	if direction.length_squared() <= 0.0001:
		direction = -source_actor.global_basis.z
	if direction.length_squared() <= 0.0001:
		return {}
	direction = direction.normalized()

	var sphere := SphereShape3D.new()
	sphere.radius = maximum_range
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, source_actor.global_position)
	query.collision_mask = collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = source_exclusions
	var best: Node3D = null
	var best_score: float = INF
	var seen: Dictionary = {}
	var minimum_dot: float = cos(deg_to_rad(soft_aim_angle_degrees))
	for result: Dictionary in world.direct_space_state.intersect_shape(query, 128):
		var collider_value: Variant = result.get("collider")
		if not collider_value is Node:
			continue
		var candidate: Node3D = _resolve_polarize_target(collider_value as Node)
		if candidate == null:
			continue
		var candidate_id: int = candidate.get_instance_id()
		if seen.has(candidate_id):
			continue
		seen[candidate_id] = true
		var offset: Vector3 = candidate.global_position - _cast_origin()
		var distance: float = offset.length()
		if distance <= 0.1 or distance > maximum_range:
			continue
		var aim_dot: float = direction.dot(offset / distance)
		if aim_dot < minimum_dot:
			continue
		var score: float = (1.0 - aim_dot) * 48.0 + distance / maximum_range
		if score < best_score:
			best_score = score
			best = candidate
	return {"target": best, "source": "aim_assist"} if best != null else {}


func _find_secondary_target(primary: Node3D) -> Node3D:
	var world: World3D = source_actor.get_world_3d()
	if world == null:
		return null
	var sphere := SphereShape3D.new()
	sphere.radius = secondary_search_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, primary.global_position)
	query.collision_mask = collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = source_exclusions
	var best: Node3D = null
	var best_distance: float = INF
	var seen: Dictionary = {primary.get_instance_id(): true}
	for result: Dictionary in world.direct_space_state.intersect_shape(query, 128):
		var collider_value: Variant = result.get("collider")
		if not collider_value is Node:
			continue
		var candidate: Node3D = _resolve_polarize_target(collider_value as Node)
		if candidate == null or candidate == primary:
			continue
		var candidate_id: int = candidate.get_instance_id()
		if seen.has(candidate_id):
			continue
		seen[candidate_id] = true
		var distance: float = candidate.global_position.distance_to(primary.global_position)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best


func _resolve_polarize_target(start_node: Node) -> Node3D:
	var current: Node = start_node
	while current != null and current != source_actor:
		if current is Node3D and _can_polarize(current as Node3D):
			return current as Node3D
		current = current.get_parent()
	return null


func _can_polarize(target: Node3D) -> bool:
	if target == null or not is_instance_valid(target) or target == source_actor:
		return false
	if target.is_in_group("polarize_immune"):
		return false
	if target.has_method("can_accept_polarize"):
		return bool(target.call("can_accept_polarize", source_actor))
	if target is RigidBody3D:
		return (target as RigidBody3D).mass <= maximum_rigidbody_mass
	return (
		target.is_in_group("polarizable")
		or target.is_in_group("presentation_material_metal")
		or target.has_method("receive_polarize_force")
	)


func _apply_magnetic_force(target: Node3D, force: Vector3, partner: Node3D) -> void:
	if target == null or not is_instance_valid(target):
		return
	if target.has_method("receive_polarize_force"):
		target.call("receive_polarize_force", force, partner, source_actor)
		return
	if target is RigidBody3D:
		var body := target as RigidBody3D
		if not body.freeze:
			body.apply_central_force(force)


func _target_velocity(target: Node3D) -> Vector3:
	if target is RigidBody3D:
		return (target as RigidBody3D).linear_velocity
	if target.has_method("get_polarize_velocity"):
		var value: Variant = target.call("get_polarize_velocity")
		if value is Vector3:
			return value as Vector3
	return Vector3.ZERO


func _notify_link(target: Node3D, partner: Node3D, linked: bool) -> void:
	if target == null or not is_instance_valid(target):
		return
	if linked and target.has_method("receive_polarize_link"):
		target.call("receive_polarize_link", partner, source_actor)
	elif not linked and target.has_method("release_polarize_link"):
		target.call("release_polarize_link", partner, source_actor)


func _build_beam() -> void:
	beam = MeshInstance3D.new()
	beam.name = "PolarizeBond"
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.035
	mesh.bottom_radius = 0.035
	mesh.height = 1.0
	mesh.radial_segments = 12
	beam.mesh = mesh
	beam_material = StandardMaterial3D.new()
	beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_material.albedo_color = bond_color
	beam_material.emission_enabled = true
	beam_material.emission = Color(bond_color.r, bond_color.g, bond_color.b)
	beam_material.emission_energy_multiplier = 2.0
	beam.material_override = beam_material
	add_child(beam)


func _update_beam() -> void:
	if beam == null or not _targets_are_valid():
		return
	var start: Vector3 = first_target.global_position
	var finish: Vector3 = second_target.global_position
	var offset: Vector3 = finish - start
	var length: float = offset.length()
	if length <= 0.001:
		beam.visible = false
		return
	beam.visible = true
	var y_axis: Vector3 = offset / length
	var helper: Vector3 = Vector3.UP if absf(y_axis.dot(Vector3.UP)) < 0.94 else Vector3.RIGHT
	var x_axis: Vector3 = helper.cross(y_axis).normalized()
	var z_axis: Vector3 = x_axis.cross(y_axis).normalized()
	var basis := Basis(x_axis, y_axis, z_axis).orthonormalized()
	beam.global_transform = Transform3D(basis, start.lerp(finish, 0.5))
	beam.scale = Vector3(1.0, length, 1.0)
	if beam_material != null:
		beam_material.emission_energy_multiplier = 1.4 + clampf(last_force / maxf(maximum_force, 0.1), 0.0, 1.0) * 2.0


func _cast_origin() -> Vector3:
	for path: String in [
		"GraceVisualV1/RightHandAnchor",
		"RightHandAnchor",
		"CastingHandAnchor",
	]:
		var anchor: Node3D = source_actor.get_node_or_null(path) as Node3D
		if anchor != null:
			return anchor.global_position
	return source_actor.global_position + Vector3.UP * 0.72


func _in_range(target: Node3D) -> bool:
	return target != null and _cast_origin().distance_to(target.global_position) <= maximum_range


func _targets_are_valid() -> bool:
	return (
		first_target != null and is_instance_valid(first_target)
		and second_target != null and is_instance_valid(second_target)
	)


func _valid_node3d(value: Variant) -> Node3D:
	if typeof(value) != TYPE_OBJECT or not is_instance_valid(value):
		return null
	return value as Node3D if value is Node3D else null


func _display_name(target: Node) -> String:
	if target == null:
		return "object"
	var value: Variant = target.get("display_name")
	if value != null and str(value).strip_edges() != "":
		return str(value)
	return target.name.capitalize()


func _show_message(text: String) -> void:
	if get_tree() == null:
		return
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)


func _collect_collision_rids(node: Node, target: Array[RID]) -> void:
	if node is CollisionObject3D:
		var rid: RID = (node as CollisionObject3D).get_rid()
		if rid.is_valid() and not target.has(rid):
			target.append(rid)
	for child: Node in node.get_children():
		_collect_collision_rids(child, target)


func _finish_link(reason: String) -> void:
	if not active:
		return
	active = false
	set_physics_process(false)
	if first_target != null and is_instance_valid(first_target):
		_notify_link(first_target, second_target, false)
	if second_target != null and is_instance_valid(second_target):
		_notify_link(second_target, first_target, false)
	polarize_link_broken.emit(reason)
	if show_debug_messages:
		print("POLARIZE link ended: ", reason)
	queue_free()


func get_debug_data() -> Dictionary:
	return {
		"spell": "polarize",
		"active": active,
		"first_target": _display_name(first_target) if first_target != null and is_instance_valid(first_target) else "none",
		"second_target": _display_name(second_target) if second_target != null and is_instance_valid(second_target) else "none",
		"target_source": target_source,
		"distance": snappedf(last_distance, 0.01),
		"force": snappedf(last_force, 0.1),
		"object_connection_contract": true,
		"direct_damage": false,
	}
