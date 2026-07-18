extends CircuitVoltageSource
class_name CircuitExcitationPort

signal excitation_started(excitation: ElectricalExcitation)
signal excitation_ended(source_id: String)

@export var accepted_elements: Array[String] = ["lightning"]
@export var accepted_tags: Array[String] = ["lightning", "shock", "electrical"]
@export var default_voltage_volts: float = 48.0
@export var default_duration_seconds: float = 0.45
@export var default_source_resistance_ohms: float = 0.6
@export var default_current_limit_amps: float = 14.0
@export var retain_polarity_between_pulses: bool = true

var pulse_timer: float = 0.0
var active_excitation: ElectricalExcitation
var last_excitation_source: String = "none"
var accepted_pulse_count: int = 0
var rejected_pulse_count: int = 0


func _ready() -> void:
	nominal_voltage_volts = 0.0
	source_internal_resistance_ohms = max(default_source_resistance_ohms, 0.001)
	max_current_amps = max(default_current_limit_amps, 0.001)
	initial_polarity = 1 if initial_polarity >= 0 else -1
	super._ready()
	add_to_group("electrical_excitation_ports")
	add_to_group("lab_resettable")


func _process(delta: float) -> void:
	if pulse_timer <= 0.0:
		return
	pulse_timer -= delta
	if pulse_timer <= 0.0:
		clear_excitation()


func accepts_payload(payload: DamagePayload) -> bool:
	if payload == null:
		return false
	var normalized_element: String = payload.element.to_lower().strip_edges()
	for accepted_element: String in accepted_elements:
		if normalized_element == accepted_element.to_lower().strip_edges():
			return true
	for raw_tag: String in payload.tags:
		var normalized_tag: String = raw_tag.to_lower().strip_edges()
		for accepted_tag: String in accepted_tags:
			if normalized_tag == accepted_tag.to_lower().strip_edges():
				return true
	return false


func receive_damage_payload(payload: DamagePayload) -> Dictionary:
	if not accepts_payload(payload):
		rejected_pulse_count += 1
		return {
			"message": (payload.source_name if payload != null else "Unknown source") + " does not provide compatible electrical excitation.",
			"objective": "Strike the input with Lightning or connect another electrical source.",
		}

	var excitation := ElectricalExcitation.from_payload(
		payload,
		default_voltage_volts,
		default_duration_seconds,
		default_source_resistance_ohms,
		default_current_limit_amps,
		polarity_sign
	)
	apply_excitation(excitation)
	return {
		"message": excitation.source_id + " energizes " + display_name + " for " + str(snapped(excitation.duration_seconds, 0.01)) + " s.",
		"objective": "Use transient electricity to power the same loads as the battery.",
	}


func apply_excitation(excitation: ElectricalExcitation) -> void:
	if excitation == null:
		return
	active_excitation = excitation
	pulse_timer = max(excitation.duration_seconds, 0.02)
	last_excitation_source = excitation.source_id
	accepted_pulse_count += 1
	polarity_sign = 1 if excitation.polarity_sign >= 0 else -1
	nominal_voltage_volts = abs(excitation.voltage_volts)
	source_internal_resistance_ohms = max(excitation.source_resistance_ohms, 0.001)
	max_current_amps = max(excitation.current_limit_amps, 0.001)
	refresh_voltage()
	notify_topology_changed()
	excitation_started.emit(excitation)


func clear_excitation() -> void:
	var ended_source: String = last_excitation_source
	pulse_timer = 0.0
	active_excitation = null
	nominal_voltage_volts = 0.0
	source_voltage_volts = 0.0
	apply_circuit_state(false, 0.0, 0.0, -1)
	notify_topology_changed()
	if ended_source != "none":
		excitation_ended.emit(ended_source)


func reverse_polarity() -> void:
	polarity_sign *= -1
	if active_excitation != null:
		active_excitation.polarity_sign = polarity_sign
	refresh_voltage()
	notify_topology_changed()


func interact() -> Dictionary:
	reverse_polarity()
	return {
		"message": display_name + " input polarity reversed.",
		"objective": "Pulse the input with Lightning and observe current direction.",
	}


func reset_target() -> void:
	clear_excitation()
	polarity_sign = 1 if initial_polarity >= 0 else -1
	last_excitation_source = "none"
	accepted_pulse_count = 0
	rejected_pulse_count = 0
	if not retain_polarity_between_pulses:
		refresh_voltage()


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["excitation_active"] = pulse_timer > 0.0
	data["pulse_remaining"] = snapped(max(pulse_timer, 0.0), 0.01)
	data["last_excitation_source"] = last_excitation_source
	data["accepted_pulses"] = accepted_pulse_count
	data["rejected_pulses"] = rejected_pulse_count
	data["excitation"] = active_excitation.get_debug_data() if active_excitation != null else {}
	return data
