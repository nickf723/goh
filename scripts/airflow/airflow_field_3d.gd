extends Node3D
class_name AirflowField3D

enum FieldKind {
	DIRECTIONAL,
	RADIAL,
	VORTEX,
	UPDRAFT,
	DOWNDRAFT,
}

enum VolumeShape {
	BOX,
	SPHERE,
	CYLINDER,
}

@export var field_id: String = "airflow_field"
@export var active: bool = true
@export var field_kind: FieldKind = FieldKind.DIRECTIONAL
@export var volume_shape: VolumeShape = VolumeShape.BOX

@export_group("Field Geometry")
@export var box_extents: Vector3 = Vector3(4.0, 3.0, 4.0)
@export var radius: float = 5.0
@export var cylinder_height: float = 8.0
@export_range(0.0, 1.0, 0.01) var edge_fade_fraction: float = 0.2
@export_range(0.1, 6.0, 0.1) var falloff_exponent: float = 1.0

@export_group("Vector Function")
@export var local_direction: Vector3 = Vector3.FORWARD
@export var local_axis: Vector3 = Vector3.UP
@export var strength: float = 8.0
@export_range(0.0, 2.0, 0.01) var vortex_inward_fraction: float = 0.18
@export_range(-2.0, 2.0, 0.01) var vortex_vertical_fraction: float = 0.08

@export_group("Turbulence")
@export var turbulence_strength: float = 0.0
@export var turbulence_spatial_frequency: float = 0.55
@export var turbulence_time_frequency: float = 1.2

var elapsed: float = 0.0


func _ready() -> void:
	add_to_group("airflow_fields")
	add_to_group("debuggable")
	if field_id.strip_edges() == "":
		field_id = name


func _process(delta: float) -> void:
	elapsed += max(delta, 0.0)


func sample_air_velocity(world_position: Vector3, sample_time: float = -1.0) -> Vector3:
	if not active:
		return Vector3.ZERO
	var local_position: Vector3 = to_local(world_position)
	var weight: float = get_volume_weight(local_position)
	if weight <= 0.0:
		return Vector3.ZERO

	var world_axis: Vector3 = global_transform.basis * safe_normalized(local_axis, Vector3.UP)
	world_axis = safe_normalized(world_axis, Vector3.UP)
	var world_direction: Vector3 = global_transform.basis * safe_normalized(local_direction, Vector3.FORWARD)
	world_direction = safe_normalized(world_direction, -global_transform.basis.z)
	var base_velocity: Vector3 = Vector3.ZERO

	match field_kind:
		FieldKind.DIRECTIONAL:
			base_velocity = world_direction * strength
		FieldKind.RADIAL:
			var radial: Vector3 = world_position - global_position
			base_velocity = safe_normalized(radial, world_direction) * strength
		FieldKind.VORTEX:
			var offset: Vector3 = world_position - global_position
			var axial_offset: Vector3 = world_axis * offset.dot(world_axis)
			var radial_offset: Vector3 = offset - axial_offset
			var radial_direction: Vector3 = safe_normalized(radial_offset, global_transform.basis.x)
			var tangent: Vector3 = safe_normalized(world_axis.cross(radial_direction), world_direction)
			base_velocity = (
				tangent
				- radial_direction * vortex_inward_fraction
				+ world_axis * vortex_vertical_fraction
			) * strength
		FieldKind.UPDRAFT:
			base_velocity = world_axis * strength
		FieldKind.DOWNDRAFT:
			base_velocity = -world_axis * strength

	var resolved_time: float = elapsed if sample_time < 0.0 else sample_time
	var turbulence: Vector3 = sample_turbulence(world_position, resolved_time)
	return (base_velocity + turbulence) * weight


func get_volume_weight(local_position: Vector3) -> float:
	var normalized_distance: float = 2.0
	match volume_shape:
		VolumeShape.BOX:
			var safe_extents := Vector3(
				max(abs(box_extents.x), 0.01),
				max(abs(box_extents.y), 0.01),
				max(abs(box_extents.z), 0.01)
			)
			normalized_distance = max(
				abs(local_position.x) / safe_extents.x,
				max(
					abs(local_position.y) / safe_extents.y,
					abs(local_position.z) / safe_extents.z
				)
			)
		VolumeShape.SPHERE:
			normalized_distance = local_position.length() / max(radius, 0.01)
		VolumeShape.CYLINDER:
			var radial_distance: float = Vector2(local_position.x, local_position.z).length() / max(radius, 0.01)
			var vertical_distance: float = abs(local_position.y) / max(cylinder_height * 0.5, 0.01)
			normalized_distance = max(radial_distance, vertical_distance)

	if normalized_distance >= 1.0:
		return 0.0
	var fade_fraction: float = clampf(edge_fade_fraction, 0.0, 1.0)
	if fade_fraction <= 0.001:
		return 1.0
	var fade_start: float = 1.0 - fade_fraction
	if normalized_distance <= fade_start:
		return 1.0
	var raw_weight: float = clampf((1.0 - normalized_distance) / fade_fraction, 0.0, 1.0)
	var smooth_weight: float = raw_weight * raw_weight * (3.0 - 2.0 * raw_weight)
	return pow(smooth_weight, max(falloff_exponent, 0.1))


func sample_turbulence(world_position: Vector3, sample_time: float) -> Vector3:
	if turbulence_strength <= 0.001:
		return Vector3.ZERO
	var frequency: float = max(turbulence_spatial_frequency, 0.01)
	var time_value: float = sample_time * turbulence_time_frequency
	var noise_vector := Vector3(
		sin((world_position.y + time_value) * frequency + 0.37),
		sin((world_position.z - time_value * 0.83) * frequency + 2.11),
		sin((world_position.x + time_value * 1.17) * frequency + 4.23)
	)
	return safe_normalized(noise_vector, Vector3.ZERO) * turbulence_strength


func safe_normalized(vector: Vector3, fallback: Vector3) -> Vector3:
	if vector.length() <= 0.001:
		return fallback.normalized() if fallback.length() > 0.001 else Vector3.ZERO
	return vector.normalized()


func get_debug_data() -> Dictionary:
	return {
		"airflow_field": field_id,
		"active": active,
		"kind": FieldKind.keys()[field_kind],
		"volume": VolumeShape.keys()[volume_shape],
		"strength": snapped(strength, 0.01),
		"turbulence": snapped(turbulence_strength, 0.01),
		"position": global_position,
	}
