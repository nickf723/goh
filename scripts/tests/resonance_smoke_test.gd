extends Node

const LabScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_resonance_lab_v1.tscn"
)
const PulseScene: PackedScene = preload(
	"res://scenes/abilities/resonant_pulse.tscn"
)
const ResonantPulseAbility: AbilityDefinition = preload(
	"res://data/abilities/resonant_pulse_ability.tres"
)
const LabLoadout: AbilityLoadout = preload(
	"res://data/loadouts/grace_resonance_lab_loadout.tres"
)

var failures: Array[String] = []


func _ready() -> void:
	validate_frequency_response()
	await validate_accumulation_and_thresholds()
	await validate_sympathetic_coupling()
	await validate_pulse_delivery()
	await validate_laboratory_contract()
	if failures.is_empty():
		print("RESONANCE_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("RESONANCE_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func validate_frequency_response() -> void:
	var body: ResonantBody3D = ResonantBody3D.new()
	body.natural_frequency_hz = 220.0
	body.bandwidth_hz = 12.0
	var exact: float = body.get_frequency_response(220.0)
	var near: float = body.get_frequency_response(228.0)
	var wrong: float = body.get_frequency_response(440.0)
	if exact < 0.999:
		failures.append("exact natural frequency must produce full response")
	if near <= wrong:
		failures.append("frequency response must decrease with detuning")
	if wrong > 0.001:
		failures.append("distant frequencies must not materially excite a narrow resonator")
	body.queue_free()


func validate_accumulation_and_thresholds() -> void:
	var owner: Node3D = Node3D.new()
	owner.name = "ActivationOwner"
	add_child(owner)
	var body: ResonantBody3D = ResonantBody3D.new()
	body.natural_frequency_hz = 440.0
	body.bandwidth_hz = 10.0
	body.energy_capacity = 30.0
	body.threshold_energy = 10.0
	body.threshold_mode = ResonantBody3D.ThresholdMode.ACTIVATE
	body.damping_per_second = 0.2
	owner.add_child(body)
	await get_tree().process_frame
	body.receive_frequency(440.0, 6.0, "first pulse")
	if body.activated_state:
		failures.append("one sub-threshold pulse must not activate a resonator")
	body.receive_frequency(440.0, 6.0, "second pulse")
	if not body.activated_state:
		failures.append("matching pulses must accumulate across casts and activate")
	var accumulated: float = body.current_energy
	body.step_resonance(1.0)
	if body.current_energy >= accumulated:
		failures.append("resonance energy must decay according to damping")

	var fracture_owner: Node3D = Node3D.new()
	fracture_owner.name = "FractureOwner"
	add_child(fracture_owner)
	var fracture_body: ResonantBody3D = ResonantBody3D.new()
	fracture_body.natural_frequency_hz = 660.0
	fracture_body.threshold_energy = 5.0
	fracture_body.threshold_mode = ResonantBody3D.ThresholdMode.FRACTURE
	fracture_owner.add_child(fracture_body)
	await get_tree().process_frame
	fracture_body.receive_frequency(660.0, 7.0, "fracture pulse")
	if not fracture_body.fractured_state:
		failures.append("fracture-mode resonator must fail above threshold")
	owner.queue_free()
	fracture_owner.queue_free()
	await get_tree().process_frame


func validate_sympathetic_coupling() -> void:
	var primary_owner: Node3D = Node3D.new()
	primary_owner.name = "PrimaryOwner"
	primary_owner.position = Vector3.ZERO
	add_child(primary_owner)
	var primary: ResonantBody3D = ResonantBody3D.new()
	primary.natural_frequency_hz = 220.0
	primary.coupling_group = "smoke_pair"
	primary.coupling_radius = 5.0
	primary.coupling_efficiency = 0.8
	primary.propagation_threshold = 2.0
	primary_owner.add_child(primary)

	var secondary_owner: Node3D = Node3D.new()
	secondary_owner.name = "SecondaryOwner"
	secondary_owner.position = Vector3(2.0, 0.0, 0.0)
	add_child(secondary_owner)
	var secondary: ResonantBody3D = ResonantBody3D.new()
	secondary.natural_frequency_hz = 220.0
	secondary.coupling_group = "smoke_pair"
	secondary.coupling_radius = 5.0
	secondary.propagation_threshold = 100.0
	secondary_owner.add_child(secondary)
	await get_tree().process_frame
	primary.receive_frequency(220.0, 10.0, "direct pulse", true)
	if secondary.current_energy <= 0.1:
		failures.append("matched nearby resonators must receive sympathetic energy")
	if secondary.last_source_name.find("sympathetic transfer") < 0:
		failures.append("coupled energy must identify its sympathetic source")
	primary_owner.queue_free()
	secondary_owner.queue_free()
	await get_tree().process_frame


func validate_pulse_delivery() -> void:
	var target_owner: Node3D = Node3D.new()
	target_owner.name = "PulseTargetOwner"
	target_owner.position = Vector3(2.0, 0.0, 0.0)
	add_child(target_owner)
	var target: ResonantBody3D = ResonantBody3D.new()
	target.natural_frequency_hz = 110.0
	target.bandwidth_hz = 10.0
	target_owner.add_child(target)
	var source: Node3D = Node3D.new()
	source.name = "PulseSource"
	source.position = Vector3.ZERO
	add_child(source)
	await get_tree().process_frame
	var pulse: ResonantPulse = PulseScene.instantiate() as ResonantPulse
	var payload: ResonancePayload = ResonancePayload.new()
	payload.frequency_hz = 110.0
	payload.energy = 12.0
	payload.radius = 5.0
	pulse.set_payload(payload)
	add_child(pulse)
	pulse.execute(source, Vector3.FORWARD)
	if target.current_energy <= 0.1:
		failures.append("Resonant Pulse must deliver its payload to resonant bodies in range")
	if pulse.affected_body_ids.size() <= 0:
		failures.append("Resonant Pulse must report materially excited resonators")
	target_owner.queue_free()
	source.queue_free()
	pulse.queue_free()
	await get_tree().process_frame


func validate_laboratory_contract() -> void:
	if not LabLoadout.knows_ability(ResonantPulseAbility):
		failures.append("resonance lab loadout is missing Resonant Pulse")
	if not (ResonantPulseAbility.get_action_payload() is ResonancePayload):
		failures.append("Resonant Pulse must use a ResonancePayload")
	var lab: Node = LabScene.instantiate()
	if lab == null:
		failures.append("Resonance Laboratory failed to instantiate")
		return
	add_child(lab)
	await get_tree().process_frame
	await get_tree().physics_frame
	var body_count: int = 0
	for node: Node in get_tree().get_nodes_in_group("resonant_bodies"):
		if lab.is_ancestor_of(node):
			body_count += 1
	if body_count < 12:
		failures.append("laboratory must contain selective, coupled, gate, and fracture resonators")
	if lab.get_node_or_null("ResonantGate") == null:
		failures.append("laboratory is missing its frequency-activated gate")
	if lab.get_node_or_null("GlassShard1") == null:
		failures.append("laboratory is missing its 660 Hz fracture cluster")
	if lab.get_node_or_null("ResonanceHUD/Panel/Margin/Readout") == null:
		failures.append("laboratory is missing its compact resonance readout")
	var debug_data: Dictionary = lab.call("get_debug_data") as Dictionary
	if int(debug_data.get("resonant_bodies", 0)) < 12:
		failures.append("laboratory debug contract must report its resonators")
	if int(round(float(debug_data.get("active_frequency_hz", 0.0)))) != 220:
		failures.append("laboratory must begin tuned to 220 Hz")
	lab.queue_free()
	await get_tree().process_frame

