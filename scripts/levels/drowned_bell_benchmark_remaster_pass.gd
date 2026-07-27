extends Node
class_name DrownedBellBenchmarkRemasterPass

const Catalog = preload("res://scripts/environment/modular_environment_catalog.gd")

const FLOOR_ID := "weathered_stone_floor_4m"
const WALL_ID := "weathered_stone_wall_4m"
const ARCH_ID := "weathered_stone_arch_4m"
const STAIRS_ID := "weathered_stone_stairs_4m"
const PILLAR_ID := "weathered_stone_pillar_3m"
const TIMBER_ID := "weathered_timber_frame_4m"
const PEDESTAL_ID := "weathered_stone_pedestal"
const CRATE_ID := "weathered_crate"
const BARREL_ID := "weathered_barrel"
const SCONCE_ID := "weathered_wall_sconce"
const WATER_CHANNEL_ID := "weathered_water_channel_4m"

var mission: Node3D
var world: Node3D
var authored_root: Node3D
var remaster_root: Node3D
var installed: bool = false
var install_attempts: int = 0
var placed_piece_ids: Array[String] = []
var placed_categories: Dictionary = {}
var replaced_paths: Array[String] = []
var hidden_legacy_meshes: int = 0
var support_shell_piece_count: int = 0
var physical_prop_count: int = 0


func _ready() -> void:
	add_to_group("drowned_chapel_benchmark_remaster")
	call_deferred("_install")


func _install() -> void:
	if installed:
		return
	mission = get_parent() as Node3D
	if mission == null:
		return
	world = mission.get_node_or_null("World") as Node3D
	if world == null:
		return

	var environment_pass: Node = mission.get_node_or_null("EnvironmentPass")
	var opening_patch: Node = mission.get_node_or_null("CryptOpeningPatch")
	var environment_ready: bool = environment_pass == null or bool(environment_pass.get("installed"))
	var opening_ready: bool = opening_patch == null or bool(opening_patch.get("installed"))
	if not environment_ready or not opening_ready:
		install_attempts += 1
		if install_attempts < 90:
			call_deferred("_install")
		return

	authored_root = world.get_node_or_null("AuthoredEnvironmentV2") as Node3D
	if authored_root == null:
		return

	var existing: Node3D = world.get_node_or_null("ModularChapelBenchmarkV1") as Node3D
	if existing != null:
		remaster_root = existing
		installed = true
		return

	remaster_root = Node3D.new()
	remaster_root.name = "ModularChapelBenchmarkV1"
	remaster_root.add_to_group("modular_environment_set")
	remaster_root.add_to_group("story_integrated_modular_environment")
	remaster_root.set_meta("set_id", "drowned_chapel_benchmark_v1")
	remaster_root.set_meta("preserves_support_shell", true)
	world.add_child(remaster_root)

	_mute_replaced_builder_geometry()
	_build_causeway_modules()
	_build_chapel_floor_modules()
	_build_wall_and_threshold_modules()
	_build_nave_structure_modules()
	_build_pool_and_altar_modules()
	_build_furnishing_modules()

	remaster_root.set_meta("module_count", placed_piece_ids.size())
	remaster_root.set_meta("support_shell_piece_count", support_shell_piece_count)
	remaster_root.set_meta("physical_prop_count", physical_prop_count)
	remaster_root.set_meta("hidden_legacy_meshes", hidden_legacy_meshes)
	installed = true


func _mute_replaced_builder_geometry() -> void:
	var exact_paths: Array[String] = [
		"AuthoredEnvironmentV2/ShoreAndCauseway/CausewayCore",
		"AuthoredEnvironmentV2/ChapelShell/NaveFloor",
		"AuthoredEnvironmentV2/ChapelShell/EastVestibuleFloor",
		"AuthoredEnvironmentV2/ChapelShell/EastRearFloor",
		"AuthoredEnvironmentV2/ChapelShell/WestWall",
		"AuthoredEnvironmentV2/ChapelShell/EastWall",
		"AuthoredEnvironmentV2/ChapelShell/FrontWallWest",
		"AuthoredEnvironmentV2/ChapelShell/FrontWallEast",
		"AuthoredEnvironmentV2/ChapelShell/EntranceArch",
		"AuthoredEnvironmentV2/Architecture/AltarAndCrypt/AltarDais",
		"AuthoredEnvironmentV2/Architecture/AltarAndCrypt/AltarSteps",
		"AuthoredEnvironmentV2/Architecture/AltarAndCrypt/CryptFrame",
		"CryptDoorwayWallPatch",
	]
	for path: String in exact_paths:
		_hide_existing_path(path)

	_hide_children_with_prefix("AuthoredEnvironmentV2/ShoreAndCauseway", "CausewaySlab")
	_hide_children_with_prefix("AuthoredEnvironmentV2/ChapelShell", "WestMortar")
	_hide_children_with_prefix("AuthoredEnvironmentV2/ChapelShell", "EastMortar")
	_hide_children_with_prefix("AuthoredEnvironmentV2/Architecture", "WestPillar")
	_hide_children_with_prefix("AuthoredEnvironmentV2/Architecture", "EastPillar")
	_hide_children_with_prefix("AuthoredEnvironmentV2/Architecture", "NaveCrossbeam")
	_hide_children_with_prefix("AuthoredEnvironmentV2/Architecture", "RafterLeft")
	_hide_children_with_prefix("AuthoredEnvironmentV2/Architecture", "RafterRight")


func _build_causeway_modules() -> void:
	var root := _make_root("CausewayModules")
	var z_positions: Array[float] = [-1.5, 2.5, 6.5, 10.5, 14.5, 18.5, 22.1]
	for index: int in range(z_positions.size()):
		var length_scale: float = 0.98 if index < z_positions.size() - 1 else 0.72
		_place_piece(
			root,
			FLOOR_ID,
			"CausewayFloor%02d" % index,
			Vector3(0.0, 0.12, z_positions[index]),
			Vector3.ZERO,
			Vector3(1.18, 1.0, length_scale),
			false,
			index + 2
		)


func _build_chapel_floor_modules() -> void:
	var root := _make_root("ChapelFloorModules")
	var z_positions: Array[float] = [24.8, 28.8, 32.8]
	var x_positions: Array[float] = [-4.7, -0.7]
	var seed: int = 20
	for z_value: float in z_positions:
		for x_value: float in x_positions:
			_place_piece(
				root,
				FLOOR_ID,
				"NaveFloor_%s_%s" % [_coord_name(x_value), _coord_name(z_value)],
				Vector3(x_value, -0.14, z_value),
				Vector3.ZERO,
				Vector3.ONE,
				false,
				seed
			)
			seed += 1
	_place_piece(root, FLOOR_ID, "EastVestibuleFloor", Vector3(4.35, -0.14, 24.35), Vector3.ZERO, Vector3(1.16, 1.0, 0.78), false, 32)
	_place_piece(root, FLOOR_ID, "EastRearFloor", Vector3(4.35, -0.14, 34.35), Vector3.ZERO, Vector3(1.16, 1.0, 0.78), false, 33)
	_place_piece(root, FLOOR_ID, "EntranceThreshold", Vector3(0.0, -0.14, 22.75), Vector3.ZERO, Vector3(1.1, 1.0, 0.54), false, 34)


func _build_wall_and_threshold_modules() -> void:
	var root := _make_root("WallAndThresholdModules")
	var side_z: Array[float] = [24.3, 28.3, 32.3, 35.4]
	var seed: int = 50
	for side: float in [-1.0, 1.0]:
		for level: int in range(2):
			for z_value: float in side_z:
				var side_name: String = "West" if side < 0.0 else "East"
				_place_piece(
					root,
					WALL_ID,
					"SideWall_%s_L%d_%s" % [side_name, level, _coord_name(z_value)],
					Vector3(side * 7.05, float(level) * 3.2, z_value),
					Vector3(0.0, PI * 0.5, 0.0),
					Vector3(1.0, 1.03, 1.0),
					false,
					seed
				)
				seed += 1

	for level: int in range(2):
		for side: float in [-1.0, 1.0]:
			var side_name: String = "West" if side < 0.0 else "East"
			_place_piece(
				root,
				WALL_ID,
				"FrontWall_%s_L%d" % [side_name, level],
				Vector3(side * 4.95, float(level) * 3.2, 22.55),
				Vector3.ZERO,
				Vector3(1.25, 1.03, 1.0),
				false,
				seed
			)
			seed += 1

	_place_piece(root, ARCH_ID, "ModularEntranceArch", Vector3(0.0, 0.0, 22.55), Vector3.ZERO, Vector3(1.45, 1.36, 1.12), false, 70)

	for level: int in range(2):
		_place_piece(root, WALL_ID, "BackWallWest_L%d" % level, Vector3(-5.48, float(level) * 3.2, 36.55), Vector3.ZERO, Vector3(0.97, 1.03, 1.0), false, 72 + level)
		_place_piece(root, WALL_ID, "BackWallEastInner_L%d" % level, Vector3(1.95, float(level) * 3.2, 36.55), Vector3.ZERO, Vector3(1.0, 1.03, 1.0), false, 74 + level)
		_place_piece(root, WALL_ID, "BackWallEastOuter_L%d" % level, Vector3(5.65, float(level) * 3.2, 36.55), Vector3.ZERO, Vector3(0.9, 1.03, 1.0), false, 76 + level)
	_place_piece(root, WALL_ID, "CryptUpperWall", Vector3(-1.8, 3.5, 36.55), Vector3.ZERO, Vector3(0.9, 0.9, 1.0), false, 78)
	_place_piece(root, ARCH_ID, "ModularCryptArch", Vector3(-1.8, 0.0, 36.14), Vector3.ZERO, Vector3(1.35, 1.05, 1.02), false, 79)


func _build_nave_structure_modules() -> void:
	var root := _make_root("NaveStructureModules")
	var pillar_positions: Array[Vector3] = [
		Vector3(-3.95, 0.0, 25.6),
		Vector3(-3.95, 0.0, 30.0),
		Vector3(-3.95, 0.0, 34.2),
		Vector3(1.15, 0.0, 25.6),
		Vector3(1.15, 0.0, 34.15),
	]
	for index: int in range(pillar_positions.size()):
		_place_piece(
			root,
			PILLAR_ID,
			"NavePillar%02d" % index,
			pillar_positions[index],
			Vector3.ZERO,
			Vector3(0.84, 1.66, 0.84),
			false,
			90 + index
		)

	var frame_z_positions: Array[float] = [25.6, 30.0, 34.15]
	for index: int in range(frame_z_positions.size()):
		_place_piece(
			root,
			TIMBER_ID,
			"NaveTimberFrame%02d" % index,
			Vector3(-1.4, 0.0, frame_z_positions[index]),
			Vector3.ZERO,
			Vector3(1.5, 1.7, 1.0),
			false,
			100 + index
		)

	var sconce_z_positions: Array[float] = [25.5, 30.0, 34.35]
	for side: float in [-1.0, 1.0]:
		for index: int in range(sconce_z_positions.size()):
			var side_name: String = "West" if side < 0.0 else "East"
			var sconce_yaw: float = -PI * 0.5 if side < 0.0 else PI * 0.5
			_place_piece(
				root,
				SCONCE_ID,
				"NaveSconce_%s_%02d" % [side_name, index],
				Vector3(side * 6.7, 1.35, sconce_z_positions[index]),
				Vector3(0.0, sconce_yaw, 0.0),
				Vector3(0.86, 0.86, 0.86),
				false,
				110 + index
			)


func _build_pool_and_altar_modules() -> void:
	var root := _make_root("PoolAndAltarModules")
	_place_piece(
		root,
		WATER_CHANNEL_ID,
		"PoolOverflowChannel",
		Vector3(4.35, 0.0, 25.85),
		Vector3(0.0, PI * 0.5, 0.0),
		Vector3(0.72, 1.0, 1.08),
		false,
		120
	)
	_place_piece(
		root,
		PEDESTAL_ID,
		"SubmergedMechanismPedestal",
		Vector3(4.6, -3.0, 29.5),
		Vector3.ZERO,
		Vector3(0.65, 0.65, 0.65),
		false,
		121
	)
	_place_piece(
		root,
		STAIRS_ID,
		"ModularAltarSteps",
		Vector3(-1.8, 0.0, 31.85),
		Vector3.ZERO,
		Vector3(0.95, 0.39, 0.62),
		false,
		122
	)
	_place_piece(
		root,
		PEDESTAL_ID,
		"TuningPlatePedestal",
		Vector3(1.2, -0.55, 33.1),
		Vector3.ZERO,
		Vector3(0.5, 0.5, 0.5),
		false,
		123
	)


func _build_furnishing_modules() -> void:
	var root := _make_root("FurnishingModules")
	_place_piece(root, CRATE_ID, "VestibuleSupplyCrate", Vector3(5.6, 0.0, 23.65), Vector3(0.0, -0.18, 0.0), Vector3(0.82, 0.82, 0.82), true, 130)
	_place_piece(root, BARREL_ID, "MemorialStorageBarrel", Vector3(-5.7, 0.0, 34.15), Vector3(0.0, 0.26, 0.0), Vector3(0.82, 0.82, 0.82), true, 131)
	_place_piece(root, CRATE_ID, "CollapsedAisleCrate", Vector3(-5.4, 0.0, 24.0), Vector3(0.0, 0.34, 0.0), Vector3(0.68, 0.68, 0.68), true, 132)


func _make_root(node_name: String) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	root.set_meta("modular_environment_assembly", true)
	remaster_root.add_child(root)
	return root


func _place_piece(
	parent: Node3D,
	piece_id: String,
	node_name: String,
	position_value: Vector3,
	rotation_value: Vector3 = Vector3.ZERO,
	scale_value: Vector3 = Vector3.ONE,
	keep_collision: bool = false,
	variant_seed: int = -1
) -> Node3D:
	var piece: Node3D = Catalog.instantiate_piece(piece_id)
	if piece == null:
		push_warning("Unknown Drowned Chapel modular piece: " + piece_id)
		return null
	piece.name = node_name
	piece.position = position_value
	piece.rotation = rotation_value
	piece.scale = scale_value
	if variant_seed >= 0 and _has_property(piece, "variant_seed"):
		piece.set("variant_seed", variant_seed)
	parent.add_child(piece)
	piece.add_to_group("drowned_chapel_modular_piece")
	piece.set_meta("benchmark_owner", "drowned_chapel_benchmark_v1")
	piece.set_meta("uses_support_shell", not keep_collision)
	if keep_collision:
		physical_prop_count += 1
	else:
		support_shell_piece_count += 1
		_set_piece_collision_enabled(piece, false)
	placed_piece_ids.append(piece_id)
	var definition: Dictionary = Catalog.get_definition(piece_id)
	placed_categories[str(definition.get("category", "unknown"))] = true
	return piece


func _set_piece_collision_enabled(node: Node, enabled: bool) -> void:
	if node is CollisionObject3D:
		var collision_object := node as CollisionObject3D
		collision_object.collision_layer = 1 if enabled else 0
		collision_object.collision_mask = 1 if enabled else 0
	if node is CollisionShape3D:
		(node as CollisionShape3D).set_deferred("disabled", not enabled)
	for child: Node in node.get_children():
		_set_piece_collision_enabled(child, enabled)


func _hide_existing_path(path: String) -> void:
	var node: Node = world.get_node_or_null(path)
	if node == null:
		return
	hidden_legacy_meshes += _hide_meshes_under(node)
	replaced_paths.append(path)


func _hide_children_with_prefix(parent_path: String, prefix: String) -> void:
	var parent: Node = world.get_node_or_null(parent_path)
	if parent == null:
		return
	for child: Node in parent.get_children():
		if child.name.begins_with(prefix):
			hidden_legacy_meshes += _hide_meshes_under(child)
			replaced_paths.append(parent_path + "/" + str(child.name))


func _hide_meshes_under(node: Node) -> int:
	var count: int = 0
	if node is MeshInstance3D:
		(node as MeshInstance3D).visible = false
		count += 1
	for child: Node in node.get_children():
		count += _hide_meshes_under(child)
	return count


func _has_property(node: Object, property_name: String) -> bool:
	for property_variant: Variant in node.get_property_list():
		if not property_variant is Dictionary:
			continue
		var property_data: Dictionary = property_variant as Dictionary
		if str(property_data.get("name", "")) == property_name:
			return true
	return false


func _coord_name(value: float) -> String:
	return str(snappedf(value, 0.01)).replace("-", "m").replace(".", "_")


func get_debug_data() -> Dictionary:
	return {
		"installed": installed,
		"set_id": "drowned_chapel_benchmark_v1",
		"module_count": placed_piece_ids.size(),
		"piece_ids": placed_piece_ids.duplicate(),
		"categories": placed_categories.keys(),
		"replaced_paths": replaced_paths.duplicate(),
		"hidden_legacy_meshes": hidden_legacy_meshes,
		"support_shell_piece_count": support_shell_piece_count,
		"physical_prop_count": physical_prop_count,
		"preserved_landmarks": ["MemorialArcade", "BellFrame", "RoseWindow"],
	}
