extends Node
class_name TacticalNavigationAgent

@export_group("Identity")
@export var lane_id: String = ""
@export var personality_id: String = "balanced"
@export var require_route_anchor: bool = true

@export_group("Navigation Agent")
@export var navigation_agent_name: String = "TacticalNavigationAgent3D"
@export_flags_3d_navigation var navigation_layers: int = 1
@export_range(0.05, 3.0, 0.05) var path_desired_distance: float = 0.45
@export_range(0.05, 3.0, 0.05) var target_desired_distance: float = 0.65
@export_range(0.1, 10.0, 0.1) var path_max_distance: float = 2.5
@export_range(0.1, 10.0, 0.1) var agent_radius: float = 0.52
@export_range(0.2, 6.0, 0.1) var agent_height: float = 1.55
@export var simplify_path: bool = true
@export_range(0.0, 2.0, 0.05) var simplify_epsilon: float = 0.15

@export_group("Route Planning")
@export_range(0.1, 3.0, 0.05) var route_replan_interval: float = 0.55
@export_range(0.05, 3.0, 0.05) var destination_replan_distance: float = 0.45
@export_range(0.2, 3.0, 0.05) var hazard_sample_spacing: float = 0.7
@export_range(0.1, 4.0, 0.05) var waypoint_reach_distance: float = 0.75
@export_range(0.1, 5.0, 0.1) var endpoint_reach_tolerance: float = 1.4

@export_group("Local Steering")
@export_range(0.0, 4.0, 0.05) var separation_radius: float = 1.35
@export_range(0.0, 2.0, 0.05) var separation_strength: float = 0.35

@export_group("Stuck Recovery")
@export_range(0.1, 4.0, 0.05) var stuck_replan_seconds: float = 0.85
@export_range(0.001, 0.5, 0.005) var stuck_movement_threshold: float = 0.035

var actor: CharacterBody3D = null
var navigation_agent: NavigationAgent3D = null
var navigation_ready: bool = false
var has_destination: bool = false
var current_destination: Vector3 = Vector3.ZERO
var route_waypoints: Array[Vector3] = []
var current_waypoint_index: int = 0
var planned_path: PackedVector3Array = PackedVector3Array()
var chosen_route_id: String = "none"
var chosen_route_score: float = INF
var chosen_route_distance: float = 0.0
var chosen_hazard_cost: float = 0.0
var chosen_route_bias: float = 0.0
var route_replan_timer: float = 0.0
var last_actor_position: Vector3 = Vector3.ZERO
var stuck_timer: float = 0.0
var replan_count: int = 0
var last_route_summary: String = "unplanned"
var last_next_position: Vector3 = Vector3.ZERO
var last_move_direction: Vector3 = Vector3.ZERO


func _ready() -> void:
	add_to_group("tactical_navigation_components")
	add_to_group("debuggable")
	actor = get_parent() as CharacterBody3D
	resolve_navigation_agent()
	if actor != null:
		last_actor_position = actor.global_position
	call_deferred("synchronize_navigation")


func resolve_navigation_agent() -> void:
	if actor == null:
		return
	var existing: Node = actor.get_node_or_null(navigation_agent_name)
	if existing is NavigationAgent3D:
		navigation_agent = existing as NavigationAgent3D
	else:
		navigation_agent = NavigationAgent3D.new()
		navigation_agent.name = navigation_agent_name
		actor.add_child(navigation_agent)
	configure_navigation_agent()


func configure_navigation_agent() -> void:
	if navigation_agent == null:
		return
	navigation_agent.navigation_layers = navigation_layers
	navigation_agent.path_desired_distance = path_desired_distance
	navigation_agent.target_desired_distance = target_desired_distance
	navigation_agent.path_max_distance = path_max_distance
	navigation_agent.radius = agent_radius
	navigation_agent.height = agent_height
	navigation_agent.simplify_path = simplify_path
	navigation_agent.simplify_epsilon = simplify_epsilon
	navigation_agent.avoidance_enabled = false


func synchronize_navigation() -> void:
	await get_tree().physics_frame
	navigation_ready = true
	if has_destination:
		plan_route(true)


func set_personality(new_personality_id: String) -> void:
	personality_id = new_personality_id.to_lower().strip_edges()
	force_replan()


func request_destination(destination: Vector3, delta: float = 0.0) -> void:
	route_replan_timer = max(route_replan_timer - max(delta, 0.0), 0.0)
	var destination_changed: bool = (
		not has_destination
		or current_destination.distance_to(destination) >= destination_replan_distance
	)
	current_destination = destination
	has_destination = true
	if not navigation_ready:
		return
	if destination_changed:
		plan_route(true)
	elif route_replan_timer <= 0.0:
		plan_route(false)


func clear_destination() -> void:
	has_destination = false
	route_waypoints.clear()
	planned_path = PackedVector3Array()
	current_waypoint_index = 0
	chosen_route_id = "none"
	chosen_route_score = INF
	chosen_route_distance = 0.0
	chosen_hazard_cost = 0.0
	chosen_route_bias = 0.0
	last_route_summary = "cleared"
	last_move_direction = Vector3.ZERO
	stuck_timer = 0.0
	if navigation_agent != null and actor != null:
		navigation_agent.target_position = actor.global_position


func force_replan() -> void:
	route_replan_timer = 0.0
	if navigation_ready and has_destination:
		plan_route(true)


func plan_route(force_reset: bool = false) -> void:
	if actor == null or not navigation_ready or not has_destination:
		return
	var navigation_map: RID = actor.get_world_3d().get_navigation_map()
	if not navigation_map.is_valid():
		last_route_summary = "navigation map unavailable"
		return

	var candidates: Array[Dictionary] = []
	var anchors: Array[TacticalRouteAnchor] = collect_route_anchors()
	if anchors.is_empty() or not require_route_anchor:
		var direct_candidate: Dictionary = build_direct_candidate(navigation_map)
		if not direct_candidate.is_empty():
			candidates.append(direct_candidate)
	for anchor: TacticalRouteAnchor in anchors:
		var anchored_candidate: Dictionary = build_anchor_candidate(navigation_map, anchor)
		if not anchored_candidate.is_empty():
			candidates.append(anchored_candidate)

	route_replan_timer = max(route_replan_interval, 0.1)
	replan_count += 1
	if candidates.is_empty():
		last_route_summary = "no reachable route"
		return

	var best_candidate: Dictionary = {}
	var best_score: float = INF
	for candidate: Dictionary in candidates:
		var score: float = float(candidate.get("score", INF))
		if score < best_score:
			best_score = score
			best_candidate = candidate
	if best_candidate.is_empty():
		last_route_summary = "no scored route"
		return

	var new_route_id: String = str(best_candidate.get("route_id", "direct"))
	var route_changed: bool = new_route_id != chosen_route_id
	chosen_route_id = new_route_id
	chosen_route_score = best_score
	chosen_route_distance = float(best_candidate.get("distance", 0.0))
	chosen_hazard_cost = float(best_candidate.get("hazard_cost", 0.0))
	chosen_route_bias = float(best_candidate.get("bias", 0.0))
	planned_path = best_candidate.get("path", PackedVector3Array()) as PackedVector3Array
	last_route_summary = (
		chosen_route_id
		+ " score " + str(snapped(chosen_route_score, 0.1))
		+ " = " + str(snapped(chosen_route_distance, 0.1))
		+ "m + hazard " + str(snapped(chosen_hazard_cost, 0.1))
	)

	if not force_reset and not route_changed:
		if current_waypoint_index >= route_waypoints.size() - 1 and not route_waypoints.is_empty():
			route_waypoints[route_waypoints.size() - 1] = current_destination
			set_agent_target(current_destination)
		return

	route_waypoints.clear()
	var anchor_value: Variant = best_candidate.get("anchor")
	if anchor_value is TacticalRouteAnchor:
		route_waypoints.append((anchor_value as TacticalRouteAnchor).global_position)
	route_waypoints.append(current_destination)
	current_waypoint_index = 0
	set_agent_target(route_waypoints[0])
	stuck_timer = 0.0


func build_direct_candidate(navigation_map: RID) -> Dictionary:
	var path: PackedVector3Array = NavigationServer3D.map_get_path(
		navigation_map,
		actor.global_position,
		current_destination,
		true,
		navigation_layers
	)
	if not path_reaches(path, current_destination):
		return {}
	return score_candidate("direct", path, null, 0.0)


func build_anchor_candidate(navigation_map: RID, anchor: TacticalRouteAnchor) -> Dictionary:
	if anchor == null or not anchor.enabled:
		return {}
	var first_path: PackedVector3Array = NavigationServer3D.map_get_path(
		navigation_map,
		actor.global_position,
		anchor.global_position,
		true,
		navigation_layers
	)
	if not path_reaches(first_path, anchor.global_position):
		return {}
	var second_path: PackedVector3Array = NavigationServer3D.map_get_path(
		navigation_map,
		anchor.global_position,
		current_destination,
		true,
		navigation_layers
	)
	if not path_reaches(second_path, current_destination):
		return {}
	var merged_path: PackedVector3Array = first_path.duplicate()
	for index: int in range(1, second_path.size()):
		merged_path.append(second_path[index])
	return score_candidate(anchor.route_id, merged_path, anchor, anchor.route_bias)


func score_candidate(
	route_id: String,
	path: PackedVector3Array,
	anchor: TacticalRouteAnchor,
	bias: float
) -> Dictionary:
	var distance: float = get_path_distance(path)
	var hazard_cost: float = get_path_hazard_cost(path)
	return {
		"route_id": route_id,
		"path": path,
		"anchor": anchor,
		"distance": distance,
		"hazard_cost": hazard_cost,
		"bias": bias,
		"score": distance + hazard_cost + bias,
	}


func path_reaches(path: PackedVector3Array, destination: Vector3) -> bool:
	if path.is_empty():
		return false
	var endpoint: Vector3 = path[path.size() - 1]
	var horizontal_delta: Vector3 = destination - endpoint
	horizontal_delta.y = 0.0
	return horizontal_delta.length() <= endpoint_reach_tolerance


func get_path_distance(path: PackedVector3Array) -> float:
	var total: float = 0.0
	for index: int in range(1, path.size()):
		total += path[index - 1].distance_to(path[index])
	return total


func get_path_hazard_cost(path: PackedVector3Array) -> float:
	if path.size() < 2:
		return 0.0
	var hazards: Array[TacticalNavigationHazard] = collect_hazards()
	if hazards.is_empty():
		return 0.0
	var total_cost: float = 0.0
	var spacing: float = max(hazard_sample_spacing, 0.2)
	for path_index: int in range(1, path.size()):
		var start: Vector3 = path[path_index - 1]
		var finish: Vector3 = path[path_index]
		var segment_length: float = start.distance_to(finish)
		if segment_length <= 0.001:
			continue
		var sample_count: int = max(1, ceili(segment_length / spacing))
		var sample_length: float = segment_length / float(sample_count)
		for sample_index: int in range(sample_count):
			var weight: float = (float(sample_index) + 0.5) / float(sample_count)
			var sample_position: Vector3 = start.lerp(finish, weight)
			for hazard: TacticalNavigationHazard in hazards:
				var local_cost: float = hazard.get_cost_at_position(sample_position, personality_id)
				if hazard.impassable and local_cost > 0.0:
					return hazard.impassable_cost
				total_cost += local_cost * sample_length
	return total_cost


func collect_route_anchors() -> Array[TacticalRouteAnchor]:
	var results: Array[TacticalRouteAnchor] = []
	for candidate: Node in get_tree().get_nodes_in_group("tactical_route_anchors"):
		if candidate is TacticalRouteAnchor:
			var anchor: TacticalRouteAnchor = candidate as TacticalRouteAnchor
			if anchor.matches_lane(lane_id):
				results.append(anchor)
	return results


func collect_hazards() -> Array[TacticalNavigationHazard]:
	var results: Array[TacticalNavigationHazard] = []
	for candidate: Node in get_tree().get_nodes_in_group("tactical_navigation_hazards"):
		if candidate is TacticalNavigationHazard:
			var hazard: TacticalNavigationHazard = candidate as TacticalNavigationHazard
			if hazard.matches_lane(lane_id):
				results.append(hazard)
	return results


func set_agent_target(target: Vector3) -> void:
	if navigation_agent == null:
		return
	navigation_agent.target_position = target


func get_next_direction(destination: Vector3, delta: float) -> Vector3:
	request_destination(destination, delta)
	if actor == null or navigation_agent == null or not navigation_ready:
		return Vector3.ZERO
	advance_waypoint_if_reached()
	if route_waypoints.is_empty():
		return Vector3.ZERO
	if navigation_agent.is_navigation_finished():
		advance_waypoint_if_reached()
		if navigation_agent.is_navigation_finished():
			last_move_direction = Vector3.ZERO
			update_stuck_recovery(delta, Vector3.ZERO)
			return Vector3.ZERO

	last_next_position = navigation_agent.get_next_path_position()
	var direction: Vector3 = last_next_position - actor.global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		var current_target: Vector3 = route_waypoints[current_waypoint_index]
		direction = current_target - actor.global_position
		direction.y = 0.0
	if direction.length_squared() > 0.0001:
		direction = direction.normalized()
		direction = apply_local_separation(direction)
	last_move_direction = direction
	update_stuck_recovery(delta, direction)
	return direction


func advance_waypoint_if_reached() -> void:
	if actor == null or route_waypoints.is_empty():
		return
	var waypoint: Vector3 = route_waypoints[current_waypoint_index]
	var offset: Vector3 = waypoint - actor.global_position
	offset.y = 0.0
	if offset.length() > waypoint_reach_distance:
		return
	if current_waypoint_index < route_waypoints.size() - 1:
		current_waypoint_index += 1
		set_agent_target(route_waypoints[current_waypoint_index])


func apply_local_separation(direction: Vector3) -> Vector3:
	if actor == null or separation_radius <= 0.0 or separation_strength <= 0.0:
		return direction
	var separation: Vector3 = Vector3.ZERO
	var radius_squared: float = separation_radius * separation_radius
	for candidate: Node in get_tree().get_nodes_in_group("enemy"):
		if candidate == actor or not candidate is Node3D:
			continue
		var other: Node3D = candidate as Node3D
		var away: Vector3 = actor.global_position - other.global_position
		away.y = 0.0
		var distance_squared: float = away.length_squared()
		if distance_squared <= 0.0001 or distance_squared >= radius_squared:
			continue
		var distance: float = sqrt(distance_squared)
		separation += away.normalized() * (1.0 - distance / separation_radius)
	if separation.length_squared() <= 0.0001:
		return direction
	var combined: Vector3 = direction + separation * separation_strength
	return combined.normalized() if combined.length_squared() > 0.0001 else direction


func update_stuck_recovery(delta: float, desired_direction: Vector3) -> void:
	if actor == null:
		return
	var movement: float = actor.global_position.distance_to(last_actor_position)
	last_actor_position = actor.global_position
	if desired_direction.length_squared() <= 0.01 or movement >= stuck_movement_threshold:
		stuck_timer = 0.0
		return
	stuck_timer += max(delta, 0.0)
	if stuck_timer >= stuck_replan_seconds:
		stuck_timer = 0.0
		plan_route(true)


func is_destination_reached(arrival_distance: float = 0.75) -> bool:
	if actor == null or not has_destination:
		return false
	var offset: Vector3 = current_destination - actor.global_position
	offset.y = 0.0
	return offset.length() <= arrival_distance


func get_current_navigation_path() -> PackedVector3Array:
	if navigation_agent == null:
		return planned_path
	var live_path: PackedVector3Array = navigation_agent.get_current_navigation_path()
	return live_path if not live_path.is_empty() else planned_path


func get_debug_data() -> Dictionary:
	return {
		"tactical_navigation": true,
		"lane": lane_id,
		"personality": personality_id,
		"ready": navigation_ready,
		"route": chosen_route_id,
		"score": snapped(chosen_route_score, 0.1) if chosen_route_score < INF else "inf",
		"distance": snapped(chosen_route_distance, 0.1),
		"hazard_cost": snapped(chosen_hazard_cost, 0.1),
		"bias": snapped(chosen_route_bias, 0.1),
		"waypoint": current_waypoint_index,
		"waypoint_count": route_waypoints.size(),
		"destination": current_destination,
		"next_position": last_next_position,
		"direction": last_move_direction,
		"stuck": snapped(stuck_timer, 0.1),
		"replans": replan_count,
		"summary": last_route_summary,
	}
