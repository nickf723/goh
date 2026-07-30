extends Node3D
class_name SpellTargetingPreview


var profile: SpellTargetingProfile
var source_actor: Node3D
var target_position: Vector3 = Vector3.ZERO
var target_direction: Vector3 = Vector3.FORWARD
var target_valid: bool = true
var invalid_reason: String = ""

var target_shape_root: Node3D
var source_range_root: Node3D
var center_root: Node3D
var fill_instance: MeshInstance3D
var outline_instance: MeshInstance3D
var range_instance: MeshInstance3D
var dynamic_instance: MeshInstance3D
var center_instance: MeshInstance3D

var fill_material: StandardMaterial3D
var outline_material: StandardMaterial3D
var range_material: StandardMaterial3D
var center_material: StandardMaterial3D
var outline_mesh: ImmediateMesh
var range_mesh: ImmediateMesh
var dynamic_mesh: ImmediateMesh


func configure(
	new_profile: SpellTargetingProfile,
	new_source_actor: Node3D
) -> void:
	profile = new_profile
	source_actor = new_source_actor
	_clear_preview()
	if profile == null:
		return
	_build_materials()
	_build_roots()
	_build_fill()
	_build_outline()
	_build_range_ring()
	_build_center_marker()
	_update_color_state()


func set_preview_state(
	new_target_position: Vector3,
	new_direction: Vector3,
	is_valid: bool,
	reason: String = ""
) -> void:
	target_position = new_target_position
	target_direction = new_direction
	target_direction.y = 0.0
	if target_direction.length() <= 0.01:
		target_direction = Vector3.FORWARD
	target_direction = target_direction.normalized()
	target_valid = is_valid
	invalid_reason = reason
	_update_transforms()
	_update_dynamic_lines()
	_update_color_state()
	_update_pulse()


func _process(_delta: float) -> void:
	if profile == null:
		return
	_update_pulse()


func _build_roots() -> void:
	target_shape_root = Node3D.new()
	target_shape_root.name = "TargetShape"
	add_child(target_shape_root)

	source_range_root = Node3D.new()
	source_range_root.name = "SourceRange"
	add_child(source_range_root)

	center_root = Node3D.new()
	center_root.name = "TargetCenter"
	add_child(center_root)

	dynamic_instance = MeshInstance3D.new()
	dynamic_instance.name = "DynamicGuide"
	dynamic_instance.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	dynamic_mesh = ImmediateMesh.new()
	dynamic_instance.mesh = dynamic_mesh
	add_child(dynamic_instance)


func _build_materials() -> void:
	fill_material = _make_material(
		profile.valid_color,
		profile.fill_alpha
	)
	outline_material = _make_material(
		profile.valid_color,
		profile.outline_alpha
	)
	range_material = _make_material(profile.neutral_color, 0.34)
	center_material = _make_material(profile.valid_color, 0.96)


func _build_fill() -> void:
	fill_instance = MeshInstance3D.new()
	fill_instance.name = "PreviewFill"
	fill_instance.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	fill_instance.material_override = fill_material
	target_shape_root.add_child(fill_instance)

	match profile.preview_shape:
		SpellTargetingProfile.PreviewShape.POINT,
		SpellTargetingProfile.PreviewShape.TARGET_LOCK:
			var point_mesh := CylinderMesh.new()
			point_mesh.top_radius = 0.34
			point_mesh.bottom_radius = 0.34
			point_mesh.height = 0.025
			point_mesh.radial_segments = 24
			fill_instance.mesh = point_mesh
		SpellTargetingProfile.PreviewShape.CIRCLE,
		SpellTargetingProfile.PreviewShape.SELF_BURST:
			var circle_mesh := CylinderMesh.new()
			circle_mesh.top_radius = profile.radius
			circle_mesh.bottom_radius = profile.radius
			circle_mesh.height = 0.025
			circle_mesh.radial_segments = 48
			fill_instance.mesh = circle_mesh
		SpellTargetingProfile.PreviewShape.LINE:
			var line_mesh := BoxMesh.new()
			line_mesh.size = Vector3(
				profile.width,
				0.025,
				profile.length
			)
			fill_instance.mesh = line_mesh
			fill_instance.position = Vector3(
				0.0,
				0.0,
				-profile.length * 0.5
			)
		SpellTargetingProfile.PreviewShape.CONE:
			fill_instance.mesh = _build_cone_fill_mesh()
		SpellTargetingProfile.PreviewShape.TRAJECTORY:
			fill_instance.visible = false
		_:
			fill_instance.visible = false


func _build_outline() -> void:
	outline_instance = MeshInstance3D.new()
	outline_instance.name = "PreviewOutline"
	outline_instance.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	outline_mesh = ImmediateMesh.new()
	outline_instance.mesh = outline_mesh
	target_shape_root.add_child(outline_instance)
	outline_mesh.surface_begin(
		Mesh.PRIMITIVE_LINES,
		outline_material
	)
	match profile.preview_shape:
		SpellTargetingProfile.PreviewShape.POINT,
		SpellTargetingProfile.PreviewShape.TARGET_LOCK:
			_add_circle(outline_mesh, 0.42, 28, 0.035)
		SpellTargetingProfile.PreviewShape.CIRCLE,
		SpellTargetingProfile.PreviewShape.SELF_BURST:
			_add_circle(
				outline_mesh,
				profile.radius,
				56,
				0.035
			)
		SpellTargetingProfile.PreviewShape.CONE:
			_add_cone_outline(outline_mesh)
		SpellTargetingProfile.PreviewShape.LINE:
			_add_line_outline(outline_mesh)
		SpellTargetingProfile.PreviewShape.TRAJECTORY:
			_add_circle(
				outline_mesh,
				maxf(profile.radius, 0.45),
				32,
				0.035
			)
		_:
			pass
	outline_mesh.surface_end()


func _build_range_ring() -> void:
	range_instance = MeshInstance3D.new()
	range_instance.name = "MaximumRange"
	range_instance.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	range_mesh = ImmediateMesh.new()
	range_instance.mesh = range_mesh
	source_range_root.add_child(range_instance)
	range_instance.visible = (
		profile.show_range_ring
		and profile.maximum_range > 0.0
	)
	if not range_instance.visible:
		return
	range_mesh.surface_begin(Mesh.PRIMITIVE_LINES, range_material)
	_add_circle(
		range_mesh,
		profile.maximum_range,
		72,
		0.018
	)
	if profile.minimum_range > 0.0:
		_add_circle(
			range_mesh,
			profile.minimum_range,
			48,
			0.02
		)
	range_mesh.surface_end()


func _build_center_marker() -> void:
	center_instance = MeshInstance3D.new()
	center_instance.name = "CenterMarker"
	center_instance.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	center_instance.material_override = center_material
	center_instance.visible = profile.show_center_marker
	var sphere := SphereMesh.new()
	sphere.radius = 0.11
	sphere.height = 0.22
	sphere.radial_segments = 12
	sphere.rings = 6
	center_instance.mesh = sphere
	center_root.add_child(center_instance)


func _update_transforms() -> void:
	if profile == null or source_actor == null:
		return
	var source_position: Vector3 = source_actor.global_position
	if source_range_root != null:
		source_range_root.global_position = (
			source_position + Vector3.UP * 0.035
		)
	if center_root != null:
		center_root.global_position = (
			target_position + Vector3.UP * 0.08
		)
	if target_shape_root == null:
		return
	match profile.preview_shape:
		SpellTargetingProfile.PreviewShape.CONE,
		SpellTargetingProfile.PreviewShape.LINE:
			target_shape_root.global_position = (
				source_position + Vector3.UP * 0.045
			)
			target_shape_root.look_at(
				target_shape_root.global_position
				+ target_direction,
				Vector3.UP
			)
		SpellTargetingProfile.PreviewShape.SELF_BURST:
			target_shape_root.global_position = (
				source_position + Vector3.UP * 0.045
			)
		_:
			target_shape_root.global_position = target_position


func _update_dynamic_lines() -> void:
	if (
		dynamic_mesh == null
		or profile == null
		or source_actor == null
	):
		return
	dynamic_mesh.clear_surfaces()
	if not profile.show_direction_line:
		return
	dynamic_mesh.surface_begin(
		Mesh.PRIMITIVE_LINES,
		outline_material
	)
	var source_position: Vector3 = (
		source_actor.global_position + Vector3.UP * 0.12
	)
	var end_position: Vector3 = (
		target_position + Vector3.UP * 0.12
	)
	if (
		profile.preview_shape
		== SpellTargetingProfile.PreviewShape.TRAJECTORY
	):
		_add_trajectory(
			dynamic_mesh,
			source_position,
			end_position
		)
	else:
		_add_segment(
			dynamic_mesh,
			source_position,
			end_position
		)
	dynamic_mesh.surface_end()


func _update_color_state() -> void:
	if profile == null:
		return
	var color: Color = (
		profile.valid_color
		if target_valid
		else profile.invalid_color
	)
	_set_material_color(
		fill_material,
		color,
		profile.fill_alpha
	)
	_set_material_color(
		outline_material,
		color,
		profile.outline_alpha
	)
	_set_material_color(center_material, color, 0.96)


func _update_pulse() -> void:
	if target_shape_root == null or profile == null:
		return
	var age: float = float(Time.get_ticks_msec()) * 0.001
	var pulse: float = (
		1.0
		+ sin(age * profile.pulse_speed) * profile.pulse_size
	)
	target_shape_root.scale = Vector3.ONE * pulse
	if center_root != null:
		center_root.scale = (
			Vector3.ONE * (1.0 + (pulse - 1.0) * 1.8)
		)


func _build_cone_fill_mesh() -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, fill_material)
	var half_angle: float = deg_to_rad(
		profile.angle_degrees * 0.5
	)
	var segments: int = 24
	for index: int in range(segments):
		var t0: float = float(index) / float(segments)
		var t1: float = float(index + 1) / float(segments)
		var a0: float = lerpf(-half_angle, half_angle, t0)
		var a1: float = lerpf(-half_angle, half_angle, t1)
		mesh.surface_add_vertex(Vector3.ZERO)
		mesh.surface_add_vertex(
			Vector3(sin(a0), 0.0, -cos(a0))
			* profile.length
		)
		mesh.surface_add_vertex(
			Vector3(sin(a1), 0.0, -cos(a1))
			* profile.length
		)
	mesh.surface_end()
	return mesh


func _add_cone_outline(mesh: ImmediateMesh) -> void:
	var half_angle: float = deg_to_rad(
		profile.angle_degrees * 0.5
	)
	var left: Vector3 = (
		Vector3(sin(-half_angle), 0.035, -cos(-half_angle))
		* profile.length
	)
	var right: Vector3 = (
		Vector3(sin(half_angle), 0.035, -cos(half_angle))
		* profile.length
	)
	_add_segment(
		mesh,
		Vector3(0.0, 0.035, 0.0),
		left
	)
	_add_segment(
		mesh,
		Vector3(0.0, 0.035, 0.0),
		right
	)
	var segments: int = 30
	for index: int in range(segments):
		var a0: float = lerpf(
			-half_angle,
			half_angle,
			float(index) / float(segments)
		)
		var a1: float = lerpf(
			-half_angle,
			half_angle,
			float(index + 1) / float(segments)
		)
		_add_segment(
			mesh,
			Vector3(sin(a0), 0.035, -cos(a0))
			* profile.length,
			Vector3(sin(a1), 0.035, -cos(a1))
			* profile.length
		)


func _add_line_outline(mesh: ImmediateMesh) -> void:
	var half_width: float = profile.width * 0.5
	var near_left := Vector3(-half_width, 0.035, 0.0)
	var near_right := Vector3(half_width, 0.035, 0.0)
	var far_left := Vector3(
		-half_width,
		0.035,
		-profile.length
	)
	var far_right := Vector3(
		half_width,
		0.035,
		-profile.length
	)
	_add_segment(mesh, near_left, near_right)
	_add_segment(mesh, near_right, far_right)
	_add_segment(mesh, far_right, far_left)
	_add_segment(mesh, far_left, near_left)


func _add_circle(
	mesh: ImmediateMesh,
	circle_radius: float,
	segments: int,
	y: float
) -> void:
	for index: int in range(segments):
		var a0: float = TAU * float(index) / float(segments)
		var a1: float = (
			TAU * float(index + 1) / float(segments)
		)
		_add_segment(
			mesh,
			Vector3(
				cos(a0) * circle_radius,
				y,
				sin(a0) * circle_radius
			),
			Vector3(
				cos(a1) * circle_radius,
				y,
				sin(a1) * circle_radius
			)
		)


func _add_trajectory(
	mesh: ImmediateMesh,
	start: Vector3,
	finish: Vector3
) -> void:
	var distance: float = start.distance_to(finish)
	var arc_height: float = maxf(1.2, distance * 0.22)
	var previous: Vector3 = start
	var segments: int = 24
	for index: int in range(1, segments + 1):
		var t: float = float(index) / float(segments)
		var point: Vector3 = start.lerp(finish, t)
		point.y += sin(t * PI) * arc_height
		_add_segment(mesh, previous, point)
		previous = point


func _add_segment(
	mesh: ImmediateMesh,
	start: Vector3,
	finish: Vector3
) -> void:
	mesh.surface_add_vertex(start)
	mesh.surface_add_vertex(finish)


func _make_material(
	color: Color,
	alpha: float
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(
		color.r,
		color.g,
		color.b,
		alpha
	)
	material.emission_enabled = true
	material.emission = Color(
		color.r,
		color.g,
		color.b,
		1.0
	)
	material.emission_energy_multiplier = (
		profile.emission_energy if profile != null else 0.7
	)
	material.transparency = (
		BaseMaterial3D.TRANSPARENCY_ALPHA
	)
	material.shading_mode = (
		BaseMaterial3D.SHADING_MODE_UNSHADED
	)
	material.no_depth_test = true
	return material


func _set_material_color(
	material: StandardMaterial3D,
	color: Color,
	alpha: float
) -> void:
	if material == null:
		return
	material.albedo_color = Color(
		color.r,
		color.g,
		color.b,
		alpha
	)
	material.emission = Color(
		color.r,
		color.g,
		color.b,
		1.0
	)


func _clear_preview() -> void:
	for child: Node in get_children():
		child.queue_free()
	target_shape_root = null
	source_range_root = null
	center_root = null
	fill_instance = null
	outline_instance = null
	range_instance = null
	dynamic_instance = null
	center_instance = null
	outline_mesh = null
	range_mesh = null
	dynamic_mesh = null


func get_debug_data() -> Dictionary:
	return {
		"profile": (
			profile.profile_id if profile != null else "none"
		),
		"shape": (
			profile.get_shape_name()
			if profile != null
			else "none"
		),
		"placement": (
			profile.get_placement_name()
			if profile != null
			else "none"
		),
		"valid": target_valid,
		"reason": invalid_reason,
		"target_position": target_position,
		"direction": target_direction,
		"has_fill": (
			fill_instance != null and fill_instance.visible
		),
		"has_outline": outline_instance != null,
		"has_range_ring": (
			range_instance != null and range_instance.visible
		),
		"has_center": (
			center_instance != null and center_instance.visible
		),
	}
