extends "res://scripts/enemies/enemy_tactical_action_brain.gd"


const BLACKBOARD_PATH: String = "res://scripts/ai/tactical_blackboard.gd"
const CLAIM_REGISTRY_PATH: String = "res://scripts/ai/reaction_claim_registry.gd"
const LANE_REGISTRY_PATH: String = "res://scripts/ai/engagement_lane_registry.gd"
const ACTION_CANDIDATE_PATH: String = "res://scripts/ai/tactical_action_candidate.gd"
const DECISION_RECORDER_PATH: String = "res://scripts/ai/tactical_decision_recorder.gd"
const ROLE_ALLOCATOR_PATH: String = "res://scripts/ai/squad_role_allocator.gd"

@export_group("Squad Coordination")
@export var enable_squad_coordination: bool = true
@export var tactical_squad_id: String = "auto"
@export_range(0.1, 3.0, 0.05) var reaction_reservation_seconds: float = 0.9
@export_range(0.1, 2.0, 0.05) var lane_reservation_seconds: float = 0.55
@export_range(0.1, 2.0, 0.05) var cover_request_seconds: float = 0.7

@export_group("Squad Role")
@export var tactical_squad_role_id: String = "auto"
@export var auto_assign_squad_role: bool = true

@export_group("Decision Replay")
@export_range(4, 128, 1) var decision_history_capacity: int = 48
@export var record_tactical_decisions: bool = true

var last_coordination_result: Dictionary = {}
var coordination_frame: int = -1
var decision_recorder: RefCounted = null
var squad_role_assignment: Dictionary = {}
var service_scripts: Dictionary = {}


func _ready() -> void:
	super._ready()
	_ensure_squad_role_assignment()
	_ensure_decision_recorder()
	add_to_group("tactical_decision_source")


func _begin_tactical_evaluation() -> void:
	coordination_frame = -1
	_ensure_squad_role_assignment()
	super._begin_tactical_evaluation()


func _ensure_tactical_snapshot() -> void:
	super._ensure_tactical_snapshot()
	var assignment: Dictionary = _ensure_squad_role_assignment()
	tactical_snapshot["squad_role_id"] = str(assignment.get("role_id", "generalist"))
	tactical_snapshot["squad_role_name"] = str(assignment.get("role_name", "Generalist"))
	var role_context: Dictionary = _get_role_context()
	for role_key: Variant in role_context.keys():
		tactical_snapshot[role_key] = role_context[role_key]
	if not enable_squad_coordination:
		return
	var frame: int = Engine.get_process_frames()
	if coordination_frame == frame:
		return
	coordination_frame = frame
	var context: Dictionary = _get_coordination_context(
		_get_owner_id(),
		_get_target_id()
	)
	for key: Variant in context.keys():
		tactical_snapshot[key] = context[key]


func _finalize_tactical_decision(option) -> void:
	super._finalize_tactical_decision(option)
	last_tactical_decision["squad_role_id"] = get_tactical_squad_role_id()
	last_tactical_decision["squad_role_name"] = get_tactical_squad_role_name()
	last_tactical_decision["squad_role_assignment"] = squad_role_assignment.duplicate(true)
	if not enable_squad_coordination:
		last_coordination_result = {
			"enabled": false,
			"squad_role": squad_role_assignment.duplicate(true),
		}
		_record_tactical_frame("decision")
		return
	if option == null:
		_release_coordination("no selected action", false)
		last_coordination_result = {
			"enabled": true,
			"reserved": false,
			"reason": "No selected action",
			"squad_role": squad_role_assignment.duplicate(true),
		}
		_record_tactical_frame("decision")
		return
	_reserve_selected_option(option)
	_record_tactical_frame("decision")


func _reserve_selected_option(option) -> void:
	var owner_id: int = _get_owner_id()
	var owner_name: String = actor.name if actor != null else name
	var target_id: int = _get_target_id()
	var selected: Dictionary = _dictionary(last_tactical_decision.get("selected", {}))
	var opportunities: Array[Dictionary] = _dictionary_array(selected.get("opportunities", []))
	var results: Array[Dictionary] = []
	var emergency: Dictionary = _first_opportunity(opportunities, "emergency_override")
	if not emergency.is_empty():
		_append_result(results, _call_service(
			BLACKBOARD_PATH,
			"reserve_emergency",
			[
				get_tactical_squad_id(),
				owner_id,
				owner_name,
				str(emergency.get("emergency_id", "emergency")),
				0.5,
				100.0,
				{"action": _option_name(option), "squad_role": get_tactical_squad_role_id()},
			]
		))
	else:
		var payoff: Dictionary = _first_opportunity(opportunities, "reaction_payoff")
		if not payoff.is_empty():
			_append_result(results, _call_service(
				CLAIM_REGISTRY_PATH,
				"reserve_payoff",
				[
					get_tactical_squad_id(), owner_id, owner_name,
					str(payoff.get("reaction_id", "")), target_id,
					reaction_reservation_seconds,
					float(selected.get("total_score", 0.0)),
					{"action": _option_name(option), "squad_role": get_tactical_squad_role_id()},
				]
			))
		var setup: Dictionary = _first_opportunity(opportunities, "reaction_setup")
		if not setup.is_empty():
			_append_result(results, _call_service(
				CLAIM_REGISTRY_PATH,
				"reserve_setup",
				[
					get_tactical_squad_id(), owner_id, owner_name,
					str(setup.get("reaction_id", "")), target_id,
					reaction_reservation_seconds,
					float(selected.get("total_score", 0.0)),
					{"action": _option_name(option), "squad_role": get_tactical_squad_role_id()},
				]
			))

	var candidate: Variant = _call_service(
		ACTION_CANDIDATE_PATH,
		"from_enemy_option",
		[option]
	)
	if _candidate_uses_melee_lane(candidate):
		_append_result(results, _call_service(
			LANE_REGISTRY_PATH,
			"reserve_lane",
			[
				get_tactical_squad_id(), owner_id, owner_name, "melee", target_id,
				lane_reservation_seconds,
				float(selected.get("total_score", 0.0)),
				{"action": _option_name(option), "squad_role": get_tactical_squad_role_id()},
			]
		))
	if _candidate_requests_cover(candidate):
		var cover_tags: Array[String] = ["cover_requested"]
		_append_result(results, _call_service(
			BLACKBOARD_PATH,
			"broadcast_intent",
			[
				get_tactical_squad_id(), owner_id, owner_name, "cover_request",
				cover_tags, target_id, cover_request_seconds,
				{"action": _option_name(option), "squad_role": get_tactical_squad_role_id()},
			]
		))
	last_coordination_result = {
		"enabled": true,
		"squad_id": get_tactical_squad_id(),
		"owner_id": owner_id,
		"target_id": target_id,
		"action": _option_name(option),
		"squad_role": squad_role_assignment.duplicate(true),
		"results": results,
		"blackboard": _get_coordination_context(0, target_id),
		"role_context": _get_role_context(),
	}


func get_tactical_squad_id() -> String:
	var configured: String = tactical_squad_id.strip_edges().to_lower()
	if configured not in ["", "auto"]:
		return configured
	if actor != null and actor.has_meta("tactical_squad_id"):
		var metadata_value: String = str(actor.get_meta("tactical_squad_id"))
		if metadata_value.strip_edges() != "":
			return metadata_value.strip_edges().to_lower()
	if actor != null and actor.get_parent() != null:
		return "enemy_encounter_" + str(actor.get_parent().get_instance_id())
	return "enemy_squad"


func get_tactical_squad_role_id() -> String:
	return str(_ensure_squad_role_assignment().get("role_id", "generalist"))


func get_tactical_squad_role_name() -> String:
	return str(_ensure_squad_role_assignment().get("role_name", "Generalist"))


func get_tactical_squad_role_assignment() -> Dictionary:
	return _ensure_squad_role_assignment().duplicate(true)


func refresh_tactical_squad_role() -> Dictionary:
	_call_service(ROLE_ALLOCATOR_PATH, "release_owner", [_get_owner_id(), get_tactical_squad_id()])
	squad_role_assignment.clear()
	tactical_frame = -1
	coordination_frame = -1
	return _ensure_squad_role_assignment()


func _ensure_squad_role_assignment() -> Dictionary:
	if not squad_role_assignment.is_empty():
		return squad_role_assignment
	var configured_role: String = tactical_squad_role_id
	if not auto_assign_squad_role and configured_role.strip_edges().to_lower() == "auto":
		configured_role = "generalist"
	var value: Variant = _call_service(
		ROLE_ALLOCATOR_PATH,
		"assign_from_enemy_options",
		[
			get_tactical_squad_id(),
			_get_owner_id(),
			actor.name if actor != null else name,
			configured_role,
			action_options,
		]
	)
	squad_role_assignment = _dictionary(value)
	if squad_role_assignment.is_empty():
		squad_role_assignment = {
			"role_id": "generalist",
			"role_name": "Generalist",
			"reason": "Role service unavailable",
		}
	return squad_role_assignment


func on_action_completed(action) -> void:
	super.on_action_completed(action)
	_release_coordination("action completed")


func interrupt_current_action(reason: String) -> bool:
	var interrupted: bool = super.interrupt_current_action(reason)
	if interrupted:
		_release_coordination("interrupted: " + reason)
	return interrupted


func cancel_current_action(reason: String) -> void:
	super.cancel_current_action(reason)
	_release_coordination("cancelled: " + reason)


func finish_action_state() -> void:
	super.finish_action_state()
	_release_coordination("action state finished")


func _exit_tree() -> void:
	_release_coordination("actor removed")
	_call_service(ROLE_ALLOCATOR_PATH, "release_owner", [_get_owner_id(), get_tactical_squad_id()])
	squad_role_assignment.clear()


func _release_coordination(reason: String, record_release: bool = true) -> void:
	var released_value: Variant = _call_service(
		BLACKBOARD_PATH,
		"release_owner",
		[_get_owner_id(), reason, get_tactical_squad_id()]
	)
	last_coordination_result = {
		"enabled": enable_squad_coordination,
		"released": int(released_value) if released_value != null else 0,
		"reason": reason,
		"squad_id": get_tactical_squad_id(),
		"owner_id": _get_owner_id(),
		"target_id": _get_target_id(),
		"squad_role": squad_role_assignment.duplicate(true),
		"blackboard": _get_coordination_context(0, _get_target_id()),
		"role_context": _get_role_context(),
	}
	if record_release:
		_record_tactical_frame("coordination_release")


func _candidate_uses_melee_lane(candidate: Variant) -> bool:
	if candidate == null:
		return false
	var action_kind: String = str(candidate.get("action_kind"))
	if action_kind != "attack":
		return false
	var has_melee: bool = bool(candidate.call("has_tag", "melee"))
	var has_projectile: bool = bool(candidate.call("has_tag", "projectile"))
	if has_melee and not has_projectile:
		return true
	return float(candidate.get("maximum_distance")) <= 2.5


func _candidate_requests_cover(candidate: Variant) -> bool:
	if candidate == null:
		return false
	return (
		str(candidate.get("movement_mode")) == "away_from_target"
		or bool(candidate.call("has_tag", "retreat"))
	)


func _first_opportunity(opportunities: Array[Dictionary], type_id: String) -> Dictionary:
	for opportunity: Dictionary in opportunities:
		if str(opportunity.get("type", "")) == type_id:
			return opportunity
	return {}


func _ensure_decision_recorder() -> RefCounted:
	if decision_recorder != null:
		return decision_recorder
	var script_value: Script = _service_script(DECISION_RECORDER_PATH)
	if script_value == null:
		return null
	var instance_value: Variant = script_value.new()
	if instance_value is RefCounted:
		decision_recorder = instance_value as RefCounted
		decision_recorder.call("configure", decision_history_capacity)
	return decision_recorder


func _record_tactical_frame(event_name: String) -> void:
	if not record_tactical_decisions:
		return
	var recorder: RefCounted = _ensure_decision_recorder()
	if recorder == null:
		return
	recorder.call(
		"record_frame",
		_get_owner_id(),
		actor.name if actor != null else name,
		event_name,
		last_tactical_decision,
		last_coordination_result,
		{
			"state": str(state),
			"selection": last_selection_summary,
			"action_summary": last_action_summary,
			"squad_role_id": get_tactical_squad_role_id(),
			"squad_role_name": get_tactical_squad_role_name(),
		}
	)


func get_tactical_decision_recorder() -> RefCounted:
	return _ensure_decision_recorder()


func get_tactical_decision_timeline() -> Dictionary:
	var recorder: RefCounted = _ensure_decision_recorder()
	if recorder == null:
		return {}
	return _dictionary(recorder.call("to_dictionary"))


func get_coordination_debug_data() -> Dictionary:
	return last_coordination_result.duplicate(true)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["squad_coordination"] = last_coordination_result.duplicate(true)
	data["squad_id"] = get_tactical_squad_id()
	data["squad_role_id"] = get_tactical_squad_role_id()
	data["squad_role_name"] = get_tactical_squad_role_name()
	data["squad_role_assignment"] = squad_role_assignment.duplicate(true)
	data["squad_role_context"] = _get_role_context()
	var recorder: RefCounted = _ensure_decision_recorder()
	data["decision_replay"] = (
		_dictionary(recorder.call("get_debug_data"))
		if recorder != null
		else {"available": false}
	)
	return data


func _get_coordination_context(owner_id: int, target_id: int) -> Dictionary:
	return _dictionary(_call_service(
		BLACKBOARD_PATH,
		"get_coordination_context",
		[get_tactical_squad_id(), owner_id, target_id]
	))


func _get_role_context() -> Dictionary:
	return _dictionary(_call_service(
		ROLE_ALLOCATOR_PATH,
		"get_squad_context",
		[get_tactical_squad_id()]
	))


func _call_service(path: String, method_name: String, arguments: Array) -> Variant:
	var script_value: Script = _service_script(path)
	if script_value == null or not script_value.has_method(method_name):
		return null
	return script_value.callv(method_name, arguments)


func _service_script(path: String) -> Script:
	if service_scripts.has(path):
		var cached: Variant = service_scripts[path]
		return cached as Script if cached is Script else null
	if not ResourceLoader.exists(path):
		return null
	var loaded: Variant = load(path)
	if loaded is Script:
		service_scripts[path] = loaded
		return loaded as Script
	return null


func _get_owner_id() -> int:
	return actor.get_instance_id() if actor != null else get_instance_id()


func _get_target_id() -> int:
	return player.get_instance_id() if player != null else 0


func _option_name(option: Variant) -> String:
	if option != null and option.has_method("get_display_name"):
		return str(option.call("get_display_name"))
	return "Action"


func _append_result(results: Array[Dictionary], value: Variant) -> void:
	if value is Dictionary:
		results.append((value as Dictionary).duplicate(true))


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for raw: Variant in value as Array:
			if raw is Dictionary:
				result.append((raw as Dictionary).duplicate(true))
	return result
