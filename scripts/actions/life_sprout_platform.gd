extends Node3D
class_name LifeSproutPlatform

@export_group("Placement")
@export_range(2.0, 30.0, 0.5) var maximum_range: float = 15.0
@export_range(1.0, 12.0, 0.25) var fallback_distance: float = 6.0
@export_flags_3d_physics var placement_collision_mask: int = 1

@export_group("Platform")
@export_range(0.5, 3.0, 0.05) var platform_height: float = 1.45
@export_range(0.4, 2.0, 0.05) var platform_radius: float = 1.05
@export_range(0.1, 0.6, 0.02) var platform_thickness: float = 0.24
@export_range(1.0, 30.0, 0.25) var lifetime: float = 10.0
@export_range(0.2, 4.0, 0.1) var wither_duration: float = 1.35
@export_range(1, 8, 1) var maximum_active_per_caster: int = 3

@export_group("Growth Lift")
@export_range(0.5, 3.0, 0.05) var lift_radius: float = 1.2
@export_range(0.5, 12.0, 0.1) var character_lift_speed: float = 4.8
@export_range(0.5, 12.0, 0.1) var rigid_lift_speed: float = 4.2

var source_actor: Node3D = null
var platform_body: StaticBody3D = null
var platform_collision: CollisionShape3D = null
var visual_root: Node3D = null
var life_material: StandardMaterial3D = null
var vein_material: StandardMaterial3D = null
var age: float = 0.0
var active: bool = false
var withering: bool = false
var created_at_msec: int = 0
var last_lift_count: int = 0

const FRESH_GREEN: Color = Color(0.16, 0.66, 0.11, 1.0)
const LIGHT_GREEN: Color = Color(0.38, 0.86, 0.22, 1.0)
const WITHER_BROWN: Color = Color(0.42, 0.2, 0.055, 1.0)


func _ready() -> void:
	add_to_group("life_sprout_platforms")
	add_to_group("debuggable")
	created_at_msec = Time.get_ticks_msec()


func set_source_actor(actor: Node) -> void:
	if actor is Node3D and is_instance_valid(actor as Node3D):
		source_actor = actor as Node3D


func execute(player: Node3D, cast_direction: Vector3) -> void:
	if source_actor == null:
		source_actor = player
	if source_actor == null or not is_instance_valid(source_actor):
		queue_free()
		return

	var placement: Dictionary = resolve_placement(cast_direction)
	var point_value: Variant = placement.get("point")
	var normal_value: Variant = placement.get("normal")
	if not point_value is Vector3:
		point_value = source_actor.global_position
	if not normal_value is Vector3:
		normal_value = Vector3.UP
	activate_at(point_value as Vector3, normal_value as Vector3, source_actor)


func activate_at(
	world_position: Vector3,
	surface_normal: Vector3 = Vector3.UP,
	caster: Node3D = null
) -> bool:
	if caster != null and is_instance_valid(caster):
		source_actor = caster
	if active:
		return false

	global_position = world_position
	var normal: Vector3 = surface_normal.normalized()
	if normal.length_squared() <= 0.001 or normal.dot(Vector3.UP) < 0.35:
		normal = Vector3.UP
	_align_up_to_normal(normal)
	_enforce_active_limit()
	_build_platform()
	active = true
	age = 0.0
	withering = false
	last_lift_count = lift_occupants()

	var growth_tween := create_tween()
	growth_tween.tween_interval(0.16)
	growth_tween.tween_callback(_finish_growth)
	return true


func _process(delta: float) -> void:
	if not active:
		return
	age += maxf(delta, 0.0)
	var wither_start: float = maxf(lifetime - wither_duration, 0.0)
	if age >= wither_start:
		_update_wither_visual()
	if age >= lifetime:
		begin_wither_and_remove()


func resolve_placement(cast_direction: Vector3) -> Dictionary:
	if source_actor == null or not is_instance_valid(source_actor):
		return {}
	var world: World3D = source_actor.get_world_3d()
	if world == null:
		return {}

	var camera: Camera3D = source_actor.get_viewport().get_camera_3d()
	var origin: Vector3 = camera.global_position if camera != null else source_actor.global_position + Vector3.UP
	var direction: Vector3 = cast_direction
	if direction.length_squared() <= 0.0001:
		direction = -source_actor.global_basis.z
	direction = direction.normalized()

	var exclusions: Array[RID] = []
	_collect_collision_rids(source_actor, exclusions)
	var ray := PhysicsRayQueryParameters3D.create(
		origin,
		origin + direction * maximum_range
	)
	ray.collision_mask = placement_collision_mask
	ray.collide_with_areas = false
	ray.collide_with_bodies = true
	ray.exclude = exclusions
	var hit: Dictionary = world.direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		var hit_point_value: Variant = hit.get("position")
		var hit_normal_value: Variant = hit.get("normal")
		if hit_point_value is Vector3 and hit_normal_value is Vector3:
			var hit_point: Vector3 = hit_point_value as Vector3
			var hit_normal: Vector3 = hit_normal_value as Vector3
			if hit_normal.normalized().dot(Vector3.UP) >= 0.55:
				return {"point": hit_point, "normal": hit_normal, "source": "camera_surface"}
			var grounded: Dictionary = _raycast_down_to_ground(
				hit_point + Vector3.UP * 3.0,
				exclusions
			)
			if not grounded.is_empty():
				grounded["source"] = "camera_then_ground"
				return grounded

	var horizontal := Vector3(direction.x, 0.0, direction.z)
	if horizontal.length_squared() <= 0.001:
		horizontal = -source_actor.global_basis.z
		horizontal.y = 0.0
	if horizontal.length_squared() > 0.001:
		horizontal = horizontal.normalized()
	var fallback_origin: Vector3 = (
		source_actor.global_position
		+ horizontal * fallback_distance
		+ Vector3.UP * 4.0
	)
	var fallback: Dictionary = _raycast_down_to_ground(fallback_origin, exclusions)
	if not fallback.is_empty():
		fallback["source"] = "forward_ground"
		return fallback

	return {
		"point": source_actor.global_position - Vector3.UP * 0.92,
		"normal": Vector3.UP,
		"source": "feet_fallback",
	}


func _raycast_down_to_ground(origin: Vector3, exclusions: Array[RID]) -> Dictionary:
	if source_actor == null or not is_instance_valid(source_actor):
		return {}
	var world: World3D = source_actor.get_world_3d()
	if world == null:
		return {}
	var ray := PhysicsRayQueryParameters3D.create(
		origin,
		origin + Vector3.DOWN * 12.0
	)
	ray.collision_mask = placement_collision_mask
	ray.collide_with_areas = false
	ray.collide_with_bodies = true
	ray.exclude = exclusions
	var hit: Dictionary = world.direct_space_state.intersect_ray(ray)
	if hit.is_empty():
		return {}
	var point_value: Variant = hit.get("position")
	var normal_value: Variant = hit.get("normal")
	if not point_value is Vector3 or not normal_value is Vector3:
		return {}
	return {"point": point_value as Vector3, "normal": normal_value as Vector3}


func _align_up_to_normal(normal: Vector3) -> void:
	if normal.is_equal_approx(Vector3.UP):
		global_basis = Basis.IDENTITY
		return
	var forward: Vector3 = -global_basis.z
	forward = (forward - normal * forward.dot(normal)).normalized()
	if forward.length_squared() <= 0.001:
		forward = normal.cross(Vector3.RIGHT).normalized()
	var right: Vector3 = forward.cross(normal).normalized()
	global_basis = Basis(right, normal, -forward).orthonormalized()


func _build_platform() -> void:
	visual_root = Node3D.new()
	visual_root.name = "SproutVisual"
	add_child(visual_root)

	life_material = _make_material(FRESH_GREEN, 0.42)
	vein_material = _make_material(LIGHT_GREEN, 0.72)
	var stem_material: StandardMaterial3D = _make_material(Color(0.24, 0.38, 0.07, 1.0), 0.12)

	var stem := MeshInstance3D.new()
	stem.name = "Stem"
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.13
	stem_mesh.bottom_radius = 0.23
	stem_mesh.height = platform_height
	stem_mesh.radial_segments = 10
	stem.mesh = stem_mesh
	stem.material_override = stem_material
	stem.position.y = platform_height * 0.5
	visual_root.add_child(stem)

	var crown := MeshInstance3D.new()
	crown.name = "LeafPlatform"
	var crown_mesh := CylinderMesh.new()
	crown_mesh.top_radius = platform_radius
	crown_mesh.bottom_radius = platform_radius * 0.82
	crown_mesh.height = platform_thickness
	crown_mesh.radial_segments = 16
	crown.mesh = crown_mesh
	crown.material_override = life_material
	crown.position.y = platform_height
	visual_root.add_child(crown)

	for index: int in range(4):
		var leaf := MeshInstance3D.new()
		leaf.name = "LeafFlange" + str(index + 1)
		var leaf_mesh := BoxMesh.new()
		leaf_mesh.size = Vector3(platform_radius * 1.05, 0.07, platform_radius * 0.48)
		leaf.mesh = leaf_mesh
		leaf.material_override = vein_material
		var angle: float = TAU * float(index) / 4.0
		leaf.position = Vector3(
			cos(angle) * platform_radius * 0.58,
			platform_height + platform_thickness * 0.16,
			sin(angle) * platform_radius * 0.58
		)
		leaf.rotation.y = -angle
		leaf.rotation.z = sin(angle) * 0.08
		visual_root.add_child(leaf)

	platform_body = StaticBody3D.new()
	platform_body.name = "SproutPlatformBody"
	platform_body.collision_layer = 1
	platform_body.collision_mask = 1
	add_child(platform_body)
	platform_body.position.y = platform_height

	platform_collision = CollisionShape3D.new()
	platform_collision.name = "PlatformCollision"
	var box := BoxShape3D.new()
	box.size = Vector3(
		platform_radius * 1.9,
		platform_thickness,
		platform_radius * 1.9
	)
	platform_collision.shape = box
	platform_collision.disabled = true
	platform_body.add_child(platform_collision)

	visual_root.scale = Vector3(0.18, 0.035, 0.18)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(visual_root, "scale", Vector3.ONE, 0.28)


func _finish_growth() -> void:
	if not active:
		return
	if platform_collision != null and is_instance_valid(platform_collision):
		platform_collision.set_deferred("disabled", false)
	last_lift_count = maxi(last_lift_count, lift_occupants())


func lift_occupants() -> int:
	if get_world_3d() == null:
		return 0
	var sphere := SphereShape3D.new()
	sphere.radius = lift_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, global_position + Vector3.UP * 0.45)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.collision_mask = 0x7FFFFFFF
	if platform_body != null and is_instance_valid(platform_body):
		query.exclude = [platform_body.get_rid()]
	var hits: Array[Dictionary] = get_world_3d().direct_space_state.intersect_shape(query, 24)
	var seen: Dictionary = {}
	var count: int = 0
	for hit: Dictionary in hits:
		var collider: Node = hit.get("collider") as Node
		var body: Node3D = _resolve_movable_body(collider)
		if body == null or not is_instance_valid(body):
			continue
		var body_id: int = body.get_instance_id()
		if seen.has(body_id):
			continue
		seen[body_id] = true
		if body is CharacterBody3D:
			var character := body as CharacterBody3D
			character.velocity.y = maxf(character.velocity.y, character_lift_speed)
			count += 1
		elif body is RigidBody3D:
			var rigid := body as RigidBody3D
			if rigid.freeze:
				continue
			rigid.sleeping = false
			rigid.apply_central_impulse(
				Vector3.UP * maxf(rigid.mass, 0.1) * rigid_lift_speed
			)
			count += 1
	return count


func _resolve_movable_body(node: Node) -> Node3D:
	var current: Node = node
	while current != null:
		if current is CharacterBody3D or current is RigidBody3D:
			return current as Node3D
		current = current.get_parent()
	return null


func _update_wither_visual() -> void:
	if visual_root == null or withering:
		return
	withering = true
	var start: float = maxf(lifetime - wither_duration, 0.0)
	var ratio: float = clampf((age - start) / maxf(wither_duration, 0.01), 0.0, 1.0)
	if life_material != null:
		var color: Color = FRESH_GREEN.lerp(WITHER_BROWN, ratio)
		life_material.albedo_color = color
		life_material.emission = color
	if vein_material != null:
		var vein_color: Color = LIGHT_GREEN.lerp(WITHER_BROWN, ratio)
		vein_material.albedo_color = vein_color
		vein_material.emission = vein_color
	visual_root.scale = Vector3(
		lerpf(1.0, 0.88, ratio),
		lerpf(1.0, 0.76, ratio),
		lerpf(1.0, 0.88, ratio)
	)
	# Continue updating the palette over the whole wither window.
	withering = false


func begin_wither_and_remove() -> void:
	if not active:
		return
	active = false
	if platform_collision != null and is_instance_valid(platform_collision):
		platform_collision.set_deferred("disabled", true)
	if visual_root == null or not is_instance_valid(visual_root):
		queue_free()
		return
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(visual_root, "scale", Vector3(0.86, 0.02, 0.86), 0.24)
	tween.tween_property(visual_root, "rotation:y", visual_root.rotation.y + 0.24, 0.24)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)


func _enforce_active_limit() -> void:
	if source_actor == null or get_tree() == null:
		return
	var owned: Array[LifeSproutPlatform] = []
	for raw: Node in get_tree().get_nodes_in_group("life_sprout_platforms"):
		if raw == self or not raw is LifeSproutPlatform:
			continue
		var sprout := raw as LifeSproutPlatform
		if sprout.source_actor == source_actor and sprout.active:
			owned.append(sprout)
	owned.sort_custom(func(a: LifeSproutPlatform, b: LifeSproutPlatform) -> bool:
		return a.created_at_msec < b.created_at_msec
	)
	while owned.size() >= maximum_active_per_caster:
		var oldest: LifeSproutPlatform = owned.pop_front()
		if oldest != null and is_instance_valid(oldest):
			oldest.begin_wither_and_remove()


func _collect_collision_rids(node: Node, output: Array[RID]) -> void:
	if node == null:
		return
	if node is CollisionObject3D:
		var rid: RID = (node as CollisionObject3D).get_rid()
		if rid.is_valid() and not output.has(rid):
			output.append(rid)
	for child: Node in node.get_children():
		_collect_collision_rids(child, output)


func _make_material(color: Color, emission_energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = emission_energy > 0.0
	material.emission = color
	material.emission_energy_multiplier = emission_energy
	material.roughness = 0.84
	return material


func get_debug_data() -> Dictionary:
	return {
		"spell": "sprout",
		"active": active,
		"age": snappedf(age, 0.01),
		"platform_height": platform_height,
		"platform_radius": platform_radius,
		"collision_enabled": (
			platform_collision != null
			and is_instance_valid(platform_collision)
			and not platform_collision.disabled
		),
		"last_lift_count": last_lift_count,
		"temporary_geometry": true,
	}
