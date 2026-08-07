extends Node3D
class_name LightningFlash

signal flash_started(origin: Vector3, direction: Vector3)
signal flash_resolved(
	origin: Vector3,
	destination: Vector3,
	distance: float,
	contacted: bool
)
signal flash_finished(destination: Vector3, reason: String)

const ControllerHapticPatternScript = preload(
	"res://scripts/input/controller_haptic_pattern.gd"
)

@export_group("Travel")
@export_range(2.0, 60.0, 0.5) var maximum_distance: float = 24.0
@export_range(0.0, 0.5, 0.01) var contact_skin: float = 0.08
@export_range(3, 21, 2) var sweep_ray_count_hint: int = 9
@export_flags_3d_physics var collision_mask_override: int = 0
@export_range(-1.0, 1.0, 0.05) var upward_warning_threshold: float = 0.38

@export_group("Presentation")
@export_range(0.04, 0.5, 0.01) var visual_lifetime: float = 0.18
@export_range(0.01, 0.2, 0.005) var reveal_delay: float = 0.055
@export_range(0.01, 0.12, 0.005) var segment_thickness: float = 0.04
@export_range(4, 64, 1) var minimum_main_segments: int = 8
@export_range(4, 96, 1) var maximum_main_segments: int = 30
@export_range(0.0, 1.0, 0.05) var branch_chance: float = 0.34
@export_range(8, 128, 1) var maximum_visual_segments: int = 72
@export_range(0.0, 1.5, 0.05) var haptic_strength_scale: float = 1.0

var source_actor: CharacterBody3D
var cast_origin: Vector3 = Vector3.ZERO
var cast_direction: Vector3 = Vector3.FORWARD
var destination: Vector3 = Vector3.ZERO
var travel_distance: float = 0.0
var contacted: bool = false
var contact_name: String = "none"
var contact_normal: Vector3 = Vector3.ZERO
var active: bool = false
var age: float = 0.0
var visual_restored: bool = false
var source_was_visible: bool = true
var visual_token: int = 0
var last_visual_segment_count: int = 0
var last_haptic_started: bool = false
var last_finish_reason: String = "not_started"
var sweep_ray_count: int = 0

var trail_segments: MultiMeshInstance3D
var segment_mesh: BoxMesh
var trail_material: StandardMaterial3D
var origin_light: OmniLight3D
var destination_light: OmniLight3D


func _ready() -> void:
	add_to_group("spell_effects")
	add_to_group("lightning_flash_effects")
	add_to_group("debuggable")
	_build_visuals()
	set_process(false)


func _process(delta: float) -> void:
	if not active:
		return
	age += maxf(delta, 0.0)
	if not visual_restored and age >= reveal_delay:
		_restore_source_visual()
	var ratio: float = clampf(
		age / maxf(visual_lifetime, 0.01),
		0.0,
		1.0
	)
	if trail_segments != null:
		trail_segments.transparency = ratio
		trail_segments.scale = Vector3.ONE * lerpf(1.0, 1.035, ratio)
	if origin_light != null:
		origin_light.light_energy = lerpf(4.2, 0.0, ratio)
	if destination_light != null:
		destination_light.light_energy = lerpf(
			5.4 if contacted else 3.5,
			0.0,
			ratio
		)
	if ratio >= 1.0:
		finish_flash("complete")


func _exit_tree() -> void:
	_restore_source_visual()


func set_source_actor(new_source_actor: Node) -> void:
	if new_source_actor is CharacterBody3D:
		source_actor = new_source_actor as CharacterBody3D


func belongs_to_source(candidate: Node) -> bool:
	return source_actor != null and source_actor == candidate


func execute(player: Node3D, requested_direction: Vector3) -> void:
	if player is CharacterBody3D:
		source_actor = player as CharacterBody3D
	if source_actor == null or not is_instance_valid(source_actor):
		queue_free()
		return

	_cancel_previous_flash()
	cast_direction = _resolve_direction(requested_direction)
	cast_origin = source_actor.global_position
	var travel_result: Dictionary = _resolve_travel(cast_direction)
	travel_distance = float(travel_result.get("distance", 0.0))
	contacted = bool(travel_result.get("contacted", false))
	contact_name = str(travel_result.get("contact_name", "none"))
	contact_normal = travel_result.get("contact_normal", Vector3.ZERO) as Vector3
	destination = cast_origin + cast_direction * travel_distance

	global_transform = Transform3D(Basis.IDENTITY, cast_origin)
	_build_procedural_trail(destination - cast_origin)
	_move_source_to_destination()
	_hide_source_visual()
	_write_flash_metadata()
	last_haptic_started = _play_haptic_pattern()

	if cast_direction.y >= upward_warning_threshold:
		_show_message("Flash carries Grace skyward. Landing is now your problem.")

	age = 0.0
	active = true
	last_finish_reason = "active"
	if trail_segments != null:
		trail_segments.visible = true
		trail_segments.transparency = 0.0
	if origin_light != null:
		origin_light.light_energy = 4.2
	if destination_light != null:
		destination_light.position = destination - cast_origin
		destination_light.light_energy = 5.4 if contacted else 3.5
	set_process(true)
	flash_started.emit(cast_origin, cast_direction)
	flash_resolved.emit(
		cast_origin,
		destination,
		travel_distance,
		contacted
	)


func finish_flash(reason: String = "complete") -> void:
	if not active and last_finish_reason != "active":
		_restore_source_visual()
		return
	active = false
	last_finish_reason = reason
	set_process(false)
	_restore_source_visual()
	if trail_segments != null:
		trail_segments.visible = false
	if origin_light != null:
		origin_light.light_energy = 0.0
	if destination_light != null:
		destination_light.light_energy = 0.0
	flash_finished.emit(destination, reason)
	queue_free()


func _resolve_direction(requested_direction: Vector3) -> Vector3:
	var direction: Vector3 = requested_direction
	if direction.length_squared() <= 0.0001 and source_actor != null:
		direction = -source_actor.global_transform.basis.z
	if direction.length_squared() <= 0.0001:
		direction = Vector3.FORWARD
	return direction.normalized()


func _resolve_travel(direction: Vector3) -> Dictionary:
	var result: Dictionary = {
		"distance": maximum_distance,
		"contacted": false,
		"contact_name": "none",
		"contact_normal": Vector3.ZERO,
	}
	var world: World3D = source_actor.get_world_3d()
	if world == null:
		return result

	var profile: Dictionary = _get_collision_profile()
	var collision_center: Vector3 = source_actor.global_position + (
		profile.get("center_offset", Vector3.ZERO) as Vector3
	)
	var radius: float = maxf(float(profile.get("radius", 0.42)), 0.05)
	var half_height: float = maxf(
		float(profile.get("half_height", 0.9)),
		radius
	)
	var capsule_segment_half: float = maxf(half_height - radius, 0.0)
	var front_extent: float = radius + absf(direction.y) * capsule_segment_half
	var axis_a: Vector3 = direction.cross(Vector3.UP)
	if axis_a.length_squared() <= 0.0001:
		axis_a = Vector3.RIGHT
	axis_a = axis_a.normalized()
	var axis_b: Vector3 = axis_a.cross(direction)
	if axis_b.length_squared() <= 0.0001:
		axis_b = Vector3.FORWARD
	axis_b = axis_b.normalized()
	var extent_a: float = radius + absf(axis_a.y) * capsule_segment_half
	var extent_b: float = radius + absf(axis_b.y) * capsule_segment_half
	var offsets: Array[Vector3] = _make_sweep_offsets(
		axis_a,
		axis_b,
		extent_a,
		extent_b
	)
	sweep_ray_count = offsets.size()
	var excluded: Array[RID] = []
	_collect_collision_rids(source_actor, excluded)
	var collision_mask: int = (
		collision_mask_override
		if collision_mask_override > 0
		else source_actor.collision_mask
	)
	var nearest_distance: float = maximum_distance
	var nearest_hit: Dictionary = {}

	for offset: Vector3 in offsets:
		var ray_start: Vector3 = (
			collision_center
			+ offset
			+ direction * front_extent
		)
		var ray_end: Vector3 = ray_start + direction * maximum_distance
		var query := PhysicsRayQueryParameters3D.create(
			ray_start,
			ray_end,
			collision_mask
		)
		query.collide_with_bodies = true
		query.collide_with_areas = false
		query.exclude = excluded
		var hit: Dictionary = world.direct_space_state.intersect_ray(query)
		if hit.is_empty():
			continue
		var hit_position: Variant = hit.get("position")
		if not hit_position is Vector3:
			continue
		var hit_distance: float = ray_start.distance_to(
			hit_position as Vector3
		)
		if hit_distance >= nearest_distance:
			continue
		nearest_distance = hit_distance
		nearest_hit = hit

	if nearest_hit.is_empty():
		return result

	result["distance"] = clampf(
		nearest_distance - maxf(contact_skin, 0.0),
		0.0,
		maximum_distance
	)
	result["contacted"] = true
	var collider_value: Variant = nearest_hit.get("collider")
	if collider_value is Node:
		result["contact_name"] = str((collider_value as Node).name)
	var normal_value: Variant = nearest_hit.get("normal")
	if normal_value is Vector3:
		result["contact_normal"] = normal_value as Vector3
	return result


func _make_sweep_offsets(
	axis_a: Vector3,
	axis_b: Vector3,
	extent_a: float,
	extent_b: float
) -> Array[Vector3]:
	var offsets: Array[Vector3] = [Vector3.ZERO]
	for sign_value: float in [-1.0, 1.0]:
		offsets.append(axis_a * extent_a * 0.82 * sign_value)
		offsets.append(axis_b * extent_b * 0.82 * sign_value)
	for sign_a: float in [-1.0, 1.0]:
		for sign_b: float in [-1.0, 1.0]:
			offsets.append(
				axis_a * extent_a * 0.56 * sign_a
				+ axis_b * extent_b * 0.56 * sign_b
			)
	return offsets


func _get_collision_profile() -> Dictionary:
	var profile: Dictionary = {
		"center_offset": Vector3.ZERO,
		"radius": 0.42,
		"half_height": 0.9,
	}
	var collision_shape: CollisionShape3D = source_actor.get_node_or_null(
		"CollisionShape3D"
	) as CollisionShape3D
	if collision_shape == null or collision_shape.shape == null:
		return profile
	profile["center_offset"] = (
		collision_shape.global_position - source_actor.global_position
	)
	if collision_shape.shape is CapsuleShape3D:
		var capsule := collision_shape.shape as CapsuleShape3D
		profile["radius"] = capsule.radius
		profile["half_height"] = capsule.height * 0.5
	elif collision_shape.shape is SphereShape3D:
		var sphere := collision_shape.shape as SphereShape3D
		profile["radius"] = sphere.radius
		profile["half_height"] = sphere.radius
	elif collision_shape.shape is BoxShape3D:
		var box := collision_shape.shape as BoxShape3D
		profile["radius"] = maxf(box.size.x, box.size.z) * 0.5
		profile["half_height"] = box.size.y * 0.5
	return profile


func _move_source_to_destination() -> void:
	if source_actor == null or not is_instance_valid(source_actor):
		return
	source_actor.global_position = destination
	if source_actor.has_method("reset_physics_interpolation"):
		source_actor.call("reset_physics_interpolation")


func _hide_source_visual() -> void:
	if source_actor == null or not is_instance_valid(source_actor):
		return
	source_was_visible = source_actor.visible
	visual_token = get_instance_id()
	source_actor.set_meta("lightning_flash_visual_token", visual_token)
	source_actor.visible = false
	visual_restored = false


func _restore_source_visual() -> void:
	if visual_restored:
		return
	visual_restored = true
	if source_actor == null or not is_instance_valid(source_actor):
		return
	if int(source_actor.get_meta("lightning_flash_visual_token", -1)) != visual_token:
		return
	source_actor.visible = source_was_visible
	source_actor.remove_meta("lightning_flash_visual_token")


func _write_flash_metadata() -> void:
	if source_actor == null or not is_instance_valid(source_actor):
		return
	var serial: int = int(
		source_actor.get_meta("lightning_flash_serial", 0)
	) + 1
	source_actor.set_meta("lightning_flash_serial", serial)
	source_actor.set_meta("lightning_flash_origin", cast_origin)
	source_actor.set_meta("lightning_flash_destination", destination)
	source_actor.set_meta("lightning_flash_direction", cast_direction)
	source_actor.set_meta("lightning_flash_distance", travel_distance)
	source_actor.set_meta("lightning_flash_contacted", contacted)
	source_actor.set_meta("lightning_flash_contact_name", contact_name)
	source_actor.set_meta("lightning_flash_contact_normal", contact_normal)


func _cancel_previous_flash() -> void:
	for existing: Node in get_tree().get_nodes_in_group(
		"lightning_flash_effects"
	):
		if existing == self:
			continue
		if (
			existing.has_method("belongs_to_source")
			and bool(existing.call("belongs_to_source", source_actor))
			and existing.has_method("finish_flash")
		):
			existing.call("finish_flash", "replaced")


func _build_visuals() -> void:
	segment_mesh = BoxMesh.new()
	segment_mesh.size = Vector3.ONE
	trail_material = StandardMaterial3D.new()
	trail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail_material.vertex_color_use_as_albedo = true
	trail_material.albedo_color = Color(0.72, 0.88, 1.0, 1.0)
	trail_material.emission_enabled = true
	trail_material.emission = Color(0.12, 0.38, 1.0, 1.0)
	trail_material.emission_energy_multiplier = 4.0

	trail_segments = MultiMeshInstance3D.new()
	trail_segments.name = "FlashTrailSegments"
	trail_segments.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trail_segments.material_override = trail_material
	trail_segments.visible = false
	add_child(trail_segments)

	origin_light = OmniLight3D.new()
	origin_light.name = "FlashOriginLight"
	origin_light.light_color = Color(0.3, 0.58, 1.0, 1.0)
	origin_light.light_energy = 0.0
	origin_light.omni_range = 5.0
	origin_light.shadow_enabled = false
	add_child(origin_light)

	destination_light = OmniLight3D.new()
	destination_light.name = "FlashDestinationLight"
	destination_light.light_color = Color(0.5, 0.74, 1.0, 1.0)
	destination_light.light_energy = 0.0
	destination_light.omni_range = 6.0
	destination_light.shadow_enabled = false
	add_child(destination_light)


func _build_procedural_trail(local_end: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(Time.get_ticks_usec()) + get_instance_id() * 3571
	var distance: float = maxf(local_end.length(), 0.001)
	var forward: Vector3 = local_end / distance
	var axis_a: Vector3 = forward.cross(Vector3.UP)
	if axis_a.length_squared() <= 0.0001:
		axis_a = Vector3.RIGHT
	axis_a = axis_a.normalized()
	var axis_b: Vector3 = axis_a.cross(forward).normalized()
	var segment_count: int = clampi(
		int(ceil(distance * 1.05)),
		minimum_main_segments,
		maximum_main_segments
	)
	var segments: Array[Dictionary] = []
	var previous: Vector3 = Vector3.ZERO
	for segment_index: int in range(1, segment_count + 1):
		var ratio: float = float(segment_index) / float(segment_count)
		var envelope: float = sin(PI * ratio)
		var next_point: Vector3 = local_end * ratio
		next_point += axis_a * rng.randf_range(-0.22, 0.22) * envelope
		next_point += axis_b * rng.randf_range(-0.18, 0.18) * envelope
		_append_segment(
			segments,
			previous,
			next_point,
			segment_thickness * rng.randf_range(0.8, 1.25),
			rng.randf_range(0.78, 1.0)
		)
		if (
			segment_index > 1
			and segment_index < segment_count
			and rng.randf() < branch_chance
		):
			var branch_direction: Vector3 = (
				axis_a * rng.randf_range(-1.0, 1.0)
				+ axis_b * rng.randf_range(-0.8, 0.8)
				+ forward * rng.randf_range(0.1, 0.45)
			).normalized()
			var branch_end: Vector3 = next_point + branch_direction * rng.randf_range(
				0.35,
				1.15
			)
			_append_segment(
				segments,
				next_point,
				branch_end,
				segment_thickness * 0.58,
				rng.randf_range(0.46, 0.72)
			)
		previous = next_point
		if segments.size() >= maximum_visual_segments:
			break

	last_visual_segment_count = segments.size()
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = segment_mesh
	multimesh.instance_count = segments.size()
	for index: int in range(segments.size()):
		var segment: Dictionary = segments[index]
		var start: Vector3 = segment.get("start", Vector3.ZERO) as Vector3
		var finish: Vector3 = segment.get("finish", Vector3.ZERO) as Vector3
		var width: float = float(segment.get("width", segment_thickness))
		var brightness: float = float(segment.get("brightness", 1.0))
		multimesh.set_instance_transform(
			index,
			_make_segment_transform(start, finish, width)
		)
		multimesh.set_instance_color(
			index,
			Color(
				lerpf(0.32, 0.88, brightness),
				lerpf(0.58, 0.98, brightness),
				1.0,
				lerpf(0.6, 1.0, brightness)
			)
		)
	trail_segments.multimesh = multimesh


func _append_segment(
	segments: Array[Dictionary],
	start: Vector3,
	finish: Vector3,
	width: float,
	brightness: float
) -> void:
	if segments.size() >= maximum_visual_segments:
		return
	if start.distance_squared_to(finish) <= 0.0004:
		return
	segments.append({
		"start": start,
		"finish": finish,
		"width": width,
		"brightness": brightness,
	})


func _make_segment_transform(
	start: Vector3,
	finish: Vector3,
	width: float
) -> Transform3D:
	var delta: Vector3 = finish - start
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
	return Transform3D(basis, (start + finish) * 0.5)


func _play_haptic_pattern() -> bool:
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
			existing.call("cancel_pattern", true, "replaced_by_flash")
	var pattern: Array = [
		{"weak": 0.1, "strong": 0.88, "duration": 0.026},
		{"weak": 0.0, "strong": 0.0, "duration": 0.01},
		{"weak": 0.62, "strong": 0.2, "duration": 0.045},
		{"weak": 0.0, "strong": 0.0, "duration": 0.008},
		{
			"weak": 0.28 if contacted else 0.18,
			"strong": 0.78 if contacted else 0.36,
			"duration": 0.058 if contacted else 0.04,
		},
	]
	var haptic: Node = ControllerHapticPatternScript.new()
	haptic.name = "LightningFlashHapticPattern"
	scene_root.add_child(haptic)
	var distance_ratio: float = clampf(
		travel_distance / maxf(maximum_distance, 0.01),
		0.0,
		1.0
	)
	var strength: float = clampf(
		haptic_strength_scale * lerpf(0.72, 1.0, distance_ratio),
		0.0,
		1.0
	)
	return bool(haptic.call(
		"play_pattern",
		"lightning_flash",
		pattern,
		source_actor,
		strength
	))


func _collect_collision_rids(
	node: Node,
	destination_rids: Array[RID]
) -> void:
	if node is CollisionObject3D:
		var rid: RID = (node as CollisionObject3D).get_rid()
		if rid.is_valid() and not destination_rids.has(rid):
			destination_rids.append(rid)
	for child: Node in node.get_children():
		_collect_collision_rids(child, destination_rids)


func _show_message(message: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", message)


func get_debug_data() -> Dictionary:
	return {
		"lightning_flash": true,
		"active": active,
		"origin": cast_origin,
		"destination": destination,
		"direction": cast_direction,
		"distance": snappedf(travel_distance, 0.01),
		"maximum_distance": maximum_distance,
		"contacted": contacted,
		"contact_name": contact_name,
		"contact_normal": contact_normal,
		"sweep_rays": sweep_ray_count,
		"visual_segments": last_visual_segment_count,
		"visual_multimeshes": 1 if trail_segments != null else 0,
		"per_segment_nodes": 0,
		"source_hidden": (
			source_actor != null
			and is_instance_valid(source_actor)
			and not source_actor.visible
		),
		"haptic_pattern": "crack_rush_contact",
		"haptic_started": last_haptic_started,
		"upward_component": snappedf(cast_direction.y, 0.01),
		"finish_reason": last_finish_reason,
	}
