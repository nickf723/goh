extends Node

const MapScene: PackedScene = preload("res://scenes/levels/prototypes/prototype_regional_expedition_map_v1.tscn")
const RegionalStoreScript = preload("res://scripts/expedition/regional_expedition_store.gd")
const ExpeditionStoreScript = preload("res://scripts/expedition/expedition_record_store.gd")

const TEST_NETWORK_PATH: String = "user://regional_expedition_map_smoke_test.json"
const TEST_EXPEDITION_PATH: String = "user://regional_expedition_route_smoke_test.json"
const CHECKPOINT_FILE_NAME: String = "goh-regional-map-checkpoint.txt"
const PASS_FILE_NAME: String = "goh-regional-map-pass.txt"


func _ready() -> void:
	clear_ci_markers()
	write_checkpoint("starting")
	RegionalStoreScript.delete_record(TEST_NETWORK_PATH)
	ExpeditionStoreScript.delete_record(TEST_EXPEDITION_PATH)
	get_tree().root.remove_meta("regional_expedition_launch")

	var map: RegionalExpeditionMap = MapScene.instantiate() as RegionalExpeditionMap
	if not require_true(map != null, "initial map instantiation"):
		return
	map.network_record_path = TEST_NETWORK_PATH
	map.expedition_record_path = TEST_EXPEDITION_PATH
	map.allow_scene_launch = false
	add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame
	write_checkpoint("initial map ready")

	if not require_true(
		str(map.network_record.get("current_node_id", "")) == RegionalStoreScript.NODE_CYPRESS,
		"initial current node"
	):
		return
	if not require_true(
		not RegionalStoreScript.is_node_discovered(map.network_record, RegionalStoreScript.NODE_CAIRN),
		"cairn initially hidden"
	):
		return
	map.select_node(RegionalStoreScript.NODE_BLUE_RIDGE)
	if not require_true(map.selected_route_id == RegionalStoreScript.ROUTE_MAIN, "main route selection"):
		return
	var outbound_context: Dictionary = map.build_launch_context()
	if not require_true(
		str(outbound_context.get("origin_node_id", "")) == RegionalStoreScript.NODE_CYPRESS,
		"outbound origin"
	):
		return
	if not require_true(
		str(outbound_context.get("destination_node_id", "")) == RegionalStoreScript.NODE_BLUE_RIDGE,
		"outbound destination"
	):
		return
	if not require_true(
		str(outbound_context.get("route_state", "")) == RegionalStoreScript.STATE_DISCOVERED,
		"outbound route state"
	):
		return
	var outbound_plan_value: Variant = outbound_context.get("familiarity_plan", {})
	if not require_true(outbound_plan_value is Dictionary, "outbound plan type"):
		return
	var outbound_plan: Dictionary = outbound_plan_value as Dictionary
	if not require_true(str(outbound_plan.get("signature", "")) != "", "outbound signature"):
		return
	var outbound_indices_value: Variant = outbound_plan.get("source_indices", [])
	if not require_true(outbound_indices_value is Array, "outbound indices type"):
		return
	if not require_true((outbound_indices_value as Array).size() == 5, "outbound full slice"):
		return
	write_checkpoint("outbound context valid")

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
	write_checkpoint("persistence simulated")

	var returned_map: RegionalExpeditionMap = MapScene.instantiate() as RegionalExpeditionMap
	if not require_true(returned_map != null, "returned map instantiation"):
		return
	returned_map.network_record_path = TEST_NETWORK_PATH
	returned_map.expedition_record_path = TEST_EXPEDITION_PATH
	returned_map.allow_scene_launch = false
	add_child(returned_map)
	await get_tree().process_frame
	await get_tree().process_frame
	write_checkpoint("returned map ready")

	if not require_true(
		str(returned_map.network_record.get("current_node_id", "")) == RegionalStoreScript.NODE_BLUE_RIDGE,
		"returned current node"
	):
		return
	if not require_true(
		RegionalStoreScript.is_node_discovered(returned_map.network_record, RegionalStoreScript.NODE_CAIRN),
		"returned cairn discovery"
	):
		return
	if not require_true(
		RegionalStoreScript.get_state_rank(
			RegionalStoreScript.get_route_state(
				returned_map.network_record,
				RegionalStoreScript.ROUTE_MAIN
			)
		) >= RegionalStoreScript.get_state_rank(RegionalStoreScript.STATE_CROSSED),
		"returned main route familiarity"
	):
		return
	returned_map.select_node(RegionalStoreScript.NODE_CAIRN)
	if not require_true(
		returned_map.selected_route_id == RegionalStoreScript.ROUTE_CAIRN_BLUE_RIDGE,
		"returned cairn route selection"
	):
		return
	var cairn_context: Dictionary = returned_map.build_launch_context()
	if not require_true(
		str(cairn_context.get("origin_node_id", "")) == RegionalStoreScript.NODE_BLUE_RIDGE,
		"cairn route origin"
	):
		return
	if not require_true(
		str(cairn_context.get("destination_node_id", "")) == RegionalStoreScript.NODE_CAIRN,
		"cairn route destination"
	):
		return
	if not require_true(
		str(cairn_context.get("route_state", "")) == RegionalStoreScript.STATE_MAPPED,
		"cairn route familiarity"
	):
		return
	var cairn_plan_value: Variant = cairn_context.get("familiarity_plan", {})
	if not require_true(cairn_plan_value is Dictionary, "cairn plan type"):
		return
	var cairn_indices_value: Variant = (cairn_plan_value as Dictionary).get("source_indices", [])
	if not require_true(cairn_indices_value is Array, "cairn indices type"):
		return
	if not require_true((cairn_indices_value as Array).size() == 3, "cairn eastern slice"):
		return

	returned_map.queue_free()
	await get_tree().process_frame
	RegionalStoreScript.delete_record(TEST_NETWORK_PATH)
	ExpeditionStoreScript.delete_record(TEST_EXPEDITION_PATH)
	get_tree().root.remove_meta("regional_expedition_launch")
	write_checkpoint("complete")
	write_ci_file(PASS_FILE_NAME, "PASS")
	print("REGIONAL_EXPEDITION_MAP_SMOKE_TEST: PASS")
	get_tree().quit(0)


func require_true(condition: bool, label: String) -> bool:
	if condition:
		return true
	write_checkpoint("FAILED: " + label)
	push_error("REGIONAL_EXPEDITION_MAP_SMOKE_TEST failed: " + label)
	get_tree().quit(1)
	return false


func write_checkpoint(value: String) -> void:
	write_ci_file(CHECKPOINT_FILE_NAME, value)
	print("REGIONAL_MAP_CHECKPOINT: ", value)


func clear_ci_markers() -> void:
	for file_name: String in [CHECKPOINT_FILE_NAME, PASS_FILE_NAME]:
		var file_path: String = get_ci_file_path(file_name)
		if FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(file_path)


func write_ci_file(file_name: String, value: String) -> void:
	var file: FileAccess = FileAccess.open(get_ci_file_path(file_name), FileAccess.WRITE)
	if file != null:
		file.store_string(value)
		file.flush()
		file.close()


func get_ci_file_path(file_name: String) -> String:
	var runner_temp: String = OS.get_environment("RUNNER_TEMP")
	if runner_temp != "":
		return runner_temp.path_join(file_name)
	return ProjectSettings.globalize_path("user://" + file_name)
