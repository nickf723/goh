extends Node3D

@export var opening_objective: String = "Prototype Upgrade Lab: unlock an upgrade, test it on targets, then reset or inspect Relics."
@export var opening_message: String = "Prototype Upgrade Lab online. Use pedestals to grant or reset unlocks. Right trigger / Q casts; hold Firebolt to charge once unlocked."
@export var enable_dev_reset_hotkey: bool = true
@export var enable_dev_grant_hotkey: bool = true
@export var lab_unlock_ids: Array[String] = ["charged_firebolt", "armor_trial_blessing"]


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	await get_tree().process_frame
	set_objective(opening_objective)
	show_message(get_opening_message())


func _unhandled_input(event: InputEvent) -> void:
	if not OS.has_feature("editor"):
		return

	if not (event is InputEventKey):
		return

	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	if enable_dev_reset_hotkey and key_event.physical_keycode == KEY_F8:
		get_viewport().set_input_as_handled()
		reset_lab_state()
		return

	if enable_dev_grant_hotkey and key_event.physical_keycode == KEY_F6:
		get_viewport().set_input_as_handled()
		grant_lab_unlocks()
		return


func get_opening_message() -> String:
	var message: String = opening_message

	if OS.has_feature("editor"):
		var shortcuts: Array[String] = []
		if enable_dev_grant_hotkey:
			shortcuts.append("F6 grants core lab upgrades")
		if enable_dev_reset_hotkey:
			shortcuts.append("F8 resets lab progression")

		if shortcuts.size() > 0:
			message += " " + "; ".join(shortcuts) + "."

	return message


func grant_lab_unlocks() -> void:
	var granted: Array[String] = []
	var already_active: Array[String] = []

	for unlock_id: String in lab_unlock_ids:
		if GameState.has_unlock(unlock_id):
			already_active.append(unlock_id)
			continue

		GameState.grant_unlock(unlock_id, {"source": "Prototype Upgrade Lab Shortcut"})
		granted.append(unlock_id)

	GameState.restore_rest_resources()

	var parts: Array[String] = []
	if granted.size() > 0:
		parts.append("Granted: " + ", ".join(granted))
	if already_active.size() > 0:
		parts.append("Already active: " + ", ".join(already_active))

	if parts.size() <= 0:
		parts.append("No lab upgrades changed.")

	show_message("Lab shortcut | " + " ".join(parts))
	set_objective("Equip Firebolt, hold cast, release, then inspect Relics.")


func reset_lab_state() -> void:
	GameState.reset_run()
	reset_lab_targets()
	set_objective(opening_objective)
	show_message("Prototype lab reset. Unlocks, Guard, story flags, and targets refreshed.")


func reset_lab_targets() -> void:
	for node: Node in get_tree().get_nodes_in_group("lab_resettable"):
		if node.has_method("reset_target"):
			node.call("reset_target")


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui != null and ui.has_method("show_message"):
		ui.show_message(text)
	else:
		print(text)


func set_objective(text: String) -> void:
	GameState.set_objective(text)

	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui != null and ui.has_method("set_objective"):
		ui.set_objective(text)
