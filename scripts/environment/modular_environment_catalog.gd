extends RefCounted
class_name ModularEnvironmentCatalog

const FLOOR_SCENE: PackedScene = preload("res://scenes/environment/modular/weathered_stone_floor_4m.tscn")
const WALL_SCENE: PackedScene = preload("res://scenes/environment/modular/weathered_stone_wall_4m.tscn")
const ARCH_SCENE: PackedScene = preload("res://scenes/environment/modular/weathered_stone_arch_4m.tscn")
const STAIRS_SCENE: PackedScene = preload("res://scenes/environment/modular/weathered_stone_stairs_4m.tscn")
const PILLAR_SCENE: PackedScene = preload("res://scenes/environment/modular/weathered_stone_pillar_3m.tscn")
const TIMBER_SCENE: PackedScene = preload("res://scenes/environment/modular/weathered_timber_frame_4m.tscn")
const GATE_SCENE: PackedScene = preload("res://scenes/environment/modular/weathered_iron_gate_3m.tscn")
const PEDESTAL_SCENE: PackedScene = preload("res://scenes/environment/modular/weathered_stone_pedestal.tscn")
const CRATE_SCENE: PackedScene = preload("res://scenes/environment/modular/weathered_crate.tscn")
const BARREL_SCENE: PackedScene = preload("res://scenes/environment/modular/weathered_barrel.tscn")
const SCONCE_SCENE: PackedScene = preload("res://scenes/environment/modular/weathered_wall_sconce.tscn")
const WATER_CHANNEL_SCENE: PackedScene = preload("res://scenes/environment/modular/weathered_water_channel_4m.tscn")
const VILLAGE_ROAD_SCENE: PackedScene = preload("res://scenes/environment/modular/weathered_village_road_4m.tscn")
const LOW_WALL_SCENE: PackedScene = preload("res://scenes/environment/modular/weathered_low_wall_4m.tscn")
const RUINED_CORNER_SCENE: PackedScene = preload("res://scenes/environment/modular/weathered_ruined_corner_4m.tscn")
const RUINED_FACADE_SCENE: PackedScene = preload("res://scenes/environment/modular/weathered_ruined_facade_6m.tscn")
const TIMBER_FENCE_SCENE: PackedScene = preload("res://scenes/environment/modular/weathered_timber_fence_4m.tscn")
const RUBBLE_CLUSTER_SCENE: PackedScene = preload("res://scenes/environment/modular/weathered_rubble_cluster.tscn")
const OLIVE_TREE_CLUSTER_SCENE: PackedScene = preload("res://scenes/environment/modular/weathered_olive_tree_cluster.tscn")

const PIECES: Dictionary = {
	"weathered_barrel": BARREL_SCENE,
	"weathered_crate": CRATE_SCENE,
	"weathered_iron_gate_3m": GATE_SCENE,
	"weathered_low_wall_4m": LOW_WALL_SCENE,
	"weathered_olive_tree_cluster": OLIVE_TREE_CLUSTER_SCENE,
	"weathered_rubble_cluster": RUBBLE_CLUSTER_SCENE,
	"weathered_ruined_corner_4m": RUINED_CORNER_SCENE,
	"weathered_ruined_facade_6m": RUINED_FACADE_SCENE,
	"weathered_stone_arch_4m": ARCH_SCENE,
	"weathered_stone_floor_4m": FLOOR_SCENE,
	"weathered_stone_pedestal": PEDESTAL_SCENE,
	"weathered_stone_pillar_3m": PILLAR_SCENE,
	"weathered_stone_stairs_4m": STAIRS_SCENE,
	"weathered_stone_wall_4m": WALL_SCENE,
	"weathered_timber_fence_4m": TIMBER_FENCE_SCENE,
	"weathered_timber_frame_4m": TIMBER_SCENE,
	"weathered_village_road_4m": VILLAGE_ROAD_SCENE,
	"weathered_wall_sconce": SCONCE_SCENE,
	"weathered_water_channel_4m": WATER_CHANNEL_SCENE,
}

const DEFINITIONS: Dictionary = {
	"weathered_barrel": {"category": "prop", "collision": true},
	"weathered_crate": {"category": "prop", "collision": true},
	"weathered_iron_gate_3m": {"category": "architecture", "collision": true},
	"weathered_low_wall_4m": {"category": "architecture", "collision": true},
	"weathered_olive_tree_cluster": {"category": "vegetation", "collision": false},
	"weathered_rubble_cluster": {"category": "prop", "collision": false},
	"weathered_ruined_corner_4m": {"category": "architecture", "collision": true},
	"weathered_ruined_facade_6m": {"category": "architecture", "collision": true},
	"weathered_stone_arch_4m": {"category": "architecture", "collision": true},
	"weathered_stone_floor_4m": {"category": "architecture", "collision": true},
	"weathered_stone_pedestal": {"category": "prop", "collision": true},
	"weathered_stone_pillar_3m": {"category": "architecture", "collision": true},
	"weathered_stone_stairs_4m": {"category": "architecture", "collision": true},
	"weathered_stone_wall_4m": {"category": "architecture", "collision": true},
	"weathered_timber_fence_4m": {"category": "architecture", "collision": true},
	"weathered_timber_frame_4m": {"category": "architecture", "collision": true},
	"weathered_village_road_4m": {"category": "terrain", "collision": true},
	"weathered_wall_sconce": {"category": "lighting", "collision": false},
	"weathered_water_channel_4m": {"category": "water", "collision": true},
}


static func get_piece_ids() -> Array[String]:
	var ids: Array[String] = []
	for raw_id: Variant in PIECES.keys():
		ids.append(str(raw_id))
	ids.sort()
	return ids


static func has_piece(piece_id: String) -> bool:
	return PIECES.has(piece_id)


static func instantiate_piece(piece_id: String) -> Node3D:
	var scene: PackedScene = PIECES.get(piece_id) as PackedScene
	if scene == null:
		return null
	return scene.instantiate() as Node3D


static func get_definition(piece_id: String) -> Dictionary:
	return (DEFINITIONS.get(piece_id, {}) as Dictionary).duplicate(true)


static func validate_catalog() -> Array[String]:
	var errors: Array[String] = []
	if PIECES.size() != DEFINITIONS.size():
		errors.append("Catalog scene and definition counts differ.")
	for piece_id: String in get_piece_ids():
		var scene: PackedScene = PIECES.get(piece_id) as PackedScene
		if scene == null:
			errors.append(piece_id + " has no PackedScene.")
			continue
		if not DEFINITIONS.has(piece_id):
			errors.append(piece_id + " has no catalog definition.")
		var instance: Node3D = scene.instantiate() as Node3D
		if instance == null:
			errors.append(piece_id + " failed to instantiate.")
			continue
		if str(instance.get("piece_id")) != piece_id:
			errors.append(piece_id + " scene exports mismatched piece_id " + str(instance.get("piece_id")) + ".")
		instance.free()
	return errors
