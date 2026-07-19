extends RefCounted
class_name ThermalLabGeometry


static func make_material(color: Color, emissive: bool = false, energy: float = 1.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.34
	material.metallic = 0.28
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emissive:
		material.emission_enabled = true
		material.emission = Color(color.r, color.g, color.b, 1.0)
		material.emission_energy_multiplier = energy
	return material


static func make_temperature_material(temperature_c: float) -> StandardMaterial3D:
	var cold_ratio: float = clampf((20.0 - temperature_c) / 80.0, 0.0, 1.0)
	var hot_ratio: float = clampf((temperature_c - 20.0) / 180.0, 0.0, 1.0)
	var color := Color(0.62, 0.3, 0.12, 1.0)
	if cold_ratio > 0.0:
		color = Color(0.28, 0.62, 1.0, 1.0).lerp(color, 1.0 - cold_ratio)
	elif hot_ratio > 0.0:
		color = color.lerp(Color(1.0, 0.2, 0.04, 1.0), hot_ratio)
	return make_material(color, true, 1.0 + max(cold_ratio, hot_ratio) * 2.2)


static func add_label(
	parent: Node3D,
	node_name: String,
	text_value: String,
	position_value: Vector3,
	font_size: int = 22,
	color: Color = Color.WHITE
) -> Label3D:
	var label := Label3D.new()
	label.name = node_name
	label.text = text_value
	label.position = position_value
	label.font_size = font_size
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 5
	label.modulate = color
	parent.add_child(label)
	return label


static func add_static_box(
	parent: Node3D,
	node_name: String,
	position_value: Vector3,
	size: Vector3,
	color: Color
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	parent.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_box_visual(body, "MeshInstance3D", size, color)
	return body


static func add_box_visual(
	parent: Node3D,
	node_name: String,
	size: Vector3,
	color: Color,
	emissive: bool = false,
	energy: float = 1.6
) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	mesh_node.material_override = make_material(color, emissive, energy)
	parent.add_child(mesh_node)
	return mesh_node


static func add_terminal(
	component: CircuitComponent,
	node_name: String,
	terminal_id: String,
	position_value: Vector3,
	connection_radius: float = 0.3
) -> CircuitTerminal:
	var terminal := CircuitTerminal.new()
	terminal.name = node_name
	terminal.terminal_id = terminal_id
	terminal.position = position_value
	terminal.connection_radius = connection_radius
	component.add_child(terminal)
	return terminal
