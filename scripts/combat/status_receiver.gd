extends Node

const CombatFeedback = preload("res://scripts/combat/combat_feedback.gd")

var active_statuses: Dictionary = {}


func _ready() -> void:
	add_to_group("debuggable")


func apply_status(status_name: String, duration: float, strength: float = 1.0, source: String = "unknown") -> void:
	if status_name == "" or duration <= 0.0:
		return

	resolve_status_conflicts(status_name)

	active_statuses[status_name] = {
		"duration": duration,
		"strength": strength,
		"tick_timer": 1.0,
		"source": source,
	}

	print("Applied status: ", status_name, " from ", source, " for ", duration, " seconds.")
	show_status_feedback(status_name)


func sustain_status(status_name: String, duration: float, strength: float = 1.0, source: String = "unknown") -> void:
	if status_name == "" or duration <= 0.0:
		return

	resolve_status_conflicts(status_name)

	if not active_statuses.has(status_name):
		apply_status(status_name, duration, strength, source)
		return

	active_statuses[status_name]["duration"] = max(
		float(active_statuses[status_name]["duration"]),
		duration
	)

	active_statuses[status_name]["strength"] = strength
	active_statuses[status_name]["source"] = source

	if not active_statuses[status_name].has("tick_timer"):
		active_statuses[status_name]["tick_timer"] = 1.0


func _process(delta: float) -> void:
	var expired_statuses: Array[String] = []

	for status_name: String in active_statuses.keys():
		active_statuses[status_name]["duration"] -= delta

		match status_name:
			"burning":
				process_burning(delta, status_name)
			"poisoned":
				process_poisoned(delta, status_name)

		if active_statuses[status_name]["duration"] <= 0.0:
			expired_statuses.append(status_name)

	for status_name: String in expired_statuses:
		active_statuses.erase(status_name)
		print("Status expired: ", status_name)


func process_burning(delta: float, status_name: String) -> void:
	active_statuses[status_name]["tick_timer"] -= delta

	if active_statuses[status_name]["tick_timer"] > 0.0:
		return

	active_statuses[status_name]["tick_timer"] = 1.0

	var burn_damage: int = max(1, roundi(active_statuses[status_name]["strength"]))
	var source: String = "Burning"

	if active_statuses[status_name].has("source"):
		source = str(active_statuses[status_name]["source"])

	var burn_payload: DamagePayload = DamagePayload.new()
	burn_payload.amount = burn_damage
	burn_payload.stance_damage = 0
	burn_payload.element = "fire"
	burn_payload.source_name = source
	burn_payload.hit_type = "status"
	burn_payload.tags = ["fire", "burning", "status"]

	apply_status_payload(burn_payload, true)


func process_poisoned(delta: float, status_name: String) -> void:
	active_statuses[status_name]["tick_timer"] -= delta

	if active_statuses[status_name]["tick_timer"] > 0.0:
		return

	active_statuses[status_name]["tick_timer"] = 1.0

	var poison_damage: int = max(1, roundi(active_statuses[status_name]["strength"]))
	var source: String = "Poisoned"

	if active_statuses[status_name].has("source"):
		source = str(active_statuses[status_name]["source"])

	var poison_payload: DamagePayload = DamagePayload.new()
	poison_payload.amount = poison_damage
	poison_payload.stance_damage = 0
	poison_payload.element = "poison"
	poison_payload.source_name = source
	poison_payload.hit_type = "status"
	poison_payload.tags = ["poison", "poisoned", "status"]

	apply_status_payload(poison_payload, true)


func apply_status_payload(payload: DamagePayload, force_health_damage: bool = false) -> void:
	var hit_receiver: Node = get_parent().get_node_or_null("HitReceiver")

	if hit_receiver == null:
		return

	if not hit_receiver.has_method("receive_payload"):
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
		ui.show_message(result["message"])

	if result.has("objective") and result["objective"] != "":
		ui.set_objective(result["objective"])


func show_status_feedback(status_name: String) -> void:
	var target: Node = get_parent()

	if target == null:
		target = self

	CombatFeedback.show_status_feedback(target, status_name)


func has_status(status_name: String) -> bool:
	return active_statuses.has(status_name)


func remove_status(status_name: String) -> void:
	if active_statuses.has(status_name):
		active_statuses.erase(status_name)
		print("Status removed: ", status_name)


func get_status_strength(status_name: String) -> float:
	if not active_statuses.has(status_name):
		return 1.0

	return active_statuses[status_name]["strength"]


func get_movement_multiplier() -> float:
	if has_status("stunned"):
		return 0.0

	if has_status("frozen"):
		return 0.0

	if has_status("staggered"):
		return 0.0

	if has_status("chill"):
		return get_status_strength("chill")

	return 1.0


func resolve_status_conflicts(new_status: String) -> void:
	match new_status:
		"wet":
			remove_status("oily")
			remove_status("burning")

		"burning":
			remove_status("frozen")
			remove_status("chill")

		"frozen":
			remove_status("burning")


func blocks_actions() -> bool:
	if has_status("stunned"):
		return true

	if has_status("frozen"):
		return true

	if has_status("staggered"):
		return true

	return false


func get_debug_data() -> Dictionary:
	var status_summary: Array[String] = []

	for status_name: String in active_statuses.keys():
		var duration: float = active_statuses[status_name]["duration"]
		var strength: float = active_statuses[status_name]["strength"]
		var source: String = "unknown"

		if active_statuses[status_name].has("source"):
			source = active_statuses[status_name]["source"]

		status_summary.append(
			status_name
			+ "("
			+ str(snapped(duration, 0.1))
			+ "s, "
			+ str(strength)
			+ ", "
			+ source
			+ ")"
		)

	var statuses: String = "none"

	if status_summary.size() > 0:
		statuses = ", ".join(status_summary)

	return {
		"statuses": statuses,
		"move": get_movement_multiplier(),
	}
