extends Node

const MapScene: PackedScene = preload("res://scenes/levels/prototypes/prototype_regional_expedition_map_v1.tscn")
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
	assert(str(outbound_context.get("route_state", "")) == RegionalStoreScript.STATE_DISCOVERED)
	var outbound_plan_value: Variant = outbound_context.get("familiarity_plan", {})
	assert(outbound_plan_value is Dictionary)
	var outbound_plan: Dictionary = outbound_plan_value as Dictionary
	assert(str(outbound_plan.get("signature", "")) != "")
	var outbound_indices_value: Variant = outbound_plan.get("source_indices", [])
	assert(outbound_indices_value is Array)
	assert((outbound_indices_value as Array).size() == 5)

	map.queue_free()
	await get_tree().process_frame

	var expedition_record: Dictionary = ExpeditionStoreScript.load_or_create(
		RegionalStoreScript.ROUTE_MAIN,
		18890417,
		TEST_EXPEDITION_PATH
	)
	var discoveries: Dictionary = expedition_record.get("discoveries", {}) as Dictionary
	discoveries[RegionalStoreScript.NODE_CAIRN] = true
	expedition_record["discoveries"] = discoveries
	expedition_record["shortcut_unlocked"] = true
	expedition_record["completed_forward"] = true
	ExpeditionStoreScript.save_record(expedition_record, TEST_EXPEDITION_PATH)

	var network_record: Dictionary = RegionalStoreScript.load_or_create(TEST_NETWORK_PATH)
	network_record = RegionalStoreScript.sync_from_expedition_record(network_record, expedition_record)
	network_record = RegionalStoreScript.complete_route(
		network_record,
		RegionalStoreScript.ROUTE_MAIN,
		RegionalStoreScript.NODE_BLUE_RIDGE,
		str(outbound_plan.get("signature", ""))
	)
	RegionalStoreScript.save_record(network_record, TEST_NETWORK_PATH)

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
	assert(
		RegionalStoreScript.get_state_rank(
			RegionalStoreScript.get_route_state(
				returned_map.network_record,
				RegionalStoreScript.ROUTE_MAIN
			)
		) >= RegionalStoreScript.get_state_rank(RegionalStoreScript.STATE_CROSSED)
	)
	returned_map.select_node(RegionalStoreScript.NODE_CAIRN)
	assert(returned_map.selected_route_id == RegionalStoreScript.ROUTE_CAIRN_BLUE_RIDGE)
	var cairn_context: Dictionary = returned_map.build_launch_context()
	assert(str(cairn_context.get("origin_node_id", "")) == RegionalStoreScript.NODE_BLUE_RIDGE)
	assert(str(cairn_context.get("destination_node_id", "")) == RegionalStoreScript.NODE_CAIRN)
	assert(str(cairn_context.get("route_state", "")) == RegionalStoreScript.STATE_MAPPED)
	var cairn_plan_value: Variant = cairn_context.get("familiarity_plan", {})
	assert(cairn_plan_value is Dictionary)
	var cairn_indices_value: Variant = (cairn_plan_value as Dictionary).get("source_indices", [])
	assert(cairn_indices_value is Array)
	assert((cairn_indices_value as Array).size() == 3)

	returned_map.queue_free()
	await get_tree().process_frame
	RegionalStoreScript.delete_record(TEST_NETWORK_PATH)
	ExpeditionStoreScript.delete_record(TEST_EXPEDITION_PATH)
	get_tree().root.remove_meta("regional_expedition_launch")
	print("REGIONAL_EXPEDITION_MAP_SMOKE_TEST: PASS")
	get_tree().quit()
