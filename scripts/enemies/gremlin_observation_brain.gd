extends "res://scripts/enemies/storm_drain_pack_brain.gd"

const CreatureObservationAccess = preload(
	"res://scripts/animals/creature_observation_access.gd"
)


func on_action_started(action) -> void:
	super.on_action_started(action)
	_report_action_observation("action_started", action)


func on_action_active_started(action) -> void:
	super.on_action_active_started(action)
	_report_action_observation("action_active", action)


func on_action_completed(action) -> void:
	super.on_action_completed(action)
	var target_is_player: bool = (
		is_instance_valid(player)
		and player.is_in_group("player")
	)
	var target_survived: bool = (
		target_is_player
		and GameState.get_stat("health") > 0
	)
	var context: Dictionary = {
		"target_is_player": target_is_player,
		"target_survived": target_survived,
		"hit_registered": (
			bool(action_runner.hit_registered)
			if action_runner != null
			else false
		),
	}
	_report_action_observation("action_completed", action, context)
	if target_is_player and target_survived:
		_report_action_observation("action_survived", action, context)


func _finalize_tactical_decision(option) -> void:
	super._finalize_tactical_decision(option)
	var results_value: Variant = last_coordination_result.get("results", [])
	if not results_value is Array:
		return
	var results: Array = results_value as Array
	if results.is_empty() or actor == null:
		return
	CreatureObservationAccess.call_service(
		get_tree(),
		"report_squad_coordination",
		[
			actor,
			results,
			{
				"squad_id": get_tactical_squad_id(),
				"role_id": get_tactical_squad_role_id(),
				"action": (
					option.call("get_display_name")
					if option != null and option.has_method("get_display_name")
					else "none"
				),
			},
		]
	)


func _report_action_observation(
	event_type: String,
	action,
	context: Dictionary = {}
) -> void:
	if actor == null or action == null:
		return
	CreatureObservationAccess.call_service(
		get_tree(),
		"report_action_event",
		[actor, event_type, action, context]
	)
