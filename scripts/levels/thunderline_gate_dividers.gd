extends Node3D
class_name ThunderlineGateDividers

@export var corridor_inner_half_width: float = 6.0
@export var gate_half_width: float = 2.8
@export var divider_height: float = 6.0
@export var divider_depth: float = 0.8
@export var gate_positions: Array[float] = [10.0, 36.5]

var divider_material: StandardMaterial3D


func _ready() -> void:
	divider_material = StandardMaterial3D.new()
	divider_material.albedo_color = Color(0.018, 0.03, 0.055, 1.0)
	divider_material.metallic = 0.58
	divider_material.roughness = 0.42
	var divider_width: float = maxf(
		corridor_inner_half_width - gate_half_width,
		0.2
	)
	var center_x: float = gate_half_width + divider_width * 0.5
	for gate_z: float in gate_positions:
		_create_divider(
			"LeftGateDivider" + str(roundi(gate_z * 10.0)),
			Vector3(-center_x, divider_height * 0.5, gate_z),
			Vector3(divider_width, divider_height, divider_depth)
		)
		_create_divider(
			"RightGateDivider" + str(roundi(gate_z * 10.0)),
			Vector3(center_x, divider_height * 0.5, gate_z),
			Vector3(divider_width, divider_height, divider_depth)
		)


func _create_divider(
	node_name: String,
	position_value: Vector3,
	size_value: Vector3
) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	body.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_value
	visual.mesh = mesh
	visual.material_override = divider_material
	body.add_child(visual)
	add_child(body)


func get_debug_data() -> Dictionary:
	return {
		"thunderline_gate_dividers": true,
		"gate_count": gate_positions.size(),
		"divider_count": gate_positions.size() * 2,
		"opening_width": gate_half_width * 2.0,
	}
