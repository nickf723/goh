extends RefCounted
class_name RegionalExpeditionStore

const DEFAULT_RECORD_PATH: String = "user://regional_expedition_network_v1.json"
const RECORD_VERSION: int = 2

const NODE_CYPRESS: String = "cypress_field_camp"
const NODE_BLUE_RIDGE: String = "blue_ridge_waystation"
const NODE_CAIRN: String = "old_survey_cairn"

const ROUTE_MAIN: String = "cypress_blue_ridge"
const ROUTE_CYPRESS_CAIRN: String = "cypress_survey_cairn"
const ROUTE_CAIRN_BLUE_RIDGE: String = "cairn_blue_ridge"

const STATE_UNKNOWN: String = "unknown"
const STATE_DISCOVERED: String = "discovered"
const STATE_CROSSED: String = "crossed"
const STATE_MAPPED: String = "mapped"
const STATE_STABILIZED: String = "stabilized"

const ROUTE_DEFAULT_SEEDS: Dictionary = {
	ROUTE_MAIN: 18890417,
	ROUTE_CYPRESS_CAIRN: 9042311,
	ROUTE_CAIRN_BLUE_RIDGE: 27182819,
}


static func load_or_create(record_path: String = DEFAULT_RECORD_PATH) -> Dictionary:
	var loaded: Dictionary = load_record(record_path)
	if loaded.is_empty():
		loaded = create_record()
		save_record(loaded, record_path)
	return normalize_record(loaded)


static func create_record() -> Dictionary:
	return {
		"version": RECORD_VERSION,
		"current_node_id": NODE_CYPRESS,
		"discovered_nodes": {
			NODE_CYPRESS: true,
			NODE_BLUE_RIDGE: true,
			NODE_CAIRN: false,
		},
		"routes": {
			ROUTE_MAIN: create_route_state(STATE_DISCOVERED, ROUTE_MAIN),
			ROUTE_CYPRESS_CAIRN: create_route_state(STATE_UNKNOWN, ROUTE_CYPRESS_CAIRN),
			ROUTE_CAIRN_BLUE_RIDGE: create_route_state(STATE_UNKNOWN, ROUTE_CAIRN_BLUE_RIDGE),
		},
	}


static func create_route_state(initial_state: String, route_id: String = ROUTE_MAIN) -> Dictionary:
	return {
		"state": initial_state,
		"crossings": 0,
		"last_destination": "",
		"seed": get_default_route_seed(route_id),
		"journey_index": 0,
		"last_plan_signature": "",
	}


static func normalize_record(record: Dictionary) -> Dictionary:
	var normalized: Dictionary = record.duplicate(true)
	normalized["version"] = RECORD_VERSION
	var current_node_id: String = str(normalized.get("current_node_id", NODE_CYPRESS))
	if not [NODE_CYPRESS, NODE_BLUE_RIDGE, NODE_CAIRN].has(current_node_id):
		current_node_id = NODE_CYPRESS
	normalized["current_node_id"] = current_node_id

	var discovered_nodes: Dictionary = normalized.get("discovered_nodes", {}) as Dictionary
	discovered_nodes[NODE_CYPRESS] = true
	discovered_nodes[NODE_BLUE_RIDGE] = true
	discovered_nodes[NODE_CAIRN] = bool(discovered_nodes.get(NODE_CAIRN, false))
	normalized["discovered_nodes"] = discovered_nodes

	var routes: Dictionary = normalized.get("routes", {}) as Dictionary
	routes[ROUTE_MAIN] = normalize_route_state(routes.get(ROUTE_MAIN, {}), STATE_DISCOVERED, ROUTE_MAIN)
	routes[ROUTE_CYPRESS_CAIRN] = normalize_route_state(
		routes.get(ROUTE_CYPRESS_CAIRN, {}),
		STATE_UNKNOWN,
		ROUTE_CYPRESS_CAIRN
	)
	routes[ROUTE_CAIRN_BLUE_RIDGE] = normalize_route_state(
		routes.get(ROUTE_CAIRN_BLUE_RIDGE, {}),
		STATE_UNKNOWN,
		ROUTE_CAIRN_BLUE_RIDGE
	)
	normalized["routes"] = routes
	return normalized


static func normalize_route_state(value: Variant, fallback_state: String, route_id: String) -> Dictionary:
	var route_state: Dictionary = value as Dictionary if value is Dictionary else {}
	var state_name: String = str(route_state.get("state", fallback_state))
	if get_state_rank(state_name) < 0:
		state_name = fallback_state
	return {
		"state": state_name,
		"crossings": maxi(int(route_state.get("crossings", 0)), 0),
		"last_destination": str(route_state.get("last_destination", "")),
		"seed": maxi(int(route_state.get("seed", get_default_route_seed(route_id))), 1),
		"journey_index": maxi(int(route_state.get("journey_index", 0)), 0),
		"last_plan_signature": str(route_state.get("last_plan_signature", "")),
	}


static func sync_from_expedition_record(network_record: Dictionary, expedition_record: Dictionary) -> Dictionary:
	var synced: Dictionary = normalize_record(network_record)
	var discovered_nodes: Dictionary = synced["discovered_nodes"] as Dictionary
	var discoveries: Dictionary = expedition_record.get("discoveries", {}) as Dictionary
	var cairn_discovered: bool = bool(discoveries.get(NODE_CAIRN, false))
	if cairn_discovered:
		discovered_nodes[NODE_CAIRN] = true
		synced["discovered_nodes"] = discovered_nodes
		promote_route(synced, ROUTE_CYPRESS_CAIRN, STATE_DISCOVERED)
		promote_route(synced, ROUTE_CAIRN_BLUE_RIDGE, STATE_DISCOVERED)

	if bool(expedition_record.get("completed_forward", false)):
		set_minimum_crossings(synced, ROUTE_MAIN, 1)
		promote_route(synced, ROUTE_MAIN, STATE_CROSSED)
	if bool(expedition_record.get("completed_round_trip", false)):
		set_minimum_crossings(synced, ROUTE_MAIN, 2)
		promote_route(synced, ROUTE_MAIN, STATE_MAPPED)
	if bool(expedition_record.get("shortcut_unlocked", false)):
		promote_route(synced, ROUTE_MAIN, STATE_STABILIZED)
		if cairn_discovered:
			promote_route(synced, ROUTE_CYPRESS_CAIRN, STATE_MAPPED)
			promote_route(synced, ROUTE_CAIRN_BLUE_RIDGE, STATE_MAPPED)
	return synced


static func complete_route(
	record: Dictionary,
	route_id: String,
	destination_node_id: String,
	plan_signature: String = ""
) -> Dictionary:
	var completed: Dictionary = normalize_record(record)
	var discovered_nodes: Dictionary = completed["discovered_nodes"] as Dictionary
	discovered_nodes[destination_node_id] = true
	completed["discovered_nodes"] = discovered_nodes
	completed["current_node_id"] = destination_node_id

	var routes: Dictionary = completed["routes"] as Dictionary
	var route_state: Dictionary = routes.get(
		route_id,
		create_route_state(STATE_DISCOVERED, route_id)
	) as Dictionary
	route_state["crossings"] = maxi(int(route_state.get("crossings", 0)), 0) + 1
	route_state["last_destination"] = destination_node_id
	route_state["last_plan_signature"] = plan_signature
	var crossings: int = int(route_state["crossings"])
	if crossings >= 3:
		route_state["state"] = STATE_STABILIZED
	elif crossings >= 2:
		route_state["state"] = STATE_MAPPED
	else:
		route_state["state"] = STATE_CROSSED
	route_state["journey_index"] = maxi(int(route_state.get("journey_index", 0)), 0) + 1
	route_state["seed"] = advance_route_seed(
		int(route_state.get("seed", get_default_route_seed(route_id))),
		int(route_state["journey_index"])
	)
	routes[route_id] = route_state
	completed["routes"] = routes
	return completed


static func promote_route(record: Dictionary, route_id: String, target_state: String) -> void:
	var routes: Dictionary = record.get("routes", {}) as Dictionary
	var route_state: Dictionary = routes.get(
		route_id,
		create_route_state(STATE_UNKNOWN, route_id)
	) as Dictionary
	if get_state_rank(target_state) > get_state_rank(str(route_state.get("state", STATE_UNKNOWN))):
		route_state["state"] = target_state
	routes[route_id] = route_state
	record["routes"] = routes


static func set_minimum_crossings(record: Dictionary, route_id: String, minimum: int) -> void:
	var routes: Dictionary = record.get("routes", {}) as Dictionary
	var route_state: Dictionary = routes.get(
		route_id,
		create_route_state(STATE_UNKNOWN, route_id)
	) as Dictionary
	route_state["crossings"] = maxi(int(route_state.get("crossings", 0)), minimum)
	routes[route_id] = route_state
	record["routes"] = routes


static func get_route_state(record: Dictionary, route_id: String) -> String:
	var routes: Dictionary = record.get("routes", {}) as Dictionary
	var route_state: Dictionary = routes.get(route_id, {}) as Dictionary
	return str(route_state.get("state", STATE_UNKNOWN))


static func get_route_crossings(record: Dictionary, route_id: String) -> int:
	var routes: Dictionary = record.get("routes", {}) as Dictionary
	var route_state: Dictionary = routes.get(route_id, {}) as Dictionary
	return maxi(int(route_state.get("crossings", 0)), 0)


static func get_route_seed(record: Dictionary, route_id: String) -> int:
	var routes: Dictionary = record.get("routes", {}) as Dictionary
	var route_state: Dictionary = routes.get(route_id, {}) as Dictionary
	return maxi(int(route_state.get("seed", get_default_route_seed(route_id))), 1)


static func get_route_journey_index(record: Dictionary, route_id: String) -> int:
	var routes: Dictionary = record.get("routes", {}) as Dictionary
	var route_state: Dictionary = routes.get(route_id, {}) as Dictionary
	return maxi(int(route_state.get("journey_index", 0)), 0)


static func get_default_route_seed(route_id: String) -> int:
	return maxi(int(ROUTE_DEFAULT_SEEDS.get(route_id, 18890417)), 1)


static func advance_route_seed(current_seed: int, journey_index: int) -> int:
	var advanced: int = int(
		(current_seed * 1103515245 + 12345 + journey_index * 7919)
		& 0x7FFFFFFF
	)
	return maxi(advanced, 1)


static func is_node_discovered(record: Dictionary, node_id: String) -> bool:
	var discovered_nodes: Dictionary = record.get("discovered_nodes", {}) as Dictionary
	return bool(discovered_nodes.get(node_id, false))


static func get_state_rank(state_name: String) -> int:
	match state_name:
		STATE_UNKNOWN:
			return 0
		STATE_DISCOVERED:
			return 1
		STATE_CROSSED:
			return 2
		STATE_MAPPED:
			return 3
		STATE_STABILIZED:
			return 4
	return -1


static func load_record(record_path: String = DEFAULT_RECORD_PATH) -> Dictionary:
	if not FileAccess.file_exists(record_path):
		return {}
	var file: FileAccess = FileAccess.open(record_path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


static func save_record(record: Dictionary, record_path: String = DEFAULT_RECORD_PATH) -> bool:
	var file: FileAccess = FileAccess.open(record_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(normalize_record(record), "\t"))
	return true


static func delete_record(record_path: String = DEFAULT_RECORD_PATH) -> void:
	if FileAccess.file_exists(record_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(record_path))
