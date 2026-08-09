extends "res://scripts/levels/prototype_green_grotto_detail_pass.gd"
class_name PrototypeGreenGrottoHeroPass

const HeroMaterialLibraryScript = preload(
	"res://scripts/environment/green_grotto_hero_material_library.gd"
)

var hero_materials: GreenGrottoHeroMaterialLibrary = null
var hero_root: Node3D = null
var hero_chasm_root: Node3D = null
var hero_architecture_root: Node3D = null
var hero_foliage_root: Node3D = null
var hero_water_root: Node3D = null

var hero_counts: Dictionary = {
	"retired_water_nodes": 0,
	"hidden_prototype_surfaces": 0,
	"localized_water_surfaces": 0,
	"rock_sculptures": 0,
	"causeway_face_blocks": 0,
	"causeway_supports": 0,
	"shrine_masonry_blocks": 0,
	"shrine_brackets": 0,
	"railings": 0,
	"hero_foliage_masses": 0,
	"hero_roots": 0,
}


func _ready() -> void:
	super._ready()
	hero_materials = HeroMaterialLibraryScript.new() as GreenGrottoHeroMaterialLibrary
	_build_hero_roots()
	_retire_legacy_water_fixture()
	_retire_broad_prototype_visuals()
	_rebuild_localized_water_v3()
	_sculpt_chasm_v3()
	_rebuild_causeway_faces_v3()
	_rebuild_shrine_v3()
	_build_hero_ecology_v3()
	_rebalance_lighting_v3()
	set_meta("hero_pass", "green_grotto_v3")
	set_meta("water_contract", "localized_surface_meshes_no_global_plane")
	set_meta("prototype_geometry_role", "collision_scaffold_only")
	set_meta("hero_counts", hero_counts.duplicate(true))
	set_meta("build_counts", build_counts.duplicate(true))


func _build_hero_roots() -> void:
	hero_root = _new_root(environment_root, "HeroPassV3")
	hero_chasm_root = _new_root(hero_root, "ChasmSculpt")
	hero_architecture_root = _new_root(hero_root, "HeroArchitecture")
	hero_foliage_root = _new_root(hero_root, "HeroFoliage")
	hero_water_root = _new_root(hero_root, "HeroWater")


func _retire_legacy_water_fixture() -> void:
	if water_root == null:
		return
	var old_children: Array[Node] = water_root.get_children()
	for child: Node in old_children:
		hero_counts["retired_water_nodes"] = int(hero_counts["retired_water_nodes"]) + 1
		child.free()
	water_root.set_meta("legacy_water_retired", true)
	water_root.set_meta("replacement", "GreenGrottoArt/HeroPassV3/HeroWater")


func _retire_broad_prototype_visuals() -> void:
	var paths: Array[String] = [
		"GreenGrottoArt/Terrain/ArrivalShelf",
		"GreenGrottoArt/Terrain/CliffLeftNear",
		"GreenGrottoArt/Terrain/CliffRightNear",
		"GreenGrottoArt/Terrain/CliffLeftDeep",
		"GreenGrottoArt/Terrain/CliffRightDeep",
		"GreenGrottoArt/Terrain/BackMountain",
		"GreenGrottoArt/AncientRuins/LeftTerrace",
		"GreenGrottoArt/AncientRuins/RightTerrace",
		"GreenGrottoArt/AncientRuins/RightBrokenLedge",
		"GreenGrottoArt/AncientRuins/ShrineFoundation",
	]
	for index: int in range(7):
		paths.append("GreenGrottoArt/AncientRuins/CausewaySlab%02d" % index)

	for path: String in paths:
		var body: Node = get_node_or_null(path)
		if body == null:
			continue
		var visual: MeshInstance3D = body.get_node_or_null("Visual") as MeshInstance3D
		if visual == null:
			continue
		visual.visible = false
		body.set_meta("prototype_visual_hidden", true)
		hero_counts["hidden_prototype_surfaces"] = int(hero_counts["hidden_prototype_surfaces"]) + 1

	# V2's fitted paving survives, but receives the cooler V3 hero palette.
	for slab: StaticBody3D in _get_causeway_slabs():
		for child: Node in slab.get_children():
			if child is MeshInstance3D and str(child.name).begins_with("Paver_"):
				var paver := child as MeshInstance3D
				var wet: bool = str(paver.get_meta("surface_detail", "")) == "wet_paving"
				paver.material_override = hero_materials.get_material(
					"hero_paving_wet" if wet else "hero_paving"
				)


func _rebuild_localized_water_v3() -> void:
	var shallow: Material = hero_materials.get_material("hero_water_shallow")
	var deep: Material = hero_materials.get_material("hero_water_deep")
	var waterfall: Material = hero_materials.get_material("hero_waterfall")
	var foam: Material = hero_materials.get_material("hero_foam")
	var wet_rock: Material = hero_materials.get_material("hero_rock_wet")
	var wet_soil: Material = detail_materials.get_material("soil_wet")

	# A small, irregular upper stream that visibly sits on the right terrace.
	_add_horizontal_water_polygon(
		hero_water_root,
		"V3UpperStream",
		PackedVector2Array([
			Vector2(4.85, -7.25),
			Vector2(6.65, -7.45),
			Vector2(7.30, -8.55),
			Vector2(7.05, -10.25),
			Vector2(6.35, -11.05),
			Vector2(5.25, -10.95),
			Vector2(4.85, -9.55),
		]),
		2.25,
		shallow,
		"upper_stream"
	)
	_add_horizontal_water_polygon(
		hero_water_root,
		"V3UpperStreamBed",
		PackedVector2Array([
			Vector2(4.65, -7.05),
			Vector2(6.85, -7.18),
			Vector2(7.55, -8.45),
			Vector2(7.38, -10.50),
			Vector2(6.45, -11.35),
			Vector2(5.00, -11.25),
			Vector2(4.55, -9.45),
		]),
		2.12,
		wet_soil,
		"stream_bed"
	)

	# The lower basin is a separate irregular polygon. There is intentionally no
	# world-spanning water surface anywhere beneath the rest of the grotto.
	_add_horizontal_water_polygon(
		hero_water_root,
		"V3LowerBasin",
		PackedVector2Array([
			Vector2(1.10, -9.55),
			Vector2(2.35, -11.10),
			Vector2(4.25, -11.80),
			Vector2(6.30, -11.25),
			Vector2(7.10, -9.55),
			Vector2(6.80, -7.55),
			Vector2(5.35, -6.45),
			Vector2(3.35, -6.20),
			Vector2(1.55, -7.10),
		]),
		-5.35,
		deep,
		"lower_basin"
	)

	# Thin vertical sheets connect the exact stream lip to the basin. Their small
	# footprint prevents the previous read of a hidden fixture under the room.
	for index: int in range(4):
		var x_value: float = 5.30 + float(index) * 0.38
		var sheet := _add_visual_box(
			hero_water_root,
			"V3WaterfallSheet%02d" % index,
			Vector3(0.46 - float(index % 2) * 0.07, 7.25 + float(index % 2) * 0.28, 0.055),
			Vector3(x_value, -1.55, -11.08 + float(index % 2) * 0.07),
			waterfall,
			Vector3(0.0, -0.03 + float(index) * 0.018, 0.015 * float(index % 2))
		)
		sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Rock banks physically explain where each water body begins and ends.
	var upper_bank_points: Array[Vector3] = [
		Vector3(4.70, 2.24, -7.10), Vector3(5.55, 2.25, -6.98),
		Vector3(6.65, 2.24, -7.20), Vector3(7.35, 2.23, -8.15),
		Vector3(7.45, 2.21, -9.25), Vector3(7.35, 2.20, -10.35),
		Vector3(6.85, 2.18, -11.25), Vector3(5.95, 2.18, -11.48),
		Vector3(4.95, 2.19, -11.15), Vector3(4.55, 2.21, -10.20),
		Vector3(4.45, 2.22, -8.95), Vector3(4.50, 2.23, -7.80),
	]
	for index: int in range(upper_bank_points.size()):
		_add_hero_rock(
			hero_water_root,
			"V3UpperBank%02d" % index,
			upper_bank_points[index],
			0.46 + float(index % 4) * 0.09,
			wet_rock,
			Vector3(1.25, 0.55, 0.92),
			float(index) * 0.63
		)

	var lower_bank_points: Array[Vector3] = []
	for index: int in range(24):
		var angle: float = TAU * float(index) / 24.0
		var radius_x: float = 3.25 + float(index % 3) * 0.18
		var radius_z: float = 2.78 + float((index + 1) % 4) * 0.13
		lower_bank_points.append(Vector3(
			4.05 + cos(angle) * radius_x,
			-5.15 + float(index % 4) * 0.045,
			-9.05 + sin(angle) * radius_z
		))
	for index: int in range(lower_bank_points.size()):
		_add_hero_rock(
			hero_water_root,
			"V3LowerBank%02d" % index,
			lower_bank_points[index],
			0.58 + float(index % 5) * 0.10,
			wet_rock,
			Vector3(1.3, 0.62, 1.0),
			float(index) * 0.47
		)

	for index: int in range(7):
		var strip := _add_visual_box(
			hero_water_root,
			"V3LipFoam%02d" % index,
			Vector3(0.42 + float(index % 2) * 0.12, 0.015, 0.10),
			Vector3(4.95 + float(index) * 0.28, 2.29, -11.08 + sin(float(index)) * 0.05),
			foam,
			Vector3(0.0, float(index) * 0.05, 0.0)
		)
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	hero_counts["localized_water_surfaces"] = 3


func _sculpt_chasm_v3() -> void:
	var rock: Material = hero_materials.get_material("hero_rock")
	var wet_rock: Material = hero_materials.get_material("hero_rock_wet")

	# Dense layered rock masses cover the broad collision boxes. The underlying
	# boxes remain invisible and gameplay-safe while the visible silhouette gains
	# ledges, undercuts, columns and real depth.
	for side_index: int in range(2):
		var side: float = -1.0 if side_index == 0 else 1.0
		for index: int in range(34):
			var z_value: float = 15.0 - float(index) * 1.18
			var band: int = index % 6
			var x_value: float = side * (7.2 + float(band % 3) * 0.75)
			var y_value: float = -3.0 + float((index * 5 + side_index * 2) % 9) * 1.15
			var radius: float = 0.95 + float(index % 5) * 0.28
			var material: Material = wet_rock if z_value < -5.0 and band in [1, 4] else rock
			_add_hero_rock(
				hero_chasm_root,
				"ChasmRock_%d_%02d" % [side_index, index],
				Vector3(x_value, y_value, z_value),
				radius,
				material,
				Vector3(1.55, 0.72 + float(index % 3) * 0.15, 1.20),
				float(index) * 0.41 + side
			)

	# Broken shelves and stone ribs create readable strata through the vertical gap.
	for index: int in range(12):
		var side: float = -1.0 if index % 2 == 0 else 1.0
		var shelf := _add_visual_box(
			hero_chasm_root,
			"ChasmShelf%02d" % index,
			Vector3(2.2 + float(index % 3) * 0.55, 0.38, 1.25 + float(index % 4) * 0.35),
			Vector3(
				side * (6.1 + float(index % 3) * 0.65),
				-1.2 - float(index % 5) * 1.05,
				8.0 - float(index) * 2.15
			),
			rock,
			Vector3(0.04 * float(index % 3), float(index) * 0.37, side * 0.07)
		)
		shelf.set_meta("geology_role", "undercut_shelf")

	# Pillar-like rock stacks in the lower void prevent the chasm from reading as a
	# flat orange backdrop while keeping clear empty space around the localized pool.
	for index: int in range(7):
		var x_value: float = -4.8 + float(index) * 1.65
		var height: float = 2.8 + float(index % 3) * 1.2
		_add_visual_cylinder(
			hero_chasm_root,
			"LowerRockPillar%02d" % index,
			0.48 + float(index % 2) * 0.18,
			height,
			Vector3(x_value, -5.5 + height * 0.5, -2.5 - float(index % 2) * 2.4),
			rock,
			Vector3(0.06 * float(index % 2), float(index) * 0.32, -0.04 * float(index % 3)),
			9
		)
		hero_counts["rock_sculptures"] = int(hero_counts["rock_sculptures"]) + 1


func _rebuild_causeway_faces_v3() -> void:
	var masonry: Material = hero_materials.get_material("hero_masonry")
	var trim: Material = hero_materials.get_material("hero_trim")
	var root_material: Material = material_library.get_material("root")
	var slabs: Array[StaticBody3D] = _get_causeway_slabs()

	for slab_index: int in range(slabs.size()):
		var slab: StaticBody3D = slabs[slab_index]
		var collision: CollisionShape3D = slab.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if collision == null or not collision.shape is BoxShape3D:
			continue
		var size: Vector3 = (collision.shape as BoxShape3D).size
		var segments: int = maxi(3, roundi(size.z / 0.78))
		for side: float in [-1.0, 1.0]:
			for segment: int in range(segments):
				var z_value: float = -size.z * 0.5 + size.z * (float(segment) + 0.5) / float(segments)
				var block_height: float = 0.34 + float((segment + slab_index) % 3) * 0.12
				_add_visual_box(
					slab,
					"HeroEdge_%d_%d" % [int(side), segment],
					Vector3(0.38, block_height, maxf(size.z / float(segments) - 0.055, 0.2)),
					Vector3(side * (size.x * 0.5 - 0.10), -size.y * 0.5 + block_height * 0.25, z_value),
					masonry,
					Vector3(0.0, sin(float(segment + slab_index)) * 0.025, side * 0.025)
				)
				hero_counts["causeway_face_blocks"] = int(hero_counts["causeway_face_blocks"]) + 1

		# Exposed underside support stones sell the bridge as ruins rather than a slab.
		if slab_index in [1, 3, 5]:
			for support_side: float in [-1.0, 1.0]:
				var support_height: float = 2.2 + float(slab_index % 3) * 0.55
				_add_visual_box(
					hero_architecture_root,
					"CausewayPier_%02d_%d" % [slab_index, int(support_side)],
					Vector3(0.82, support_height, 0.88),
					slab.global_position + Vector3(
						support_side * size.x * 0.31,
						-support_height * 0.5 - 0.18,
						0.08
					),
					masonry,
					Vector3(0.02 * float(slab_index), 0.03 * support_side, 0.025 * support_side)
				)
				hero_counts["causeway_supports"] = int(hero_counts["causeway_supports"]) + 1

		# Sparse broken railing keeps the route readable while adding human scale.
		if slab_index in [0, 2, 6]:
			var rail_side: float = -1.0 if slab_index % 2 == 0 else 1.0
			_build_broken_railing_on_slab(slab, size, rail_side, trim, slab_index)

	# Thick roots cross only a few bridge edges, making the invasion feel authored.
	for spec: Dictionary in [
		{"a": Vector3(-2.5, 0.45, 5.9), "b": Vector3(-1.2, 0.28, 4.7), "c": Vector3(0.2, 0.18, 4.0)},
		{"a": Vector3(2.4, 1.10, -4.2), "b": Vector3(1.5, 0.95, -5.0), "c": Vector3(0.55, 0.88, -5.7)},
	]:
		_add_visual_cylinder_between(
			hero_architecture_root,
			"CausewayHeroRoot",
			spec["a"] as Vector3,
			spec["b"] as Vector3,
			0.17,
			root_material,
			9
		)
		_add_visual_cylinder_between(
			hero_architecture_root,
			"CausewayHeroRootTip",
			spec["b"] as Vector3,
			spec["c"] as Vector3,
			0.11,
			root_material,
			8
		)
		hero_counts["hero_roots"] = int(hero_counts["hero_roots"]) + 1


func _rebuild_shrine_v3() -> void:
	var masonry: Material = hero_materials.get_material("hero_masonry")
	var trim: Material = hero_materials.get_material("hero_trim")
	var wood: Material = hero_materials.get_material("hero_wood")
	var roof: Material = hero_materials.get_material("hero_roof")
	var moss: Material = hero_materials.get_material("hero_moss")

	# Replace the hidden monolithic foundation visually with courses of individual
	# stone blocks. Collision remains the original stable foundation body.
	for course: int in range(3):
		var y_value: float = 0.35 + float(course) * 0.52
		var course_offset: float = 0.48 if course % 2 == 1 else 0.0
		for index: int in range(13):
			var x_value: float = -5.75 + float(index) * 0.96 + course_offset
			if x_value > 6.15:
				continue
			_add_visual_box(
				hero_architecture_root,
				"ShrineFrontMasonry_%d_%02d" % [course, index],
				Vector3(0.90, 0.47, 0.52),
				Vector3(x_value, y_value, -10.05),
				masonry,
				Vector3(0.0, sin(float(index + course * 7)) * 0.018, 0.0)
			)
			hero_counts["shrine_masonry_blocks"] = int(hero_counts["shrine_masonry_blocks"]) + 1

	for side: float in [-1.0, 1.0]:
		for course: int in range(3):
			for index: int in range(9):
				var z_value: float = -10.55 - float(index) * 0.99
				_add_visual_box(
					hero_architecture_root,
					"ShrineSideMasonry",
					Vector3(0.52, 0.47, 0.92),
					Vector3(side * 6.15, 0.35 + float(course) * 0.52, z_value),
					masonry,
					Vector3(0.0, 0.0, side * sin(float(index + course)) * 0.015)
				)
				hero_counts["shrine_masonry_blocks"] = int(hero_counts["shrine_masonry_blocks"]) + 1

	# Heavier Chinese-inspired bracket rhythm below the eaves.
	for z_side: float in [-1.0, 1.0]:
		for index: int in range(9):
			var x_value: float = -4.65 + float(index) * 1.16
			var base := Vector3(x_value, 6.28, -14.45 + z_side * 2.72)
			_add_visual_box(
				hero_architecture_root,
				"HeroBracketBeam",
				Vector3(0.86, 0.16, 0.38),
				base,
				wood,
				Vector3(0.0, 0.0, (0.07 if index % 2 == 0 else -0.07))
			)
			_add_visual_box(
				hero_architecture_root,
				"HeroBracketBlock",
				Vector3(0.36, 0.34, 0.34),
				base + Vector3(0.0, -0.22, -z_side * 0.05),
				trim
			)
			_add_visual_box(
				hero_architecture_root,
				"HeroBracketTongue",
				Vector3(0.28, 0.12, 0.62),
				base + Vector3(0.0, -0.08, z_side * 0.18),
				wood
			)
			hero_counts["shrine_brackets"] = int(hero_counts["shrine_brackets"]) + 3

	# Roof tile battens and ridge ornaments make the roof read as constructed layers.
	for side: float in [-1.0, 1.0]:
		for index: int in range(17):
			var x_value: float = -5.05 + float(index) * 0.63
			_add_visual_box(
				hero_architecture_root,
				"HeroRoofTile",
				Vector3(0.10, 0.09, 3.05),
				Vector3(0.0, 0.0, 0.0) + Vector3(x_value, 7.06, -14.45 + side * 1.52),
				roof,
				Vector3(side * -0.18, 0.0, 0.0)
			)

	for x_side: float in [-1.0, 1.0]:
		_add_visual_cylinder(
			hero_architecture_root,
			"RoofFinial",
			0.10,
			1.0,
			Vector3(x_side * 5.45, 7.48, -14.45),
			roof,
			Vector3(0.0, 0.0, x_side * 0.32),
			8
		)

	# Broken stone railing establishes a terrace perimeter without enclosing the route.
	_build_shrine_railing(Vector3(-5.2, 2.78, -11.25), Vector3(-5.2, 2.78, -17.5), trim, "Left")
	_build_shrine_railing(Vector3(5.2, 2.78, -11.25), Vector3(5.2, 2.78, -14.4), trim, "RightNear")
	_build_shrine_railing(Vector3(5.2, 2.78, -15.8), Vector3(5.2, 2.78, -17.5), trim, "RightFar")

	# Local moss is concentrated at joints, terrace corners and root contact points.
	for index: int in range(13):
		var side: float = -1.0 if index % 2 == 0 else 1.0
		var patch := _add_visual_sphere(
			hero_architecture_root,
			"HeroShrineMoss%02d" % index,
			Vector3(
				side * (4.2 + float(index % 3) * 0.45),
				2.38 + float(index % 2) * 0.04,
				-11.2 - float(index % 6) * 1.15
			),
			0.52 + float(index % 4) * 0.10,
			moss,
			Vector3(1.45, 0.025, 0.75)
		)
		patch.rotation.y = float(index) * 0.52


func _build_hero_ecology_v3() -> void:
	var leaf_litter: Material = hero_materials.get_material("hero_leaf_litter")
	var moss: Material = hero_materials.get_material("hero_moss")
	var root_material: Material = material_library.get_material("root")

	# Large side pockets create masses instead of evenly sprinkled individual plants.
	var pockets: Array[Dictionary] = [
		{"pos": Vector3(-5.0, 0.10, 12.4), "radius": 1.0, "seed": 210},
		{"pos": Vector3(4.8, 0.12, 10.4), "radius": 0.9, "seed": 220},
		{"pos": Vector3(-4.8, 0.62, 3.1), "radius": 1.1, "seed": 230},
		{"pos": Vector3(5.1, 1.02, -1.3), "radius": 1.0, "seed": 240},
		{"pos": Vector3(-6.6, 1.58, -4.8), "radius": 1.25, "seed": 250},
		{"pos": Vector3(7.1, 2.18, -8.0), "radius": 1.1, "seed": 260},
		{"pos": Vector3(-5.0, 2.42, -15.2), "radius": 1.2, "seed": 270},
		{"pos": Vector3(5.0, 2.42, -16.1), "radius": 1.15, "seed": 280},
	]
	for pocket_index: int in range(pockets.size()):
		var spec: Dictionary = pockets[pocket_index]
		var center: Vector3 = spec["pos"] as Vector3
		var radius: float = float(spec["radius"])
		var seed_value: int = int(spec["seed"])
		var litter := _add_visual_sphere(
			hero_foliage_root,
			"HeroLitterPocket%02d" % pocket_index,
			center,
			radius,
			leaf_litter,
			Vector3(1.6, 0.025, 1.05)
		)
		litter.rotation.y = float(pocket_index) * 0.71
		for local_index: int in range(3):
			var angle: float = TAU * float(local_index) / 3.0 + float(pocket_index) * 0.43
			var plant_position: Vector3 = center + Vector3(cos(angle) * radius * 0.68, 0.03, sin(angle) * radius * 0.68)
			if (local_index + pocket_index) % 3 == 0:
				_add_cycad(plant_position, 0.86 + float(local_index) * 0.10, seed_value + local_index)
			else:
				_add_fern(plant_position, 0.88 + float(local_index) * 0.08, seed_value + local_index)
			hero_counts["hero_foliage_masses"] = int(hero_counts["hero_foliage_masses"]) + 1

	# Massive roots now frame the camera and physically touch architecture.
	var root_specs: Array[Array] = [
		[Vector3(-8.8, 9.8, 11.0), Vector3(-7.0, 7.0, 9.3), Vector3(-5.8, 4.6, 7.3), Vector3(-4.0, 2.0, 5.7)],
		[Vector3(9.2, 10.2, 8.0), Vector3(7.8, 7.6, 6.5), Vector3(6.2, 4.4, 4.8), Vector3(4.6, 2.0, 2.7)],
		[Vector3(-8.4, 9.0, -12.0), Vector3(-7.0, 6.6, -13.2), Vector3(-6.0, 4.5, -14.5), Vector3(-4.8, 2.8, -15.3)],
	]
	for chain_index: int in range(root_specs.size()):
		var raw_chain: Array = root_specs[chain_index]
		for segment_index: int in range(raw_chain.size() - 1):
			_add_visual_cylinder_between(
				hero_foliage_root,
				"HeroFrameRoot_%d_%d" % [chain_index, segment_index],
				raw_chain[segment_index] as Vector3,
				raw_chain[segment_index + 1] as Vector3,
				0.32 - float(segment_index) * 0.055,
				root_material,
				11
			)
		hero_counts["hero_roots"] = int(hero_counts["hero_roots"]) + 1

	# Moss bands on rock ledges create ecological transitions instead of sticker patches.
	for index: int in range(18):
		var side: float = -1.0 if index % 2 == 0 else 1.0
		var patch := _add_visual_sphere(
			hero_foliage_root,
			"HeroRockMoss%02d" % index,
			Vector3(
				side * (6.8 + float(index % 3) * 0.45),
				-0.8 + float(index % 5) * 1.1,
				11.0 - float(index) * 1.75
			),
			0.70 + float(index % 4) * 0.12,
			moss,
			Vector3(1.55, 0.08, 1.0)
		)
		patch.rotation = Vector3(float(index % 3) * 0.14, float(index) * 0.43, float(index % 2) * 0.12)


func _rebalance_lighting_v3() -> void:
	var sun: DirectionalLight3D = get_node_or_null(
		"GreenGrottoArt/Lighting/CanopySunset"
	) as DirectionalLight3D
	if sun != null:
		sun.light_energy = 1.62
		sun.light_color = Color(1.0, 0.60, 0.29, 1.0)
		sun.light_volumetric_fog_energy = 1.55

	var fill: DirectionalLight3D = get_node_or_null(
		"GreenGrottoArt/Lighting/GrottoGreenFill"
	) as DirectionalLight3D
	if fill != null:
		fill.light_color = Color(0.11, 0.38, 0.25, 1.0)
		fill.light_energy = 0.68

	var shrine_bounce: OmniLight3D = get_node_or_null(
		"GreenGrottoArt/Lighting/ShrineSunBounce"
	) as OmniLight3D
	if shrine_bounce != null:
		shrine_bounce.light_energy = 2.85
		shrine_bounce.light_color = Color(1.0, 0.46, 0.16, 1.0)

	var water_bounce: OmniLight3D = get_node_or_null(
		"GreenGrottoArt/Lighting/WaterCoolBounce"
	) as OmniLight3D
	if water_bounce != null:
		water_bounce.position = Vector3(4.0, -3.4, -9.0)
		water_bounce.light_color = Color(0.055, 0.39, 0.31, 1.0)
		water_bounce.light_energy = 1.65

	var world_environment: WorldEnvironment = get_node_or_null(
		"GreenGrottoArt/Lighting/GreenGrottoEnvironment"
	) as WorldEnvironment
	if world_environment != null and world_environment.environment != null:
		var environment: Environment = world_environment.environment
		environment.tonemap_exposure = 0.92
		environment.fog_light_color = Color(0.30, 0.30, 0.20, 1.0)
		environment.fog_light_energy = 0.46
		environment.fog_density = 0.0048
		environment.volumetric_fog_density = 0.018
		environment.volumetric_fog_albedo = Color(0.48, 0.55, 0.37, 1.0)
		environment.volumetric_fog_emission = Color(0.012, 0.022, 0.016, 1.0)
		environment.volumetric_fog_emission_energy = 0.035
		environment.ambient_light_color = Color(0.095, 0.285, 0.185, 1.0)
		environment.ambient_light_energy = 0.58


func _get_causeway_slabs() -> Array[StaticBody3D]:
	var slabs: Array[StaticBody3D] = []
	for node: Node in get_tree().get_nodes_in_group("green_grotto_causeway"):
		if is_ancestor_of(node) and node is StaticBody3D:
			slabs.append(node as StaticBody3D)
	slabs.sort_custom(func(a: StaticBody3D, b: StaticBody3D) -> bool: return str(a.name) < str(b.name))
	return slabs


func _add_horizontal_water_polygon(
	parent: Node3D,
	node_name: String,
	points: PackedVector2Array,
	y_value: float,
	material: Material,
	water_role: String
) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.set_meta("water_role", water_role)
	visual.set_meta("localized_water", true)

	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector3.ZERO
	for point: Vector2 in points:
		center += Vector3(point.x, y_value, point.y)
	center /= float(maxi(points.size(), 1))
	for index: int in range(points.size()):
		var next_index: int = (index + 1) % points.size()
		for vertex: Vector3 in [
			center,
			Vector3(points[index].x, y_value, points[index].y),
			Vector3(points[next_index].x, y_value, points[next_index].y),
		]:
			surface_tool.set_normal(Vector3.UP)
			surface_tool.add_vertex(vertex)
	var mesh: ArrayMesh = surface_tool.commit()
	visual.mesh = mesh
	visual.material_override = material
	parent.add_child(visual)
	build_counts["visual_meshes"] = int(build_counts["visual_meshes"]) + 1
	return visual


func _add_hero_rock(
	parent: Node3D,
	node_name: String,
	position_value: Vector3,
	radius: float,
	material: Material,
	scale_value: Vector3,
	rotation_seed: float
) -> MeshInstance3D:
	var rock := _add_visual_sphere(
		parent,
		node_name,
		position_value,
		radius,
		material,
		scale_value
	)
	rock.rotation = Vector3(
		sin(rotation_seed * 0.73) * 0.24,
		rotation_seed,
		cos(rotation_seed * 0.61) * 0.18
	)
	rock.set_meta("hero_geometry", "rock_sculpture")
	hero_counts["rock_sculptures"] = int(hero_counts["rock_sculptures"]) + 1
	return rock


func _build_broken_railing_on_slab(
	slab: StaticBody3D,
	size: Vector3,
	side: float,
	material: Material,
	seed_value: int
) -> void:
	var post_count: int = 3
	for index: int in range(post_count):
		if seed_value == 2 and index == 1:
			continue
		var z_value: float = -size.z * 0.33 + float(index) * size.z * 0.33
		_add_visual_box(
			slab,
			"BrokenRailPost%02d" % index,
			Vector3(0.16, 0.82 + float(index % 2) * 0.18, 0.16),
			Vector3(side * (size.x * 0.5 - 0.24), size.y * 0.5 + 0.42, z_value),
			material,
			Vector3(0.0, 0.0, side * (0.03 + float(index) * 0.02))
		)
		hero_counts["railings"] = int(hero_counts["railings"]) + 1
	if seed_value != 2:
		_add_visual_box(
			slab,
			"BrokenRailBeam",
			Vector3(0.14, 0.14, size.z * 0.62),
			Vector3(side * (size.x * 0.5 - 0.24), size.y * 0.5 + 0.70, 0.0),
			material,
			Vector3(0.04, 0.0, side * 0.025)
		)
		hero_counts["railings"] = int(hero_counts["railings"]) + 1


func _build_shrine_railing(
	start: Vector3,
	finish: Vector3,
	material: Material,
	label: String
) -> void:
	var delta: Vector3 = finish - start
	var length: float = delta.length()
	var post_count: int = maxi(2, roundi(length / 1.35) + 1)
	for index: int in range(post_count):
		var progress: float = float(index) / float(maxi(post_count - 1, 1))
		if label == "RightNear" and index == post_count - 1:
			continue
		var position_value: Vector3 = start.lerp(finish, progress)
		_add_visual_box(
			hero_architecture_root,
			"ShrineRailPost" + label,
			Vector3(0.20, 0.88, 0.20),
			position_value + Vector3.UP * 0.42,
			material,
			Vector3(0.0, 0.0, sin(float(index)) * 0.025)
		)
		hero_counts["railings"] = int(hero_counts["railings"]) + 1
	_add_visual_cylinder_between(
		hero_architecture_root,
		"ShrineRailBeam" + label,
		start + Vector3.UP * 0.72,
		finish + Vector3.UP * 0.72,
		0.085,
		material,
		8
	)
	hero_counts["railings"] = int(hero_counts["railings"]) + 1


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["green_grotto_hero_pass"] = true
	data["hero_pass"] = "v3_structural_hero_rewrite"
	data["hero_counts"] = hero_counts.duplicate(true)
	data["hero_materials"] = hero_materials.get_debug_data() if hero_materials != null else {}
	data["water_geography"] = "localized upper stream -> narrow waterfall -> localized lower basin"
	data["water_contract"] = "no legacy water nodes and no broad under-level water plane"
	data["prototype_visuals"] = "hidden where V3 hero geometry replaces them; collisions retained"
	data["expansion_strategy"] = "hero_quality_gate_before_room_expansion"
	return data
