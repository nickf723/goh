extends Node3D
class_name TrainingProxyWeaponRig

var weapon: WeaponDefinition
var controller: WeaponController


func configure_weapon(new_weapon: WeaponDefinition, new_controller: WeaponController) -> void:
	weapon = new_weapon
	controller = new_controller
	_build_visual()


func _build_visual() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	if weapon == null:
		return
	match weapon.weapon_class:
		"axe":
			_build_axe()
		"bow":
			_build_bow()
		"mace":
			_build_mace()
		"daggers":
			_build_daggers()
		"gauntlets":
			_build_gauntlets()
		"flail":
			_build_flail()
		"halberd":
			_build_halberd()
		"boomerang":
			_build_boomerang()
		"scythe":
			_build_scythe()
		"staff":
			_build_staff()
		"shuriken":
			_build_shuriken()
		_:
			_build_training_blade()


func _build_training_blade() -> void:
	_add_box("Grip", Vector3(0.09, 0.09, 0.42), Vector3(0, 0, 0.16), weapon.visual_secondary_color)
	_add_box("Guard", Vector3(0.48, 0.08, 0.09), Vector3(0, 0, -0.05), weapon.visual_accent_color, Vector3.ZERO, true)
	_add_box("Blade", Vector3(0.11, 0.055, 1.3), Vector3(0, 0, -0.75), weapon.visual_primary_color, Vector3.ZERO, true)


func _build_axe() -> void:
	_add_cylinder("Haft", 0.055, 1.65, Vector3(0, 0, -0.48), weapon.visual_secondary_color)
	_add_box("AxeHead", Vector3(0.78, 0.12, 0.48), Vector3(-0.22, 0, -1.28), weapon.visual_primary_color, Vector3(0, 0, -18), true)
	_add_box("AxeEdge", Vector3(0.48, 0.08, 0.12), Vector3(-0.46, 0, -1.43), weapon.visual_accent_color, Vector3(0, 0, -18), true)


func _build_bow() -> void:
	_add_box("BowGrip", Vector3(0.11, 0.12, 0.42), Vector3.ZERO, weapon.visual_secondary_color)
	_add_box("UpperLimb", Vector3(0.08, 0.08, 1.05), Vector3(0.28, 0, -0.62), weapon.visual_primary_color, Vector3(0, 20, 0), true)
	_add_box("LowerLimb", Vector3(0.08, 0.08, 1.05), Vector3(-0.28, 0, 0.62), weapon.visual_primary_color, Vector3(0, 20, 0), true)
	_add_box("String", Vector3(0.025, 0.025, 2.1), Vector3(0, 0.02, 0), weapon.visual_accent_color, Vector3.ZERO, true)


func _build_mace() -> void:
	_add_cylinder("Handle", 0.055, 1.2, Vector3(0, 0, -0.34), weapon.visual_secondary_color)
	_add_sphere("Head", 0.34, Vector3(0, 0, -1.08), weapon.visual_primary_color, true)
	for angle: float in [0.0, 90.0, 180.0, 270.0]:
		var radians: float = deg_to_rad(angle)
		_add_box(
			"Flange" + str(int(angle)),
			Vector3(0.09, 0.18, 0.42),
			Vector3(cos(radians) * 0.25, sin(radians) * 0.25, -1.08),
			weapon.visual_accent_color,
			Vector3(0, 0, angle),
			true
		)


func _build_daggers() -> void:
	_add_box("RightGrip", Vector3(0.08, 0.08, 0.28), Vector3(0.12, 0, 0.12), weapon.visual_secondary_color)
	_add_box("RightBlade", Vector3(0.08, 0.045, 0.78), Vector3(0.12, 0, -0.42), weapon.visual_primary_color, Vector3(0, 0, -8), true)
	_add_box("LeftGrip", Vector3(0.08, 0.08, 0.28), Vector3(-0.18, 0.08, 0.16), weapon.visual_secondary_color)
	_add_box("LeftBlade", Vector3(0.08, 0.045, 0.72), Vector3(-0.22, 0.08, -0.38), weapon.visual_accent_color, Vector3(0, 0, 14), true)


func _build_gauntlets() -> void:
	_add_box("Forearm", Vector3(0.34, 0.34, 0.62), Vector3(0, 0, 0.02), weapon.visual_secondary_color)
	_add_box("Fist", Vector3(0.48, 0.42, 0.48), Vector3(0, 0, -0.48), weapon.visual_primary_color, Vector3.ZERO, true)
	_add_box("Knuckles", Vector3(0.56, 0.16, 0.14), Vector3(0, -0.12, -0.76), weapon.visual_accent_color, Vector3.ZERO, true)


func _build_flail() -> void:
	_add_cylinder("Handle", 0.06, 0.8, Vector3(0, 0, -0.18), weapon.visual_secondary_color)
	for index: int in range(5):
		_add_sphere(
			"ChainLink" + str(index),
			0.075,
			Vector3(0.05 * sin(index), 0, -0.62 - float(index) * 0.18),
			weapon.visual_accent_color
		)
	_add_sphere("Weight", 0.28, Vector3(0.02, 0, -1.58), weapon.visual_primary_color, true)


func _build_halberd() -> void:
	_add_cylinder("Shaft", 0.05, 2.1, Vector3(0, 0, -0.72), weapon.visual_secondary_color)
	_add_cone("Point", 0.16, 0.6, Vector3(0, 0, -1.98), weapon.visual_primary_color)
	_add_box("HookBlade", Vector3(0.7, 0.09, 0.38), Vector3(-0.28, 0, -1.72), weapon.visual_accent_color, Vector3(0, 0, -20), true)


func _build_boomerang() -> void:
	_add_box("WingA", Vector3(0.11, 0.08, 0.9), Vector3(-0.22, 0, -0.3), weapon.visual_primary_color, Vector3(0, 32, 0), true)
	_add_box("WingB", Vector3(0.11, 0.08, 0.9), Vector3(0.22, 0, -0.3), weapon.visual_primary_color, Vector3(0, -32, 0), true)
	_add_sphere("GripJoint", 0.13, Vector3(0, 0, 0.02), weapon.visual_accent_color, true)


func _build_scythe() -> void:
	_add_cylinder("Shaft", 0.05, 2.0, Vector3(0, 0, -0.62), weapon.visual_secondary_color)
	_add_box("BladeRoot", Vector3(0.65, 0.07, 0.16), Vector3(-0.28, 0, -1.62), weapon.visual_primary_color, Vector3(0, 0, -12), true)
	_add_box("BladeMid", Vector3(0.75, 0.065, 0.14), Vector3(-0.78, 0, -1.46), weapon.visual_primary_color, Vector3(0, 0, 28), true)
	_add_box("BladeTip", Vector3(0.5, 0.05, 0.1), Vector3(-1.15, 0, -1.18), weapon.visual_accent_color, Vector3(0, 0, 52), true)


func _build_staff() -> void:
	_add_cylinder("Staff", 0.055, 2.15, Vector3(0, 0, -0.62), weapon.visual_primary_color)
	_add_torus("TopRing", 0.2, 0.29, Vector3(0, 0, -1.74), weapon.visual_accent_color)
	_add_sphere("Focus", 0.14, Vector3(0, 0, -1.74), weapon.visual_secondary_color, true)
	_add_torus("LowerRing", 0.12, 0.18, Vector3(0, 0, 0.4), weapon.visual_accent_color)


func _build_shuriken() -> void:
	for angle: float in [0.0, 45.0, 90.0, 135.0]:
		_add_box(
			"Blade" + str(int(angle)),
			Vector3(0.08, 0.055, 0.86),
			Vector3.ZERO,
			weapon.visual_primary_color,
			Vector3(0, 0, angle),
			true
		)
	_add_torus("Center", 0.12, 0.2, Vector3.ZERO, weapon.visual_accent_color)


func _add_box(
	node_name: String,
	size: Vector3,
	position_value: Vector3,
	color: Color,
	rotation_value: Vector3 = Vector3.ZERO,
	emissive: bool = false
) -> void:
	var part := MeshInstance3D.new()
	part.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.position = position_value
	part.rotation_degrees = rotation_value
	part.material_override = _material(color, emissive)
	add_child(part)


func _add_cylinder(
	node_name: String,
	radius: float,
	height: float,
	position_value: Vector3,
	color: Color
) -> void:
	var part := MeshInstance3D.new()
	part.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	part.mesh = mesh
	part.position = position_value
	part.rotation_degrees.x = 90.0
	part.material_override = _material(color, false)
	add_child(part)


func _add_cone(
	node_name: String,
	radius: float,
	height: float,
	position_value: Vector3,
	color: Color
) -> void:
	var part := MeshInstance3D.new()
	part.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	part.mesh = mesh
	part.position = position_value
	part.rotation_degrees.x = 90.0
	part.material_override = _material(color, true)
	add_child(part)


func _add_sphere(
	node_name: String,
	radius: float,
	position_value: Vector3,
	color: Color,
	emissive: bool = false
) -> void:
	var part := MeshInstance3D.new()
	part.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 6
	part.mesh = mesh
	part.position = position_value
	part.material_override = _material(color, emissive)
	add_child(part)


func _add_torus(
	node_name: String,
	inner_radius: float,
	outer_radius: float,
	position_value: Vector3,
	color: Color
) -> void:
	var part := MeshInstance3D.new()
	part.name = node_name
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 12
	mesh.ring_segments = 8
	part.mesh = mesh
	part.position = position_value
	part.rotation_degrees.x = 90.0
	part.material_override = _material(color, true)
	add_child(part)


func _material(color: Color, emissive: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.5
	material.roughness = 0.34
	if emissive:
		material.emission_enabled = true
		material.emission = Color(color.r, color.g, color.b, 1.0)
		material.emission_energy_multiplier = 0.75
	return material


func get_debug_data() -> Dictionary:
	return {
		"training_proxy_rig": true,
		"weapon_class": weapon.weapon_class if weapon != null else "none",
		"part_count": get_child_count(),
	}
