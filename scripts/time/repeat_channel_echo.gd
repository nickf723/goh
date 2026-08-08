extends Node3D
class_name RepeatChannelEcho

@export_range(0.05, 2.0, 0.05) var water_radius: float = 0.42
@export_range(0.05, 2.0, 0.05) var fire_start_radius: float = 0.24
@export_range(0.1, 4.0, 0.05) var fire_end_radius: float = 1.35
@export_range(0.02, 1.0, 0.01) var water_damage_tick: float = 0.12
@export_range(0.02, 1.0, 0.01) var water_force_tick: float = 0.05
@export_range(0.02, 1.0, 0.01) var fire_damage_tick: float = 0.25
@export_range(0.0, 400.0, 1.0) var water_rigid_force_per_second: float = 190.0
@export_range(0.0, 80.0, 1.0) var water_character_acceleration: float = 30.0
@export_range(0.0, 30.0, 0.1) var water_character_max_speed: float = 10.0

var spell_id: String = ""
var source_proxy: Node3D = null
var payload: DamagePayload = null
var beam_outer: MeshInstance3D = null
var beam_inner: MeshInstance3D = null
var outer_material: StandardMaterial3D = null
var inner_material: StandardMaterial3D = null
var water_damage_remaining: float = 0.0
var water_force_remaining: float = 0.0
var fire_damage_remaining: float = 0.0
var sample_count: int = 0
var target_hit_count: int = 0
var pressure_event_count: int = 0
var finished: bool = false


func configure(
	channel_spell_id: String,
	proxy: Node3D,
	payload_override: Resource = null
) -> void:
	spell_id = channel_spell_id
	source_proxy = proxy
	if payload_override is DamagePayload:
		payload = (payload_override as DamagePayload).duplicate(true) as DamagePayload
	if payload == null:
		payload = _make_fallback_payload()
	name = "RepeatChannel_" + spell_id
	add_to_group("repeat_channel_echoes")
	add_to_group("clone_spell_replays")
	add_to_group("repeat_spell_replays")
	add_to_group("spell_effects")
	add_to_group("debuggable")
	_build_visuals()


func advance_sample(sample: Dictionary, delta: float) -> void:
	if finished:
		return
	var origin: Vector3 = sample.get("origin", global_position) as Vector3
	var direction: Vector3 = sample.get("direction", Vector3.FORWARD) as Vector3
	var length: float = maxf(float(sample.get("length", 0.0)), 0.05)
	if direction.length_squared() <= 0.0001:
		direction = Vector3.FORWARD
	direction = direction.normalized()
	global_position = origin
	_update_beam(origin, direction, length)
	var step: float = maxf(delta, 0.0)
	match spell_id:
		"water_jet":
			water_force_remaining -= step
			water_damage_remaining -= step
			var targets: Array[Node] = _collect_targets(origin, direction, length, water_radius, water_radius)
			if water_force_remaining <= 0.0:
				water_force_remaining += water_force_tick
				_apply_water_force(targets, direction)
			if water_damage_remaining <= 0.0:
				water_damage_remaining += water_damage_tick
				_apply_payload(targets)
		"flamethrower":
			fire_damage_remaining -= step
			if fire_damage_remaining <= 0.0:
				fire_damage_remaining += fire_damage_tick
				var targets: Array[Node] = _collect_targets(
					origin,
					direction,
					length,
					fire_start_radius,
					fire_end_radius
				)
				_apply_payload(targets)
	sample_count += 1


func finish_replay() -> void:
	if finished:
		return
	finished = true
	queue_free()


func _build_visuals() -> void:
	var outer_color: Color = (
		Color(0.18, 0.7, 1.0, 0.34)
		if spell_id == "water_jet"
		else Color(1.0, 0.22, 0.05, 0.34)
	)
	var inner_color: Color = (
		Color(0.72, 0.94, 1.0, 0.58)
		if spell_id == "water_jet"
		else Color(1.0, 0.7, 0.16, 0.62)
	)
	outer_material = _make_material(outer_color, Color(0.34, 0.44, 1.0), 2.7)
	inner_material = _make_material(inner_color, Color(0.54, 0.48, 1.0), 3.6)
	beam_outer = _make_beam("RepeatChannelOuter", outer_material)
	beam_inner = _make_beam("RepeatChannelInner", inner_material)


func _make_material(
	color: Color,
	emission_color: Color,
	energy: float
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = emission_color
	material.emission_energy_multiplier = energy
	return material


func _make_beam(node_name: String, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	mesh_instance.mesh = box
	mesh_instance.material_override = material
	add_child(mesh_instance)
	return mesh_instance


func _update_beam(origin: Vector3, direction: Vector3, length: float) -> void:
	var end: Vector3 = origin + direction * length
	_set_box_between(beam_outer, origin, end, 0.22 if spell_id == "water_jet" else 0.34)
	_set_box_between(beam_inner, origin, end, 0.09 if spell_id == "water_jet" else 0.16)


func _set_box_between(
	mesh_instance: MeshInstance3D,
	start: Vector3,
	finish: Vector3,
	thickness: float
) -> void:
	if mesh_instance == null:
		return
	var delta: Vector3 = finish - start
	var length: float = delta.length()
	if length <= 0.001:
		mesh_instance.visible = false
		return
	mesh_instance.visible = true
	var forward: Vector3 = delta / length
	var reference: Vector3 = Vector3.UP if absf(forward.dot(Vector3.UP)) < 0.94 else Vector3.RIGHT
	var right: Vector3 = reference.cross(forward).normalized()
	var up: Vector3 = forward.cross(right).normalized()
	mesh_instance.global_transform = Transform3D(
		Basis(right * thickness, up * thickness, forward * length),
		(start + finish) * 0.5
	)


func _collect_targets(
	origin: Vector3,
	direction: Vector3,
	length: float,
	start_radius: float,
	end_radius: float
) -> Array[Node]:
	var targets: Array[Node] = []
	if get_world_3d() == null:
		return targets
	var sample_count_local: int = 6
	var seen: Dictionary = {}
	for sample_index: int in range(sample_count_local):
		var ratio: float = float(sample_index + 1) / float(sample_count_local)
		var radius: float = lerpf(start_radius, end_radius, ratio)
		var shape := SphereShape3D.new()
		shape.radius = maxf(radius, 0.05)
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(
			Basis.IDENTITY,
			origin + direction * length * ratio
		)
		query.collision_mask = 0xFFFFFFFF
		query.collide_with_bodies = true
		query.collide_with_areas = true
		for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(query, 48):
			var collider_value: Variant = hit.get("collider")
			if not collider_value is Node:
				continue
			var target: Node = _find_target(collider_value as Node)
			if target == null or _ignored(target):
				continue
			var target_id: int = target.get_instance_id()
			if seen.has(target_id):
				continue
			seen[target_id] = true
			targets.append(target)
	return targets


func _find_target(start_node: Node) -> Node:
	var current: Node = start_node
	while current != null:
		if (
			current.get_node_or_null("PayloadReceiver") != null
			or current.get_node_or_null("HitReceiver") != null
			or current.has_method("receive_damage_payload")
			or current.has_method("receive_external_impulse")
			or current is RigidBody3D
			or current is CharacterBody3D
		):
			return current
		if current == get_tree().current_scene:
			break
		current = current.get_parent()
	return null


func _ignored(target: Node) -> bool:
	if target == null:
		return true
	if source_proxy != null and (target == source_proxy or source_proxy.is_ancestor_of(target)):
		return true
	return target.is_in_group("repeat_echoes") or target.is_in_group("clone_spell_replays")


func _apply_payload(targets: Array[Node]) -> void:
	if payload == null:
		return
	for target: Node in targets:
		var resolved: DamagePayload = payload.duplicate(true) as DamagePayload
		resolved.source_name = "Repeat • " + resolved.source_name
		for tag: String in ["time", "repeat", "echo", "timeline_replay"]:
			if not resolved.tags.has(tag):
				resolved.tags.append(tag)
		var receiver: Node = target.get_node_or_null("PayloadReceiver")
		if receiver != null and receiver.has_method("receive_payload"):
			receiver.call("receive_payload", resolved)
		elif target.has_method("receive_damage_payload"):
			target.call("receive_damage_payload", resolved)
		else:
			var hit_receiver: Node = target.get_node_or_null("HitReceiver")
			if hit_receiver != null and hit_receiver.has_method("receive_payload"):
				hit_receiver.call("receive_payload", resolved)
		target_hit_count += 1


func _apply_water_force(targets: Array[Node], direction: Vector3) -> void:
	for target: Node in targets:
		if target is RigidBody3D:
			var body := target as RigidBody3D
			if not body.freeze:
				body.sleeping = false
				body.apply_central_impulse(direction * water_rigid_force_per_second * water_force_tick)
		elif target.has_method("receive_external_impulse"):
			target.call(
				"receive_external_impulse",
				Vector3(direction.x, 0.0, direction.z).normalized(),
				water_character_acceleration * water_force_tick,
				direction.y * water_character_acceleration * water_force_tick,
				"Repeat • Water Jet"
			)
		elif target is CharacterBody3D:
			var character := target as CharacterBody3D
			character.velocity += direction * water_character_acceleration * water_force_tick
			var planar := Vector3(character.velocity.x, 0.0, character.velocity.z)
			if planar.length() > water_character_max_speed:
				planar = planar.normalized() * water_character_max_speed
				character.velocity.x = planar.x
				character.velocity.z = planar.z
		pressure_event_count += 1


func _make_fallback_payload() -> DamagePayload:
	var result := DamagePayload.new()
	result.element = "water" if spell_id == "water_jet" else "fire"
	result.amount = 1
	result.stance_damage = 0 if spell_id == "water_jet" else 1
	result.source_name = "Water Jet" if spell_id == "water_jet" else "Flamethrower"
	result.hit_type = "channel"
	if spell_id == "water_jet":
		result.status_effect = "wet"
		result.status_duration = 1.2
	else:
		result.status_effect = "burning"
		result.status_duration = 0.8
	result.tags = [spell_id, "channel", "magic"]
	return result


func get_debug_data() -> Dictionary:
	return {
		"repeat_channel_echo": true,
		"spell_id": spell_id,
		"samples": sample_count,
		"target_hits": target_hit_count,
		"pressure_events": pressure_event_count,
		"timeline_authoritative": true,
		"finished": finished,
	}
