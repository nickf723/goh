extends Node3D
class_name ControlledFlexibleLine3D

@export_range(3, 32, 1) var segment_count: int = 12
@export_range(0.01, 0.3, 0.005) var line_radius: float = 0.045
@export var metallic: float = 0.15
@export var roughness: float = 0.62

var points: Array[Vector3] = []
var _segments: Array[MeshInstance3D] = []
var _material: StandardMaterial3D


func _ready() -> void:
	_rebuild_visuals()


func configure(
	count: int,
	radius: float,
	color: Color,
	metallic_value: float = 0.15,
	roughness_value: float = 0.62
) -> void:
	segment_count = maxi(count, 3)
	line_radius = maxf(radius, 0.01)
	metallic = clampf(metallic_value, 0.0, 1.0)
	roughness = clampf(roughness_value, 0.0, 1.0)
	_ensure_material()
	_material.albedo_color = color
	_material.metallic = metallic
	_material.roughness = roughness
	_rebuild_visuals()


func set_color(color: Color, emission_strength: float = 0.0) -> void:
	_ensure_material()
	_material.albedo_color = color
	_material.metallic = metallic
	_material.roughness = roughness
	_material.emission_enabled = emission_strength > 0.001
	_material.emission = Color(color.r, color.g, color.b, 1.0)
	_material.emission_energy_multiplier = maxf(emission_strength, 0.0)


func set_points(new_points: Array[Vector3]) -> void:
	points.clear()
	for point: Vector3 in new_points:
		points.append(point)
	var needed_segments: int = maxi(points.size() - 1, 0)
	if _segments.size() != needed_segments:
		segment_count = maxi(needed_segments, 3)
		_rebuild_visuals()
	_update_visuals()


func get_points() -> Array[Vector3]:
	return points.duplicate()


func get_contact_samples(include_midpoints: bool = true) -> Array[Dictionary]:
	var samples: Array[Dictionary] = []
	if points.is_empty():
		return samples
	var denominator: float = maxf(float(points.size() - 1), 1.0)
	for index: int in range(points.size()):
		var fraction: float = float(index) / denominator
		samples.append({
			"position": points[index],
			"fraction": fraction,
		})
		if include_midpoints and index + 1 < points.size():
			samples.append({
				"position": points[index].lerp(points[index + 1], 0.5),
				"fraction": (float(index) + 0.5) / denominator,
			})
	return samples


func get_end_position() -> Vector3:
	return points.back() if not points.is_empty() else global_position


func _rebuild_visuals() -> void:
	for segment: MeshInstance3D in _segments:
		if is_instance_valid(segment):
			segment.queue_free()
	_segments.clear()
	_ensure_material()
	var count: int = maxi(segment_count, 3)
	for index: int in range(count):
		var segment := MeshInstance3D.new()
		segment.name = "ControlledSegment%02d" % index
		var mesh := CylinderMesh.new()
		mesh.top_radius = line_radius
		mesh.bottom_radius = line_radius
		mesh.height = 1.0
		mesh.radial_segments = 8
		segment.mesh = mesh
		segment.material_override = _material
		add_child(segment)
		_segments.append(segment)
	_update_visuals()


func _ensure_material() -> void:
	if _material != null:
		return
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(0.35, 0.28, 0.2, 1.0)
	_material.metallic = metallic
	_material.roughness = roughness


func _update_visuals() -> void:
	for index: int in range(_segments.size()):
		var segment: MeshInstance3D = _segments[index]
		if index + 1 >= points.size():
			segment.visible = false
			continue
		var point_a: Vector3 = points[index]
		var point_b: Vector3 = points[index + 1]
		var offset: Vector3 = point_b - point_a
		var length: float = offset.length()
		if length <= 0.0001:
			segment.visible = false
			continue
		segment.visible = true
		segment.global_position = point_a.lerp(point_b, 0.5)
		segment.quaternion = Quaternion(Vector3.UP, offset / length)
		segment.scale = Vector3(1.0, length, 1.0)
