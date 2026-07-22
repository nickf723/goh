extends CircuitComponent
class_name CircuitCable

const DEFAULT_COPPER_PROFILE: PhysicalMaterialProfile = preload("res://data/materials/copper_physical_profile.tres")

@export var endpoint_a: Vector3 = Vector3(-0.5, 0.0, 0.0)
@export var endpoint_b: Vector3 = Vector3(0.5, 0.0, 0.0)
@export_range(0.02, 0.5, 0.01) var thickness: float = 0.11
@export var cable_color: Color = Color(0.72, 0.25, 0.055, 1.0)
@export var energized_color: Color = Color(1.0, 0.68, 0.08, 1.0)
@export var body_path: NodePath = NodePath("Body")
@export var current_glow_path: NodePath = NodePath("CurrentGlow")

var body_visual: MeshInstance3D = null
var current_glow: MeshInstance3D = null


func _ready() -> void:
	component_kind = "wire"
	if material_profile == null:
		material_profile = DEFAULT_COPPER_PROFILE
	resolve_visuals()
	rebuild_geometry()
	super._ready()
	refresh_energized_visual()


func resolve_visuals() -> void:
	body_visual = get_node_or_null(body_path) as MeshInstance3D
	current_glow = get_node_or_null(current_glow_path) as MeshInstance3D


func rebuild_geometry() -> void:
	var terminal_a: CircuitTerminal = get_terminal_a()
	var terminal_b: CircuitTerminal = get_terminal_b()
	if terminal_a != null:
		terminal_a.position = endpoint_a
	if terminal_b != null:
		terminal_b.position = endpoint_b

	configure_segment(body_visual, thickness, make_material(cable_color, 0.0))
	configure_segment(
		current_glow,
		thickness * 1.7,
		make_material(energized_color, 3.2)
	)


func configure_segment(
	visual: MeshInstance3D,
	segment_thickness: float,
	material: StandardMaterial3D
) -> void:
	if visual == null:
		return

	var direction: Vector3 = endpoint_b - endpoint_a
	var length: float = max(direction.length(), 0.02)
	var midpoint: Vector3 = (endpoint_a + endpoint_b) * 0.5
	var up: Vector3 = Vector3.UP
	var normalized_direction: Vector3 = direction.normalized()
	if absf(normalized_direction.dot(up)) > 0.98:
		up = Vector3.RIGHT

	var mesh := BoxMesh.new()
	mesh.size = Vector3(segment_thickness, segment_thickness, length)
	visual.mesh = mesh
	visual.position = midpoint
	visual.basis = Basis.looking_at(normalized_direction, up)
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if visual == current_glow else GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func make_material(color: Color, emission_energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.82
	material.roughness = 0.28
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission_energy
	return material


func _on_circuit_state_applied() -> void:
	refresh_energized_visual()


func refresh_energized_visual() -> void:
	if current_glow != null:
		current_glow.visible = energized


func reset_target() -> void:
	apply_circuit_state(false, 0.0, 0.0, -1)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["cable_length"] = snapped(endpoint_a.distance_to(endpoint_b), 0.01)
	data["endpoint_a"] = endpoint_a
	data["endpoint_b"] = endpoint_b
	return data
