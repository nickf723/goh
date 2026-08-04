extends "res://scripts/animals/bonded_animal_actor.gd"
class_name NavigationBondedAnimalActor

signal navigation_state_changed(debug_data: Dictionary)
signal rescue_state_changed(rescued: bool, injured: bool)
signal navigation_recovered(recovery_count: int, position: Vector3)

@export_group("Navigation")
@export var navigation_enabled: bool = true
@export_range(0.1, 3.0, 0.05) var path_refresh_seconds: float = 0.35
@export_range(0.1, 3.0, 0.05) var path_desired_distance: float = 0.45
@export_range(0.5, 5.0, 0.05) var companion_stop_distance: float = 2.35
@export_range(3.0, 40.0, 0.5) var separation_recovery_distance: float = 19.0
@export_range(0.5, 10.0, 0.1) var stuck_repath_seconds: float = 1.2
@export_range(1.0, 15.0, 0.1) var stuck_recovery_seconds: float = 4.0

@export_group("Encounter State")
@export var movement_locked: bool = false
@export var rescued: bool = false
@export var injured: bool = true
@export_range(0.0, 1.0, 0.05) var injury_ratio: float = 0.65

var navigation_agent: NavigationAgent3D
var navigation_ready: bool = false
var navigation_target: Vector3 = Vector3.ZERO
var last_requested_target: Vector3 = Vector3.INF
var last_path_position: Vector3 = Vector3.ZERO
var path_refresh_remaining: float = 0.0
var progress_sample_remaining: float = 0.35
var last_progress_position: Vector3 = Vector3.ZERO
var stuck_seconds: float = 0.0
var repath_issued_for_stuck: bool = false
var repath_count: int = 0
var recovery_count: int = 0
var navigation_query_count: int = 0
var last_path_point_count: int = 0
var last_target_reachable: bool = false
var last_navigation_finished: bool = true
var last_damage_amount: int = 0


func _ready() -> void:
	super._ready()
	_build_navigation_agent()
	last_progress_position = global_position
	if movement_locked:
		velocity = Vector3.ZERO


func _build_navigation_agent() -> void:
	navigation_agent = NavigationAgent3D.new()
	navigation_agent.name = "NavigationAgent3D"
	navigation_agent.path_desired_distance = path_desired_distance
	navigation_agent.target_desired_distance = companion_stop_distance
	navigation_agent.path_max_distance = 2.4
	navigation_agent.radius = 0.46
	navigation_agent.height = 1.25
	navigation_agent.avoidance_enabled = false
	add_child(navigation_agent)


func set_navigation_ready(value: bool) -> void:
	navigation_ready = value
	path_refresh_remaining = 0.0
	if navigation_agent != null:
		navigation_agent.target_position = global_position
	_emit_navigation_state()


func set_movement_locked(value: bool) -> void:
	movement_locked = value
	if movement_locked:
		velocity.x = 0.0
		velocity.z = 0.0
		current_action_id = "trapped" if not rescued else "stay"
		current_move_id = "idle"
	if brain != null:
		brain.clear_memory()
		decision_time_remaining = 0.0
	_emit_navigation_state()


func set_rescued(value: bool, report_help: bool = true) -> Dictionary:
	var changed: bool = rescued != value
	rescued = value
	set_movement_locked(not rescued)
	var result: Dictionary = {"ok": true, "rescued": rescued}
	if rescued and changed and report_help:
		result = report_grace_event("rescue")
		result["rescued"] = true
	rescue_state_changed.emit(rescued, injured)
	return result


func set_injured(value: bool, new_ratio: float = -1.0) -> void:
	injured = value
	if new_ratio >= 0.0:
		injury_ratio = clampf(new_ratio, 0.0, 1.0)
	elif not injured:
		injury_ratio = 0.0
	rescue_state_changed.emit(rescued, injured)


func receive_healing_from_grace(amount: int = 1) -> Dictionary:
	var trust_before: float = relationship.trust if relationship != null else 0.0
	injury_ratio = maxf(injury_ratio - float(maxi(amount, 1)) * 0.42, 0.0)
	injured = injury_ratio > 0.05
	var result: Dictionary = report_grace_event("heal", clampf(float(maxi(amount, 1)), 0.5, 2.0))
	result["injured"] = injured
	result["injury_ratio"] = injury_ratio
	result["trust_before"] = trust_before
	result["trust_after"] = relationship.trust if relationship != null else trust_before
	rescue_state_changed.emit(rescued, injured)
	return result


func receive_damage_payload(payload: Variant) -> Dictionary:
	var amount: int = maxi(roundi(_payload_number(payload, "amount", 1.0)), 1)
	var source_name: String = _payload_text(payload, "source_name", "Grace")
	last_damage_amount = amount
	injured = true
	injury_ratio = clampf(injury_ratio + float(amount) * 0.16, 0.0, 1.0)
	var trust_before: float = relationship.trust if relationship != null else 0.0
	var event_result: Dictionary = report_grace_event(
		"attack",
		clampf(float(amount) * 0.55, 0.5, 2.0)
	)
	rescue_state_changed.emit(rescued, injured)
	return {
		"message": source_name + " strikes " + animal_name + ". The animal remembers the harm.",
		"objective": "Lower the weapon and rebuild trust.",
		"damage_dealt": amount,
		"trust_before": trust_before,
		"trust_after": relationship.trust if relationship != null else trust_before,
		"relationship_label": relationship_label,
		"event_result": event_result,
	}


func receive_weapon_impact(_payload: Variant, direction: Vector3, _attack: Variant = null) -> void:
	var planar: Vector3 = direction
	planar.y = 0.0
	if planar.length_squared() > 0.001:
		velocity += planar.normalized() * 1.1


func get_mob_decision_context() -> Dictionary:
	var context: Dictionary = super.get_mob_decision_context()
	if movement_locked:
		context["move_score_modifiers"] = {"idle": 20.0}
		var locked_tags: Array = context.get("context_tags", [])
		locked_tags.append("movement_locked")
		locked_tags.append("trapped")
		context["context_tags"] = locked_tags
		return context
	var grace: Node3D = _get_grace_target()
	if bonded and follow_enabled and grace != null:
		var grace_distance: float = global_position.distance_to(grace.global_position)
		if not _grace_is_current_threat(grace_distance):
			var score_modifiers: Dictionary = context.get("move_score_modifiers", {}).duplicate(true)
			score_modifiers["idle"] = float(score_modifiers.get("idle", 0.0)) + 6.0
			context["move_score_modifiers"] = score_modifiers
			var tags: Array = context.get("context_tags", [])
			if not tags.has("navigation_follow"):
				tags.append("navigation_follow")
			context["context_tags"] = tags
	return context


func _resolve_execution_action(move_id: String) -> String:
	if movement_locked:
		return "trapped"
	if move_id == "idle" and bonded and follow_enabled:
		var grace: Node3D = _get_grace_target()
		if grace != null and not _grace_is_current_threat(global_position.distance_to(grace.global_position)):
			return "follow_grace"
	return super._resolve_execution_action(move_id)


func _execute_current_action(delta: float) -> void:
	if movement_locked:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 6.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * 6.0 * delta)
		current_action_id = "trapped" if not rescued else "stay"
		current_move_id = "idle"
		_update_stuck_tracking(delta, false, null)
		return
	if not ["follow_grace", "approach_grace", "watch_grace"].has(current_action_id):
		super._execute_current_action(delta)
		_update_stuck_tracking(delta, false, null)
		return
	var grace: Node3D = _get_grace_target()
	if grace == null:
		current_action_id = "idle"
		current_move_id = "idle"
		_update_stuck_tracking(delta, false, null)
		return
	var distance: float = global_position.distance_to(grace.global_position)
	var direction: Vector3 = Vector3.ZERO
	var wants_forward_path: bool = false
	var speed_multiplier: float = 0.78
	match current_action_id:
		"follow_grace":
			speed_multiplier = 1.0
			if distance > companion_stop_distance + 0.65:
				direction = _navigation_direction(grace.global_position, delta)
				wants_forward_path = true
			elif distance < 1.45:
				direction = _flat_direction(global_position - grace.global_position)
		"approach_grace":
			var preferred: float = maxf(relationship.get_personal_space() + 0.55, 2.1)
			if distance > preferred:
				direction = _navigation_direction(grace.global_position, delta)
				wants_forward_path = true
			elif distance < relationship.get_personal_space():
				direction = _flat_direction(global_position - grace.global_position)
		"watch_grace":
			var comfort: float = relationship.get_comfort_distance()
			if distance < comfort:
				direction = _flat_direction(global_position - grace.global_position)
	var injury_multiplier: float = lerpf(1.0, 0.62, injury_ratio if injured else 0.0)
	var target_velocity: Vector3 = direction * move_speed * speed_multiplier * injury_multiplier
	velocity.x = move_toward(velocity.x, target_velocity.x, move_speed * 4.5 * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, move_speed * 4.5 * delta)
	var facing: Vector3 = direction if direction.length_squared() > 0.001 else _flat_direction(grace.global_position - global_position)
	if facing.length_squared() > 0.001:
		var target_yaw: float = atan2(-facing.x, -facing.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, clampf(delta * turn_speed, 0.0, 1.0))
	_update_stuck_tracking(delta, wants_forward_path, grace)
	if action_time_remaining <= 0.0:
		current_action_id = "idle"
		current_move_id = "idle"


func _navigation_direction(target_position: Vector3, delta: float) -> Vector3:
	if not navigation_enabled or not navigation_ready or navigation_agent == null:
		return _direction_to(target_position)
	path_refresh_remaining -= delta
	if (
		path_refresh_remaining <= 0.0
		or last_requested_target == Vector3.INF
		or last_requested_target.distance_to(target_position) > 0.65
	):
		request_navigation_target(target_position)
	var next_position: Vector3 = navigation_agent.get_next_path_position()
	navigation_query_count += 1
	last_path_position = next_position
	last_navigation_finished = navigation_agent.is_navigation_finished()
	last_target_reachable = navigation_agent.is_target_reachable()
	last_path_point_count = navigation_agent.get_current_navigation_path().size()
	if next_position.distance_squared_to(global_position) <= 0.0025:
		return _direction_to(target_position)
	return _direction_to(next_position)


func request_navigation_target(target_position: Vector3, force: bool = false) -> void:
	if navigation_agent == null:
		return
	if not force and last_requested_target != Vector3.INF and last_requested_target.distance_to(target_position) <= 0.1:
		path_refresh_remaining = path_refresh_seconds
		return
	navigation_target = target_position
	last_requested_target = target_position
	navigation_agent.target_position = target_position
	path_refresh_remaining = path_refresh_seconds
	repath_count += 1
	_emit_navigation_state()


func force_navigation_repath() -> void:
	last_requested_target = Vector3.INF
	path_refresh_remaining = 0.0
	var grace: Node3D = _get_grace_target()
	if grace != null:
		request_navigation_target(grace.global_position, true)


func force_separation_recovery() -> bool:
	var grace: Node3D = _get_grace_target()
	if grace == null:
		return false
	_recover_near_grace(grace)
	return true


func _update_stuck_tracking(delta: float, wants_move: bool, grace: Node3D) -> void:
	progress_sample_remaining -= delta
	if progress_sample_remaining > 0.0:
		return
	var sample_seconds: float = 0.35
	progress_sample_remaining = sample_seconds
	var moved: float = global_position.distance_to(last_progress_position)
	last_progress_position = global_position
	if wants_move and moved < 0.07:
		stuck_seconds += sample_seconds
	else:
		stuck_seconds = 0.0
		repath_issued_for_stuck = false
	if wants_move and stuck_seconds >= stuck_repath_seconds and not repath_issued_for_stuck:
		repath_issued_for_stuck = true
		force_navigation_repath()
	if grace != null:
		var separation: float = global_position.distance_to(grace.global_position)
		if separation >= separation_recovery_distance or stuck_seconds >= stuck_recovery_seconds:
			_recover_near_grace(grace)
	_emit_navigation_state()


func _recover_near_grace(grace: Node3D) -> void:
	var away: Vector3 = _flat_direction(global_position - grace.global_position)
	if away.length_squared() <= 0.001:
		away = Vector3.BACK
	var candidate: Vector3 = grace.global_position + away * companion_stop_distance
	if navigation_agent != null:
		var map_rid: RID = navigation_agent.get_navigation_map()
		if map_rid.is_valid():
			candidate = NavigationServer3D.map_get_closest_point(map_rid, candidate)
	global_position = candidate + Vector3.UP * 0.12
	velocity = Vector3.ZERO
	if navigation_agent != null:
		navigation_agent.set_velocity_forced(Vector3.ZERO)
	last_progress_position = global_position
	stuck_seconds = 0.0
	repath_issued_for_stuck = false
	last_requested_target = Vector3.INF
	path_refresh_remaining = 0.0
	recovery_count += 1
	navigation_recovered.emit(recovery_count, global_position)
	_emit_navigation_state()


func get_navigation_debug_data() -> Dictionary:
	return {
		"navigation_ready": navigation_ready,
		"navigation_enabled": navigation_enabled,
		"movement_locked": movement_locked,
		"rescued": rescued,
		"injured": injured,
		"injury_ratio": injury_ratio,
		"target": navigation_target,
		"next_path_position": last_path_position,
		"path_point_count": last_path_point_count,
		"target_reachable": last_target_reachable,
		"navigation_finished": last_navigation_finished,
		"navigation_queries": navigation_query_count,
		"repath_count": repath_count,
		"recovery_count": recovery_count,
		"stuck_seconds": stuck_seconds,
		"last_damage_amount": last_damage_amount,
	}


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["navigation"] = get_navigation_debug_data()
	return data


func _emit_navigation_state() -> void:
	navigation_state_changed.emit(get_navigation_debug_data())


func _payload_number(payload: Variant, key: String, fallback: float) -> float:
	if payload is Dictionary:
		return float((payload as Dictionary).get(key, fallback))
	if payload is Object:
		var value: Variant = (payload as Object).get(key)
		if value != null:
			return float(value)
	return fallback


func _payload_text(payload: Variant, key: String, fallback: String) -> String:
	if payload is Dictionary:
		return str((payload as Dictionary).get(key, fallback))
	if payload is Object:
		var value: Variant = (payload as Object).get(key)
		if value != null:
			return str(value)
	return fallback
