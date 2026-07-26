extends Node

const MapScene: PackedScene = preload("res://scenes/levels/prototypes/prototype_regional_expedition_map_v1.tscn")
const WildsScene: PackedScene = preload("res://scenes/levels/prototypes/prototype_wilds_expedition_v1.tscn")
const RegionalStoreScript = preload("res://scripts/expedition/regional_expedition_store.gd")
const ExpeditionStoreScript = preload("res://scripts/expedition/expedition_record_store.gd")

const TEST_NETWORK_PATH: String = "user://regional_expedition_map_smoke_test.json"
const TEST_EXPEDITION_PATH: String = "user://regional_expedition_route_smoke_test.json"


func _ready() -> void:
	RegionalStoreScript.delete_record(TEST_NETWORK_PATH)
	ExpeditionStoreScript.delete_record(TEST_EXPEDITION_PATH)
	get_tree().root.remove_meta("regional_expedition_launch")

	var map: RegionalExpeditionMap = MapScene.instantiate() as RegionalExpeditionMap
	assert(map != null)
	map.network_record_path = TEST_NETWORK_PATH
	map.expedition_record_path = TEST_EXPEDITION_PATH
	map.allow_scene_launch = false
	add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame

	assert(str(map.network_record.get("current_node_id", "")) == RegionalStoreScript.NODE_CYPRESS)
	assert(not RegionalStoreScript.is_node_discovered(map.network_record, RegionalStoreScript.NODE_CAIRN))
	map.select_node(RegionalStoreScript.NODE_BLUE_RIDGE)
	assert(map.selected_route_id == RegionalStoreScript.ROUTE_MAIN)
	var outbound_context: Dictionary = map.build_launch_context()
	assert(str(outbound_context.get("origin_node_id", "")) == RegionalStoreScript.NODE_CYPRESS)
	assert(str(outbound_context.get("destination_node_id", "")) == RegionalStoreScript.NODE_BLUE_RIDGE)

	map.queue_free()
	await get_tree().process_frame
	get_tree().root.set_meta("regional_expedition_launch", outbound_context)

	var route: Node = WildsScene.instantiate()
	assert(route != null)
	add_child(route)
	await get_tree().process_frame
	await get_tree().process_frame
	assert(bool(route.get("launched_from_regional_map")))

	var cairn_result: Dictionary = route.call(
		"activate_route_marker",
		"landmark",
		RegionalStoreScript.NODE_CAIRN
	) as Dictionary
	assert(not cairn_result.is_empty())
	var discovered_record: Dictionary = RegionalStoreScript.load_or_create(TEST_NETWORK_PATH)
	assert(RegionalStoreScript.is_node_discovered(discovered_record, RegionalStoreScript.NODE_CAIRN))

	var arrival_result: Dictionary = route.call(
		"activate_route_marker",
		"destination",
		RegionalStoreScript.NODE_BLUE_RIDGE
	) as Dictionary
	assert(not arrival_result.is_empty())
	var arrived_record: Dictionary = RegionalStoreScript.load_or_create(TEST_NETWORK_PATH)
	assert(str(arrived_record.get("current_node_id", "")) == RegionalStoreScript.NODE_BLUE_RIDGE)
	assert(RegionalStoreScript.get_route_crossings(arrived_record, RegionalStoreScript.ROUTE_MAIN) >= 1)
	assert(
		RegionalStoreScript.get_state_rank(
			RegionalStoreScript.get_route_state(arrived_record, RegionalStoreScript.ROUTE_MAIN)
		) >= RegionalStoreScript.get_state_rank(RegionalStoreScript.STATE_CROSSED)
	)

	route.queue_free()
	await get_tree().process_frame
	get_tree().root.remove_meta("regional_expedition_launch")

	var returned_map: RegionalExpeditionMap = MapScene.instantiate() as RegionalExpeditionMap
	assert(returned_map != null)
	returned_map.network_record_path = TEST_NETWORK_PATH
	returned_map.expedition_record_path = TEST_EXPEDITION_PATH
	returned_map.allow_scene_launch = false
	add_child(returned_map)
	await get_tree().process_frame
	await get_tree().process_frame

	assert(str(returned_map.network_record.get("current_node_id", "")) == RegionalStoreScript.NODE_BLUE_RIDGE)
	assert(RegionalStoreScript.is_node_discovered(returned_map.network_record, RegionalStoreScript.NODE_CAIRN))
	returned_map.select_node(RegionalStoreScript.NODE_CAIRN)
	assert(returned_map.selected_route_id == RegionalStoreScript.ROUTE_CAIRN_BLUE_RIDGE)
	var cairn_context: Dictionary = returned_map.build_launch_context()
	assert(str(cairn_context.get("origin_node_id", "")) == RegionalStoreScript.NODE_BLUE_RIDGE)
	assert(str(cairn_context.get("destination_node_id", "")) == RegionalStoreScript.NODE_CAIRN)

	returned_map.queue_free()
	await get_tree().process_frame
	RegionalStoreScript.delete_record(TEST_NETWORK_PATH)
	ExpeditionStoreScript.delete_record(TEST_EXPEDITION_PATH)
	print("REGIONAL_EXPEDITION_MAP_SMOKE_TEST: PASS")
	get_tree().quit()
