extends RefCounted
class_name PlayableSpaceAuditor


static func audit_scene(root: Node) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	if root == null or root.get_tree() == null:
		errors.append("Scene root is unavailable.")
		return _report(errors, warnings)

	var players: Array[Node] = _nodes_in_group_under(root, "player")
	if players.is_empty():
		errors.append("No player actor is present.")
	else:
		for player: Node in players:
			if player.get_node_or_null("RecoveryController") == null:
				errors.append("Player %s has no RecoveryController." % player.name)

	var spaces: Array[Node] = _nodes_in_group_under(root, "playable_space")
	if spaces.is_empty():
		warnings.append("No explicit PlayableSpace3D is declared; only player fallback recovery is available.")
	else:
		for space: Node in spaces:
			if not space.has_method("has_recovery_anchor") or not bool(space.call("has_recovery_anchor")):
				errors.append("Playable space %s has no recovery anchor." % space.name)
			var bounds_size: Variant = space.get("bounds_size")
			if bounds_size is Vector3:
				var size := bounds_size as Vector3
				if size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0:
					errors.append("Playable space %s has invalid bounds." % space.name)

	var guidance_targets: Array[Node] = _nodes_in_group_under(root, "quest_guidance_target")
	for interactable: Node in _nodes_in_group_under(root, "story_interactable"):
		if interactable.get_node_or_null("CollisionShape3D") == null:
			errors.append("Story interactable %s has no CollisionShape3D." % interactable.name)
		if bool(interactable.get_meta("quality_requires_guidance", false)):
			var has_guidance: bool = false
			for guidance: Node in guidance_targets:
				if interactable == guidance or interactable.is_ancestor_of(guidance):
					has_guidance = true
					break
			if not has_guidance:
				errors.append("Required interactable %s has no guidance target." % interactable.name)

	var exits: Array[Node] = _nodes_in_group_under(root, "swimming_exit_anchor")
	for volume: Node in _nodes_in_group_under(root, "swimming_water_volume"):
		var exit_count: int = 0
		for exit_anchor: Node in exits:
			if exit_anchor.has_method("supports_volume") and bool(exit_anchor.call("supports_volume", volume)):
				exit_count += 1
		if exit_count <= 0:
			errors.append("Swimming volume %s has no registered exit anchor." % volume.name)
		elif exit_count == 1:
			warnings.append("Swimming volume %s has only one registered exit." % volume.name)

	if not spaces.is_empty() and _nodes_in_group_under(root, "playable_recovery_volume").is_empty():
		warnings.append("Playable space has no explicit recovery volume; minimum-height recovery remains active.")

	return _report(errors, warnings)


static func _nodes_in_group_under(root: Node, group_name: String) -> Array[Node]:
	var result: Array[Node] = []
	if root == null or root.get_tree() == null:
		return result
	for candidate: Node in root.get_tree().get_nodes_in_group(group_name):
		if candidate == root or root.is_ancestor_of(candidate):
			result.append(candidate)
	return result


static func _report(errors: Array[String], warnings: Array[String]) -> Dictionary:
	return {
		"passed": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
		"error_count": errors.size(),
		"warning_count": warnings.size(),
	}


static func print_report(report: Dictionary, label: String = "PLAYABLE SPACE AUDIT") -> void:
	for warning: String in report.get("warnings", []):
		print(label + " WARNING: " + warning)
	for error: String in report.get("errors", []):
		push_error(label + ": " + error)
	print(
		"%s: %s (%d errors, %d warnings)" % [
			label,
			"PASS" if bool(report.get("passed", false)) else "FAIL",
			int(report.get("error_count", 0)),
			int(report.get("warning_count", 0)),
		]
	)
