extends Node3D
class_name AuthoredWildsSegmentLayout

@export_enum("cypress_basin", "wet_woodland", "pine_ridge") var layout_id: String = "cypress_basin"

var definition: ExpeditionSegmentDefinition
var rng := RandomNumberGenerator.new()
var built := false


func configure_layout(segment_definition: ExpeditionSegmentDefinition, seed_value: int) -> void:
	definition = segment_definition
	rng.seed = seed_value
	if built:
		return
	built = true
	match layout_id:
		"wet_woodland":
			build_wet_woodland()
		"pine_ridge":
			build_pine_ridge()
		_:
			build_cypress_basin()
	add_to_group("authored_wilds_layout")


func build_cypress_basin() -> void:
	add_box("EntryIsland", Vector3(8.5, 0.6, 7.0), Vector3(0, -0.3, 3.5), Color(0.17, 0.25, 0.16))
	add_box("MiddleIsland", Vector3(7.0, 0.5, 9.0), Vector3(-1.0, -0.25, 13.0), Color(0.15, 0.23, 0.15))
	add_box("ExitIsland", Vector3(8.5, 0.55, 8.0), Vector3(0.7, -0.28, 23.0), Color(0.19, 0.27, 0.17))
	add_visual_box("Floodwater", Vector3(15.5, 0.12, 28.0), Vector3(0, -0.08, 14), Color(0.06, 0.28, 0.31, 0.72), true)
	add_boardwalk(Vector3(0, 0.14, 5.2), 4, 0.0)
	add_boardwalk(Vector3(-0.9, 0.14, 12.0), 5, -8.0)
	add_boardwalk(Vector3(0.4, 0.14, 19.0), 5, 9.0)
	for p: Vector3 in [Vector3(-5.2,0,5), Vector3(5,0,8), Vector3(-5.4,0,16), Vector3(5.2,0,21), Vector3(-4.8,0,25)]:
		add_tree(p, rng.randf_range(0.95, 1.2))
	add_fallen_log(Vector3(2.8, 0.55, 13.5), -18.0, 4.6)
	add_fallen_log(Vector3(-2.8, 0.5, 21.0), 16.0, 4.2)
	add_reeds(Vector3(-3.5,0,9), 7)
	add_reeds(Vector3(3.5,0,17), 8)
	add_boundary(Vector3(-7.0, 1.2, 14), 28.0)
	add_boundary(Vector3(7.0, 1.2, 14), 28.0)


func build_wet_woodland() -> void:
	add_box("WoodlandFloor", Vector3(14.0, 0.65, 28.0), Vector3(0, -0.33, 14), Color(0.18, 0.25, 0.16))
	add_visual_box("MainTrail", Vector3(4.4, 0.08, 27.0), Vector3(0, 0.04, 14), Color(0.29, 0.25, 0.16))
	add_visual_box("BranchTrail", Vector3(6.0, 0.07, 3.2), Vector3(-4.2, 0.04, 15.5), Color(0.28, 0.24, 0.16))
	for p: Vector3 in [Vector3(-5.4,0,3.8), Vector3(5.2,0,5.7), Vector3(-5,0,10), Vector3(5.4,0,12.2), Vector3(-5.3,0,20), Vector3(5,0,23), Vector3(-4.8,0,26)]:
		add_tree(p, rng.randf_range(0.9, 1.18))
	add_fallen_log(Vector3(1.4, 0.5, 8.7), -14.0, 4.5)
	add_fallen_log(Vector3(-1.7, 0.5, 20.8), 18.0, 4.2)
	add_ruin_gate(Vector3(-4.7, 0, 15.5))
	add_rocks(Vector3(3.6, 0, 14.0))
	add_rocks(Vector3(-3.8, 0, 24.0))
	add_boundary(Vector3(-7.2, 1.4, 7.0), 12.0)
	add_boundary(Vector3(-7.2, 1.4, 23.2), 7.5)
	add_boundary(Vector3(7.2, 1.4, 14.0), 28.0)
	build_woodland_to_pine_throat()


func build_woodland_to_pine_throat() -> void:
	var throat := Node3D.new()
	throat.name = "TransitionThroat_WoodlandToPine"
	add_child(throat)
	for p: Vector3 in [Vector3(-4.3,0,24.7), Vector3(4.4,0,25.5), Vector3(-5.2,0,27.0), Vector3(5.1,0,27.2)]:
		add_pine_tree(p, rng.randf_range(0.72, 0.9), throat)
	add_pine_needles(Vector3(0, 0.075, 25.8), Vector3(5.0, 0.05, 4.0), throat)


func build_pine_ridge() -> void:
	var throat := Node3D.new()
	throat.name = "TransitionThroat_WetlandToPine"
	add_child(throat)
	add_ramp("LowerRidgeRamp", 0.0, 9.0, 0.75, 0.0, Color(0.29, 0.28, 0.16))
	add_ramp("MiddleRidgeRamp", 9.0, 9.0, 0.9, 0.75, Color(0.31, 0.29, 0.16))
	add_ramp("UpperRidgeRamp", 18.0, 10.0, 1.1, 1.65, Color(0.34, 0.3, 0.17))
	add_visual_box("MainTrail", Vector3(4.8, 0.07, 27.0), Vector3(0, 0.12, 14), Color(0.42, 0.34, 0.18))

	# Mixed entry vegetation carries the wet woodland forward before the pines take over.
	for p: Vector3 in [Vector3(-4.8,0,1.8), Vector3(4.9,0,2.8)]:
		add_tree(p, rng.randf_range(0.72, 0.88), throat)
	for p: Vector3 in [Vector3(-5.7,0,4.2), Vector3(5.5,0,5.0), Vector3(-5.4,0.0,6.8)]:
		add_pine_tree(p, rng.randf_range(0.82, 1.0), throat)
	add_reeds(Vector3(-4.0,0,1.4), 4, throat)
	add_pine_needles(Vector3(0, 0.09, 4.0), Vector3(5.2, 0.05, 5.5), throat)

	for p: Vector3 in [Vector3(-6.0,0.7,9), Vector3(5.8,0.9,11), Vector3(-5.7,1.35,15), Vector3(5.9,1.65,18), Vector3(-5.8,2.2,22.5), Vector3(5.5,2.45,25.5)]:
		add_pine_tree(p, rng.randf_range(0.95, 1.18))
	add_rocks(Vector3(-4.2, 0.8, 10.5))
	add_rocks(Vector3(4.3, 1.75, 19.0))
	add_fallen_log(Vector3(-3.7, 2.0, 22.0), 12.0, 3.6)

	# Optional overlook and resource pocket, safely outside the guaranteed corridor.
	add_box("OverlookShelf", Vector3(5.0, 0.45, 5.5), Vector3(5.7, 1.82, 16.5), Color(0.3, 0.3, 0.2))
	add_visual_box("OverlookTrail", Vector3(5.5, 0.08, 1.8), Vector3(3.6, 1.73, 16.0), Color(0.42, 0.34, 0.18))
	for p: Vector3 in [Vector3(5.0,2.25,15.3), Vector3(6.5,2.25,17.0), Vector3(5.8,2.25,18.1)]:
		add_resource_orb(p)
	add_overlook_marker(Vector3(6.2, 2.3, 15.2))

	add_boundary(Vector3(-8.0, 2.3, 14.0), 28.0)
	add_boundary(Vector3(8.0, 2.3, 14.0), 28.0)


func add_ramp(name_value: String, start_z: float, run: float, rise: float, start_y: float, color: Color) -> void:
	var slope_length := sqrt(run * run + rise * rise)
	var angle := -atan2(rise, run)
	var center := Vector3(0, start_y + rise * 0.5 - 0.22, start_z + run * 0.5)
	add_box(name_value, Vector3(14.0, 0.45, slope_length), center, color, Vector3(angle, 0, 0))


func add_pine_tree(p: Vector3, s: float, parent: Node = self) -> void:
	var root := Node3D.new()
	root.name = "LongleafPine"
	root.position = p
	root.scale = Vector3.ONE * s
	parent.add_child(root)
	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.16
	tm.bottom_radius = 0.3
	tm.height = 6.2
	tm.radial_segments = 7
	trunk.mesh = tm
	trunk.position.y = 3.1
	trunk.material_override = material(Color(0.24, 0.13, 0.055))
	root.add_child(trunk)
	for offset: Vector3 in [Vector3(0,6.1,0), Vector3(-0.55,5.65,0.15), Vector3(0.55,5.75,-0.2)]:
		var crown := MeshInstance3D.new()
		var cm := SphereMesh.new()
		cm.radius = 1.05
		cm.height = 1.7
		cm.radial_segments = 7
		cm.rings = 5
		crown.mesh = cm
		crown.position = offset
		crown.scale = Vector3(0.85, 0.62, 0.85)
		crown.material_override = material(Color(0.08, 0.22, 0.085))
		root.add_child(crown)


func add_pine_needles(p: Vector3, size: Vector3, parent: Node = self) -> void:
	var patch := MeshInstance3D.new()
	patch.name = "PineNeedlePatch"
	patch.position = p
	var mesh := BoxMesh.new()
	mesh.size = size
	patch.mesh = mesh
	patch.material_override = material(Color(0.28, 0.24, 0.1))
	parent.add_child(patch)


func add_resource_orb(p: Vector3) -> void:
	var orb := MeshInstance3D.new()
	orb.name = "RidgeResource"
	orb.position = p
	var mesh := SphereMesh.new()
	mesh.radius = 0.24
	mesh.height = 0.48
	mesh.radial_segments = 9
	mesh.rings = 6
	orb.mesh = mesh
	var mat := material(Color(0.8, 0.88, 0.38))
	mat.emission_enabled = true
	mat.emission = Color(0.8, 0.88, 0.38)
	mat.emission_energy_multiplier = 1.2
	orb.material_override = mat
	add_child(orb)


func add_overlook_marker(p: Vector3) -> void:
	var marker := Label3D.new()
	marker.name = "WetlandOverlook"
	marker.position = p
	marker.text = "WETLAND OVERLOOK"
	marker.font_size = 20
	marker.pixel_size = 0.007
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.modulate = Color(0.8, 0.88, 0.38)
	marker.outline_size = 4
	add_child(marker)


func add_boardwalk(center: Vector3, count: int, yaw: float) -> void:
	var root := Node3D.new()
	root.position = center
	root.rotation_degrees.y = yaw
	add_child(root)
	for i: int in range(count):
		var body := StaticBody3D.new()
		body.position.z = (float(i) - float(count - 1) * 0.5) * 1.1
		root.add_child(body)
		add_box_parts(body, Vector3(3.4, 0.18, 0.9), Color(0.31, 0.19, 0.09))


func add_tree(p: Vector3, s: float, parent: Node = self) -> void:
	var root := Node3D.new()
	root.name = "WetlandTree"
	root.position = p
	root.scale = Vector3.ONE * s
	parent.add_child(root)
	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.28
	tm.bottom_radius = 0.48
	tm.height = 4.8
	tm.radial_segments = 7
	trunk.mesh = tm
	trunk.position.y = 2.4
	trunk.material_override = material(Color(0.2, 0.11, 0.055))
	root.add_child(trunk)
	for offset: Vector3 in [Vector3(0,5,0), Vector3(-0.8,4.7,0.2), Vector3(0.75,4.8,-0.35)]:
		var canopy := MeshInstance3D.new()
		var cm := SphereMesh.new()
		cm.radius = 1.35
		cm.height = 2.4
		cm.radial_segments = 7
		cm.rings = 5
		canopy.mesh = cm
		canopy.position = offset
		canopy.scale = Vector3(1,0.78,1)
		canopy.material_override = material(Color(0.09,0.25,0.12))
		root.add_child(canopy)


func add_fallen_log(p: Vector3, yaw: float, length: float) -> void:
	var body := StaticBody3D.new()
	body.position = p
	body.rotation_degrees = Vector3(0, yaw, 90)
	add_child(body)
	add_cylinder_parts(body, 0.42, length, Color(0.22,0.12,0.055))


func add_boundary(p: Vector3, length: float) -> void:
	var body := StaticBody3D.new()
	body.position = p
	body.rotation_degrees.z = 90
	add_child(body)
	add_cylinder_parts(body, 0.65, length, Color(0.16,0.09,0.04))


func add_reeds(center: Vector3, count: int, parent: Node = self) -> void:
	for i: int in range(count):
		var reed := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.025
		mesh.bottom_radius = 0.04
		mesh.height = rng.randf_range(0.7,1.3)
		mesh.radial_segments = 5
		reed.mesh = mesh
		reed.position = center + Vector3(rng.randf_range(-0.8,0.8), mesh.height * 0.5, rng.randf_range(-0.8,0.8))
		reed.material_override = material(Color(0.29,0.39,0.12))
		parent.add_child(reed)


func add_ruin_gate(p: Vector3) -> void:
	for side: float in [-1.0, 1.0]:
		add_box("RuinPillar", Vector3(0.65,2.6,0.75), p + Vector3(0,1.3,side * 1.4), Color(0.34,0.35,0.29))
	add_box("RuinLintel", Vector3(0.65,0.55,3.5), p + Vector3(0,2.55,0), Color(0.34,0.35,0.29))


func add_rocks(center: Vector3) -> void:
	for i: int in range(3):
		var body := StaticBody3D.new()
		body.name = "AuthoredRock"
		body.position = center + Vector3(float(i - 1) * 0.75, 0.35, sin(float(i)) * 0.45)
		add_child(body)
		add_sphere_parts(body, 0.45 + float(i) * 0.12, Color(0.29,0.31,0.27))


func add_box(name_value: String, size: Vector3, p: Vector3, color: Color, rotation_value: Vector3 = Vector3.ZERO) -> void:
	var body := StaticBody3D.new()
	body.name = name_value
	body.position = p
	body.rotation = rotation_value
	add_child(body)
	add_box_parts(body, size, color)


func add_visual_box(name_value: String, size: Vector3, p: Vector3, color: Color, transparent := false) -> void:
	var node := MeshInstance3D.new()
	node.name = name_value
	node.position = p
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material(color, transparent)
	add_child(node)


func add_box_parts(body: StaticBody3D, size: Vector3, color: Color) -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = material(color)
	body.add_child(visual)


func add_cylinder_parts(body: StaticBody3D, radius: float, height: float, color: Color) -> void:
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	collision.shape = shape
	body.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.85
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	visual.mesh = mesh
	visual.material_override = material(color)
	body.add_child(visual)


func add_sphere_parts(body: StaticBody3D, radius: float, color: Color) -> void:
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius
	collision.shape = shape
	body.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 1.5
	mesh.radial_segments = 7
	mesh.rings = 5
	visual.mesh = mesh
	visual.scale = Vector3(1.25,0.75,1)
	visual.material_override = material(color)
	body.add_child(visual)


func material(color: Color, transparent := false) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.88
	if transparent or color.a < 0.99:
		result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return result