extends AnimatableBody3D
class_name MechanismValueElevator

signal elevator_value_changed(value: float, normalized_value: float)
signal elevator_fraction_changed(fraction: float)

@export_group("Identity")
@export var display_name: String = "Value Elevator"

@export_group("Value Mapping")
@export var input_minimum: float = 0.0
@export var input_maximum: float = 10.0
@export var starts_value: float = 0.0
@export var use_packet_range: bool = false
@export var clamp_input: bool = true

@export_group("Movement")
@export var movement_offset: Vector3 = Vector3(0.0, 6.0, 0.0)
@export_range(0.02, 5.0, 0.02) var transition_seconds: float = 0.5
@export_range(0.01, 0.5, 0.01) var fraction_signal_step: float = 0.05

@export_group("Presentation")
@export var state_label_path: NodePath = NodePath("StateLabel")
@export_range(8.0, 120.0, 1.0) var label_visibility_distance: float = 42.0

var base_position: Vector3 = Vector3.ZERO
var current_value: float = 0.0
var current_fraction: float = 0.0
var target_fraction: float = 0.0
var active: bool = false
var elevator_tween: Tween
var state_label: Label3D
var last_packet: Dictionary = {}
var last_label_text: String = ""
var last_emitted_fraction: float = -1.0
var value_application_count: int = 0


func _ready() -> void:
	add_to_group("mechanism_outputs")
	add_to_group("mechanism_value_outputs")
	add_to_group("lab_resettable")
	add_to_group("debuggable")
	base_position = position
	state_label = get_node_or_null(state_label_path) as Label3D
	if state_label != null:
		state_label.visibility_range_end = label_visibility_distance
		state_label.visibility_range_end_margin = 4.0
	set_elevator_value(starts_value, true, {"reason": "startup"})


func set_mechanism_value(next_value: float, packet: Dictionary = {}) -> void:
	set_elevator_value(next_value, false, packet)


func set_mechanism_active(next_active: bool, packet: Dictionary = {}) -> void:
	if packet.has("forwarded_value"):
		set_elevator_value(float(packet.get("forwarded_value", 0.0)), false, packet)
		return
	if packet.has("value") and not packet.has("active_only"):
		set_elevator_value(float(packet.get("value", 0.0)), false, packet)
		return
	set_elevator_value(
		get_input_maximum(packet) if next_active else get_input_minimum(packet),
		false,
		packet
	)


func set_elevator_value(
	next_value: float,
	immediate: bool = false,
	packet: Dictionary = {}
) -> void:
	last_packet = packet.duplicate(true)
	var minimum: float = get_input_minimum(packet)
	var maximum: float = get_input_maximum(packet)
	var safe_value: float = next_value
	if clamp_input:
		safe_value = clampf(safe_value, minimum, maximum)
	current_value = safe_value
	var next_fraction: float = 0.0
	if not is_equal_approx(minimum, maximum):
		next_fraction = inverse_lerp(minimum, maximum, current_value)
	set_elevator_fraction(next_fraction, immediate)
	value_application_count += 1
	elevator_value_changed.emit(current_value, current_fraction)


func set_elevator_fraction(next_fraction: float, immediate: bool = false) -> void:
	target_fraction = clampf(next_fraction, 0.0, 1.0)
	active = target_fraction > 0.001
	if elevator_tween != null and elevator_tween.is_valid():
		elevator_tween.kill()
	if immediate:
		_apply_fraction(target_fraction)
		return
	elevator_tween = create_tween()
	elevator_tween.set_trans(Tween.TRANS_QUAD)
	elevator_tween.set_ease(Tween.EASE_IN_OUT)
	elevator_tween.tween_method(
		Callable(self, "_apply_fraction"),
		current_fraction,
		target_fraction,
		transition_seconds
	)


func _apply_fraction(next_fraction: float) -> void:
	current_fraction = clampf(next_fraction, 0.0, 1.0)
	position = base_position + movement_offset * current_fraction
	_refresh_state_label()
	var endpoint: bool = current_fraction <= 0.001 or current_fraction >= 0.999
	if (
		last_emitted_fraction < 0.0
		or endpoint
		or absf(current_fraction - last_emitted_fraction) >= fraction_signal_step
	):
		last_emitted_fraction = current_fraction
		elevator_fraction_changed.emit(current_fraction)


func _refresh_state_label() -> void:
	if state_label == null:
		return
	var unit: String = str(last_packet.get("unit", ""))
	var value_text: String = str(snappedf(current_value, 0.1))
	if unit != "":
		value_text += " " + unit
	var next_text: String = (
		display_name.to_upper()
		+ "\n"
		+ value_text
		+ " • "
		+ str(roundi(current_fraction * 100.0))
		+ "%"
	)
	if next_text == last_label_text:
		return
	last_label_text = next_text
	state_label.text = next_text


func get_input_minimum(packet: Dictionary = {}) -> float:
	var minimum: float = input_minimum
	var maximum: float = input_maximum
	if use_packet_range:
		minimum = float(packet.get("minimum_value", minimum))
		maximum = float(packet.get("maximum_value", maximum))
	return minf(minimum, maximum)


func get_input_maximum(packet: Dictionary = {}) -> float:
	var minimum: float = input_minimum
	var maximum: float = input_maximum
	if use_packet_range:
		minimum = float(packet.get("minimum_value", minimum))
		maximum = float(packet.get("maximum_value", maximum))
	return maxf(minimum, maximum)


func is_mechanism_active() -> bool:
	return active


func get_mechanism_value() -> float:
	return current_value


func get_mechanism_normalized_value() -> float:
	return current_fraction


func reset_target() -> void:
	last_emitted_fraction = -1.0
	last_label_text = ""
	set_elevator_value(starts_value, true, {"reason": "reset"})


func get_debug_data() -> Dictionary:
	return {
		"mechanism_value_elevator": true,
		"display_name": display_name,
		"active": active,
		"value": current_value,
		"fraction": current_fraction,
		"target_fraction": target_fraction,
		"input_minimum": get_input_minimum(last_packet),
		"input_maximum": get_input_maximum(last_packet),
		"movement_offset": movement_offset,
		"applications": value_application_count,
		"packet": last_packet.duplicate(true),
	}
