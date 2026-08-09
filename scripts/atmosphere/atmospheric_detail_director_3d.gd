extends Node3D
class_name AtmosphericDetailDirector3D

signal atmospheric_quality_changed(quality: int, visible_instances: int)

@export var profile: AtmosphericDetailProfile
@export var enabled: bool = true

var lighting_director: LightingDirector3D = null
var motion_director: EnvironmentalMotionDirector3D = null
var active_camera: Camera3D = null
var fields: Array[Dictionary] = []
var soft_texture: ImageTexture = null
var elapsed: float = 0.0
var update_timer: float = 0.0
var active_quality: int = -1
var total_authored_instances: int = 0
var visible_instance_count: int = 0
var update_count: int = 0


func _ready() -> void:
	add_to_group("atmospheric_detail_director")
	add_to_group("debuggable")
	_resolve_dependencies()
	_ensure_soft_texture()
	_apply_quality(_current_quality())
	set_meta("atmospheric_detail_initialized", profile != null)


func _process(delta: float) -> void:
	if not enabled or profile == null:
		return
	var safe_delta: float = maxf(delta, 0.0)
	elapsed += safe_delta
	if lighting_director == null or not is_instance_valid(lighting_director):
		_resolve_dependencies()
	var requested_quality: int = _current_quality()
	if requested_quality != active_quality:
		_apply_quality(requested_quality)
	update_timer -= safe_delta
	if update_timer <= 0.0:
		update_timer = maxf(profile.update_interval, 0.02)
		_update_fields()


func add_field(
	field_id: String,
	world_center: Vector3,
	extents: Vector3,
	kind: String,
	maximum_count: int,
	color: Color,
	minimum_size: float,
	maximum_size: float,
	wind_response: float,
	vertical_drift: float,
	minimum_quality: int = 1
) -> MultiMeshInstance3D:
	if profile == null:
		return null
	_ensure_soft_texture()
	var safe_count: int = maxi(maximum_count, 0)
	var remaining: int = maxi(profile.maximum_instances - total_authored_instances, 0)
	safe_count = mini(safe_count, remaining)
	if safe_count <= 0:
		return null

	var normalized_kind: String = kind.strip_edges().to_lower()
	var field := MultiMeshInstance3D.new()
	field.name = field_id
	add_child(field)
	field.global_position = world_center
	field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_texture = soft_texture
	material.albedo_color = color

	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = material

	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = quad
	multi.instance_count = safe_count
	multi.visible_instance_count = 0
	field.multimesh = multi

	var safe_extents := Vector3(
		maxf(absf(extents.x), 0.1),
		maxf(absf(extents.y), 0.1),
		maxf(absf(extents.z), 0.1)
	)
	var base_positions: Array[Vector3] = []
	var phases: Array[float] = []
	var sizes: Array[float] = []
	var seed_base: int = abs(field_id.hash()) + 137
	var min_size: float = maxf(minimum_size, 0.005)
	var max_size: float = maxf(maximum_size, min_size)
	for index: int in range(safe_count):
		var seed: int = seed_base + index * 17
		base_positions.append(Vector3(
			lerpf(-safe_extents.x, safe_extents.x, _rand01(seed + 1)),
			lerpf(-safe_extents.y, safe_extents.y, _rand01(seed + 2)),
			lerpf(-safe_extents.z, safe_extents.z, _rand01(seed + 3))
		))
		phases.append(_rand01(seed + 4) * TAU)
		sizes.append(lerpf(min_size, max_size, _rand01(seed + 5)))

	fields.append({
		"id": field_id,
		"node": field,
		"multimesh": multi,
		"kind": normalized_kind,
		"extents": safe_extents,
		"maximum_count": safe_count,
		"minimum_quality": clampi(minimum_quality, 0, 2),
		"wind_response": maxf(wind_response, 0.0),
		"vertical_drift": vertical_drift,
		"base_positions": base_positions,
		"phases": phases,
		"sizes": sizes,
	})
	total_authored_instances += safe_count
	_apply_quality(_current_quality())
	return field


func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		visible_instance_count = 0
		for record: Dictionary in fields:
			var multi: MultiMesh = record.get("multimesh") as MultiMesh
			if multi != null:
				multi.visible_instance_count = 0
		return
	_apply_quality(_current_quality())


func _resolve_dependencies() -> void:
	lighting_director = null
	motion_director = null
	active_camera = null
	if get_tree() == null:
		return
	var lighting_candidate: Node = get_tree().get_first_node_in_group(
		"lighting_director"
	)
	if lighting_candidate is LightingDirector3D:
		lighting_director = lighting_candidate as LightingDirector3D
	var motion_candidate: Node = get_tree().get_first_node_in_group(
		"environmental_motion_director"
	)
	if motion_candidate is EnvironmentalMotionDirector3D:
		motion_director = motion_candidate as EnvironmentalMotionDirector3D
	if get_viewport() != null:
		active_camera = get_viewport().get_camera_3d()


func _current_quality() -> int:
	if profile == null:
		return 0
	if not profile.follow_lighting_quality or lighting_director == null:
		return 2
	return clampi(lighting_director.quality, 0, 2)


func _apply_quality(quality: int) -> void:
	if profile == null:
		return
	active_quality = clampi(quality, 0, 2)
	visible_instance_count = 0
	var density_scale: float = profile.get_density_scale(active_quality)
	for record: Dictionary in fields:
		var multi: MultiMesh = record.get("multimesh") as MultiMesh
		if multi == null:
			continue
		var minimum_quality: int = int(record.get("minimum_quality", 1))
		var count: int = int(record.get("maximum_count", 0))
		var visible_count: int = 0
		if enabled and active_quality >= minimum_quality:
			visible_count = clampi(
				int(round(float(count) * density_scale)),
				0,
				count
			)
		multi.visible_instance_count = visible_count
		visible_instance_count += visible_count
	atmospheric_quality_changed.emit(active_quality, visible_instance_count)


func _update_fields() -> void:
	if visible_instance_count <= 0:
		return
	if get_viewport() != null:
		active_camera = get_viewport().get_camera_3d()
	for record: Dictionary in fields:
		var field: MultiMeshInstance3D = record.get("node") as MultiMeshInstance3D
		var multi: MultiMesh = record.get("multimesh") as MultiMesh
		if field == null or multi == null or multi.visible_instance_count <= 0:
			continue
		var extents: Vector3 = record.get("extents", Vector3.ONE)
		var kind: String = str(record.get("kind", "dust"))
		var wind_response: float = float(record.get("wind_response", 0.2))
		var vertical_drift: float = float(record.get("vertical_drift", 0.0))
		var base_positions: Array = record.get("base_positions", []) as Array
		var phases: Array = record.get("phases", []) as Array
		var sizes: Array = record.get("sizes", []) as Array
		var wind: Vector3 = Vector3.ZERO
		if (
			motion_director != null
			and is_instance_valid(motion_director)
			and motion_director.enabled
		):
			wind = motion_director.sample_visual_wind_at(
				field.global_position,
				0.61
			)
		var max_wind: float = maxf(profile.maximum_visual_wind_speed, 0.1)
		if wind.length_squared() > max_wind * max_wind:
			wind = wind.normalized() * max_wind
		var local_wind: Vector3 = field.global_basis.inverse() * wind

		for index: int in range(multi.visible_instance_count):
			var base: Vector3 = base_positions[index] as Vector3
			var phase: float = float(phases[index])
			var size: float = float(sizes[index])
			var local: Vector3 = base
			local += local_wind * elapsed * wind_response * 0.18
			local.y += elapsed * vertical_drift
			local.x += sin(elapsed * 0.46 + phase) * 0.16
			local.z += cos(elapsed * 0.39 + phase * 1.17) * 0.13
			if kind == "mist":
				local.x += sin(elapsed * 0.73 + phase * 1.9) * 0.22
				local.z += cos(elapsed * 0.58 + phase * 0.8) * 0.20
			elif kind == "pollen":
				local.y += sin(elapsed * 0.66 + phase) * 0.10
			local.x = _wrap_axis(local.x, extents.x)
			local.y = _wrap_axis(local.y, extents.y)
			local.z = _wrap_axis(local.z, extents.z)

			var pulse: float = 1.0 + sin(elapsed * 0.9 + phase) * 0.12
			var camera_fade: float = _camera_fade_for(field, local)
			var scale_value := Vector3(size, size, size) * pulse * camera_fade
			if kind == "mist":
				scale_value = Vector3(size * 2.2, size * 0.72, size) * pulse * camera_fade
			elif kind == "pollen":
				scale_value = Vector3(size * 0.72, size * 1.15, size) * pulse * camera_fade
			multi.set_instance_transform(
				index,
				Transform3D(Basis().scaled(scale_value), local)
			)
	update_count += 1


func _camera_fade_for(field: MultiMeshInstance3D, local_position: Vector3) -> float:
	if profile == null or profile.camera_clear_radius <= 0.0:
		return 1.0
	if active_camera == null or not is_instance_valid(active_camera):
		return 1.0
	var world_position: Vector3 = field.to_global(local_position)
	var distance_to_camera: float = active_camera.global_position.distance_to(world_position)
	var clear_radius: float = maxf(profile.camera_clear_radius, 0.0)
	var fade_distance: float = maxf(profile.camera_fade_distance, 0.0)
	if fade_distance <= 0.001:
		return 0.0 if distance_to_camera < clear_radius else 1.0
	return smoothstep(
		clear_radius,
		clear_radius + fade_distance,
		distance_to_camera
	)


func _ensure_soft_texture() -> void:
	if soft_texture != null or profile == null:
		return
	var resolution: int = clampi(profile.soft_texture_resolution, 8, 64)
	var image: Image = Image.create_empty(
		resolution,
		resolution,
		false,
		Image.FORMAT_RGBA8
	)
	for y: int in range(resolution):
		for x: int in range(resolution):
			var uv := Vector2(
				(float(x) + 0.5) / float(resolution),
				(float(y) + 0.5) / float(resolution)
			)
			var distance: float = (uv - Vector2(0.5, 0.5)).length() / 0.5
			var alpha: float = 1.0 - smoothstep(0.12, 1.0, distance)
			alpha *= alpha
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	soft_texture = ImageTexture.create_from_image(image)


func _rand01(seed: int) -> float:
	var value: float = sin(float(seed) * 12.9898 + 78.233) * 43758.5453
	return value - floor(value)


func _wrap_axis(value: float, extent: float) -> float:
	var safe_extent: float = maxf(absf(extent), 0.01)
	return wrapf(value, -safe_extent, safe_extent)


func get_field_counts() -> Dictionary:
	var counts: Dictionary = {}
	for record: Dictionary in fields:
		var kind: String = str(record.get("kind", "unknown"))
		counts[kind] = int(counts.get(kind, 0)) + int(
			record.get("maximum_count", 0)
		)
	return counts


func get_debug_data() -> Dictionary:
	return {
		"atmospheric_detail_director": true,
		"initialized": profile != null and soft_texture != null,
		"profile_id": profile.profile_id if profile != null else "",
		"enabled": enabled,
		"quality": active_quality,
		"field_count": fields.size(),
		"authored_instances": total_authored_instances,
		"visible_instances": visible_instance_count,
		"field_counts": get_field_counts(),
		"multimesh_batched": true,
		"follows_lighting_quality": profile != null and profile.follow_lighting_quality,
		"samples_environmental_motion": motion_director != null,
		"camera_clear_radius": profile.camera_clear_radius if profile != null else 0.0,
		"camera_fade_distance": profile.camera_fade_distance if profile != null else 0.0,
		"camera_safe_fade": profile != null and profile.camera_clear_radius > 0.0,
		"update_count": update_count,
		"soft_texture_runtime_generated": soft_texture != null,
		"gameplay_authority": false,
	}
