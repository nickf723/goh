extends Node3D
class_name PoisonRadioactiveRod

signal radiation_pulse_emitted(maximum_dose: float, affected_targets: int)
signal rod_expired()

@export_group("Placement")
@export_range(1.0, 10.0, 0.1) var placement_distance: float = 4.0
@export_range(0.5, 8.0, 0.1) var ground_probe_height: float = 3.0
@export_range(0.5, 10.0, 0.1) var ground_probe_depth: float = 5.0
@export_flags_3d_physics var collision_mask: int = 1

@export_group("Radiation Field")
@export_range(1.0, 12.0, 0.1) var radius: float = 4.6
@export_range(1.0, 40.0, 0.25) var lifetime: float = 14.0
@export_range(0.1, 1.5, 0.05) var tick_interval: float = 0.45
@export_range(0.1, 8.0, 0.1) var exposure_gain_per_second: float = 1.0
@export_range(0.1, 8.0, 0.1) var exposure_decay_per_second: float = 0.72
@export_range(0.5, 10.0, 0.1) var maximum_dose: float = 3.0
@export_range(0.2, 5.0, 0.1) var influence_height: float = 2.2

@export_group("Damage")
@export_range(0, 20, 1) var base_damage: int = 1
@export_range(0, 20, 1) var high_dose_bonus_damage: int = 2
@export_range(0, 20, 1) var extreme_dose_bonus_damage: int = 2
@export_range(0.0, 8.0, 0.1) var stance_damage: float = 0.5

@export_group("Presentation")
@export var rod_color: Color = Color(0.66, 1.0, 0.08, 1.0)
@export var field_color: Color = Color(0.52, 1.0, 0.12, 0.20)
@export var show_debug_messages: bool = false

var source_actor: Node3D = null
var field_origin: Vector3 = Vector3.ZERO
var elapsed: float = 0.0
var tick_remaining: float = 0.0
var active: bool = false
var source_exclusions: Array[RID] = []
var exposure_by_id: Dictionary = {}
var target_refs_by_id: Dictionary = {}
var target_names_by_id: Dictionary = {}
var last_maximum_dose: float = 0.0
var last_affected_count: int = 0
var rod_visual: MeshInstance3D = null
var aura_visual: MeshInstance3D = null
var aura_material: StandardMaterial3D = null


func _ready() -> void:
	add_to_group("radiation_fields")
	add_to_group("hazard_reactive")
	add_to_group("debuggable")
	_build_visuals()
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
	var direction: Vector3 = cast_direction
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		direction = -source_actor.global_basis.z
		direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		direction = Vector3.FORWARD
	direction = direction.normalized()

	var desired: Vector3 = source_actor.global_position + direction * placement_distance
	field_origin = _resolve_ground_point(desired)
	global_position = field_origin
	elapsed = 0.0
	tick_remaining = 0.0
	exposure_by_id.clear()
	target_refs_by_id.clear()
	target_names_by_id.clear()
	last_maximum_dose = 0.0
	last_affected_count = 0
	active = true
	set_physics_process(true)
	_apply_radiation_tick(tick_interval)


func _physics_process(delta: float) -> void:
	if not active:
		return
	var step: float = maxf(delta, 0.0)
	elapsed += step
	tick_remaining -= step
	_update_visuals()
	if tick_remaining <= 0.0:
		tick_remaining = maxf(tick_interval, 0.1)
		_apply_radiation_tick(tick_remaining)
	if elapsed >= lifetime:
		_finish_rod()


func _apply_radiation_tick(step: float) -> void:
	var targets: Array[Node] = _query_targets()
	var present_ids: Dictionary = {}
	last_maximum_dose = 0.0
	last_affected_count = targets.size()

	for target: Node in targets:
		if target == null or not is_instance_valid(target):
			continue
		var target_id: int = target.get_instance_id()
		present_ids[target_id] = true
		target_refs_by_id[target_id] = weakref(target)
		target_names_by_id[target_id] = str(target.name)
		var intensity: float = _field_intensity(_target_position(target))
		var gain: float = exposure_gain_per_second * maxf(step, 0.0) * lerpf(0.38, 1.0, intensity)
		var dose: float = clampf(
			float(exposure_by_id.get(target_id, 0.0)) + gain,
			0.0,
			maximum_dose
		)
		exposure_by_id[target_id] = dose
		last_maximum_dose = maxf(last_maximum_dose, dose)
		_apply_exposure_hook(target, dose, intensity)
		_apply_radiation_damage(target, dose, intensity)

	for key: Variant in exposure_by_id.keys():
		var target_id: int = int(key)
		if present_ids.has(target_id):
			continue
		var decayed: float = maxf(
			float(exposure_by_id.get(target_id, 0.0))
			- exposure_decay_per_second * maxf(step, 0.0),
			0.0
		)
		if decayed <= 0.001:
			exposure_by_id.erase(target_id)
			target_refs_by_id.erase(target_id)
			target_names_by_id.erase(target_id)
		else:
			exposure_by_id[target_id] = decayed

	radiation_pulse_emitted.emit(last_maximum_dose, last_affected_count)
	if show_debug_messages and last_affected_count > 0:
		print(
			"RADIOACTIVE ROD targets=", last_affected_count,
			" max_dose=", snappedf(last_maximum_dose, 0.01)
		)


func _query_targets() -> Array[Node]:
	var result: Array[Node] = []
	var world: World3D = get_world_3d()
	if world == null:
		return result
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, field_origin + Vector3.UP * influence_height * 0.22)
	query.collision_mask = collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = source_exclusions
	var seen: Dictionary = {}
	for hit: Dictionary in world.direct_space_state.intersect_shape(query, 128):
		var collider_value: Variant = hit.get("collider")
		if not collider_value is Node:
			continue
		var target: Node = _resolve_damage_target(collider_value as Node)
		if target == null:
			continue
		var id: int = target.get_instance_id()
		if seen.has(id):
			continue
		seen[id] = true
		if absf(_target_position(target).y - field_origin.y) <= influence_height:
			result.append(target)
	return result


func _resolve_damage_target(start_node: Node) -> Node:
	var current: Node = start_node
	while current != null:
		if current == source_actor or (source_actor != null and source_actor.is_ancestor_of(current)):
			return null
		if (
			current.get_node_or_null("PayloadReceiver") != null
			or current.get_node_or_null("HitReceiver") != null
			or current.has_method("receive_payload")
			or current.has_method("receive_radiation_exposure")
		):
			return current
		if current == get_tree().current_scene:
			break
		current = current.get_parent()
	return null


func _apply_radiation_damage(target: Node, dose: float, intensity: float) -> void:
	var amount: int = base_damage
	if dose >= maximum_dose * 0.48:
		amount += high_dose_bonus_damage
	if dose >= maximum_dose * 0.82:
		amount += extreme_dose_bonus_damage
	amount = maxi(roundi(float(amount) * lerpf(0.65, 1.0, intensity)), 0)
	if amount <= 0:
		return

	var payload := DamagePayload.new()
	payload.amount = amount
	payload.stance_damage = maxi(roundi(stance_damage * lerpf(0.6, 1.0, intensity)), 0)
	payload.element = "poison"
	payload.source_name = "Radioactive Rod"
	payload.hit_type = "radiation"
	payload.tags = [
		"poison",
		"radiation",
		"chemical",
		"field",
		"hazard",
		"magic",
		"exposure",
	]

	var receiver: Node = target.get_node_or_null("PayloadReceiver")
	if receiver == null and target.has_method("receive_payload"):
		receiver = target
	if receiver != null and receiver.has_method("receive_payload"):
		receiver.call("receive_payload", payload)
		return
	var hit_receiver: Node = target.get_node_or_null("HitReceiver")
	if hit_receiver != null and hit_receiver.has_method("receive_payload"):
		hit_receiver.call("receive_payload", payload)


func _apply_exposure_hook(target: Node, dose: float, intensity: float) -> void:
	if target.has_method("receive_radiation_exposure"):
		target.call(
			"receive_radiation_exposure",
			dose,
			intensity,
			source_actor
		)


func _field_intensity(world_position: Vector3) -> float:
	var offset: Vector3 = world_position - field_origin
	offset.y = 0.0
	var distance: float = offset.length()
	if distance >= radius:
		return 0.0
	var normalized: float = 1.0 - distance / maxf(radius, 0.01)
	return smoothstep(0.0, 1.0, normalized)


func _target_position(target: Node) -> Vector3:
	return (target as Node3D).global_position if target is Node3D else field_origin


func _build_visuals() -> void:
	rod_visual = MeshInstance3D.new()
	rod_visual.name = "RadioactiveRodVisual"
	rod_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var rod_mesh := CylinderMesh.new()
	rod_mesh.top_radius = 0.11
	rod_mesh.bottom_radius = 0.16
	rod_mesh.height = 1.65
	rod_mesh.radial_segments = 12
	rod_visual.mesh = rod_mesh
	rod_visual.position.y = rod_mesh.height * 0.5
	var rod_material := StandardMaterial3D.new()
	rod_material.albedo_color = rod_color
	rod_material.metallic = 0.28
	rod_material.roughness = 0.36
	rod_material.emission_enabled = true
	rod_material.emission = Color(rod_color.r, rod_color.g, rod_color.b)
	rod_material.emission_energy_multiplier = 1.65
	rod_visual.material_override = rod_material
	add_child(rod_visual)

	aura_visual = MeshInstance3D.new()
	aura_visual.name = "RadiationFieldVisual"
	aura_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var aura_mesh := CylinderMesh.new()
	aura_mesh.top_radius = radius
	aura_mesh.bottom_radius = radius
	aura_mesh.height = 0.035
	aura_mesh.radial_segments = 48
	aura_visual.mesh = aura_mesh
	aura_visual.position.y = 0.025
	aura_material = StandardMaterial3D.new()
	aura_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aura_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	aura_material.albedo_color = field_color
	aura_material.emission_enabled = true
	aura_material.emission = Color(field_color.r, field_color.g, field_color.b)
	aura_material.emission_energy_multiplier = 0.48
	aura_visual.material_override = aura_material
	add_child(aura_visual)


func _update_visuals() -> void:
	if aura_visual == null:
		return
	var pulse: float = 1.0 + sin(elapsed * 3.8) * 0.035
	aura_visual.scale = Vector3(pulse, 1.0, pulse)
	if aura_material != null:
		aura_material.emission_energy_multiplier = 0.42 + 0.16 * (sin(elapsed * 5.2) * 0.5 + 0.5)


func _resolve_ground_point(world_position: Vector3) -> Vector3:
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
	query.exclude = source_exclusions
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	var position_value: Variant = hit.get("position")
	if position_value is Vector3:
		return (position_value as Vector3) + Vector3.UP * 0.02
	return world_position


func _collect_collision_rids(node: Node, target: Array[RID]) -> void:
	if node is CollisionObject3D:
		var rid: RID = (node as CollisionObject3D).get_rid()
		if rid.is_valid() and not target.has(rid):
			target.append(rid)
	for child: Node in node.get_children():
		_collect_collision_rids(child, target)


func _finish_rod() -> void:
	if not active:
		return
	active = false
	set_physics_process(false)
	rod_expired.emit()
	queue_free()


func get_debug_data() -> Dictionary:
	return {
		"spell": "radioactive_rod",
		"active": active,
		"radius": radius,
		"elapsed": snappedf(elapsed, 0.01),
		"last_affected_count": last_affected_count,
		"last_maximum_dose": snappedf(last_maximum_dose, 0.01),
		"tracked_exposures": exposure_by_id.size(),
		"cumulative_exposure": true,
		"radiation_response_contract": true,
		"direct_damage": true,
		"cloud_clone": false,
	}
