extends Area3D
class_name WeaponRack

@export var weapon: WeaponDefinition
@export var prompt_text: String = "Equip Weapon"
@export var rack_label_height: float = 1.55

@onready var preview_root: Node3D = get_node_or_null("PreviewRoot")
@onready var label: Label3D = get_node_or_null("WeaponLabel")


func _ready() -> void:
	add_to_group("debuggable")
	refresh_rack()


func interact() -> Dictionary:
	if weapon == null:
		return {
			"message": "The rack is empty.",
			"objective": "Choose a stocked weapon rack.",
		}

	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return {
			"message": "No player can equip " + weapon.display_name + ".",
			"objective": "",
		}

	var controller: Node = player.get_node_or_null("WeaponController")
	if controller == null or not controller.has_method("equip_weapon"):
		return {
			"message": "Grace has no weapon controller.",
			"objective": "",
		}

	controller.call("equip_weapon", weapon)
	return {
		"message": "Grace equips " + weapon.display_name + ".",
		"objective": "Test Light chains and branch into Heavy finishers.",
	}


func refresh_rack() -> void:
	if label != null:
		label.position.y = rack_label_height
		label.text = weapon.display_name if weapon != null else "EMPTY RACK"
		if weapon != null:
			label.modulate = weapon.visual_accent_color

	if preview_root == null:
		return

	for child: Node in preview_root.get_children():
		preview_root.remove_child(child)
		child.queue_free()

	if weapon == null:
		return

	match weapon.weapon_class:
		"hammer":
			build_hammer_preview()
		"lance":
			build_spear_preview()
		_:
			build_sword_preview()


func build_sword_preview() -> void:
	add_box(Vector3(0.08, 0.08, 0.35), Vector3(0, 0, 0.18), weapon.visual_secondary_color)
	add_box(Vector3(0.42, 0.07, 0.08), Vector3(0, 0, -0.04), weapon.visual_accent_color, true)
	add_box(Vector3(0.1, 0.05, 1.15), Vector3(0, 0, -0.66), weapon.visual_primary_color, true)


func build_hammer_preview() -> void:
	add_box(Vector3(0.1, 0.1, 1.2), Vector3(0, 0, -0.35), weapon.visual_secondary_color)
	add_box(Vector3(0.72, 0.38, 0.34), Vector3(0, 0, -0.92), weapon.visual_primary_color)
	add_box(Vector3(0.78, 0.1, 0.39), Vector3(0, 0, -0.92), weapon.visual_accent_color, true)


func build_spear_preview() -> void:
	add_box(Vector3(0.07, 0.07, 1.75), Vector3(0, 0, -0.62), weapon.visual_secondary_color)
	add_cone(0.16, 0.0, 0.54, Vector3(0, 0, -1.7), weapon.visual_primary_color)
	add_box(Vector3(0.2, 0.1, 0.14), Vector3(0, 0, -1.42), weapon.visual_accent_color, true)


func add_box(size: Vector3, local_position: Vector3, color: Color, emissive: bool = false) -> void:
	var part: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.position = local_position
	part.material_override = create_material(color, emissive)
	preview_root.add_child(part)


func add_cone(bottom_radius: float, top_radius: float, height: float, local_position: Vector3, color: Color) -> void:
	var part: MeshInstance3D = MeshInstance3D.new()
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.bottom_radius = bottom_radius
	mesh.top_radius = top_radius
	mesh.height = height
	mesh.radial_segments = 10
	part.mesh = mesh
	part.position = local_position
	part.rotation_degrees = Vector3(90, 0, 0)
	part.material_override = create_material(color, true)
	preview_root.add_child(part)


func create_material(color: Color, emissive: bool = false) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.4
	material.roughness = 0.4

	if emissive:
		material.emission_enabled = true
		material.emission = Color(color.r, color.g, color.b, 1.0)
		material.emission_energy_multiplier = 0.7

	return material


func get_debug_data() -> Dictionary:
	return {
		"rack": weapon.display_name if weapon != null else "empty",
		"class": weapon.weapon_class if weapon != null else "none",
	}
