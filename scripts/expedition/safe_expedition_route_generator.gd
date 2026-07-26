extends "res://scripts/expedition/expedition_route_generator.gd"

const RegionalStoreScript = preload("res://scripts/expedition/regional_expedition_store.gd")

@export var regional_network_record_path: String = RegionalStoreScript.DEFAULT_RECORD_PATH
@export var regional_map_scene_path: String = "res://scenes/levels/prototypes/prototype_regional_expedition_map_v1.tscn"

var regional_launch_context: Dictionary = {}
var launched_from_regional_map: bool = false
var regional_arrival_pending: bool = false


func _ready() -> void:
	read_regional_launch_context()
	super._ready()
	if launched_from_regional_map:
		apply_regional_launch_origin()
		set_regional_route_objective()


func read_regional_launch_context() -> void:
	if not get_tree().root.has_meta("regional_expedition_launch"):
		return
	var context_value: Variant = get_tree().root.get_meta("regional_expedition_launch")
	if not context_value is Dictionary:
		return
	regional_launch_context = (context_value as Dictionary).duplicate(true)
	launched_from_regional_map = not regional_launch_context.is_empty()
	if not launched_from_regional_map:
		return
	record_path = str(regional_launch_context.get("expedition_record_path", record_path))
	regional_network_record_path = str(
		regional_launch_context.get("network_record_path", regional_network_record_path)
	)
	regional_map_scene_path = str(regional_launch_context.get("map_scene_path", regional_map_scene_path))


func clear_generated_route() -> void:
	clear_player_generated_references()
	super.clear_generated_route()


func clear_player_generated_references() -> void:
	if player == null or not is_instance_valid(player):
		return

	if player.has_method("clear_lock_on"):
		player.call("clear_lock_on")
	else:
		player.set("lock_on_target", null)

	player.set("current_interactable", null)

	var nearby_value: Variant = player.get("nearby_interactables")
	if nearby_value is Array:
		var nearby: Array = nearby_value as Array
		nearby.clear()
		player.set("nearby_interactables", nearby)

	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("hide_prompt"):
		ui.call("hide_prompt")


func apply_regional_launch_origin() -> void:
	if player == null or not is_instance_valid(player):
		return
	var origin_node_id: String = str(
		regional_launch_context.get("origin_node_id", RegionalStoreScript.NODE_CYPRESS)
	)
	match origin_node_id:
		RegionalStoreScript.NODE_BLUE_RIDGE:
			place_player_near_marker(destination_marker, Vector3(0.0, 1.0, 3.1))
		RegionalStoreScript.NODE_CAIRN:
			place_player_near_marker(landmark_marker, Vector3(2.6, 1.0, 0.0))
		_:
			reset_player_to_route_start()


func place_player_near_marker(marker: Node3D, local_offset: Vector3) -> void:
	if marker == null or not is_instance_valid(marker) or player == null:
		return
	player.global_transform = marker.global_transform.translated_local(local_offset)
	player.velocity = Vector3.ZERO
	if player.has_method("cancel_combat_motion"):
		player.call("cancel_combat_motion")
	if player.has_method("clear_lock_on"):
		player.call("clear_lock_on")


func set_regional_route_objective() -> void:
	var destination_node_id: String = str(regional_launch_context.get("destination_node_id", ""))
	var objective: String = "Reach " + get_regional_node_display_name(destination_node_id) + "."
	GameState.set_objective(objective)
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("set_objective"):
		ui.call("set_objective", objective)
	show_message(
		"Regional route assembled: "
		+ get_regional_node_display_name(str(regional_launch_context.get("origin_node_id", "")))
		+ " → "
		+ get_regional_node_display_name(destination_node_id)
	)


func activate_route_marker(marker_type: String, marker_id: String) -> Dictionary:
	if not launched_from_regional_map:
		return super.activate_route_marker(marker_type, marker_id)

	var marker_node_id: String = get_regional_node_for_marker(marker_type, marker_id)
	var destination_node_id: String = str(regional_launch_context.get("destination_node_id", ""))
	var selected_route_id: String = str(regional_launch_context.get("route_id", RegionalStoreScript.ROUTE_MAIN))

	if marker_type == "landmark":
		var landmark_result: Dictionary = super.activate_route_marker(marker_type, marker_id)
		sync_regional_network_from_expedition()
		if marker_node_id == destination_node_id:
			return complete_regional_arrival(selected_route_id, destination_node_id, landmark_result)
		return landmark_result

	if marker_node_id != destination_node_id:
		return {
			"message": get_regional_node_display_name(marker_node_id) + " is not the selected destination.",
			"objective": "Reach " + get_regional_node_display_name(destination_node_id) + ".",
		}

	var base_result: Dictionary = {}
	if selected_route_id == RegionalStoreScript.ROUTE_MAIN:
		base_result = super.activate_route_marker(marker_type, marker_id)
	return complete_regional_arrival(selected_route_id, destination_node_id, base_result)


func complete_regional_arrival(
	selected_route_id: String,
	destination_node_id: String,
	base_result: Dictionary = {}
) -> Dictionary:
	if regional_arrival_pending:
		return base_result
	regional_arrival_pending = true

	var network_record: Dictionary = RegionalStoreScript.load_or_create(regional_network_record_path)
	network_record = RegionalStoreScript.sync_from_expedition_record(network_record, route_record)
	network_record = RegionalStoreScript.complete_route(
		network_record,
		selected_route_id,
		destination_node_id
	)
	RegionalStoreScript.save_record(network_record, regional_network_record_path)

	var result: Dictionary = base_result.duplicate(true)
	result["message"] = "Arrived at " + get_regional_node_display_name(destination_node_id) + ". The regional map has been updated."
	result["objective"] = "Choose the next expedition route."

	if not bool(regional_launch_context.get("suppress_scene_transition", false)):
		get_tree().root.remove_meta("regional_expedition_launch")
		call_deferred("return_to_regional_map")
	return result


func sync_regional_network_from_expedition() -> void:
	var network_record: Dictionary = RegionalStoreScript.load_or_create(regional_network_record_path)
	network_record = RegionalStoreScript.sync_from_expedition_record(network_record, route_record)
	RegionalStoreScript.save_record(network_record, regional_network_record_path)


func return_to_regional_map() -> void:
	get_tree().change_scene_to_file(regional_map_scene_path)


func get_regional_node_for_marker(marker_type: String, marker_id: String) -> String:
	match marker_type:
		"start":
			return RegionalStoreScript.NODE_CYPRESS
		"destination":
			return RegionalStoreScript.NODE_BLUE_RIDGE
		"landmark":
			if marker_id == RegionalStoreScript.NODE_CAIRN:
				return RegionalStoreScript.NODE_CAIRN
	return ""


func get_regional_node_display_name(node_id: String) -> String:
	match node_id:
		RegionalStoreScript.NODE_CYPRESS:
			return "Cypress Field Camp"
		RegionalStoreScript.NODE_BLUE_RIDGE:
			return "Blue Ridge Waystation"
		RegionalStoreScript.NODE_CAIRN:
			return "Old Survey Cairn"
	return "Unknown Location"
