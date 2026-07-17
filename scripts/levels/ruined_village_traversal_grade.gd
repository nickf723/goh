extends Node
class_name RuinedVillageTraversalGrade


func _ready() -> void:
	call_deferred("apply_traversal_grade")


func apply_traversal_grade() -> void:
	await get_tree().process_frame

	var level: Node = get_parent()
	if level == null:
		return

	var geometry_root: Node3D = level.get_node_or_null("GeneratedGeometry") as Node3D
	if geometry_root == null:
		push_error("RuinedVillageTraversalGrade could not find GeneratedGeometry.")
		return

	# The broad far-lip block is visual mass only. Traversal uses two authored ramps.
	var far_lip: StaticBody3D = geometry_root.get_node_or_null("FarRavineLip") as StaticBody3D
	if far_lip != null:
		set_body_enabled(far_lip, false)

	var left_far_platform: StaticBody3D = geometry_root.get_node_or_null("LeftFarPlatform") as StaticBody3D
	if left_far_platform != null:
		resize_box_body(left_far_platform, Vector3(-10, 2.65, -37), Vector3(8, 1.2, 7))

	var church_ground: StaticBody3D = geometry_root.get_node_or_null("ChurchGround") as StaticBody3D
	if church_ground != null:
		resize_box_body(church_ground, Vector3(0, 7.5, -66), Vector3(46, 1, 27))

	var church_hill: StaticBody3D = geometry_root.get_node_or_null("ChurchHill") as StaticBody3D
	if church_hill != null:
		resize_box_body(church_hill, Vector3(0, 3.0, -66), Vector3(52, 9, 30))

	create_ramp(
		geometry_root,
		"ArrivalTraversalRamp",
		Vector3(0, 1.5, 31.0),
		Vector3(9.5, 0.55, 17.0),
		10.0,
		Color(0.52, 0.44, 0.34, 1.0)
	)
	create_ramp(
		geometry_root,
		"LeftRavineAscent",
		Vector3(-10, 4.48, -42.5),
		Vector3(5.6, 0.6, 13.0),
		13.0,
		Color(0.48, 0.43, 0.36, 1.0)
	)
	create_ramp(
		geometry_root,
		"RightRavineAscent",
		Vector3(10, 4.48, -42.5),
		Vector3(5.6, 0.6, 13.0),
		13.0,
		Color(0.48, 0.43, 0.36, 1.0)
	)
	create_ramp(
		geometry_root,
		"ChurchHillAscent",
		Vector3(0, 6.95, -51.0),
		Vector3(11.5, 0.65, 10.5),
		11.0,
		Color(0.58, 0.48, 0.36, 1.0)
	)

	add_to_group("ruined_village_traversal_ready")


func set_body_enabled(body: StaticBody3D, enabled: bool) -> void:
	for child: Node in body.get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).set_deferred("disabled", not enabled)
		elif child is MeshInstance3D:
			(child as MeshInstance3D).visible = enabled


func resize_box_body(body: StaticBody3D, new_position: Vector3, new_size: Vector3) -> void:
	body.position = new_position
	for child: Node in body.get_children():
		if child is CollisionShape3D:
			var collision: CollisionShape3D = child as CollisionShape3D
			if collision.shape is BoxShape3D:
				var shape: BoxShape3D = collision.shape as BoxShape3D
				shape.size = new_size
		elif child is MeshInstance3D:
			var mesh_instance: MeshInstance3D = child as MeshInstance3D
			if mesh_instance.mesh is BoxMesh:
				var mesh: BoxMesh = mesh_instance.mesh as BoxMesh
				mesh.size = new_size


func create_ramp(
	parent: Node3D,
	node_name: String,
	position_value: Vector3,
	size: Vector3,
	rotation_x_degrees: float,
	color: Color
) -> void:
	if parent.get_node_or_null(node_name) != null:
		return

	var body: StaticBody3D = StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	body.rotation_degrees.x = rotation_x_degrees

	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)

	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	mesh_instance.material_override = material
	body.add_child(mesh_instance)

	parent.add_child(body)
