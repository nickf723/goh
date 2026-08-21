extends Node3D
class_name EarthquakeField

signal seismic_pulse_emitted(pulse_index: int, radius: float, strength: float)
signal earthquake_finished(pulses: int, affected_targets: int)

@export_group("Seismic Pulse")
@export_range(1, 16, 1) var pulse_count: int = 7
@export_range(0.08, 1.0, 0.01) var pulse_interval: float = 0.26
@export_range(0.5, 8.0, 0.1) var starting_radius: float = 2.4
@export_range(1.0, 18.0, 0.1) var ending_radius: float = 8.5
@export_range(0.2, 6.0, 0.1) var query_height: float = 2.8
@export_flags_3d_physics var collision_mask: int = 1

@export_group("Physical Response")
@export_range(0.0, 30.0, 0.1) var horizontal_impulse: float = 5.8
@export_range(0.0, 20.0, 0.1) var upward_impulse: float = 2.7
@export_range(0.0, 2.0, 0.05) var airborne_multiplier: float = 0.18
@export_range(0.0, 1.0, 0.05) var boss_multiplier: float = 0.28
@export_range(0.05, 3.0, 0.05) var minimum_response: float = 0.25
@export_range(0.05, 3.0, 0.05) var maximum_response: float = 1.5
@export_range(1.0, 1000.0, 1.0) var reference_mass_kg: float = 70.0

@export_group("Presentation")
@export var show_debug_messages: bool = false
@export var pulse_color: Color = Color(0.42, 0.78, 0.30, 0.32)

var source_actor: Node3D = null
var epicenter: Vector3 = Vector3.ZERO
var elapsed: float = 0.0
var next_pulse_time: float = 0.0
var emitted_pulses: int = 0
var active: bool = false
var collision_exclusions: Array[RID] = []
var affected_target_ids: Dictionary = {}
var affected_target_names: Array[String] = []


func _ready() -> void:
	add_to_group("earthquake_fields")
	add_to_group("debuggable")
	set_physics_process(false)


func set_source_actor(actor: Node) -> void:
	if actor is Node3D and is_instance_valid(actor):
		source_actor = actor as Node3D


func execute(player: Node3D, _cast_direction: Vector3) -> void:
	if source_actor == null:
		source_actor = player
	if source_actor == null or not is_instance_valid(source_actor):
		queue_free()
		return

	collision_exclusions.clear()
	_collect_collision_rids(source_actor, collision_exclusions)
	epicenter = _resolve_ground_point(source_actor.global_position)
	global_position = epicenter
	elapsed = 0.0
	next_pulse_time = 0.0
	emitted_pulses = 0
	affected_target_ids.clear()
	affected_target_names.clear()
	active = true
	set_physics_process(true)
	_emit_due_pulses()


func _physics_process(delta: float) -> void:
	if not active:
		return
	elapsed += maxf(delta, 0.0)
	_emit_due_pulses()
	if emitted_pulses >= pulse_count:
		var recovery: float = maxf(pulse_interval * 0.7, 0.08)
		if elapsed >= float(maxi(pulse_count - 1, 0)) * pulse_interval + recovery:
			_finish_earthquake()


func _emit_due_pulses() -> void:
	while active and emitted_pulses < pulse_count and elapsed + 0.0001 >= next_pulse_time:
		_emit_seismic_pulse(emitted_pulses)
		emitted_pulses += 1
		next_pulse_time = float(emitted_pulses) * pulse_interval


func _emit_seismic_pulse(index: int) -> void:
	var denominator: float = maxf(float(pulse_count - 1), 1.0)
	var progress: float = clampf(float(index) / denominator, 0.0, 1.0)
	var radius: float = lerpf(starting_radius, ending_radius, progress)
	var strength: float = lerpf(0.62, 1.0, sin(progress * PI))
	if index == pulse_count - 1:
		strength = maxf(strength, 0.74)
	_apply_pulse_to_physics(radius, strength, index)
	_apply_pulse_to_registered_responders(radius, strength, index)
	_spawn_pulse_visual(radius, strength)
	seismic_pulse_emitted.emit(index, radius, strength)
	if show_debug_messages:
		print(
			"EARTHQUAKE pulse=", index,
			" radius=", snappedf(radius, 0.1),
			" strength=", snappedf(strength, 0.01)
		)


func _apply_pulse_to_physics(radius: float, strength: float, index: int) -> void:
	var world: World3D = get_world_3d()
	if world == null:
		return
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, epicenter + Vector3.UP * query_height * 0.22)
	query.collision_mask = collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = collision_exclusions
	var seen: Dictionary = {}
	for hit: Dictionary in world.direct_space_state.intersect_shape(query, 128):
		var collider_value: Variant = hit.get("collider")
		if not collider_value is Node:
			continue
		var target: Node = _resolve_seismic_target(collider_value as Node)
		if target == null:
			continue
		var target_id: int = target.get_instance_id()
		if seen.has(target_id):
			continue
		seen[target_id] = true
		_apply_seismic_response(target, radius, strength, index)


func _apply_pulse_to_registered_responders(radius: float, strength: float, index: int) -> void:
	if get_tree() == null:
		return
	for candidate: Node in get_tree().get_nodes_in_group("seismic_responsive"):
		if candidate == null or not is_instance_valid(candidate):
			continue
		if not candidate is Node3D:
			continue
		var target := candidate as Node3D
		if target.global_position.distance_to(epicenter) > radius:
			continue
		var target_id: int = target.get_instance_id()
		if affected_target_ids.has("hook:" + str(target_id) + ":" + str(index)):
			continue
		affected_target_ids["hook:" + str(target_id) + ":" + str(index)] = true
		_call_seismic_hook(target, strength, index)


func _apply_seismic_response(target: Node, radius: float, strength: float, index: int) -> void:
	var position: Vector3 = _target_position(target)
	if absf(position.y - epicenter.y) > query_height:
		return
	var planar: Vector3 = position - epicenter
	planar.y = 0.0
	var distance: float = planar.length()
	if distance > radius + 0.2:
		return
	var direction: Vector3 = planar.normalized() if distance > 0.05 else Vector3.RIGHT.rotated(Vector3.UP, float(index) * 1.618)
	var radial_falloff: float = clampf(1.0 - distance / maxf(radius, 0.1), 0.16, 1.0)
	var response: float = strength * lerpf(0.58, 1.0, radial_falloff)
	if target.is_in_group("boss"):
		response *= boss_multiplier
	if target is CharacterBody3D and not (target as CharacterBody3D).is_on_floor():
		response *= airborne_multiplier
	response *= _mass_response_multiplier(target)
	response = clampf(response, minimum_response, maximum_response)

	_call_seismic_hook(target, response, index)
	var force_receiver: Node = target.get_node_or_null("ForceReceiver")
	if force_receiver != null and force_receiver.has_method("apply_impulse"):
		force_receiver.call(
			"apply_impulse",
			direction,
			horizontal_impulse * response,
			upward_impulse * response,
			"Earthquake"
		)
	elif target is RigidBody3D:
		var body := target as RigidBody3D
		body.apply_central_impulse(
			direction * horizontal_impulse * response
			+ Vector3.UP * upward_impulse * response
		)
	elif target.has_method("receive_external_impulse"):
		target.call(
			"receive_external_impulse",
			direction,
			horizontal_impulse * response,
			upward_impulse * response,
			"Earthquake"
		)
	elif target is CharacterBody3D:
		var character := target as CharacterBody3D
		character.velocity += (
			direction * horizontal_impulse * response
			+ Vector3.UP * upward_impulse * response
		)

	var id_key: String = str(target.get_instance_id())
	if not affected_target_ids.has(id_key):
		affected_target_ids[id_key] = true
		affected_target_names.append(str(target.name))


func _call_seismic_hook(target: Node, strength: float, index: int) -> void:
	if target.has_method("receive_earthquake_pulse"):
		target.call(
			"receive_earthquake_pulse",
			epicenter,
			strength,
			index,
			source_actor
		)
	elif target.has_method("receive_seismic_pulse"):
		target.call(
			"receive_seismic_pulse",
			epicenter,
			strength,
			index,
			source_actor
		)


func _resolve_seismic_target(start_node: Node) -> Node:
	var current: Node = start_node
	while current != null:
		if current == source_actor or (source_actor != null and source_actor.is_ancestor_of(current)):
			return null
		if _is_seismic_target(current):
			return current
		if current == get_tree().current_scene:
			break
		current = current.get_parent()
	return null


func _is_seismic_target(node: Node) -> bool:
	if node == null or node is StaticBody3D:
		return false
	return (
		node is CharacterBody3D
		or node is RigidBody3D
		or node.get_node_or_null("ForceReceiver") != null
		or node.has_method("receive_external_impulse")
		or node.has_method("receive_earthquake_pulse")
		or node.has_method("receive_seismic_pulse")
	)


func _mass_response_multiplier(target: Node) -> float:
	var mass_kg: float = 0.0
	if target is RigidBody3D:
		mass_kg = (target as RigidBody3D).mass
	elif target.has_method("get_effective_mass"):
		mass_kg = float(target.call("get_effective_mass"))
	elif target.has_method("get_mechanism_mass_kg"):
		mass_kg = float(target.call("get_mechanism_mass_kg"))
	if mass_kg <= 0.0:
		return 1.0
	return clampf(
		sqrt(maxf(reference_mass_kg, 0.01) / mass_kg),
		minimum_response,
		maximum_response
	)


func _resolve_ground_point(world_position: Vector3) -> Vector3:
	var world: World3D = get_world_3d()
	if world == null:
		return world_position
	var query := PhysicsRayQueryParameters3D.create(
		world_position + Vector3.UP * 1.5,
		world_position + Vector3.DOWN * 4.5
	)
	query.collision_mask = collision_mask
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = collision_exclusions
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	var position_value: Variant = hit.get("position")
	return (position_value as Vector3) + Vector3.UP * 0.02 if position_value is Vector3 else world_position


func _target_position(target: Node) -> Vector3:
	if target is Node3D:
		return (target as Node3D).global_position
	return epicenter


func _spawn_pulse_visual(radius: float, strength: float) -> void:
	if get_tree() == null or get_tree().current_scene == null:
		return
	var ring := MeshInstance3D.new()
	ring.name = "EarthquakePulse"
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 0.018
	mesh.radial_segments = 48
	ring.mesh = mesh
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var color: Color = pulse_color
	color.a *= clampf(strength, 0.35, 1.0)
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b)
	material.emission_energy_multiplier = 0.45 + strength * 0.55
	ring.material_override = material
	get_tree().current_scene.add_child(ring)
	ring.global_position = epicenter + Vector3.UP * (0.025 + float(emitted_pulses) * 0.002)
	ring.scale = Vector3(0.18, 0.1, 0.18)
	var tween := ring.create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ring, "scale", Vector3(radius, 0.08, radius), pulse_interval * 1.35)
	tween.parallel().tween_property(material, "albedo_color:a", 0.0, pulse_interval * 1.35)
	tween.finished.connect(ring.queue_free)


func _collect_collision_rids(node: Node, target: Array[RID]) -> void:
	if node is CollisionObject3D:
		var rid: RID = (node as CollisionObject3D).get_rid()
		if rid.is_valid() and not target.has(rid):
			target.append(rid)
	for child: Node in node.get_children():
		_collect_collision_rids(child, target)


func _finish_earthquake() -> void:
	if not active:
		return
	active = false
	set_physics_process(false)
	earthquake_finished.emit(emitted_pulses, affected_target_names.size())
	queue_free()


func get_debug_data() -> Dictionary:
	return {
		"spell": "earthquake",
		"active": active,
		"epicenter": epicenter,
		"emitted_pulses": emitted_pulses,
		"pulse_count": pulse_count,
		"affected_targets": affected_target_names.duplicate(),
		"seismic_response_contract": true,
		"direct_damage": false,
		"environmental": true,
	}
