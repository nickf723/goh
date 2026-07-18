extends RefCounted
class_name LabGeometryFactory


static func make_material(color: Color, emissive: bool = false, energy: float = 1.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.32
	material.metallic = 0.35
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emissive:
		material.emission_enabled = true
		material.emission = Color(color.r, color.g, color.b, 1.0)
		material.emission_energy_multiplier = energy
	return material


static func add_terminal(
	component: CircuitComponent,
	node_name: String,
	terminal_id: String,
	local_position: Vector3
) -> CircuitTerminal:
	var terminal := CircuitTerminal.new()
	terminal.name = node_name
	terminal.terminal_id = terminal_id
	terminal.position = local_position
	component.add_child(terminal)
	return terminal


static func add_label(
	parent: Node3D,
	node_name: String,
	text: String,
	position: Vector3,
	font_size: int = 24,
	color: Color = Color.WHITE
) -> Label3D:
	var label := Label3D.new()
	label.name = node_name
	label.position = position
	label.text = text
	label.font_size = font_size
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 5
	label.modulate = color
	parent.add_child(label)
	return label


static func add_box_interactable(
	parent: Area3D,
	size: Vector3,
	color: Color,
	label_text: String
) -> Label3D:
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	parent.add_child(shape_node)

	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	mesh_node.material_override = make_material(color, true, 1.4)
	parent.add_child(mesh_node)
	return add_label(parent, "StateLabel", label_text, Vector3(0.0, 1.15, 0.0), 23)


static func add_sphere_area(parent: Node3D, node_name: String, radius: float, position: Vector3) -> Area3D:
	var area := Area3D.new()
	area.name = node_name
	area.position = position
	area.monitoring = true
	area.monitorable = true
	parent.add_child(area)
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius
	collision.shape = shape
	area.add_child(collision)
	return area
