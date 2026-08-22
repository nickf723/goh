extends Node

signal status_applied(status_name: String, status_data: Dictionary)
signal status_removed(status_name: String)
signal statuses_cleared

@export_range(1, 64, 1) var maximum_statuses: int = 24

const CombatFeedback = preload("res://scripts/combat/combat_feedback.gd")
const StatusVisualControllerScript = preload(
	"res://scripts/visuals/status_visual_controller.gd"
)
const StatePolicy = preload("res://scripts/systems/reaction_state_policy.gd")

var active_statuses: Dictionary = {}
var status_visual_controller: Node3D


func _ready() -> void:
	add_to_group("debuggable")
	call_deferred("attach_status_visual_controller")


func attach_status_visual_controller() -> void:
	if not is_inside_tree():
		return
	var target: Node = get_parent()
	if not target is Node3D:
		return
	var existing: Node = target.get_node_or_null("StatusVisualController")
	if existing is Node3D:
		status_visual_controller = existing as Node3D
	else:
		status_visual_controller = StatusVisualControllerScript.new() as Node3D
		status_visual_controller.name = "StatusVisualController"
		target.add_child(status_visual_controller)
	if status_visual_controller != null and status_visual_controller.has_method("bind"):
		status_visual_controller.call("bind", self)


func apply_status(
	status_name: String,
	duration: float,
	strength: float = 1.0,
	source: String = "unknown"
) -> void:
	var normalized: String = StatePolicy.normalize_state(status_name)
	if normalized == "" or duration <= 0.0:
		return
	if (
		not active_statuses.has(normalized)
		and active_statuses.size() >= maximum_statuses
	):
		return
	StatePolicy.resolve_conflicts(self, normalized)
	active_statuses[normalized] = {
		"duration": duration,
		"strength": maxf(strength, 0.0),
		"tick_timer": 1.0,
		"source": source,
		"element": StatePolicy.get_state_element(normalized),
	}
	# Leaf Pelt is intentionally subliminal control. Do not cover combat in giant
	# status text three times per volley; the movement change and leaf impacts are
	# the feedback. Other authored statuses retain the existing announcement.
	if normalized != "leaf_pelted":
		print("Applied status: ", normalized, " from ", source, " for ", duration, " seconds.")
		show_status_feedback(normalized)
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
	StatePolicy.resolve_conflicts(self, normalized)
	if not active_statuses.has(normalized):
		apply_status(normalized, duration, strength, source)
		return
	var status: Dictionary = active_statuses[normalized] as Dictionary
	status["duration"] = maxf(float(status.get("duration", 0.0)), duration)
	status["strength"] = maxf(float(status.get("strength", 0.0)), strength)
	status["source"] = source
	status["element"] = StatePolicy.get_state_element(normalized)
	if not status.has("tick_timer"):
		status["tick_timer"] = 1.0
	active_statuses[normalized] = status
	status_applied.emit(normalized, status.duplicate(true))


func _process(delta: float) -> void:
	advance_statuses(delta)


func advance_statuses(delta: float) -> Array[String]:
	var expired_statuses: Array[String] = []
	var step: float = maxf(delta, 0.0)
	if step <= 0.0:
		return expired_statuses
	for status_value: Variant in active_statuses.keys():
		var status_name: String = str(status_value)
		if not active_statuses.has(status_name):
			continue
		var status: Dictionary = active_statuses[status_name] as Dictionary
		status["duration"] = float(status.get("duration", 0.0)) - step
		match status_name:
			"burning":
				_process_damage_status(status_name, status, "fire", step)
			"poisoned":
				_process_damage_status(status_name, status, "poison", step)
		active_statuses[status_name] = status
		if float(status.get("duration", 0.0)) <= 0.0:
			expired_statuses.append(status_name)
	for status_name: String in expired_statuses:
		remove_status(status_name)
	return expired_statuses


func _process_damage_status(
	status_name: String,
	status: Dictionary,
	element: String,
	delta: float
) -> void:
	status["tick_timer"] = float(status.get("tick_timer", 1.0)) - delta
	if float(status.get("tick_timer", 0.0)) > 0.0:
		return
	status["tick_timer"] = 1.0
	var payload := DamagePayload.new()
	payload.amount = maxi(roundi(float(status.get("strength", 1.0))), 1)
	payload.stance_damage = 0
	payload.element = element
	payload.source_name = str(status.get("source", status_name.capitalize()))
	payload.hit_type = "status"
	payload.tags = [element, status_name, "status"]
	payload.suppress_reactions = true
	apply_status_payload(payload, true)


func apply_status_payload(
	payload: DamagePayload,
	force_health_damage: bool = false
) -> void:
	var target: Node = get_parent()
	var hit_receiver: Node = target.get_node_or_null("HitReceiver")
	if hit_receiver == null or not hit_receiver.has_method("receive_payload"):
		if target.has_method("receive_damage_payload"):
			var raw_result: Variant = target.call(
				"receive_damage_payload",
				payload
			)
			show_status_result(
				raw_result as Dictionary
				if raw_result is Dictionary
				else {}
			)
		return
	if force_health_damage:
		var original_hit_mode: Variant = hit_receiver.get("hit_mode")
		if original_hit_mode != null:
			hit_receiver.set("hit_mode", 2)
			var forced_result: Dictionary = hit_receiver.receive_payload(payload)
			hit_receiver.set("hit_mode", original_hit_mode)
			show_status_result(forced_result)
			return
	var result: Dictionary = hit_receiver.receive_payload(payload)
	show_status_result(result)


func show_status_result(result: Dictionary) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui == null:
		return
	if result.has("message") and result["message"] != "":
		ui.call("show_message", result["message"])
	if result.has("objective") and result["objective"] != "":
		ui.call("set_objective", result["objective"])


func show_status_feedback(status_name: String) -> void:
	var target: Node = get_parent()
	CombatFeedback.show_status_feedback(target if target != null else self, status_name)


func has_status(status_name: String) -> bool:
	return active_statuses.has(StatePolicy.normalize_state(status_name))


func remove_status(status_name: String) -> void:
	var normalized: String = StatePolicy.normalize_state(status_name)
	if not active_statuses.has(normalized):
		return
	active_statuses.erase(normalized)
	print("Status removed: ", normalized)
	status_removed.emit(normalized)


func clear_all_statuses() -> void:
	if active_statuses.is_empty():
		return
	active_statuses.clear()
	statuses_cleared.emit()


func get_active_status_names() -> Array[String]:
	var names: Array[String] = []
	for status_value: Variant in active_statuses.keys():
		names.append(str(status_value))
	return names


func get_context_tags() -> Array[String]:
	var tags: Array[String] = []
	for status_name: String in get_active_status_names():
		tags.append(status_name)
		tags.append("status:" + status_name)
	return tags


func get_status_strength(status_name: String) -> float:
	var normalized: String = StatePolicy.normalize_state(status_name)
	if not active_statuses.has(normalized):
		return 0.0
	return float(
		(active_statuses[normalized] as Dictionary).get("strength", 0.0)
	)


func get_movement_multiplier() -> float:
	if has_status("stunned") or has_status("frozen") or has_status("staggered"):
		return 0.0
	# Root Bind immobilizes translation but deliberately does not enter
	# blocks_actions(). A rooted enemy can still turn, attack, cast, or defend.
	if has_status("rooted"):
		return 0.0
	var multiplier: float = 1.0
	if has_status("chill"):
		multiplier = minf(
			multiplier,
			clampf(get_status_strength("chill"), 0.0, 1.0)
		)
	# Leaf Pelt deliberately lives at the edge of perception. Three fresh leaves
	# bottom out at roughly 97.6% movement speed, enough to be irritating without
	# becoming a substitute for Ice or other true control elements.
	if has_status("leaf_pelted"):
		multiplier = minf(
			multiplier,
			clampf(get_status_strength("leaf_pelted"), 0.85, 1.0)
		)
	return multiplier


func resolve_status_conflicts(new_status: String) -> void:
	StatePolicy.resolve_conflicts(self, new_status)


func blocks_actions() -> bool:
	return has_status("stunned") or has_status("frozen") or has_status("staggered")


func get_debug_data() -> Dictionary:
	var status_summary: Array[String] = []
	for status_value: Variant in active_statuses.keys():
		var status_name: String = str(status_value)
		var status: Dictionary = active_statuses[status_name] as Dictionary
		status_summary.append(
			status_name
			+ "("
			+ str(snappedf(float(status.get("duration", 0.0)), 0.1))
			+ "s, "
			+ str(snappedf(float(status.get("strength", 0.0)), 0.1))
			+ ", "
			+ str(status.get("source", "unknown"))
			+ ")"
		)
	return {
		"statuses": "none" if status_summary.is_empty() else ", ".join(status_summary),
		"maximum_statuses": maximum_statuses,
		"status_names": get_active_status_names(),
		"move": get_movement_multiplier(),
		"blocks_actions": blocks_actions(),
	}
