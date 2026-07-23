extends Node3D
class_name GasEmitter3D

@export var emitter_id: String = "gas_emitter"
@export var gas_id: String = "gas"
@export var active: bool = true
@export_range(0.0, 20.0, 0.01) var emission_rate_per_second: float = 1.2
@export_range(0.05, 10.0, 0.05) var emission_radius: float = 1.25
@export_range(0.0, 1.0, 0.01) var center_bias: float = 0.45
@export var pulse_frequency: float = 0.0
@export_range(0.0, 1.0, 0.01) var pulse_depth: float = 0.0
@export var resettable: bool = true

var elapsed: float = 0.0
var initial_active: bool = true


func _ready() -> void:
	add_to_group("gas_emitters")
	add_to_group("debuggable")
	if resettable:
		add_to_group("lab_resettable")
	initial_active = active
	if emitter_id.strip_edges() == "":
		emitter_id = name


func _process(delta: float) -> void:
	elapsed += max(delta, 0.0)


func get_emission_amount(delta: float) -> float:
	if not active:
		return 0.0
	var pulse_multiplier: float = 1.0
	if pulse_frequency > 0.001 and pulse_depth > 0.001:
		pulse_multiplier += sin(elapsed * TAU * pulse_frequency) * pulse_depth
	return max(emission_rate_per_second, 0.0) * max(delta, 0.0) * max(pulse_multiplier, 0.0)


func matches_gas(requested_gas_id: String) -> bool:
	return gas_id == requested_gas_id


func set_emitting(value: bool) -> void:
	active = value


func reset_target() -> void:
	active = initial_active
	elapsed = 0.0


func get_debug_data() -> Dictionary:
	return {
		"gas_emitter": emitter_id,
		"gas_id": gas_id,
		"active": active,
		"rate": snapped(emission_rate_per_second, 0.01),
		"radius": snapped(emission_radius, 0.01),
		"position": global_position,
	}
