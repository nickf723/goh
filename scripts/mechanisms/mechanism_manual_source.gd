extends MechanismSignalNode
class_name MechanismManualSource

@export var momentary_seconds: float = 0.0

var pulse_remaining: float = 0.0


func _ready() -> void:
	evaluate_sources_as_or = false
	super._ready()
	set_process(false)


func _process(delta: float) -> void:
	pulse_remaining = maxf(pulse_remaining - delta, 0.0)
	if pulse_remaining > 0.0:
		return
	set_process(false)
	set_input_active(false, {"reason": "momentary_complete"})


func set_input_active(next_active: bool, packet: Dictionary = {}) -> bool:
	var result: bool = set_mechanism_active(next_active, packet)
	if next_active and momentary_seconds > 0.0:
		pulse_remaining = momentary_seconds
		set_process(true)
	return result


func toggle_input(packet: Dictionary = {}) -> bool:
	set_input_active(not active, packet)
	return active


func pulse(duration: float = -1.0, packet: Dictionary = {}) -> void:
	var resolved_duration: float = duration if duration > 0.0 else maxf(momentary_seconds, 0.05)
	pulse_remaining = resolved_duration
	set_input_active(true, packet)
	set_process(true)


func reset_target() -> void:
	pulse_remaining = 0.0
	set_process(false)
	super.reset_target()


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["manual_source"] = true
	data["pulse_remaining"] = snappedf(pulse_remaining, 0.01)
	return data
