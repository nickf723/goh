extends "res://scripts/input/player_control_router_contextual.gd"


func _handle_active_manipulation_button(
	event: InputEventJoypadButton
) -> bool:
	var shared_placement: Node = _get_shared_placement_controller()
	if shared_placement != null:
		return bool(shared_placement.call("handle_controller_button", event))
	return super._handle_active_manipulation_button(event)


func _get_shared_placement_controller() -> Node:
	var controller: Node = null
	if actor != null and is_instance_valid(actor):
		controller = actor.get_node_or_null("SharedPlacementController")
	if controller == null:
		controller = get_tree().get_first_node_in_group(
			"shared_placement_controller"
		)
	if controller == null or not is_instance_valid(controller):
		return null
	if not controller.has_method("is_placement_active"):
		return null
	if not bool(controller.call("is_placement_active")):
		return null
	return controller


func _is_shared_placement_active() -> bool:
	return _get_shared_placement_controller() != null


func get_input_mode_debug_data() -> Dictionary:
	var data: Dictionary = super.get_input_mode_debug_data()
	data["shared_placement"] = _is_shared_placement_active()
	if data["shared_placement"]:
		data["right_stick_owner"] = "shared_placement_camera"
	return data
