extends Area3D

@export var prompt_text: String = "Use Upgrade Pedestal"
@export var pedestal_title: String = "Upgrade Pedestal"
@export var mode: String = "grant_unlocks"
@export var unlock_ids: Array[String] = []
@export var source_label: String = "Prototype Upgrade Lab"
@export_multiline var success_message: String = "Progression updated."
@export var objective_after: String = "Test the upgrade, then check the Relics menu."
@export var should_restore_resources: bool = false
@export var should_grant_guard: bool = false
@export var should_reset_targets: bool = false


func _ready() -> void:
	add_to_group("upgrade_pedestal")
	add_to_group("debuggable")


func interact() -> Dictionary:
	match mode:
		"grant_unlocks":
			return grant_unlocks()
		"reset_progress":
			return reset_progress()
		"restore_resources":
			return restore_resources()
		"show_unlocks":
			return show_unlocks()
		"reset_targets":
			return reset_targets()
		_:
			return {
				"message": pedestal_title + " has no valid mode: " + mode,
				"objective": objective_after,
			}


func grant_unlocks() -> Dictionary:
	var granted: Array[String] = []
	var already_had: Array[String] = []

	for unlock_id: String in unlock_ids:
		if unlock_id == "":
			continue

		if GameState.has_unlock(unlock_id):
			already_had.append(get_unlock_display_name(unlock_id))
		else:
			GameState.grant_unlock(unlock_id, {"source": source_label})
			granted.append(get_unlock_display_name(unlock_id))

	if should_restore_resources and GameState.has_method("restore_rest_resources"):
		GameState.restore_rest_resources()

	if should_grant_guard and GameState.has_method("grant_guard"):
		GameState.grant_guard(1, 1)

	if should_reset_targets:
		reset_lab_targets()

	var message_parts: Array[String] = []

	if granted.size() > 0:
		message_parts.append("Unlocked: " + ", ".join(granted))

	if already_had.size() > 0:
		message_parts.append("Already active: " + ", ".join(already_had))

	if should_restore_resources:
		message_parts.append("Resources restored.")

	if should_grant_guard:
		message_parts.append("Guard granted.")

	if message_parts.size() <= 0:
		message_parts.append(success_message)

	return {
		"message": pedestal_title + " | " + " ".join(message_parts),
		"objective": objective_after,
	}


func reset_progress() -> Dictionary:
	GameState.reset_run()
	reset_lab_targets()
	return {
		"message": pedestal_title + " | Lab progression reset. Unlocks, Guard, and story flags cleared.",
		"objective": "Choose an upgrade pedestal and test again.",
	}


func restore_resources() -> Dictionary:
	if GameState.has_method("restore_rest_resources"):
		GameState.restore_rest_resources()

	var rest_messages: Array[String] = []
	if GameState.has_method("apply_rest_unlocks"):
		rest_messages = GameState.apply_rest_unlocks()

	if should_grant_guard and GameState.has_method("grant_guard"):
		GameState.grant_guard(1, 1)
		rest_messages.append("Lab console grants 1 Guard.")

	var message: String = pedestal_title + " | Resources restored."
	if rest_messages.size() > 0:
		message += " " + " ".join(rest_messages)

	return {
		"message": message,
		"objective": objective_after,
	}


func show_unlocks() -> Dictionary:
	var rows: Array = []

	if GameState.has_method("get_unlock_rows"):
		rows = GameState.get_unlock_rows()

	if rows.size() <= 0:
		return {
			"message": pedestal_title + " | No active unlocks.",
			"objective": objective_after,
		}

	var labels: Array[String] = []
	for row_variant in rows:
		if not (row_variant is Dictionary):
			continue

		var row: Dictionary = row_variant as Dictionary
		labels.append(str(row.get("display_name", row.get("id", "Unlock"))))

	return {
		"message": pedestal_title + " | Active unlocks: " + ", ".join(labels),
		"objective": objective_after,
	}


func reset_targets() -> Dictionary:
	reset_lab_targets()
	return {
		"message": pedestal_title + " | Lab targets reset.",
		"objective": "Test another spell or upgrade.",
	}


func reset_lab_targets() -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root != null and scene_root.has_method("reset_lab_targets"):
		scene_root.call("reset_lab_targets")
		return

	for node: Node in get_tree().get_nodes_in_group("lab_resettable"):
		if node.has_method("reset_target"):
			node.call("reset_target")


func get_unlock_display_name(unlock_id: String) -> String:
	if not GameState.has_method("get_unlock_rows"):
		return unlock_id.capitalize()

	for row_variant in GameState.get_unlock_rows():
		if not (row_variant is Dictionary):
			continue

		var row: Dictionary = row_variant as Dictionary
		if str(row.get("id", "")) == unlock_id:
			return str(row.get("display_name", unlock_id.capitalize()))

	return unlock_id.capitalize()


func get_debug_data() -> Dictionary:
	return {
		"type": "UpgradePedestal",
		"title": pedestal_title,
		"mode": mode,
		"unlock_ids": unlock_ids,
	}
