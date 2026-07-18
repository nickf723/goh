extends SpatialVectorField
class_name MagneticDipoleField

@export var local_moment_axis: Vector3 = Vector3.RIGHT
@export var polarity: float = 1.0
@export var maximum_field_strength: float = 18.0


func _ready() -> void:
	field_kind = "magnetic"
	super._ready()


func sample_field(world_position: Vector3) -> Dictionary:
	var offset: Vector3 = world_position - global_position
	var distance: float = offset.length()
	var field_vector: Vector3 = Vector3.ZERO

	if active and distance <= maximum_distance:
		var safe_distance: float = max(distance, minimum_distance)
		var radial_direction: Vector3 = offset.normalized() if distance > 0.001 else Vector3.UP
		var world_moment: Vector3 = get_world_moment()
		var dipole_shape: Vector3 = (
			3.0 * radial_direction * world_moment.dot(radial_direction)
			- world_moment
		)
		var magnitude_scale: float = abs(base_strength) / pow(
			safe_distance,
			max(falloff_power, 0.0)
		)
		field_vector = dipole_shape * magnitude_scale
		if field_vector.length() > maximum_field_strength:
			field_vector = field_vector.normalized() * maximum_field_strength

	return record_sample(world_position, field_vector, distance)


func get_world_moment() -> Vector3:
	var axis: Vector3 = local_moment_axis
	if axis.length() <= 0.001:
		axis = Vector3.RIGHT
	return (global_basis * axis.normalized()) * signf(polarity) * signf(base_strength)


func reverse_polarity() -> void:
	polarity *= -1.0


func reverse_field() -> void:
	reverse_polarity()


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["polarity"] = polarity
	data["moment"] = get_world_moment()
	data["maximum_field_strength"] = maximum_field_strength
	return data
