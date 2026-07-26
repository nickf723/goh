extends "res://scripts/expedition/expedition_route_generator.gd"


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
