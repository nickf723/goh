extends StaticBody3D
class_name MechanismElementSensor

signal mechanism_signal_changed(mechanism_id: String, active: bool, packet: Dictionary)
signal element_accepted(element: String, payload: DamagePayload)
signal element_rejected(element: String, payload: DamagePayload)

@export_group("Identity")
@export var mechanism_id: String = "element_sensor"
@export var display_name: String = "Element Sensor"

@export_group("Elements")
@export var accepted_elements: Array[String] = ["fire"]
@export var reset_elements: Array[String] = ["water"]
@export var latch_when_activated: bool = true
@export_range(0.05, 30.0, 0.05) var active_seconds: float = 4.0
@export var starts_active: bool = false

@export_group("Presentation")
@export var sensor_visual_path: NodePath = NodePath("SensorVisual")
@export var state_label_path: NodePath = NodePath("StateLabel")
@export var inactive_color: Color = Color(0.18, 0.2, 0.26)
@export var active_color: Color = Color(1.0, 0.34, 0.08)
@export var rejected_color: Color = Color(0.38, 0.55, 0.9)

var source: MechanismManualSource
var sensor_visual: MeshInstance3D
var state_label: Label3D
var flash_tween: Tween


func _ready() -> void:
	add_to_group("mechanism_inputs")
	add_to_group("elemental_mechanism_sensors")
	add_to_group("lab_resettable")
	add_to_group("debuggable")
	sensor_visual = get_node_or_null(sensor_visual_path) as MeshInstance3D
	state_label = get_node_or_null(state_label_path) as Label3D
	_ensure_source()
	set_sensor_active(starts_active, {"reason": "startup"})
	_refresh_presentation()


func _ensure_source() -> void:
	source = get_node_or_null("Signal") as MechanismManualSource
	if source == null:
		source = MechanismManualSource.new()
		source.name = "Signal"
		source.mechanism_id = get_mechanism_id()
		source.display_name = display_name
		source.initial_active = starts_active
		source.momentary_seconds = 0.0 if latch_when_activated else active_seconds
		add_child(source)
	else:
		source.mechanism_id = get_mechanism_id()
		source.display_name = display_name
		source.initial_active = starts_active
		source.momentary_seconds = 0.0 if latch_when_activated else active_seconds
	var callback := Callable(self, "_on_source_signal_changed")
	if not source.mechanism_signal_changed.is_connected(callback):
		source.mechanism_signal_changed.connect(callback)


func receive_damage_payload(payload: DamagePayload) -> Dictionary:
	if payload == null:
		return _result(display_name + " receives no elemental signal.")
	var element: String = payload.element.to_lower().strip_edges()
	if _normalized_elements(reset_elements).has(element):
		set_sensor_active(false, {
			"reason": "reset_element",
			"element": element,
			"source_name": payload.source_name,
		})
		return _result(element.capitalize() + " resets " + display_name + ".")
	if not _normalized_elements(accepted_elements).has(element):
		_flash_rejected()
		element_rejected.emit(element, payload)
		return _result(
			display_name + " rejects " + element.capitalize() + ". It accepts "
			+ ", ".join(_normalized_elements(accepted_elements)).capitalize() + "."
		)
	if latch_when_activated:
		set_sensor_active(true, {
			"reason": "element_hit",
			"element": element,
			"source_name": payload.source_name,
		})
	else:
		source.pulse(active_seconds, {
			"reason": "element_pulse",
			"element": element,
			"source_name": payload.source_name,
		})
	element_accepted.emit(element, payload)
	return _result(display_name + " answers " + element.capitalize() + ".")


func set_sensor_active(next_active: bool, packet: Dictionary = {}) -> void:
	if source == null:
		_ensure_source()
	source.set_input_active(next_active, packet)
	_refresh_presentation()


func is_mechanism_active() -> bool:
	return source != null and source.is_mechanism_active()


func get_mechanism_id() -> String:
	var normalized: String = mechanism_id.to_lower().strip_edges().replace(" ", "_")
	return normalized if normalized != "" else str(name).to_lower()


func get_mechanism_packet() -> Dictionary:
	return source.get_mechanism_packet() if source != null else {}


func _on_source_signal_changed(
	_signal_id: String,
	active: bool,
	packet: Dictionary
) -> void:
	_refresh_presentation()
	mechanism_signal_changed.emit(get_mechanism_id(), active, packet.duplicate(true))


func _refresh_presentation() -> void:
	var active: bool = is_mechanism_active()
	if state_label != null:
		var accepted_text: String = "/".join(_normalized_elements(accepted_elements)).to_upper()
		state_label.text = display_name.to_upper() + "\n" + accepted_text + " • " + ("ACTIVE" if active else "DORMANT")
	if sensor_visual != null:
		_apply_visual_color(active_color if active else inactive_color, 2.5 if active else 0.35)


func _flash_rejected() -> void:
	if sensor_visual == null:
		return
	if flash_tween != null and flash_tween.is_valid():
		flash_tween.kill()
	_apply_visual_color(rejected_color, 1.8)
	flash_tween = create_tween()
	flash_tween.tween_interval(0.2)
	flash_tween.tween_callback(Callable(self, "_refresh_presentation"))


func _apply_visual_color(color: Color, emission_energy: float) -> void:
	if sensor_visual == null:
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.55
	material.roughness = 0.28
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = emission_energy
	sensor_visual.material_override = material


func _normalized_elements(values: Array[String]) -> Array[String]:
	var normalized: Array[String] = []
	for value: String in values:
		var element: String = value.to_lower().strip_edges()
		if element != "" and not normalized.has(element):
			normalized.append(element)
	return normalized


func _result(message: String) -> Dictionary:
	return {
		"message": message,
		"objective": "Route mechanism signals to the chamber output.",
	}


func reset_target() -> void:
	if source != null:
		source.reset_target()
	set_sensor_active(starts_active, {"reason": "reset"})


func get_debug_data() -> Dictionary:
	return {
		"mechanism_id": get_mechanism_id(),
		"element_sensor": true,
		"active": is_mechanism_active(),
		"accepted_elements": _normalized_elements(accepted_elements),
		"reset_elements": _normalized_elements(reset_elements),
		"latched": latch_when_activated,
		"packet": get_mechanism_packet(),
	}
