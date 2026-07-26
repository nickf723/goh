extends Node

const MapScene: PackedScene = preload("res://scenes/levels/prototypes/prototype_regional_expedition_map_v1.tscn")
const RegionalStoreScript = preload("res://scripts/expedition/regional_expedition_store.gd")
const ExpeditionStoreScript = preload("res://scripts/expedition/expedition_record_store.gd")
const NETWORK_PATH := "user://validation_atomic_route_network.json"
const EXPEDITION_PATH := "user://validation_atomic_route_expedition.json"


func _ready() -> void:
	RegionalStoreScript.delete_record(NETWORK_PATH)
	ExpeditionStoreScript.delete_record(EXPEDITION_PATH)
	var stage := OS.get_environment("ROUTE_STAGE")
	if stage.begins_with("initial_"):
		await validate_initial(stage.trim_prefix("initial_"))
	elif stage == "returned":
		await validate_returned()
	else:
		fail("unknown stage")


func make_map() -> RegionalExpeditionMap:
	var map: RegionalExpeditionMap = MapScene.instantiate() as RegionalExpeditionMap
	map.network_record_path = NETWORK_PATH
	map.expedition_record_path = EXPEDITION_PATH
	map.allow_scene_launch = false
	add_child(map)
	return map


func validate_initial(check_id: String) -> void:
	var map := make_map()
	await get_tree().process_frame
	await get_tree().process_frame
	map.select_node(RegionalStoreScript.NODE_BLUE_RIDGE)
	var context: Dictionary = map.build_launch_context()
	match check_id:
		"node":
			if not check(str(map.network_record.get("current_node_id", "")) == RegionalStoreScript.NODE_CYPRESS, "initial node"): return
		"selection":
			if not check(map.selected_route_id == RegionalStoreScript.ROUTE_MAIN, "route selection"): return
		"context_route":
			if not check(str(context.get("route_id", "")) == RegionalStoreScript.ROUTE_MAIN, "context route"): return
		"context_state":
			if not check(str(context.get("route_state", "")) == RegionalStoreScript.STATE_DISCOVERED, "context state"): return
		"plan_type":
			if not check(context.get("familiarity_plan", {}) is Dictionary, "plan type"): return
		"indices_type":
			var plan_value: Variant = context.get("familiarity_plan", {})
			if not check(plan_value is Dictionary, "plan type"): return
			if not check((plan_value as Dictionary).get("source_indices", []) is Array, "indices type"): return
		"plan_size":
			var plan_value: Variant = context.get("familiarity_plan", {})
			if not check(plan_value is Dictionary, "plan type"): return
			var indices_value: Variant = (plan_value as Dictionary).get("source_indices", [])
			if not check(indices_value is Array and (indices_value as Array).size() == 5, "plan size"): return
		_:
			fail("unknown initial check")
			return
	pass_stage("INITIAL_" + check_id.to_upper())


func validate_returned() -> void:
	var expedition: Dictionary = ExpeditionStoreScript.load_or_create(RegionalStoreScript.ROUTE_MAIN, 18890417, EXPEDITION_PATH)
	var discoveries: Dictionary = expedition.get("discoveries", {}) as Dictionary
	discoveries[RegionalStoreScript.NODE_CAIRN] = true
	expedition["discoveries"] = discoveries
	expedition["shortcut_unlocked"] = true
	expedition["completed_forward"] = true
	ExpeditionStoreScript.save_record(expedition, EXPEDITION_PATH)
	var network: Dictionary = RegionalStoreScript.load_or_create(NETWORK_PATH)
	network = RegionalStoreScript.sync_from_expedition_record(network, expedition)
	network = RegionalStoreScript.complete_route(network, RegionalStoreScript.ROUTE_MAIN, RegionalStoreScript.NODE_BLUE_RIDGE, "validation-plan")
	RegionalStoreScript.save_record(network, NETWORK_PATH)

	var map := make_map()
	await get_tree().process_frame
	await get_tree().process_frame
	if not check(str(map.network_record.get("current_node_id", "")) == RegionalStoreScript.NODE_BLUE_RIDGE, "returned node"): return
	if not check(RegionalStoreScript.is_node_discovered(map.network_record, RegionalStoreScript.NODE_CAIRN), "cairn persisted"): return
	if not check(RegionalStoreScript.get_route_state(map.network_record, RegionalStoreScript.ROUTE_MAIN) == RegionalStoreScript.STATE_STABILIZED, "main stabilized"): return
	map.select_node(RegionalStoreScript.NODE_CAIRN)
	var context: Dictionary = map.build_launch_context()
	if not check(str(context.get("route_id", "")) == RegionalStoreScript.ROUTE_CAIRN_BLUE_RIDGE, "eastern route"): return
	if not check(str(context.get("route_state", "")) == RegionalStoreScript.STATE_MAPPED, "eastern mapped"): return
	var plan_value: Variant = context.get("familiarity_plan", {})
	if not check(plan_value is Dictionary, "eastern plan type"): return
	var indices_value: Variant = (plan_value as Dictionary).get("source_indices", [])
	if not check(indices_value is Array and (indices_value as Array).size() == 3, "eastern plan size"): return
	pass_stage("RETURNED")


func check(condition: bool, label: String) -> bool:
	if condition: return true
	fail(label)
	return false


func pass_stage(label: String) -> void:
	RegionalStoreScript.delete_record(NETWORK_PATH)
	ExpeditionStoreScript.delete_record(EXPEDITION_PATH)
	print("ATOMIC_ROUTE_MAP_" + label + ": PASS")
	get_tree().quit(0)


func fail(label: String) -> void:
	push_error("ATOMIC_ROUTE_MAP failed: " + label)
	get_tree().quit(1)
