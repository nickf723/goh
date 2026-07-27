extends "res://scripts/player/player_swimming_controller.gd"


func _try_water_exit_handoff() -> bool:
	var anchor: Node = _find_best_exit_anchor()
	if anchor != null and anchor.has_method("try_exit"):
		if bool(anchor.call("try_exit", actor)):
			water_exit_handoff = false
			_set_state("ANCHOR EXIT")
			return true
	return super._try_water_exit_handoff()


func _find_best_exit_anchor() -> Node:
	if actor == null or get_tree() == null:
		return null
	var best: Node = null
	var best_distance: float = INF
	for candidate: Node in get_tree().get_nodes_in_group("swimming_exit_anchor"):
		if not candidate.has_method("supports_any_volume") or not candidate.has_method("is_available_for"):
			continue
		if not bool(candidate.call("supports_any_volume", active_volumes)):
			continue
		if not bool(candidate.call("is_available_for", actor)):
			continue
		var candidate_3d: Node3D = candidate as Node3D
		if candidate_3d == null:
			continue
		var distance: float = actor.global_position.distance_to(candidate_3d.global_position)
		if distance < best_distance:
			best = candidate
			best_distance = distance
	return best


func get_available_exit_count() -> int:
	if actor == null or get_tree() == null:
		return 0
	var count: int = 0
	for candidate: Node in get_tree().get_nodes_in_group("swimming_exit_anchor"):
		if candidate.has_method("supports_any_volume") and bool(candidate.call("supports_any_volume", active_volumes)):
			count += 1
	return count
