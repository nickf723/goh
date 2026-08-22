extends "res://scripts/animals/bonded_animal_actor.gd"
class_name NavigationBondedAnimalActor

signal navigation_state_changed(debug_data: Dictionary)
signal rescue_state_changed(rescued: bool, injured: bool)
signal navigation_recovered(recovery_count: int, position: Vector3)
signal companion_command_changed(command_data: Dictionary)
signal companion_command_completed(command_id: String, completion_count: int)

const COMMAND_NONE: String = "none"
const COMMAND_FOLLOW: String = "follow"
const COMMAND_STAY: String = "stay"
const COMMAND_COME_HERE: String = "come_here"
const COMMAND_MOVE_TO: String = "move_to"

@export_group("Navigation")
@export var navigation_enabled: bool = true
@export_range(0.1, 3.0, 0.05) var path_refresh_seconds: float = 0.35
@export_range(0.1, 3.0, 0.05) var path_desired_distance: float = 0.45
@export_range(0.5, 5.0, 0.05) var companion_stop_distance: float = 2.35
@export_range(3.0, 40.0, 0.5) var separation_recovery_distance: float = 19.0
@export_range(0.5, 10.0, 0.1) var stuck_repath_seconds: float = 1.2
@export_range(1.0, 15.0, 0.1) var stuck_recovery_seconds: float = 4.0

@export_group("Command Authority")
@export_range(0.35, 3.0, 0.05) var stay_anchor_radius: float = 0.85
@export_range(0.35, 3.0, 0.05) var destination_completion_radius: float = 0.9
@export_range(0.1, 1.0, 0.05) var command_fear_suspend_threshold: float = 0.68

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

var command_id: String = COMMAND_NONE
var previous_command_id: String = COMMAND_NONE
var command_anchor: Vector3 = Vector3.ZERO
var has_command_anchor: bool = false
var command_destination: Vector3 = Vector3.ZERO
var has_command_destination: bool = false
var command_suspended: bool = false
var command_suspend_reason: String = ""
var last_completed_command_id: String = ""
var command_completion_count: int = 0
var command_sequence: int = 0


func _ready() -> void:
	super._ready()
	_build_navigation_agent()
	last_progress_position = global_position
	if movement_locked:
		velocity = Vector3.ZERO
	_apply_command_authority(true)


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
	_apply_command_authority(true)
	_emit_navigation_state()


func set_movement_locked(value: bool) -> void:
	movement_locked = value
	if movement_locked:
		_halt_horizontal_motion("trapped" if not rescued else "command_stay")
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


func attempt_bond() -> Dictionary:
	var result: Dictionary = super.attempt_bond()
	if bool(result.get("ok", false)):
		issue_follow_command(false)
		persist_named_state(true)
	return result


func toggle_follow() -> Dictionary:
	if not bonded:
		return {"ok": false, "error": "animal is not bonded"}
	if command_id == COMMAND_FOLLOW:
		return issue_stay_command(global_position)
	return issue_follow_command()


func issue_follow_command(save_now: bool = true) -> Dictionary:
	var error: String = _command_availability_error()
	if error != "":
		return {"ok": false, "error": error}
	previous_command_id = COMMAND_FOLLOW
	command_id = COMMAND_FOLLOW
	follow_enabled = true
	has_command_anchor = false
	has_command_destination = false
	command_suspended = false
	command_suspend_reason = ""
	last_completed_command_id = ""
	command_sequence += 1
	_halt_horizontal_motion("command_follow")
	var grace: Node3D = _get_grace_target()
	if grace != null:
		request_navigation_target(grace.global_position, true)
	_finish_command_issue(save_now)
	return _command_result(true)


func issue_stay_command(anchor: Vector3 = Vector3.INF, save_now: bool = true) -> Dictionary:
	var error: String = _command_availability_error()
	if error != "":
		return {"ok": false, "error": error}
	previous_command_id = COMMAND_STAY
	command_id = COMMAND_STAY
	follow_enabled = false
	command_anchor = global_position if anchor == Vector3.INF else anchor
	has_command_anchor = true
	has_command_destination = false
	command_suspended = false
	command_suspend_reason = ""
	last_completed_command_id = ""
	command_sequence += 1
	_halt_horizontal_motion("command_stay")
	request_navigation_target(command_anchor, true)
	_finish_command_issue(save_now)
	return _command_result(true)


func issue_come_here_command(save_now: bool = true) -> Dictionary:
	var error: String = _command_availability_error()
	if error != "":
		return {"ok": false, "error": error}
	var grace: Node3D = _get_grace_target()
	if grace == null:
		return {"ok": false, "error": "Grace unavailable"}
	previous_command_id = COMMAND_FOLLOW if command_id == COMMAND_FOLLOW else COMMAND_STAY
	command_id = COMMAND_COME_HERE
	command_destination = grace.global_position
	has_command_destination = true
	command_suspended = false
	command_suspend_reason = ""
	last_completed_command_id = ""
	command_sequence += 1
	_halt_horizontal_motion("command_come_here")
	request_navigation_target(command_destination, true)
	_finish_command_issue(save_now)
	return _command_result(true)


func issue_move_to_command(destination: Vector3, save_now: bool = true) -> Dictionary:
	var error: String = _command_availability_error()
	if error != "":
		return {"ok": false, "error": error}
	previous_command_id = COMMAND_STAY
	command_id = COMMAND_MOVE_TO
	follow_enabled = false
	command_destination = destination
	has_command_destination = true
	command_suspended = false
	command_suspend_reason = ""
	last_completed_command_id = ""
	command_sequence += 1
	_halt_horizontal_motion("command_move_to")
	request_navigation_target(command_destination, true)
	_finish_command_issue(save_now)
	return _command_result(true)


func refresh_command_authority() -> void:
	_update_command_suspension(true)
	_apply_command_authority(true)


func get_companion_command_data() -> Dictionary:
	return {
		"command_id": command_id,
		"previous_command_id": previous_command_id,
		"has_anchor": has_command_anchor,
		"anchor": command_anchor,
		"has_destination": has_command_destination,
		"destination": command_destination,
		"suspended": command_suspended,
		"suspend_reason": command_suspend_reason,
		"last_completed_command_id": last_completed_command_id,
		"completion_count": command_completion_count,
		"sequence": command_sequence,
	}


func get_bond_data() -> Dictionary:
	var data: Dictionary = super.get_bond_data()
	data["command"] = get_companion_command_data()
	return data


func persist_named_state(save_now: bool = false) -> Dictionary:
	if relationship == null or persistent_animal_id == "" or not is_inside_tree():
		return {}
	if bond_store == null:
		bond_store = AnimalBondStore.get_or_create(get_tree())
	if bond_store == null:
		return {}
	return bond_store.set_record(
		persistent_animal_id,
		{
			"animal_name": animal_name,
			"species_id": species_id,
			"personality_profile_id": personality_profile_id,
			"relationship": relationship.to_dictionary(),
			"bonded": bonded,
			"follow_enabled": follow_enabled,
			"help_events": help_events,
			"harm_events": harm_events,
			"companion_command": _get_command_persistence_data(),
		},
		save_now
	)


func reload_persistent_state() -> bool:
	var loaded: bool = super.reload_persistent_state()
	if bond_store == null and is_inside_tree():
		bond_store = AnimalBondStore.get_or_create(get_tree())
	var record: Dictionary = (
		bond_store.get_record(persistent_animal_id)
		if bond_store != null and persistent_animal_id != ""
		else {}
	)
	if loaded:
		_restore_command_record(record.get("companion_command", {}) as Dictionary)
	elif bonded:
		command_id = COMMAND_FOLLOW if follow_enabled else COMMAND_STAY
		if command_id == COMMAND_STAY:
			command_anchor = global_position
			has_command_anchor = true
	else:
		_reset_command_state()
	_apply_command_authority(true)
	return loaded


func clear_persistent_bond() -> bool:
	var removed: bool = super.clear_persistent_bond()
	_reset_command_state()
	_emit_command_state()
	return removed


func reset_actor() -> void:
	super.reset_actor()
	if not bonded:
		_reset_command_state()
	_apply_command_authority(true)


func get_mob_decision_context() -> Dictionary:
	var context: Dictionary = super.get_mob_decision_context()
	if movement_locked:
		context["move_score_modifiers"] = {"idle": 20.0}
		var locked_tags: Array = context.get("context_tags", [])
		locked_tags.append("movement_locked")
		locked_tags.append("trapped")
		context["context_tags"] = locked_tags
		return context
	_update_command_suspension(false)
	if _has_authoritative_command() and not command_suspended:
		var score_modifiers: Dictionary = context.get("move_score_modifiers", {}).duplicate(true)
		score_modifiers["idle"] = float(score_modifiers.get("idle", 0.0)) + 40.0
		context["move_score_modifiers"] = score_modifiers
		var tags: Array = context.get("context_tags", [])
		tags.append("companion_command")
		tags.append("command_" + command_id)
		context["context_tags"] = tags
	elif command_suspended:
		var suspended_tags: Array = context.get("context_tags", [])
		suspended_tags.append("command_suspended")
		suspended_tags.append("command_suspended_" + command_suspend_reason)
		context["context_tags"] = suspended_tags
	return context


func _resolve_execution_action(move_id: String) -> String:
	if movement_locked:
		return "trapped"
	_update_command_suspension(false)
	if _has_authoritative_command() and not command_suspended:
		match command_id:
			COMMAND_FOLLOW:
				return "command_follow"
			COMMAND_STAY:
				return "command_stay"
			COMMAND_COME_HERE:
				return "command_come_here"
			COMMAND_MOVE_TO:
				return "command_move_to"
	return super._resolve_execution_action(move_id)


func _execute_current_action(delta: float) -> void:
	if movement_locked:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 6.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * 6.0 * delta)
		current_action_id = "trapped" if not rescued else "command_stay"
		current_move_id = "idle"
		_update_stuck_tracking(delta, false, Vector3.ZERO, false)
		return
	_update_command_suspension(false)
	if _has_authoritative_command() and not command_suspended:
		_execute_companion_command(delta)
		return
	super._execute_current_action(delta)
	_update_stuck_tracking(delta, false, Vector3.ZERO, false)


func _execute_companion_command(delta: float) -> void:
	var direction: Vector3 = Vector3.ZERO
	var facing_target: Vector3 = global_position
	var wants_path: bool = false
	var recovery_target: Vector3 = Vector3.ZERO
	var allow_grace_recovery: bool = false
	var speed_multiplier: float = 1.0
	match command_id:
		COMMAND_FOLLOW:
			current_action_id = "command_follow"
			var grace: Node3D = _get_grace_target()
			if grace == null:
				_halt_horizontal_motion("command_follow")
				return
			facing_target = grace.global_position
			var grace_distance: float = global_position.distance_to(grace.global_position)
			if grace_distance > companion_stop_distance + 0.65:
				direction = _navigation_direction(grace.global_position, delta)
				wants_path = true
				recovery_target = grace.global_position
				allow_grace_recovery = true
			elif grace_distance < 1.45:
				direction = _flat_direction(global_position - grace.global_position)
		COMMAND_STAY:
			current_action_id = "command_stay"
			if not has_command_anchor:
				command_anchor = global_position
				has_command_anchor = true
			facing_target = _get_grace_target().global_position if _get_grace_target() != null else command_anchor
			var anchor_distance: float = global_position.distance_to(command_anchor)
			if anchor_distance > stay_anchor_radius:
				current_action_id = "command_return_to_stay"
				direction = _navigation_direction(command_anchor, delta)
				wants_path = true
		COMMAND_COME_HERE:
			current_action_id = "command_come_here"
			var grace_target: Node3D = _get_grace_target()
			if grace_target == null:
				_halt_horizontal_motion("command_come_here")
				return
			command_destination = grace_target.global_position
			has_command_destination = true
			facing_target = command_destination
			var come_distance: float = global_position.distance_to(command_destination)
			if come_distance > companion_stop_distance:
				direction = _navigation_direction(command_destination, delta)
				wants_path = true
				recovery_target = command_destination
				allow_grace_recovery = true
			else:
				_complete_transient_command(COMMAND_COME_HERE)
				return
		COMMAND_MOVE_TO:
			current_action_id = "command_move_to"
			if not has_command_destination:
				_complete_transient_command(COMMAND_MOVE_TO)
				return
			facing_target = command_destination
			var destination_distance: float = global_position.distance_to(command_destination)
			if destination_distance > destination_completion_radius:
				direction = _navigation_direction(command_destination, delta)
				wants_path = true
			else:
				_complete_transient_command(COMMAND_MOVE_TO)
				return
	var injury_multiplier: float = lerpf(1.0, 0.62, injury_ratio if injured else 0.0)
	var target_velocity: Vector3 = direction * move_speed * speed_multiplier * injury_multiplier
	velocity.x = move_toward(velocity.x, target_velocity.x, move_speed * 5.5 * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, move_speed * 5.5 * delta)
	var facing: Vector3 = direction if direction.length_squared() > 0.001 else _flat_direction(facing_target - global_position)
	if facing.length_squared() > 0.001:
		var target_yaw: float = atan2(-facing.x, -facing.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, clampf(delta * turn_speed, 0.0, 1.0))
	_update_stuck_tracking(delta, wants_path, recovery_target, allow_grace_recovery)


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
	var target_data: Dictionary = _get_active_command_target()
	if bool(target_data.get("valid", false)):
		request_navigation_target(target_data.get("position", global_position) as Vector3, true)


func force_separation_recovery() -> bool:
	if command_id not in [COMMAND_FOLLOW, COMMAND_COME_HERE]:
		return false
	var grace: Node3D = _get_grace_target()
	if grace == null:
		return false
	_recover_near_grace(grace)
	return true


func _update_stuck_tracking(
	delta: float,
	wants_move: bool,
	recovery_target: Vector3,
	allow_grace_recovery: bool
) -> void:
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
	if allow_grace_recovery and wants_move:
		var separation: float = global_position.distance_to(recovery_target)
		if separation >= separation_recovery_distance or stuck_seconds >= stuck_recovery_seconds:
			var grace: Node3D = _get_grace_target()
			if grace != null:
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
	var data: Dictionary = {
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
	data.merge(get_companion_command_data(), true)
	return data


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["navigation"] = get_navigation_debug_data()
	data["companion_command"] = get_companion_command_data()
	return data


func _command_availability_error() -> String:
	if not bonded:
		return "animal is not bonded"
	if movement_locked or not rescued:
		return "animal cannot move yet"
	return ""


func _has_authoritative_command() -> bool:
	return bonded and command_id in [
		COMMAND_FOLLOW,
		COMMAND_STAY,
		COMMAND_COME_HERE,
		COMMAND_MOVE_TO,
	]


func _update_command_suspension(force_emit: bool) -> void:
	var next_reason: String = ""
	if _has_authoritative_command():
		if _is_grace_threatening():
			next_reason = "grace_threatening"
		elif get_drive("fear") >= command_fear_suspend_threshold or relationship_label in ["afraid", "hostile"]:
			next_reason = "fear"
	var next_suspended: bool = next_reason != ""
	if next_suspended == command_suspended and next_reason == command_suspend_reason and not force_emit:
		return
	command_suspended = next_suspended
	command_suspend_reason = next_reason
	if command_suspended:
		_interrupt_current_action("command_suspended_" + command_suspend_reason, true)
		current_action_id = "idle"
		current_move_id = "idle"
		if brain != null:
			brain.clear_memory()
			force_decision(false)
	else:
		_apply_command_authority(true)
	_emit_command_state()


func _apply_command_authority(force_repath: bool) -> void:
	if not _has_authoritative_command() or command_suspended or movement_locked:
		return
	match command_id:
		COMMAND_FOLLOW:
			current_action_id = "command_follow"
			var grace: Node3D = _get_grace_target()
			if force_repath and grace != null:
				request_navigation_target(grace.global_position, true)
		COMMAND_STAY:
			if not has_command_anchor:
				command_anchor = global_position
				has_command_anchor = true
			_halt_horizontal_motion("command_stay")
			if force_repath:
				request_navigation_target(command_anchor, true)
		COMMAND_COME_HERE:
			current_action_id = "command_come_here"
			var come_target: Node3D = _get_grace_target()
			if force_repath and come_target != null:
				request_navigation_target(come_target.global_position, true)
		COMMAND_MOVE_TO:
			current_action_id = "command_move_to"
			if force_repath and has_command_destination:
				request_navigation_target(command_destination, true)
	current_move_id = "idle"
	if brain != null:
		brain.clear_memory()
		decision_time_remaining = 0.0


func _halt_horizontal_motion(action_id: String) -> void:
	_interrupt_current_action("authoritative_" + action_id, true)
	velocity.x = 0.0
	velocity.z = 0.0
	current_action_id = action_id
	current_move_id = "idle"
	action_time_remaining = 0.0
	last_requested_target = Vector3.INF
	path_refresh_remaining = 0.0
	if navigation_agent != null:
		navigation_agent.set_velocity_forced(Vector3.ZERO)
		navigation_agent.target_position = global_position


func _complete_transient_command(completed_id: String) -> void:
	last_completed_command_id = completed_id
	command_completion_count += 1
	companion_command_completed.emit(completed_id, command_completion_count)
	if completed_id == COMMAND_COME_HERE and previous_command_id == COMMAND_FOLLOW:
		issue_follow_command(false)
		last_completed_command_id = completed_id
	else:
		issue_stay_command(global_position, false)
		last_completed_command_id = completed_id
	persist_named_state(true)
	_emit_command_state()


func _finish_command_issue(save_now: bool) -> void:
	if brain != null:
		brain.clear_memory()
		decision_time_remaining = 0.0
	persist_named_state(save_now)
	bond_changed.emit(bonded, follow_enabled)
	_emit_command_state()


func _command_result(ok: bool) -> Dictionary:
	var result: Dictionary = get_companion_command_data()
	result["ok"] = ok
	result["bonded"] = bonded
	result["follow_enabled"] = follow_enabled
	return result


func _get_active_command_target() -> Dictionary:
	match command_id:
		COMMAND_FOLLOW, COMMAND_COME_HERE:
			var grace: Node3D = _get_grace_target()
			if grace != null:
				return {"valid": true, "position": grace.global_position}
		COMMAND_STAY:
			if has_command_anchor:
				return {"valid": true, "position": command_anchor}
		COMMAND_MOVE_TO:
			if has_command_destination:
				return {"valid": true, "position": command_destination}
	return {"valid": false, "position": global_position}


func _get_command_persistence_data() -> Dictionary:
	return {
		"command_id": command_id,
		"previous_command_id": previous_command_id,
		"has_anchor": has_command_anchor,
		"anchor": _vector_to_dictionary(command_anchor),
		"has_destination": has_command_destination,
		"destination": _vector_to_dictionary(command_destination),
		"last_completed_command_id": last_completed_command_id,
		"completion_count": command_completion_count,
		"sequence": command_sequence,
	}


func _restore_command_record(command: Dictionary) -> void:
	if not bonded:
		_reset_command_state()
		return
	if command.is_empty():
		command_id = COMMAND_FOLLOW if follow_enabled else COMMAND_STAY
		previous_command_id = command_id
		if command_id == COMMAND_STAY:
			command_anchor = global_position
			has_command_anchor = true
		return
	command_id = str(command.get("command_id", COMMAND_FOLLOW if follow_enabled else COMMAND_STAY))
	if command_id not in [COMMAND_FOLLOW, COMMAND_STAY, COMMAND_COME_HERE, COMMAND_MOVE_TO]:
		command_id = COMMAND_FOLLOW if follow_enabled else COMMAND_STAY
	previous_command_id = str(command.get("previous_command_id", command_id))
	has_command_anchor = bool(command.get("has_anchor", false))
	command_anchor = _dictionary_to_vector(command.get("anchor", {}) as Dictionary)
	has_command_destination = bool(command.get("has_destination", false))
	command_destination = _dictionary_to_vector(command.get("destination", {}) as Dictionary)
	last_completed_command_id = str(command.get("last_completed_command_id", ""))
	command_completion_count = maxi(int(command.get("completion_count", 0)), 0)
	command_sequence = maxi(int(command.get("sequence", 0)), 0)
	follow_enabled = command_id == COMMAND_FOLLOW or (
		command_id == COMMAND_COME_HERE and previous_command_id == COMMAND_FOLLOW
	)
	command_suspended = false
	command_suspend_reason = ""


func _reset_command_state() -> void:
	command_id = COMMAND_NONE
	previous_command_id = COMMAND_NONE
	command_anchor = Vector3.ZERO
	has_command_anchor = false
	command_destination = Vector3.ZERO
	has_command_destination = false
	command_suspended = false
	command_suspend_reason = ""
	last_completed_command_id = ""
	command_completion_count = 0
	command_sequence = 0


func _vector_to_dictionary(value: Vector3) -> Dictionary:
	return {"x": value.x, "y": value.y, "z": value.z}


func _dictionary_to_vector(value: Dictionary) -> Vector3:
	return Vector3(
		float(value.get("x", 0.0)),
		float(value.get("y", 0.0)),
		float(value.get("z", 0.0))
	)


func _emit_command_state() -> void:
	companion_command_changed.emit(get_companion_command_data())
	_emit_navigation_state()


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
