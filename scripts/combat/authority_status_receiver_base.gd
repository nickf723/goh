extends Node
class_name AuthorityStatusReceiverBase

signal status_applied(status_name: String, status_data: Dictionary)
signal status_removed(status_name: String)
signal status_blocked(status_name: String, source: String)
signal statuses_cleared

const StatePolicy = preload("res://scripts/systems/reaction_state_policy.gd")

var active_statuses: Dictionary = {}
var actor: Node
var authority_controller: PlayerElementalAuthorityController
var last_result: String = "ready"
var total_damage_ticks: int = 0
var total_blocked_statuses: int = 0


func _ready() -> void:
	actor = get_parent()
	authority_controller = null
	if actor != null:
		authority_controller = actor.get_node_or_null(
			"ElementalAuthorityController"
		) as PlayerElementalAuthorityController
	var receiver_group: String = get_receiver_group()
	if receiver_group != "":
		add_to_group(receiver_group)
	add_to_group("debuggable")


func _process(delta: float) -> void:
	if active_statuses.is_empty():
		return
	var expired: Array[String] = []
	var step: float = maxf(delta, 0.0)
	for status_value: Variant in active_statuses.keys():
		var status_name: String = str(status_value)
		if not active_statuses.has(status_name):
			continue
		var status: Dictionary = active_statuses[status_name] as Dictionary
		status["duration"] = maxf(
			float(status.get("duration", 0.0)) - step,
			0.0
		)
		status["tick_timer"] = float(status.get("tick_timer", 1.0)) - step
		if float(status.get("tick_timer", 0.0)) <= 0.0:
			status["tick_timer"] = 1.0
			_apply_status_tick(status_name, status)
			if not active_statuses.has(status_name):
				continue
		active_statuses[status_name] = status
		if float(status.get("duration", 0.0)) <= 0.0:
			expired.append(status_name)
	for status_name: String in expired:
		remove_status(status_name)


func apply_status(
	status_name: String,
	duration: float,
	strength: float = 1.0,
	source: String = "unknown"
) -> void:
	var normalized: String = StatePolicy.normalize_state(status_name)
	if normalized == "" or duration <= 0.0:
		return
	var source_element: String = StatePolicy.get_state_element(normalized)
	if not _can_receive_status(normalized, source_element, source):
		return
	StatePolicy.resolve_conflicts(self, normalized)
	active_statuses[normalized] = {
		"duration": duration,
		"strength": maxf(strength, 0.0),
		"tick_timer": 1.0,
		"source": source,
		"element": source_element,
	}
	last_result = "applied:" + normalized
	status_applied.emit(
		normalized,
		(active_statuses[normalized] as Dictionary).duplicate(true)
	)


func sustain_status(
	status_name: String,
	duration: float,
	strength: float = 1.0,
	source: String = "unknown"
) -> void:
	var normalized: String = StatePolicy.normalize_state(status_name)
	if normalized == "" or duration <= 0.0:
		return
	var source_element: String = StatePolicy.get_state_element(normalized)
	if not _can_receive_status(normalized, source_element, source):
		remove_status(normalized)
		return
	StatePolicy.resolve_conflicts(self, normalized)
	if not active_statuses.has(normalized):
		apply_status(normalized, duration, strength, source)
		return
	var status: Dictionary = active_statuses[normalized] as Dictionary
	status["duration"] = maxf(float(status.get("duration", 0.0)), duration)
	status["strength"] = maxf(float(status.get("strength", 0.0)), strength)
	status["source"] = source
	status["element"] = source_element
	active_statuses[normalized] = status
	last_result = "sustained:" + normalized
	status_applied.emit(normalized, status.duplicate(true))


func _can_receive_status(
	status_name: String,
	source_element: String,
	source: String
) -> bool:
	if (
		authority_controller != null
		and not authority_controller.can_receive_status(
			status_name,
			source_element
		)
	):
		last_result = "blocked:" + status_name
		total_blocked_statuses += 1
		status_blocked.emit(status_name, source)
		return false
	return true


func remove_status(status_name: String) -> void:
	var normalized: String = StatePolicy.normalize_state(status_name)
	if not active_statuses.has(normalized):
		return
	active_statuses.erase(normalized)
	last_result = "removed:" + normalized
	status_removed.emit(normalized)


func clear_all_statuses() -> void:
	if active_statuses.is_empty():
		return
	active_statuses.clear()
	last_result = "cleared"
	statuses_cleared.emit()


func prune_blocked_statuses() -> int:
	if authority_controller == null:
		return 0
	var blocked: Array[String] = []
	for status_value: Variant in active_statuses.keys():
		var status_name: String = str(status_value)
		if not authority_controller.can_receive_status(
			status_name,
			StatePolicy.get_state_element(status_name)
		):
			blocked.append(status_name)
	for status_name: String in blocked:
		remove_status(status_name)
	return blocked.size()


func has_status(status_name: String) -> bool:
	return active_statuses.has(StatePolicy.normalize_state(status_name))


func get_active_status_names() -> Array[String]:
	var names: Array[String] = []
	for status_value: Variant in active_statuses.keys():
		names.append(str(status_value))
	return names


func get_status_strength(status_name: String) -> float:
	var normalized: String = StatePolicy.normalize_state(status_name)
	if not active_statuses.has(normalized):
		return 0.0
	return float(
		(active_statuses[normalized] as Dictionary).get("strength", 0.0)
	)


func get_movement_multiplier() -> float:
	if (
		has_status("stunned")
		or has_status("frozen")
		or has_status("staggered")
		or has_status("stasis")
	):
		return 0.0
	if has_status("chill"):
		return clampf(get_status_strength("chill"), 0.0, 1.0)
	return 1.0


func blocks_actions() -> bool:
	return (
		has_status("stunned")
		or has_status("frozen")
		or has_status("staggered")
		or has_status("stasis")
	)


func _apply_status_tick(status_name: String, status: Dictionary) -> void:
	if status_name not in ["burning", "poisoned"]:
		return
	var payload := DamagePayload.new()
	payload.amount = maxi(roundi(float(status.get("strength", 1.0))), 1)
	payload.stance_damage = 0
	payload.element = str(
		status.get("element", StatePolicy.get_state_element(status_name))
	)
	payload.source_name = str(status.get("source", status_name.capitalize()))
	payload.hit_type = "status"
	payload.tags = [
		payload.element,
		status_name,
		"status",
		get_tick_tag(),
	]
	payload.suppress_reactions = true
	if authority_controller != null:
		var authority_result: Dictionary = (
			authority_controller.resolve_incoming_payload(payload)
		)
		if bool(authority_result.get("immune", false)):
			remove_status(status_name)
			last_result = "negated_tick:" + status_name
			return
		var resolved_value: Variant = authority_result.get("payload", payload)
		if resolved_value is DamagePayload:
			payload = resolved_value as DamagePayload
	if payload.amount <= 0:
		return
	deliver_status_tick(payload)
	total_damage_ticks += 1
	last_result = "tick:" + status_name


func deliver_status_tick(_payload: DamagePayload) -> void:
	# Implemented by the concrete player or manifestation receiver.
	pass


func get_receiver_group() -> String:
	return "authority_status_receiver"


func get_tick_tag() -> String:
	return "authority_status"


func get_debug_data() -> Dictionary:
	var rows: Array[String] = []
	for status_value: Variant in active_statuses.keys():
		var status_name: String = str(status_value)
		var status: Dictionary = active_statuses[status_name] as Dictionary
		rows.append(
			status_name
			+ "("
			+ str(snappedf(float(status.get("duration", 0.0)), 0.1))
			+ "s x"
			+ str(snappedf(float(status.get("strength", 0.0)), 0.1))
			+ ")"
		)
	return {
		"statuses": rows,
		"status_count": rows.size(),
		"movement_multiplier": get_movement_multiplier(),
		"blocks_actions": blocks_actions(),
		"last_result": last_result,
		"damage_ticks": total_damage_ticks,
		"blocked_statuses": total_blocked_statuses,
		"authority_ready": authority_controller != null,
		"shared_policy": true,
	}
