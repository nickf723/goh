extends "res://scripts/levels/prototype_curling_puck_spell_trial.gd"
class_name PrototypeCurlingPuckSpellTrialReady

# The two marks share one centerline. Grace writes the ice route from the first
# mark, steps forward, switches to Boulder, and sends the heavy spell down the
# exact path rather than accidentally creating two parallel lanes.


func _ready() -> void:
	super._ready()
	var ice_mark: Node3D = get_node_or_null(
		"RimeRinkEnvironment/MomentumIceMark"
	) as Node3D
	var boulder_mark: Node3D = get_node_or_null(
		"RimeRinkEnvironment/MomentumBoulderMark"
	) as Node3D
	if ice_mark != null:
		ice_mark.position = Vector3(0.0, 0.06, 38.6)
	if boulder_mark != null:
		boulder_mark.position = Vector3(0.0, 0.06, 40.4)


func _evaluate_curl_route() -> void:
	if player == null:
		return
	for trail: Node in get_tree().get_nodes_in_group("curling_ice_trails"):
		if not _is_fresh_player_trail(trail, curl_serial_baseline):
			continue
		var serial: int = int(trail.get("cast_serial"))
		var curl_sign_value: float = float(
			trail.get_meta(
				"curling_puck_curl_sign",
				player.get_meta("curling_puck_last_curl_sign", 0.0)
			)
		)
		if curl_sign_value < 0.5:
			continue
		var positions: Array[Vector3] = _get_trail_positions(trail)
		if positions.is_empty():
			continue
		var all_marks_reached: bool = true
		for checkpoint: Vector3 in curl_checkpoints:
			if not _trail_reaches_checkpoint(positions, checkpoint):
				all_marks_reached = false
				break
		if not all_marks_reached:
			continue
		curl_success_serial = serial
		curl_completion_count += 1
		curl_gate.set_gate_open(
			true,
			false,
			{"reason": "curl_route_complete"}
		)
		_set_stage(TrialStage.FROZEN_CROSSING)
		curl_route_completed.emit(serial)
		_show_message(
			"The right-hand curl threads all three marks. The next route has no floor, so write one across the water."
		)
		call_deferred("_clear_curling_effects")
		return


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["momentum_marks_share_centerline"] = true
	data["curl_validation_source"] = "trail_metadata"
	return data
