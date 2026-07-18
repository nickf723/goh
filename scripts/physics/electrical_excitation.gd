extends Resource
class_name ElectricalExcitation

@export var source_id: String = "electrical_source"
@export var source_kind: String = "transient"
@export var voltage_volts: float = 24.0
@export var duration_seconds: float = 0.4
@export var source_resistance_ohms: float = 0.5
@export var current_limit_amps: float = 12.0
@export var polarity_sign: int = 1
@export var tags: Array[String] = []


static func from_payload(
	payload: DamagePayload,
	default_voltage: float,
	default_duration: float,
	default_resistance: float,
	default_current_limit: float,
	default_polarity: int = 1
) -> ElectricalExcitation:
	var excitation := ElectricalExcitation.new()
	if payload == null:
		excitation.voltage_volts = max(default_voltage, 0.0)
		excitation.duration_seconds = max(default_duration, 0.02)
		excitation.source_resistance_ohms = max(default_resistance, 0.001)
		excitation.current_limit_amps = max(default_current_limit, 0.001)
		excitation.polarity_sign = 1 if default_polarity >= 0 else -1
		return excitation

	excitation.source_id = payload.source_name if payload.source_name != "" else "electrical_payload"
	excitation.source_kind = payload.hit_type if payload.hit_type != "" else "payload"
	var intensity: float = max(payload.status_strength, 1.0)
	if payload.amount > 1:
		intensity += min(float(payload.amount - 1) * 0.15, 1.0)
	excitation.voltage_volts = max(default_voltage, 0.0) * clampf(intensity, 0.5, 3.0)
	excitation.duration_seconds = max(default_duration, payload.status_duration, 0.02)
	excitation.source_resistance_ohms = max(default_resistance, 0.001)
	excitation.current_limit_amps = max(default_current_limit, 0.001)
	excitation.polarity_sign = 1 if default_polarity >= 0 else -1
	excitation.tags = payload.tags.duplicate()
	if payload.element != "" and not excitation.tags.has(payload.element.to_lower()):
		excitation.tags.append(payload.element.to_lower())
	if excitation.tags.has("reverse_polarity"):
		excitation.polarity_sign *= -1
	return excitation


func get_signed_voltage() -> float:
	return abs(voltage_volts) * float(1 if polarity_sign >= 0 else -1)


func get_debug_data() -> Dictionary:
	return {
		"source": source_id,
		"kind": source_kind,
		"voltage": snapped(get_signed_voltage(), 0.01),
		"duration": snapped(duration_seconds, 0.01),
		"resistance": snapped(source_resistance_ohms, 0.001),
		"current_limit": snapped(current_limit_amps, 0.01),
		"polarity": 1 if polarity_sign >= 0 else -1,
		"tags": tags.duplicate(),
	}
