extends Node
class_name ResonantBody3D

signal resonance_received(
	frequency_hz: float,
	response: float,
	added_energy: float
)
signal energy_changed(current_energy: float, normalized_energy: float)
signal threshold_reached(mode: int, energy: float)
signal activated(resonant_body: ResonantBody3D)
signal fractured(resonant_body: ResonantBody3D)

enum ThresholdMode {
	NONE,
	ACTIVATE,
	FRACTURE,
}

@export var resonance_id: String = "resonant_body"
@export_range(20.0, 2000.0, 1.0) var natural_frequency_hz: float = 220.0
@export_range(1.0, 500.0, 1.0) var bandwidth_hz: float = 18.0
@export_range(0.0, 10.0, 0.05) var damping_per_second: float = 0.8
@export_range(1.0, 100.0, 0.5) var energy_capacity: float = 36.0
@export_range(0.0, 100.0, 0.5) var threshold_energy: float = 24.0
@export var threshold_mode: ThresholdMode = ThresholdMode.NONE

@export_group("Sympathetic Coupling")
@export var coupling_group: String = ""
@export_range(0.0, 20.0, 0.25) var coupling_radius: float = 4.5
@export_range(0.0, 1.0, 0.01) var coupling_efficiency: float = 0.42
@export_range(0.0, 100.0, 0.5) var propagation_threshold: float = 8.0

@export_group("Physical Response")
@export var visual_target_path: NodePath = NodePath("../Visual")
@export_range(0.0, 0.25, 0.005) var maximum_visual_displacement: float = 0.08
@export_range(0.0, 0.2, 0.005) var maximum_visual_scale_pulse: float = 0.055
@export_range(0.0, 20.0, 0.1) var rigid_body_impulse_scale: float = 0.18

var current_energy: float = 0.0
var peak_energy: float = 0.0
var last_frequency_hz: float = 0.0
var last_response: float = 0.0
var last_source_name: String = "none"
var activated_state: bool = false
var fractured_state: bool = false
var visual_target: Node3D = null
var visual_rest_position: Vector3 = Vector3.ZERO
var visual_rest_scale: Vector3 = Vector3.ONE
var visual_phase: float = 0.0


func _ready() -> void:
	add_to_group("resonant_bodies")
	add_to_group("debuggable")
	add_to_group("lab_resettable")
	resolve_visual_target()


func _process(delta: float) -> void:
	step_resonance(delta)


func resolve_visual_target() -> void:
	if visual_target != null and is_instance_valid(visual_target):
		return
	if visual_target_path.is_empty():
		return
	visual_target = get_node_or_null(visual_target_path) as Node3D
	if visual_target != null:
		visual_rest_position = visual_target.position
		visual_rest_scale = visual_target.scale


func step_resonance(delta: float) -> void:
	var safe_delta: float = maxf(delta, 0.0)
	if current_energy > 0.0:
		current_energy *= exp(-maxf(damping_per_second, 0.0) * safe_delta)
		if current_energy < 0.01:
			current_energy = 0.0
	update_visual_response(safe_delta)
	energy_changed.emit(current_energy, get_normalized_energy())


func receive_resonance(
	payload: ResonancePayload,
	distance: float = 0.0
) -> Dictionary:
	if payload == null or fractured_state:
		return {}
	var distance_factor: float = payload.get_distance_factor(distance)
	if distance_factor <= 0.0:
		return {}
	return receive_frequency(
		payload.frequency_hz,
		payload.energy * distance_factor,
		payload.source_name,
		true
	)


func receive_frequency(
	frequency_hz: float,
	available_energy: float,
	source_name: String = "resonance",
	allow_propagation: bool = true
) -> Dictionary:
	if fractured_state:
		return {}
	var response: float = get_frequency_response(frequency_hz)
	var added_energy: float = maxf(available_energy, 0.0) * response
	last_frequency_hz = frequency_hz
	last_response = response
	last_source_name = source_name
	current_energy = clampf(
		current_energy + added_energy,
		0.0,
		maxf(energy_capacity, 1.0)
	)
	peak_energy = maxf(peak_energy, current_energy)
	resonance_received.emit(frequency_hz, response, added_energy)
	energy_changed.emit(current_energy, get_normalized_energy())
	apply_rigid_body_response(added_energy)
	evaluate_threshold()
	if (
		allow_propagation
		and not fractured_state
		and current_energy >= propagation_threshold
	):
		propagate_resonance()
	return {
		"resonance_id": resonance_id,
		"frequency_hz": frequency_hz,
		"natural_frequency_hz": natural_frequency_hz,
		"response": response,
		"added_energy": added_energy,
		"energy": current_energy,
		"activated": activated_state,
		"fractured": fractured_state,
	}


func get_frequency_response(frequency_hz: float) -> float:
	var safe_bandwidth: float = maxf(bandwidth_hz, 0.1)
	var detuning: float = absf(frequency_hz - natural_frequency_hz)
	var normalized_detuning: float = detuning / safe_bandwidth
	return exp(-0.5 * normalized_detuning * normalized_detuning)


func propagate_resonance() -> void:
	if coupling_group == "" or coupling_radius <= 0.0:
		return
	var owner_position: Vector3 = get_owner_position()
	var transfer_energy: float = current_energy * clampf(
		coupling_efficiency,
		0.0,
		1.0
	)
	if transfer_energy <= 0.0:
		return
	for candidate: Node in get_tree().get_nodes_in_group("resonant_bodies"):
		if candidate == self or not (candidate is ResonantBody3D):
			continue
		var other: ResonantBody3D = candidate as ResonantBody3D
		if other.coupling_group != coupling_group:
			continue
		var distance: float = owner_position.distance_to(other.get_owner_position())
		if distance > coupling_radius:
			continue
		var distance_factor: float = 1.0 - clampf(
			distance / maxf(coupling_radius, 0.01),
			0.0,
			1.0
		)
		other.receive_frequency(
			last_frequency_hz,
			transfer_energy * distance_factor,
			resonance_id + " sympathetic transfer",
			false
		)


func evaluate_threshold() -> void:
	if threshold_mode == ThresholdMode.NONE:
		return
	if current_energy < threshold_energy:
		return
	if threshold_mode == ThresholdMode.ACTIVATE and not activated_state:
		activated_state = true
		threshold_reached.emit(threshold_mode, current_energy)
		activated.emit(self)
	elif threshold_mode == ThresholdMode.FRACTURE and not fractured_state:
		fractured_state = true
		threshold_reached.emit(threshold_mode, current_energy)
		fractured.emit(self)


func apply_rigid_body_response(added_energy: float) -> void:
	var owner_node: Node = get_parent()
	if not (owner_node is RigidBody3D):
		return
	var rigid_body: RigidBody3D = owner_node as RigidBody3D
	if rigid_body.freeze or added_energy <= 0.0:
		return
	var impulse: Vector3 = Vector3(
		sin(last_frequency_hz * 0.013),
		0.35,
		cos(last_frequency_hz * 0.017)
	).normalized() * added_energy * rigid_body_impulse_scale
	rigid_body.apply_central_impulse(impulse)
	rigid_body.apply_torque_impulse(
		Vector3.UP * added_energy * rigid_body_impulse_scale * 0.35
	)


func update_visual_response(delta: float) -> void:
	resolve_visual_target()
	if visual_target == null:
		return
	var normalized_energy: float = get_normalized_energy()
	var display_frequency: float = clampf(
		maxf(last_frequency_hz, natural_frequency_hz) / 32.0,
		2.0,
		18.0
	)
	visual_phase = fmod(
		visual_phase + delta * TAU * display_frequency,
		TAU
	)
	var wave: float = sin(visual_phase)
	visual_target.position = (
		visual_rest_position
		+ Vector3.RIGHT * wave * maximum_visual_displacement * normalized_energy
	)
	visual_target.scale = visual_rest_scale * (
		1.0 + wave * maximum_visual_scale_pulse * normalized_energy
	)


func get_owner_position() -> Vector3:
	var owner_node: Node = get_parent()
	if owner_node is Node3D:
		return (owner_node as Node3D).global_position
	return Vector3.ZERO


func get_normalized_energy() -> float:
	return clampf(current_energy / maxf(energy_capacity, 0.01), 0.0, 1.0)


func reset_resonance() -> void:
	current_energy = 0.0
	peak_energy = 0.0
	last_frequency_hz = 0.0
	last_response = 0.0
	last_source_name = "reset"
	activated_state = false
	fractured_state = false
	resolve_visual_target()
	if visual_target != null:
		visual_target.position = visual_rest_position
		visual_target.scale = visual_rest_scale


func reset_target() -> void:
	reset_resonance()


func get_debug_data() -> Dictionary:
	return {
		"resonance_id": resonance_id,
		"natural_hz": natural_frequency_hz,
		"last_hz": last_frequency_hz,
		"response": snappedf(last_response, 0.001),
		"energy": snappedf(current_energy, 0.01),
		"peak_energy": snappedf(peak_energy, 0.01),
		"normalized_energy": snappedf(get_normalized_energy(), 0.01),
		"source": last_source_name,
		"coupling_group": coupling_group,
		"activated": activated_state,
		"fractured": fractured_state,
	}
