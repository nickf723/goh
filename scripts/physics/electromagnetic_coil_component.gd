extends CircuitComponent
class_name ElectromagneticCoilComponent

@export var magnetic_field_path: NodePath = NodePath("MagneticField")
@export var field_strength_per_amp: float = 4.0
@export var minimum_activation_amps: float = 0.05
@export var maximum_base_strength: float = 18.0


func _ready() -> void:
	component_kind = "electromagnetic_coil"
	super._ready()
	update_magnetic_field()


func get_magnetic_field() -> MagneticDipoleField:
	return get_node_or_null(magnetic_field_path) as MagneticDipoleField


func _on_circuit_state_applied() -> void:
	update_magnetic_field()


func update_magnetic_field() -> void:
	var magnetic_field: MagneticDipoleField = get_magnetic_field()
	if magnetic_field == null:
		return
	var current_magnitude: float = abs(signed_current_amps)
	magnetic_field.active = energized and current_magnitude >= minimum_activation_amps
	magnetic_field.base_strength = clamp(
		current_magnitude * max(field_strength_per_amp, 0.0),
		0.0,
		max(maximum_base_strength, 0.0)
	)
	magnetic_field.polarity = 1.0 if signed_current_amps >= 0.0 else -1.0


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	var magnetic_field: MagneticDipoleField = get_magnetic_field()
	data["magnetic_field"] = magnetic_field.get_debug_data() if magnetic_field != null else {}
	return data
