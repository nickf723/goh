extends Node3D
class_name MechanismIndicator

signal output_state_changed(active: bool)

@export var display_name: String = "Signal Indicator"
@export var glow_path: NodePath = NodePath("Glow")
@export var state_label_path: NodePath = NodePath("StateLabel")
@export var inactive_color: Color = Color(0.18, 0.22, 0.3)
@export var active_color: Color = Color(0.24, 1.0, 0.48)
@export var starts_active: bool = false

var active: bool = false
var glow: MeshInstance3D
var state_label: Label3D
var last_packet: Dictionary = {}


func _ready() -> void:
	add_to_group("mechanism_outputs")
	add_to_group("lab_resettable")
	add_to_group("debuggable")
	glow = get_node_or_null(glow_path) as MeshInstance3D
	state_label = get_node_or_null(state_label_path) as Label3D
	set_mechanism_active(starts_active, {"reason": "startup"})


func set_mechanism_active(next_active: bool, packet: Dictionary = {}) -> void:
	var changed: bool = active != next_active
	active = next_active
	last_packet = packet.duplicate(true)
	_refresh_presentation()
	if changed:
		output_state_changed.emit(active)


func is_mechanism_active() -> bool:
	return active


func _refresh_presentation() -> void:
	var color: Color = active_color if active else inactive_color
	if glow != null:
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.metallic = 0.4
		material.roughness = 0.25
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 2.8 if active else 0.3
		glow.material_override = material
	if state_label != null:
		state_label.text = display_name.to_upper() + "\n" + ("ACTIVE" if active else "INACTIVE")
		state_label.modulate = color


func reset_target() -> void:
	set_mechanism_active(starts_active, {"reason": "reset"})


func get_debug_data() -> Dictionary:
	return {
		"mechanism_indicator": true,
		"display_name": display_name,
		"active": active,
		"packet": last_packet.duplicate(true),
	}
