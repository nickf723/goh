extends Node
class_name PlayerStatusReceiver

signal status_applied(status_name: String, status_data: Dictionary)
signal status_removed(status_name: String)
signal status_blocked(status_name: String, source: String)
signal statuses_cleared

var active_statuses: Dictionary = {}
var authority_controller: PlayerElementalAuthorityController
var last_result: String = "ready"
var total_damage_ticks: int = 0
var total_blocked_statuses: int = 0


func _ready() -> void:
	authority_controller = get_parent().get_node_or_null(
		"ElementalAuthorityController"
	) as PlayerElementalAuthorityController
	add_to_group("player_status_receiver")
	add_to_group("debuggable")


func _process(delta: float) -> void:
	if active_statuses.is_empty():
		return
	var expired_statuses: Array[String] = []
	for status_name_variant: Variant in active_statuses.keys():
		var status_name: String = str(status_name_variant)
		var status: Dictionary = active_statuses[status_name] as Dictionary
		status["duration"] = maxf(float(status.get("duration", 0.0)) - maxf(delta, 0.0), 0.0)
		status["tick_timer"] = float(status.get("tick_timer", 1.0)) - maxf(delta, 0.0)
		if float(status.get("tick_timer", 0.0)) <= 0.0:
			status["tick_timer"] = 1.0
			_apply_status_tick(status_name, status)
		active_statuses[status_name] = status
		if float(status.get("duration", 0.0)) <= 0.0:
			expired_statuses.append(status_name)
	for status_name: String in expired_statuses:
		remove_status(status_name)


func apply_status(
	status_name: String,
	duration: float,
	strength: float = 1.0,
	source: String = "unknown"
) -> void:
	var normalized_status: String = status_name.strip_edges().to_lower()
	if normalized_status == "" or duration <= 0.0:
		return
	var source_element: String = _get_status_element(normalized_status)
	if (
		authority_controller != null
		and not authority_controller.can_receive_status(
			normalized_status,
			source_element
		)
	):
		last_result = "blocked:" + normalized_status
		total_blocked_statuses += 1
		status_blocked.emit(normalized_status, source)
		return
	active_statuses[normalized_status] = {
		"duration": duration,
		"strength": maxf(strength, 0.0),
		"tick_timer": 1.0,
		"source": source,
		"element": source_element,
	}
	last_result = "applied:" + normalized_status
	status_applied.emit(
		normalized_status,
		(active_statuses[normalized_status] as Dictionary).duplicate(true)
	)


func sustain_status(
	status_name: String,
	duration: float,
	strength: float = 1.0,
	source: String = "unknown"
) -> void:
	var normalized_status: String = status_name.strip_edges().to_lower()
	var source_element: String = _get_status_element(normalized_status)
	if (
		authority_controller != null
		and not authority_controller.can_receive_status(
			normalized_status,
			source_element
		)
	):
		remove_status(normalized_status)
		last_result = "blocked:" + normalized_status
		total_blocked_statuses += 1
		status_blocked.emit(normalized_status, source)
		return
	if not active_statuses.has(normalized_status):
		apply_status(normalized_status, duration, strength, source)
		return
	var status: Dictionary = active_statuses[normalized_status] as Dictionary
	status["duration"] = maxf(float(status.get("duration", 0.0)), duration)
	status["strength"] = maxf(float(status.get("strength", 0.0)), strength)
	status["source"] = source
	status["element"] = source_element
	active_statuses[normalized_status] = status
	last_result = "sustained:" + normalized_status
	status_applied.emit(normalized_status, status.duplicate(true))


func remove_status(status_name: String) -> void:
	var normalized_status: String = status_name.strip_edges().to_lower()
	if not active_statuses.has(normalized_status):
		return
	active_statuses.erase(normalized_status)
	last_result = "removed:" + normalized_status
	status_removed.emit(normalized_status)


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
	for status_name_variant: Variant in active_statuses.keys():
		var status_name: String = str(status_name_variant)
		if not authority_controller.can_receive_status(
			status_name,
			_get_status_element(status_name)
		):
			blocked.append(status_name)
	for status_name: String in blocked:
		remove_status(status_name)
	return blocked.size()


func has_status(status_name: String) -> bool:
	return active_statuses.has(status_name.strip_edges().to_lower())


func get_status_strength(status_name: String) -> float:
	var normalized_status: String = status_name.strip_edges().to_lower()
	if not active_statuses.has(normalized_status):
		return 0.0
	return float((active_statuses[normalized_status] as Dictionary).get("strength", 0.0))


func get_movement_multiplier() -> float:
	if has_status("stunned") or has_status("frozen") or has_status("staggered"):
		return 0.0
	if has_status("chill"):
		return clampf(get_status_strength("chill"), 0.0, 1.0)
	return 1.0


func blocks_actions() -> bool:
	return has_status("stunned") or has_status("frozen") or has_status("staggered")


func _apply_status_tick(status_name: String, status: Dictionary) -> void:
	if status_name not in ["burning", "poisoned"]:
		return
	var element: String = str(status.get("element", _get_status_element(status_name)))
	var payload: DamagePayload = DamagePayload.new()
	payload.amount = maxi(roundi(float(status.get("strength", 1.0))), 1)
	payload.stance_damage = 0
	payload.element = element
	payload.source_name = str(status.get("source", status_name.capitalize()))
	payload.hit_type = "status"
	payload.tags = [element, status_name, "status", "player_status"]
	if authority_controller != null:
		var authority_result: Dictionary = authority_controller.resolve_incoming_payload(payload)
		if bool(authority_result.get("immune", false)):
			remove_status(status_name)
			last_result = "negated_tick:" + status_name
			return
		var resolved_value: Variant = authority_result.get("payload", payload)
		if resolved_value is DamagePayload:
			payload = resolved_value as DamagePayload
	if payload.amount <= 0:
		return
	GameState.take_damage(payload.amount)
	total_damage_ticks += 1
	last_result = "tick:" + status_name


func _get_status_element(status_name: String) -> String:
	match status_name.strip_edges().to_lower():
		"burning":
			return "fire"
		"poisoned":
			return "poison"
		"wet", "steamed":
			return "water"
		"frozen", "chill":
			return "ice"
		"stunned", "electrified":
			return "lightning"
		_:
			return "neutral"


func get_debug_data() -> Dictionary:
	var rows: Array[String] = []
	for status_name_variant: Variant in active_statuses.keys():
		var status_name: String = str(status_name_variant)
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
	}
