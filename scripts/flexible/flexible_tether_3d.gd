extends Node3D
class_name FlexibleTether3D

signal tether_broken(reason: String, peak_tension: float)
signal tether_repaired()

@export var endpoint_a_path: NodePath
@export var endpoint_b_path: NodePath
@export var material_profile: FlexibleMaterialProfile
@export_range(0.25, 50.0, 0.05) var rest_length: float = 4.0
@export_range(3, 64, 1) var segment_count: int = 14
@export_range(1, 20, 1) var constraint_iterations: int = 7
@export_range(0.8, 1.0, 0.001) var verlet_damping: float = 0.985
@export_range(0.0, 3.0, 0.05) var gravity_scale: float = 1.0
@export var apply_endpoint_forces: bool = true
@export var debug_tension_color: bool = true

var current_tension: float = 0.0
var peak_tension: float = 0.0
var heat_amount: float = 0.0
var cold_amount: float = 0.0
var burn_progress: float = 0.0
var is_broken: bool = false
var break_reason: String = ""

var _endpoint_a: Node3D
var _endpoint_b: Node3D
var _points: PackedVector3Array = PackedVector3Array()
var _previous_points: PackedVector3Array = PackedVector3Array()
var _segments: Array[MeshInstance3D] = []
var _visual_material: StandardMaterial3D
var _broken_segment_index: int = -1


func _ready() -> void:
	add_to_group("flexible_tethers")
	_resolve_endpoints()
	_create_visuals()
	reset_tether()


func _physics_process(delta: float) -> void:
	if not _endpoints_are_valid():
		_resolve_endpoints()
	if not _endpoints_are_valid():
		return

	_update_material_state(delta)
	_update_tension()
	if not is_broken:
		_apply_tension_forces()
	_simulate_segments(delta)
	_update_visuals()


func _resolve_endpoints() -> void:
	_endpoint_a = get_node_or_null(endpoint_a_path) as Node3D
	_endpoint_b = get_node_or_null(endpoint_b_path) as Node3D


func _endpoints_are_valid() -> bool:
	return is_instance_valid(_endpoint_a) and is_instance_valid(_endpoint_b)


func reset_tether() -> void:
	is_broken = false
	break_reason = ""
	current_tension = 0.0
	peak_tension = 0.0
	heat_amount = 0.0
	cold_amount = 0.0
	burn_progress = 0.0
	_broken_segment_index = -1
	_initialize_points()
	_update_visuals()
	tether_repaired.emit()


func apply_heat(amount: float) -> void:
	heat_amount = clampf(heat_amount + maxf(amount, 0.0), 0.0, 1.0)
	cold_amount = maxf(0.0, cold_amount - amount * 0.65)


func apply_cold(amount: float) -> void:
	cold_amount = clampf(cold_amount + maxf(amount, 0.0), 0.0, 1.0)
	heat_amount = maxf(0.0, heat_amount - amount * 0.65)


func cut() -> void:
	_break_tether("cut")


func get_effective_break_strength() -> float:
	if material_profile == null:
		return 1.0
	return material_profile.effective_break_strength(heat_amount, cold_amount, burn_progress)


func get_debug_data() -> Dictionary:
	return {
		"material": material_profile.material_id if material_profile != null else "missing",
		"rest_length": rest_length,
		"straight_distance": _straight_distance(),
		"tension": current_tension,
		"peak_tension": peak_tension,
		"effective_break_strength": get_effective_break_strength(),
		"heat": heat_amount,
		"cold": cold_amount,
		"burn_progress": burn_progress,
		"conductive": material_profile.conductive if material_profile != null else false,
		"broken": is_broken,
		"break_reason": break_reason,
	}


func _initialize_points() -> void:
	_points = PackedVector3Array()
	_previous_points = PackedVector3Array()
	if not _endpoints_are_valid():
		return
	var point_total := maxi(segment_count + 1, 4)
	var point_a := _endpoint_a.global_position
	var point_b := _endpoint_b.global_position
	for index: int in range(point_total):
		var weight := float(index) / float(point_total - 1)
		var point := point_a.lerp(point_b, weight)
		var sag := sin(weight * PI) * _available_slack() * 0.72
		point.y -= sag
		_points.append(point)
		_previous_points.append(point)


func _simulate_segments(delta: float) -> void:
	if _points.size() < 4:
		_initialize_points()
		return
	var point_total := _points.size()
	var last_index := point_total - 1
	var gravity_step := Vector3.DOWN * 9.8 * gravity_scale * delta * delta

	for index: int in range(1, last_index):
		var point := _points[index]
		var velocity := (point - _previous_points[index]) * verlet_damping
		_previous_points[index] = point
		_points[index] = point + velocity + gravity_step

	_points[0] = _endpoint_a.global_position
	if not is_broken:
		_points[last_index] = _endpoint_b.global_position
	else:
		var loose_velocity := (_points[last_index] - _previous_points[last_index]) * verlet_damping
		_previous_points[last_index] = _points[last_index]
		_points[last_index] += loose_velocity + gravity_step

	var target_segment_length := rest_length / float(last_index)
	for iteration: int in range(constraint_iterations):
		_points[0] = _endpoint_a.global_position
		if not is_broken:
			_points[last_index] = _endpoint_b.global_position
		for index: int in range(last_index):
			if is_broken and index == _broken_segment_index:
				continue
			var point_a := _points[index]
			var point_b := _points[index + 1]
			var offset := point_b - point_a
			var distance := offset.length()
			if distance <= 0.0001:
				continue
			var correction := offset * ((distance - target_segment_length) / distance)
			var a_is_pinned := index == 0
			var b_is_pinned := index + 1 == last_index and not is_broken
			if a_is_pinned:
				_points[index + 1] -= correction
			elif b_is_pinned:
				_points[index] += correction
			else:
				_points[index] += correction * 0.5
				_points[index + 1] -= correction * 0.5


func _update_tension() -> void:
	if is_broken or material_profile == null or not _endpoints_are_valid():
		current_tension = 0.0
		return
	var offset := _endpoint_b.global_position - _endpoint_a.global_position
	var distance := offset.length()
	var extension := maxf(distance - rest_length, 0.0)
	var relative_speed := 0.0
	if distance > 0.0001:
		relative_speed = (_endpoint_velocity(_endpoint_b) - _endpoint_velocity(_endpoint_a)).dot(offset / distance)
	var stiffness := material_profile.effective_stiffness(cold_amount)
	current_tension = maxf(extension * stiffness + maxf(relative_speed, 0.0) * material_profile.tension_damping, 0.0)
	peak_tension = maxf(peak_tension, current_tension)
	if current_tension > get_effective_break_strength():
		_break_tether("overload")


func _apply_tension_forces() -> void:
	if not apply_endpoint_forces or current_tension <= 0.0:
		return
	var offset := _endpoint_b.global_position - _endpoint_a.global_position
	if offset.length_squared() <= 0.0001:
		return
	var force := offset.normalized() * current_tension
	_apply_force_to_endpoint(_endpoint_a, force)
	_apply_force_to_endpoint(_endpoint_b, -force)


func _apply_force_to_endpoint(endpoint: Node3D, force: Vector3) -> void:
	if endpoint is RigidBody3D:
		(endpoint as RigidBody3D).apply_central_force(force)
	elif endpoint.has_method("apply_tether_force"):
		endpoint.call("apply_tether_force", force)


func _endpoint_velocity(endpoint: Node3D) -> Vector3:
	if endpoint is RigidBody3D:
		return (endpoint as RigidBody3D).linear_velocity
	if endpoint is CharacterBody3D:
		return (endpoint as CharacterBody3D).velocity
	var value: Variant = endpoint.get("velocity")
	return value if value is Vector3 else Vector3.ZERO


func _update_material_state(delta: float) -> void:
	if material_profile == null:
		return
	if material_profile.is_ignited(heat_amount) and not is_broken:
		burn_progress = clampf(burn_progress + material_profile.burn_rate * delta, 0.0, 1.0)
		heat_amount = clampf(heat_amount + delta * 0.04, 0.0, 1.0)
		if burn_progress >= 1.0:
			_break_tether("burned")


func _break_tether(reason: String) -> void:
	if is_broken:
		return
	is_broken = true
	break_reason = reason
	current_tension = 0.0
	_broken_segment_index = maxi(1, int(float(_points.size() - 1) / 2.0))
	tether_broken.emit(reason, peak_tension)


func _create_visuals() -> void:
	for segment: MeshInstance3D in _segments:
		segment.queue_free()
	_segments.clear()
	_visual_material = StandardMaterial3D.new()
	_visual_material.vertex_color_use_as_albedo = false
	var count := maxi(segment_count, 3)
	for index: int in range(count):
		var segment := MeshInstance3D.new()
		segment.name = "FlexibleSegment%02d" % index
		if material_profile != null and material_profile.visual_style == FlexibleMaterialProfile.VisualStyle.CHAIN:
			var link := TorusMesh.new()
			link.inner_radius = maxf(material_profile.radius * 1.35, 0.045)
			link.outer_radius = maxf(material_profile.radius * 2.6, 0.1)
			link.rings = 10
			link.ring_segments = 6
			segment.mesh = link
		else:
			var strand := CylinderMesh.new()
			var radius := material_profile.radius if material_profile != null else 0.05
			strand.top_radius = radius
			strand.bottom_radius = radius
			strand.height = 1.0
			strand.radial_segments = 8
			segment.mesh = strand
		segment.material_override = _visual_material
		add_child(segment)
		_segments.append(segment)
	_update_visual_material()


func _update_visuals() -> void:
	if _points.size() < 2:
		return
	if _segments.size() != _points.size() - 1:
		_create_visuals()
	for index: int in range(_segments.size()):
		var segment := _segments[index]
		if is_broken and index == _broken_segment_index:
			segment.visible = false
			continue
		segment.visible = true
		var point_a := _points[index]
		var point_b := _points[index + 1]
		var offset := point_b - point_a
		var length := offset.length()
		if length <= 0.0001:
			segment.visible = false
			continue
		segment.global_position = point_a.lerp(point_b, 0.5)
		if material_profile != null and material_profile.visual_style == FlexibleMaterialProfile.VisualStyle.CHAIN:
			var direction := offset / length
			var normal := direction.cross(Vector3.UP if index % 2 == 0 else Vector3.RIGHT).normalized()
			if normal.length_squared() <= 0.001:
				normal = Vector3.FORWARD
			segment.quaternion = Quaternion(Vector3.UP, normal)
			var nominal_diameter := maxf(material_profile.radius * 5.2, 0.2)
			segment.scale = Vector3.ONE * maxf(length / nominal_diameter, 0.72)
		else:
			segment.quaternion = Quaternion(Vector3.UP, offset / length)
			segment.scale = Vector3(1.0, length, 1.0)
	_update_visual_material()


func _update_visual_material() -> void:
	if _visual_material == null:
		return
	var base_color := material_profile.base_color if material_profile != null else Color.WHITE
	if cold_amount > 0.0 and material_profile != null:
		base_color = base_color.lerp(material_profile.frozen_color, cold_amount)
	if heat_amount > 0.0:
		base_color = base_color.lerp(Color(1.0, 0.22, 0.03, 1.0), heat_amount * 0.72)
	if debug_tension_color and material_profile != null and not is_broken:
		var ratio := clampf(current_tension / maxf(get_effective_break_strength(), 1.0), 0.0, 1.0)
		base_color = base_color.lerp(Color(1.0, 0.04, 0.02, 1.0), ratio)
	_visual_material.albedo_color = base_color
	_visual_material.metallic = material_profile.metallic if material_profile != null else 0.0
	_visual_material.roughness = material_profile.roughness if material_profile != null else 0.8
	var active_glow := maxf(heat_amount, clampf(current_tension / maxf(get_effective_break_strength(), 1.0), 0.0, 1.0) * 0.45)
	_visual_material.emission_enabled = active_glow > 0.02
	_visual_material.emission = base_color
	_visual_material.emission_energy_multiplier = active_glow * 2.0


func _straight_distance() -> float:
	return _endpoint_a.global_position.distance_to(_endpoint_b.global_position) if _endpoints_are_valid() else 0.0


func _available_slack() -> float:
	return maxf(rest_length - _straight_distance(), 0.0)
