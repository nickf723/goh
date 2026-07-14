extends Node
class_name RuinedVillageSaveSync

var sync_count: int = 0


func _ready() -> void:
	add_to_group("ruined_village_save_sync")
	add_to_group("debuggable")

	if not GameState.save_loaded.is_connected(_on_save_loaded):
		GameState.save_loaded.connect(_on_save_loaded)

	call_deferred("sync_after_startup")


func _exit_tree() -> void:
	if GameState.save_loaded.is_connected(_on_save_loaded):
		GameState.save_loaded.disconnect(_on_save_loaded)


func sync_after_startup() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	synchronize_world_from_game_state()


func _on_save_loaded(_save_data: Dictionary) -> void:
	call_deferred("synchronize_world_from_game_state")


func synchronize_world_from_game_state() -> void:
	sync_group("village_route_gate")
	sync_group("village_ice_bridge")
	sync_group("village_memory")
	sync_group("village_clue")
	sync_group("encounter_controller")
	sync_count += 1


func sync_group(group_name: String) -> void:
	for node: Node in get_tree().get_nodes_in_group(group_name):
		if node.has_method("sync_from_game_state"):
			node.call("sync_from_game_state")


func get_debug_data() -> Dictionary:
	return {
		"save_syncs": sync_count,
		"route_gates": get_tree().get_nodes_in_group("village_route_gate").size(),
		"encounters": get_tree().get_nodes_in_group("encounter_controller").size(),
	}
