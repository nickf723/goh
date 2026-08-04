extends "res://scripts/ui/full_menu_shell_familiar.gd"
class_name FullMenuShellSettings


func render_system() -> void:
	var service: PlayerPreferenceService = _get_player_preference_service()
	if service == null:
		add_text_card(
			"Preferences Unavailable",
			"The current scene does not contain the shared player preference service.",
			"⚙",
			"System"
		)
		return

	var summary: Dictionary = service.get_summary()
	add_summary_card([
		"Profile settings " + str(summary.get("preference_count", 0)),
		"Changed " + str(summary.get("changed_count", 0)),
		"Defaults " + str(summary.get("default_count", 0)),
		"Auto-save " + ("On" if bool(summary.get("auto_save", true)) else "Off"),
	])
	add_text_card(
		"Profile-Wide Preferences",
		"These settings are stored outside Grace's save slot. Starting a new journey does not reset camera or motion preferences.",
		"⚙",
		"User Profile"
	)

	var current_category: String = ""
	var category_grid: GridContainer = null
	for row: Dictionary in service.get_rows():
		var category: String = str(row.get("category", "Preferences"))
		if category != current_category:
			current_category = category
			add_section_header(category.to_upper())
			category_grid = make_visual_grid(3)
			content_box.add_child(category_grid)
		if category_grid == null:
			continue
		var badge: String = str(row.get("value_label", "Default")).to_upper()
		badge += "  •  " + ("DEFAULT" if bool(row.get("is_default", false)) else "CHANGED")
		add_visual_action_tile(
			category_grid,
			str(row.get("icon", "◇")),
			str(row.get("label", "Preference")),
			badge,
			{
				"kind": "cycle_player_preference",
				"preference_id": str(row.get("id", "")),
			},
			str(row.get("description", "")) + "\nSelect to cycle through the available values."
		)

	add_section_header("RESET")
	var reset_grid: GridContainer = make_visual_grid(3)
	content_box.add_child(reset_grid)
	add_visual_action_tile(
		reset_grid,
		"↺",
		"Restore Defaults",
		"ALL CAMERA AND MOTION SETTINGS",
		{"kind": "reset_player_preferences"},
		"Restores the authored camera, feedback, and Focus-menu defaults, then saves them immediately."
	)
	add_visual_info_card(
		"i",
		"Current Scope",
		"Camera speed, right-stick deadzone, Focus-menu camera control, camera impact, and procedural motion pulses are configurable in v1.",
		"No gameplay balance changes"
	)


func activate_action(action: Dictionary) -> void:
	match str(action.get("kind", "")):
		"cycle_player_preference":
			_cycle_player_preference(str(action.get("preference_id", "")))
		"reset_player_preferences":
			_reset_player_preferences()
		_:
			super.activate_action(action)


func get_footer_text() -> String:
	if get_current_tab_id() == "system" and not is_assignment_active():
		return "LB/RB or Q/E: tabs  •  D-pad/Stick or WASD: move  •  A/Enter: cycle setting  •  B/Esc: back"
	return super.get_footer_text()


func _cycle_player_preference(preference_id: String) -> void:
	var service: PlayerPreferenceService = _get_player_preference_service()
	if service == null or preference_id == "":
		return
	var result: Dictionary = service.cycle_preference(preference_id, 1, true)
	if bool(result.get("ok", false)):
		_show_preference_message(
			str(result.get("id", preference_id)).replace("_", " ").capitalize()
			+ ": "
			+ str(result.get("label", "Updated"))
		)
	else:
		_show_preference_message(
			"Preference update failed: " + str(result.get("error", "unknown error"))
		)
	rebuild_menu()


func _reset_player_preferences() -> void:
	var service: PlayerPreferenceService = _get_player_preference_service()
	if service == null:
		return
	service.reset_defaults(true)
	_show_preference_message("Player preferences restored to defaults.")
	rebuild_menu()


func _get_player_preference_service() -> PlayerPreferenceService:
	var node: Node = find_first_node_named(
		get_tree().current_scene,
		"PlayerPreferences"
	)
	return node as PlayerPreferenceService


func _show_preference_message(text: String) -> void:
	if GameState.has_method("show_system_message"):
		GameState.call("show_system_message", text)
