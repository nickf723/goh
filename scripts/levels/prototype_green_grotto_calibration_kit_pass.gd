extends "res://scripts/levels/prototype_green_grotto_art_direction_study.gd"
class_name PrototypeGreenGrottoCalibrationKitPass

const GreenKitDefinition: EnvironmentKitDefinition = preload(
	"res://data/environment_kits/green_earth_calibration_kit.tres"
)
const CliffA: PackedScene = preload(
	"res://scenes/environment/kits/green_earth/green_cliff_a.tscn"
)
const CliffB: PackedScene = preload(
	"res://scenes/environment/kits/green_earth/green_cliff_b.tscn"
)
const PathSlabA: PackedScene = preload(
	"res://scenes/environment/kits/green_earth/green_path_slab_a.tscn"
)
const PathSlabB: PackedScene = preload(
	"res://scenes/environment/kits/green_earth/green_path_slab_b.tscn"
)
const ShrinePlatform: PackedScene = preload(
	"res://scenes/environment/kits/green_earth/green_shrine_platform.tscn"
)
const ShrineStair: PackedScene = preload(
	"res://scenes/environment/kits/green_earth/green_shrine_stair.tscn"
)
const ShrineColumn: PackedScene = preload(
	"res://scenes/environment/kits/green_earth/green_shrine_column.tscn"
)
const ShrineBeam: PackedScene = preload(
	"res://scenes/environment/kits/green_earth/green_shrine_beam.tscn"
)
const ShrineRoof: PackedScene = preload(
	"res://scenes/environment/kits/green_earth/green_shrine_roof.tscn"
)
const ShrineBracket: PackedScene = preload(
	"res://scenes/environment/kits/green_earth/green_shrine_bracket.tscn"
)
const ShrineWall: PackedScene = preload(
	"res://scenes/environment/kits/green_earth/green_shrine_wall.tscn"
)
const Lantern: PackedScene = preload(
	"res://scenes/environment/kits/green_earth/green_lantern.tscn"
)
const FernCluster: PackedScene = preload(
	"res://scenes/environment/kits/green_earth/green_fern_cluster.tscn"
)

var calibration_root: Node3D = null
var kit_instance_count: int = 0
var kit_piece_counts: Dictionary = {}


func _ready() -> void:
	super._ready()
	if direction_root != null:
		direction_root.visible = false
	_build_calibration_root()
	_build_calibration_canyon()
	_build_calibration_route()
	_build_calibration_shrine()
	_build_calibration_ecology()
	set_meta("environment_kit", GreenKitDefinition.kit_id)
	set_meta("environment_kit_module_count", GreenKitDefinition.get_module_count())
	set_meta("calibration_instances", kit_instance_count)
	set_meta("calibration_piece_counts", kit_piece_counts.duplicate(true))
	set_meta("art_authoring_contract", "external authored meshes replace module visuals; Godot owns placement and systems")


func _build_calibration_root() -> void:
	calibration_root = _new_root(environment_root, "GreenEarthCalibrationKitV01")
	calibration_root.set_meta("environment_kit", GreenKitDefinition.kit_id)
	calibration_root.set_meta("placeholder_only", GreenKitDefinition.placeholder_only)
	calibration_root.set_meta("collision_source", "hidden_green_grotto_blockout")


func _build_calibration_canyon() -> void:
	_place_module(
		CliffA,
		"KitCliffLeftNear",
		Vector3(-9.0, -2.0, 10.0),
		Vector3(0.04, -0.08, 0.08)
	)
	_place_module(
		CliffA,
		"KitCliffRightNear",
		Vector3(9.2, -2.1, 9.3),
		Vector3(-0.03, 0.07, -0.08)
	)
	_place_module(
		CliffB,
		"KitCliffLeftDeep",
		Vector3(-10.0, -3.0, -6.2),
		Vector3(0.03, 0.09, 0.06)
	)
	_place_module(
		CliffB,
		"KitCliffRightDeep",
		Vector3(10.2, -3.0, -7.0),
		Vector3(-0.02, -0.08, -0.06)
	)


func _build_calibration_route() -> void:
	var route: Array[Dictionary] = [
		{"scene": PathSlabA, "pos": Vector3(0.0, 0.16, 11.5), "rot": Vector3(0.0, 0.01, 0.0)},
		{"scene": PathSlabA, "pos": Vector3(0.0, 0.24, 8.2), "rot": Vector3(0.0, 0.025, 0.0)},
		{"scene": PathSlabB, "pos": Vector3(-0.18, 0.36, 5.2), "rot": Vector3(0.008, -0.025, -0.012)},
		{"scene": PathSlabB, "pos": Vector3(0.16, 0.57, 2.35), "rot": Vector3(-0.015, 0.04, 0.018)},
		{"scene": PathSlabB, "pos": Vector3(-0.24, 0.82, -0.30), "rot": Vector3(0.02, -0.055, -0.03)},
		{"scene": PathSlabB, "pos": Vector3(0.22, 1.01, -2.75), "rot": Vector3(-0.01, 0.075, 0.025)},
		{"scene": PathSlabB, "pos": Vector3(0.02, 1.16, -5.0), "rot": Vector3(0.018, -0.035, -0.018)},
		{"scene": PathSlabB, "pos": Vector3(-0.10, 1.30, -7.05), "rot": Vector3(-0.012, 0.025, 0.012)},
	]
	for index: int in range(route.size()):
		var spec: Dictionary = route[index]
		_place_module(
			spec["scene"] as PackedScene,
			"KitRoute%02d" % index,
			spec["pos"] as Vector3,
			spec["rot"] as Vector3
		)


func _build_calibration_shrine() -> void:
	_place_module(
		ShrinePlatform,
		"KitShrinePlatform",
		Vector3(0.0, 1.05, -14.7)
	)
	_place_module(
		ShrineStair,
		"KitShrineStair",
		Vector3(0.0, 0.95, -10.35)
	)

	for x_value: float in [-3.4, 3.4]:
		for z_value: float in [-12.2, -17.0]:
			_place_module(
				ShrineColumn,
				"KitShrineColumn",
				Vector3(x_value, 2.28, z_value)
			)

	_place_module(
		ShrineWall,
		"KitShrineBackWall",
		Vector3(0.0, 2.28, -17.18)
	)
	for z_value: float in [-12.2, -17.0]:
		_place_module(
			ShrineBeam,
			"KitShrineBeam",
			Vector3(0.0, 6.18, z_value)
		)

	for side: float in [-1.0, 1.0]:
		_place_module(
			ShrineRoof,
			"KitShrineRoof",
			Vector3(0.0, 7.08, -14.6 + side * 1.55),
			Vector3(side * -0.20, 0.0, 0.0)
		)

	for side: float in [-1.0, 1.0]:
		for x_index: int in range(3):
			_place_module(
				ShrineBracket,
				"KitShrineBracket",
				Vector3(-2.2 + float(x_index) * 2.2, 6.62, -14.6 + side * 2.65)
			)

	for side: float in [-1.0, 1.0]:
		_place_module(
			Lantern,
			"KitShrineLantern",
			Vector3(side * 2.35, 4.7, -11.85)
		)

	var focus_light := OmniLight3D.new()
	focus_light.name = "CalibrationShrineFocusLight"
	focus_light.position = Vector3(0.0, 5.2, -14.2)
	focus_light.light_color = Color(1.0, 0.52, 0.20, 1.0)
	focus_light.light_energy = 1.55
	focus_light.omni_range = 12.0
	focus_light.shadow_enabled = false
	calibration_root.add_child(focus_light)


func _build_calibration_ecology() -> void:
	for position_value: Vector3 in [
		Vector3(-5.0, 0.0, 10.0),
		Vector3(5.1, 0.0, 7.0),
		Vector3(-5.0, 2.25, -12.3),
		Vector3(5.0, 2.25, -16.2),
	]:
		_place_module(
			FernCluster,
			"KitFernCluster",
			position_value
		)


func _place_module(
	scene: PackedScene,
	node_name: String,
	position_value: Vector3,
	rotation_value: Vector3 = Vector3.ZERO
) -> EnvironmentKitModule:
	var module: EnvironmentKitModule = scene.instantiate() as EnvironmentKitModule
	if module == null:
		return null
	module.name = node_name + "_%03d" % kit_instance_count
	module.position = position_value
	module.rotation = rotation_value
	calibration_root.add_child(module)
	kit_instance_count += 1
	kit_piece_counts[module.module_id] = int(
		kit_piece_counts.get(module.module_id, 0)
	) + 1
	return module


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["green_grotto_calibration_kit_pass"] = true
	data["environment_kit"] = GreenKitDefinition.get_debug_data()
	data["calibration_instances"] = kit_instance_count
	data["calibration_piece_counts"] = kit_piece_counts.duplicate(true)
	data["previous_direction_study_hidden"] = direction_root != null and not direction_root.visible
	data["authored_visuals_ready"] = false
	data["replacement_strategy"] = "replace authored_visual_scene per module without changing level placement"
	return data
