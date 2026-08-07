extends CharacterBody3D
class_name CurlingPuck

signal puck_launched(
	cast_serial: int,
	direction: Vector3,
	curl_sign: float,
	launch_speed: float
)
signal puck_impacted(
	target: Node,
	cast_serial: int,
	impact_speed: float,
	result: Dictionary
)
signal puck_finished(
	cast_serial: int,
	reason: String,
	distance_travelled: float,
	trail_segments: int
)

const IceTrailScript = preload(
	"res://scripts/actions/curling_ice_trail.gd"
)
const IceVisuals = preload(
	"res://scripts/visuals/element_visuals.gd"
)

@export_group("Puck Motion")
@export_range(0.15, 1.2, 0.01) var puck_radius: float = 0.42
@export_range(0.08, 0.6, 0.01) var puck_height: float = 0.18
@export_range(1.0, 30.0, 0.1) var initial_speed: float = 8.8
@export_range(0.0, 8.0, 0.05) var deceleration: float = 0.95
@export_range(0.5, 60.0, 0.5) var curl_degrees_per_second: float = 11.0
@export_range(2.0, 60.0, 0.5) var maximum_distance: float = 22.0
@export_range(0.05, 3.0, 0.05) var stop_speed: float = 0.65
@export_range(0.5, 5.0, 0.1) var spawn_forward_distance: float = 1.45
@export_range(0.0, 0.3, 0.01) var support_clearance: float = 0.035
@export_range(0.0, 0.3, 0.01) var impact_skin: float = 0.04
@export_flags_3d_physics var collision_query_mask: int = 1

@export_group("Trail")
@export_range(0.6, 3.0, 0.05) var trail_width: float = 1.45
@export_range(0.2, 1.5, 0.05) var trail_segment_spacing: float = 0.46
@export_range(8, 128, 1) var trail_maximum_segments: int = 56
@export_range(0.5, 30.0, 0.1) var trail_linger_seconds: float = 9.0

@export_group("Presentation")
@export_range(0.05, 1.0, 0.01) var formation_seconds: float = 0.16
@export_range(0.1, 1.0, 0.01) var formation_start_scale: float = 0.42
@export_range(0.05, 2.0, 0.05) var dissolve_seconds: float = 0.24
@export_range(0.0, 10.0, 0.1) var launch_light_energy: float = 2.5
@export var show_debug_messages: bool = false

var source_actor: Node3D = null
var runtime_payload: DamagePayload = null
var trail: CurlingIceTrail = null
var cast_serial: int = 0
var cast_direction: Vector3 = Vector3.FORWARD
var curl_sign: float = 1.0
var current_speed: float = 0.0
var distance_travelled: float = 0.0
var age_seconds: float = 0.0
var active: bool = false
var dissolving: bool = false
var finish_reason: String = "none"
var dissolve_elapsed: float = 0.0
var collision_exclusions: Array[RID] = []
var impact_count: int = 0
var last_support_kind: String = "none"
var last_support_normal: Vector3 = Vector3.UP
var previous_position: Vector3 = Vector3.ZERO
var visual_initial_scale: Vector3 = Vector3.ONE

@onready var collision_shape: CollisionShape3D = get_node_or_null(
	"CollisionShape3D"
) as CollisionShape3D
@onready var visual_root: Node3D = get_node_or_null("VisualRoot") as Node3D
@onready var launch_light: OmniLight3D = get_node_or_null(
	"LaunchLight"
) as OmniLight3D


func _ready() -> void:
	add_to_group("curling_puck_effects")
	add_to_group("spell_effects")
	add_to_group("spell_projectiles")
	add_to_group("lab_resettable")
	add_to_group("debuggable")
	_sync_collision_shape()
	if visual_root != null:
		visual_initial_scale = visual_root.scale
		visual_root.scale = visual_initial_scale * formation_start_scale
	if launch_light != null:
		launch_light.light_energy = 0.0
	set_physics_process(false)
	set_process(false)


func set_payload(new_payload: Resource) -> void:
	if new_payload is DamagePayload:
		runtime_payload = (
			(new_payload as DamagePayload).duplicate(true) as DamagePayload
		)


func set_source_actor(new_source_actor: Node) -> void:
	if new_source_actor is Node3D:
		source_actor = new_source_actor as Node3D


func belongs_to_source(candidate: Node) -> bool:
	return source_actor != null and source_actor == candidate


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
	curl_sign = _resolve_curl_sign()

	cast_serial = int(source_actor.get_meta("curling_puck_cast_serial", 0)) + 1
	source_actor.set_meta("curling_puck_cast_serial", cast_serial)
	source_actor.set_meta("curling_puck_last_curl_sign", curl_sign)
	name = "CurlingPuck_" + str(cast_serial)
	set_meta("curling_puck_cast_serial", cast_serial)

	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		queue_free()
		return
	trail = IceTrailScript.new() as CurlingIceTrail
	trail.trail_width = trail_width
	trail.segment_spacing = trail_segment_spacing
	trail.maximum_segments = trail_maximum_segments
	trail.linger_seconds = trail_linger_seconds
	scene_root.add_child(trail)
	trail.configure(source_actor, cast_serial, self)

	var desired_spawn: Vector3 = (
		source_actor.global_position
		+ cast_direction * spawn_forward_distance
	)
	var support: Dictionary = trail.resolve_surface_sample(
		desired_spawn,
		self
	)
	if not bool(support.get("found", false)):
		trail.force_dissipate("no_launch_surface")
		trail = null
		queue_free()
		return
	var support_position: Vector3 = support.get(
		"position",
		desired_spawn
	) as Vector3
	last_support_normal = support.get("normal", Vector3.UP) as Vector3
	if last_support_normal.length_squared() <= 0.0001:
		last_support_normal = Vector3.UP
	last_support_normal = last_support_normal.normalized()
	last_support_kind = str(support.get("support_kind", "ground"))
	global_position = (
		support_position
		+ last_support_normal * (puck_height * 0.5 + support_clearance)
	)
	trail.add_sample(global_position, cast_direction)

	collision_exclusions.clear()
	_collect_collision_rids(source_actor, collision_exclusions)
	_collect_collision_rids(self, collision_exclusions)
	if trail.get_static_body() != null:
		_collect_collision_rids(
			trail.get_static_body(),
			collision_exclusions
		)

	current_speed = initial_speed
	distance_travelled = 0.0
	age_seconds = 0.0
	dissolve_elapsed = 0.0
	impact_count = 0
	finish_reason = "active"
	previous_position = global_position
	active = true
	dissolving = false
	collision_layer = 1
	collision_mask = collision_query_mask
	if visual_root != null:
		visual_root.visible = true
		visual_root.scale = visual_initial_scale * formation_start_scale
	if launch_light != null:
		launch_light.light_energy = launch_light_energy
	set_process(false)
	set_physics_process(true)
	puck_launched.emit(cast_serial, cast_direction, curl_sign, initial_speed)

	if show_debug_messages:
		print(
			"CURLING_PUCK serial=",
			cast_serial,
			" curl=",
			curl_sign,
			" speed=",
			current_speed
		)


func _physics_process(delta: float) -> void:
	advance_puck(delta)


func advance_puck(delta: float) -> bool:
	if not active or dissolving:
		return false
	var step: float = maxf(delta, 0.0)
	if step <= 0.0:
		return true
	age_seconds += step
	current_speed = move_toward(
		current_speed,
		0.0,
		maxf(deceleration, 0.0) * step
	)
	if current_speed <= stop_speed:
		finish_puck("settled")
		return false

	var speed_ratio: float = clampf(
		current_speed / maxf(initial_speed, 0.01),
		0.0,
		1.0
	)
	var curl_weight: float = lerpf(1.25, 0.38, speed_ratio)
	cast_direction = cast_direction.rotated(
		Vector3.UP,
		deg_to_rad(curl_degrees_per_second)
		* curl_sign
		* curl_weight
		* step
	).normalized()
	var remaining_distance: float = maxf(
		maximum_distance - distance_travelled,
		0.0
	)
	if remaining_distance <= 0.001:
		finish_puck("maximum_distance")
		return false
	var step_distance: float = minf(current_speed * step, remaining_distance)
	var desired_position: Vector3 = (
		global_position + cast_direction * step_distance
	)
	var support: Dictionary = trail.resolve_surface_sample(
		desired_position,
		self
	)
	if not bool(support.get("found", false)):
		finish_puck("lost_surface")
		return false
	var support_position: Vector3 = support.get(
		"position",
		desired_position
	) as Vector3
	last_support_normal = support.get("normal", Vector3.UP) as Vector3
	if last_support_normal.length_squared() <= 0.0001:
		last_support_normal = Vector3.UP
	last_support_normal = last_support_normal.normalized()
	last_support_kind = str(support.get("support_kind", "ground"))
	var target_position: Vector3 = (
		support_position
		+ last_support_normal * (puck_height * 0.5 + support_clearance)
	)

	var hit: Dictionary = _trace_puck(
		global_position,
		target_position,
		last_support_normal
	)
	if not hit.is_empty():
		var hit_position: Vector3 = hit.get(
			"position",
			target_position
		) as Vector3
		var safe_position: Vector3 = (
			hit_position
			- cast_direction * (puck_radius + impact_skin)
		)
		safe_position.y = target_position.y
		trail.add_path_between(
			global_position,
			safe_position,
			cast_direction
		)
		distance_travelled += global_position.distance_to(safe_position)
		global_position = safe_position
		var target_value: Variant = hit.get("target")
		if target_value is Node:
			_apply_puck_impact(target_value as Node)
			finish_puck("target_impact")
		else:
			finish_puck("solid_contact")
		return false

	trail.add_path_between(
		global_position,
		target_position,
		cast_direction
	)
	previous_position = global_position
	global_position = target_position
	distance_travelled += previous_position.distance_to(global_position)
	_update_visual_motion(step)
	if distance_travelled >= maximum_distance - 0.001:
		finish_puck("maximum_distance")
		return false
	return true


func finish_puck(reason: String = "finished") -> void:
	if not active or dissolving:
		return
	active = false
	dissolving = true
	finish_reason = reason
	current_speed = 0.0
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	if trail != null and is_instance_valid(trail):
		trail.finish_drawing(reason)
	var trail_segment_count: int = (
		trail.get_segment_positions().size()
		if trail != null and is_instance_valid(trail)
		else 0
	)
	puck_finished.emit(
		cast_serial,
		reason,
		distance_travelled,
		trail_segment_count
	)
	dissolve_elapsed = 0.0
	set_process(true)


func force_dissipate(reason: String = "forced_cleanup") -> void:
	if trail != null and is_instance_valid(trail):
		trail.force_dissipate(reason)
	trail = null
	active = false
	dissolving = false
	set_physics_process(false)
	set_process(false)
	queue_free()


func reset_target() -> void:
	force_dissipate("trial_reset")


func _process(delta: float) -> void:
	if not dissolving:
		return
	var safe_duration: float = maxf(dissolve_seconds, 0.01)
	dissolve_elapsed = minf(
		dissolve_elapsed + maxf(delta, 0.0),
		safe_duration
	)
	var ratio: float = clampf(
		dissolve_elapsed / safe_duration,
		0.0,
		1.0
	)
	if visual_root != null:
		visual_root.scale = visual_initial_scale * lerpf(1.0, 0.08, ratio)
	if launch_light != null:
		launch_light.light_energy = lerpf(
			launch_light_energy * 0.35,
			0.0,
			ratio
		)
	if ratio >= 1.0:
		queue_free()


func _trace_puck(
	start_position: Vector3,
	end_position: Vector3,
	support_normal: Vector3
) -> Dictionary:
	var world: World3D = get_world_3d()
	if world == null:
		return {}
	var right: Vector3 = support_normal.cross(cast_direction)
	if right.length_squared() <= 0.0001:
		right = Vector3.RIGHT
	right = right.normalized()
	var offsets: Array[Vector3] = [
		Vector3.ZERO,
		right * puck_radius * 0.72,
		-right * puck_radius * 0.72,
		support_normal * puck_height * 0.26,
		-support_normal * puck_height * 0.18,
	]
	var nearest: Dictionary = {}
	var nearest_distance: float = INF
	for offset: Vector3 in offsets:
		var hit: Dictionary = _trace_single_ray(
			start_position + offset,
			end_position + offset,
			support_normal
		)
		if hit.is_empty():
			continue
		var hit_position: Vector3 = hit.get(
			"position",
			end_position
		) as Vector3
		var distance: float = start_position.distance_to(hit_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = hit
	return nearest


func _trace_single_ray(
	start_position: Vector3,
	end_position: Vector3,
	support_normal: Vector3
) -> Dictionary:
	var world: World3D = get_world_3d()
	if world == null:
		return {}
	var query_start: Vector3 = start_position
	var exclusions: Array[RID] = collision_exclusions.duplicate()
	for _attempt: int in range(10):
		if query_start.distance_squared_to(end_position) <= 0.00001:
			return {}
		var query := PhysicsRayQueryParameters3D.create(
			query_start,
			end_position,
			collision_query_mask
		)
		query.collide_with_bodies = true
		query.collide_with_areas = true
		query.exclude = exclusions
		var hit: Dictionary = world.direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return {}
		var collider_value: Variant = hit.get("collider")
		var hit_position: Vector3 = hit.get(
			"position",
			end_position
		) as Vector3
		var hit_normal: Vector3 = hit.get(
			"normal",
			Vector3.ZERO
		) as Vector3
		if not collider_value is Node:
			return {
				"position": hit_position,
				"normal": hit_normal,
				"target": null,
			}
		var collider: Node = collider_value as Node
		var target: Node = _resolve_effect_target(collider)
		if target != null:
			return {
				"position": hit_position,
				"normal": hit_normal,
				"target": target,
			}
		if (
			hit_normal.length_squared() > 0.0001
			and hit_normal.normalized().dot(support_normal) > 0.58
			and collider is CollisionObject3D
		):
			var support_rid: RID = (collider as CollisionObject3D).get_rid()
			if support_rid.is_valid() and not exclusions.has(support_rid):
				exclusions.append(support_rid)
			query_start = hit_position + cast_direction * 0.025
			continue
		if collider is Area3D:
			var area_rid: RID = (collider as Area3D).get_rid()
			if area_rid.is_valid() and not exclusions.has(area_rid):
				exclusions.append(area_rid)
			query_start = hit_position + cast_direction * 0.025
			continue
		return {
			"position": hit_position,
			"normal": hit_normal,
			"target": null,
		}
	return {}


func _apply_puck_impact(target: Node) -> Dictionary:
	if target == null or not is_instance_valid(target):
		return {}
	var payload: DamagePayload = _get_payload().duplicate(true) as DamagePayload
	payload.source_name = "Curling Puck"
	payload.hit_type = "curling_puck"
	payload.knockback_direction = cast_direction
	var result: Dictionary = _deliver_payload(target, payload)
	if target is RigidBody3D:
		var rigid_body := target as RigidBody3D
		rigid_body.apply_central_impulse(
			cast_direction * maxf(payload.knockback_strength, 1.2)
			+ Vector3.UP * payload.knockback_up_strength
		)
		rigid_body.sleeping = false
	impact_count += 1
	target.set_meta("curling_puck_last_cast_serial", cast_serial)
	target.set_meta("curling_puck_last_impact_speed", current_speed)
	target.set_meta("curling_puck_last_curl_sign", curl_sign)
	IceVisuals.spawn_impact(
		get_tree(),
		_get_target_position(target),
		"ice",
		0.62
	)
	puck_impacted.emit(target, cast_serial, current_speed, result)
	return result


func _resolve_effect_target(start_node: Node) -> Node:
	var current: Node = start_node
	while current != null:
		if source_actor != null and (
			current == source_actor
			or source_actor.is_ancestor_of(current)
		):
			return null
		if current == trail or (
			trail != null and trail.is_ancestor_of(current)
		):
			return null
		if current is RigidBody3D or current is CharacterBody3D:
			return current
		if (
			current.get_node_or_null("PayloadReceiver") != null
			or current.get_node_or_null("HitReceiver") != null
			or current.has_method("receive_damage_payload")
			or current.has_method("receive_magic_hit")
		):
			return current
		if current is StaticBody3D or current is AnimatableBody3D:
			return null
		if current == get_tree().current_scene:
			break
		current = current.get_parent()
	return null


func _deliver_payload(target: Node, payload: DamagePayload) -> Dictionary:
	var payload_receiver: Node = target.get_node_or_null("PayloadReceiver")
	if payload_receiver != null and payload_receiver.has_method("receive_payload"):
		var received: Variant = payload_receiver.call("receive_payload", payload)
		return (
			(received as Dictionary).duplicate(true)
			if received is Dictionary
			else {}
		)
	if target.has_method("receive_damage_payload"):
		var direct: Variant = target.call("receive_damage_payload", payload)
		return (
			(direct as Dictionary).duplicate(true)
			if direct is Dictionary
			else {}
		)
	var hit_receiver: Node = target.get_node_or_null("HitReceiver")
	if hit_receiver != null and hit_receiver.has_method("receive_payload"):
		var hit_result: Variant = hit_receiver.call("receive_payload", payload)
		return (
			(hit_result as Dictionary).duplicate(true)
			if hit_result is Dictionary
			else {}
		)
	if target.has_method("receive_magic_hit"):
		target.call("receive_magic_hit", payload.amount)
	return {}


func _get_payload() -> DamagePayload:
	if runtime_payload != null:
		return runtime_payload
	var fallback := DamagePayload.new()
	fallback.amount = 1
	fallback.stance_damage = 2
	fallback.element = "ice"
	fallback.source_name = "Curling Puck"
	fallback.hit_type = "curling_puck"
	fallback.status_effect = "chill"
	fallback.status_duration = 2.4
	fallback.status_strength = 1.0
	fallback.knockback_strength = 1.2
	fallback.knockback_up_strength = 0.05
	fallback.tags = [
		"ice",
		"puck",
		"curling",
		"projectile",
		"terrain",
		"slippery",
		"freeze_water",
		"momentum_setup",
	]
	return fallback


func _resolve_curl_sign() -> float:
	var left_strength: float = Input.get_action_strength("move_left")
	var right_strength: float = Input.get_action_strength("move_right")
	if left_strength > right_strength + 0.12:
		return -1.0
	if right_strength > left_strength + 0.12:
		return 1.0
	return 1.0


func _update_visual_motion(delta: float) -> void:
	if visual_root != null:
		var formation_ratio: float = clampf(
			age_seconds / maxf(formation_seconds, 0.01),
			0.0,
			1.0
		)
		visual_root.scale = visual_initial_scale * lerpf(
			formation_start_scale,
			1.0,
			formation_ratio
		)
		visual_root.rotate_y(
			curl_sign * current_speed * delta * 1.65
		)
	if launch_light != null:
		var light_ratio: float = clampf(
			age_seconds / maxf(formation_seconds, 0.01),
			0.0,
			1.0
		)
		launch_light.light_energy = lerpf(
			launch_light_energy,
			0.0,
			light_ratio
		)


func _sync_collision_shape() -> void:
	if collision_shape == null:
		return
	if collision_shape.shape is CylinderShape3D:
		var cylinder := collision_shape.shape as CylinderShape3D
		cylinder.radius = puck_radius
		cylinder.height = puck_height


func _collect_collision_rids(
	node: Node,
	target: Array[RID]
) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node is CollisionObject3D:
		var rid: RID = (node as CollisionObject3D).get_rid()
		if rid.is_valid() and not target.has(rid):
			target.append(rid)
	for child: Node in node.get_children():
		_collect_collision_rids(child, target)


func _get_target_position(target: Node) -> Vector3:
	if target is Node3D:
		return (target as Node3D).global_position
	var parent: Node = target.get_parent()
	return (
		(parent as Node3D).global_position
		if parent is Node3D
		else global_position
	)


func get_trail() -> CurlingIceTrail:
	return trail


func get_debug_data() -> Dictionary:
	return {
		"curling_puck": true,
		"active": active,
		"dissolving": dissolving,
		"finish_reason": finish_reason,
		"cast_serial": cast_serial,
		"curl_sign": curl_sign,
		"direction": cast_direction,
		"speed": snappedf(current_speed, 0.01),
		"distance_travelled": snappedf(distance_travelled, 0.01),
		"maximum_distance": maximum_distance,
		"age_seconds": snappedf(age_seconds, 0.01),
		"impact_count": impact_count,
		"support_kind": last_support_kind,
		"support_normal": last_support_normal,
		"trail": (
			trail.get_debug_data()
			if trail != null and is_instance_valid(trail)
			else {}
		),
		"persistent": is_in_group("persistent_spell_effects"),
	}
