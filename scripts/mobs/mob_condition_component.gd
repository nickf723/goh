extends Node
class_name MobConditionComponent

signal condition_applied(condition_id: String, snapshot: Dictionary)
signal condition_removed(condition_id: String, reason: String)
signal conditions_changed(snapshot: Dictionary)

@export var automatic_ticking: bool = true
@export_range(1, 64, 1) var maximum_conditions: int = 24

var active_conditions: Dictionary = {}


func _ready() -> void:
	set_process(automatic_ticking)


func _process(delta: float) -> void:
	advance_conditions(delta)


func apply_status(
	status_id: String,
	duration: float,
	strength: float = 1.0,
	source_name: String = ""
) -> Dictionary:
	return sustain_status(status_id, duration, strength, source_name)


func sustain_status(
	status_id: String,
	duration: float,
	strength: float = 1.0,
	source_name: String = ""
) -> Dictionary:
	var normalized_id: String = status_id.to_lower().strip_edges()
	var normalized_duration: float = maxf(duration, 0.0)
	if normalized_id == "":
		return {"ok": false, "error": "status id is empty"}
	if normalized_duration <= 0.0:
		return {"ok": false, "error": "status duration must be positive"}
	var previous: Dictionary = (
		(active_conditions.get(normalized_id, {}) as Dictionary).duplicate(true)
		if active_conditions.get(normalized_id, {}) is Dictionary
		else {}
	)
	if previous.is_empty() and active_conditions.size() >= maximum_conditions:
		return {"ok": false, "error": "condition capacity reached"}
	var application_count: int = int(previous.get("application_count", 0)) + 1
	var condition: Dictionary = {
		"id": normalized_id,
		"remaining": maxf(
			normalized_duration,
			float(previous.get("remaining", 0.0))
		),
		"duration": maxf(
			normalized_duration,
			float(previous.get("duration", 0.0))
		),
		"strength": maxf(
			maxf(strength, 0.0),
			float(previous.get("strength", 0.0))
		),
		"source_name": (
			source_name
			if source_name != ""
			else str(previous.get("source_name", ""))
		),
		"application_count": application_count,
	}
	active_conditions[normalized_id] = condition
	condition_applied.emit(normalized_id, condition.duplicate(true))
	_emit_changed()
	return {
		"ok": true,
		"condition": condition.duplicate(true),
		"refreshed": not previous.is_empty(),
	}


func advance_conditions(delta: float) -> Array[String]:
	var expired: Array[String] = []
	if delta <= 0.0 or active_conditions.is_empty():
		return expired
	for raw_id: Variant in active_conditions.keys():
		var condition_id: String = str(raw_id)
		var condition: Dictionary = active_conditions[raw_id] as Dictionary
		condition["remaining"] = maxf(
			float(condition.get("remaining", 0.0)) - delta,
			0.0
		)
		active_conditions[raw_id] = condition
		if float(condition.get("remaining", 0.0)) <= 0.0:
			expired.append(condition_id)
	for condition_id: String in expired:
		active_conditions.erase(condition_id)
		condition_removed.emit(condition_id, "expired")
	if not expired.is_empty() or not active_conditions.is_empty():
		_emit_changed()
	return expired


func remove_status(status_id: String, reason: String = "removed") -> bool:
	var normalized_id: String = status_id.to_lower().strip_edges()
	if not active_conditions.has(normalized_id):
		return false
	active_conditions.erase(normalized_id)
	condition_removed.emit(normalized_id, reason)
	_emit_changed()
	return true


func clear_statuses(reason: String = "reset") -> void:
	var ids: Array[String] = get_condition_ids()
	active_conditions.clear()
	for condition_id: String in ids:
		condition_removed.emit(condition_id, reason)
	_emit_changed()


func has_status(status_id: String) -> bool:
	return active_conditions.has(status_id.to_lower().strip_edges())


func get_status_strength(status_id: String) -> float:
	var condition: Dictionary = active_conditions.get(
		status_id.to_lower().strip_edges(),
		{}
	) as Dictionary
	return maxf(float(condition.get("strength", 0.0)), 0.0)


func get_condition_ids() -> Array[String]:
	var result: Array[String] = []
	for raw_id: Variant in active_conditions.keys():
		result.append(str(raw_id))
	result.sort()
	return result


func get_context_tags() -> Array[String]:
	var result: Array[String] = []
	for condition_id: String in get_condition_ids():
		result.append(condition_id)
		result.append("status:" + condition_id)
	return result


func to_dictionary() -> Dictionary:
	var conditions: Array[Dictionary] = []
	for condition_id: String in get_condition_ids():
		conditions.append(
			(active_conditions[condition_id] as Dictionary).duplicate(true)
		)
	return {
		"count": conditions.size(),
		"ids": get_condition_ids(),
		"conditions": conditions,
	}


func _emit_changed() -> void:
	conditions_changed.emit(to_dictionary())
