extends Node3D

@export var opening_objective: String = "Prototype Upgrade Lab: unlock an upgrade, test it on targets, then reset or inspect Relics."
@export var opening_message: String = "Prototype Upgrade Lab online. Use pedestals to grant or reset unlocks. Keyboard: E interact, Tab focus, Q cast. Controller: B interact, hold LT/L2 focus, RT/R2 cast."
@export var enable_dev_reset_hotkey: bool = true
@export var enable_dev_grant_hotkey: bool = true
@export var enable_feedback_test_hotkey: bool = true
@export var lab_unlock_ids: Array[String] = ["charged_firebolt", "piercing_ice_lance", "armor_trial_blessing"]
@export var feedback_test_ids: Array[String] = ["light_tick", "hit_collision", "player_hit", "full_charge", "guard_block", "heavy_impact", "low_health_warning"]

var feedback_test_index: int = 0
var previous_guard_value: int = 0
var previous_health_value: int = 0
var suppress_hit_feedback: bool = false


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	previous_guard_value = GameState.get_stat("guard")
	previous_health_value = GameState.get_stat("health")
	connect_feedback_signals()
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

	if enable_feedback_test_hotkey and key_event.physical_keycode == KEY_F5:
		get_viewport().set_input_as_handled()
		play_next_feedback_test()
		return

	if enable_dev_reset_hotkey and key_event.physical_keycode == KEY_F8:
		get_viewport().set_input_as_handled()
		reset_lab_state()
		return

	if enable_dev_grant_hotkey and key_event.physical_keycode == KEY_F6:
		get_viewport().set_input_as_handled()
		grant_lab_unlocks()
		return


func connect_feedback_signals() -> void:
	var stat_callable: Callable = Callable(self, "_on_game_state_stat_changed")
	if not GameState.stat_changed.is_connected(stat_callable):
		GameState.stat_changed.connect(stat_callable)


func _on_game_state_stat_changed(stat_name: String, value: int) -> void:
	if stat_name == "guard":
		handle_guard_feedback(value)
		return

	if stat_name == "health":
		handle_player_hit_feedback(value)


func handle_guard_feedback(value: int) -> void:
	if suppress_hit_feedback:
		previous_guard_value = value
		return

	if previous_guard_value > 0 and value < previous_guard_value:
		GameFeedback.play("guard_block", {"source": "Prototype Upgrade Lab Guard"})

	previous_guard_value = value


func handle_player_hit_feedback(value: int) -> void:
	if suppress_hit_feedback:
		previous_health_value = value
		return

	if previous_health_value > 0 and value < previous_health_value:
		GameFeedback.play("player_hit", {"source": "Prototype Upgrade Lab Health"})

	previous_health_value = value


func get_opening_message() -> String:
	var message: String = opening_message

	if OS.has_feature("editor"):
		var shortcuts: Array[String] = []
		if enable_feedback_test_hotkey:
			shortcuts.append("F5 cycles feedback presets")
		if enable_dev_grant_hotkey:
			shortcuts.append("F6 grants core lab upgrades")
		if enable_dev_reset_hotkey:
			shortcuts.append("F8 resets lab progression")

		if shortcuts.size() > 0:
			message += " " + "; ".join(shortcuts) + "."

	return message


func play_next_feedback_test() -> void:
	if feedback_test_ids.size() <= 0:
		show_message("No feedback presets configured for the lab.")
		return

	feedback_test_index = clamp(feedback_test_index, 0, feedback_test_ids.size() - 1)
	var feedback_id: String = feedback_test_ids[feedback_test_index]
	feedback_test_index = (feedback_test_index + 1) % feedback_test_ids.size()

	var feedback_data: Dictionary = GameFeedback.play(feedback_id, {"source": "Prototype Upgrade Lab Shortcut"})
	var label: String = str(feedback_data.get("label", feedback_id.capitalize()))
	show_message("Feedback test: " + label + " (" + feedback_id + ")")
	set_objective("Feel the haptic preset, then press F5 again to cycle the next one.")


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
	previous_health_value = GameState.get_stat("health")
	GameFeedback.play("light_tick", {"source": "Prototype Upgrade Lab Shortcut"})

	var parts: Array[String] = []
	if granted.size() > 0:
		parts.append("Granted: " + ", ".join(granted))
	if already_active.size() > 0:
		parts.append("Already active: " + ", ".join(already_active))

	if parts.size() <= 0:
		parts.append("No lab upgrades changed.")

	show_message("Lab shortcut | " + " ".join(parts))
	set_objective("Equip Firebolt or Ice Lance, then test the upgraded projectile on targets.")


func reset_lab_state() -> void:
	suppress_hit_feedback = true
	GameState.reset_run()
	previous_guard_value = GameState.get_stat("guard")
	previous_health_value = GameState.get_stat("health")
	suppress_hit_feedback = false
	reset_lab_targets()
	GameFeedback.play("light_tick", {"source": "Prototype Upgrade Lab Reset"})
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
