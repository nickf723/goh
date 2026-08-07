extends Node3D
class_name FlightConcentrationSpell

const FlightDefinition: Resource = preload(
	"res://data/concentration/flight_concentration.tres"
)
const ConcentrationRuntime = preload(
	"res://scripts/concentration/concentration_runtime_access.gd"
)


func execute(player: Node3D, _cast_direction: Vector3) -> void:
	if player == null:
		queue_free()
		return

	var aerial_locomotion: Node = player.get_node_or_null("AerialLocomotion")
	if aerial_locomotion == null or not aerial_locomotion.has_method("activate_flight"):
		show_message("Grace has no aerial locomotion controller in this scene.")
		queue_free()
		return

	# Presence in Grace's learned spell library is the development unlock. The
	# progression layer can later remove the resource until Flight is earned.
	aerial_locomotion.set("flight_unlocked", true)
	if ConcentrationRuntime.ensure_manager(get_tree(), player) == null:
		show_message("Flight could not establish its concentration service.")
		queue_free()
		return

	# AbilityCaster has already approved this cast. Hand the brief generic cast
	# lock to the sustained Flight state before activation checks run.
	var action_state: Node = player.get_node_or_null("PlayerActionState")
	if action_state != null:
		action_state.set("is_casting", false)
		action_state.set("cast_lock_timer", 0.0)

	var activated: bool = bool(
		aerial_locomotion.call("activate_flight", FlightDefinition)
	)
	if activated:
		_release_inactive_runtime_weather()
	else:
		show_message("Flight could not take hold.")
	queue_free()


func _release_inactive_runtime_weather() -> void:
	for controller: Node in get_tree().get_nodes_in_group(
		"runtime_weather_controller"
	):
		if (
			controller == null
			or not is_instance_valid(controller)
			or controller.is_queued_for_deletion()
		):
			continue
		if bool(controller.get("active")):
			continue
		controller.queue_free()


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	else:
		print(text)
