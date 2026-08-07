extends Node3D
class_name LightningSparkBurst

signal spark_fired(hit_count: int)
signal target_struck(target: Node, distance: float, angle_degrees: float)
signal spark_finished(hit_count: int)

const ControllerHapticPatternScript = preload(
	"res://scripts/input/controller_haptic_pattern.gd"
)

const LIGHTNING_SPARK_HAPTIC_PATTERN: Array = [
	{"weak": 0.12, "strong": 0.78, "duration": 0.035},
	{"weak": 0.0, "strong": 0.0, "duration": 0.016},
	{"weak": 0.56, "strong": 0.2, "duration": 0.06},
	{"weak": 0.0, "strong": 0.0, "duration": 0.012},
	{"weak": 0.24, "strong": 0.44, "duration": 0.04},
]

@export_group("Cone")
@export_range(1.0, 10.0, 0.1) var maximum_range: float = 4.8
@export_range(5.0, 80.0, 1.0) var half_angle_degrees: float = 38.0
@export_range(0.5, 4.0, 0.05) var vertical_tolerance: float = 2.25
@export_range(1, 64, 1) var maximum_targets: int = 24
@export var origin_height: float = 0.88
@export_flags_3d_physics var collision_mask: int = 1

@export_group("Presentation")
@export_range(0.05, 0.5, 0.01) var visual_lifetime: float = 0.18
@export_range(3, 12, 1) var primary_branch_count: int = 7
@export_range(2, 8, 1) var minimum_segments_per_branch: int = 4
@export_range(3, 10, 1) var maximum_segments_per_branch: int = 6
@export_range(0.01, 0.12, 0.005) var segment_thickness: float = 0.038
@export_range(0.0, 1.0, 0.05) var side_branch_chance: float = 0.38
@export_range(8, 96, 1) var maximum_visual_segments: int = 56
@export_range(0.0, 1.5, 0.05) var haptic_strength_scale: float = 1.0
@export var show_debug_messages: bool = false

var source_actor: Node3D
var runtime_payload: DamagePayload
var cast_origin: Vector3 = Vector3.ZERO
var cast_direction: Vector3 = Vector3.FORWARD
var collision_exclusions: Array[RID] = []
var active: bool = false
var age: float = 0.0
var last_hit_count: int = 0
var last_hit_names: Array[String] = []
var last_visual_segment_count: int = 0
var last_query_result_count: int = 0
var last_haptic_started: bool = false
var last_visual_range: float = 0.0

var spark_segments: MultiMeshInstance3D
var spark_light: OmniLight3D
var segment_mesh: BoxMesh
var spark_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("spell_effects")
	add_to_group("lightning_spark_effects")
	add_to_group("debuggable")
	_build_visuals()
	set_process(false)


func _process(delta: float) -> void:
	if not active:
		return
	age += maxf(delta, 0.0)
	var ratio: float = clampf(
		age / maxf(visual_lifetime, 0.01),
		0.0,
		1.0
	)
	if spark_segments != null:
		spark_segments.transparency = ratio
		spark_segments.scale = Vector3.ONE * lerpf(1.0, 1.045, ratio)
	if spark_light != null:
		spark_light.light_energy = lerpf(3.6, 0.0, ratio)
	if ratio >= 1.0:
		finish_spark()


func set_payload(new_payload: Resource) -> void:
	if new_payload is DamagePayload:
		runtime_payload = (
			(new_payload as DamagePayload).duplicate(true) as DamagePayload
		)


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

	cast_origin = source_actor.global_position + Vector3.UP * origin_height
	global_transform = Transform3D(_get_cast_basis(), cast_origin)
	collision_exclusions.clear()
	_collect_collision_rids(source_actor, collision_exclusions)

	last_hit_names.clear()
	last_hit_count = 0
	last_query_result_count = 0
	last_visual_range = _resolve_centerline_visual_range()

	var hits: Array[Dictionary] = _collect_cone_targets()
	for hit: Dictionary in hits:
		var target_value: Variant = hit.get("target")
		if not target_value is Node:
			continue
		var target: Node = target_value as Node
		_apply_spark_payload(target)
		last_hit_count += 1
		last_hit_names.append(str(target.name))
		target_struck.emit(
			target,
			float(hit.get("distance", 0.0)),
			float(hit.get("angle_degrees", 0.0))
		)

	_build_procedural_spark_pattern(last_visual_range)
	last_haptic_started = _play_haptic_pattern(last_hit_count)
	age = 0.0
	active = true
	if spark_segments != null:
		spark_segments.visible = true
		spark_segments.transparency = 0.0
	if spark_light != null:
		spark_light.light_energy = 3.6
	set_process(true)
	spark_fired.emit(last_hit_count)

	if show_debug_messages:
		print(
			"LIGHTNING_SPARK cone hit ",
			last_hit_count,
			" targets: ",
			last_hit_names
		)


func finish_spark() -> void:
	if not active:
		return
	active = false
	set_process(false)
	if spark_segments != null:
		spark_segments.visible = false
	if spark_light != null:
		spark_light.light_energy = 0.0
	spark_finished.emit(last_hit_count)
	queue_free()


func _build_visuals() -> void:
	segment_mesh = BoxMesh.new()
	segment_mesh.size = Vector3.ONE

	spark_material = StandardMaterial3D.new()
	spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spark_material.vertex_color_use_as_albedo = true
	spark_material.albedo_color = Color(0.72, 0.86, 1.0, 1.0)
	spark_material.emission_enabled = true
	spark_material.emission = Color(0.16, 0.42, 1.0, 1.0)
	spark_material.emission_energy_multiplier = 3.2

	spark_segments = MultiMeshInstance3D.new()
	spark_segments.name = "ProceduralSparkSegments"
	spark_segments.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spark_segments.material_override = spark_material
	spark_segments.visible = false
	add_child(spark_segments)

	spark_light = OmniLight3D.new()
	spark_light.name = "SparkFlashLight"
	spark_light.position = Vector3(0.0, 0.0, -1.7)
	spark_light.light_color = Color(0.28, 0.5, 1.0, 1.0)
	spark_light.light_energy = 0.0
	spark_light.omni_range = 6.0
	spark_light.shadow_enabled = false
	add_child(spark_light)


func _collect_cone_targets() -> Array[Dictionary]:
	var hits: Array[Dictionary] = []
	var world: World3D = get_world_3d()
	if world == null:
		return hits

	var shape := SphereShape3D.new()
	shape.radius = maximum_range
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, cast_origin)
	query.collision_mask = collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = collision_exclusions

	var results: Array[Dictionary] = world.direct_space_state.intersect_shape(
		query,
		64
	)
	last_query_result_count = results.size()
	var seen_targets: Dictionary = {}
	var minimum_dot: float = cos(deg_to_rad(half_angle_degrees))

	for result: Dictionary in results:
		var collider_value: Variant = result.get("collider")
		if not collider_value is Node:
			continue
		var target: Node = _resolve_effect_target(collider_value as Node)
		if target == null:
			continue
		var target_id: int = target.get_instance_id()
		if seen_targets.has(target_id):
			continue

		var target_center: Vector3 = _get_target_center(target)
		var offset: Vector3 = target_center - cast_origin
		if absf(offset.y) > vertical_tolerance:
			continue
		var horizontal_offset := Vector3(offset.x, 0.0, offset.z)
		var distance: float = horizontal_offset.length()
		if distance <= 0.12 or distance > maximum_range:
			continue
		var direction_to_target: Vector3 = horizontal_offset / distance
		var dot_value: float = cast_direction.dot(direction_to_target)
		if dot_value < minimum_dot:
			continue
		if not _has_clear_line_to_target(target, target_center):
			continue

		seen_targets[target_id] = true
		hits.append({
			"target": target,
			"distance": distance,
			"angle_degrees": rad_to_deg(acos(clampf(dot_value, -1.0, 1.0))),
		})
		if hits.size() >= maximum_targets:
			break

	return hits


func _has_clear_line_to_target(
	target: Node,
	target_center: Vector3
) -> bool:
	var world: World3D = get_world_3d()
	if world == null:
		return true
	var exclusions: Array[RID] = collision_exclusions.duplicate()
	for _attempt: int in range(12):
		var query := PhysicsRayQueryParameters3D.create(
			cast_origin,
			target_center
		)
		query.collision_mask = collision_mask
		query.collide_with_areas = true
		query.collide_with_bodies = true
		query.exclude = exclusions
		var hit: Dictionary = world.direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return true
		var collider_value: Variant = hit.get("collider")
		if not collider_value is Node:
			return false
		var collider: Node = collider_value as Node
		var hit_target: Node = _resolve_effect_target(collider)
		if hit_target == target:
			return true
		if hit_target != null and collider is CollisionObject3D:
			var rid: RID = (collider as CollisionObject3D).get_rid()
			if rid.is_valid() and not exclusions.has(rid):
				exclusions.append(rid)
				continue
		return false
	return false


func _resolve_centerline_visual_range() -> float:
	var world: World3D = get_world_3d()
	if world == null:
		return maximum_range
	var exclusions: Array[RID] = collision_exclusions.duplicate()
	var ray_end: Vector3 = cast_origin + cast_direction * maximum_range
	for _attempt: int in range(16):
		var query := PhysicsRayQueryParameters3D.create(cast_origin, ray_end)
		query.collision_mask = collision_mask
		query.collide_with_areas = true
		query.collide_with_bodies = true
		query.exclude = exclusions
		var hit: Dictionary = world.direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return maximum_range
		var collider_value: Variant = hit.get("collider")
		var position_value: Variant = hit.get("position")
		if not collider_value is Node or not position_value is Vector3:
			return maximum_range
		var collider: Node = collider_value as Node
		if _resolve_effect_target(collider) != null:
			if collider is CollisionObject3D:
				var rid: RID = (collider as CollisionObject3D).get_rid()
				if rid.is_valid() and not exclusions.has(rid):
					exclusions.append(rid)
					continue
		return clampf(
			cast_origin.distance_to(position_value as Vector3) - 0.08,
			0.5,
			maximum_range
		)
	return maximum_range


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
	if node == null or node is StaticBody3D or node is AnimatableBody3D:
		return false
	return (
		node.get_node_or_null("PayloadReceiver") != null
		or node.get_node_or_null("HitReceiver") != null
		or node.has_method("receive_damage_payload")
		or node.has_method("receive_magic_hit")
	)


func _get_target_center(target: Node) -> Vector3:
	if target is CharacterBody3D:
		return (target as CharacterBody3D).global_position + Vector3.UP * 0.85
	if target is Node3D:
		return (target as Node3D).global_position
	var parent: Node = target.get_parent()
	if parent is Node3D:
		return (parent as Node3D).global_position
	return cast_origin


func _apply_spark_payload(target: Node) -> void:
	var payload: DamagePayload = get_payload().duplicate(true) as DamagePayload
	payload.hit_type = "cone_burst"
	payload.knockback_direction = cast_direction
	for tag: String in ["cone", "burst", "close_range"]:
		if not payload.tags.has(tag):
			payload.tags.append(tag)

	var payload_receiver: Node = target.get_node_or_null("PayloadReceiver")
	if payload_receiver != null and payload_receiver.has_method("receive_payload"):
		payload_receiver.call("receive_payload", payload)
		return
	if target.has_method("receive_damage_payload"):
		target.call("receive_damage_payload", payload)
		return
	var hit_receiver: Node = target.get_node_or_null("HitReceiver")
	if hit_receiver != null:
		if hit_receiver.has_method("receive_payload"):
			hit_receiver.call("receive_payload", payload)
		elif hit_receiver.has_method("receive_hit"):
			hit_receiver.call("receive_hit", payload.amount)
		return
	if target.has_method("receive_magic_hit"):
		target.call("receive_magic_hit", payload.amount)


func get_payload() -> DamagePayload:
	if runtime_payload != null:
		return runtime_payload
	var fallback := DamagePayload.new()
	fallback.amount = 2
	fallback.stance_damage = 3
	fallback.element = "lightning"
	fallback.source_name = "Lightning Spark"
	fallback.hit_type = "cone_burst"
	fallback.status_effect = "stunned"
	fallback.status_duration = 0.45
	fallback.status_strength = 1.0
	fallback.tags = [
		"lightning",
		"magic",
		"cone",
		"burst",
		"close_range",
		"shock",
		"control",
		"interrupt",
		"conductive",
	]
	return fallback


func _build_procedural_spark_pattern(visual_range: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(Time.get_ticks_usec()) + get_instance_id() * 7919
	var segments: Array[Dictionary] = []
	var branch_count: int = maxi(primary_branch_count, 1)
	var half_angle: float = deg_to_rad(half_angle_degrees * 0.86)
	var resolved_range: float = clampf(visual_range, 0.5, maximum_range)

	for branch_index: int in range(branch_count):
		var branch_ratio: float = (
			0.5
			if branch_count <= 1
			else float(branch_index) / float(branch_count - 1)
		)
		var yaw: float = lerpf(-half_angle, half_angle, branch_ratio)
		yaw += rng.randf_range(-0.09, 0.09)
		var distance: float = rng.randf_range(
			resolved_range * 0.72,
			resolved_range
		)
		var endpoint := Vector3(
			sin(yaw) * distance,
			rng.randf_range(-0.48, 0.66),
			-cos(yaw) * distance
		)
		var previous := Vector3.ZERO
		var segment_count: int = rng.randi_range(
			mini(minimum_segments_per_branch, maximum_segments_per_branch),
			maxi(minimum_segments_per_branch, maximum_segments_per_branch)
		)

		for segment_index: int in range(1, segment_count + 1):
			var t: float = float(segment_index) / float(segment_count)
			var envelope: float = sin(PI * t)
			var next_point: Vector3 = endpoint * t
			next_point += Vector3(
				rng.randf_range(-0.24, 0.24) * envelope,
				rng.randf_range(-0.2, 0.2) * envelope,
				rng.randf_range(-0.16, 0.16) * envelope
			)
			_append_visual_segment(
				segments,
				previous,
				next_point,
				segment_thickness * rng.randf_range(0.82, 1.22),
				rng.randf_range(0.7, 1.0)
			)

			if (
				segment_index > 1
				and segment_index < segment_count
				and rng.randf() < side_branch_chance
			):
				var branch_end: Vector3 = next_point + Vector3(
					rng.randf_range(-0.7, 0.7),
					rng.randf_range(-0.42, 0.42),
					rng.randf_range(-0.62, -0.2)
				)
				_append_visual_segment(
					segments,
					next_point,
					branch_end,
					segment_thickness * 0.64,
					rng.randf_range(0.48, 0.72)
				)
			previous = next_point
			if segments.size() >= maximum_visual_segments:
				break
		if segments.size() >= maximum_visual_segments:
			break

	last_visual_segment_count = segments.size()
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = segment_mesh
	multimesh.instance_count = segments.size()
	for segment_index: int in range(segments.size()):
		var segment: Dictionary = segments[segment_index]
		var start: Vector3 = segment.get("start", Vector3.ZERO) as Vector3
		var end: Vector3 = segment.get("end", Vector3.ZERO) as Vector3
		var width: float = float(segment.get("width", segment_thickness))
		var brightness: float = float(segment.get("brightness", 1.0))
		multimesh.set_instance_transform(
			segment_index,
			_make_segment_transform(start, end, width)
		)
		multimesh.set_instance_color(
			segment_index,
			Color(
				lerpf(0.38, 0.86, brightness),
				lerpf(0.62, 0.96, brightness),
				1.0,
				lerpf(0.68, 1.0, brightness)
			)
		)
	spark_segments.multimesh = multimesh


func _append_visual_segment(
	segments: Array[Dictionary],
	start: Vector3,
	end: Vector3,
	width: float,
	brightness: float
) -> void:
	if segments.size() >= maximum_visual_segments:
		return
	if start.distance_squared_to(end) <= 0.0004:
		return
	segments.append({
		"start": start,
		"end": end,
		"width": width,
		"brightness": brightness,
	})


func _make_segment_transform(
	start: Vector3,
	end: Vector3,
	width: float
) -> Transform3D:
	var delta: Vector3 = end - start
	var length: float = maxf(delta.length(), 0.001)
	var forward: Vector3 = delta / length
	var reference: Vector3 = (
		Vector3.UP
		if absf(forward.dot(Vector3.UP)) < 0.94
		else Vector3.RIGHT
	)
	var right: Vector3 = reference.cross(forward).normalized()
	var up: Vector3 = forward.cross(right).normalized()
	var basis := Basis(
		right * width,
		up * width,
		forward * length
	)
	return Transform3D(basis, (start + end) * 0.5)


func _play_haptic_pattern(hit_count: int) -> bool:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return false
	for existing: Node in get_tree().get_nodes_in_group(
		"controller_haptic_patterns"
	):
		if (
			existing.has_method("belongs_to_source")
			and bool(existing.call("belongs_to_source", source_actor))
			and existing.has_method("cancel_pattern")
		):
			existing.call("cancel_pattern", true, "replaced_by_lightning_spark")

	var haptic: Node = ControllerHapticPatternScript.new()
	haptic.name = "LightningSparkHapticPattern"
	scene_root.add_child(haptic)
	var target_scale: float = clampf(
		haptic_strength_scale
		* (0.76 + 0.07 * float(mini(hit_count, 3))),
		0.0,
		1.0
	)
	return bool(haptic.call(
		"play_pattern",
		"lightning_spark",
		LIGHTNING_SPARK_HAPTIC_PATTERN,
		source_actor,
		target_scale
	))


func _get_cast_basis() -> Basis:
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


func get_debug_data() -> Dictionary:
	return {
		"lightning_spark_burst": true,
		"active": active,
		"range": maximum_range,
		"half_angle_degrees": half_angle_degrees,
		"hit_count": last_hit_count,
		"hit_names": last_hit_names.duplicate(),
		"query_results": last_query_result_count,
		"visual_segments": last_visual_segment_count,
		"visual_multimeshes": 1 if spark_segments != null else 0,
		"per_segment_nodes": 0,
		"visual_range": last_visual_range,
		"haptic_pattern": "crack_buzz_snap",
		"haptic_started": last_haptic_started,
		"haptic_step_count": LIGHTNING_SPARK_HAPTIC_PATTERN.size(),
	}
