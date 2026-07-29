extends Node3D
class_name DivineSpecialEffect

signal special_finished(success: bool, result: Dictionary)

const ProjectionVisualScene: PackedScene = preload(
	"res://scenes/actors/avatars/manifested_wire_visual_v1.tscn"
)
const AllySafeFireFieldScene: PackedScene = preload(
	"res://scenes/actions/manifested_fire_field.tscn"
)

var definition: DivineSpecialDefinition
var owner_actor: CharacterBody3D
var performer_actor: Node3D
var target_position: Vector3 = Vector3.ZERO
var cast_direction: Vector3 = Vector3.FORWARD
var configured: bool = false
var started: bool = false
var finished: bool = false
var finish_success: bool = false
var finish_reason: String = "not_started"
var elapsed: float = 0.0
var targets_hit: int = 0
var projectiles_cleared: int = 0
var persistent_nodes_spawned: int = 0
var projection_visual: Node3D
var projection_renderer: AvatarWireSkeletonRenderer


func configure_special(
	new_definition: DivineSpecialDefinition,
	new_owner: CharacterBody3D,
	new_target_position: Vector3,
	new_cast_direction: Vector3,
	new_performer: Node3D = null
) -> Array[String]:
	var failures: Array[String] = []
	if new_definition == null:
		failures.append("Divine special definition is missing.")
		return failures
	failures.append_array(new_definition.validate_definition())
	if new_owner == null or not is_instance_valid(new_owner):
		failures.append(new_definition.special_id + ": owner actor is missing")
	if not failures.is_empty():
		return failures

	definition = new_definition
	owner_actor = new_owner
	performer_actor = new_performer
	target_position = new_target_position
	cast_direction = new_cast_direction
	cast_direction.y = 0.0
	if cast_direction.length_squared() <= 0.0001:
		cast_direction = -owner_actor.global_transform.basis.z
		cast_direction.y = 0.0
	if cast_direction.length_squared() <= 0.0001:
		cast_direction = Vector3.FORWARD
	cast_direction = cast_direction.normalized()
	configured = true
	finish_reason = "configured"
	set_meta("divine_special_id", definition.special_id)
	set_meta("divine_special_patron_id", definition.patron_id)
	set_meta("divine_special_owner_instance_id", owner_actor.get_instance_id())
	return failures


func begin_special() -> bool:
	if not configured or started or finished:
		return false
	started = true
	finish_reason = "active"
	add_to_group("divine_special_effect")
	add_to_group("debuggable")
	return true


func _process(delta: float) -> void:
	if started and not finished:
		elapsed += maxf(delta, 0.0)


func cancel_special(reason: String = "cancelled") -> void:
	if finished:
		return
	_finish_special(false, reason)


func _finish_special(
	success: bool,
	reason: String,
	extra_result: Dictionary = {}
) -> void:
	if finished:
		return
	finished = true
	finish_success = success
	finish_reason = (
		reason
		if reason != ""
		else ("completed" if success else "cancelled")
	)
	_cleanup_special()
	var result: Dictionary = get_debug_data()
	result.merge(extra_result, true)
	special_finished.emit(success, result)
	call_deferred("queue_free")


func _cleanup_special() -> void:
	if projection_visual != null and is_instance_valid(projection_visual):
		projection_visual.queue_free()
	projection_visual = null
	projection_renderer = null


func spawn_patron_projection(
	world_position: Vector3,
	world_yaw: float = 0.0,
	scale_multiplier: float = 1.0
) -> Node3D:
	if definition == null or definition.patron_avatar_definition == null:
		return null
	var instance: Node = ProjectionVisualScene.instantiate()
	if not (instance is Node3D):
		if instance != null:
			instance.queue_free()
		return null
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		instance.queue_free()
		return null

	projection_visual = instance as Node3D
	scene_root.add_child(projection_visual)
	projection_visual.global_position = world_position
	projection_visual.rotation.y = world_yaw
	projection_visual.scale = Vector3.ONE * maxf(scale_multiplier, 0.05)
	projection_renderer = projection_visual.get_node_or_null(
		"WireSkeletonRenderer"
	) as AvatarWireSkeletonRenderer
	if projection_renderer != null:
		projection_renderer.set_avatar_presentation(
			definition.patron_avatar_definition
		)
		projection_renderer.sample_now(1.0)
	projection_visual.process_mode = Node.PROCESS_MODE_DISABLED
	return projection_visual


func spawn_pulse_disc(
	world_position: Vector3,
	start_radius: float,
	end_radius: float,
	duration: float,
	color: Color,
	height: float = 0.08
) -> MeshInstance3D:
	var disc: MeshInstance3D = MeshInstance3D.new()
	disc.name = "DivineSpecialPulse"
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = maxf(height, 0.01)
	mesh.radial_segments = 48
	disc.mesh = mesh
	disc.material_override = make_visual_material(color)
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return disc
	scene_root.add_child(disc)
	disc.global_position = world_position
	disc.scale = Vector3(start_radius, 1.0, start_radius)
	var resolved_duration: float = maxf(duration, 0.05)
	var tween: Tween = disc.create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(
		disc,
		"scale",
		Vector3(end_radius, 0.35, end_radius),
		resolved_duration
	)
	tween.parallel().tween_method(
		_set_mesh_alpha.bind(disc),
		color.a,
		0.0,
		resolved_duration
	)
	tween.finished.connect(disc.queue_free)
	return disc


func spawn_flash_sphere(
	world_position: Vector3,
	start_radius: float,
	end_radius: float,
	duration: float,
	color: Color
) -> MeshInstance3D:
	var flash: MeshInstance3D = MeshInstance3D.new()
	flash.name = "DivineSpecialFlash"
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 32
	mesh.rings = 16
	flash.mesh = mesh
	flash.material_override = make_visual_material(color)
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return flash
	scene_root.add_child(flash)
	flash.global_position = world_position
	flash.scale = Vector3.ONE * start_radius
	var resolved_duration: float = maxf(duration, 0.05)
	var tween: Tween = flash.create_tween()
	tween.set_trans(Tween.TRANS_EXPO)
	tween.set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(
		flash,
		"scale",
		Vector3.ONE * end_radius,
		resolved_duration
	)
	tween.parallel().tween_method(
		_set_mesh_alpha.bind(flash),
		color.a,
		0.0,
		resolved_duration
	)
	tween.finished.connect(flash.queue_free)
	return flash


func _set_mesh_alpha(alpha: float, mesh_instance: MeshInstance3D) -> void:
	if mesh_instance == null or not is_instance_valid(mesh_instance):
		return
	var material: StandardMaterial3D = (
		mesh_instance.material_override as StandardMaterial3D
	)
	if material == null:
		return
	var next_color: Color = material.albedo_color
	next_color.a = clampf(alpha, 0.0, 1.0)
	material.albedo_color = next_color


func make_visual_material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b, 1.0)
	material.emission_energy_multiplier = 1.7
	if color.a < 0.999:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func get_targets_in_radius(
	center: Vector3,
	radius: float,
	maximum_targets: int = 64
) -> Array[Node]:
	var targets: Array[Node] = []
	var seen: Dictionary = {}
	var safe_radius: float = maxf(radius, 0.05)
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = safe_radius
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(
		Basis.IDENTITY,
		center + Vector3.UP * 0.8
	)
	query.collision_mask = 0xFFFFFFFF
	query.collide_with_bodies = true
	query.collide_with_areas = true
	var exclusions: Array[RID] = []
	if owner_actor != null:
		exclusions.append(owner_actor.get_rid())
	if performer_actor is CollisionObject3D and performer_actor != owner_actor:
		exclusions.append((performer_actor as CollisionObject3D).get_rid())
	query.exclude = exclusions
	var world: World3D = get_world_3d()
	if world != null:
		for result: Dictionary in world.direct_space_state.intersect_shape(
			query,
			maxi(maximum_targets * 3, 48)
		):
			var collider: Node = result.get("collider") as Node
			var target: Node = resolve_payload_target(collider)
			_append_unique_target(
				target,
				center,
				safe_radius,
				seen,
				targets
			)
			if targets.size() >= maximum_targets:
				return targets

	for group_name: String in ["enemy", "combat_targetable", "lock_on_target"]:
		for candidate: Node in get_tree().get_nodes_in_group(group_name):
			var target: Node = resolve_payload_target(candidate)
			_append_unique_target(
				target,
				center,
				safe_radius,
				seen,
				targets
			)
			if targets.size() >= maximum_targets:
				return targets
	return targets


func _append_unique_target(
	target: Node,
	center: Vector3,
	radius: float,
	seen: Dictionary,
	targets: Array[Node]
) -> void:
	if target == null or is_friendly_target(target):
		return
	var target_id: int = target.get_instance_id()
	if seen.has(target_id):
		return
	if get_target_world_position(target).distance_to(center) > radius:
		return
	seen[target_id] = true
	targets.append(target)


func resolve_payload_target(candidate: Node) -> Node:
	if candidate == null or not is_instance_valid(candidate):
		return null
	var weapon_controller: WeaponController = null
	if owner_actor != null:
		weapon_controller = owner_actor.get_node_or_null(
			"WeaponController"
		) as WeaponController
	if weapon_controller != null:
		var resolved: Node = weapon_controller.find_payload_target(candidate)
		if resolved != null:
			return resolved

	var cursor: Node = candidate
	while cursor != null:
		if _is_payload_target(cursor):
			return cursor
		cursor = cursor.get_parent()
	return _find_payload_target_in_children(candidate)


func _find_payload_target_in_children(root: Node) -> Node:
	if root == null:
		return null
	for child: Node in root.get_children():
		if _is_payload_target(child):
			return child
		var deeper: Node = _find_payload_target_in_children(child)
		if deeper != null:
			return deeper
	return null


func _is_payload_target(candidate: Node) -> bool:
	if candidate == null:
		return false
	return (
		candidate.has_method("receive_damage_payload")
		or candidate.get_node_or_null("PayloadReceiver") != null
		or candidate.get_node_or_null("HitReceiver") != null
	)


func apply_payload_to_target(
	target: Node,
	payload: DamagePayload,
	force_origin: Vector3,
	force_strength: float = -1.0,
	up_strength: float = -1.0
) -> bool:
	if target == null or payload == null or is_friendly_target(target):
		return false
	var resolved_payload: DamagePayload = (
		payload.duplicate(true) as DamagePayload
	)
	if resolved_payload == null:
		resolved_payload = payload
	var resolved_force: float = (
		force_strength
		if force_strength >= 0.0
		else resolved_payload.knockback_strength
	)
	var resolved_up: float = (
		up_strength
		if up_strength >= 0.0
		else resolved_payload.knockback_up_strength
	)
	resolved_payload.knockback_strength = 0.0
	resolved_payload.knockback_up_strength = 0.0
	var delivered: bool = false
	var payload_receiver: Node = target.get_node_or_null("PayloadReceiver")
	if payload_receiver != null and payload_receiver.has_method("receive_payload"):
		payload_receiver.call("receive_payload", resolved_payload)
		delivered = true
	elif target.has_method("receive_damage_payload"):
		target.call("receive_damage_payload", resolved_payload)
		delivered = true
	else:
		var hit_receiver: Node = target.get_node_or_null("HitReceiver")
		if hit_receiver != null:
			if hit_receiver.has_method("receive_payload"):
				hit_receiver.call("receive_payload", resolved_payload)
				delivered = true
			elif hit_receiver.has_method("receive_hit"):
				hit_receiver.call("receive_hit", resolved_payload.amount)
				delivered = true
	if delivered:
		_apply_force_to_target(
			target,
			force_origin,
			resolved_force,
			resolved_up,
			resolved_payload.source_name
		)
		targets_hit += 1
	return delivered


func _apply_force_to_target(
	target: Node,
	force_origin: Vector3,
	strength: float,
	up_strength: float,
	source_name: String
) -> void:
	if strength <= 0.0 and up_strength <= 0.0:
		return
	var receiver: Node = _find_named_component(target, "ForceReceiver")
	if receiver == null or not receiver.has_method("apply_impulse"):
		return
	var direction: Vector3 = get_target_world_position(target) - force_origin
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		direction = cast_direction
	receiver.call(
		"apply_impulse",
		direction.normalized(),
		maxf(strength, 0.0),
		maxf(up_strength, 0.0),
		source_name
	)


func _find_named_component(root: Node, component_name: String) -> Node:
	if root == null:
		return null
	if root.name == component_name:
		return root
	var direct: Node = root.get_node_or_null(component_name)
	if direct != null:
		return direct
	for child: Node in root.get_children():
		var deeper: Node = _find_named_component(child, component_name)
		if deeper != null:
			return deeper
	return null


func is_friendly_target(target: Node) -> bool:
	if target == null:
		return false
	var cursor: Node = target
	while cursor != null:
		if cursor == owner_actor or cursor == performer_actor:
			return true
		if cursor.is_in_group("player") or cursor.is_in_group("friendly_actor"):
			return true
		cursor = cursor.get_parent()
	return false


func get_target_world_position(target: Node) -> Vector3:
	if target is Node3D:
		if target.has_method("get_targeting_aim_point"):
			var aim_value: Variant = target.call("get_targeting_aim_point")
			if aim_value is Vector3:
				return aim_value as Vector3
		return (target as Node3D).global_position
	var parent: Node = target.get_parent() if target != null else null
	return (
		(parent as Node3D).global_position
		if parent is Node3D
		else target_position
	)


func project_point_to_floor(
	point: Vector3,
	probe_height: float = 5.0,
	probe_depth: float = 12.0
) -> Vector3:
	var world: World3D = get_world_3d()
	if world == null:
		return point
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		point + Vector3.UP * probe_height,
		point + Vector3.DOWN * probe_depth,
		1
	)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var exclusions: Array[RID] = []
	if owner_actor != null:
		exclusions.append(owner_actor.get_rid())
	if performer_actor is CollisionObject3D and performer_actor != owner_actor:
		exclusions.append((performer_actor as CollisionObject3D).get_rid())
	query.exclude = exclusions
	var result: Dictionary = world.direct_space_state.intersect_ray(query)
	if result.is_empty():
		return point
	var normal_value: Variant = result.get("normal", Vector3.UP)
	if not (normal_value is Vector3):
		return point
	var normal: Vector3 = normal_value as Vector3
	if normal.dot(Vector3.UP) < 0.48:
		return point
	var position_value: Variant = result.get("position", point)
	return position_value as Vector3 if position_value is Vector3 else point


func spawn_ally_safe_fire_field(
	world_position: Vector3,
	radius: float,
	lifetime: float,
	field_payload: DamagePayload,
	field_kind: String
) -> Node3D:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null or owner_actor == null:
		return null
	var instance: Node = AllySafeFireFieldScene.instantiate()
	if not (instance is Node3D):
		if instance != null:
			instance.queue_free()
		return null
	if radius > 0.0:
		instance.set("radius", radius)
	if lifetime > 0.0:
		instance.set("lifetime", lifetime)
	if "show_debug_prints" in instance:
		instance.set("show_debug_prints", false)
	if field_payload != null and instance.has_method("set_payload"):
		instance.call("set_payload", field_payload)
	if instance.has_method("set_source_actor"):
		instance.call("set_source_actor", owner_actor)
	scene_root.add_child(instance)
	var field: Node3D = instance as Node3D
	field.global_position = world_position
	var authority_profile: ElementalAuthorityProfile = null
	if definition != null and definition.patron_avatar_definition != null:
		authority_profile = (
			definition.patron_avatar_definition.elemental_authority_profile
		)
	if authority_profile != null and instance.has_method("set_authority_context"):
		instance.call(
			"set_authority_context",
			owner_actor,
			authority_profile,
			false,
			field_kind
		)
	if instance.has_method("ignite_at"):
		instance.call("ignite_at", world_position)
	persistent_nodes_spawned += 1
	return field


func clear_hostile_projectiles(center: Vector3, radius: float) -> int:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return 0
	var cleared: int = 0
	for candidate: Node in _get_descendants(scene_root):
		if not (candidate is GenericProjectile):
			continue
		var projectile: GenericProjectile = candidate as GenericProjectile
		if projectile.is_queued_for_deletion():
			continue
		if projectile.global_position.distance_to(center) > radius:
			continue
		if _is_friendly_projectile(projectile):
			continue
		projectile.queue_free()
		cleared += 1
	projectiles_cleared += cleared
	return cleared


func _get_descendants(root: Node) -> Array[Node]:
	var descendants: Array[Node] = []
	if root == null:
		return descendants
	for child: Node in root.get_children():
		descendants.append(child)
		descendants.append_array(_get_descendants(child))
	return descendants


func _is_friendly_projectile(projectile: GenericProjectile) -> bool:
	if projectile == null:
		return false
	var source: Node = projectile.source_actor
	if source == null:
		return false
	return is_friendly_target(source)


func get_debug_data() -> Dictionary:
	return {
		"special_id": definition.special_id if definition != null else "none",
		"patron_id": definition.patron_id if definition != null else "none",
		"configured": configured,
		"started": started,
		"finished": finished,
		"success": finish_success,
		"reason": finish_reason,
		"elapsed": snappedf(elapsed, 0.01),
		"target_position": target_position,
		"cast_direction": cast_direction,
		"performer_is_owner": (
			performer_actor != null and performer_actor == owner_actor
		),
		"projection_active": (
			projection_visual != null
			and is_instance_valid(projection_visual)
		),
		"targets_hit": targets_hit,
		"projectiles_cleared": projectiles_cleared,
		"persistent_nodes_spawned": persistent_nodes_spawned,
	}
