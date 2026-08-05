extends Node3D
class_name MechanismIndicator

signal output_state_changed(active: bool)

@export var display_name: String = "Signal Indicator"
@export var glow_path: NodePath = NodePath("Glow")
@export var state_label_path: NodePath = NodePath("StateLabel")
@export var inactive_color: Color = Color(0.18, 0.22, 0.3)
@export var active_color: Color = Color(0.24, 1.0, 0.48)
@export var starts_active: bool = false
@export_range(8.0, 120.0, 1.0) var label_visibility_distance: float = 34.0

var active: bool = false
var glow: MeshInstance3D
var state_label: Label3D
var last_packet: Dictionary = {}
var inactive_material: StandardMaterial3D
var active_material: StandardMaterial3D
var presentation_initialized: bool = false
var presentation_refresh_count: int = 0


func _ready() -> void:
	add_to_group("mechanism_outputs")
	add_to_group("lab_resettable")
	add_to_group("debuggable")
	glow = get_node_or_null(glow_path) as MeshInstance3D
	state_label = get_node_or_null(state_label_path) as Label3D
	if state_label != null:
		state_label.visibility_range_end = label_visibility_distance
		state_label.visibility_range_end_margin = 4.0
	inactive_material = _build_material(inactive_color, 0.3)
	active_material = _build_material(active_color, 2.8)
	set_mechanism_active(starts_active, {"reason": "startup"})


func set_mechanism_active(next_active: bool, packet: Dictionary = {}) -> void:
	var changed: bool = active != next_active
	active = next_active
	last_packet = packet.duplicate(true)
	if changed or not presentation_initialized:
		_refresh_presentation()
	if changed:
		output_state_changed.emit(active)


func is_mechanism_active() -> bool:
	return active


func _refresh_presentation() -> void:
	presentation_initialized = true
	presentation_refresh_count += 1
	var color: Color = active_color if active else inactive_color
	if glow != null:
		glow.material_override = active_material if active else inactive_material
	if state_label != null:
		state_label.text = display_name.to_upper() + "\n" + ("ACTIVE" if active else "INACTIVE")
		state_label.modulate = color


func _build_material(color: Color, emission_energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.4
	material.roughness = 0.25
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = emission_energy
	return material


func reset_target() -> void:
	set_mechanism_active(starts_active, {"reason": "reset"})


func get_debug_data() -> Dictionary:
	return {
		"mechanism_indicator": true,
		"display_name": display_name,
		"active": active,
		"presentation_refreshes": presentation_refresh_count,
		"packet": last_packet.duplicate(true),
	}
