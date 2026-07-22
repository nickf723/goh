extends Node3D
class_name FlightConcentrationSpell

const FlightDefinition: Resource = preload("res://data/concentration/flight_concentration.tres")


func execute(player: Node3D, _cast_direction: Vector3) -> void:
	if player == null:
		queue_free()
		return

	var aerial_locomotion: Node = player.get_node_or_null("AerialLocomotion")
	if aerial_locomotion == null or not aerial_locomotion.has_method("activate_flight"):
		show_message("Grace has no aerial locomotion controller in this scene.")
		queue_free()
		return

	# AbilityCaster has already approved and paid for this cast before execute() runs.
	# Hand the action lock off to the sustained Flight state so activation is not
	# rejected by the brief generic cast timer that was just started.
	var action_state: Node = player.get_node_or_null("PlayerActionState")
	if action_state != null:
		action_state.set("is_casting", false)
		action_state.set("cast_lock_timer", 0.0)

	aerial_locomotion.call("activate_flight", FlightDefinition)
	queue_free()


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	else:
		print(text)
