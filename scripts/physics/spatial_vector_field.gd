extends Node3D
class_name SpatialVectorField

@export var field_id: String = "spatial_field"
@export var display_name: String = "Spatial Field"
@export var field_kind: String = "generic"
@export var active: bool = true
@export var maximum_distance: float = 8.0
@export var minimum_distance: float = 0.35
@export var base_strength: float = 1.0
@export var falloff_power: float = 2.0

var sample_count: int = 0
var last_sample_position: Vector3 = Vector3.ZERO
var last_sample_strength: float = 0.0


func _ready() -> void:
	add_to_group("physical_fields")
	add_to_group("debuggable")


func sample_field(world_position: Vector3) -> Dictionary:
	var offset: Vector3 = world_position - global_position
	var distance: float = offset.length()
	var field_vector: Vector3 = Vector3.ZERO

	if active and distance <= maximum_distance:
		var direction: Vector3 = offset.normalized() if distance > 0.001 else Vector3.UP
		var safe_distance: float = max(distance, minimum_distance)
		var strength: float = base_strength / pow(safe_distance, max(falloff_power, 0.0))
		field_vector = direction * strength

	return record_sample(world_position, field_vector, distance)


func record_sample(world_position: Vector3, field_vector: Vector3, distance: float) -> Dictionary:
	sample_count += 1
	last_sample_position = world_position
	last_sample_strength = field_vector.length()
	return {
		"field_id": field_id,
		"display_name": display_name,
		"kind": field_kind,
		"active": active,
		"vector": field_vector,
		"strength": field_vector.length(),
		"distance": distance,
		"source_position": global_position,
	}


func set_field_active(is_active: bool) -> void:
	active = is_active


func reverse_field() -> void:
	base_strength *= -1.0


func get_debug_data() -> Dictionary:
	return {
		"field_id": field_id,
		"field": display_name,
		"kind": field_kind,
		"active": active,
		"base_strength": snapped(base_strength, 0.01),
		"maximum_distance": snapped(maximum_distance, 0.01),
		"falloff_power": snapped(falloff_power, 0.01),
		"samples": sample_count,
		"last_sample_strength": snapped(last_sample_strength, 0.001),
		"last_sample_position": last_sample_position,
	}
