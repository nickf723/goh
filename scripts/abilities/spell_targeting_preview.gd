extends Node3D
class_name SpellTargetingPreview


const TargetingProfileScript = preload(
	"res://scripts/abilities/spell_targeting_profile.gd"
)

var profile = null
var source_actor: Node3D = null
var target_position: Vector3 = Vector3.ZERO
var target_direction: Vector3 = Vector3.FORWARD
var target_valid: bool = true
var invalid_reason: String = ""

var target_shape_root: Node3D = null
var source_range_root: Node3D = null
var center_root: Node3D = null
var fill_instance: MeshInstance3D = null
var outline_instance: MeshInstance3D = null
var range_instance: MeshInstance3D = null
var dynamic_instance: MeshInstance3D = null
var center_instance: MeshInstance3D = null

var fill_material: StandardMaterial3D = null
var outline_material: StandardMaterial3D = null
var range_material: StandardMaterial3D = null
var center_material: StandardMaterial3D = null
var outline_mesh: ImmediateMesh = null
var range_mesh: ImmediateMesh = null
var dynamic_mesh: ImmediateMesh = null


func configure(new_profile, new_source_actor: Node3D) -> void:
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
	_update_transforms()
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
	else:
		target_direction = target_direction.normalized()
	target_valid = is_valid
	invalid_reason = reason
	_update_transforms()
	_update_dynamic_lines()
	_update_color_state()
	_update_pulse()


func _process(_delta: float) -> void:
	if profile != null:
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
	dynamic_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dynamic_mesh = ImmediateMesh.new()
	dynamic_instance.mesh = dynamic_mesh
	add_child(dynamic_instance)


func _build_materials() -> void:
	fill_material = _make_material(profile.valid_color, profile.fill_alpha)
	outline_material = _make_material(profile.valid_color, profile.outline_alpha)
	range_material = _make_material(profile.neutral_color, 0.34)
	center_material = _make_material(profile.valid_color, 0.96)


func _build_fill() -> void:
	fill_instance = MeshInstance3D.new()
	fill_instance.name = "PreviewFill"
	fill_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fill_instance.material_override = fill_material
	target_shape_root.add_child(fill_instance)

	match int(profile.preview_shape):
		TargetingProfileScript.PreviewShape.POINT, TargetingProfileScript.PreviewShape.TARGET_LOCK:
			fill_instance.mesh = _make_disc_mesh(0.34, 24)
		TargetingProfileScript.PreviewShape.CIRCLE, TargetingProfileScript.PreviewShape.SELF_BURST:
			fill_instance.mesh = _make_disc_mesh(float(profile.radius), 48)
		TargetingProfileScript.PreviewShape.LINE:
			var line_mesh: BoxMesh = BoxMesh.new()
			line_mesh.size = Vector3(
				float(profile.width),
				0.025,
				float(profile.length)
			)
			fill_instance.mesh = line_mesh
			fill_instance.position = Vector3(
				0.0,
				0.0,
				-float(profile.length) * 0.5
			)
		TargetingProfileScript.PreviewShape.CONE:
			fill_instance.mesh = _build_cone_fill_mesh()
		_:
			fill_instance.visible = false


func _make_disc_mesh(radius_value: float, segments: int) -> CylinderMesh:
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = maxf(radius_value, 0.01)
	disc.bottom_radius = maxf(radius_value, 0.01)
	disc.height = 0.025
	disc.radial_segments = maxi(segments, 8)
	return disc


func _build_outline() -> void:
	outline_instance = MeshInstance3D.new()
	outline_instance.name = "PreviewOutline"
	outline_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	outline_mesh = ImmediateMesh.new()
	outline_instance.mesh = outline_mesh
	target_shape_root.add_child(outline_instance)

	outline_mesh.surface_begin(Mesh.PRIMITIVE_LINES, outline_material)
	match int(profile.preview_shape):
		TargetingProfileScript.PreviewShape.POINT, TargetingProfileScript.PreviewShape.TARGET_LOCK:
			_add_circle(outline_mesh, 0.42, 28, 0.035)
		TargetingProfileScript.PreviewShape.CIRCLE, TargetingProfileScript.PreviewShape.SELF_BURST:
			_add_circle(
				outline_mesh,
				float(profile.radius),
				56,
				0.035
			)
		TargetingProfileScript.PreviewShape.CONE:
			_add_cone_outline(outline_mesh)
		TargetingProfileScript.PreviewShape.LINE:
			_add_line_outline(outline_mesh)
		TargetingProfileScript.PreviewShape.TRAJECTORY:
			_add_circle(
				outline_mesh,
				maxf(float(profile.radius), 0.45),
				32,
				0.035
			)
		_:
			pass
	outline_mesh.surface_end()


func _build_range_ring() -> void:
	range_instance = MeshInstance3D.new()
	range_instance.name = "MaximumRange"
	range_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	range_mesh = ImmediateMesh.new()
	range_instance.mesh = range_mesh
	source_range_root.add_child(range_instance)

	range_instance.visible = (
		bool(profile.show_range_ring)
		and float(profile.maximum_range) > 0.0
	)
	if not range_instance.visible:
		return

	range_mesh.surface_begin(Mesh.PRIMITIVE_LINES, range_material)
	_add_circle(
		range_mesh,
		float(profile.maximum_range),
		72,
		0.018
	)
	if float(profile.minimum_range) > 0.0:
		_add_circle(
			range_mesh,
			float(profile.minimum_range),
			48,
			0.02
		)
	range_mesh.surface_end()


func _build_center_marker() -> void:
	center_instance = MeshInstance3D.new()
	center_instance.name = "CenterMarker"
	center_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	center_instance.material_override = center_material
	center_instance.visible = bool(profile.show_center_marker)

	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.11
	sphere.height = 0.22
	sphere.radial_segments = 12
	sphere.rings = 6
	center_instance.mesh = sphere
	center_root.add_child(center_instance)


func _update_transforms() -> void:
	if profile == null or source_actor == null:
		return
	if not is_instance_valid(source_actor):
		return

	var source_position: Vector3 = source_actor.global_position
	if source_range_root != null:
		source_range_root.global_position = source_position + Vector3.UP * 0.035
	if center_root != null:
		center_root.global_position = target_position + Vector3.UP * 0.08
	if target_shape_root == null:
		return

	match int(profile.preview_shape):
		TargetingProfileScript.PreviewShape.CONE, TargetingProfileScript.PreviewShape.LINE:
			target_shape_root.global_position = source_position + Vector3.UP * 0.045
			target_shape_root.look_at(
				target_shape_root.global_position + target_direction,
				Vector3.UP
			)
		TargetingProfileScript.PreviewShape.SELF_BURST:
			target_shape_root.global_position = source_position + Vector3.UP * 0.045
		_:
			target_shape_root.global_position = target_position


func _update_dynamic_lines() -> void:
	if dynamic_mesh == null or profile == null or source_actor == null:
		return
	if not is_instance_valid(source_actor):
		return

	dynamic_mesh.clear_surfaces()
	if not bool(profile.show_direction_line):
		return

	dynamic_mesh.surface_begin(Mesh.PRIMITIVE_LINES, outline_material)
	var source_position: Vector3 = source_actor.global_position + Vector3.UP * 0.12
	var end_position: Vector3 = target_position + Vector3.UP * 0.12
	if int(profile.preview_shape) == TargetingProfileScript.PreviewShape.TRAJECTORY:
		_add_trajectory(dynamic_mesh, source_position, end_position)
	else:
		_add_segment(dynamic_mesh, source_position, end_position)
	dynamic_mesh.surface_end()


func _update_color_state() -> void:
	if profile == null:
		return
	var state_color: Color = profile.valid_color
	if not target_valid:
		state_color = profile.invalid_color
	_set_material_color(fill_material, state_color, float(profile.fill_alpha))
	_set_material_color(outline_material, state_color, float(profile.outline_alpha))
	_set_material_color(center_material, state_color, 0.96)


func _update_pulse() -> void:
	if target_shape_root == null or profile == null:
		return
	var age: float = float(Time.get_ticks_msec()) * 0.001
	var pulse: float = (
		1.0
		+ sin(age * float(profile.pulse_speed)) * float(profile.pulse_size)
	)
	target_shape_root.scale = Vector3.ONE * pulse
	if center_root != null:
		center_root.scale = Vector3.ONE * (1.0 + (pulse - 1.0) * 1.8)


func _build_cone_fill_mesh() -> ImmediateMesh:
	var cone_mesh: ImmediateMesh = ImmediateMesh.new()
	cone_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, fill_material)
	var half_angle: float = deg_to_rad(float(profile.angle_degrees) * 0.5)
	var segment_count: int = 24
	for index: int in range(segment_count):
		var t0: float = float(index) / float(segment_count)
		var t1: float = float(index + 1) / float(segment_count)
		var angle0: float = lerpf(-half_angle, half_angle, t0)
		var angle1: float = lerpf(-half_angle, half_angle, t1)
		cone_mesh.surface_add_vertex(Vector3.ZERO)
		cone_mesh.surface_add_vertex(
			Vector3(sin(angle0), 0.0, -cos(angle0))
			* float(profile.length)
		)
		cone_mesh.surface_add_vertex(
			Vector3(sin(angle1), 0.0, -cos(angle1))
			* float(profile.length)
		)
	cone_mesh.surface_end()
	return cone_mesh


func _add_cone_outline(target_mesh: ImmediateMesh) -> void:
	var half_angle: float = deg_to_rad(float(profile.angle_degrees) * 0.5)
	var left_point: Vector3 = (
		Vector3(sin(-half_angle), 0.035, -cos(-half_angle))
		* float(profile.length)
	)
	var right_point: Vector3 = (
		Vector3(sin(half_angle), 0.035, -cos(half_angle))
		* float(profile.length)
	)
	_add_segment(target_mesh, Vector3(0.0, 0.035, 0.0), left_point)
	_add_segment(target_mesh, Vector3(0.0, 0.035, 0.0), right_point)

	var segment_count: int = 30
	for index: int in range(segment_count):
		var angle0: float = lerpf(
			-half_angle,
			half_angle,
			float(index) / float(segment_count)
		)
		var angle1: float = lerpf(
			-half_angle,
			half_angle,
			float(index + 1) / float(segment_count)
		)
		_add_segment(
			target_mesh,
			Vector3(sin(angle0), 0.035, -cos(angle0))
			* float(profile.length),
			Vector3(sin(angle1), 0.035, -cos(angle1))
			* float(profile.length)
		)


func _add_line_outline(target_mesh: ImmediateMesh) -> void:
	var half_width: float = float(profile.width) * 0.5
	var near_left: Vector3 = Vector3(-half_width, 0.035, 0.0)
	var near_right: Vector3 = Vector3(half_width, 0.035, 0.0)
	var far_left: Vector3 = Vector3(
		-half_width,
		0.035,
		-float(profile.length)
	)
	var far_right: Vector3 = Vector3(
		half_width,
		0.035,
		-float(profile.length)
	)
	_add_segment(target_mesh, near_left, near_right)
	_add_segment(target_mesh, near_right, far_right)
	_add_segment(target_mesh, far_right, far_left)
	_add_segment(target_mesh, far_left, near_left)


func _add_circle(
	target_mesh: ImmediateMesh,
	circle_radius: float,
	segment_count: int,
	height_offset: float
) -> void:
	var safe_segments: int = maxi(segment_count, 3)
	for index: int in range(safe_segments):
		var angle0: float = TAU * float(index) / float(safe_segments)
		var angle1: float = TAU * float(index + 1) / float(safe_segments)
		_add_segment(
			target_mesh,
			Vector3(
				cos(angle0) * circle_radius,
				height_offset,
				sin(angle0) * circle_radius
			),
			Vector3(
				cos(angle1) * circle_radius,
				height_offset,
				sin(angle1) * circle_radius
			)
		)


func _add_trajectory(
	target_mesh: ImmediateMesh,
	start_point: Vector3,
	end_point: Vector3
) -> void:
	var distance: float = start_point.distance_to(end_point)
	var arc_height: float = maxf(1.2, distance * 0.22)
	var previous_point: Vector3 = start_point
	var segment_count: int = 24
	for index: int in range(1, segment_count + 1):
		var t: float = float(index) / float(segment_count)
		var current_point: Vector3 = start_point.lerp(end_point, t)
		current_point.y += sin(t * PI) * arc_height
		_add_segment(target_mesh, previous_point, current_point)
		previous_point = current_point


func _add_segment(
	target_mesh: ImmediateMesh,
	start_point: Vector3,
	end_point: Vector3
) -> void:
	target_mesh.surface_add_vertex(start_point)
	target_mesh.surface_add_vertex(end_point)


func _make_material(
	base_color: Color,
	alpha_value: float
) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(
		base_color.r,
		base_color.g,
		base_color.b,
		alpha_value
	)
	material.emission_enabled = true
	material.emission = Color(
		base_color.r,
		base_color.g,
		base_color.b,
		1.0
	)
	material.emission_energy_multiplier = (
		float(profile.emission_energy) if profile != null else 0.7
	)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	return material


func _set_material_color(
	material: StandardMaterial3D,
	base_color: Color,
	alpha_value: float
) -> void:
	if material == null:
		return
	material.albedo_color = Color(
		base_color.r,
		base_color.g,
		base_color.b,
		alpha_value
	)
	material.emission = Color(
		base_color.r,
		base_color.g,
		base_color.b,
		1.0
	)


func _clear_preview() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	target_shape_root = null
	source_range_root = null
	center_root = null
	fill_instance = null
	outline_instance = null
	range_instance = null
	dynamic_instance = null
	center_instance = null
	fill_material = null
	outline_material = null
	range_material = null
	center_material = null
	outline_mesh = null
	range_mesh = null
	dynamic_mesh = null


func get_debug_data() -> Dictionary:
	var profile_id: String = "none"
	var shape_name: String = "none"
	var placement_name: String = "none"
	if profile != null:
		profile_id = str(profile.profile_id)
		shape_name = str(profile.get_shape_name())
		placement_name = str(profile.get_placement_name())
	return {
		"profile": profile_id,
		"shape": shape_name,
		"placement": placement_name,
		"valid": target_valid,
		"reason": invalid_reason,
		"target_position": target_position,
		"direction": target_direction,
		"has_fill": fill_instance != null and fill_instance.visible,
		"has_outline": outline_instance != null,
		"has_range_ring": range_instance != null and range_instance.visible,
		"has_center": center_instance != null and center_instance.visible,
	}
