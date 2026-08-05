extends StaticBody3D
class_name MechanismSlidingGate

signal output_state_changed(active: bool)
signal gate_fraction_changed(open_fraction: float)

@export var display_name: String = "Mechanism Gate"
@export var moving_visual_path: NodePath = NodePath("GateVisual")
@export var collision_shape_path: NodePath = NodePath("CollisionShape3D")
@export var state_label_path: NodePath = NodePath("StateLabel")
@export var open_offset: Vector3 = Vector3(0.0, 4.0, 0.0)
@export_range(0.05, 5.0, 0.05) var transition_seconds: float = 0.65
@export var starts_open: bool = false
@export var disable_collision_while_open: bool = true

var active: bool = false
var open_fraction: float = 0.0
var moving_visual: Node3D
var collision_shape: CollisionShape3D
var state_label: Label3D
var closed_visual_position: Vector3 = Vector3.ZERO
var gate_tween: Tween
var last_packet: Dictionary = {}


func _ready() -> void:
	add_to_group("mechanism_outputs")
	add_to_group("mechanism_gates")
	add_to_group("lab_resettable")
	add_to_group("debuggable")
	moving_visual = get_node_or_null(moving_visual_path) as Node3D
	collision_shape = get_node_or_null(collision_shape_path) as CollisionShape3D
	state_label = get_node_or_null(state_label_path) as Label3D
	if moving_visual != null:
		closed_visual_position = moving_visual.position
	set_gate_open(starts_open, true, {"reason": "startup"})


func set_mechanism_active(next_active: bool, packet: Dictionary = {}) -> void:
	set_gate_open(next_active, false, packet)


func set_gate_open(
	next_open: bool,
	immediate: bool = false,
	packet: Dictionary = {}
) -> void:
	var changed: bool = active != next_open
	active = next_open
	last_packet = packet.duplicate(true)
	if disable_collision_while_open:
		_set_collision_enabled(not active)
	var target_fraction: float = 1.0 if active else 0.0
	if gate_tween != null and gate_tween.is_valid():
		gate_tween.kill()
	if immediate or moving_visual == null:
		_apply_fraction(target_fraction)
	else:
		gate_tween = create_tween()
		gate_tween.set_trans(Tween.TRANS_QUAD)
		gate_tween.set_ease(Tween.EASE_IN_OUT)
		gate_tween.tween_method(Callable(self, "_apply_fraction"), open_fraction, target_fraction, transition_seconds)
	if changed:
		output_state_changed.emit(active)


func is_mechanism_active() -> bool:
	return active


func _apply_fraction(value: float) -> void:
	open_fraction = clampf(value, 0.0, 1.0)
	if moving_visual != null:
		moving_visual.position = closed_visual_position + open_offset * open_fraction
	if state_label != null:
		var state_text: String = "OPEN" if open_fraction >= 0.99 else "CLOSED" if open_fraction <= 0.01 else str(int(round(open_fraction * 100.0))) + "%"
		state_label.text = display_name.to_upper() + "\n" + state_text
	gate_fraction_changed.emit(open_fraction)


func _set_collision_enabled(enabled: bool) -> void:
	collision_layer = 1 if enabled else 0
	collision_mask = 1 if enabled else 0
	set_deferred("collision_layer", collision_layer)
	set_deferred("collision_mask", collision_mask)
	if collision_shape != null:
		collision_shape.disabled = not enabled
		collision_shape.set_deferred("disabled", not enabled)


func reset_target() -> void:
	set_gate_open(starts_open, true, {"reason": "reset"})


func get_debug_data() -> Dictionary:
	return {
		"mechanism_gate": true,
		"display_name": display_name,
		"open": active,
		"open_fraction": snappedf(open_fraction, 0.01),
		"collision_enabled": collision_layer != 0,
		"packet": last_packet.duplicate(true),
	}
