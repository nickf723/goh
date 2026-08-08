extends Node3D
class_name LifeVineGrapple

const VineMaterial: FlexibleMaterialProfile = preload(
	"res://data/flexible_materials/life_vine_grapple.tres"
)

@export_group("Channel")
@export var channel_action: String = "cast_spell"

@export_group("Targeting")
@export_range(2.0, 40.0, 0.5) var maximum_target_range: float = 22.0
@export_range(1.0, 60.0, 1.0) var soft_aim_angle_degrees: float = 20.0
@export var require_line_of_sight: bool = true
@export_range(1.0, 1000.0, 1.0) var maximum_rigidbody_mass: float = 180.0

@export_group("Pull")
@export_range(0.5, 4.0, 0.05) var catch_distance: float = 1.55
@export_range(1.0, 40.0, 0.5) var maximum_pull_speed: float = 14.0
@export_range(1.0, 80.0, 0.5) var maximum_pull_acceleration: float = 36.0
@export_range(0.1, 10.0, 0.1) var speed_per_meter: float = 2.4
@export_range(0.1, 20.0, 0.1) var velocity_gain: float = 6.0
@export_range(0.0, 10.0, 0.1) var break_range_padding: float = 4.0

@export_group("Presentation")
@export_range(0.0, 1.0, 0.01) var visual_tension_offset: float = 0.24
@export_range(6, 32, 1) var visual_segment_count: int = 16
@export_range(3, 14, 1) var visual_constraint_iterations: int = 8
@export_range(0.0, 2.0, 0.05) var visual_gravity_scale: float = 0.42
@export var show_messages: bool = true

var source_actor: Node3D = null
var active_target: Node3D = null
var target_force_receiver: Node = null
var target_anchor_local: Vector3 = Vector3.ZERO
var grapple_active: bool = false
var current_distance: float = 0.0
var last_pull_speed: float = 0.0
var last_pull_acceleration: float = 0.0
var elapsed: float = 0.0

var source_endpoint: Node3D = null
var target_endpoint: Node3D = null
var tether_visual: FlexibleTether3D = null
var target_marker: MeshInstance3D = null


func _ready() -> void:
	add_to_group("debuggable")
	add_to_group("vine_grapple_runtime")


func set_source_actor(actor: Node3D) -> void:
	source_actor = actor


func execute(player: Node3D, cast_direction: Vector3) -> void:
	set_source_actor(player)
	if source_actor == null or not is_instance_valid(source_actor):
		queue_free()
		return

	var hit: Dictionary = find_grapple_target(cast_direction)
	var target: Node3D = hit.get("target") as Node3D
	var point_value: Variant = hit.get("point")
	if target == null or not point_value is Vector3:
		show_message("Vine Grapple found nothing it can pull.")
		queue_free()
		return

	if not attach_to_target(target, point_value as Vector3):
		show_message("That target resists Vine Grapple.")
		queue_free()


func _physics_process(delta: float) -> void:
	if not grapple_active:
		return
	elapsed += maxf(delta, 0.0)

	if not _source_is_available():
		release_grapple("source unavailable", false)
		return
	if not _target_is_available(active_target):
		release_grapple("target unavailable", true)
		return
	if not Input.is_action_pressed(channel_action):
		release_grapple("released", false)
		return
	if (
		source_actor.has_method("is_focus_spell_menu_open")
		and bool(source_actor.call("is_focus_spell_menu_open"))
	):
		release_grapple("focus menu", false)
		return
	if bool(source_actor.get("is_defeated")):
		release_grapple("defeated", false)
		return

	update_visual_endpoints()
	apply_pull(delta)


func _exit_tree() -> void:
	clear_target_force()


func attach_to_target(target: Node3D, world_anchor: Vector3) -> bool:
	if source_actor == null or not _target_is_available(target):
		return false

	var source_position: Vector3 = get_source_anchor_position()
	var distance: float = source_position.distance_to(world_anchor)
	if distance < catch_distance * 0.5 or distance > maximum_target_range:
		return false

	active_target = target
	target_force_receiver = find_force_receiver(target)
	target_anchor_local = target.to_local(world_anchor)
	grapple_active = true
	current_distance = distance
	last_pull_speed = 0.0
	last_pull_acceleration = 0.0

	if active_target is RigidBody3D:
		(active_target as RigidBody3D).sleeping = false

	build_tether_visual()
	update_visual_endpoints()
	GameFeedback.play("light_tick", {"source": "life_vine_grapple"})
	show_message("Vine Grapple latched onto " + get_target_display_name(active_target) + ".")
	return true


func release_grapple(reason: String = "released", should_show_message: bool = false) -> void:
	if not grapple_active and active_target == null:
		return

	clear_target_force()
	grapple_active = false
	active_target = null
	target_force_receiver = null
	current_distance = 0.0
	last_pull_speed = 0.0
	last_pull_acceleration = 0.0
	destroy_tether_visual()

	if should_show_message:
		if reason == "vine snapped":
			show_message("The living vine snapped under the strain.")
		elif reason == "out of range":
			show_message("Vine Grapple broke as the target escaped its reach.")
		elif reason == "target unavailable":
			show_message("Vine Grapple lost its target.")

	if is_inside_tree():
		queue_free()


func apply_pull(delta: float) -> void:
	if not grapple_active or source_actor == null or active_target == null:
		return

	var source_position: Vector3 = get_source_anchor_position()
	var target_position: Vector3 = get_target_anchor_position()
	var to_source: Vector3 = source_position - target_position
	current_distance = to_source.length()
	if current_distance <= catch_distance:
		GameFeedback.play("light_tick", {"source": "life_vine_reel_in"})
		show_message(get_target_display_name(active_target) + " was pulled to Grace.")
		release_grapple("reeled in", false)
		return
	if current_distance > maximum_target_range + break_range_padding:
		release_grapple("out of range", true)
		return
	if current_distance <= 0.001:
		return

	var direction: Vector3 = to_source / current_distance
	var extension: float = maxf(current_distance - catch_distance, 0.0)
	var desired_speed: float = minf(maximum_pull_speed, extension * speed_per_meter)
	var target_velocity: Vector3 = get_target_velocity(active_target)
	var radial_speed: float = target_velocity.dot(direction)
	var speed_error: float = maxf(desired_speed - radial_speed, 0.0)
	var requested_acceleration: float = minf(
		maximum_pull_acceleration,
		speed_error * velocity_gain
	)
	last_pull_speed = radial_speed
	last_pull_acceleration = requested_acceleration

	if active_target.has_method("apply_vine_grapple_force"):
		active_target.call(
			"apply_vine_grapple_force",
			direction * requested_acceleration,
			delta,
			source_actor
		)
		return

	if active_target is RigidBody3D:
		var rigid_body: RigidBody3D = active_target as RigidBody3D
		rigid_body.sleeping = false
		rigid_body.apply_central_force(
			direction * requested_acceleration * maxf(rigid_body.mass, 0.1)
		)
		return

	var velocity_step: float = minf(
		speed_error,
		requested_acceleration * maxf(delta, 0.0)
	)
	if velocity_step <= 0.0001:
		return

	if target_force_receiver != null and target_force_receiver.has_method("apply_impulse"):
		var horizontal_direction := Vector3(direction.x, 0.0, direction.z)
		var horizontal_weight: float = horizontal_direction.length()
		var horizontal_strength: float = velocity_step * horizontal_weight
		var upward_strength: float = maxf(direction.y, 0.0) * velocity_step
		target_force_receiver.call(
			"apply_impulse",
			horizontal_direction,
			horizontal_strength,
			upward_strength,
			"life_vine_grapple"
		)
		if active_target is CharacterBody3D and direction.y < 0.0:
			var receiver_body: CharacterBody3D = active_target as CharacterBody3D
			receiver_body.velocity.y += direction.y * velocity_step
		return

	if active_target is CharacterBody3D:
		var character_body: CharacterBody3D = active_target as CharacterBody3D
		character_body.velocity += direction * velocity_step


func find_grapple_target(cast_direction: Vector3) -> Dictionary:
	if source_actor == null or get_tree() == null:
		return {}

	var origin: Vector3 = get_source_anchor_position()
	var direction: Vector3 = cast_direction
	if direction.length_squared() <= 0.0001:
		var camera: Camera3D = get_viewport().get_camera_3d()
		direction = -camera.global_basis.z if camera != null else -source_actor.global_basis.z
	if direction.length_squared() <= 0.0001:
		return {}
	direction = direction.normalized()

	var direct_hit: Dictionary = raycast_for_target(origin, direction)
	if not direct_hit.is_empty():
		return direct_hit

	var lock_on_value: Variant = source_actor.get("lock_on_target")
	if lock_on_value is Node3D:
		var lock_on_target: Node3D = resolve_pull_target(lock_on_value as Node)
		if lock_on_target != null and candidate_is_visible(origin, lock_on_target):
			return {
				"target": lock_on_target,
				"point": get_default_target_point(lock_on_target),
			}

	return find_soft_target(origin, direction)


func raycast_for_target(origin: Vector3, direction: Vector3) -> Dictionary:
	var world: World3D = source_actor.get_world_3d()
	if world == null:
		return {}
	var query := PhysicsRayQueryParameters3D.create(
		origin,
		origin + direction * maximum_target_range
	)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = get_source_collision_exclusions()
	var result: Dictionary = world.direct_space_state.intersect_ray(query)
	if result.is_empty():
		return {}
	var collider: Node = result.get("collider") as Node
	var target: Node3D = resolve_pull_target(collider)
	var point_value: Variant = result.get("position")
	if target == null or not point_value is Vector3:
		return {}
	return {
		"target": target,
		"point": point_value as Vector3,
	}


func find_soft_target(origin: Vector3, direction: Vector3) -> Dictionary:
	var minimum_dot: float = cos(deg_to_rad(soft_aim_angle_degrees))
	var best_target: Node3D = null
	var best_point: Vector3 = Vector3.ZERO
	var best_score: float = INF
	var seen: Dictionary = {}

	for group_name: String in ["enemy", "vine_grapple_target"]:
		for candidate_node: Node in get_tree().get_nodes_in_group(group_name):
			var candidate: Node3D = resolve_pull_target(candidate_node)
			if candidate == null:
				continue
			var candidate_id: int = candidate.get_instance_id()
			if seen.has(candidate_id):
				continue
			seen[candidate_id] = true

			var point: Vector3 = get_default_target_point(candidate)
			var offset: Vector3 = point - origin
			var distance: float = offset.length()
			if distance <= 0.25 or distance > maximum_target_range:
				continue
			var aim_dot: float = direction.dot(offset / distance)
			if aim_dot < minimum_dot:
				continue
			if require_line_of_sight and not has_line_of_sight(origin, point, candidate):
				continue
			var score: float = (1.0 - aim_dot) * 30.0 + distance / maximum_target_range
			if score < best_score:
				best_score = score
				best_target = candidate
				best_point = point

	if best_target == null:
		return {}
	return {"target": best_target, "point": best_point}


func resolve_pull_target(start_node: Node) -> Node3D:
	var current: Node = start_node
	while current != null and current != source_actor:
		if current is Node3D and target_meets_contract(current as Node3D):
			return current as Node3D
		current = current.get_parent()
	return null


func target_meets_contract(target: Node3D) -> bool:
	if target == null or target == source_actor or not is_instance_valid(target):
		return false
	if target.is_in_group("vine_grapple_immune"):
		return false
	if target.has_method("can_accept_vine_grapple"):
		return bool(target.call("can_accept_vine_grapple", source_actor))
	if target.is_in_group("vine_grapple_target"):
		return true
	if target is RigidBody3D:
		var rigid_body: RigidBody3D = target as RigidBody3D
		return not rigid_body.freeze and rigid_body.mass <= maximum_rigidbody_mass
	if target is CharacterBody3D and target.is_in_group("enemy"):
		return true
	return find_force_receiver(target) != null


func candidate_is_visible(origin: Vector3, target: Node3D) -> bool:
	if not _target_is_available(target):
		return false
	var point: Vector3 = get_default_target_point(target)
	if origin.distance_to(point) > maximum_target_range:
		return false
	return not require_line_of_sight or has_line_of_sight(origin, point, target)


func has_line_of_sight(origin: Vector3, point: Vector3, target: Node3D) -> bool:
	var world: World3D = source_actor.get_world_3d()
	if world == null:
		return false
	var query := PhysicsRayQueryParameters3D.create(origin, point)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = get_source_collision_exclusions()
	var result: Dictionary = world.direct_space_state.intersect_ray(query)
	if result.is_empty():
		return true
	var collider: Node = result.get("collider") as Node
	return resolve_pull_target(collider) == target


func get_source_collision_exclusions() -> Array[RID]:
	var exclusions: Array[RID] = []
	collect_collision_rids(source_actor, exclusions)
	return exclusions


func collect_collision_rids(node: Node, exclusions: Array[RID]) -> void:
	if node == null:
		return
	if node is CollisionObject3D:
		var collision_object: CollisionObject3D = node as CollisionObject3D
		var rid: RID = collision_object.get_rid()
		if rid.is_valid() and not exclusions.has(rid):
			exclusions.append(rid)
	for child: Node in node.get_children():
		collect_collision_rids(child, exclusions)


func find_force_receiver(target: Node) -> Node:
	if target == null:
		return null
	if target is ForceReceiver:
		return target
	var direct: Node = target.get_node_or_null("ForceReceiver")
	if direct != null:
		return direct
	for child: Node in target.get_children():
		if child is ForceReceiver:
			return child
	return null


func get_source_anchor_position() -> Vector3:
	if source_actor == null:
		return global_position
	for anchor_path: String in [
		"GraceVisualV1/RightHandAnchor",
		"RightHandAnchor",
		"CastingHandAnchor",
	]:
		var anchor: Node3D = source_actor.get_node_or_null(anchor_path) as Node3D
		if anchor != null:
			return anchor.global_position
	var recursive_anchor: Node = source_actor.find_child("RightHandAnchor", true, false)
	if recursive_anchor is Node3D:
		return (recursive_anchor as Node3D).global_position
	return source_actor.global_position + Vector3.UP * 0.72


func get_target_anchor_position() -> Vector3:
	if active_target == null:
		return global_position
	if active_target.has_method("get_vine_grapple_anchor_position"):
		var custom_value: Variant = active_target.call("get_vine_grapple_anchor_position")
		if custom_value is Vector3:
			return custom_value as Vector3
	return active_target.to_global(target_anchor_local)


func get_default_target_point(target: Node3D) -> Vector3:
	if target == null:
		return Vector3.ZERO
	if target.has_method("get_vine_grapple_anchor_position"):
		var custom_value: Variant = target.call("get_vine_grapple_anchor_position")
		if custom_value is Vector3:
			return custom_value as Vector3
	if target.has_method("get_tether_anchor_position"):
		var tether_value: Variant = target.call("get_tether_anchor_position")
		if tether_value is Vector3:
			return tether_value as Vector3
	return target.global_position + Vector3.UP * 0.55


func get_target_velocity(target: Node3D) -> Vector3:
	if target is RigidBody3D:
		return (target as RigidBody3D).linear_velocity
	if target is CharacterBody3D:
		return (target as CharacterBody3D).velocity
	var value: Variant = target.get("velocity")
	return value as Vector3 if value is Vector3 else Vector3.ZERO


func build_tether_visual() -> void:
	destroy_tether_visual()
	if not grapple_active or active_target == null:
		return

	source_endpoint = Node3D.new()
	source_endpoint.name = "SourceEndpoint"
	add_child(source_endpoint)

	target_endpoint = Node3D.new()
	target_endpoint.name = "TargetEndpoint"
	add_child(target_endpoint)

	tether_visual = FlexibleTether3D.new()
	tether_visual.name = "LivingVineTether"
	tether_visual.endpoint_a_path = NodePath("../SourceEndpoint")
	tether_visual.endpoint_b_path = NodePath("../TargetEndpoint")
	tether_visual.material_profile = VineMaterial
	tether_visual.rest_length = maxf(catch_distance, current_distance - visual_tension_offset)
	tether_visual.segment_count = visual_segment_count
	tether_visual.constraint_iterations = visual_constraint_iterations
	tether_visual.verlet_damping = 0.984
	tether_visual.gravity_scale = visual_gravity_scale
	tether_visual.apply_endpoint_forces = false
	tether_visual.debug_tension_color = false
	tether_visual.tether_broken.connect(on_visual_tether_broken)
	add_child(tether_visual)

	target_marker = MeshInstance3D.new()
	target_marker.name = "VineBudMarker"
	target_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var marker_mesh := SphereMesh.new()
	marker_mesh.radius = 0.14
	marker_mesh.height = 0.28
	target_marker.mesh = marker_mesh
	var marker_material := StandardMaterial3D.new()
	marker_material.albedo_color = Color(0.32, 0.9, 0.2, 0.82)
	marker_material.emission_enabled = true
	marker_material.emission = Color(0.12, 0.78, 0.08, 1.0)
	marker_material.emission_energy_multiplier = 2.1
	marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	target_marker.material_override = marker_material
	add_child(target_marker)


func update_visual_endpoints() -> void:
	if not grapple_active or active_target == null:
		return
	var source_position: Vector3 = get_source_anchor_position()
	var target_position: Vector3 = get_target_anchor_position()
	if source_endpoint != null:
		source_endpoint.global_position = source_position
	if target_endpoint != null:
		target_endpoint.global_position = target_position
	if tether_visual != null:
		current_distance = source_position.distance_to(target_position)
		tether_visual.rest_length = maxf(
			catch_distance,
			current_distance - visual_tension_offset
		)
	if target_marker != null:
		target_marker.global_position = target_position
		var pulse: float = 1.0 + sin(elapsed * 9.0) * 0.13
		target_marker.scale = Vector3.ONE * pulse


func destroy_tether_visual() -> void:
	if is_instance_valid(tether_visual):
		tether_visual.queue_free()
	if is_instance_valid(source_endpoint):
		source_endpoint.queue_free()
	if is_instance_valid(target_endpoint):
		target_endpoint.queue_free()
	if is_instance_valid(target_marker):
		target_marker.queue_free()
	tether_visual = null
	source_endpoint = null
	target_endpoint = null
	target_marker = null


func clear_target_force() -> void:
	if target_force_receiver != null and target_force_receiver.has_method("clear_continuous_force"):
		target_force_receiver.call("clear_continuous_force", "life_vine_grapple")


func on_visual_tether_broken(_reason: String, _peak_tension: float) -> void:
	if grapple_active:
		release_grapple("vine snapped", true)


func _source_is_available() -> bool:
	return (
		source_actor != null
		and is_instance_valid(source_actor)
		and source_actor.is_inside_tree()
	)


func _target_is_available(target: Node3D) -> bool:
	return (
		target != null
		and is_instance_valid(target)
		and target.is_inside_tree()
		and target_meets_contract(target)
	)


func get_target_display_name(target: Node3D) -> String:
	if target == null:
		return "target"
	var display_value: Variant = target.get("display_name")
	if display_value != null and str(display_value) != "":
		return str(display_value)
	var source_label: Variant = target.get("source_label")
	if source_label != null and str(source_label) != "":
		return str(source_label)
	return target.name.capitalize()


func show_message(text: String) -> void:
	if not show_messages or get_tree() == null:
		return
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)


func get_debug_data() -> Dictionary:
	return {
		"spell": "vine_grapple",
		"active": grapple_active,
		"target": get_target_display_name(active_target) if active_target != null else "none",
		"distance": snapped(current_distance, 0.01),
		"pull_speed": snapped(last_pull_speed, 0.01),
		"pull_acceleration": snapped(last_pull_acceleration, 0.01),
		"rigid_mass_limit": maximum_rigidbody_mass,
		"material": VineMaterial.material_id,
	}
