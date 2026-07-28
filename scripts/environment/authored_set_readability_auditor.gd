extends RefCounted
class_name AuthoredSetReadabilityAuditor

const DEFAULT_PROFILE: Resource = preload("res://data/player/grace_spatial_profile.tres")


static func audit(scene_root: Node, plan: Dictionary, spatial_profile: Resource = DEFAULT_PROFILE) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var route_reports: Array[Dictionary] = []
	var zone_reports: Array[Dictionary] = []
	if scene_root == null:
		return {
			"passed": false,
			"errors": ["Spatial readability audit received a null scene root."],
			"warnings": warnings,
			"routes": route_reports,
			"zones": zone_reports,
		}

	var ignored_piece_ids: Array[String] = _string_array(plan.get("ignore_piece_ids", []))
	var candidates: Array[Dictionary] = _collect_candidates(scene_root, ignored_piece_ids)

	for route: Dictionary in _dictionary_rows(plan.get("routes", [])):
		var report: Dictionary = _audit_route(route, candidates, spatial_profile)
		route_reports.append(report)
		for error: String in report.get("errors", []):
			errors.append(error)
		for warning: String in report.get("warnings", []):
			warnings.append(warning)

	for zone: Dictionary in _dictionary_rows(plan.get("zones", [])):
		var report: Dictionary = _audit_zone(zone, candidates, spatial_profile)
		zone_reports.append(report)
		for error: String in report.get("errors", []):
			errors.append(error)
		for warning: String in report.get("warnings", []):
			warnings.append(warning)

	return {
		"passed": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
		"candidate_count": candidates.size(),
		"routes": route_reports,
		"zones": zone_reports,
		"profile_id": str(_profile_value(spatial_profile, "profile_id", "grace_default_v1")),
	}


static func _audit_route(route: Dictionary, candidates: Array[Dictionary], spatial_profile: Resource) -> Dictionary:
	var route_id: String = str(route.get("id", "route"))
	var points: Array[Vector3] = _vector3_rows(route.get("points", []))
	var errors: Array[String] = []
	var warnings: Array[String] = []
	if points.size() < 2:
		errors.append(route_id + " requires at least two route points.")
		return {"id": route_id, "errors": errors, "warnings": warnings}

	var clear_radius: float = maxf(
		float(route.get("clear_radius", _profile_number(spatial_profile, "primary_route_radius", 1.35))),
		0.1
	)
	var camera_radius: float = maxf(
		float(route.get("camera_radius", _profile_number(spatial_profile, "camera_route_radius", 2.55))),
		clear_radius
	)
	var max_physical: int = maxi(int(route.get("max_physical_intrusions", 0)), 0)
	var max_visible: int = maxi(int(route.get("max_visible_modules", 3)), 0)
	var physical_intrusions: Array[String] = []
	var visual_intrusions: Array[String] = []

	for candidate: Dictionary in candidates:
		var position_value: Vector3 = candidate.get("position", Vector3.ZERO)
		var footprint_radius: float = float(candidate.get("footprint_radius", 0.5))
		var distance_to_route: float = _distance_to_polyline_xz(position_value, points)
		if bool(candidate.get("active_collision", false)) and distance_to_route - footprint_radius < clear_radius:
			physical_intrusions.append(str(candidate.get("label", "module")))
		if distance_to_route - footprint_radius < camera_radius:
			visual_intrusions.append(str(candidate.get("label", "module")))

	if physical_intrusions.size() > max_physical:
		errors.append(
			route_id
			+ " has "
			+ str(physical_intrusions.size())
			+ " physical intrusions inside its protected travel lane: "
			+ ", ".join(physical_intrusions)
		)
	if visual_intrusions.size() > max_visible:
		warnings.append(
			route_id
			+ " has "
			+ str(visual_intrusions.size())
			+ " tall or freestanding modules inside its camera envelope; budget is "
			+ str(max_visible)
			+ "."
		)

	return {
		"id": route_id,
		"clear_radius": clear_radius,
		"camera_radius": camera_radius,
		"physical_intrusions": physical_intrusions,
		"visible_modules": visual_intrusions,
		"errors": errors,
		"warnings": warnings,
	}


static func _audit_zone(zone: Dictionary, candidates: Array[Dictionary], spatial_profile: Resource) -> Dictionary:
	var zone_id: String = str(zone.get("id", "zone"))
	var kind: String = str(zone.get("kind", "interaction")).to_lower().strip_edges()
	var center: Vector3 = _vector3_from(zone.get("center", Vector3.ZERO), Vector3.ZERO)
	var radius: float = maxf(
		float(zone.get("radius", _profile_zone_radius(spatial_profile, kind))),
		0.1
	)
	var max_physical: int = maxi(int(zone.get("max_physical_props", 0)), 0)
	var max_visible: int = maxi(int(zone.get("max_visible_modules", 3)), 0)
	var physical_props: Array[String] = []
	var visible_modules: Array[String] = []
	var errors: Array[String] = []
	var warnings: Array[String] = []

	for candidate: Dictionary in candidates:
		var position_value: Vector3 = candidate.get("position", Vector3.ZERO)
		var horizontal_distance: float = Vector2(position_value.x - center.x, position_value.z - center.z).length()
		var footprint_radius: float = float(candidate.get("footprint_radius", 0.5))
		if horizontal_distance - footprint_radius > radius:
			continue
		visible_modules.append(str(candidate.get("label", "module")))
		if bool(candidate.get("active_collision", false)):
			physical_props.append(str(candidate.get("label", "module")))

	if physical_props.size() > max_physical:
		errors.append(
			zone_id
			+ " has "
			+ str(physical_props.size())
			+ " physical modules inside its "
			+ kind
			+ " approach zone: "
			+ ", ".join(physical_props)
		)
	if visible_modules.size() > max_visible:
		warnings.append(
			zone_id
			+ " contains "
			+ str(visible_modules.size())
			+ " visible modules; its declared density budget is "
			+ str(max_visible)
			+ "."
		)

	return {
		"id": zone_id,
		"kind": kind,
		"center": center,
		"radius": radius,
		"physical_props": physical_props,
		"visible_modules": visible_modules,
		"errors": errors,
		"warnings": warnings,
	}


static func _collect_candidates(scene_root: Node, ignored_piece_ids: Array[String]) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var stack: Array[Node] = [scene_root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child: Node in node.get_children():
			stack.append(child)
		if not node is Node3D:
			continue
		var node_3d: Node3D = node as Node3D
		if not node_3d.is_visible_in_tree():
			continue
		if not _is_candidate(node):
			continue
		var piece_id: String = _piece_id(node)
		if ignored_piece_ids.has(piece_id):
			continue
		candidates.append({
			"node": node,
			"label": str(node.name),
			"piece_id": piece_id,
			"category": _piece_category(node),
			"position": node_3d.global_position,
			"footprint_radius": _footprint_radius(node_3d),
			"active_collision": _has_active_collision(node),
		})
	return candidates


static func _is_candidate(node: Node) -> bool:
	return (
		node.is_in_group("modular_environment_piece")
		or node.has_meta("benchmark_owner")
		or str(node.get_meta("composer_kind", "")) == "module"
	)


static func _piece_id(node: Node) -> String:
	for key: String in ["layout_piece_id", "piece_id"]:
		if node.has_meta(key):
			return str(node.get_meta(key, ""))
	if _has_property(node, "piece_id"):
		return str(node.get("piece_id"))
	return str(node.name)


static func _piece_category(node: Node) -> String:
	if node.has_meta("piece_category"):
		return str(node.get_meta("piece_category", "unknown"))
	if _has_property(node, "category"):
		return str(node.get("category"))
	return "unknown"


static func _footprint_radius(node: Node3D) -> float:
	var footprint := Vector3(1.0, 1.0, 1.0)
	if _has_property(node, "footprint"):
		var raw_footprint: Variant = node.get("footprint")
		if raw_footprint is Vector3:
			footprint = raw_footprint as Vector3
	var scale_xz: float = maxf(absf(node.global_basis.get_scale().x), absf(node.global_basis.get_scale().z))
	return maxf(maxf(footprint.x, footprint.z) * scale_xz * 0.5, 0.15)


static func _has_active_collision(node: Node) -> bool:
	if node is CollisionObject3D and (node as CollisionObject3D).collision_layer != 0:
		for child: Node in node.get_children():
			if child is CollisionShape3D and not (child as CollisionShape3D).disabled:
				return true
	for child: Node in node.get_children():
		if _has_active_collision(child):
			return true
	return false


static func _distance_to_polyline_xz(point: Vector3, points: Array[Vector3]) -> float:
	var best: float = INF
	for index: int in range(points.size() - 1):
		best = minf(best, _distance_to_segment_xz(point, points[index], points[index + 1]))
	return best


static func _distance_to_segment_xz(point: Vector3, start: Vector3, finish: Vector3) -> float:
	var point_2d := Vector2(point.x, point.z)
	var start_2d := Vector2(start.x, start.z)
	var finish_2d := Vector2(finish.x, finish.z)
	var segment: Vector2 = finish_2d - start_2d
	if segment.length_squared() <= 0.0001:
		return point_2d.distance_to(start_2d)
	var progress: float = clampf((point_2d - start_2d).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return point_2d.distance_to(start_2d + segment * progress)


static func _profile_zone_radius(profile: Resource, kind: String) -> float:
	match kind:
		"camera", "camera_route":
			return _profile_number(profile, "camera_route_radius", 2.55)
		"landmark":
			return _profile_number(profile, "landmark_radius", 2.4)
		"combat":
			return _profile_number(profile, "combat_radius", 5.5)
		"interaction":
			return _profile_number(profile, "interaction_radius", 1.8)
		_:
			return _profile_number(profile, "primary_route_radius", 1.35)


static func _profile_number(profile: Resource, property_name: String, fallback: float) -> float:
	var value: Variant = _profile_value(profile, property_name, fallback)
	return fallback if value == null else float(value)


static func _profile_value(profile: Resource, property_name: String, fallback: Variant) -> Variant:
	if profile == null:
		return fallback
	if _has_property(profile, property_name):
		return profile.get(property_name)
	return fallback


static func _dictionary_rows(value: Variant) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if not value is Array:
		return rows
	for row_variant: Variant in value as Array:
		if row_variant is Dictionary:
			rows.append((row_variant as Dictionary).duplicate(true))
	return rows


static func _vector3_rows(value: Variant) -> Array[Vector3]:
	var rows: Array[Vector3] = []
	if not value is Array:
		return rows
	for row_variant: Variant in value as Array:
		rows.append(_vector3_from(row_variant, Vector3.ZERO))
	return rows


static func _vector3_from(value: Variant, fallback: Vector3) -> Vector3:
	if value is Vector3:
		return value as Vector3
	if value is Array:
		var values: Array = value as Array
		if values.size() >= 3:
			return Vector3(float(values[0]), float(values[1]), float(values[2]))
	if value is Dictionary:
		var values_dict: Dictionary = value as Dictionary
		return Vector3(
			float(values_dict.get("x", fallback.x)),
			float(values_dict.get("y", fallback.y)),
			float(values_dict.get("z", fallback.z))
		)
	return fallback


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return result
	for item: Variant in value as Array:
		result.append(str(item))
	return result


static func _has_property(object: Object, property_name: String) -> bool:
	for property_variant: Variant in object.get_property_list():
		if property_variant is Dictionary and str((property_variant as Dictionary).get("name", "")) == property_name:
			return true
	return false
