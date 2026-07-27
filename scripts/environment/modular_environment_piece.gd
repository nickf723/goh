extends Node3D
class_name ModularEnvironmentPiece

const STONE_MATERIAL: Material = preload("res://art/materials/environment/modular/weathered_stone.tres")
const TRIM_STONE_MATERIAL: Material = preload("res://art/materials/environment/modular/trim_stone.tres")
const WET_STONE_MATERIAL: Material = preload("res://art/materials/environment/modular/wet_stone.tres")
const WOOD_MATERIAL: Material = preload("res://art/materials/environment/modular/aged_wood.tres")
const METAL_MATERIAL: Material = preload("res://art/materials/environment/modular/aged_metal.tres")
const MOSS_MATERIAL: Material = preload("res://art/materials/environment/modular/moss.tres")
const WARM_GLOW_MATERIAL: Material = preload("res://art/materials/environment/modular/warm_glow.tres")
const WATER_MATERIAL: Material = preload("res://art/materials/environment/modular/weathered_water.tres")

@export var piece_id: String = "modular_piece"
@export var display_name: String = "Modular Environment Piece"
@export_enum("architecture", "prop", "lighting", "water") var category: String = "architecture"
@export_enum(
	"stone_floor",
	"stone_wall",
	"stone_arch",
	"stone_stairs",
	"stone_pillar",
	"timber_frame",
	"stone_pedestal",
	"crate",
	"barrel",
	"wall_sconce",
	"water_channel"
) var piece_type: String = "stone_floor"
@export var footprint: Vector3 = Vector3(4.0, 1.0, 4.0)
@export var requires_collision: bool = true
@export var variant_seed: int = 0
@export var build_on_ready: bool = true

var built: bool = false
var build_counts: Dictionary = {
	"colliders": 0,
	"visuals": 0,
	"lights": 0,
}


func _ready() -> void:
	add_to_group("modular_environment_piece")
	add_to_group("modular_environment_" + category)
	set_meta("piece_id", piece_id)
	set_meta("piece_category", category)
	set_meta("collision_required", requires_collision)
	set_meta("prototype_asset_quality", "modular_v1")
	if build_on_ready:
		build_piece()


func build_piece() -> void:
	if built:
		return
	built = true
	match piece_type:
		"stone_wall":
			_build_stone_wall()
		"stone_arch":
			_build_stone_arch()
		"stone_stairs":
			_build_stone_stairs()
		"stone_pillar":
			_build_stone_pillar()
		"timber_frame":
			_build_timber_frame()
		"stone_pedestal":
			_build_stone_pedestal()
		"crate":
			_build_crate()
		"barrel":
			_build_barrel()
		"wall_sconce":
			_build_wall_sconce()
		"water_channel":
			_build_water_channel()
		_:
			_build_stone_floor()
	set_meta("build_counts", build_counts.duplicate(true))


func _build_stone_floor() -> void:
	_add_static_box("CollisionCore", Vector3(4.0, 0.42, 4.0), Vector3(0.0, -0.21, 0.0), STONE_MATERIAL, Vector3.ZERO, false)
	for x_index: int in range(4):
		for z_index: int in range(4):
			var index: int = x_index * 4 + z_index + variant_seed * 7
			var offset_x: float = sin(float(index) * 1.73) * 0.055
			var offset_z: float = cos(float(index) * 1.21) * 0.055
			var height: float = 0.11 + float((index + 2) % 3) * 0.018
			var slab_material: Material = WET_STONE_MATERIAL if (index + variant_seed) % 5 == 0 else STONE_MATERIAL
			_add_visual_box(
				"Slab_%02d_%02d" % [x_index, z_index],
				Vector3(0.93, height, 0.93),
				Vector3(-1.48 + float(x_index) * 0.99 + offset_x, height * 0.5 + 0.015, -1.48 + float(z_index) * 0.99 + offset_z),
				slab_material,
				Vector3(0.0, sin(float(index) * 0.9) * 0.018, 0.0)
			)
	for side: float in [-1.0, 1.0]:
		_add_visual_box("EdgeX_%s" % ("L" if side < 0.0 else "R"), Vector3(0.16, 0.16, 4.08), Vector3(side * 1.94, 0.08, 0.0), TRIM_STONE_MATERIAL)
		_add_visual_box("EdgeZ_%s" % ("N" if side < 0.0 else "S"), Vector3(4.08, 0.16, 0.16), Vector3(0.0, 0.08, side * 1.94), TRIM_STONE_MATERIAL)
	_add_visual_box("MossPatchA", Vector3(0.72, 0.025, 0.26), Vector3(-1.45, 0.145, 1.48), MOSS_MATERIAL, Vector3(0.0, -0.22, 0.0))
	_add_visual_box("MossPatchB", Vector3(0.42, 0.022, 0.2), Vector3(1.55, 0.142, -1.4), MOSS_MATERIAL, Vector3(0.0, 0.35, 0.0))


func _build_stone_wall() -> void:
	_add_static_box("CollisionCore", Vector3(4.0, 3.2, 0.48), Vector3(0.0, 1.6, 0.0), STONE_MATERIAL, Vector3.ZERO, false)
	for course: int in range(4):
		var course_offset: float = 0.46 if course % 2 == 1 else 0.0
		for block: int in range(5):
			var x_value: float = -1.82 + float(block) * 0.91 + course_offset
			if x_value > 2.02:
				continue
			var index: int = course * 5 + block + variant_seed * 3
			var width: float = 0.84 + sin(float(index) * 1.41) * 0.045
			var block_material: Material = WET_STONE_MATERIAL if index % 7 == 0 else STONE_MATERIAL
			_add_visual_box(
				"Masonry_%02d_%02d" % [course, block],
				Vector3(width, 0.68, 0.56),
				Vector3(x_value, 0.39 + float(course) * 0.75, sin(float(index) * 0.7) * 0.025),
				block_material,
				Vector3(0.0, sin(float(index) * 0.67) * 0.018, sin(float(index) * 1.11) * 0.012)
			)
	_add_visual_box("WallBase", Vector3(4.25, 0.28, 0.76), Vector3(0.0, 0.14, 0.0), TRIM_STONE_MATERIAL)
	_add_visual_box("WallCap", Vector3(4.3, 0.32, 0.74), Vector3(0.0, 3.12, 0.0), TRIM_STONE_MATERIAL)
	for side: float in [-1.0, 1.0]:
		_add_visual_box("Pilaster_%s" % ("L" if side < 0.0 else "R"), Vector3(0.36, 3.35, 0.72), Vector3(side * 1.91, 1.67, -0.01), TRIM_STONE_MATERIAL)
	_add_visual_box("MossCreep", Vector3(1.45, 0.05, 0.65), Vector3(-0.9, 0.32, -0.32), MOSS_MATERIAL, Vector3(0.0, 0.0, 0.04))


func _build_stone_arch() -> void:
	_add_static_box("LeftCollision", Vector3(0.76, 2.7, 0.7), Vector3(-1.68, 1.35, 0.0), STONE_MATERIAL, Vector3.ZERO, false)
	_add_static_box("RightCollision", Vector3(0.76, 2.7, 0.7), Vector3(1.68, 1.35, 0.0), STONE_MATERIAL, Vector3.ZERO, false)
	_add_static_box("TopCollision", Vector3(4.1, 0.72, 0.7), Vector3(0.0, 3.43, 0.0), STONE_MATERIAL, Vector3.ZERO, false)
	for side: float in [-1.0, 1.0]:
		for course: int in range(4):
			_add_visual_box(
				"Pier_%s_%02d" % [("L" if side < 0.0 else "R"), course],
				Vector3(0.72, 0.66, 0.78),
				Vector3(side * 1.68, 0.36 + float(course) * 0.69, 0.0),
				STONE_MATERIAL,
				Vector3(0.0, side * 0.012 * float(course % 2), 0.0)
			)
		_add_visual_box("Foot_%s" % ("L" if side < 0.0 else "R"), Vector3(1.02, 0.28, 0.95), Vector3(side * 1.68, 0.14, 0.0), TRIM_STONE_MATERIAL)
	for segment: int in range(9):
		var angle: float = PI - float(segment) * PI / 8.0
		var x_value: float = cos(angle) * 1.56
		var y_value: float = 2.38 + sin(angle) * 1.05
		_add_visual_box(
			"ArchStone%02d" % segment,
			Vector3(0.55, 0.4, 0.82),
			Vector3(x_value, y_value, 0.0),
			TRIM_STONE_MATERIAL,
			Vector3(0.0, 0.0, -(angle - PI * 0.5))
		)
	_add_visual_box("Keystone", Vector3(0.62, 0.56, 0.9), Vector3(0.0, 3.5, -0.01), TRIM_STONE_MATERIAL)
	_add_visual_box("ArchMoss", Vector3(0.5, 0.04, 0.72), Vector3(-1.18, 3.14, -0.39), MOSS_MATERIAL, Vector3(0.0, 0.0, -0.32))


func _build_stone_stairs() -> void:
	var step_count: int = 6
	var step_run: float = 0.62
	var step_rise: float = 0.25
	for index: int in range(step_count):
		var height: float = step_rise * float(index + 1)
		var z_value: float = -1.55 + step_run * float(index)
		_add_static_box(
			"Step%02d" % index,
			Vector3(4.0, height, step_run + 0.04),
			Vector3(0.0, height * 0.5, z_value),
			WET_STONE_MATERIAL
		)
		_add_visual_box("RiserTrim%02d" % index, Vector3(4.12, 0.09, 0.07), Vector3(0.0, height - 0.045, z_value - step_run * 0.46), TRIM_STONE_MATERIAL)
	for side: float in [-1.0, 1.0]:
		_add_visual_box("Cheek_%s" % ("L" if side < 0.0 else "R"), Vector3(0.3, 1.65, 3.95), Vector3(side * 2.08, 0.82, -0.02), TRIM_STONE_MATERIAL, Vector3(-0.17, 0.0, 0.0))
	_add_visual_box("StairMoss", Vector3(0.62, 0.035, 1.1), Vector3(-1.55, 1.53, 1.22), MOSS_MATERIAL, Vector3(0.0, 0.18, 0.0))


func _build_stone_pillar() -> void:
	_add_static_cylinder("CollisionShaft", 0.42, 2.75, Vector3(0.0, 1.5, 0.0), STONE_MATERIAL, Vector3.ZERO, false)
	_add_visual_box("BaseLower", Vector3(1.25, 0.24, 1.25), Vector3(0.0, 0.12, 0.0), TRIM_STONE_MATERIAL)
	_add_visual_box("BaseUpper", Vector3(0.98, 0.26, 0.98), Vector3(0.0, 0.37, 0.0), STONE_MATERIAL)
	_add_visual_cylinder("Shaft", 0.38, 0.43, 2.45, Vector3(0.0, 1.65, 0.0), STONE_MATERIAL)
	for ring_index: int in range(3):
		_add_visual_torus("ShaftBand%02d" % ring_index, 0.38, 0.45, Vector3(0.0, 0.72 + float(ring_index) * 0.9, 0.0), TRIM_STONE_MATERIAL)
	_add_visual_box("CapitalLower", Vector3(0.98, 0.25, 0.98), Vector3(0.0, 2.9, 0.0), STONE_MATERIAL)
	_add_visual_box("CapitalUpper", Vector3(1.35, 0.28, 1.35), Vector3(0.0, 3.16, 0.0), TRIM_STONE_MATERIAL)
	_add_visual_box("PillarMoss", Vector3(0.42, 0.04, 0.7), Vector3(0.38, 0.48, 0.05), MOSS_MATERIAL, Vector3(0.0, 0.0, 0.8))


func _build_timber_frame() -> void:
	for side: float in [-1.0, 1.0]:
		_add_static_box("Post_%s" % ("L" if side < 0.0 else "R"), Vector3(0.34, 3.2, 0.42), Vector3(side * 1.75, 1.6, 0.0), WOOD_MATERIAL)
		_add_visual_box("Brace_%s" % ("L" if side < 0.0 else "R"), Vector3(0.22, 2.65, 0.28), Vector3(side * 1.05, 1.75, 0.0), WOOD_MATERIAL, Vector3(0.0, 0.0, -side * 0.53))
		_add_visual_cylinder("IronFoot_%s" % ("L" if side < 0.0 else "R"), 0.24, 0.26, 0.16, Vector3(side * 1.75, 0.18, 0.0), METAL_MATERIAL)
	_add_static_box("Crossbeam", Vector3(4.05, 0.4, 0.5), Vector3(0.0, 3.05, 0.0), WOOD_MATERIAL)
	_add_visual_box("PegBeam", Vector3(3.5, 0.16, 0.58), Vector3(0.0, 2.67, 0.0), WOOD_MATERIAL)
	for peg: int in range(5):
		_add_visual_cylinder("Peg%02d" % peg, 0.045, 0.045, 0.64, Vector3(-1.35 + float(peg) * 0.68, 2.67, 0.0), METAL_MATERIAL, Vector3(PI * 0.5, 0.0, 0.0))


func _build_stone_pedestal() -> void:
	_add_static_box("Base", Vector3(1.75, 0.3, 1.75), Vector3(0.0, 0.15, 0.0), TRIM_STONE_MATERIAL)
	_add_static_box("LowerPlinth", Vector3(1.42, 0.35, 1.42), Vector3(0.0, 0.47, 0.0), STONE_MATERIAL)
	_add_static_box("Column", Vector3(0.92, 1.15, 0.92), Vector3(0.0, 1.22, 0.0), STONE_MATERIAL)
	_add_static_box("Cap", Vector3(1.5, 0.24, 1.5), Vector3(0.0, 1.91, 0.0), TRIM_STONE_MATERIAL)
	_add_visual_box("Inset", Vector3(0.66, 0.55, 0.04), Vector3(0.0, 1.28, -0.48), METAL_MATERIAL)
	_add_visual_box("MossLip", Vector3(0.56, 0.035, 1.12), Vector3(-0.35, 0.67, 0.0), MOSS_MATERIAL, Vector3(0.0, 0.0, 0.08))


func _build_crate() -> void:
	_add_static_box("CollisionCore", Vector3(1.35, 1.25, 1.35), Vector3(0.0, 0.625, 0.0), WOOD_MATERIAL, Vector3.ZERO, false)
	for slat: int in range(6):
		var y_value: float = 0.12 + float(slat) * 0.205
		_add_visual_box("FrontSlat%02d" % slat, Vector3(1.28, 0.16, 0.12), Vector3(0.0, y_value, -0.68), WOOD_MATERIAL)
		_add_visual_box("BackSlat%02d" % slat, Vector3(1.28, 0.16, 0.12), Vector3(0.0, y_value, 0.68), WOOD_MATERIAL)
	for side: float in [-1.0, 1.0]:
		_add_visual_box("SidePanel_%s" % ("L" if side < 0.0 else "R"), Vector3(0.12, 1.18, 1.28), Vector3(side * 0.68, 0.62, 0.0), WOOD_MATERIAL)
		_add_visual_box("Brace_%s" % ("L" if side < 0.0 else "R"), Vector3(0.13, 1.7, 0.15), Vector3(side * 0.44, 0.64, -0.75), METAL_MATERIAL, Vector3(0.0, 0.0, side * 0.65))
	_add_visual_box("Top", Vector3(1.42, 0.15, 1.42), Vector3(0.0, 1.28, 0.0), WOOD_MATERIAL)
	_add_visual_box("CornerMoss", Vector3(0.46, 0.035, 0.28), Vector3(-0.48, 1.37, 0.45), MOSS_MATERIAL)


func _build_barrel() -> void:
	_add_static_cylinder("CollisionCore", 0.62, 1.35, Vector3(0.0, 0.68, 0.0), WOOD_MATERIAL, Vector3.ZERO, false)
	_add_visual_cylinder("Body", 0.52, 0.62, 1.35, Vector3(0.0, 0.68, 0.0), WOOD_MATERIAL)
	for band_y: float in [0.2, 0.67, 1.14]:
		_add_visual_cylinder("Hoop_%s" % str(band_y).replace(".", "_"), 0.635, 0.635, 0.09, Vector3(0.0, band_y, 0.0), METAL_MATERIAL)
	_add_visual_cylinder("TopCap", 0.5, 0.5, 0.08, Vector3(0.0, 1.39, 0.0), WOOD_MATERIAL)
	for slat: int in range(8):
		var angle: float = float(slat) * TAU / 8.0
		_add_visual_box(
			"Stave%02d" % slat,
			Vector3(0.11, 1.23, 0.12),
			Vector3(cos(angle) * 0.57, 0.68, sin(angle) * 0.57),
			WOOD_MATERIAL,
			Vector3(0.0, -angle, 0.0)
		)


func _build_wall_sconce() -> void:
	_add_visual_box("WallPlate", Vector3(0.55, 0.75, 0.1), Vector3(0.0, 0.65, 0.0), METAL_MATERIAL)
	_add_visual_box("Bracket", Vector3(0.12, 0.12, 0.72), Vector3(0.0, 0.52, -0.34), METAL_MATERIAL, Vector3(0.12, 0.0, 0.0))
	_add_visual_cylinder("Bowl", 0.26, 0.14, 0.18, Vector3(0.0, 0.58, -0.73), METAL_MATERIAL, Vector3.ZERO)
	_add_visual_sphere("FlameCore", 0.17, Vector3(0.0, 0.82, -0.73), WARM_GLOW_MATERIAL, Vector3(0.72, 1.5, 0.72))
	_add_visual_sphere("FlameTip", 0.095, Vector3(0.03, 1.06, -0.72), WARM_GLOW_MATERIAL, Vector3(0.55, 1.45, 0.55))
	_add_point_light("WarmLight", Vector3(0.0, 0.88, -0.7), Color(1.0, 0.46, 0.16), 2.2, 6.5)


func _build_water_channel() -> void:
	_add_static_box("BasinFloor", Vector3(2.2, 0.32, 4.0), Vector3(0.0, -0.48, 0.0), WET_STONE_MATERIAL)
	for side: float in [-1.0, 1.0]:
		_add_static_box("ChannelWall_%s" % ("L" if side < 0.0 else "R"), Vector3(0.38, 0.72, 4.05), Vector3(side * 1.1, -0.18, 0.0), TRIM_STONE_MATERIAL)
		_add_visual_box("MossEdge_%s" % ("L" if side < 0.0 else "R"), Vector3(0.24, 0.035, 2.2), Vector3(side * 0.92, 0.2, 0.32), MOSS_MATERIAL)
	_add_visual_box("WaterSurface", Vector3(1.76, 0.035, 3.94), Vector3(0.0, 0.07, 0.0), WATER_MATERIAL)
	_add_visual_box("WaterDepth", Vector3(1.72, 0.06, 3.9), Vector3(0.0, -0.32, 0.0), WET_STONE_MATERIAL)
	for ripple: int in range(4):
		_add_visual_box("Ripple%02d" % ripple, Vector3(1.42, 0.018, 0.055), Vector3(0.0, 0.105, -1.35 + float(ripple) * 0.9), WATER_MATERIAL, Vector3(0.0, sin(float(ripple)) * 0.12, 0.0))


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
		var visual := MeshInstance3D.new()
		visual.name = "Visual"
		var mesh := BoxMesh.new()
		mesh.size = size
		visual.mesh = mesh
		visual.material_override = material_value
		body.add_child(visual)
		build_counts["visuals"] = int(build_counts["visuals"]) + 1
	return body


func _add_static_cylinder(
	node_name: String,
	radius: float,
	height: float,
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
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	collision.shape = shape
	body.add_child(collision)
	build_counts["colliders"] = int(build_counts["colliders"]) + 1
	if visible_mesh:
		var visual := MeshInstance3D.new()
		visual.name = "Visual"
		var mesh := CylinderMesh.new()
		mesh.top_radius = radius
		mesh.bottom_radius = radius
		mesh.height = height
		mesh.radial_segments = 12
		visual.mesh = mesh
		visual.material_override = material_value
		body.add_child(visual)
		build_counts["visuals"] = int(build_counts["visuals"]) + 1
	return body


func _add_visual_box(
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
	visual.set_meta("modular_piece_owner", piece_id)
	add_child(visual)
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


func _add_visual_torus(
	node_name: String,
	inner_radius: float,
	outer_radius: float,
	position_value: Vector3,
	material_value: Material,
	rotation_value: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.position = position_value
	visual.rotation = rotation_value
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 20
	mesh.ring_segments = 10
	visual.mesh = mesh
	visual.material_override = material_value
	visual.set_meta("modular_piece_owner", piece_id)
	add_child(visual)
	build_counts["visuals"] = int(build_counts["visuals"]) + 1
	return visual


func _add_point_light(
	node_name: String,
	position_value: Vector3,
	color_value: Color,
	energy: float,
	range_value: float
) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = node_name
	light.position = position_value
	light.light_color = color_value
	light.light_energy = energy
	light.omni_range = range_value
	light.shadow_enabled = false
	add_child(light)
	build_counts["lights"] = int(build_counts["lights"]) + 1
	return light


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
