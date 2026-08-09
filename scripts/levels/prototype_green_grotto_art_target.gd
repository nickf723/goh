extends Node3D
class_name PrototypeGreenGrottoArtTarget

const MaterialLibraryScript = preload(
	"res://scripts/environment/green_grotto_material_library.gd"
)
const FaunaVisualScript = preload(
	"res://scripts/environment/green_grotto_fauna_visual.gd"
)

const PLAYER_SPAWN := Vector3(0.0, 1.2, 16.0)

var material_library: GreenGrottoMaterialLibrary = null
var environment_root: Node3D = null
var architecture_root: Node3D = null
var terrain_root: Node3D = null
var foliage_root: Node3D = null
var canopy_root: Node3D = null
var water_root: Node3D = null
var fauna_root: Node3D = null
var lighting_root: Node3D = null

var build_counts: Dictionary = {
	"static_surfaces": 0,
	"visual_meshes": 0,
	"ruin_modules": 0,
	"foliage_clusters": 0,
	"trees": 0,
	"roots": 0,
	"waterfalls": 0,
	"fauna": 0,
}


func _ready() -> void:
	add_to_group("green_grotto_art_target")
	add_to_group("environment_art_target")
	set_meta("art_target", "green_earth_chinese_grotto")
	set_meta("visual_priority", "environment_first")
	set_meta("production_vfx_deferred", true)
	set_meta("production_audio_deferred", true)
	material_library = MaterialLibraryScript.new() as GreenGrottoMaterialLibrary
	_build_roots()
	_build_world_environment()
	_build_grotto_shell()
	_build_main_causeway()
	_build_shrine_landmark()
	_build_secondary_ruins()
	_build_canopy()
	_build_prehistoric_foliage()
	_build_water_system()
	_build_fauna()
	_build_fall_recovery()
	_configure_player()
	set_meta("build_counts", build_counts.duplicate(true))
	GameState.set_objective(
		"Green Earth art target • cross the fractured grotto causeway toward the sunset shrine."
	)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_scene"):
		_reset_player()
		get_viewport().set_input_as_handled()


func _build_roots() -> void:
	environment_root = Node3D.new()
	environment_root.name = "GreenGrottoArt"
	add_child(environment_root)

	terrain_root = _new_root(environment_root, "Terrain")
	architecture_root = _new_root(environment_root, "AncientRuins")
	foliage_root = _new_root(environment_root, "PrehistoricFoliage")
	canopy_root = _new_root(environment_root, "Canopy")
	water_root = _new_root(environment_root, "Water")
	fauna_root = _new_root(environment_root, "Fauna")
	lighting_root = _new_root(environment_root, "Lighting")


func _build_world_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "GreenGrottoEnvironment"
	var environment := Environment.new()

	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.008, 0.025, 0.018, 1.0)
	sky_material.sky_horizon_color = Color(0.92, 0.43, 0.105, 1.0)
	sky_material.ground_bottom_color = Color(0.006, 0.012, 0.008, 1.0)
	sky_material.ground_horizon_color = Color(0.20, 0.13, 0.055, 1.0)
	sky_material.sun_angle_max = 14.0
	sky_material.sun_curve = 0.045
	var sky := Sky.new()
	sky.sky_material = sky_material

	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.background_energy_multiplier = 0.58
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_color = Color(0.16, 0.25, 0.18, 1.0)
	environment.ambient_light_energy = 0.42
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.03
	environment.tonemap_white = 1.48

	environment.fog_enabled = true
	environment.fog_light_color = Color(0.46, 0.35, 0.17, 1.0)
	environment.fog_light_energy = 0.72
	environment.fog_density = 0.0065
	environment.fog_height = 2.5
	environment.fog_height_density = 0.09
	environment.fog_sun_scatter = 0.72
	environment.fog_sky_affect = 0.42

	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.028
	environment.volumetric_fog_albedo = Color(0.78, 0.66, 0.42, 1.0)
	environment.volumetric_fog_emission = Color(0.018, 0.028, 0.018, 1.0)
	environment.volumetric_fog_emission_energy = 0.08
	environment.volumetric_fog_length = 62.0
	environment.volumetric_fog_detail_spread = 1.8
	environment.volumetric_fog_ambient_inject = 0.24
	environment.volumetric_fog_anisotropy = 0.78
	environment.volumetric_fog_temporal_reprojection_enabled = true

	environment.glow_enabled = true
	environment.glow_intensity = 0.22
	environment.glow_bloom = 0.04
	environment.glow_hdr_threshold = 1.35
	environment.ssao_enabled = true
	environment.ssao_intensity = 2.0
	environment.ssao_radius = 2.8

	world_environment.environment = environment
	lighting_root.add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.name = "CanopySunset"
	sun.rotation_degrees = Vector3(-35.0, 19.0, -3.0)
	sun.light_color = Color(1.0, 0.56, 0.22, 1.0)
	sun.light_energy = 2.15
	sun.light_volumetric_fog_energy = 2.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 92.0
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
	lighting_root.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.name = "GrottoGreenFill"
	fill.rotation_degrees = Vector3(-64.0, 164.0, 0.0)
	fill.light_color = Color(0.18, 0.34, 0.23, 1.0)
	fill.light_energy = 0.38
	fill.light_volumetric_fog_energy = 0.15
	fill.shadow_enabled = false
	fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	lighting_root.add_child(fill)

	_add_omni_light(
		"ShrineSunBounce",
		Vector3(0.0, 6.2, -20.0),
		Color(1.0, 0.40, 0.10, 1.0),
		4.8,
		22.0,
		1.35
	)
	_add_omni_light(
		"WaterCoolBounce",
		Vector3(5.5, -2.0, -7.0),
		Color(0.10, 0.32, 0.24, 1.0),
		1.15,
		14.0,
		0.18
	)


func _build_grotto_shell() -> void:
	var stone_dark: Material = material_library.get_material("stone_dark")
	var soil: Material = material_library.get_material("soil")
	var stone: Material = material_library.get_material("stone")

	# Shadowed arrival shelf.
	_add_static_box(
		terrain_root,
		"ArrivalShelf",
		Vector3(10.0, 1.3, 10.0),
		Vector3(0.0, -0.65, 13.0),
		stone
	)
	_add_surface_moss(Vector3(-3.4, 0.03, 11.0), Vector3(2.4, 0.035, 1.2), 0.18)
	_add_surface_moss(Vector3(3.6, 0.04, 14.0), Vector3(2.2, 0.035, 1.4), -0.24)

	# Grotto cliff walls. They deliberately lean inward to frame the central view.
	var cliff_specs: Array[Dictionary] = [
		{"name": "CliffLeftNear", "size": Vector3(7.0, 13.0, 18.0), "pos": Vector3(-10.6, 2.0, 8.0), "rot": Vector3(0.03, -0.11, 0.12)},
		{"name": "CliffRightNear", "size": Vector3(7.2, 14.0, 18.0), "pos": Vector3(10.8, 2.3, 7.0), "rot": Vector3(-0.04, 0.08, -0.10)},
		{"name": "CliffLeftDeep", "size": Vector3(8.0, 15.0, 20.0), "pos": Vector3(-11.8, 1.0, -10.0), "rot": Vector3(0.02, 0.16, 0.08)},
		{"name": "CliffRightDeep", "size": Vector3(8.0, 15.5, 20.0), "pos": Vector3(12.0, 1.2, -11.0), "rot": Vector3(-0.03, -0.14, -0.09)},
	]
	for spec: Dictionary in cliff_specs:
		_add_static_box(
			terrain_root,
			str(spec["name"]),
			spec["size"] as Vector3,
			spec["pos"] as Vector3,
			stone_dark,
			spec["rot"] as Vector3
		)

	# Chunky rock breakup over the cliff boxes stops the silhouette reading as a wall.
	for index: int in range(20):
		var side: float = -1.0 if index % 2 == 0 else 1.0
		var z_value: float = 15.0 - float(index) * 1.75
		var y_value: float = -1.2 + float((index * 7) % 6) * 1.2
		var radius: float = 1.2 + float(index % 4) * 0.42
		var rock := _add_visual_sphere(
			terrain_root,
			"CliffRock%02d" % index,
			Vector3(side * (7.6 + float(index % 3) * 0.9), y_value, z_value),
			radius,
			stone_dark,
			Vector3(1.4, 0.9 + float(index % 2) * 0.3, 1.2)
		)
		rock.rotation = Vector3(float(index % 3) * 0.18, float(index) * 0.37, float(index % 4) * 0.13)

	# Deep soil/stone silhouettes beyond the shrine, hiding the finite prototype set.
	_add_static_box(
		terrain_root,
		"BackMountain",
		Vector3(34.0, 18.0, 8.0),
		Vector3(0.0, 2.0, -29.0),
		soil,
		Vector3(-0.08, 0.0, 0.0)
	)
	for index: int in range(7):
		_add_visual_sphere(
			terrain_root,
			"BackRock%02d" % index,
			Vector3(-12.0 + float(index) * 4.0, 8.0 + float(index % 3), -24.0 - float(index % 2) * 2.0),
			3.4 + float(index % 2),
			stone_dark,
			Vector3(1.25, 1.0, 1.0)
		)


func _build_main_causeway() -> void:
	var stone: Material = material_library.get_material("stone")
	var warm_stone: Material = material_library.get_material("stone_warm")
	var dark_stone: Material = material_library.get_material("stone_dark")

	var slabs: Array[Dictionary] = [
		{"pos": Vector3(0.0, 0.0, 8.7), "size": Vector3(5.7, 0.52, 4.2), "rot": Vector3(0.0, 0.02, 0.0)},
		{"pos": Vector3(-0.20, 0.10, 5.0), "size": Vector3(5.4, 0.56, 3.2), "rot": Vector3(0.008, -0.025, -0.012)},
		{"pos": Vector3(0.18, 0.30, 2.05), "size": Vector3(5.1, 0.58, 2.7), "rot": Vector3(-0.015, 0.04, 0.018)},
		{"pos": Vector3(-0.28, 0.54, -0.55), "size": Vector3(4.7, 0.60, 2.45), "rot": Vector3(0.02, -0.055, -0.03)},
		{"pos": Vector3(0.25, 0.74, -2.95), "size": Vector3(4.4, 0.58, 2.2), "rot": Vector3(-0.01, 0.075, 0.025)},
		{"pos": Vector3(0.04, 0.90, -5.15), "size": Vector3(4.1, 0.56, 2.1), "rot": Vector3(0.018, -0.035, -0.018)},
		{"pos": Vector3(-0.12, 1.02, -7.20), "size": Vector3(4.4, 0.60, 2.25), "rot": Vector3(-0.012, 0.025, 0.012)},
	]
	for index: int in range(slabs.size()):
		var spec: Dictionary = slabs[index]
		var material: Material = warm_stone if index >= 4 else stone
		var slab := _add_static_box(
			architecture_root,
			"CausewaySlab%02d" % index,
			spec["size"] as Vector3,
			spec["pos"] as Vector3,
			material,
			spec["rot"] as Vector3
		)
		slab.add_to_group("green_grotto_causeway")
		slab.set_meta("unstable_geography", true)
		_add_cracks_to_slab(spec["pos"] as Vector3, spec["size"] as Vector3, index)
		if index % 2 == 0:
			_add_surface_moss(
				(spec["pos"] as Vector3) + Vector3(-1.25 + float(index % 3) * 0.4, (spec["size"] as Vector3).y * 0.52 + 0.03, 0.4),
				Vector3(1.0 + float(index % 2) * 0.4, 0.03, 0.44),
				float(index) * 0.21
			)

	# Broken edge blocks under the bridge make it feel assembled from a collapsed ruin.
	for index: int in range(10):
		var side: float = -1.0 if index % 2 == 0 else 1.0
		var z_value: float = 7.6 - float(index) * 1.62
		var block := _add_visual_box(
			architecture_root,
			"CausewayEdgeBlock%02d" % index,
			Vector3(0.72 + float(index % 3) * 0.18, 0.5, 1.05),
			Vector3(side * (2.0 + float(index % 3) * 0.28), 0.05 + float(index) * 0.11, z_value),
			warm_stone,
			Vector3(float(index % 2) * 0.08, float(index) * 0.17, side * 0.11)
		)
		block.set_meta("ruin_fragment", true)

	# Side terraces give the grotto layered traversal/readability without competing with the shrine.
	_add_static_box(
		architecture_root,
		"LeftTerrace",
		Vector3(6.5, 1.0, 6.5),
		Vector3(-6.2, 1.0, -3.8),
		stone,
		Vector3(0.0, -0.08, 0.02)
	)
	_add_static_box(
		architecture_root,
		"RightTerrace",
		Vector3(6.0, 1.2, 7.0),
		Vector3(6.5, 1.5, -8.0),
		warm_stone,
		Vector3(0.0, 0.08, -0.015)
	)
	_add_static_box(
		architecture_root,
		"RightBrokenLedge",
		Vector3(3.7, 0.55, 4.0),
		Vector3(6.1, 1.95, -2.0),
		dark_stone,
		Vector3(0.04, -0.18, 0.055)
	)

	build_counts["ruin_modules"] = int(build_counts["ruin_modules"]) + slabs.size() + 3


func _build_shrine_landmark() -> void:
	var stone: Material = material_library.get_material("stone_warm")
	var trim: Material = material_library.get_material("stone")
	var roof: Material = material_library.get_material("roof")
	var wood: Material = material_library.get_material("wood")
	var moss: Material = material_library.get_material("moss")

	# Elevated shrine foundation.
	_add_static_box(
		architecture_root,
		"ShrineFoundation",
		Vector3(12.6, 1.6, 9.4),
		Vector3(0.0, 1.45, -14.7),
		stone
	)
	_add_visual_box(
		architecture_root,
		"ShrineFoundationTrim",
		Vector3(13.0, 0.26, 9.8),
		Vector3(0.0, 2.30, -14.7),
		trim
	)

	# Broad ceremonial stair climbs out of the fractured causeway.
	for index: int in range(6):
		var height: float = 0.30 + float(index) * 0.30
		var z_value: float = -8.75 - float(index) * 0.72
		_add_static_box(
			architecture_root,
			"ShrineStep%02d" % index,
			Vector3(6.6 - float(index) * 0.18, height, 0.82),
			Vector3(0.0, height * 0.5 + 0.98, z_value),
			stone
		)

	var column_positions: Array[Vector3] = [
		Vector3(-3.55, 0.0, -12.1),
		Vector3(0.0, 0.0, -12.1),
		Vector3(3.55, 0.0, -12.1),
		Vector3(-3.55, 0.0, -16.8),
		Vector3(0.0, 0.0, -16.8),
		Vector3(3.55, 0.0, -16.8),
	]
	for index: int in range(column_positions.size()):
		_build_shrine_column("ShrineColumn%02d" % index, column_positions[index], 4.25, stone, trim)

	# Lintels and crossbeams suggest a Chinese timber/stone hybrid without borrowing the European kit.
	for z_value: float in [-12.1, -16.8]:
		_add_visual_box(
			architecture_root,
			"ShrineBeam",
			Vector3(8.7, 0.38, 0.52),
			Vector3(0.0, 6.18, z_value),
			wood
		)
		_add_visual_box(
			architecture_root,
			"ShrineStoneLintel",
			Vector3(9.4, 0.25, 0.68),
			Vector3(0.0, 5.78, z_value),
			trim
		)
	for x_value: float in [-3.55, 3.55]:
		_add_visual_box(
			architecture_root,
			"ShrineSideBeam",
			Vector3(0.46, 0.36, 5.4),
			Vector3(x_value, 6.06, -14.45),
			wood
		)

	# Layered pitched roof with oversized eaves is the primary Chinese silhouette cue.
	for side: float in [-1.0, 1.0]:
		var roof_plane := _add_visual_box(
			architecture_root,
			"RoofPlane" + ("Front" if side > 0.0 else "Back"),
			Vector3(10.8, 0.34, 3.45),
			Vector3(0.0, 6.92, -14.45 + side * 1.53),
			roof,
			Vector3(side * -0.18, 0.0, 0.0)
		)
		roof_plane.set_meta("landmark_roof", true)
		_add_visual_box(
			architecture_root,
			"RoofEave" + ("Front" if side > 0.0 else "Back"),
			Vector3(11.7, 0.20, 0.46),
			Vector3(0.0, 6.62, -14.45 + side * 3.05),
			wood,
			Vector3(side * 0.08, 0.0, 0.0)
		)
	_add_visual_box(
		architecture_root,
		"RoofRidge",
		Vector3(10.9, 0.46, 0.52),
		Vector3(0.0, 7.28, -14.45),
		roof
	)
	for x_side: float in [-1.0, 1.0]:
		for z_side: float in [-1.0, 1.0]:
			_add_visual_box(
				architecture_root,
				"UpturnedEave",
				Vector3(1.15, 0.18, 0.32),
				Vector3(x_side * 5.72, 6.82, -14.45 + z_side * 2.88),
				roof,
				Vector3(z_side * 0.10, 0.0, x_side * z_side * 0.19)
			)

	# Rear altar wall, doorway, and carved strips.
	_add_static_box(
		architecture_root,
		"ShrineRearWallLeft",
		Vector3(3.7, 3.25, 0.52),
		Vector3(-3.0, 3.92, -17.8),
		stone
	)
	_add_static_box(
		architecture_root,
		"ShrineRearWallRight",
		Vector3(3.7, 3.25, 0.52),
		Vector3(3.0, 3.92, -17.8),
		stone
	)
	_add_static_box(
		architecture_root,
		"ShrineRearWallTop",
		Vector3(2.5, 0.62, 0.52),
		Vector3(0.0, 5.24, -17.8),
		trim
	)
	for index: int in range(7):
		var x_value: float = -4.5 + float(index) * 1.5
		_add_visual_box(
			architecture_root,
			"CarvedFrieze%02d" % index,
			Vector3(0.74, 0.15, 0.08),
			Vector3(x_value, 5.56, -17.55),
			trim,
			Vector3(0.0, 0.0, float(index % 2) * 0.08)
		)

	# Heavy root takeover keeps architecture ancient rather than pristine.
	_add_root_chain([
		Vector3(-5.0, 7.6, -16.8),
		Vector3(-4.4, 6.2, -16.2),
		Vector3(-3.8, 5.0, -15.3),
		Vector3(-4.2, 3.6, -14.0),
		Vector3(-4.9, 2.4, -13.0),
	], 0.30, 0.13)
	_add_root_chain([
		Vector3(4.8, 8.0, -13.0),
		Vector3(4.2, 6.7, -13.7),
		Vector3(3.8, 5.2, -14.5),
		Vector3(4.4, 3.8, -15.3),
		Vector3(5.3, 2.4, -16.1),
	], 0.32, 0.14)

	for index: int in range(6):
		_add_visual_box(
			architecture_root,
			"ShrineMoss%02d" % index,
			Vector3(1.5 + float(index % 2) * 0.8, 0.035, 0.46 + float(index % 3) * 0.18),
			Vector3(-4.5 + float(index) * 1.75, 2.34, -13.0 - float(index % 2) * 3.2),
			moss,
			Vector3(0.0, float(index) * 0.21, 0.0)
		)

	build_counts["ruin_modules"] = int(build_counts["ruin_modules"]) + 24


func _build_secondary_ruins() -> void:
	var stone: Material = material_library.get_material("stone")
	var warm_stone: Material = material_library.get_material("stone_warm")
	var dark_stone: Material = material_library.get_material("stone_dark")

	# Leaning carved monolith on the left foreground.
	var monolith := _add_static_box(
		architecture_root,
		"LeaningMonolith",
		Vector3(1.15, 6.3, 1.0),
		Vector3(-6.7, 2.5, 7.5),
		stone,
		Vector3(0.08, -0.15, 0.19)
	)
	monolith.set_meta("ancient_carving", true)
	for index: int in range(5):
		_add_visual_box(
			architecture_root,
			"MonolithRelief%02d" % index,
			Vector3(0.62, 0.18, 0.07),
			Vector3(-6.95, 0.7 + float(index) * 0.9, 7.02),
			warm_stone,
			Vector3(0.08, -0.15, 0.19 + float(index % 2) * 0.08)
		)

	# Broken gate on left terrace.
	_build_ruin_gate(
		"LeftBrokenGate",
		Vector3(-6.1, 1.52, -3.8),
		2.7,
		3.8,
		stone,
		warm_stone,
		-0.08
	)

	# Partial colonnade behind the right terrace.
	for index: int in range(4):
		var x_value: float = 4.2 + float(index) * 2.0
		var height: float = 3.1 + float(index % 3) * 0.75
		var pillar := _add_static_cylinder(
			architecture_root,
			"RightRuinPillar%02d" % index,
			0.42,
			height,
			Vector3(x_value, 2.05 + height * 0.5, -11.0 - float(index % 2) * 1.0),
			dark_stone,
			Vector3(0.0, 0.0, -0.04 + float(index) * 0.025)
		)
		pillar.set_meta("ruin_fragment", true)

	# Fallen lintels and blocks scattered below the path.
	for index: int in range(13):
		var side: float = -1.0 if index % 2 == 0 else 1.0
		_add_visual_box(
			architecture_root,
			"CollapsedBlock%02d" % index,
			Vector3(0.8 + float(index % 4) * 0.3, 0.55 + float(index % 2) * 0.22, 0.9 + float(index % 3) * 0.25),
			Vector3(side * (3.7 + float(index % 5) * 0.65), -1.7 - float(index % 3) * 0.6, 5.5 - float(index) * 1.4),
			stone,
			Vector3(float(index) * 0.11, float(index) * 0.33, float(index % 5) * 0.14)
		)

	build_counts["ruin_modules"] = int(build_counts["ruin_modules"]) + 20


func _build_canopy() -> void:
	var bark: Material = material_library.get_material("bark")
	var canopy: Material = material_library.get_material("canopy")

	var tree_specs: Array[Dictionary] = [
		{"pos": Vector3(-8.5, 6.8, 12.0), "radius": 1.25, "height": 15.0, "rot": Vector3(0.07, 0.0, -0.11)},
		{"pos": Vector3(8.8, 7.3, 10.0), "radius": 1.38, "height": 16.0, "rot": Vector3(-0.08, 0.0, 0.10)},
		{"pos": Vector3(-9.2, 7.6, -9.5), "radius": 1.55, "height": 17.0, "rot": Vector3(0.05, 0.0, 0.12)},
		{"pos": Vector3(9.8, 8.0, -15.0), "radius": 1.65, "height": 18.0, "rot": Vector3(-0.05, 0.0, -0.10)},
		{"pos": Vector3(-2.0, 10.8, -25.0), "radius": 1.75, "height": 19.0, "rot": Vector3(0.10, 0.0, 0.03)},
	]
	for index: int in range(tree_specs.size()):
		var spec: Dictionary = tree_specs[index]
		var trunk := _add_visual_cylinder(
			canopy_root,
			"CanopyTrunk%02d" % index,
			float(spec["radius"]),
			float(spec["height"]),
			spec["pos"] as Vector3,
			bark,
			spec["rot"] as Vector3,
			14
		)
		trunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		build_counts["trees"] = int(build_counts["trees"]) + 1

	# Interlocking canopy crowns create genuine shadow breakup for the sunset light.
	for index: int in range(28):
		var angle: float = TAU * float(index) / 28.0
		var ring: float = 7.5 + float(index % 4) * 1.35
		var x_value: float = cos(angle) * ring
		var z_value: float = -4.0 + sin(angle) * (12.0 + float(index % 3))
		var y_value: float = 12.2 + float((index * 5) % 5) * 0.9
		var crown := _add_visual_sphere(
			canopy_root,
			"CanopyCrown%02d" % index,
			Vector3(x_value, y_value, z_value),
			2.3 + float(index % 3) * 0.55,
			canopy,
			Vector3(1.55, 0.65 + float(index % 2) * 0.15, 1.3)
		)
		crown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	# A few central clusters leave deliberate holes so sunset shafts emerge naturally.
	for spec: Dictionary in [
		{"pos": Vector3(-4.4, 14.1, -2.0), "scale": Vector3(1.4, 0.65, 1.1)},
		{"pos": Vector3(4.8, 14.5, 2.0), "scale": Vector3(1.35, 0.62, 1.25)},
		{"pos": Vector3(-5.0, 15.0, -16.5), "scale": Vector3(1.5, 0.7, 1.3)},
	]:
		_add_visual_sphere(
			canopy_root,
			"CanopyInner",
			spec["pos"] as Vector3,
			2.8,
			canopy,
			spec["scale"] as Vector3
		)

	# Massive surface roots cross architecture and make the grotto feel biologically sealed.
	var root_chains: Array[Array] = [
		[Vector3(-8.5, 1.0, 12.0), Vector3(-6.4, 0.55, 10.2), Vector3(-4.2, 0.2, 9.0), Vector3(-2.3, 0.05, 8.3)],
		[Vector3(8.8, 1.0, 10.0), Vector3(6.9, 0.4, 8.2), Vector3(5.4, 0.0, 6.8), Vector3(3.8, -0.2, 5.4)],
		[Vector3(-9.2, 2.1, -9.5), Vector3(-7.5, 1.8, -7.3), Vector3(-6.3, 1.6, -5.0), Vector3(-5.3, 1.35, -3.7)],
		[Vector3(9.8, 2.6, -15.0), Vector3(7.8, 2.5, -14.4), Vector3(6.1, 2.35, -13.5), Vector3(5.2, 2.25, -12.2)],
	]
	for chain: Array in root_chains:
		var points: Array[Vector3] = []
		for point_value: Variant in chain:
			if point_value is Vector3:
				points.append(point_value as Vector3)
		_add_root_chain(points, 0.38, 0.13)

	# Hanging vines create vertical curtains at the edges, not across the critical route.
	for index: int in range(28):
		var side: float = -1.0 if index % 2 == 0 else 1.0
		var top := Vector3(
			side * (6.2 + float(index % 5) * 0.85),
			13.8 + float(index % 4) * 0.45,
			13.0 - float(index) * 1.32
		)
		var length: float = 2.8 + float(index % 6) * 0.75
		_add_visual_cylinder_between(
			canopy_root,
			"HangingVine%02d" % index,
			top,
			top + Vector3(sin(float(index)) * 0.22, -length, cos(float(index) * 0.8) * 0.18),
			0.045 + float(index % 3) * 0.012,
			material_library.get_material("root"),
			6
		)


func _build_prehistoric_foliage() -> void:
	var foliage_specs: Array[Dictionary] = [
		{"pos": Vector3(-3.8, 0.15, 12.5), "scale": 1.15},
		{"pos": Vector3(3.9, 0.12, 11.2), "scale": 1.0},
		{"pos": Vector3(-3.5, 0.45, 6.6), "scale": 0.9},
		{"pos": Vector3(4.1, 0.48, 4.7), "scale": 1.25},
		{"pos": Vector3(-4.2, 0.72, 0.6), "scale": 1.4},
		{"pos": Vector3(4.5, 0.9, -1.6), "scale": 1.0},
		{"pos": Vector3(-7.1, 1.55, -4.2), "scale": 1.5},
		{"pos": Vector3(-4.8, 1.5, -6.4), "scale": 0.95},
		{"pos": Vector3(5.4, 2.1, -7.5), "scale": 1.35},
		{"pos": Vector3(7.6, 2.2, -10.8), "scale": 1.25},
		{"pos": Vector3(-5.2, 2.42, -12.7), "scale": 1.1},
		{"pos": Vector3(4.9, 2.42, -13.0), "scale": 0.9},
		{"pos": Vector3(-4.6, 2.42, -16.5), "scale": 1.3},
		{"pos": Vector3(4.4, 2.42, -17.0), "scale": 1.2},
	]
	for index: int in range(foliage_specs.size()):
		var spec: Dictionary = foliage_specs[index]
		if index % 3 == 0:
			_add_cycad(spec["pos"] as Vector3, float(spec["scale"]), index)
		else:
			_add_fern(spec["pos"] as Vector3, float(spec["scale"]), index)

	# Tiny low ground plants add density without filling the walkable center.
	for index: int in range(24):
		var side: float = -1.0 if index % 2 == 0 else 1.0
		var x_value: float = side * (2.7 + float(index % 5) * 0.55)
		var z_value: float = 14.0 - float(index) * 1.35
		var y_value: float = 0.10 + minf(float(index) * 0.055, 2.0)
		_add_leaf_cluster(
			Vector3(x_value, y_value, z_value),
			0.45 + float(index % 3) * 0.15,
			index
		)


func _build_water_system() -> void:
	var water: Material = material_library.get_material("water")
	var waterfall: Material = material_library.get_material("waterfall")
	var dark_stone: Material = material_library.get_material("stone_dark")

	# Pool at the bottom of the chasm gives depth and a cool counter-color.
	_add_visual_box(
		water_root,
		"GrottoPool",
		Vector3(13.5, 0.12, 25.0),
		Vector3(2.0, -6.35, -4.0),
		water
	)

	# Waterfall from the right terrace, built as overlapping translucent ribbons.
	for index: int in range(3):
		var width: float = 1.25 - float(index) * 0.22
		var x_value: float = 5.7 + float(index) * 0.46
		var ribbon := _add_visual_box(
			water_root,
			"WaterfallRibbon%02d" % index,
			Vector3(width, 8.2 + float(index) * 0.4, 0.11),
			Vector3(x_value, -1.92 - float(index) * 0.15, -10.8 + float(index) * 0.22),
			waterfall,
			Vector3(0.0, -0.04 + float(index) * 0.05, 0.015 * float(index))
		)
		ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		build_counts["waterfalls"] = int(build_counts["waterfalls"]) + 1

	# Rock lip and wet receiving shelf.
	_add_visual_box(
		water_root,
		"WaterfallLip",
		Vector3(3.6, 0.7, 2.3),
		Vector3(6.0, 2.1, -10.5),
		dark_stone,
		Vector3(-0.08, 0.04, -0.05)
	)


func _build_fauna() -> void:
	_add_fauna("RaptorArrival", "raptor", Vector3(-3.3, 0.12, 6.3), 0.78, 1.3, 0.0)
	_add_fauna("RaptorTerrace", "raptor", Vector3(5.6, 2.18, -8.4), 0.72, 0.85, 2.1)
	_add_fauna("RaptorShrine", "raptor", Vector3(-3.7, 2.42, -13.2), 0.62, 0.0, 4.0)
	_add_fauna("DistantSauropod", "sauropod", Vector3(-8.0, 2.9, -24.0), 0.62, 0.0, 1.4)


func _build_fall_recovery() -> void:
	var area := Area3D.new()
	area.name = "ChasmRecovery"
	area.position = Vector3(0.0, -9.0, -3.0)
	area.collision_layer = 0
	area.collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(34.0, 2.0, 48.0)
	collision.shape = shape
	area.add_child(collision)
	add_child(area)
	area.body_entered.connect(_on_chasm_body_entered)


func _on_chasm_body_entered(body: Node3D) -> void:
	if body == null or not body.is_in_group("player"):
		return
	if body is CharacterBody3D:
		(body as CharacterBody3D).velocity = Vector3.ZERO
	body.global_position = PLAYER_SPAWN


func _configure_player() -> void:
	var player: CharacterBody3D = get_node_or_null("Player") as CharacterBody3D
	if player == null:
		return
	player.global_position = PLAYER_SPAWN
	player.rotation.y = 0.0
	var spring_arm: SpringArm3D = player.get_node_or_null("CameraPivot/SpringArm3D") as SpringArm3D
	if spring_arm != null:
		spring_arm.spring_length = 6.7
	GameState.set_stat("max_health", maxi(GameState.get_stat("max_health"), 100))
	GameState.set_stat("health", GameState.get_stat("max_health"))
	GameState.set_stat("max_mana", maxi(GameState.get_stat("max_mana"), 100))
	GameState.set_stat("mana", GameState.get_stat("max_mana"))
	GameState.set_stat("max_stamina", maxi(GameState.get_stat("max_stamina"), 100))
	GameState.set_stat("stamina", GameState.get_stat("max_stamina"))


func _reset_player() -> void:
	var player: CharacterBody3D = get_node_or_null("Player") as CharacterBody3D
	if player == null:
		return
	player.global_position = PLAYER_SPAWN
	player.velocity = Vector3.ZERO
	_configure_player()


func _build_shrine_column(
	node_name: String,
	base_position: Vector3,
	height: float,
	stone: Material,
	trim: Material
) -> void:
	_add_static_cylinder(
		architecture_root,
		node_name + "Shaft",
		0.42,
		height,
		base_position + Vector3(0.0, 2.34 + height * 0.5, 0.0),
		stone
	)
	_add_visual_box(
		architecture_root,
		node_name + "Base",
		Vector3(1.15, 0.30, 1.15),
		base_position + Vector3(0.0, 2.49, 0.0),
		trim
	)
	_add_visual_box(
		architecture_root,
		node_name + "Capital",
		Vector3(1.28, 0.34, 1.28),
		base_position + Vector3(0.0, 2.34 + height - 0.08, 0.0),
		trim
	)
	for band_index: int in range(2):
		_add_visual_torus(
			architecture_root,
			node_name + "Band%02d" % band_index,
			0.38,
			0.47,
			base_position + Vector3(0.0, 3.25 + float(band_index) * 2.35, 0.0),
			trim
		)


func _build_ruin_gate(
	node_name: String,
	center: Vector3,
	opening_width: float,
	height: float,
	stone: Material,
	trim: Material,
	lean: float
) -> void:
	var root := _new_root(architecture_root, node_name)
	root.position = center
	root.rotation.z = lean
	for side: float in [-1.0, 1.0]:
		_add_static_box(
			root,
			"GatePost",
			Vector3(0.72, height, 0.82),
			Vector3(side * (opening_width * 0.5 + 0.42), height * 0.5, 0.0),
			stone
		)
		_add_visual_box(
			root,
			"GateFoot",
			Vector3(1.1, 0.3, 1.1),
			Vector3(side * (opening_width * 0.5 + 0.42), 0.15, 0.0),
			trim
		)
	_add_static_box(
		root,
		"GateLintel",
		Vector3(opening_width + 1.6, 0.62, 0.90),
		Vector3(0.0, height - 0.18, 0.0),
		trim,
		Vector3(0.0, 0.0, -lean * 0.35)
	)
	build_counts["ruin_modules"] = int(build_counts["ruin_modules"]) + 1


func _add_cracks_to_slab(position_value: Vector3, slab_size: Vector3, seed_value: int) -> void:
	var dark: Material = material_library.get_material("stone_dark")
	for index: int in range(3):
		var x_offset: float = sin(float(seed_value * 7 + index) * 1.73) * slab_size.x * 0.28
		var z_offset: float = cos(float(seed_value * 5 + index) * 1.29) * slab_size.z * 0.24
		_add_visual_box(
			architecture_root,
			"Crack_%02d_%02d" % [seed_value, index],
			Vector3(0.055, 0.018, 0.72 + float(index) * 0.28),
			position_value + Vector3(x_offset, slab_size.y * 0.52 + 0.016, z_offset),
			dark,
			Vector3(0.0, float(seed_value + index) * 0.53, 0.0)
		)


func _add_surface_moss(position_value: Vector3, size: Vector3, rotation_y: float) -> void:
	_add_visual_box(
		architecture_root,
		"MossPatch",
		size,
		position_value,
		material_library.get_material("moss"),
		Vector3(0.0, rotation_y, 0.0)
	)


func _add_fern(position_value: Vector3, scale_value: float, seed_value: int) -> void:
	var root := _new_root(foliage_root, "Fern%02d" % seed_value)
	root.position = position_value
	root.rotation.y = float(seed_value) * 1.37
	var material: Material = material_library.get_material(
		"foliage_sunlit" if seed_value % 4 == 0 else "foliage"
	)
	_add_visual_cylinder(
		root,
		"Stem",
		0.045 * scale_value,
		0.75 * scale_value,
		Vector3(0.0, 0.34 * scale_value, 0.0),
		material_library.get_material("root"),
		Vector3.ZERO,
		7
	)
	for index: int in range(10):
		var angle: float = TAU * float(index) / 10.0
		var leaf := _add_visual_sphere(
			root,
			"Frond%02d" % index,
			Vector3(cos(angle) * 0.42, 0.45 + float(index % 2) * 0.08, sin(angle) * 0.42) * scale_value,
			0.38 * scale_value,
			material,
			Vector3(0.18, 0.055, 1.85)
		)
		leaf.rotation = Vector3(deg_to_rad(16.0 + float(index % 3) * 7.0), -angle, angle * 0.18)
	build_counts["foliage_clusters"] = int(build_counts["foliage_clusters"]) + 1


func _add_cycad(position_value: Vector3, scale_value: float, seed_value: int) -> void:
	var root := _new_root(foliage_root, "Cycad%02d" % seed_value)
	root.position = position_value
	root.rotation.y = float(seed_value) * 0.73
	var foliage: Material = material_library.get_material(
		"foliage_sunlit" if seed_value % 2 == 0 else "foliage"
	)
	_add_visual_cylinder(
		root,
		"CycadTrunk",
		0.16 * scale_value,
		0.72 * scale_value,
		Vector3(0.0, 0.34 * scale_value, 0.0),
		material_library.get_material("bark"),
		Vector3.ZERO,
		9
	)
	for index: int in range(14):
		var angle: float = TAU * float(index) / 14.0
		var leaf := _add_visual_sphere(
			root,
			"CycadLeaf%02d" % index,
			Vector3(cos(angle) * 0.45, 0.73, sin(angle) * 0.45) * scale_value,
			0.42 * scale_value,
			foliage,
			Vector3(0.16, 0.045, 2.2)
		)
		leaf.rotation = Vector3(deg_to_rad(20.0 + float(index % 4) * 5.0), -angle, sin(angle) * 0.16)
	build_counts["foliage_clusters"] = int(build_counts["foliage_clusters"]) + 1


func _add_leaf_cluster(position_value: Vector3, scale_value: float, seed_value: int) -> void:
	var root := _new_root(foliage_root, "GroundLeaf%02d" % seed_value)
	root.position = position_value
	var foliage: Material = material_library.get_material("foliage")
	for index: int in range(5):
		var angle: float = TAU * float(index) / 5.0 + float(seed_value) * 0.21
		var leaf := _add_visual_sphere(
			root,
			"Leaf%02d" % index,
			Vector3(cos(angle) * 0.14, 0.12 + float(index % 2) * 0.06, sin(angle) * 0.14),
			0.24 * scale_value,
			foliage,
			Vector3(0.36, 0.09, 1.45)
		)
		leaf.rotation = Vector3(deg_to_rad(32.0), -angle, 0.0)
	build_counts["foliage_clusters"] = int(build_counts["foliage_clusters"]) + 1


func _add_root_chain(points: Array[Vector3], start_radius: float, end_radius: float) -> void:
	if points.size() < 2:
		return
	var root_material: Material = material_library.get_material("root")
	for index: int in range(points.size() - 1):
		var progress: float = float(index) / float(maxi(points.size() - 2, 1))
		_add_visual_cylinder_between(
			canopy_root,
			"RootSegment",
			points[index],
			points[index + 1],
			lerpf(start_radius, end_radius, progress),
			root_material,
			10
		)
	build_counts["roots"] = int(build_counts["roots"]) + 1


func _add_fauna(
	node_name: String,
	species_id: String,
	position_value: Vector3,
	scale_value: float,
	patrol_radius_value: float,
	phase: float
) -> void:
	var creature: GreenGrottoFaunaVisual = FaunaVisualScript.new() as GreenGrottoFaunaVisual
	creature.name = node_name
	creature.species = species_id
	creature.creature_scale = scale_value
	creature.patrol_radius = patrol_radius_value
	creature.idle_phase = phase
	creature.position = position_value
	fauna_root.add_child(creature)
	build_counts["fauna"] = int(build_counts["fauna"]) + 1


func _add_omni_light(
	node_name: String,
	position_value: Vector3,
	color: Color,
	energy: float,
	range_value: float,
	fog_energy: float
) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = node_name
	light.position = position_value
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_value
	light.omni_attenuation = 1.25
	light.light_volumetric_fog_energy = fog_energy
	light.shadow_enabled = false
	lighting_root.add_child(light)
	return light


func _new_root(parent: Node3D, node_name: String) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	parent.add_child(root)
	return root


func _add_static_box(
	parent: Node3D,
	node_name: String,
	size: Vector3,
	position_value: Vector3,
	material: Material,
	rotation_value: Vector3 = Vector3.ZERO
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	body.rotation = rotation_value
	body.add_to_group("green_grotto_surface")
	body.set_meta("presentation_material", "stone")
	parent.add_child(body)

	var visual := MeshInstance3D.new()
	visual.name = "Visual"
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = material
	body.add_child(visual)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	build_counts["static_surfaces"] = int(build_counts["static_surfaces"]) + 1
	build_counts["visual_meshes"] = int(build_counts["visual_meshes"]) + 1
	return body


func _add_static_cylinder(
	parent: Node3D,
	node_name: String,
	radius: float,
	height: float,
	position_value: Vector3,
	material: Material,
	rotation_value: Vector3 = Vector3.ZERO
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	body.rotation = rotation_value
	body.add_to_group("green_grotto_surface")
	body.set_meta("presentation_material", "stone")
	parent.add_child(body)

	var visual := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.94
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 14
	visual.mesh = mesh
	visual.material_override = material
	body.add_child(visual)

	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	collision.shape = shape
	body.add_child(collision)
	build_counts["static_surfaces"] = int(build_counts["static_surfaces"]) + 1
	build_counts["visual_meshes"] = int(build_counts["visual_meshes"]) + 1
	return body


func _add_visual_box(
	parent: Node3D,
	node_name: String,
	size: Vector3,
	position_value: Vector3,
	material: Material,
	rotation_value: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.position = position_value
	visual.rotation = rotation_value
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = material
	parent.add_child(visual)
	build_counts["visual_meshes"] = int(build_counts["visual_meshes"]) + 1
	return visual


func _add_visual_cylinder(
	parent: Node3D,
	node_name: String,
	radius: float,
	height: float,
	position_value: Vector3,
	material: Material,
	rotation_value: Vector3 = Vector3.ZERO,
	segments: int = 10
) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.position = position_value
	visual.rotation = rotation_value
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.88
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = maxi(segments, 5)
	visual.mesh = mesh
	visual.material_override = material
	parent.add_child(visual)
	build_counts["visual_meshes"] = int(build_counts["visual_meshes"]) + 1
	return visual


func _add_visual_cylinder_between(
	parent: Node3D,
	node_name: String,
	start: Vector3,
	finish: Vector3,
	radius: float,
	material: Material,
	segments: int = 8
) -> MeshInstance3D:
	var delta: Vector3 = finish - start
	var length: float = delta.length()
	var visual := _add_visual_cylinder(
		parent,
		node_name,
		radius,
		maxf(length, 0.01),
		(start + finish) * 0.5,
		material,
		Vector3.ZERO,
		segments
	)
	if length > 0.001:
		visual.quaternion = Quaternion(Vector3.UP, delta / length)
	return visual


func _add_visual_sphere(
	parent: Node3D,
	node_name: String,
	position_value: Vector3,
	radius: float,
	material: Material,
	scale_value: Vector3 = Vector3.ONE
) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.position = position_value
	visual.scale = scale_value
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 6
	visual.mesh = mesh
	visual.material_override = material
	parent.add_child(visual)
	build_counts["visual_meshes"] = int(build_counts["visual_meshes"]) + 1
	return visual


func _add_visual_torus(
	parent: Node3D,
	node_name: String,
	inner_radius: float,
	outer_radius: float,
	position_value: Vector3,
	material: Material
) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.position = position_value
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 18
	mesh.ring_segments = 8
	visual.mesh = mesh
	visual.material_override = material
	parent.add_child(visual)
	build_counts["visual_meshes"] = int(build_counts["visual_meshes"]) + 1
	return visual


func get_debug_data() -> Dictionary:
	return {
		"green_grotto_art_target": true,
		"concept": "Chinese mountain grotto / prehistoric Earth dungeon / orange sunset through dense green canopy",
		"build_counts": build_counts.duplicate(true),
		"materials": material_library.get_debug_data() if material_library != null else {},
		"production_vfx_deferred": true,
		"production_audio_deferred": true,
		"procedural_texture_target": true,
		"landmark": "sunset shrine",
		"route": "fractured causeway",
	}
