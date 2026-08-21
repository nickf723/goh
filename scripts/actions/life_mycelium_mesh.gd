extends Node3D
class_name LifeMyceliumMesh

signal network_node_grown(position: Vector3, index: int)
signal mesh_finished(nodes_grown: int, affected_targets: int)

@export_group("Placement")
@export_range(0.5, 12.0, 0.25) var placement_distance: float = 4.5
@export_range(1.0, 12.0, 0.25) var ground_probe_height: float = 4.0
@export_range(1.0, 16.0, 0.25) var ground_probe_depth: float = 7.0
@export_flags_3d_physics var collision_mask: int = 1

@export_group("Growth")
@export_range(0.5, 12.0, 0.1) var growth_duration: float = 4.8
@export_range(1.0, 30.0, 0.25) var lifetime: float = 13.0
@export_range(1.0, 14.0, 0.1) var maximum_radius: float = 6.2
@export_range(4, 48, 1) var maximum_nodes: int = 22
@export_range(0.05, 1.0, 0.01) var influence_interval: float = 0.24

@export_group("Field Influence")
@export_range(0.0, 8.0, 0.1) var enemy_drag_per_second: float = 1.35
@export_range(0.0, 1.0, 0.05) var boss_drag_multiplier: float = 0.28
@export_range(0.0, 4.0, 0.05) var hook_strength: float = 1.0
@export_range(0.2, 5.0, 0.1) var influence_height: float = 1.8

@export_group("Presentation")
@export var stem_color: Color = Color(0.69, 0.84, 0.61, 1.0)
@export var cap_color: Color = Color(0.25, 0.83, 0.45, 1.0)
@export var network_color: Color = Color(0.38, 1.0, 0.58, 0.72)
@export var show_debug_messages: bool = false

var source_actor: Node3D = null
var mesh_origin: Vector3 = Vector3.ZERO
var elapsed: float = 0.0
var current_radius: float = 0.0
var active: bool = false
var next_influence_time: float = 0.0
var grown_nodes: int = 0
var collision_exclusions: Array[RID] = []
var node_world_positions: Array[Vector3] = []
var affected_target_ids: Dictionary = {}
var affected_target_names: Array[String] = []
var visual_root: Node3D = null
var network_material: StandardMaterial3D = null


func _ready() -> void:
	add_to_group("mycelium_mesh_fields")
	add_to_group("life_growth_fields")
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

	collision_exclusions.clear()
	_collect_collision_rids(source_actor, collision_exclusions)
	mesh_origin = _resolve_placement_point(cast_direction)
	global_position = mesh_origin
	elapsed = 0.0
	current_radius = 0.0
	next_influence_time = 0.0
	grown_nodes = 0
	node_world_positions.clear()
	affected_target_ids.clear()
	affected_target_names.clear()
	_build_visual_root()
	active = true
	set_physics_process(true)
	_grow_available_nodes()


func _physics_process(delta: float) -> void:
	if not active:
		return
	var step: float = maxf(delta, 0.0)
	elapsed += step
	var growth_t: float = clampf(elapsed / maxf(growth_duration, 0.01), 0.0, 1.0)
	current_radius = maximum_radius * smoothstep(0.0, 1.0, growth_t)
	_grow_available_nodes()

	if elapsed + 0.0001 >= next_influence_time:
		_apply_field_influence(maxf(influence_interval, step))
		next_influence_time = elapsed + influence_interval

	if elapsed >= lifetime:
		_finish_mesh()


func _grow_available_nodes() -> void:
	while grown_nodes < maximum_nodes:
		var target_position: Vector3 = _planned_node_position(grown_nodes)
		var radial_distance: float = Vector2(
			target_position.x - mesh_origin.x,
			target_position.z - mesh_origin.z
		).length()
		if radial_distance > current_radius + 0.08 and grown_nodes > 0:
			break
		var grounded: Vector3 = _ground_point_near(target_position)
		_spawn_mushroom_cluster(grounded, grown_nodes)
		if not node_world_positions.is_empty():
			_spawn_network_segment(node_world_positions[-1], grounded, grown_nodes)
		node_world_positions.append(grounded)
		network_node_grown.emit(grounded, grown_nodes)
		grown_nodes += 1
		if maximum_nodes <= 1:
			break


func _planned_node_position(index: int) -> Vector3:
	if index <= 0:
		return mesh_origin
	var count_scale: float = sqrt(float(index) / maxf(float(maximum_nodes - 1), 1.0))
	var radius: float = maximum_radius * count_scale
	var golden_angle: float = 2.39996323
	var angle: float = float(index) * golden_angle
	return mesh_origin + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)


func _apply_field_influence(step: float) -> void:
	if current_radius <= 0.15:
		return
	var world: World3D = get_world_3d()
	if world == null:
		return
	var sphere := SphereShape3D.new()
	sphere.radius = current_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, mesh_origin + Vector3.UP * influence_height * 0.25)
	query.collision_mask = collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = collision_exclusions
	var seen: Dictionary = {}
	for hit: Dictionary in world.direct_space_state.intersect_shape(query, 128):
		var collider_value: Variant = hit.get("collider")
		if not collider_value is Node:
			continue
		var target: Node = _resolve_field_target(collider_value as Node)
		if target == null:
			continue
		var id: int = target.get_instance_id()
		if seen.has(id):
			continue
		seen[id] = true
		_apply_to_target(target, step)

	if get_tree() != null:
		for candidate: Node in get_tree().get_nodes_in_group("mycelium_reactive"):
			if candidate == null or not is_instance_valid(candidate) or not candidate is Node3D:
				continue
			var target_3d := candidate as Node3D
			if target_3d.global_position.distance_to(mesh_origin) > current_radius:
				continue
			if seen.has(target_3d.get_instance_id()):
				continue
			_apply_growth_hook(target_3d, _influence_at(target_3d.global_position))


func _apply_to_target(target: Node, step: float) -> void:
	var position: Vector3 = (target as Node3D).global_position if target is Node3D else mesh_origin
	if absf(position.y - mesh_origin.y) > influence_height:
		return
	var influence: float = _influence_at(position)
	if influence <= 0.0:
		return
	_apply_growth_hook(target, influence)

	if target is CharacterBody3D and target.is_in_group("enemy"):
		var character := target as CharacterBody3D
		var drag: float = enemy_drag_per_second * influence
		if target.is_in_group("boss"):
			drag *= boss_drag_multiplier
		var retention: float = exp(-maxf(drag, 0.0) * maxf(step, 0.0))
		character.velocity.x *= retention
		character.velocity.z *= retention

	var key: String = str(target.get_instance_id())
	if not affected_target_ids.has(key):
		affected_target_ids[key] = true
		affected_target_names.append(str(target.name))


func _apply_growth_hook(target: Node, influence: float) -> void:
	if target.has_method("receive_mycelium_growth"):
		target.call("receive_mycelium_growth", mesh_origin, influence * hook_strength, source_actor)
	elif target.has_method("receive_mycelium_field"):
		target.call("receive_mycelium_field", mesh_origin, current_radius, influence * hook_strength, source_actor)


func _influence_at(world_position: Vector3) -> float:
	var offset: Vector3 = world_position - mesh_origin
	offset.y = 0.0
	var distance: float = offset.length()
	if distance > current_radius:
		return 0.0
	return clampf(1.0 - distance / maxf(current_radius, 0.1), 0.18, 1.0)


func _resolve_field_target(start_node: Node) -> Node:
	var current: Node = start_node
	while current != null:
		if current == source_actor or (source_actor != null and source_actor.is_ancestor_of(current)):
			return null
		if _is_field_target(current):
			return current
		if current == get_tree().current_scene:
			break
		current = current.get_parent()
	return null


func _is_field_target(node: Node) -> bool:
	return (
		node is CharacterBody3D
		or node.has_method("receive_mycelium_growth")
		or node.has_method("receive_mycelium_field")
		or node.is_in_group("mycelium_reactive")
	)


func _resolve_placement_point(cast_direction: Vector3) -> Vector3:
	var direction: Vector3 = cast_direction
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		direction = -source_actor.global_basis.z
		direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		direction = Vector3.FORWARD
	direction = direction.normalized()
	var desired: Vector3 = source_actor.global_position + direction * placement_distance
	return _ground_point_near(desired)


func _ground_point_near(world_position: Vector3) -> Vector3:
	var world: World3D = get_world_3d()
	if world == null:
		return world_position
	var query := PhysicsRayQueryParameters3D.create(
		world_position + Vector3.UP * ground_probe_height,
		world_position + Vector3.DOWN * ground_probe_depth
	)
	query.collision_mask = collision_mask
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = collision_exclusions
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	var hit_position: Variant = hit.get("position")
	return (hit_position as Vector3) + Vector3.UP * 0.02 if hit_position is Vector3 else world_position


func _build_visual_root() -> void:
	visual_root = Node3D.new()
	visual_root.name = "MyceliumNetworkVisual"
	add_child(visual_root)
	network_material = StandardMaterial3D.new()
	network_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	network_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	network_material.albedo_color = network_color
	network_material.emission_enabled = true
	network_material.emission = Color(network_color.r, network_color.g, network_color.b)
	network_material.emission_energy_multiplier = 0.72


func _spawn_mushroom_cluster(world_position: Vector3, index: int) -> void:
	if visual_root == null:
		return
	var cluster := Node3D.new()
	cluster.name = "MyceliumNode%02d" % index
	visual_root.add_child(cluster)
	cluster.global_position = world_position
	var size_seed: float = 0.78 + 0.22 * sin(float(index) * 2.173)

	var stem := MeshInstance3D.new()
	stem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.035 * size_seed
	stem_mesh.bottom_radius = 0.055 * size_seed
	stem_mesh.height = 0.22 * size_seed
	stem_mesh.radial_segments = 8
	stem.mesh = stem_mesh
	var stem_material := StandardMaterial3D.new()
	stem_material.albedo_color = stem_color
	stem_material.roughness = 0.88
	stem.material_override = stem_material
	stem.position.y = stem_mesh.height * 0.5
	cluster.add_child(stem)

	var cap := MeshInstance3D.new()
	cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var cap_mesh := SphereMesh.new()
	cap_mesh.radius = 0.13 * size_seed
	cap_mesh.height = 0.18 * size_seed
	cap_mesh.radial_segments = 12
	cap_mesh.rings = 6
	cap.mesh = cap_mesh
	var cap_material := StandardMaterial3D.new()
	cap_material.albedo_color = cap_color
	cap_material.roughness = 0.72
	cap_material.emission_enabled = true
	cap_material.emission = Color(cap_color.r * 0.35, cap_color.g * 0.45, cap_color.b * 0.35)
	cap_material.emission_energy_multiplier = 0.22
	cap.material_override = cap_material
	cap.position.y = stem_mesh.height + cap_mesh.height * 0.08
	cap.scale = Vector3(1.2, 0.55, 1.2)
	cluster.add_child(cap)

	cluster.scale = Vector3.ONE * 0.08
	var tween := cluster.create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(cluster, "scale", Vector3.ONE, 0.24)


func _spawn_network_segment(start: Vector3, finish: Vector3, index: int) -> void:
	if visual_root == null:
		return
	var offset: Vector3 = finish - start
	var length: float = offset.length()
	if length <= 0.03:
		return
	var strand := MeshInstance3D.new()
	strand.name = "MyceliumStrand%02d" % index
	strand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.018
	mesh.bottom_radius = 0.026
	mesh.height = 1.0
	mesh.radial_segments = 7
	strand.mesh = mesh
	strand.material_override = network_material
	visual_root.add_child(strand)
	var y_axis: Vector3 = offset / length
	var helper: Vector3 = Vector3.UP if absf(y_axis.dot(Vector3.UP)) < 0.94 else Vector3.RIGHT
	var x_axis: Vector3 = helper.cross(y_axis).normalized()
	var z_axis: Vector3 = x_axis.cross(y_axis).normalized()
	strand.global_transform = Transform3D(
		Basis(x_axis, y_axis, z_axis).orthonormalized(),
		start.lerp(finish, 0.5) + Vector3.UP * 0.012
	)
	strand.scale = Vector3(1.0, length, 1.0)


func _collect_collision_rids(node: Node, target: Array[RID]) -> void:
	if node is CollisionObject3D:
		var rid: RID = (node as CollisionObject3D).get_rid()
		if rid.is_valid() and not target.has(rid):
			target.append(rid)
	for child: Node in node.get_children():
		_collect_collision_rids(child, target)


func _finish_mesh() -> void:
	if not active:
		return
	active = false
	set_physics_process(false)
	mesh_finished.emit(grown_nodes, affected_target_names.size())
	queue_free()


func get_debug_data() -> Dictionary:
	return {
		"spell": "mycelium_mesh",
		"active": active,
		"origin": mesh_origin,
		"radius": snappedf(current_radius, 0.01),
		"nodes_grown": grown_nodes,
		"maximum_nodes": maximum_nodes,
		"affected_targets": affected_target_names.duplicate(),
		"growth_response_contract": true,
		"direct_damage": false,
		"field_state": true,
	}
