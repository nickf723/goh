extends Node3D
class_name ModularOutdoorEnvironmentPiece

const STONE_MATERIAL: Material = preload("res://art/materials/environment/modular/weathered_stone.tres")
const TRIM_STONE_MATERIAL: Material = preload("res://art/materials/environment/modular/trim_stone.tres")
const WET_STONE_MATERIAL: Material = preload("res://art/materials/environment/modular/wet_stone.tres")
const WOOD_MATERIAL: Material = preload("res://art/materials/environment/modular/aged_wood.tres")
const METAL_MATERIAL: Material = preload("res://art/materials/environment/modular/aged_metal.tres")
const MOSS_MATERIAL: Material = preload("res://art/materials/environment/modular/moss.tres")
const PLASTER_MATERIAL: Material = preload("res://art/materials/environment/modular/weathered_plaster.tres")
const EARTH_MATERIAL: Material = preload("res://art/materials/environment/modular/dry_earth.tres")
const LEAF_MATERIAL: Material = preload("res://art/materials/environment/modular/olive_leaf.tres")

@export var piece_id: String = "outdoor_modular_piece"
@export var display_name: String = "Outdoor Modular Piece"
@export_enum("architecture", "terrain", "prop", "vegetation") var category: String = "architecture"
@export_enum(
	"village_road",
	"low_wall",
	"ruined_corner",
	"ruined_facade",
	"timber_fence",
	"rubble_cluster",
	"olive_tree_cluster"
) var piece_type: String = "village_road"
@export var footprint: Vector3 = Vector3(4.0, 1.0, 4.0)
@export var requires_collision: bool = true
@export var variant_seed: int = 0
@export var build_on_ready: bool = true

var built: bool = false
var build_counts: Dictionary = {
	"colliders": 0,
	"visuals": 0,
}


func _ready() -> void:
	add_to_group("modular_environment_piece")
	add_to_group("modular_environment_" + category)
	add_to_group("modular_outdoor_environment_piece")
	set_meta("piece_id", piece_id)
	set_meta("piece_category", category)
	set_meta("collision_required", requires_collision)
	set_meta("prototype_asset_quality", "modular_outdoor_v1")
	if build_on_ready:
		build_piece()


func build_piece() -> void:
	if built:
		return
	built = true
	match piece_type:
		"low_wall":
			_build_low_wall()
		"ruined_corner":
			_build_ruined_corner()
		"ruined_facade":
			_build_ruined_facade()
		"timber_fence":
			_build_timber_fence()
		"rubble_cluster":
			_build_rubble_cluster()
		"olive_tree_cluster":
			_build_olive_tree_cluster()
		_:
			_build_village_road()
	set_meta("build_counts", build_counts.duplicate(true))


func _build_village_road() -> void:
	if requires_collision:
		_add_static_box("CollisionCore", Vector3(4.0, 0.22, 4.0), Vector3(0.0, -0.11, 0.0), EARTH_MATERIAL, Vector3.ZERO, false)
	_add_visual_box("EarthBed", Vector3(3.96, 0.08, 3.96), Vector3(0.0, 0.0, 0.0), EARTH_MATERIAL)
	for lane: int in range(2):
		for index: int in range(5):
			var seed: int = variant_seed * 17 + lane * 11 + index
			var x_value: float = -1.08 + float(lane) * 2.16 + sin(float(seed) * 1.19) * 0.10
			var z_value: float = -1.58 + float(index) * 0.79 + cos(float(seed) * 0.83) * 0.08
			var width: float = 0.66 + float(seed % 3) * 0.07
			var depth: float = 0.54 + float((seed + 1) % 3) * 0.08
			var slab_material: Material = WET_STONE_MATERIAL if seed % 6 == 0 else STONE_MATERIAL
			_add_visual_box(
				"RoadStone_%02d_%02d" % [lane, index],
				Vector3(width, 0.11, depth),
				Vector3(x_value, 0.075 + float(seed % 2) * 0.012, z_value),
				slab_material,
				Vector3(0.0, sin(float(seed) * 0.57) * 0.06, 0.0)
			)
	for side: float in [-1.0, 1.0]:
		_add_visual_box(
			"RoadEdge_%s" % ("L" if side < 0.0 else "R"),
			Vector3(0.32, 0.07, 3.9),
			Vector3(side * 1.78, 0.055, 0.0),
			MOSS_MATERIAL,
			Vector3(0.0, 0.0, side * 0.018)
		)


func _build_low_wall() -> void:
	if requires_collision:
		_add_static_box("CollisionCore", Vector3(4.0, 1.25, 0.62), Vector3(0.0, 0.625, 0.0), STONE_MATERIAL, Vector3.ZERO, false)
	_add_visual_box("WallFoot", Vector3(4.18, 0.24, 0.82), Vector3(0.0, 0.12, 0.0), TRIM_STONE_MATERIAL)
	for course: int in range(2):
		for block: int in range(5):
			var seed: int = variant_seed * 13 + course * 7 + block
			if course == 1 and block == (variant_seed % 5):
				continue
			var offset: float = 0.39 if course == 1 else 0.0
			var x_value: float = -1.63 + float(block) * 0.81 + offset
			if x_value > 1.9:
				continue
			_add_visual_box(
				"WallStone_%02d_%02d" % [course, block],
				Vector3(0.76 + sin(float(seed) * 0.7) * 0.04, 0.48, 0.68),
				Vector3(x_value, 0.48 + float(course) * 0.48, sin(float(seed)) * 0.025),
				STONE_MATERIAL,
				Vector3(0.0, sin(float(seed) * 0.91) * 0.025, sin(float(seed) * 1.27) * 0.018)
			)
	_add_visual_box("WallMoss", Vector3(1.35, 0.035, 0.68), Vector3(-0.95, 1.13, 0.0), MOSS_MATERIAL, Vector3(0.0, 0.0, -0.04))


func _build_ruined_corner() -> void:
	if requires_collision:
		_add_static_box("LongWallCollision", Vector3(4.0, 2.85, 0.58), Vector3(0.0, 1.425, -1.71), STONE_MATERIAL, Vector3.ZERO, false)
		_add_static_box("ReturnWallCollision", Vector3(0.58, 2.2, 3.45), Vector3(-1.71, 1.1, 0.0), STONE_MATERIAL, Vector3.ZERO, false)
	_add_visual_box("LongStoneBase", Vector3(4.12, 0.52, 0.76), Vector3(0.0, 0.26, -1.71), TRIM_STONE_MATERIAL)
	_add_visual_box("LongPlaster", Vector3(3.78, 2.08, 0.48), Vector3(0.0, 1.48, -1.71), PLASTER_MATERIAL, Vector3(0.0, 0.0, -0.025))
	_add_visual_box("ReturnStoneBase", Vector3(0.76, 0.52, 3.5), Vector3(-1.71, 0.26, 0.0), TRIM_STONE_MATERIAL)
	_add_visual_box("ReturnPlaster", Vector3(0.48, 1.52, 3.14), Vector3(-1.71, 1.02, 0.0), PLASTER_MATERIAL, Vector3(0.0, 0.0, 0.02))
	_add_visual_box("ExposedBeam", Vector3(3.4, 0.18, 0.2), Vector3(0.18, 2.62, -1.96), WOOD_MATERIAL, Vector3(0.0, 0.0, 0.07))
	_add_visual_box("CornerPost", Vector3(0.24, 2.7, 0.24), Vector3(-1.77, 1.35, -1.77), WOOD_MATERIAL, Vector3(0.0, 0.0, -0.04))
	_add_visual_box("CornerMoss", Vector3(0.62, 0.035, 1.45), Vector3(-1.48, 0.57, -0.62), MOSS_MATERIAL)


func _build_ruined_facade() -> void:
	var opening_width: float = 1.9
	var total_width: float = 6.0
	var pier_width: float = (total_width - opening_width) * 0.5
	if requires_collision:
		_add_static_box("LeftPierCollision", Vector3(pier_width, 3.65, 0.62), Vector3(-(opening_width + pier_width) * 0.5, 1.825, 0.0), STONE_MATERIAL, Vector3.ZERO, false)
		_add_static_box("RightPierCollision", Vector3(pier_width, 3.15, 0.62), Vector3((opening_width + pier_width) * 0.5, 1.575, 0.0), STONE_MATERIAL, Vector3.ZERO, false)
		_add_static_box("LintelCollision", Vector3(opening_width, 0.64, 0.62), Vector3(0.0, 3.33, 0.0), STONE_MATERIAL, Vector3.ZERO, false)
	_add_visual_box("StoneFoot", Vector3(6.18, 0.52, 0.82), Vector3(0.0, 0.26, 0.0), TRIM_STONE_MATERIAL)
	_add_visual_box("LeftPlaster", Vector3(pier_width - 0.16, 2.88, 0.52), Vector3(-(opening_width + pier_width) * 0.5, 1.78, 0.0), PLASTER_MATERIAL, Vector3(0.0, 0.0, -0.025))
	_add_visual_box("RightPlaster", Vector3(pier_width - 0.16, 2.38, 0.52), Vector3((opening_width + pier_width) * 0.5, 1.53, 0.0), PLASTER_MATERIAL, Vector3(0.0, 0.0, 0.028))
	_add_visual_box("DoorLintel", Vector3(opening_width + 0.42, 0.42, 0.76), Vector3(0.0, 3.14, 0.0), TRIM_STONE_MATERIAL, Vector3(0.0, 0.0, -0.025))
	_add_visual_box("LeftTimber", Vector3(0.22, 3.25, 0.18), Vector3(-2.73, 1.72, -0.34), WOOD_MATERIAL, Vector3(0.0, 0.0, -0.08))
	_add_visual_box("RightTimber", Vector3(0.22, 2.7, 0.18), Vector3(2.72, 1.43, -0.34), WOOD_MATERIAL, Vector3(0.0, 0.0, 0.06))
	_add_visual_box("BrokenTopBeam", Vector3(3.1, 0.2, 0.22), Vector3(-1.25, 3.67, -0.2), WOOD_MATERIAL, Vector3(0.0, 0.0, 0.12))
	_add_visual_box("FacadeMoss", Vector3(1.4, 0.035, 0.7), Vector3(1.78, 0.58, 0.0), MOSS_MATERIAL, Vector3(0.0, 0.0, -0.05))


func _build_timber_fence() -> void:
	if requires_collision:
		_add_static_box("CollisionCore", Vector3(4.0, 1.18, 0.22), Vector3(0.0, 0.59, 0.0), WOOD_MATERIAL, Vector3.ZERO, false)
	for index: int in range(5):
		var x_value: float = -1.72 + float(index) * 0.86
		var height: float = 1.05 + float((index + variant_seed) % 3) * 0.14
		_add_visual_box(
			"FencePost%02d" % index,
			Vector3(0.16, height, 0.18),
			Vector3(x_value, height * 0.5, 0.0),
			WOOD_MATERIAL,
			Vector3(0.0, 0.0, sin(float(index + variant_seed)) * 0.05)
		)
	_add_visual_box("UpperRail", Vector3(3.72, 0.14, 0.18), Vector3(0.0, 0.86, 0.0), WOOD_MATERIAL, Vector3(0.0, 0.0, 0.025))
	_add_visual_box("LowerRail", Vector3(3.42, 0.13, 0.18), Vector3(-0.12, 0.43, 0.0), WOOD_MATERIAL, Vector3(0.0, 0.0, -0.035))
	for index: int in range(2):
		_add_visual_cylinder("IronTie%02d" % index, 0.055, 0.055, 0.26, Vector3(-0.86 + float(index) * 1.72, 0.66, -0.12), METAL_MATERIAL, Vector3(PI * 0.5, 0.0, 0.0))


func _build_rubble_cluster() -> void:
	for index: int in range(8):
		var seed: int = variant_seed * 19 + index * 5
		var angle: float = float(index) * 2.399 + float(variant_seed) * 0.17
		var radius: float = 0.35 + float(index % 4) * 0.28
		var size := Vector3(
			0.48 + float(seed % 3) * 0.18,
			0.28 + float((seed + 1) % 3) * 0.14,
			0.5 + float((seed + 2) % 3) * 0.17
		)
		_add_visual_box(
			"RubbleStone%02d" % index,
			size,
			Vector3(cos(angle) * radius, size.y * 0.5, sin(angle) * radius),
			STONE_MATERIAL,
			Vector3(sin(float(seed)) * 0.28, angle, cos(float(seed)) * 0.22)
		)
	_add_visual_box("BrokenTimber", Vector3(2.4, 0.18, 0.22), Vector3(0.18, 0.42, -0.12), WOOD_MATERIAL, Vector3(0.08, 0.42, -0.16))
	_add_visual_box("RubbleMoss", Vector3(0.74, 0.03, 0.5), Vector3(-0.44, 0.38, 0.4), MOSS_MATERIAL, Vector3(0.0, 0.24, 0.0))


func _build_olive_tree_cluster() -> void:
	for trunk_index: int in range(2):
		var side: float = -1.0 if trunk_index == 0 else 1.0
		var trunk_height: float = 3.9 - float(trunk_index) * 0.55
		var trunk_position := Vector3(side * 0.48, trunk_height * 0.5, float(trunk_index) * 0.32 - 0.16)
		_add_visual_cylinder(
			"Trunk%02d" % trunk_index,
			0.22,
			0.32,
			trunk_height,
			trunk_position,
			WOOD_MATERIAL,
			Vector3(0.0, 0.0, side * 0.08)
		)
	for crown_index: int in range(5):
		var angle: float = float(crown_index) * TAU / 5.0 + float(variant_seed) * 0.21
		var crown_position := Vector3(cos(angle) * 1.05, 3.7 + float(crown_index % 2) * 0.55, sin(angle) * 0.78)
		_add_visual_sphere(
			"Crown%02d" % crown_index,
			1.12 + float(crown_index % 3) * 0.12,
			crown_position,
			LEAF_MATERIAL,
			Vector3(1.0, 0.72 + float(crown_index % 2) * 0.1, 0.9)
		)
	_add_visual_box("RootMoss", Vector3(1.5, 0.04, 1.1), Vector3(0.0, 0.03, 0.0), MOSS_MATERIAL, Vector3(0.0, 0.31, 0.0))


func _add_static_box(
	node_name: String,
	size: Vector3,
	position_value: Vector3,
	material_value: Material,
	rotation_value: Vector3 = Vector3.ZERO,
	visible_mesh: bool = true
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	body.rotation = rotation_value
	body.set_meta("modular_piece_owner", piece_id)
	add_child(body)
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	build_counts["colliders"] = int(build_counts["colliders"]) + 1
	if visible_mesh:
		var visual := _make_box_mesh(node_name + "Visual", size, Vector3.ZERO, material_value, Vector3.ZERO)
		body.add_child(visual)
	return body


func _add_visual_box(
	node_name: String,
	size: Vector3,
	position_value: Vector3,
	material_value: Material,
	rotation_value: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var visual := _make_box_mesh(node_name, size, position_value, material_value, rotation_value)
	add_child(visual)
	return visual


func _make_box_mesh(
	node_name: String,
	size: Vector3,
	position_value: Vector3,
	material_value: Material,
	rotation_value: Vector3
) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.position = position_value
	visual.rotation = rotation_value
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = material_value
	visual.set_meta("modular_piece_owner", piece_id)
	build_counts["visuals"] = int(build_counts["visuals"]) + 1
	return visual


func _add_visual_cylinder(
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
	visual.set_meta("modular_piece_owner", piece_id)
	add_child(visual)
	build_counts["visuals"] = int(build_counts["visuals"]) + 1
	return visual


func _add_visual_sphere(
	node_name: String,
	radius: float,
	position_value: Vector3,
	material_value: Material,
	scale_value: Vector3 = Vector3.ONE
) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.position = position_value
	visual.scale = scale_value
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 8
	visual.mesh = mesh
	visual.material_override = material_value
	visual.set_meta("modular_piece_owner", piece_id)
	add_child(visual)
	build_counts["visuals"] = int(build_counts["visuals"]) + 1
	return visual


func get_collision_shape_count() -> int:
	return _count_collision_shapes(self)


func _count_collision_shapes(node: Node) -> int:
	var count: int = 1 if node is CollisionShape3D else 0
	for child: Node in node.get_children():
		count += _count_collision_shapes(child)
	return count


func get_debug_data() -> Dictionary:
	return {
		"piece_id": piece_id,
		"display_name": display_name,
		"category": category,
		"piece_type": piece_type,
		"footprint": footprint,
		"requires_collision": requires_collision,
		"built": built,
		"counts": build_counts.duplicate(true),
	}
