extends Node3D
class_name PlayerBubbleShieldController

signal bubble_activated(duration: float, refreshed: bool)
signal bubble_absorbed(payload: DamagePayload, attacker: Node3D, result: Dictionary)
signal bubble_burst(origin: Vector3, affected_targets: int)
signal bubble_ended(reason: String)

enum ShieldState {
	INACTIVE,
	ACTIVE,
	BURSTING,
}

@export_group("Shield")
@export_range(0.25, 60.0, 0.1) var duration_seconds: float = 12.0
@export var refresh_duration_on_recast: bool = true

@export_group("Burst")
@export_range(0.5, 12.0, 0.1) var burst_radius: float = 4.0
@export_range(0.0, 20.0, 0.1) var burst_knockback: float = 6.5
@export_range(0.0, 8.0, 0.1) var burst_upward_knockback: float = 1.1
@export_range(0.0, 1.0, 0.05) var boss_knockback_multiplier: float = 0.25
@export_range(0.0, 30.0, 0.1) var rigid_body_impulse: float = 5.5
@export_flags_3d_physics var collision_mask: int = 1
@export_range(1, 256, 1) var maximum_burst_candidates: int = 64

@export_group("Presentation")
@export_range(0.5, 3.0, 0.05) var bubble_radius: float = 1.15
@export_range(0.5, 2.5, 0.05) var bubble_height_scale: float = 1.2
@export_range(0.05, 2.0, 0.05) var burst_visual_seconds: float = 0.32
@export_range(5.0, 120.0, 1.0) var visual_updates_per_second: float = 30.0

var state: ShieldState = ShieldState.INACTIVE
var active_remaining: float = 0.0
var burst_remaining: float = 0.0
var visual_accumulator: float = 0.0
var activation_count: int = 0
var absorb_count: int = 0
var burst_count: int = 0
var last_end_reason: String = "never_activated"
var last_absorbed_source: String = "none"
var last_burst_target_names: Array[String] = []

var actor: Node3D
var runtime_burst_payload: DamagePayload
var bubble_visual: MeshInstance3D
var bubble_material: StandardMaterial3D
var broadphase_shape: SphereShape3D
var broadphase_query: PhysicsShapeQueryParameters3D
var collision_exclusions: Array[RID] = []


func _ready() -> void:
	actor = get_parent() as Node3D
	add_to_group("bubble_shield_controllers")
	add_to_group("debuggable")
	_build_visual()
	_build_broadphase_query()
	set_process(false)


func activate_bubble(
	burst_payload: Resource = null,
	duration_override: float = -1.0
) -> Dictionary:
	if actor == null or not is_instance_valid(actor):
		return {
			"activated": false,
			"reason": "missing_actor",
		}

	if burst_payload is DamagePayload:
		var duplicate_value: Resource = (burst_payload as DamagePayload).duplicate(true)
		runtime_burst_payload = (
			duplicate_value as DamagePayload
			if duplicate_value is DamagePayload
			else burst_payload as DamagePayload
		)
		runtime_burst_payload.suppress_reactions = true

	var refreshed: bool = state == ShieldState.ACTIVE
	state = ShieldState.ACTIVE
	var resolved_duration: float = (
		duration_override
		if duration_override > 0.0
		else duration_seconds
	)
	if refreshed and not refresh_duration_on_recast:
		active_remaining = maxf(active_remaining, resolved_duration)
	else:
		active_remaining = maxf(resolved_duration, 0.25)
	burst_remaining = 0.0
	visual_accumulator = 0.0
	activation_count += 1
	last_end_reason = "active"
	last_absorbed_source = "none"
	last_burst_target_names.clear()
	_refresh_collision_exclusions()
	_set_spell_effect_groups(true, true)
	if bubble_visual != null:
		bubble_visual.visible = true
		bubble_visual.transparency = 0.0
		bubble_visual.scale = _base_visual_scale()
	set_process(true)
	_update_visual()
	bubble_activated.emit(active_remaining, refreshed)
	return {
		"activated": true,
		"refreshed": refreshed,
		"duration": active_remaining,
	}


func is_bubble_active() -> bool:
	return state == ShieldState.ACTIVE


func absorb_incoming_hit(
	payload: DamagePayload,
	attacker: Node3D = null
) -> Dictionary:
	if state != ShieldState.ACTIVE:
		return {
			"absorbed": false,
			"reason": "inactive",
		}
	if payload == null:
		return {
			"absorbed": false,
			"reason": "invalid_payload",
		}

	absorb_count += 1
	last_absorbed_source = payload.source_name
	active_remaining = 0.0
	var affected_targets: int = _apply_burst_force(attacker)
	state = ShieldState.BURSTING
	burst_remaining = maxf(burst_visual_seconds, 0.05)
	visual_accumulator = 0.0
	_set_spell_effect_groups(true, false)
	set_process(true)
	_update_visual()

	var result: Dictionary = {
		"absorbed": true,
		"source": payload.source_name,
		"negated_damage": payload.amount,
		"negated_stance_damage": payload.stance_damage,
		"burst_targets": affected_targets,
		"message": (
			"Bubble absorbs "
			+ payload.source_name
			+ " and bursts outward."
		),
	}
	bubble_absorbed.emit(payload, attacker, result.duplicate(true))
	return result


func expire_bubble(reason: String = "expired") -> void:
	if state == ShieldState.INACTIVE:
		return
	state = ShieldState.BURSTING
	active_remaining = 0.0
	burst_remaining = maxf(burst_visual_seconds * 0.65, 0.05)
	last_end_reason = reason
	_set_spell_effect_groups(true, false)
	set_process(true)
	_update_visual()


func reset_target() -> void:
	_finish_bubble("reset")


func _process(delta: float) -> void:
	var safe_delta: float = maxf(delta, 0.0)
	match state:
		ShieldState.ACTIVE:
			active_remaining = maxf(active_remaining - safe_delta, 0.0)
			if active_remaining <= 0.0:
				expire_bubble("duration_complete")
		ShieldState.BURSTING:
			burst_remaining = maxf(burst_remaining - safe_delta, 0.0)
			if burst_remaining <= 0.0:
				_finish_bubble(
					"absorbed_hit"
					if last_absorbed_source != "none"
					else last_end_reason
				)
				return
		ShieldState.INACTIVE:
			set_process(false)
			return

	visual_accumulator += safe_delta
	var visual_interval: float = 1.0 / maxf(visual_updates_per_second, 1.0)
	if visual_accumulator >= visual_interval:
		visual_accumulator = fmod(visual_accumulator, visual_interval)
		_update_visual()


func _apply_burst_force(attacker: Node3D = null) -> int:
	burst_count += 1
	last_burst_target_names.clear()
	var world: World3D = get_world_3d()
	if world == null or broadphase_query == null:
		bubble_burst.emit(global_position, 0)
		return 0

	_refresh_collision_exclusions()
	var burst_origin: Vector3 = _get_burst_origin()
	broadphase_query.transform = Transform3D(Basis.IDENTITY, burst_origin)
	broadphase_query.exclude = collision_exclusions
	var results: Array[Dictionary] = world.direct_space_state.intersect_shape(
		broadphase_query,
		maximum_burst_candidates
	)
	var seen_targets: Dictionary = {}
	var affected: int = 0
	for result: Dictionary in results:
		var collider_value: Variant = result.get("collider")
		if not collider_value is Node:
			continue
		var target: Node = _resolve_force_target(collider_value as Node)
		if target == null:
			continue
		var target_id: int = target.get_instance_id()
		if seen_targets.has(target_id):
			continue
		seen_targets[target_id] = true
		if _apply_force_to_target(target, burst_origin, attacker):
			affected += 1
			last_burst_target_names.append(str(target.name))

	bubble_burst.emit(burst_origin, affected)
	return affected


func _apply_force_to_target(
	target: Node,
	burst_origin: Vector3,
	attacker: Node3D
) -> bool:
	if target == null or target == actor:
		return false
	var direction: Vector3 = _get_target_center(target) - burst_origin
	direction.y = 0.0
	if direction.length_squared() <= 0.0001 and attacker != null:
		direction = attacker.global_position - burst_origin
		direction.y = 0.0
	if direction.length_squared() <= 0.0001 and actor != null:
		direction = -actor.global_transform.basis.z
		direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		direction = Vector3.FORWARD
	direction = direction.normalized()

	var strength: float = maxf(burst_knockback, 0.0)
	var upward: float = maxf(burst_upward_knockback, 0.0)
	if target.is_in_group("boss"):
		strength *= clampf(boss_knockback_multiplier, 0.0, 1.0)
		upward *= clampf(boss_knockback_multiplier, 0.0, 1.0)

	var force_receiver: Node = _get_component(target, "ForceReceiver")
	if force_receiver != null and force_receiver.has_method("apply_impulse"):
		force_receiver.call(
			"apply_impulse",
			direction,
			strength,
			upward,
			"Bubble Burst"
		)
		return true

	if target is RigidBody3D:
		var rigid_body := target as RigidBody3D
		rigid_body.apply_central_impulse(
			direction * maxf(rigid_body_impulse, 0.0)
			+ Vector3.UP * upward
		)
		return true

	if target is CharacterBody3D:
		var character := target as CharacterBody3D
		character.velocity += direction * strength + Vector3.UP * upward
		return true

	return false


func _resolve_force_target(start_node: Node) -> Node:
	var current: Node = start_node
	while current != null:
		if current == actor or (
			actor != null
			and actor.is_ancestor_of(current)
		):
			return null
		if (
			_get_component(current, "ForceReceiver") != null
			or current is RigidBody3D
			or current is CharacterBody3D
		):
			return current
		if current == get_tree().current_scene:
			break
		current = current.get_parent()
	return null


func _get_component(target: Node, component_name: String) -> Node:
	if target == null:
		return null
	return target.get_node_or_null(component_name)


func _get_target_center(target: Node) -> Vector3:
	if target == null:
		return _get_burst_origin()
	var collision_shape: CollisionShape3D = target.get_node_or_null(
		"CollisionShape3D"
	) as CollisionShape3D
	if collision_shape != null:
		return collision_shape.global_position
	if target is Node3D:
		return (target as Node3D).global_position
	var parent: Node = target.get_parent()
	return (
		(parent as Node3D).global_position
		if parent is Node3D
		else _get_burst_origin()
	)


func _get_burst_origin() -> Vector3:
	if actor != null and is_instance_valid(actor):
		return actor.global_position + Vector3.UP * 0.55
	return global_position


func _build_visual() -> void:
	bubble_visual = MeshInstance3D.new()
	bubble_visual.name = "BubbleShieldVisual"
	bubble_visual.position = Vector3(0.0, 0.52, 0.0)
	bubble_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bubble_visual.visibility_range_end = 34.0
	bubble_visual.visibility_range_end_margin = 4.0
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
	bubble_visual.mesh = mesh

	bubble_material = StandardMaterial3D.new()
	bubble_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bubble_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bubble_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	bubble_material.albedo_color = Color(0.28, 0.72, 1.0, 0.24)
	bubble_material.emission_enabled = true
	bubble_material.emission = Color(0.12, 0.58, 1.0)
	bubble_material.emission_energy_multiplier = 1.7
	bubble_material.rim_enabled = true
	bubble_material.rim = 0.82
	bubble_material.rim_tint = 0.55
	bubble_visual.material_override = bubble_material
	bubble_visual.scale = _base_visual_scale()
	bubble_visual.visible = false
	add_child(bubble_visual)


func _base_visual_scale() -> Vector3:
	return Vector3(
		bubble_radius,
		bubble_radius * bubble_height_scale,
		bubble_radius
	)


func _update_visual() -> void:
	if bubble_visual == null:
		return
	match state:
		ShieldState.ACTIVE:
			var time_value: float = Time.get_ticks_msec() * 0.001
			var pulse: float = 1.0 + sin(time_value * 4.8) * 0.035
			bubble_visual.scale = _base_visual_scale() * pulse
			bubble_visual.transparency = 0.0
		ShieldState.BURSTING:
			var ratio: float = clampf(
				burst_remaining / maxf(burst_visual_seconds, 0.05),
				0.0,
				1.0
			)
			var expansion: float = lerpf(1.65, 1.0, ratio)
			bubble_visual.scale = _base_visual_scale() * expansion
			bubble_visual.transparency = 1.0 - ratio
		ShieldState.INACTIVE:
			bubble_visual.visible = false


func _build_broadphase_query() -> void:
	broadphase_shape = SphereShape3D.new()
	broadphase_shape.radius = maxf(burst_radius, 0.5)
	broadphase_query = PhysicsShapeQueryParameters3D.new()
	broadphase_query.shape = broadphase_shape
	broadphase_query.collision_mask = collision_mask
	broadphase_query.collide_with_bodies = true
	broadphase_query.collide_with_areas = true


func _refresh_collision_exclusions() -> void:
	collision_exclusions.clear()
	_collect_collision_rids(actor, collision_exclusions)


func _collect_collision_rids(node: Node, destination: Array[RID]) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node is CollisionObject3D:
		var rid: RID = (node as CollisionObject3D).get_rid()
		if rid.is_valid() and not destination.has(rid):
			destination.append(rid)
	for child: Node in node.get_children():
		_collect_collision_rids(child, destination)


func _set_spell_effect_groups(
	spell_effect_active: bool,
	persistent_active: bool
) -> void:
	if spell_effect_active:
		if not is_in_group("spell_effects"):
			add_to_group("spell_effects")
	else:
		if is_in_group("spell_effects"):
			remove_from_group("spell_effects")
	if persistent_active:
		if not is_in_group("persistent_spell_effects"):
			add_to_group("persistent_spell_effects")
	else:
		if is_in_group("persistent_spell_effects"):
			remove_from_group("persistent_spell_effects")


func _finish_bubble(reason: String) -> void:
	var was_active: bool = state != ShieldState.INACTIVE
	state = ShieldState.INACTIVE
	active_remaining = 0.0
	burst_remaining = 0.0
	visual_accumulator = 0.0
	last_end_reason = reason
	_set_spell_effect_groups(false, false)
	if bubble_visual != null:
		bubble_visual.visible = false
		bubble_visual.transparency = 0.0
		bubble_visual.scale = _base_visual_scale()
	set_process(false)
	if was_active:
		bubble_ended.emit(reason)


func get_debug_data() -> Dictionary:
	return {
		"bubble_shield_controller": true,
		"state": ShieldState.keys()[state].to_lower(),
		"active": is_bubble_active(),
		"active_remaining": snappedf(active_remaining, 0.01),
		"burst_remaining": snappedf(burst_remaining, 0.01),
		"activation_count": activation_count,
		"absorb_count": absorb_count,
		"burst_count": burst_count,
		"last_absorbed_source": last_absorbed_source,
		"last_burst_targets": last_burst_target_names.duplicate(),
		"last_end_reason": last_end_reason,
		"processing": is_processing(),
		"spell_effect_group": is_in_group("spell_effects"),
		"persistent_group": is_in_group("persistent_spell_effects"),
	}
