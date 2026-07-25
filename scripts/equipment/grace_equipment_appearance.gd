extends Node
class_name GraceEquipmentAppearance

const OUTFIT_SLOT: String = "outfit"
const CLOTH_PATHS: Array[String] = [
	"BodyRoot/RobeSkirt",
	"BodyRoot/Torso",
	"LeftShoulderPivot/LeftArm",
	"RightShoulderPivot/RightArm",
]
const ACCENT_PATHS: Array[String] = [
	"BodyRoot/WaistSash",
	"SashTailPivot/SashTail",
	"HeadRoot/HairRibbon",
]
const TRIM_PATHS: Array[String] = [
	"BodyRoot/Collar",
	"BodyRoot/Brooch",
	"BodyRoot/SashKnot",
	"LeftShoulderPivot/LeftCuff",
	"RightShoulderPivot/RightCuff",
]

var visual_root: Node3D
var accessory_root: Node3D
var original_materials: Dictionary = {}
var current_outfit_id: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visual_root = get_parent().get_node_or_null("GraceVisualV1/VisualRoot") as Node3D
	if visual_root == null:
		push_warning("GraceEquipmentAppearance could not find GraceVisualV1/VisualRoot.")
		return

	cache_original_materials()
	accessory_root = Node3D.new()
	accessory_root.name = "EquippedOutfitPieces"
	visual_root.add_child(accessory_root)

	if not GameState.equipment_changed.is_connected(_on_equipment_changed):
		GameState.equipment_changed.connect(_on_equipment_changed)
	apply_outfit(GameState.get_equipped_item(OUTFIT_SLOT))


func _exit_tree() -> void:
	if GameState != null and GameState.equipment_changed.is_connected(_on_equipment_changed):
		GameState.equipment_changed.disconnect(_on_equipment_changed)


func _on_equipment_changed(slot_id: String, item_id: String) -> void:
	if slot_id == OUTFIT_SLOT:
		apply_outfit(item_id)


func apply_outfit(outfit_id: String) -> void:
	if visual_root == null:
		return
	current_outfit_id = outfit_id
	clear_accessory_pieces()
	restore_original_materials()

	match outfit_id:
		"travelers_coat":
			apply_travelers_coat()
		"apprentice_robe":
			apply_apprentice_robe()
		"ironweave_jacket":
			apply_ironweave_jacket()
		_:
			pass


func cache_original_materials() -> void:
	for path: String in CLOTH_PATHS + ACCENT_PATHS + TRIM_PATHS:
		var mesh_instance: MeshInstance3D = visual_root.get_node_or_null(path) as MeshInstance3D
		if mesh_instance != null:
			original_materials[path] = mesh_instance.material_override


func restore_original_materials() -> void:
	for path_variant: Variant in original_materials.keys():
		var path: String = str(path_variant)
		var mesh_instance: MeshInstance3D = visual_root.get_node_or_null(path) as MeshInstance3D
		if mesh_instance != null:
			mesh_instance.material_override = original_materials[path_variant] as Material


func apply_travelers_coat() -> void:
	var cloth: StandardMaterial3D = make_material(Color(0.105, 0.255, 0.235, 1.0), 0.88)
	var accent: StandardMaterial3D = make_material(Color(0.52, 0.31, 0.13, 1.0), 0.9)
	var brass: StandardMaterial3D = make_material(Color(0.72, 0.53, 0.19, 1.0), 0.58, 0.24)
	apply_material_group(CLOTH_PATHS, cloth)
	apply_material_group(ACCENT_PATHS, accent)
	apply_material_group(TRIM_PATHS, brass)

	var body_root: Node3D = visual_root.get_node_or_null("BodyRoot") as Node3D
	if body_root == null:
		return
	add_box_piece(body_root, "LeftCoatTail", Vector3(0.24, 0.72, 0.075), Vector3(-0.19, -0.46, 0.22), Vector3(8.0, 0.0, -4.0), cloth)
	add_box_piece(body_root, "RightCoatTail", Vector3(0.24, 0.72, 0.075), Vector3(0.19, -0.46, 0.22), Vector3(8.0, 0.0, 4.0), cloth)
	add_box_piece(body_root, "LeftLapel", Vector3(0.13, 0.45, 0.055), Vector3(-0.11, 0.2, -0.265), Vector3(0.0, 0.0, -13.0), accent)
	add_box_piece(body_root, "RightLapel", Vector3(0.13, 0.45, 0.055), Vector3(0.11, 0.2, -0.265), Vector3(0.0, 0.0, 13.0), accent)


func apply_apprentice_robe() -> void:
	var cloth: StandardMaterial3D = make_material(Color(0.16, 0.12, 0.42, 1.0), 0.76)
	var accent: StandardMaterial3D = make_material(Color(0.15, 0.48, 0.68, 1.0), 0.68)
	var gold: StandardMaterial3D = make_material(Color(0.92, 0.66, 0.2, 1.0), 0.45, 0.18)
	var rune: StandardMaterial3D = make_material(Color(0.35, 0.82, 1.0, 1.0), 0.3, 0.0, Color(0.12, 0.55, 0.95, 1.0))
	apply_material_group(CLOTH_PATHS, cloth)
	apply_material_group(ACCENT_PATHS, accent)
	apply_material_group(TRIM_PATHS, gold)

	var body_root: Node3D = visual_root.get_node_or_null("BodyRoot") as Node3D
	if body_root == null:
		return
	add_cylinder_piece(body_root, "ArcaneMantle", 0.45, 0.39, 0.13, Vector3(0.0, 0.36, 0.02), gold)
	add_box_piece(body_root, "LeftRobePanel", Vector3(0.19, 0.8, 0.05), Vector3(-0.15, -0.45, -0.3), Vector3(0.0, 0.0, -3.0), accent)
	add_box_piece(body_root, "RightRobePanel", Vector3(0.19, 0.8, 0.05), Vector3(0.15, -0.45, -0.3), Vector3(0.0, 0.0, 3.0), accent)
	add_sphere_piece(body_root, "ArcaneGem", 0.085, Vector3(0.0, 0.33, -0.37), rune)


func apply_ironweave_jacket() -> void:
	var cloth: StandardMaterial3D = make_material(Color(0.15, 0.19, 0.24, 1.0), 0.86)
	var accent: StandardMaterial3D = make_material(Color(0.38, 0.09, 0.12, 1.0), 0.82)
	var steel: StandardMaterial3D = make_material(Color(0.46, 0.55, 0.62, 1.0), 0.34, 0.7)
	apply_material_group(CLOTH_PATHS, cloth)
	apply_material_group(ACCENT_PATHS, accent)
	apply_material_group(TRIM_PATHS, steel)

	var body_root: Node3D = visual_root.get_node_or_null("BodyRoot") as Node3D
	var left_shoulder: Node3D = visual_root.get_node_or_null("LeftShoulderPivot") as Node3D
	var right_shoulder: Node3D = visual_root.get_node_or_null("RightShoulderPivot") as Node3D
	if body_root != null:
		add_box_piece(body_root, "ChestPlate", Vector3(0.49, 0.43, 0.085), Vector3(0.0, 0.18, -0.275), Vector3.ZERO, steel)
		add_box_piece(body_root, "LeftWaistPlate", Vector3(0.2, 0.38, 0.07), Vector3(-0.22, -0.31, -0.25), Vector3(0.0, 0.0, -7.0), steel)
		add_box_piece(body_root, "RightWaistPlate", Vector3(0.2, 0.38, 0.07), Vector3(0.22, -0.31, -0.25), Vector3(0.0, 0.0, 7.0), steel)
	if left_shoulder != null:
		add_box_piece(left_shoulder, "LeftShoulderPlate", Vector3(0.3, 0.13, 0.38), Vector3(-0.03, 0.0, 0.0), Vector3(0.0, 0.0, -6.0), steel)
	if right_shoulder != null:
		add_box_piece(right_shoulder, "RightShoulderPlate", Vector3(0.3, 0.13, 0.38), Vector3(0.03, 0.0, 0.0), Vector3(0.0, 0.0, 6.0), steel)


func apply_material_group(paths: Array[String], material: Material) -> void:
	for path: String in paths:
		var mesh_instance: MeshInstance3D = visual_root.get_node_or_null(path) as MeshInstance3D
		if mesh_instance != null:
			mesh_instance.material_override = material


func clear_accessory_pieces() -> void:
	if accessory_root == null:
		return
	for child: Node in accessory_root.get_children():
		accessory_root.remove_child(child)
		child.queue_free()


func add_box_piece(parent_node: Node3D, piece_name: String, size: Vector3, position: Vector3, rotation: Vector3, material: Material) -> void:
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	add_mesh_piece(parent_node, piece_name, box, position, rotation, material)


func add_cylinder_piece(parent_node: Node3D, piece_name: String, top_radius: float, bottom_radius: float, height: float, position: Vector3, material: Material) -> void:
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = top_radius
	cylinder.bottom_radius = bottom_radius
	cylinder.height = height
	cylinder.radial_segments = 12
	add_mesh_piece(parent_node, piece_name, cylinder, position, Vector3.ZERO, material)


func add_sphere_piece(parent_node: Node3D, piece_name: String, radius: float, position: Vector3, material: Material) -> void:
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	add_mesh_piece(parent_node, piece_name, sphere, position, Vector3.ZERO, material)


func add_mesh_piece(parent_node: Node3D, piece_name: String, geometry: PrimitiveMesh, position: Vector3, rotation: Vector3, material: Material) -> void:
	var piece: MeshInstance3D = MeshInstance3D.new()
	piece.name = piece_name
	piece.mesh = geometry
	piece.material_override = material
	piece.position = position
	piece.rotation_degrees = rotation
	parent_node.add_child(piece)
	piece.set_meta("equipment_visual", true)
	accessory_root.add_child(piece)
	piece.reparent(parent_node, true)


func make_material(color: Color, roughness: float, metallic: float = 0.0, emission: Color = Color(0.0, 0.0, 0.0, 1.0)) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if emission.r > 0.0 or emission.g > 0.0 or emission.b > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = 1.7
	return material
