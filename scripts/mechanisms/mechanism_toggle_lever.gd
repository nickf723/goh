extends Area3D
class_name MechanismToggleLever

signal mechanism_signal_changed(mechanism_id: String, active: bool, packet: Dictionary)
signal lever_toggled(active: bool)

@export_group("Identity")
@export var mechanism_id: String = "lever"
@export var display_name: String = "Mechanism Lever"

@export_group("Behavior")
@export var starts_active: bool = false
@export var momentary: bool = false
@export_range(0.05, 5.0, 0.05) var momentary_seconds: float = 0.35

@export_group("Presentation")
@export var handle_path: NodePath = NodePath("Handle")
@export var state_label_path: NodePath = NodePath("StateLabel")
@export var off_rotation_degrees: Vector3 = Vector3(0.0, 0.0, 28.0)
@export var on_rotation_degrees: Vector3 = Vector3(0.0, 0.0, -28.0)
@export_range(0.02, 1.0, 0.02) var animation_seconds: float = 0.16

var source: MechanismManualSource
var handle: Node3D
var state_label: Label3D
var lever_tween: Tween


func _ready() -> void:
	add_to_group("mechanism_inputs")
	add_to_group("lab_resettable")
	add_to_group("debuggable")
	handle = get_node_or_null(handle_path) as Node3D
	state_label = get_node_or_null(state_label_path) as Label3D
	_ensure_source()
	set_lever_active(starts_active, true)


func _ensure_source() -> void:
	source = get_node_or_null("Signal") as MechanismManualSource
	if source == null:
		source = MechanismManualSource.new()
		source.name = "Signal"
		add_child(source)
	source.mechanism_id = get_mechanism_id()
	source.display_name = display_name
	source.initial_active = starts_active
	source.momentary_seconds = momentary_seconds if momentary else 0.0
	var callback := Callable(self, "_on_source_signal_changed")
	if not source.mechanism_signal_changed.is_connected(callback):
		source.mechanism_signal_changed.connect(callback)


func interact() -> Dictionary:
	if momentary:
		source.pulse(momentary_seconds, {
			"source_type": "lever",
			"interaction": "press",
		})
	else:
		source.toggle_input({
			"source_type": "lever",
			"interaction": "toggle",
		})
	return {
		"message": display_name + (" activates." if is_mechanism_active() else " deactivates."),
		"objective": "Trace the mechanism signal to its output.",
	}


func set_lever_active(next_active: bool, immediate: bool = false) -> void:
	if source == null:
		_ensure_source()
	source.set_input_active(next_active, {
		"source_type": "lever",
		"reason": "direct_set",
	})
	_refresh_presentation(immediate)


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
	_refresh_presentation(false)
	lever_toggled.emit(active)
	mechanism_signal_changed.emit(get_mechanism_id(), active, packet.duplicate(true))


func _refresh_presentation(immediate: bool) -> void:
	var active: bool = is_mechanism_active()
	if state_label != null:
		state_label.text = display_name.to_upper() + "\n" + ("ON" if active else "OFF")
	if handle == null:
		return
	var target_rotation: Vector3 = on_rotation_degrees if active else off_rotation_degrees
	if lever_tween != null and lever_tween.is_valid():
		lever_tween.kill()
	if immediate:
		handle.rotation_degrees = target_rotation
		return
	lever_tween = create_tween()
	lever_tween.set_trans(Tween.TRANS_QUAD)
	lever_tween.set_ease(Tween.EASE_OUT)
	lever_tween.tween_property(handle, "rotation_degrees", target_rotation, animation_seconds)


func reset_target() -> void:
	if source != null:
		source.reset_target()
	set_lever_active(starts_active, true)


func get_debug_data() -> Dictionary:
	return {
		"mechanism_id": get_mechanism_id(),
		"lever": true,
		"active": is_mechanism_active(),
		"momentary": momentary,
		"packet": get_mechanism_packet(),
	}
