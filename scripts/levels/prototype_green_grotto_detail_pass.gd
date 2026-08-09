extends "res://scripts/levels/prototype_green_grotto_art_target.gd"
class_name PrototypeGreenGrottoDetailPass

const DetailMaterialLibraryScript = preload(
	"res://scripts/environment/green_grotto_detail_material_library.gd"
)

var detail_materials: GreenGrottoDetailMaterialLibrary = null
var detail_counts: Dictionary = {
	"paving_stones": 0,
	"water_banks": 0,
	"ecology_pockets": 0,
	"shrine_details": 0,
	"rubble_details": 0,
}


func _ready() -> void:
	super._ready()
	detail_materials = DetailMaterialLibraryScript.new() as GreenGrottoDetailMaterialLibrary
	_refine_water_geography()
	_dress_walkable_surfaces()
	_dress_shrine_landmark()
	_build_ecology_pockets()
	_rebalance_grotto_lighting()
	set_meta("detail_pass", "green_grotto_v2")
	set_meta("water_geography", "upper_stream_to_waterfall_to_lower_basin")
	set_meta("build_counts", build_counts.duplicate(true))
	set_meta("detail_counts", detail_counts.duplicate(true))


func _refine_water_geography() -> void:
	var deep_water: Material = detail_materials.get_material("water_deep")
	var shallow_water: Material = detail_materials.get_material("water_shallow")
	var foam: Material = detail_materials.get_material("water_foam")
	var river_rock: Material = detail_materials.get_material("river_rock")
	var wet_soil: Material = detail_materials.get_material("soil_wet")

	# The original art target used one broad pool beneath most of the scene.
	# Tighten that into an authored lower basin so water reads as geography rather
	# than a giant plane hidden under every gap in the ruins.
	var pool: MeshInstance3D = get_node_or_null(
		"GreenGrottoArt/Water/GrottoPool"
	) as MeshInstance3D
	if pool != null:
		pool.position = Vector3(2.7, -5.88, -7.2)
		pool.material_override = deep_water
		var pool_mesh: BoxMesh = pool.mesh as BoxMesh
		if pool_mesh != null:
			pool_mesh.size = Vector3(9.6, 0.08, 11.4)
		pool.set_meta("water_role", "lower_basin")

	# A visible upper stream now supplies the waterfall at terrace height. The dark
	# bed beneath the translucent surface makes its height unambiguous from the
	# gameplay camera.
	_add_visual_box(
		water_root,
		"UpperStreamBed",
		Vector3(3.45, 0.18, 4.8),
		Vector3(6.05, 2.08, -9.65),
		wet_soil,
		Vector3(0.0, 0.035, 0.0)
	)
	var upper_stream: MeshInstance3D = _add_visual_box(
		water_root,
		"UpperStream",
		Vector3(3.18, 0.055, 4.55),
		Vector3(6.05, 2.20, -9.68),
		shallow_water,
		Vector3(0.0, 0.035, 0.0)
	)
	upper_stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	upper_stream.set_meta("water_role", "waterfall_source")

	# Irregular stone banks obscure the rectangular water meshes and visibly join
	# the stream, fall lip and lower basin to the surrounding grotto rock.
	for index: int in range(18):
		var side: float = -1.0 if index % 2 == 0 else 1.0
		var z_value: float = -7.65 - float(index % 9) * 0.52
		var x_value: float = 6.05 + side * (1.63 + float(index % 3) * 0.16)
		var rock := _add_visual_sphere(
			water_root,
			"UpperBankRock%02d" % index,
			Vector3(x_value, 2.24 + float(index % 3) * 0.035, z_value),
			0.42 + float(index % 4) * 0.09,
			river_rock,
			Vector3(1.15, 0.55, 0.9)
		)
		rock.rotation = Vector3(float(index % 2) * 0.10, float(index) * 0.57, float(index % 3) * 0.06)
		detail_counts["water_banks"] = int(detail_counts["water_banks"]) + 1

	for index: int in range(22):
		var angle: float = TAU * float(index) / 22.0
		var x_radius: float = 5.0 + float(index % 3) * 0.20
		var z_radius: float = 5.9 + float((index + 1) % 4) * 0.18
		var rock := _add_visual_sphere(
			water_root,
			"LowerBasinRock%02d" % index,
			Vector3(
				2.7 + cos(angle) * x_radius,
				-5.64 + float(index % 4) * 0.05,
				-7.2 + sin(angle) * z_radius
			),
			0.55 + float(index % 5) * 0.10,
			river_rock,
			Vector3(1.25, 0.65, 1.0)
		)
		rock.rotation = Vector3(float(index % 3) * 0.09, angle * 0.7, float(index % 4) * 0.07)
		detail_counts["water_banks"] = int(detail_counts["water_banks"]) + 1

	# Quiet foam shelves define where falling water actually meets each surface.
	for index: int in range(5):
		var foam_strip: MeshInstance3D = _add_visual_box(
			water_root,
			"UpperFoam%02d" % index,
			Vector3(0.55 + float(index % 2) * 0.20, 0.018, 0.12),
			Vector3(5.45 + float(index) * 0.28, 2.235, -11.22 + float(index % 2) * 0.08),
			foam,
			Vector3(0.0, -0.10 + float(index) * 0.05, 0.0)
		)
		foam_strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for index: int in range(6):
		var foam_patch: MeshInstance3D = _add_visual_box(
			water_root,
			"LowerFoam%02d" % index,
			Vector3(0.80 + float(index % 3) * 0.18, 0.018, 0.16),
			Vector3(4.6 + float(index % 3) * 0.48, -5.82, -10.6 + float(index / 3) * 0.42),
			foam,
			Vector3(0.0, float(index) * 0.17, 0.0)
		)
		foam_patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _dress_walkable_surfaces() -> void:
	var arrival: StaticBody3D = get_node_or_null(
		"GreenGrottoArt/Terrain/ArrivalShelf"
	) as StaticBody3D
	if arrival != null:
		_dress_arrival_shelf(arrival)

	var slab_index: int = 0
	for node: Node in get_tree().get_nodes_in_group("green_grotto_causeway"):
		if not is_ancestor_of(node) or not node is StaticBody3D:
			continue
		_decorate_causeway_slab(node as StaticBody3D, slab_index)
		slab_index += 1

	_build_edge_rubble()


func _dress_arrival_shelf(arrival: StaticBody3D) -> void:
	var paving: Material = detail_materials.get_material("paving")
	var leaf_litter: Material = detail_materials.get_material("leaf_litter")
	var columns: int = 4
	var rows: int = 5
	for row: int in range(rows):
		for column: int in range(columns):
			var index: int = row * columns + column
			var x_value: float = -2.55 + float(column) * 1.70
			var z_value: float = -3.35 + float(row) * 1.65
			var tile := _add_visual_box(
				arrival,
				"ArrivalPaver%02d" % index,
				Vector3(1.55, 0.045, 1.48),
				Vector3(
					x_value + sin(float(index) * 1.71) * 0.045,
					0.674 + float(index % 3) * 0.004,
					z_value + cos(float(index) * 1.29) * 0.05
				),
				paving,
				Vector3(0.0, sin(float(index) * 0.83) * 0.025, 0.0)
			)
			tile.set_meta("surface_detail", "paving_stone")
			detail_counts["paving_stones"] = int(detail_counts["paving_stones"]) + 1

	for index: int in range(7):
		var patch := _add_visual_sphere(
			arrival,
			"ArrivalLeafLitter%02d" % index,
			Vector3(
				(-1.0 if index % 2 == 0 else 1.0) * (3.1 + float(index % 3) * 0.35),
				0.69,
				-2.8 + float(index) * 1.05
			),
			0.62 + float(index % 2) * 0.18,
			leaf_litter,
			Vector3(1.4, 0.025, 0.8)
		)
		patch.rotation.y = float(index) * 0.63


func _decorate_causeway_slab(slab: StaticBody3D, slab_index: int) -> void:
	var collision: CollisionShape3D = slab.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision == null or not collision.shape is BoxShape3D:
		return
	var size: Vector3 = (collision.shape as BoxShape3D).size
	var columns: int = 3
	var rows: int = maxi(2, roundi(size.z / 1.05))
	var tile_width: float = size.x / float(columns)
	var tile_depth: float = size.z / float(rows)
	var paving: Material = detail_materials.get_material("paving")
	var wet_paving: Material = detail_materials.get_material("paving_wet")
	var leaf_litter: Material = detail_materials.get_material("leaf_litter")

	for row: int in range(rows):
		for column: int in range(columns):
			var index: int = row * columns + column
			var x_value: float = -size.x * 0.5 + tile_width * (float(column) + 0.5)
			var z_value: float = -size.z * 0.5 + tile_depth * (float(row) + 0.5)
			var material: Material = wet_paving if slab_index >= 5 and (index + slab_index) % 3 == 0 else paving
			var tile := _add_visual_box(
				slab,
				"Paver_%02d_%02d" % [slab_index, index],
				Vector3(maxf(tile_width - 0.085, 0.25), 0.036, maxf(tile_depth - 0.085, 0.25)),
				Vector3(
					x_value + sin(float(index + slab_index * 9)) * 0.025,
					size.y * 0.5 + 0.025 + float(index % 2) * 0.003,
					z_value + cos(float(index + slab_index * 4)) * 0.025
				),
				material,
				Vector3(0.0, sin(float(index * 3 + slab_index)) * 0.018, 0.0)
			)
			tile.set_meta("surface_detail", "wet_paving" if material == wet_paving else "paving_stone")
			detail_counts["paving_stones"] = int(detail_counts["paving_stones"]) + 1

	if slab_index % 2 == 1:
		var patch := _add_visual_sphere(
			slab,
			"CausewayLeafLitter%02d" % slab_index,
			Vector3(
				-size.x * 0.34,
				size.y * 0.5 + 0.055,
				size.z * (0.18 if slab_index % 4 == 1 else -0.22)
			),
			0.48,
			leaf_litter,
			Vector3(1.45, 0.022, 0.75)
		)
		patch.rotation.y = float(slab_index) * 0.72


func _build_edge_rubble() -> void:
	var river_rock: Material = detail_materials.get_material("river_rock")
	var paving: Material = detail_materials.get_material("paving")
	for index: int in range(24):
		var side: float = -1.0 if index % 2 == 0 else 1.0
		var z_value: float = 10.5 - float(index) * 0.78
		var material: Material = river_rock if index % 3 == 0 else paving
		var rubble := _add_visual_box(
			architecture_root,
			"DetailRubble%02d" % index,
			Vector3(
				0.22 + float(index % 4) * 0.11,
				0.13 + float(index % 3) * 0.08,
				0.28 + float(index % 5) * 0.09
			),
			Vector3(
				side * (2.45 + float(index % 4) * 0.24),
				0.14 + minf(float(index) * 0.045, 1.0),
				z_value
			),
			material,
			Vector3(float(index) * 0.19, float(index) * 0.47, float(index % 6) * 0.13)
		)
		rubble.set_meta("surface_detail", "loose_rubble")
		detail_counts["rubble_details"] = int(detail_counts["rubble_details"]) + 1


func _dress_shrine_landmark() -> void:
	var roof_material: Material = material_library.get_material("roof")
	var wood: Material = material_library.get_material("wood")
	var paving: Material = detail_materials.get_material("paving")
	var moss: Material = material_library.get_material("moss")

	for roof_name: String in ["RoofPlaneFront", "RoofPlaneBack"]:
		var roof_plane: MeshInstance3D = get_node_or_null(
			"GreenGrottoArt/AncientRuins/" + roof_name
		) as MeshInstance3D
		if roof_plane == null:
			continue
		for index: int in range(13):
			var x_value: float = -4.85 + float(index) * 0.81
			_add_visual_box(
				roof_plane,
				"RoofTileRib%02d" % index,
				Vector3(0.11, 0.11, 3.28),
				Vector3(x_value, 0.22, 0.0),
				roof_material
			)
			detail_counts["shrine_details"] = int(detail_counts["shrine_details"]) + 1

	# Layered bracket blocks beneath the broad eaves strengthen the Chinese-inspired
	# silhouette even before bespoke imported architecture arrives.
	for z_side: float in [-1.0, 1.0]:
		for index: int in range(7):
			var x_value: float = -4.2 + float(index) * 1.4
			var center := Vector3(x_value, 6.36, -14.45 + z_side * 2.68)
			_add_visual_box(
				architecture_root,
				"EaveBracketUpper",
				Vector3(0.78, 0.18, 0.32),
				center,
				wood,
				Vector3(0.0, 0.0, (0.06 if index % 2 == 0 else -0.06))
			)
			_add_visual_box(
				architecture_root,
				"EaveBracketLower",
				Vector3(0.38, 0.38, 0.30),
				center + Vector3(0.0, -0.24, -z_side * 0.04),
				wood
			)
			detail_counts["shrine_details"] = int(detail_counts["shrine_details"]) + 2

	# Broken forecourt paving gives the shrine a human-made surface distinct from
	# the natural grotto soil and the rough causeway.
	for row: int in range(3):
		for column: int in range(6):
			var index: int = row * 6 + column
			if index in [2, 9, 15]:
				continue
			_add_visual_box(
				architecture_root,
				"ShrineCourtPaver%02d" % index,
				Vector3(1.22, 0.045, 1.08),
				Vector3(
					-3.25 + float(column) * 1.30,
					2.32 + float(index % 2) * 0.004,
					-12.4 - float(row) * 1.18
				),
				paving,
				Vector3(0.0, sin(float(index) * 1.37) * 0.025, 0.0)
			)
			detail_counts["paving_stones"] = int(detail_counts["paving_stones"]) + 1

	for index: int in range(8):
		var patch := _add_visual_sphere(
			architecture_root,
			"ShrineMossCreepDetail%02d" % index,
			Vector3(
				(-1.0 if index % 2 == 0 else 1.0) * (3.4 + float(index % 3) * 0.45),
				2.37,
				-12.2 - float(index % 4) * 1.55
			),
			0.62 + float(index % 2) * 0.18,
			moss,
			Vector3(1.5, 0.025, 0.72)
		)
		patch.rotation.y = float(index) * 0.54


func _build_ecology_pockets() -> void:
	var wet_soil: Material = detail_materials.get_material("soil_wet")
	var leaf_litter: Material = detail_materials.get_material("leaf_litter")
	var river_rock: Material = detail_materials.get_material("river_rock")

	var pockets: Array[Dictionary] = [
		{"pos": Vector3(-4.8, 0.06, 10.2), "scale": Vector3(2.1, 0.035, 1.2), "wet": false},
		{"pos": Vector3(4.5, 0.08, 8.4), "scale": Vector3(1.7, 0.030, 1.0), "wet": true},
		{"pos": Vector3(-4.2, 0.62, 1.8), "scale": Vector3(1.6, 0.030, 0.9), "wet": false},
		{"pos": Vector3(4.8, 1.02, -2.8), "scale": Vector3(1.8, 0.030, 1.2), "wet": true},
		{"pos": Vector3(-6.5, 1.56, -5.2), "scale": Vector3(2.2, 0.035, 1.2), "wet": false},
		{"pos": Vector3(6.6, 2.15, -7.4), "scale": Vector3(1.6, 0.030, 1.0), "wet": true},
		{"pos": Vector3(-4.6, 2.38, -15.6), "scale": Vector3(1.9, 0.030, 1.1), "wet": false},
	]
	for index: int in range(pockets.size()):
		var spec: Dictionary = pockets[index]
		var material: Material = wet_soil if bool(spec["wet"]) else leaf_litter
		var patch := _add_visual_sphere(
			foliage_root,
			"EcologyPocket%02d" % index,
			spec["pos"] as Vector3,
			0.78,
			material,
			spec["scale"] as Vector3
		)
		patch.rotation.y = float(index) * 0.71
		detail_counts["ecology_pockets"] = int(detail_counts["ecology_pockets"]) + 1

	# Extra vegetation is clustered around those pockets instead of being evenly
	# distributed down the centerline.
	_add_fern(Vector3(-4.9, 0.10, 10.6), 0.95, 110)
	_add_fern(Vector3(4.7, 0.14, 8.7), 0.82, 111)
	_add_cycad(Vector3(-6.6, 1.58, -5.5), 0.88, 112)
	_add_fern(Vector3(6.9, 2.20, -7.8), 0.92, 113)
	_add_cycad(Vector3(-4.8, 2.42, -15.9), 0.82, 114)

	for index: int in range(14):
		var side: float = -1.0 if index % 2 == 0 else 1.0
		var rock := _add_visual_sphere(
			foliage_root,
			"EcologyStone%02d" % index,
			Vector3(
				side * (3.1 + float(index % 4) * 0.62),
				0.12 + minf(float(index) * 0.08, 1.8),
				9.8 - float(index) * 1.75
			),
			0.34 + float(index % 4) * 0.11,
			river_rock,
			Vector3(1.2, 0.62, 1.0)
		)
		rock.rotation = Vector3(float(index % 3) * 0.12, float(index) * 0.49, float(index % 5) * 0.08)


func _rebalance_grotto_lighting() -> void:
	var sun: DirectionalLight3D = get_node_or_null(
		"GreenGrottoArt/Lighting/CanopySunset"
	) as DirectionalLight3D
	if sun != null:
		sun.light_energy = 1.92
		sun.light_volumetric_fog_energy = 1.95

	var fill: DirectionalLight3D = get_node_or_null(
		"GreenGrottoArt/Lighting/GrottoGreenFill"
	) as DirectionalLight3D
	if fill != null:
		fill.light_color = Color(0.14, 0.36, 0.25, 1.0)
		fill.light_energy = 0.54

	var shrine_bounce: OmniLight3D = get_node_or_null(
		"GreenGrottoArt/Lighting/ShrineSunBounce"
	) as OmniLight3D
	if shrine_bounce != null:
		shrine_bounce.light_energy = 3.85

	var water_bounce: OmniLight3D = get_node_or_null(
		"GreenGrottoArt/Lighting/WaterCoolBounce"
	) as OmniLight3D
	if water_bounce != null:
		water_bounce.light_color = Color(0.075, 0.35, 0.27, 1.0)
		water_bounce.light_energy = 1.48

	var world_environment: WorldEnvironment = get_node_or_null(
		"GreenGrottoArt/Lighting/GreenGrottoEnvironment"
	) as WorldEnvironment
	if world_environment != null and world_environment.environment != null:
		var environment: Environment = world_environment.environment
		environment.fog_light_color = Color(0.37, 0.34, 0.20, 1.0)
		environment.fog_light_energy = 0.62
		environment.volumetric_fog_albedo = Color(0.62, 0.58, 0.38, 1.0)
		environment.ambient_light_color = Color(0.13, 0.27, 0.19, 1.0)
		environment.ambient_light_energy = 0.48


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["green_grotto_detail_pass"] = true
	data["detail_pass"] = "v2_water_ground_microdetail"
	data["detail_counts"] = detail_counts.duplicate(true)
	data["detail_materials"] = detail_materials.get_debug_data() if detail_materials != null else {}
	data["water_geography"] = "upper_stream -> waterfall -> lower_basin"
	data["expansion_strategy"] = "quality_benchmark_before_larger_set"
	return data
