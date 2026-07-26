extends Node

const MapScene: PackedScene = preload("res://scenes/levels/prototypes/prototype_regional_expedition_map_v1.tscn")
const RegionalStoreScript = preload("res://scripts/expedition/regional_expedition_store.gd")
const ExpeditionStoreScript = preload("res://scripts/expedition/expedition_record_store.gd")

const NETWORK_PATH: String = "user://validation_regional_stage_network.json"
const EXPEDITION_PATH: String = "user://validation_regional_stage_expedition.json"


func _ready() -> void:
	RegionalStoreScript.delete_record(NETWORK_PATH)
	ExpeditionStoreScript.delete_record(EXPEDITION_PATH)
	var stage: String = OS.get_environment("ROUTE_STAGE")
	if stage.begins_with("initial_"):
		await run_initial_check(stage.trim_prefix("initial_"))
	elif stage == "returned":
		await run_returned_stage()
	else:
		fail("unknown stage " + stage)


func run_initial_check(check_id: String) -> void:
	var map: RegionalExpeditionMap = MapScene.instantiate() as RegionalExpeditionMap
	if map == null:
		fail("initial map instantiated")
		return
	map.network_record_path = NETWORK_PATH
	map.expedition_record_path = EXPEDITION_PATH
	map.allow_scene_launch = false
	add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame

	match check_id:
		"node":
			if not check(str(map.network_record.get("current_node_id", "")) == RegionalStoreScript.NODE_CYPRESS, "initial node is Cypress"):
				return
		"cairn":
			if not check(not RegionalStoreScript.is_node_discovered(map.network_record, RegionalStoreScript.NODE_CAIRN), "cairn starts hidden"):
				return
		"route":
			map.select_node(RegionalStoreScript.NODE_BLUE_RIDGE)
			if not check(map.selected_route_id == RegionalStoreScript.ROUTE_MAIN, "main route selected"):
				return
		"origin":
			map.select_node(RegionalStoreScript.NODE_BLUE_RIDGE)
			var origin_context: Dictionary = map.build_launch_context()
			if not check(str(origin_context.get("origin_node_id", "")) == RegionalStoreScript.NODE_CYPRESS, "outbound origin"):
				return
		"destination":
			map.select_node(RegionalStoreScript.NODE_BLUE_RIDGE)
			var destination_context: Dictionary = map.build_launch_context()
			if not check(str(destination_context.get("destination_node_id", "")) == RegionalStoreScript.NODE_BLUE_RIDGE, "outbound destination"):
				return
		"state":
			map.select_node(RegionalStoreScript.NODE_BLUE_RIDGE)
			var state_context: Dictionary = map.build_launch_context()
			if not check(str(state_context.get("route_state", "")) == RegionalStoreScript.STATE_DISCOVERED, "main route starts discovered"):
				return
		"plan_type":
			map.select_node(RegionalStoreScript.NODE_BLUE_RIDGE)
			var type_context: Dictionary = map.build_launch_context()
			if not check(type_context.get("familiarity_plan", {}) is Dictionary, "initial plan dictionary"):
				return
		"plan_size":
			map.select_node(RegionalStoreScript.NODE_BLUE_RIDGE)
			var size_context: Dictionary = map.build_launch_context()
			var plan_value: Variant = size_context.get("familiarity_plan", {})
			if not check(plan_value is Dictionary, "initial plan dictionary"):
				return
			var indices_value: Variant = (plan_value as Dictionary).get("source_indices", [])
			if not check(indices_value is Array, "initial plan indices array"):
				return
			if not check((indices_value as Array).size() == 5, "initial plan uses five segments; actual=" + str((indices_value as Array).size())):
				return
		_:
			fail("unknown initial check " + check_id)
			return
	pass_stage("INITIAL_" + check_id.to_upper())


func run_returned_stage() -> void:
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
	if not check(map != null, "returned map instantiated"):
		return
	map.network_record_path = NETWORK_PATH
	map.expedition_record_path = EXPEDITION_PATH
	map.allow_scene_launch = false
	add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame
	if not check(str(map.network_record.get("current_node_id", "")) == RegionalStoreScript.NODE_BLUE_RIDGE, "returned node is Blue Ridge"):
		return
	if not check(RegionalStoreScript.is_node_discovered(map.network_record, RegionalStoreScript.NODE_CAIRN), "returned cairn discovered"):
		return
	if not check(RegionalStoreScript.get_route_state(map.network_record, RegionalStoreScript.ROUTE_MAIN) == RegionalStoreScript.STATE_STABILIZED, "main familiarity remains stabilized"):
		return
	map.select_node(RegionalStoreScript.NODE_CAIRN)
	if not check(map.selected_route_id == RegionalStoreScript.ROUTE_CAIRN_BLUE_RIDGE, "eastern route selected"):
		return
	var context: Dictionary = map.build_launch_context()
	if not check(str(context.get("route_state", "")) == RegionalStoreScript.STATE_MAPPED, "eastern route is mapped"):
		return
	var plan_value: Variant = context.get("familiarity_plan", {})
	if not check(plan_value is Dictionary, "returned plan dictionary"):
		return
	var indices_value: Variant = (plan_value as Dictionary).get("source_indices", [])
	if not check(indices_value is Array and (indices_value as Array).size() == 3, "mapped eastern route uses three segments"):
		return
	pass_stage("RETURNED")


func check(condition: bool, label: String) -> bool:
	if condition:
		return true
	fail(label)
	return false


func pass_stage(label: String) -> void:
	RegionalStoreScript.delete_record(NETWORK_PATH)
	ExpeditionStoreScript.delete_record(EXPEDITION_PATH)
	print("REGIONAL_ROUTE_STAGE_" + label + ": PASS")
	get_tree().quit(0)


func fail(label: String) -> void:
	push_error("REGIONAL_ROUTE_STAGE_TEST failed: " + label)
	get_tree().quit(1)
