extends Node3D
class_name MetalNeedleFan

signal volley_started(cast_serial: int, needle_count: int, fan_angle_degrees: float)
signal needle_launched(needle_index: int, direction: Vector3)
signal needle_struck(needle_index: int, target: Node, result: Dictionary)
signal volley_finished(cast_serial: int, total_hits: int, unique_targets: int)

@export_group("Fan Volley")
@export_range(3, 21, 2) var needle_count: int = 9
@export_range(5.0, 100.0, 1.0) var fan_angle_degrees: float = 54.0
@export_range(0.0, 18.0, 0.5) var vertical_stagger_degrees: float = 4.0
@export_range(0.0, 0.08, 0.002) var launch_interval_seconds: float = 0.018
@export_range(2.0, 80.0, 0.5) var needle_speed: float = 36.0
@export_range(2.0, 40.0, 0.5) var maximum_range: float = 17.0
@export_range(0.0, 2.0, 0.05) var launch_forward_offset: float = 0.62
@export_range(-1.0, 3.0, 0.05) var launch_height: float = 0.92
@export_range(1, 12, 1) var maximum_hits_per_target: int = 3
@export_flags_3d_physics var collision_mask: int = 1

@export_group("Presentation")
@export_range(0.02, 0.4, 0.01) var needle_thickness: float = 0.075
@export_range(0.2, 2.0, 0.05) var needle_length: float = 0.92
@export_range(0.0, 0.5, 0.01) var impact_skin: float = 0.035
@export_range(0.0, 8.0, 0.1) var launch_light_energy: float = 2.4
@export_range(0.02, 0.5, 0.01) var launch_light_seconds: float = 0.13
@export var show_debug_messages: bool = false

var source_actor: Node3D
var runtime_payload: DamagePayload
var ability_caster: Node
var cast_origin: Vector3 = Vector3.ZERO
var cast_direction: Vector3 = Vector3.FORWARD
var cast_up: Vector3 = Vector3.UP
var cast_serial: int = 0
var elapsed: float = 0.0
var active: bool = false
var total_hits: int = 0
var launched_count: int = 0
var finished_count: int = 0
var target_hit_counts: Dictionary = {}
var hit_target_names: Array[String] = []
var collision_exclusions: Array[RID] = []

var needle_directions: Array[Vector3] = []
var needle_positions: Array[Vector3] = []
var needle_distances: Array[float] = []
var needle_launch_times: Array[float] = []
var needle_launched_flags: Array[bool] = []
var needle_finished_flags: Array[bool] = []

var needle_visual: MultiMeshInstance3D
var needle_multimesh: MultiMesh
var needle_mesh: BoxMesh
var needle_material: StandardMaterial3D
var launch_light: OmniLight3D


func _ready() -> void:
	add_to_group("metal_needle_fan_effects")
	add_to_group("spell_effects")
	add_to_group("lab_resettable")
	add_to_group("debuggable")
	global_transform = Transform3D.IDENTITY
	_build_visuals()
	set_physics_process(false)


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

	ability_caster = source_actor.get_node_or_null("AbilityCaster")
	cast_direction = requested_direction
	if cast_direction.length_squared() <= 0.0001:
		cast_direction = -source_actor.global_transform.basis.z
	if cast_direction.length_squared() <= 0.0001:
		cast_direction = Vector3.FORWARD
	cast_direction = cast_direction.normalized()
	cast_up = _resolve_fan_up(cast_direction)
	cast_origin = _get_cast_origin() + cast_direction * launch_forward_offset

	cast_serial = int(source_actor.get_meta("metal_needle_fan_serial", 0)) + 1
	source_actor.set_meta("metal_needle_fan_serial", cast_serial)
	source_actor.set_meta("metal_needle_fan_last_direction", cast_direction)

	collision_exclusions.clear()
	_collect_collision_rids(source_actor, collision_exclusions)
	_build_needle_states()
	elapsed = 0.0
	total_hits = 0
	launched_count = 0
	finished_count = 0
	target_hit_counts.clear()
	hit_target_names.clear()
	active = true
	if needle_visual != null:
		needle_visual.visible = true
	if launch_light != null:
		launch_light.global_position = cast_origin
		launch_light.light_energy = launch_light_energy
	set_physics_process(true)
	volley_started.emit(cast_serial, needle_count, fan_angle_degrees)

	if show_debug_messages:
		print(
			"METAL_NEEDLE_FAN serial=",
			cast_serial,
			" needles=",
			needle_count,
			" fan=",
			fan_angle_degrees
		)


func _physics_process(delta: float) -> void:
	advance_volley(delta)


func advance_volley(delta: float) -> bool:
	if not active:
		return false
	var step: float = maxf(delta, 0.0)
	if step <= 0.0:
		return true
	elapsed += step

	if launch_light != null:
		var light_ratio: float = clampf(
			elapsed / maxf(launch_light_seconds, 0.01),
			0.0,
			1.0
		)
		launch_light.light_energy = lerpf(launch_light_energy, 0.0, light_ratio)

	for needle_index: int in range(needle_count):
		if needle_finished_flags[needle_index]:
			continue
		if not needle_launched_flags[needle_index]:
			if elapsed < needle_launch_times[needle_index]:
				_hide_needle_instance(needle_index)
				continue
			_launch_needle(needle_index)
		if needle_finished_flags[needle_index]:
			continue
		_advance_needle(needle_index, step)

	_update_all_visual_transforms()
	if finished_count >= needle_count:
		finish_volley()
		return false
	return true


func finish_volley() -> void:
	if not active:
		return
	active = false
	set_physics_process(false)
	if needle_visual != null:
		needle_visual.visible = false
	if launch_light != null:
		launch_light.light_energy = 0.0
	volley_finished.emit(cast_serial, total_hits, target_hit_counts.size())
	queue_free()


func reset_target() -> void:
	finish_volley()


func _build_needle_states() -> void:
	needle_count = maxi(needle_count, 3)
	if needle_count % 2 == 0:
		needle_count += 1
	needle_directions.clear()
	needle_positions.clear()
	needle_distances.clear()
	needle_launch_times.clear()
	needle_launched_flags.clear()
	needle_finished_flags.clear()

	var half_angle: float = deg_to_rad(fan_angle_degrees * 0.5)
	var fan_right: Vector3 = cast_up.cross(cast_direction)
	if fan_right.length_squared() <= 0.0001:
		fan_right = Vector3.RIGHT
	fan_right = fan_right.normalized()
	for needle_index: int in range(needle_count):
		var ratio: float = (
			0.5
			if needle_count <= 1
			else float(needle_index) / float(needle_count - 1)
		)
		var fan_angle: float = lerpf(-half_angle, half_angle, ratio)
		var direction: Vector3 = cast_direction.rotated(cast_up, fan_angle)
		var stagger_index: int = (needle_index % 3) - 1
		var vertical_angle: float = deg_to_rad(
			float(stagger_index) * vertical_stagger_degrees
		)
		direction = direction.rotated(fan_right, vertical_angle).normalized()
		needle_directions.append(direction)
		needle_positions.append(cast_origin)
		needle_distances.append(0.0)
		needle_launch_times.append(float(needle_index) * launch_interval_seconds)
		needle_launched_flags.append(false)
		needle_finished_flags.append(false)

	if needle_multimesh != null:
		needle_multimesh.instance_count = needle_count
		for needle_index: int in range(needle_count):
			_hide_needle_instance(needle_index)


func _launch_needle(needle_index: int) -> void:
	needle_launched_flags[needle_index] = true
	launched_count += 1
	needle_positions[needle_index] = _get_cast_origin() + (
		needle_directions[needle_index] * launch_forward_offset
	)
	needle_launched.emit(needle_index, needle_directions[needle_index])


func _advance_needle(needle_index: int, delta: float) -> void:
	var start_position: Vector3 = needle_positions[needle_index]
	var direction: Vector3 = needle_directions[needle_index]
	var remaining_range: float = maxf(
		maximum_range - needle_distances[needle_index],
		0.0
	)
	if remaining_range <= 0.001:
		_finish_needle(needle_index)
		return
	var step_distance: float = minf(needle_speed * delta, remaining_range)
	var end_position: Vector3 = start_position + direction * step_distance
	var hit: Dictionary = _trace_needle(start_position, end_position, direction)
	if not hit.is_empty():
		var hit_position: Vector3 = hit.get("position", end_position) as Vector3
		needle_positions[needle_index] = hit_position - direction * impact_skin
		needle_distances[needle_index] += start_position.distance_to(
			needle_positions[needle_index]
		)
		var target_value: Variant = hit.get("target")
		if target_value is Node:
			_apply_needle_to_target(
				needle_index,
				target_value as Node,
				direction
			)
		_finish_needle(needle_index)
		return
	needle_positions[needle_index] = end_position
	needle_distances[needle_index] += step_distance
	if needle_distances[needle_index] >= maximum_range - 0.001:
		_finish_needle(needle_index)


func _trace_needle(
	start_position: Vector3,
	end_position: Vector3,
	direction: Vector3
) -> Dictionary:
	var world: World3D = get_world_3d()
	if world == null:
		return {}
	var query_start: Vector3 = start_position
	var local_exclusions: Array[RID] = collision_exclusions.duplicate()
	for _attempt: int in range(12):
		if query_start.distance_squared_to(end_position) <= 0.00001:
			return {}
		var query := PhysicsRayQueryParameters3D.create(
			query_start,
			end_position,
			collision_mask
		)
		query.collide_with_bodies = true
		query.collide_with_areas = true
		query.exclude = local_exclusions
		var hit: Dictionary = world.direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return {}
		var collider_value: Variant = hit.get("collider")
		var hit_position: Vector3 = hit.get("position", end_position) as Vector3
		if not collider_value is Node:
			return {"position": hit_position, "target": null}
		var collider: Node = collider_value as Node
		var target: Node = _resolve_effect_target(collider)
		if target != null:
			return {"position": hit_position, "target": target}
		if collider is Area3D:
			var rid: RID = (collider as Area3D).get_rid()
			if rid.is_valid() and not local_exclusions.has(rid):
				local_exclusions.append(rid)
			query_start = hit_position + direction * 0.025
			continue
		return {"position": hit_position, "target": null}
	return {}


func _apply_needle_to_target(
	needle_index: int,
	target: Node,
	direction: Vector3
) -> Dictionary:
	if target == null or not is_instance_valid(target):
		return {}
	var target_id: int = target.get_instance_id()
	var previous_hits: int = int(target_hit_counts.get(target_id, 0))
	if previous_hits >= maximum_hits_per_target:
		return {}

	var payload: DamagePayload = _get_payload().duplicate(true) as DamagePayload
	payload.source_name = "Metal Needle Fan"
	payload.hit_type = "projectile"
	payload.knockback_direction = direction
	if not payload.tags.has("fan"):
		payload.tags.append("fan")
	if not payload.tags.has("volley"):
		payload.tags.append("volley")

	var result: Dictionary = _deliver_payload(target, payload)
	var updated_hits: int = previous_hits + 1
	target_hit_counts[target_id] = updated_hits
	total_hits += 1
	if not hit_target_names.has(str(target.name)):
		hit_target_names.append(str(target.name))

	var previous_serial: int = int(
		target.get_meta("metal_needle_fan_last_serial", 0)
	)
	var serial_hits: int = int(
		target.get_meta("metal_needle_fan_hits_from_serial", 0)
	)
	if previous_serial != cast_serial:
		serial_hits = 0
	target.set_meta("metal_needle_fan_last_serial", cast_serial)
	target.set_meta("metal_needle_fan_hits_from_serial", serial_hits + 1)
	target.set_meta("metal_needle_fan_last_needle_index", needle_index)
	needle_struck.emit(needle_index, target, result)
	return result


func _deliver_payload(target: Node, payload: DamagePayload) -> Dictionary:
	var payload_receiver: Node = _get_component(target, "PayloadReceiver")
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
	var hit_receiver: Node = _get_component(target, "HitReceiver")
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


func _resolve_effect_target(start_node: Node) -> Node:
	var current: Node = start_node
	while current != null:
		if source_actor != null and (
			current == source_actor or source_actor.is_ancestor_of(current)
		):
			return null
		if (
			_get_component(current, "PayloadReceiver") != null
			or _get_component(current, "HitReceiver") != null
			or current.has_method("receive_damage_payload")
			or current.has_method("receive_magic_hit")
		):
			return current
		if current == get_tree().current_scene:
			break
		current = current.get_parent()
	return null


func _get_component(target: Node, component_name: String) -> Node:
	if target == null:
		return null
	var direct: Node = target.get_node_or_null(component_name)
	if direct != null:
		return direct
	for child: Node in target.get_children():
		if str(child.name) == component_name:
			return child
	return null


func _get_payload() -> DamagePayload:
	if runtime_payload != null:
		return runtime_payload
	var fallback := DamagePayload.new()
	fallback.amount = 1
	fallback.stance_damage = 1
	fallback.element = "metal"
	fallback.source_name = "Metal Needle Fan"
	fallback.hit_type = "projectile"
	fallback.knockback_strength = 0.25
	fallback.tags = [
		"metal",
		"pierce",
		"sharp",
		"magic",
		"projectile",
		"fan",
		"volley",
	]
	return fallback


func _get_cast_origin() -> Vector3:
	if ability_caster != null and ability_caster.has_method(
		"get_player_cast_origin"
	):
		var origin_value: Variant = ability_caster.call(
			"get_player_cast_origin",
			source_actor
		)
		if origin_value is Vector3:
			return origin_value as Vector3
	return source_actor.global_position + Vector3.UP * launch_height


func _resolve_fan_up(direction: Vector3) -> Vector3:
	var camera: Camera3D = get_viewport().get_camera_3d()
	var up: Vector3 = (
		camera.global_transform.basis.y if camera != null else Vector3.UP
	)
	up = up - direction * up.dot(direction)
	if up.length_squared() <= 0.0001:
		up = Vector3.UP - direction * Vector3.UP.dot(direction)
	if up.length_squared() <= 0.0001:
		up = Vector3.RIGHT
	return up.normalized()


func _build_visuals() -> void:
	needle_mesh = BoxMesh.new()
	needle_mesh.size = Vector3(
		maxf(needle_thickness, 0.01),
		maxf(needle_thickness, 0.01),
		maxf(needle_length, 0.05)
	)
	needle_material = StandardMaterial3D.new()
	needle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	needle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	needle_material.vertex_color_use_as_albedo = true
	needle_material.albedo_color = Color(1.0, 0.78, 0.12, 1.0)
	needle_material.emission_enabled = true
	needle_material.emission = Color(1.0, 0.62, 0.04, 1.0)
	needle_material.emission_energy_multiplier = 2.4

	needle_multimesh = MultiMesh.new()
	needle_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	needle_multimesh.use_colors = true
	needle_multimesh.mesh = needle_mesh
	needle_multimesh.instance_count = maxi(needle_count, 3)
	needle_visual = MultiMeshInstance3D.new()
	needle_visual.name = "MetalNeedleFanMultiMesh"
	needle_visual.multimesh = needle_multimesh
	needle_visual.material_override = needle_material
	needle_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	needle_visual.visible = false
	add_child(needle_visual)

	launch_light = OmniLight3D.new()
	launch_light.name = "MetalNeedleLaunchLight"
	launch_light.light_color = Color(1.0, 0.66, 0.08, 1.0)
	launch_light.light_energy = 0.0
	launch_light.omni_range = 4.5
	launch_light.shadow_enabled = false
	add_child(launch_light)


func _update_all_visual_transforms() -> void:
	if needle_multimesh == null:
		return
	for needle_index: int in range(needle_count):
		if (
			not needle_launched_flags[needle_index]
			or needle_finished_flags[needle_index]
		):
			_hide_needle_instance(needle_index)
			continue
		var direction: Vector3 = needle_directions[needle_index]
		var basis: Basis = _basis_for_direction(direction)
		needle_multimesh.set_instance_transform(
			needle_index,
			Transform3D(basis, needle_positions[needle_index])
		)
		var center_ratio: float = (
			1.0 - absf(
				(float(needle_index) / float(maxi(needle_count - 1, 1)))
				* 2.0 - 1.0
			)
		)
		needle_multimesh.set_instance_color(
			needle_index,
			Color(1.0, 0.62 + center_ratio * 0.22, 0.08, 1.0)
		)


func _hide_needle_instance(needle_index: int) -> void:
	if needle_multimesh == null or needle_index >= needle_multimesh.instance_count:
		return
	needle_multimesh.set_instance_transform(
		needle_index,
		Transform3D(
			Basis.IDENTITY.scaled(Vector3.ONE * 0.0001),
			Vector3.ZERO
		)
	)


func _basis_for_direction(direction_value: Vector3) -> Basis:
	var forward: Vector3 = direction_value
	if forward.length_squared() <= 0.0001:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var reference_up: Vector3 = (
		Vector3.UP
		if absf(forward.dot(Vector3.UP)) < 0.96
		else Vector3.RIGHT
	)
	var right: Vector3 = reference_up.cross(forward).normalized()
	var up: Vector3 = forward.cross(right).normalized()
	return Basis(right, up, forward).orthonormalized()


func _finish_needle(needle_index: int) -> void:
	if needle_finished_flags[needle_index]:
		return
	needle_finished_flags[needle_index] = true
	finished_count += 1
	_hide_needle_instance(needle_index)


func _collect_collision_rids(node: Node, target: Array[RID]) -> void:
	if node is CollisionObject3D:
		var rid: RID = (node as CollisionObject3D).get_rid()
		if rid.is_valid() and not target.has(rid):
			target.append(rid)
	for child: Node in node.get_children():
		_collect_collision_rids(child, target)


func get_debug_data() -> Dictionary:
	return {
		"metal_needle_fan": true,
		"active": active,
		"cast_serial": cast_serial,
		"needle_count": needle_count,
		"launched": launched_count,
		"finished": finished_count,
		"fan_angle_degrees": fan_angle_degrees,
		"launch_interval": launch_interval_seconds,
		"speed": needle_speed,
		"maximum_range": maximum_range,
		"total_hits": total_hits,
		"unique_targets": target_hit_counts.size(),
		"hit_targets": hit_target_names.duplicate(),
		"maximum_hits_per_target": maximum_hits_per_target,
		"multimeshes": 1,
		"needle_instances": (
			needle_multimesh.instance_count if needle_multimesh != null else 0
		),
		"per_needle_nodes": 0,
		"persistent": is_in_group("persistent_spell_effects"),
	}
