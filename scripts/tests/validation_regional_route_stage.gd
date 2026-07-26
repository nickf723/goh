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
	match stage:
		"initial":
			await run_initial_stage()
		"returned":
			await run_returned_stage()
		_:
			fail("unknown stage " + stage)


func run_initial_stage() -> void:
	var map: RegionalExpeditionMap = MapScene.instantiate() as RegionalExpeditionMap
	if not check(map != null, "initial map instantiated"):
		return
	map.network_record_path = NETWORK_PATH
	map.expedition_record_path = EXPEDITION_PATH
	map.allow_scene_launch = false
	add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame
	if not check(str(map.network_record.get("current_node_id", "")) == RegionalStoreScript.NODE_CYPRESS, "initial node is Cypress"):
		return
	if not check(not RegionalStoreScript.is_node_discovered(map.network_record, RegionalStoreScript.NODE_CAIRN), "cairn starts hidden"):
		return
	map.select_node(RegionalStoreScript.NODE_BLUE_RIDGE)
	if not check(map.selected_route_id == RegionalStoreScript.ROUTE_MAIN, "main route selected"):
		return
	var context: Dictionary = map.build_launch_context()
	if not check(str(context.get("route_state", "")) == RegionalStoreScript.STATE_DISCOVERED, "main route starts discovered"):
		return
	var plan_value: Variant = context.get("familiarity_plan", {})
	if not check(plan_value is Dictionary, "initial plan dictionary"):
		return
	var indices_value: Variant = (plan_value as Dictionary).get("source_indices", [])
	if not check(indices_value is Array and (indices_value as Array).size() == 5, "initial plan uses five segments"):
		return
	pass_stage("INITIAL")


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
