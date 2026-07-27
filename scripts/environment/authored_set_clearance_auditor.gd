extends RefCounted
class_name AuthoredSetClearanceAuditor

const Composer = preload("res://scripts/environment/authored_set_composer.gd")


static func audit(root: Node) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var corridor_count: int = 0
	var wall_count: int = 0
	var opening_count: int = 0
	var stair_count: int = 0
	var module_count: int = 0

	if root == null:
		return {
			"passed": false,
			"errors": ["Authored set audit received a null root."],
			"warnings": warnings,
		}

	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child: Node in node.get_children():
			stack.append(child)
		var kind: String = str(node.get_meta("composer_kind", ""))
		match kind:
			"corridor":
				corridor_count += 1
				_audit_corridor(node, errors, warnings)
			"wall":
				wall_count += 1
				opening_count += _audit_wall(node, errors, warnings)
			"stairs":
				stair_count += 1
				_audit_stairs(node, errors, warnings)
			"module":
				module_count += 1

	return {
		"passed": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
		"corridors": corridor_count,
		"walls": wall_count,
		"openings": opening_count,
		"stairs": stair_count,
		"modules": module_count,
	}


static func _audit_corridor(node: Node, errors: Array[String], warnings: Array[String]) -> void:
	var traversal: String = str(node.get_meta("traversal", Composer.TRAVERSAL_LAND))
	var recommendation: Vector2 = Composer.get_recommended_clearance(traversal)
	var clear_width: float = float(node.get_meta("clear_width", 0.0))
	var clear_height: float = float(node.get_meta("clear_height", 0.0))
	var label: String = node.get_path().get_concatenated_names()
	if clear_width < recommendation.x - 0.001:
		errors.append(
			label
			+ " provides "
			+ str(snappedf(clear_width, 0.01))
			+ "m width for "
			+ traversal
			+ "; recommended minimum is "
			+ str(recommendation.x)
			+ "m."
		)
	if clear_height < recommendation.y - 0.001:
		errors.append(
			label
			+ " provides "
			+ str(snappedf(clear_height, 0.01))
			+ "m height for "
			+ traversal
			+ "; recommended minimum is "
			+ str(recommendation.y)
			+ "m."
		)
	if clear_width < recommendation.x + 0.5:
		warnings.append(label + " is technically valid but has little lateral camera margin.")


static func _audit_wall(node: Node, errors: Array[String], warnings: Array[String]) -> int:
	var raw_openings: Variant = node.get_meta("openings", [])
	if not raw_openings is Array:
		errors.append(node.get_path().get_concatenated_names() + " publishes invalid opening metadata.")
		return 0
	var count: int = 0
	for opening_variant: Variant in raw_openings as Array:
		if not opening_variant is Dictionary:
			errors.append(node.get_path().get_concatenated_names() + " contains a non-Dictionary opening.")
			continue
		count += 1
		var opening: Dictionary = opening_variant as Dictionary
		var traversal: String = str(opening.get("traversal", Composer.TRAVERSAL_LAND))
		var recommendation: Vector2 = Composer.get_recommended_clearance(traversal)
		var width: float = float(opening.get("width", 0.0))
		var height: float = float(opening.get("height", 0.0))
		var opening_id: String = str(opening.get("id", "opening"))
		var label: String = node.get_path().get_concatenated_names() + "/" + opening_id
		if width < recommendation.x - 0.001:
			errors.append(label + " is too narrow for " + traversal + " traversal: " + str(width) + "m.")
		if height < recommendation.y - 0.001:
			errors.append(label + " is too low for " + traversal + " traversal: " + str(height) + "m.")
		if absf(float(opening.get("center_offset", 0.0))) > float(node.get_meta("wall_length", 0.0)) * 0.5:
			warnings.append(label + " is centered outside the declared wall length.")
	return count


static func _audit_stairs(node: Node, errors: Array[String], warnings: Array[String]) -> void:
	var total_rise: float = float(node.get_meta("total_rise", 0.0))
	var total_run: float = float(node.get_meta("total_run", 0.0))
	var width: float = float(node.get_meta("width", 0.0))
	var label: String = node.get_path().get_concatenated_names()
	if total_run <= 0.0:
		errors.append(label + " has no horizontal stair run.")
		return
	var slope_degrees: float = rad_to_deg(atan2(total_rise, total_run))
	if slope_degrees > 34.0:
		errors.append(label + " exceeds the 34-degree walkable stair-ramp limit: " + str(snappedf(slope_degrees, 0.1)) + " degrees.")
	elif slope_degrees > 30.0:
		warnings.append(label + " is steep enough to deserve a close manual traversal test.")
	if width < 3.0:
		warnings.append(label + " is narrower than the preferred three-meter authored stair width.")
	if node.get_node_or_null("WalkRamp") == null:
		errors.append(label + " is missing its continuous WalkRamp collision.")
