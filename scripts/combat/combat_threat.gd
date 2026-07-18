extends RefCounted
class_name CombatThreat

var threat_id: String = "threat"
var display_name: String = "Threat"
var source_ref: WeakRef
var source_position_snapshot: Vector3 = Vector3.ZERO
var origin_height: float = 0.0
var direction: Vector3 = Vector3.FORWARD
var announced_at_msec: int = 0
var impact_delay: float = 0.0
var active_duration: float = 0.0
var lifetime_padding: float = 0.18
var range: float = 0.0
var cone_angle_degrees: float = 90.0
var center_forward_offset: float = 0.0
var close_range_radius: float = 0.0
var severity: float = 1.0
var tags: Array[String] = []
var cancelled: bool = false


func configure(
	resolved_id: String,
	resolved_name: String,
	source: Node3D,
	resolved_origin_height: float,
	resolved_direction: Vector3,
	resolved_impact_delay: float,
	resolved_active_duration: float,
	resolved_range: float,
	resolved_cone_angle_degrees: float,
	resolved_center_forward_offset: float,
	resolved_close_range_radius: float,
	resolved_severity: float,
	resolved_tags: Array[String]
) -> CombatThreat:
	threat_id = resolved_id
	display_name = resolved_name
	source_ref = weakref(source) if source != null else null
	source_position_snapshot = source.global_position if source != null else Vector3.ZERO
	origin_height = resolved_origin_height
	direction = normalize_direction(resolved_direction)
	announced_at_msec = Time.get_ticks_msec()
	impact_delay = max(resolved_impact_delay, 0.0)
	active_duration = max(resolved_active_duration, 0.0)
	range = max(resolved_range, 0.0)
	cone_angle_degrees = clampf(resolved_cone_angle_degrees, 1.0, 360.0)
	center_forward_offset = resolved_center_forward_offset
	close_range_radius = max(resolved_close_range_radius, 0.0)
	severity = max(resolved_severity, 0.0)
	tags = resolved_tags.duplicate()
	return self


func get_source() -> Node3D:
	if source_ref == null:
		return null

	var source: Variant = source_ref.get_ref()
	return source as Node3D if source is Node3D else null


func get_origin() -> Vector3:
	var source: Node3D = get_source()
	var base_position: Vector3 = source.global_position if source != null else source_position_snapshot
	return base_position + Vector3.UP * origin_height


func get_center() -> Vector3:
	return get_origin() + direction * center_forward_offset


func get_age_seconds() -> float:
	return max(float(Time.get_ticks_msec() - announced_at_msec) / 1000.0, 0.0)


func get_time_until_impact() -> float:
	return impact_delay - get_age_seconds()


func get_time_until_end() -> float:
	return impact_delay + active_duration + lifetime_padding - get_age_seconds()


func is_expired() -> bool:
	return cancelled or get_time_until_end() <= 0.0


func contains_point(point: Vector3, geometry_padding: float = 0.0) -> bool:
	if is_expired():
		return false

	var origin: Vector3 = get_origin()
	var to_point_from_origin: Vector3 = point - origin
	to_point_from_origin.y = 0.0

	if to_point_from_origin.length() <= close_range_radius + max(geometry_padding, 0.0):
		return true

	var center: Vector3 = get_center()
	var to_point_from_center: Vector3 = point - center
	to_point_from_center.y = 0.0
	if to_point_from_center.length() > range + max(geometry_padding, 0.0):
		return false

	if to_point_from_origin.length() <= 0.01:
		return true

	var minimum_dot: float = cos(deg_to_rad(cone_angle_degrees * 0.5))
	return direction.dot(to_point_from_origin.normalized()) >= minimum_dot


func has_tag(tag: String) -> bool:
	return tags.has(tag.to_lower().strip_edges())


func matches_all_tags(required_tags: Array[String]) -> bool:
	for required_tag: String in required_tags:
		if required_tag == "":
			continue
		if not has_tag(required_tag):
			return false
	return true


func matches_any_tag(candidate_tags: Array[String]) -> bool:
	if candidate_tags.is_empty():
		return true

	for candidate_tag: String in candidate_tags:
		if has_tag(candidate_tag):
			return true
	return false


func get_debug_summary() -> String:
	return (
		display_name
		+ " impact="
		+ str(snapped(get_time_until_impact(), 0.01))
		+ "s tags="
		+ ",".join(tags)
	)


func normalize_direction(value: Vector3) -> Vector3:
	var flattened: Vector3 = value
	flattened.y = 0.0
	if flattened.length() <= 0.01:
		return Vector3.FORWARD
	return flattened.normalized()
