extends Node

const MapScene: PackedScene = preload("res://scenes/levels/prototypes/prototype_regional_expedition_map_v1.tscn")
const RegionalStoreScript = preload("res://scripts/expedition/regional_expedition_store.gd")
const ExpeditionStoreScript = preload("res://scripts/expedition/expedition_record_store.gd")

const NETWORK_PATH := "user://validation_route_familiarity_map_network.json"
const EXPEDITION_PATH := "user://validation_route_familiarity_map_expedition.json"


func _ready() -> void:
	RegionalStoreScript.delete_record(NETWORK_PATH)
	ExpeditionStoreScript.delete_record(EXPEDITION_PATH)
	var stage: String = OS.get_environment("ROUTE_STAGE")
	if stage.begins_with("initial_"):
		await validate_initial_check(stage.trim_prefix("initial_"))
	elif stage == "returned":
		await validate_returned_map()
	else:
		fail("unknown stage " + stage)


func validate_initial_check(check_id: String) -> void:
	var map: RegionalExpeditionMap = MapScene.instantiate() as RegionalExpeditionMap
	if not require(map != null, "map instantiated"):
		return
	map.network_record_path = NETWORK_PATH
	map.expedition_record_path = EXPEDITION_PATH
	map.allow_scene_launch = false
	add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame

	match check_id:
		"node":
			if not require(str(map.network_record.get("current_node_id", "")) == RegionalStoreScript.NODE_CYPRESS, "starts at Cypress"):
				return
		"cairn":
			if not require(not RegionalStoreScript.is_node_discovered(map.network_record, RegionalStoreScript.NODE_CAIRN), "cairn hidden"):
				return
		"route":
			map.select_node(RegionalStoreScript.NODE_BLUE_RIDGE)
			if not require(map.selected_route_id == RegionalStoreScript.ROUTE_MAIN, "main route selected"):
				return
		"state":
			map.select_node(RegionalStoreScript.NODE_BLUE_RIDGE)
			var state_context: Dictionary = map.build_launch_context()
			if not require(str(state_context.get("route_state", "")) == RegionalStoreScript.STATE_DISCOVERED, "route discovered"):
				return
		"plan_type":
			map.select_node(RegionalStoreScript.NODE_BLUE_RIDGE)
			var type_context: Dictionary = map.build_launch_context()
			if not require(type_context.get("familiarity_plan", {}) is Dictionary, "plan dictionary"):
				return
		"indices_type":
			map.select_node(RegionalStoreScript.NODE_BLUE_RIDGE)
			var indices_context: Dictionary = map.build_launch_context()
			var plan_value: Variant = indices_context.get("familiarity_plan", {})
			if not require(plan_value is Dictionary, "plan dictionary"):
				return
			if not require((plan_value as Dictionary).get("source_indices", []) is Array, "source indices array"):
				return
		"plan_size_probe":
			map.select_node(RegionalStoreScript.NODE_BLUE_RIDGE)
			var size_context: Dictionary = map.build_launch_context()
			var size_plan_value: Variant = size_context.get("familiarity_plan", {})
			if not require(size_plan_value is Dictionary, "plan dictionary"):
				return
			var source_value: Variant = (size_plan_value as Dictionary).get("source_indices", [])
			if not require(source_value is Array, "source indices array"):
				return
			var expected_size: int = int(OS.get_environment("EXPECTED_ROUTE_SIZE"))
			if not require((source_value as Array).size() == expected_size, "expected plan size"):
				return
		_:
			fail("unknown initial check " + check_id)
			return
	pass_stage("INITIAL_" + check_id.to_upper())


func validate_returned_map() -> void:
	var expedition_record: Dictionary = ExpeditionStoreScript.load_or_create(
		RegionalStoreScript.ROUTE_MAIN,
		18890417,
		EXPEDITION_PATH
	)
	var discoveries: Dictionary = expedition_record.get("discoveries", {}) as Dictionary
	discoveries[RegionalStoreScript.NODE_CAIRN] = true
	expedition_record["discoveries"] = discoveries
	expedition_record["shortcut_unlocked"] = true
	expedition_record["completed_forward"] = true
	ExpeditionStoreScript.save_record(expedition_record, EXPEDITION_PATH)

	var network_record: Dictionary = RegionalStoreScript.load_or_create(NETWORK_PATH)
	network_record = RegionalStoreScript.sync_from_expedition_record(network_record, expedition_record)
	network_record = RegionalStoreScript.complete_route(
		network_record,
		RegionalStoreScript.ROUTE_MAIN,
		RegionalStoreScript.NODE_BLUE_RIDGE,
		"validation-plan"
	)
	RegionalStoreScript.save_record(network_record, NETWORK_PATH)

	var map: RegionalExpeditionMap = MapScene.instantiate() as RegionalExpeditionMap
	if not require(map != null, "returned map instantiated"):
		return
	map.network_record_path = NETWORK_PATH
	map.expedition_record_path = EXPEDITION_PATH
	map.allow_scene_launch = false
	add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame

	if not require(str(map.network_record.get("current_node_id", "")) == RegionalStoreScript.NODE_BLUE_RIDGE, "returned at Blue Ridge"):
		return
	if not require(RegionalStoreScript.is_node_discovered(map.network_record, RegionalStoreScript.NODE_CAIRN), "cairn persisted"):
		return
	if not require(RegionalStoreScript.get_route_state(map.network_record, RegionalStoreScript.ROUTE_MAIN) == RegionalStoreScript.STATE_STABILIZED, "main route remains stabilized"):
		return
	map.select_node(RegionalStoreScript.NODE_CAIRN)
	if not require(map.selected_route_id == RegionalStoreScript.ROUTE_CAIRN_BLUE_RIDGE, "eastern route selected"):
		return
	var context: Dictionary = map.build_launch_context()
	if not require(str(context.get("route_state", "")) == RegionalStoreScript.STATE_MAPPED, "eastern route mapped"):
		return
	var plan_value: Variant = context.get("familiarity_plan", {})
	if not require(plan_value is Dictionary, "eastern plan dictionary"):
		return
	var source_value: Variant = (plan_value as Dictionary).get("source_indices", [])
	if not require(source_value is Array and (source_value as Array).size() == 3, "three-segment eastern route"):
		return
	pass_stage("RETURNED")


func require(condition: bool, label: String) -> bool:
	if condition:
		return true
	fail(label)
	return false


func pass_stage(label: String) -> void:
	RegionalStoreScript.delete_record(NETWORK_PATH)
	ExpeditionStoreScript.delete_record(EXPEDITION_PATH)
	print("ROUTE_FAMILIARITY_MAP_STAGE_" + label + ": PASS")
	get_tree().quit(0)


func fail(label: String) -> void:
	push_error("ROUTE_FAMILIARITY_MAP_STAGE failed: " + label)
	get_tree().quit(1)
