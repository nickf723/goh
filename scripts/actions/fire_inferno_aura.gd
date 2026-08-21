extends Node3D
class_name FireInfernoAura

signal inferno_started(duration: float)
signal inferno_tick(affected_targets: int)
signal inferno_finished()

@export_group("Inferno Aura")
@export_range(0.5, 30.0, 0.25) var duration_seconds: float = 8.0
@export_range(0.5, 8.0, 0.1) var radius: float = 2.65
@export_range(0.1, 1.0, 0.05) var tick_interval: float = 0.38
@export_range(0.2, 4.0, 0.1) var influence_height: float = 2.2
@export_flags_3d_physics var collision_mask: int = 1

@export_group("Heat")
@export_range(0, 12, 1) var tick_damage: int = 1
@export_range(0, 12, 1) var stance_damage: int = 1
@export_range(0.2, 5.0, 0.1) var burning_duration: float = 1.45
@export_range(0.1, 4.0, 0.1) var burning_strength: float = 1.0
@export_range(0.0, 1.0, 0.05) var boss_intensity_multiplier: float = 0.42

@export_group("Presentation")
@export_range(4, 16, 1) var flame_wisp_count: int = 8
@export var flame_color: Color = Color(1.0, 0.19, 0.025, 0.72)
@export var hot_color: Color = Color(1.0, 0.76, 0.16, 0.92)
@export_range(0.0, 10.0, 0.1) var light_energy: float = 2.8

var source_actor: Node3D = null
var duration_remaining: float = 0.0
var tick_remaining: float = 0.0
var elapsed: float = 0.0
var active: bool = false
var source_exclusions: Array[RID] = []
var visual_root: Node3D = null
var flame_wisps: Array[MeshInstance3D] = []
var inferno_light: OmniLight3D = null
var last_affected_count: int = 0
var total_heat_contacts: int = 0


func _ready() -> void:
	add_to_group("inferno_auras")
	add_to_group("fire_fields")
	add_to_group("debuggable")
	_build_visuals()
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
	source_exclusions.clear()
	_collect_collision_rids(source_actor, source_exclusions)
	duration_remaining = maxf(duration_seconds, 0.5)
	tick_remaining = 0.0
	elapsed = 0.0
	last_affected_count = 0
	total_heat_contacts = 0
	active = true
	_sync_to_source()
	set_physics_process(true)
	inferno_started.emit(duration_remaining)
	_apply_heat_tick()


func _physics_process(delta: float) -> void:
	if not active:
		return
	var step: float = maxf(delta, 0.0)
	if source_actor == null or not is_instance_valid(source_actor):
		_finish_inferno()
		return
	elapsed += step
	duration_remaining = maxf(duration_remaining - step, 0.0)
	tick_remaining -= step
	_sync_to_source()
	_update_visuals()
	if tick_remaining <= 0.0:
		tick_remaining = maxf(tick_interval, 0.1)
		_apply_heat_tick()
	if duration_remaining <= 0.0:
		_finish_inferno()


func _apply_heat_tick() -> void:
	var targets: Array[Node] = _query_targets()
	last_affected_count = targets.size()
	for target: Node in targets:
		if target == null or not is_instance_valid(target):
			continue
		var intensity: float = _heat_intensity(_target_position(target))
		if target.is_in_group("boss"):
			intensity *= boss_intensity_multiplier
		if intensity <= 0.0:
			continue
		_apply_heat_hook(target, intensity)
		_apply_burning(target, intensity)
		_apply_fire_damage(target, intensity)
		total_heat_contacts += 1
	inferno_tick.emit(last_affected_count)


func _query_targets() -> Array[Node]:
	var targets: Array[Node] = []
	var world: World3D = get_world_3d()
	if world == null:
		return targets
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, global_position + Vector3.UP * 0.25)
	query.collision_mask = collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = source_exclusions
	var seen: Dictionary = {}
	for hit: Dictionary in world.direct_space_state.intersect_shape(query, 128):
		var collider_value: Variant = hit.get("collider")
		if not collider_value is Node:
			continue
		var target: Node = _resolve_heat_target(collider_value as Node)
		if target == null:
			continue
		var target_id: int = target.get_instance_id()
		if seen.has(target_id):
			continue
		seen[target_id] = true
		if absf(_target_position(target).y - global_position.y) <= influence_height:
			targets.append(target)
	return targets


func _resolve_heat_target(start_node: Node) -> Node:
	var current: Node = start_node
	while current != null:
		if current == source_actor or (source_actor != null and source_actor.is_ancestor_of(current)):
			return null
		if (
			current.get_node_or_null("PayloadReceiver") != null
			or current.get_node_or_null("StatusReceiver") != null
			or current.get_node_or_null("HitReceiver") != null
			or current.has_method("receive_payload")
			or current.has_method("receive_inferno_heat")
		):
			return current
		if current == get_tree().current_scene:
			break
		current = current.get_parent()
	return null


func _apply_heat_hook(target: Node, intensity: float) -> void:
	if target.has_method("receive_inferno_heat"):
		target.call("receive_inferno_heat", global_position, intensity, source_actor)
	if target.has_method("receive_heat"):
		target.call("receive_heat", intensity, source_actor)


func _apply_burning(target: Node, intensity: float) -> void:
	var receiver: Node = _find_status_receiver(target)
	if receiver == null or not receiver.has_method("apply_status"):
		return
	receiver.call(
		"apply_status",
		"burning",
		maxf(burning_duration * lerpf(0.65, 1.0, intensity), 0.25),
		maxf(burning_strength * intensity, 0.1),
		"Inferno"
	)


func _apply_fire_damage(target: Node, intensity: float) -> void:
	if tick_damage <= 0:
		return
	var payload := DamagePayload.new()
	payload.amount = maxi(roundi(float(tick_damage) * lerpf(0.6, 1.0, intensity)), 1)
	payload.stance_damage = maxi(roundi(float(stance_damage) * intensity), 0)
	payload.element = "fire"
	payload.source_name = "Inferno"
	payload.hit_type = "heat_aura"
	payload.tags = ["fire", "heat", "burning", "field", "aura", "magic", "contact"]
	var receiver: Node = target.get_node_or_null("PayloadReceiver")
	if receiver == null and target.has_method("receive_payload"):
		receiver = target
	if receiver != null and receiver.has_method("receive_payload"):
		receiver.call("receive_payload", payload)
		return
	var hit_receiver: Node = target.get_node_or_null("HitReceiver")
	if hit_receiver != null and hit_receiver.has_method("receive_payload"):
		hit_receiver.call("receive_payload", payload)


func _find_status_receiver(target: Node) -> Node:
	if target == null:
		return null
	if target.has_method("apply_status"):
		return target
	var receiver: Node = target.get_node_or_null("StatusReceiver")
	if receiver != null and receiver.has_method("apply_status"):
		return receiver
	var nested: Node = target.find_child("StatusReceiver", true, false)
	if nested != null and nested.has_method("apply_status"):
		return nested
	return null


func _heat_intensity(world_position: Vector3) -> float:
	var offset: Vector3 = world_position - global_position
	offset.y = 0.0
	var distance: float = offset.length()
	if distance >= radius:
		return 0.0
	return clampf(1.0 - distance / maxf(radius, 0.01), 0.2, 1.0)


func _sync_to_source() -> void:
	global_position = source_actor.global_position + Vector3.UP * 0.25


func _target_position(target: Node) -> Vector3:
	return (target as Node3D).global_position if target is Node3D else global_position


func _build_visuals() -> void:
	visual_root = Node3D.new()
	visual_root.name = "InfernoVisual"
	add_child(visual_root)
	flame_wisps.clear()
	for index: int in range(maxi(flame_wisp_count, 1)):
		var wisp := MeshInstance3D.new()
		wisp.name = "InfernoFlame%02d" % index
		wisp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mesh := SphereMesh.new()
		mesh.radius = 0.10
		mesh.height = 0.20
		mesh.radial_segments = 8
		mesh.rings = 4
		wisp.mesh = mesh
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = flame_color
		material.emission_enabled = true
		material.emission = Color(hot_color.r, hot_color.g, hot_color.b)
		material.emission_energy_multiplier = 2.2
		wisp.material_override = material
		visual_root.add_child(wisp)
		flame_wisps.append(wisp)

	inferno_light = OmniLight3D.new()
	inferno_light.name = "InfernoLight"
	inferno_light.light_color = Color(1.0, 0.29, 0.06)
	inferno_light.light_energy = light_energy
	inferno_light.omni_range = radius * 2.0
	inferno_light.shadow_enabled = false
	inferno_light.position.y = 0.8
	visual_root.add_child(inferno_light)


func _update_visuals() -> void:
	var count: int = flame_wisps.size()
	for index: int in range(count):
		var wisp: MeshInstance3D = flame_wisps[index]
		if wisp == null:
			continue
		var phase: float = float(index) / maxf(float(count), 1.0)
		var angle: float = elapsed * (2.6 + phase * 0.7) + phase * TAU
		var orbit_radius: float = lerpf(radius * 0.42, radius * 0.88, 0.5 + 0.5 * sin(elapsed * 1.3 + phase * 5.0))
		var height: float = 0.35 + 1.25 * (0.5 + 0.5 * sin(elapsed * 2.1 + phase * TAU * 1.7))
		wisp.position = Vector3(cos(angle) * orbit_radius, height, sin(angle) * orbit_radius)
		var pulse: float = 0.72 + 0.36 * (0.5 + 0.5 * sin(elapsed * 7.0 + float(index)))
		wisp.scale = Vector3(pulse, pulse * 1.7, pulse)
	if inferno_light != null:
		inferno_light.light_energy = light_energy * (0.82 + 0.18 * (sin(elapsed * 8.0) * 0.5 + 0.5))


func _collect_collision_rids(node: Node, target: Array[RID]) -> void:
	if node is CollisionObject3D:
		var rid: RID = (node as CollisionObject3D).get_rid()
		if rid.is_valid() and not target.has(rid):
			target.append(rid)
	for child: Node in node.get_children():
		_collect_collision_rids(child, target)


func _finish_inferno() -> void:
	if not active:
		return
	active = false
	set_physics_process(false)
	inferno_finished.emit()
	queue_free()


func get_debug_data() -> Dictionary:
	return {
		"spell": "inferno",
		"active": active,
		"duration_remaining": snappedf(duration_remaining, 0.01),
		"last_affected_count": last_affected_count,
		"total_heat_contacts": total_heat_contacts,
		"roaming_fire_zone": true,
		"burning_status": true,
		"heat_response_contract": true,
		"direct_damage": true,
	}
