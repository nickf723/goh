extends Node3D
class_name ModularEnvironmentGate

const STONE_MATERIAL: Material = preload("res://art/materials/environment/modular/weathered_stone.tres")
const TRIM_STONE_MATERIAL: Material = preload("res://art/materials/environment/modular/trim_stone.tres")
const METAL_MATERIAL: Material = preload("res://art/materials/environment/modular/aged_metal.tres")

signal gate_state_changed(opened: bool)

@export var piece_id: String = "weathered_iron_gate_3m"
@export var display_name: String = "Weathered Iron Gate"
@export var category: String = "architecture"
@export var footprint: Vector3 = Vector3(4.0, 3.5, 0.8)
@export var requires_collision: bool = true
@export var open_angle_degrees: float = -96.0
@export var animation_speed: float = 4.0
@export var starts_open: bool = false

var built: bool = false
var target_open: bool = false
var gate_pivot: Node3D
var gate_body: AnimatableBody3D


func _ready() -> void:
	add_to_group("modular_environment_piece")
	add_to_group("modular_environment_architecture")
	add_to_group("modular_environment_gate")
	set_meta("piece_id", piece_id)
	set_meta("piece_category", category)
	set_meta("collision_required", requires_collision)
	set_meta("prototype_asset_quality", "modular_v1")
	_build_gate()
	set_open(starts_open, true)


func _process(delta: float) -> void:
	if gate_pivot == null:
		return
	var target_angle: float = deg_to_rad(open_angle_degrees) if target_open else 0.0
	gate_pivot.rotation.y = lerp_angle(
		gate_pivot.rotation.y,
		target_angle,
		clampf(maxf(delta, 0.0) * animation_speed, 0.0, 1.0)
	)
	if absf(angle_difference(gate_pivot.rotation.y, target_angle)) <= 0.004:
		gate_pivot.rotation.y = target_angle


func _build_gate() -> void:
	if built:
		return
	built = true
	_add_static_box(self, "LeftPier", Vector3(0.72, 3.35, 0.82), Vector3(-1.85, 1.675, 0.0), STONE_MATERIAL)
	_add_static_box(self, "RightPier", Vector3(0.72, 3.35, 0.82), Vector3(1.85, 1.675, 0.0), STONE_MATERIAL)
	_add_static_box(self, "Lintel", Vector3(4.35, 0.5, 0.88), Vector3(0.0, 3.28, 0.0), TRIM_STONE_MATERIAL)
	gate_pivot = Node3D.new()
	gate_pivot.name = "GatePivot"
	gate_pivot.position = Vector3(-1.48, 0.0, 0.0)
	add_child(gate_pivot)
	gate_body = AnimatableBody3D.new()
	gate_body.name = "GatePanel"
	gate_body.position = Vector3(1.48, 0.0, 0.0)
	gate_pivot.add_child(gate_body)
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.96, 2.62, 0.22)
	collision.shape = shape
	collision.position.y = 1.45
	gate_body.add_child(collision)
	for bar: int in range(9):
		_add_visual_box(
			gate_body,
			"Bar%02d" % bar,
			Vector3(0.12, 2.62, 0.14),
			Vector3(-1.3 + float(bar) * 0.325, 1.45, 0.0),
			METAL_MATERIAL
		)
	for rail_y: float in [0.42, 1.42, 2.44]:
		_add_visual_box(gate_body, "Rail_%s" % str(rail_y).replace(".", "_"), Vector3(2.96, 0.14, 0.18), Vector3(0.0, rail_y, 0.0), METAL_MATERIAL)
	_add_visual_box(gate_body, "DiagonalA", Vector3(0.13, 3.34, 0.17), Vector3(0.0, 1.45, -0.02), METAL_MATERIAL, Vector3(0.0, 0.0, 0.92))
	_add_visual_box(gate_body, "DiagonalB", Vector3(0.13, 3.34, 0.17), Vector3(0.0, 1.45, 0.02), METAL_MATERIAL, Vector3(0.0, 0.0, -0.92))
	for hinge_y: float in [0.62, 2.28]:
		_add_visual_cylinder(self, "Hinge_%s" % str(hinge_y).replace(".", "_"), 0.13, 0.13, 0.36, Vector3(-1.5, hinge_y, 0.0), METAL_MATERIAL, Vector3(PI * 0.5, 0.0, 0.0))


func set_open(value: bool, instant: bool = false) -> void:
	target_open = value
	if instant and gate_pivot != null:
		gate_pivot.rotation.y = deg_to_rad(open_angle_degrees) if target_open else 0.0
	gate_state_changed.emit(target_open)


func toggle_gate() -> void:
	set_open(not target_open)


func is_open() -> bool:
	return target_open


func get_collision_shape_count() -> int:
	return _count_collision_shapes(self)


func _count_collision_shapes(node: Node) -> int:
	var count: int = 1 if node is CollisionShape3D else 0
	for child: Node in node.get_children():
		count += _count_collision_shapes(child)
	return count


func _add_static_box(
	parent: Node3D,
	node_name: String,
	size: Vector3,
	position_value: Vector3,
	material_value: Material
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	parent.add_child(body)
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	_add_visual_box(body, "Visual", size, Vector3.ZERO, material_value)
	return body


func _add_visual_box(
	parent: Node3D,
	node_name: String,
	size: Vector3,
	position_value: Vector3,
	material_value: Material,
	rotation_value: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.position = position_value
	visual.rotation = rotation_value
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = material_value
	parent.add_child(visual)
	return visual


func _add_visual_cylinder(
	parent: Node3D,
	node_name: String,
	top_radius: float,
	bottom_radius: float,
	height: float,
	position_value: Vector3,
	material_value: Material,
	rotation_value: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.position = position_value
	visual.rotation = rotation_value
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 12
	visual.mesh = mesh
	visual.material_override = material_value
	parent.add_child(visual)
	return visual


func get_debug_data() -> Dictionary:
	return {
		"piece_id": piece_id,
		"category": category,
		"built": built,
		"open": target_open,
		"angle": gate_pivot.rotation.y if gate_pivot != null else 0.0,
		"colliders": get_collision_shape_count(),
	}
