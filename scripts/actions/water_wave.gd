extends Node3D
class_name WaterWave

signal target_pushed(
	target: Node,
	push_direction: Vector3,
	push_strength: float
)
signal wave_finished(target_count: int)

@export_group("Travel")
@export_range(1.0, 30.0, 0.1) var travel_speed: float = 12.0
@export_range(1.0, 30.0, 0.1) var maximum_distance: float = 9.0
@export_range(0.5, 12.0, 0.1) var starting_width: float = 2.4
@export_range(0.5, 16.0, 0.1) var ending_width: float = 7.2
@export_range(0.1, 4.0, 0.05) var wave_depth: float = 0.9
@export_range(0.2, 5.0, 0.05) var wave_height: float = 2.2
@export var origin_height_offset: float = -0.42
@export_flags_3d_physics var collision_mask: int = 1

@export_group("Push")
@export_range(0.0, 20.0, 0.1) var character_push_speed: float = 6.2
@export_range(0.0, 40.0, 0.1) var rigid_body_impulse: float = 9.0
@export_range(0.0, 8.0, 0.05) var upward_push_speed: float = 0.35
@export_range(0.0, 1.0, 0.05) var radial_direction_blend: float = 0.22
@export_range(0.1, 100.0, 0.1) var reference_mass_kg: float = 5.0
@export_range(0.05, 2.0, 0.05) var minimum_mass_multiplier: float = 0.28
@export_range(0.05, 3.0, 0.05) var maximum_mass_multiplier: float = 1.55
@export_range(0.0, 1.0, 0.05) var boss_push_multiplier: float = 0.25

@export_group("Presentation")
@export var show_debug_messages: bool = false
@export_range(3, 15, 1) var foam_segment_count: int = 9

var source_actor: Node3D
var runtime_payload: DamagePayload
var cast_origin: Vector3 = Vector3.ZERO
var cast_direction: Vector3 = Vector3.FORWARD
var resolved_maximum_distance: float = 9.0
var distance_travelled: float = 0.0
var active: bool = false
var hit_target_ids: Dictionary = {}
var hit_target_names: Array[String] = []
var collision_exclusions: Array[RID] = []
var visual_age: float = 0.0

var wave_visual_root: Node3D
var water_body: MeshInstance3D
var foam_crest: MeshInstance3D
var water_light: OmniLight3D
var foam_segments: Array[MeshInstance3D] = []


func _ready() -> void:
	add_to_group("water_wave_effects")
	add_to_group("debuggable")
	_build_visuals()
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	advance_wave(delta)


func set_payload(new_payload: Resource) -> void:
	if new_payload is DamagePayload:
		runtime_payload = (new_payload as DamagePayload).duplicate(true) as DamagePayload


func set_source_actor(new_source_actor: Node) -> void:
	if new_source_actor is Node3D:
		source_actor = new_source_actor as Node3D


func execute(player: Node3D, requested_direction: Vector3) -> void:
	if player != null:
		source_actor = player
	if source_actor == null or not is_instance_valid(source_actor):
		queue_free()
		return

	cast_direction = requested_direction
	cast_direction.y = 0.0
	if cast_direction.length_squared() <= 0.0001:
		cast_direction = -source_actor.global_transform.basis.z
		cast_direction.y = 0.0
	if cast_direction.length_squared() <= 0.0001:
		cast_direction = Vector3.FORWARD
	cast_direction = cast_direction.normalized()

	cast_origin = (
		source_actor.global_position
		+ Vector3.UP * origin_height_offset
	)
	global_transform = Transform3D(_get_wave_basis(), cast_origin)
	collision_exclusions.clear()
	_collect_collision_rids(source_actor, collision_exclusions)
	resolved_maximum_distance = _resolve_maximum_travel_distance()
	distance_travelled = 0.0
	visual_age = 0.0
	hit_target_ids.clear()
	hit_target_names.clear()
	active = true
	wave_visual_root.visible = true
	_update_visuals()
	set_physics_process(true)


func advance_wave(delta: float) -> bool:
	if not active:
		return false

	var safe_delta: float = maxf(delta, 0.0)
	var previous_distance: float = distance_travelled
	distance_travelled = minf(
		distance_travelled + travel_speed * safe_delta,
		resolved_maximum_distance
	)
	visual_age += safe_delta
	_apply_swept_wave(previous_distance, distance_travelled)
	_update_visuals()

	if distance_travelled >= resolved_maximum_distance - 0.001:
		finish_wave()
		return false
	return true


func finish_wave() -> void:
	if not active:
		return
	active = false
	set_physics_process(false)
	if wave_visual_root != null:
		wave_visual_root.visible = false
	wave_finished.emit(hit_target_ids.size())
	queue_free()


func _apply_swept_wave(
	previous_distance: float,
	current_distance: float
) -> void:
	var world: World3D = get_world_3d()
	if world == null:
		return

	var travelled_step: float = maxf(
		current_distance - previous_distance,
		0.02
	)
	var center_distance: float = (
		previous_distance + current_distance
	) * 0.5
	var progress: float = clampf(
		current_distance / maxf(resolved_maximum_distance, 0.01),
		0.0,
		1.0
	)
	var current_width: float = lerpf(
		starting_width,
		ending_width,
		progress
	)
	var shape := BoxShape3D.new()
	shape.size = Vector3(
		current_width,
		wave_height,
		wave_depth + travelled_step
	)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(
		_get_wave_basis(),
		cast_origin
		+ cast_direction * center_distance
		+ Vector3.UP * wave_height * 0.34
	)
	query.collision_mask = collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = collision_exclusions

	for result: Dictionary in world.direct_space_state.intersect_shape(
		query,
		64
	):
		var collider_value: Variant = result.get("collider")
		if not collider_value is Node:
			continue
		var target: Node = _resolve_effect_target(collider_value as Node)
		if target == null:
			continue
		var target_id: int = target.get_instance_id()
		if hit_target_ids.has(target_id):
			continue
		hit_target_ids[target_id] = true
		hit_target_names.append(str(target.name))
		_apply_wave_to_target(target)


func _resolve_effect_target(start_node: Node) -> Node:
	var current: Node = start_node
	while current != null:
		if current == source_actor or source_actor.is_ancestor_of(current):
			return null
		if _is_effect_target(current):
			return current
		if current == get_tree().current_scene:
			break
		current = current.get_parent()
	return null


func _is_effect_target(node: Node) -> bool:
	if node == null:
		return false
	if node is StaticBody3D or node is AnimatableBody3D:
		return false
	return (
		node is CharacterBody3D
		or node is RigidBody3D
		or node.get_node_or_null("ForceReceiver") != null
		or node.get_node_or_null("PayloadReceiver") != null
		or node.get_node_or_null("HitReceiver") != null
		or node.has_method("receive_external_impulse")
		or node.has_method("receive_damage_payload")
	)


func _apply_wave_to_target(target: Node) -> void:
	var target_position: Vector3 = _get_target_position(target)
	var radial_direction: Vector3 = target_position - cast_origin
	radial_direction.y = 0.0
	if radial_direction.length_squared() <= 0.0001:
		radial_direction = cast_direction
	else:
		radial_direction = radial_direction.normalized()
	var direction: Vector3 = cast_direction.lerp(
		radial_direction,
		clampf(radial_direction_blend, 0.0, 1.0)
	)
	direction.y = 0.0
	direction = (
		direction.normalized()
		if direction.length_squared() > 0.0001
		else cast_direction
	)

	_apply_water_payload(target)
	var push_strength: float = (
		character_push_speed * _get_character_push_multiplier(target)
	)
	var force_receiver: ForceReceiver = target.get_node_or_null(
		"ForceReceiver"
	) as ForceReceiver
	if force_receiver != null:
		force_receiver.apply_impulse(
			direction,
			push_strength,
			upward_push_speed,
			"Water Wave"
		)
	elif target is RigidBody3D:
		var rigid_body := target as RigidBody3D
		rigid_body.apply_central_impulse(
			direction * rigid_body_impulse
			+ Vector3.UP * upward_push_speed
		)
	elif target.has_method("receive_external_impulse"):
		target.call(
			"receive_external_impulse",
			direction,
			push_strength,
			upward_push_speed,
			"Water Wave"
		)
	elif target is CharacterBody3D:
		var character := target as CharacterBody3D
		character.velocity += (
			direction * push_strength
			+ Vector3.UP * upward_push_speed
		)

	target_pushed.emit(target, direction, push_strength)
	if show_debug_messages:
		print(
			"WATER_WAVE pushed ",
			target.name,
			" at ",
			snappedf(push_strength, 0.01),
			" m/s"
		)


func _apply_water_payload(target: Node) -> void:
	var payload: DamagePayload = get_payload().duplicate(true) as DamagePayload
	payload.amount = 0
	payload.stance_damage = 0
	payload.knockback_strength = 0.0
	payload.knockback_up_strength = 0.0
	var payload_receiver: Node = target.get_node_or_null("PayloadReceiver")
	if payload_receiver != null and payload_receiver.has_method("receive_payload"):
		payload_receiver.call("receive_payload", payload)
		return
	if target.has_method("receive_damage_payload"):
		target.call("receive_damage_payload", payload)


func get_payload() -> DamagePayload:
	if runtime_payload != null:
		return runtime_payload
	var fallback := DamagePayload.new()
	fallback.amount = 0
	fallback.stance_damage = 0
	fallback.element = "water"
	fallback.source_name = "Water Wave"
	fallback.hit_type = "wave"
	fallback.status_effect = "wet"
	fallback.status_duration = 4.0
	fallback.status_strength = 1.0
	fallback.tags = [
		"water",
		"magic",
		"wave",
		"force",
		"control",
		"wet",
		"non_damage",
	]
	return fallback


func _get_character_push_multiplier(target: Node) -> float:
	var multiplier: float = 1.0
	if target.is_in_group("boss"):
		multiplier *= boss_push_multiplier
	if target.has_meta("wave_push_multiplier"):
		multiplier *= maxf(
			float(target.get_meta("wave_push_multiplier")),
			0.0
		)

	var mass_kg: float = 0.0
	if target.has_method("get_effective_mass"):
		mass_kg = float(target.call("get_effective_mass"))
	elif target.has_method("get_mechanism_mass_kg"):
		mass_kg = float(target.call("get_mechanism_mass_kg"))
	if mass_kg > 0.0:
		multiplier *= clampf(
			sqrt(maxf(reference_mass_kg, 0.01) / mass_kg),
			minimum_mass_multiplier,
			maximum_mass_multiplier
		)
	return maxf(multiplier, 0.0)


func _get_target_position(target: Node) -> Vector3:
	if target is Node3D:
		return (target as Node3D).global_position
	var parent: Node = target.get_parent()
	return (
		(parent as Node3D).global_position
		if parent is Node3D
		else cast_origin
	)


func _resolve_maximum_travel_distance() -> float:
	var world: World3D = get_world_3d()
	if world == null:
		return maximum_distance
	var exclusions: Array[RID] = collision_exclusions.duplicate()
	var ray_start: Vector3 = cast_origin + Vector3.UP * 0.5
	var ray_end: Vector3 = ray_start + cast_direction * maximum_distance
	for _attempt: int in range(20):
		var query := PhysicsRayQueryParameters3D.create(
			ray_start,
			ray_end
		)
		query.collision_mask = collision_mask
		query.collide_with_areas = true
		query.collide_with_bodies = true
		query.exclude = exclusions
		var hit: Dictionary = world.direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return maximum_distance
		var collider_value: Variant = hit.get("collider")
		var position_value: Variant = hit.get("position")
		if not collider_value is Node or not position_value is Vector3:
			return maximum_distance
		var collider := collider_value as Node
		var target: Node = _resolve_effect_target(collider)
		if target == null:
			return clampf(
				ray_start.distance_to(position_value as Vector3) - 0.1,
				0.35,
				maximum_distance
			)
		if collider is CollisionObject3D:
			var rid: RID = (collider as CollisionObject3D).get_rid()
			if rid.is_valid() and not exclusions.has(rid):
				exclusions.append(rid)
				continue
		break
	return maximum_distance


func _get_wave_basis() -> Basis:
	var forward: Vector3 = cast_direction
	forward.y = 0.0
	forward = (
		forward.normalized()
		if forward.length_squared() > 0.0001
		else Vector3.FORWARD
	)
	var right: Vector3 = forward.cross(Vector3.UP)
	right = (
		right.normalized()
		if right.length_squared() > 0.0001
		else Vector3.RIGHT
	)
	return Basis(right, Vector3.UP, -forward).orthonormalized()


func _collect_collision_rids(
	node: Node,
	target: Array[RID]
) -> void:
	if node is CollisionObject3D:
		var rid: RID = (node as CollisionObject3D).get_rid()
		if rid.is_valid() and not target.has(rid):
			target.append(rid)
	for child: Node in node.get_children():
		_collect_collision_rids(child, target)


func _build_visuals() -> void:
	wave_visual_root = Node3D.new()
	wave_visual_root.name = "WaveVisualRoot"
	wave_visual_root.visible = false
	add_child(wave_visual_root)

	water_body = _create_box_visual(
		"WaterBody",
		Color(0.05, 0.48, 0.95, 0.48),
		2.8
	)
	wave_visual_root.add_child(water_body)
	foam_crest = _create_box_visual(
		"FoamCrest",
		Color(0.72, 0.96, 1.0, 0.72),
		4.2
	)
	wave_visual_root.add_child(foam_crest)

	for index: int in range(maxi(foam_segment_count, 3)):
		var segment := MeshInstance3D.new()
		segment.name = "FoamSegment" + str(index + 1)
		segment.cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		)
		var sphere := SphereMesh.new()
		sphere.radius = 0.22
		sphere.height = 0.44
		segment.mesh = sphere
		segment.material_override = _make_wave_material(
			Color(0.8, 0.98, 1.0, 0.78),
			4.8
		)
		wave_visual_root.add_child(segment)
		foam_segments.append(segment)

	water_light = OmniLight3D.new()
	water_light.name = "WaterLight"
	water_light.light_color = Color(0.1, 0.52, 1.0)
	water_light.light_energy = 1.6
	water_light.omni_range = 5.5
	water_light.shadow_enabled = false
	wave_visual_root.add_child(water_light)


func _create_box_visual(
	node_name: String,
	color: Color,
	emission_energy: float
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _make_wave_material(
		color,
		emission_energy
	)
	return mesh_instance


func _make_wave_material(
	color: Color,
	emission_energy: float
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b)
	material.emission_energy_multiplier = emission_energy
	return material


func _update_visuals() -> void:
	if wave_visual_root == null:
		return
	var progress: float = clampf(
		distance_travelled / maxf(resolved_maximum_distance, 0.01),
		0.0,
		1.0
	)
	var width: float = lerpf(
		starting_width,
		ending_width,
		progress
	)
	wave_visual_root.position = Vector3(
		0.0,
		wave_height * 0.34,
		-distance_travelled
	)
	var surge: float = 1.0 + sin(visual_age * 18.0) * 0.08
	if water_body != null:
		water_body.position = Vector3(0.0, -0.05, 0.0)
		water_body.scale = Vector3(
			width,
			wave_height * 0.72 * surge,
			wave_depth
		)
	if foam_crest != null:
		foam_crest.position = Vector3(
			0.0,
			wave_height * 0.38,
			-wave_depth * 0.12
		)
		foam_crest.scale = Vector3(
			width * 1.02,
			0.16,
			wave_depth * 0.72
		)

	var segment_count: int = foam_segments.size()
	for index: int in range(segment_count):
		var segment: MeshInstance3D = foam_segments[index]
		var fraction: float = (
			0.5
			if segment_count <= 1
			else float(index) / float(segment_count - 1)
		)
		var x_position: float = lerpf(-width * 0.48, width * 0.48, fraction)
		var bob: float = sin(
			visual_age * 15.0 + float(index) * 0.9
		) * 0.12
		segment.position = Vector3(
			x_position,
			wave_height * 0.48 + bob,
			-wave_depth * 0.18
		)
		var edge_scale: float = 0.72 + sin(PI * fraction) * 0.42
		segment.scale = Vector3.ONE * edge_scale
	if water_light != null:
		water_light.position = Vector3(0.0, wave_height * 0.4, 0.0)
		water_light.light_energy = 1.35 + sin(visual_age * 12.0) * 0.25


func get_debug_data() -> Dictionary:
	return {
		"water_wave": true,
		"active": active,
		"distance": snappedf(distance_travelled, 0.01),
		"maximum_distance": snappedf(resolved_maximum_distance, 0.01),
		"direction": cast_direction,
		"target_count": hit_target_ids.size(),
		"targets": hit_target_names.duplicate(),
		"zero_damage": get_payload().amount == 0,
		"zero_stance_damage": get_payload().stance_damage == 0,
	}
