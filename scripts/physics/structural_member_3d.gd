extends RigidBody3D
class_name StructuralMember3D

signal support_state_changed(is_supported: bool)

@export var structural_id: String = ""
@export_range(0.01, 10.0, 0.01) var authored_load_multiplier: float = 1.0
@export var starts_supported: bool = true

var supported: bool = true
var initial_transform: Transform3D
var initial_freeze: bool = true
var has_snapshot: bool = false


func _ready() -> void:
	if structural_id == "":
		structural_id = name.to_snake_case()
	initial_transform = global_transform
	initial_freeze = freeze
	has_snapshot = true
	supported = starts_supported
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = supported
	add_to_group("structural_members")
	add_to_group("debuggable")
	add_to_group("lab_resettable")


func set_supported(next_supported: bool, release_impulse: Vector3 = Vector3.ZERO) -> void:
	if supported == next_supported and freeze == next_supported:
		return
	supported = next_supported
	freeze = supported
	if supported:
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
	else:
		sleeping = false
		if release_impulse.length() > 0.001:
			apply_central_impulse(release_impulse)
	support_state_changed.emit(supported)


func reset_member() -> void:
	if not has_snapshot:
		return
	global_transform = initial_transform
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	sleeping = false
	supported = starts_supported
	freeze = starts_supported


func reset_target() -> void:
	reset_member()


func get_load_n() -> float:
	return mass * 9.81 * maxf(authored_load_multiplier, 0.01)


func get_debug_data() -> Dictionary:
	return {
		"structural_member": structural_id,
		"supported": supported,
		"mass_kg": snapped(mass, 0.01),
		"load_n": snapped(get_load_n(), 0.1),
		"velocity": linear_velocity,
	}
