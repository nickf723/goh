extends "res://scripts/ui/full_menu_shell_plants.gd"
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
		"Reset Current Category",
		"RESTORE DEFAULTS",
		{"kind": "reset_player_preference_category"},
		"Restores every preference in the current category to its authored default."
	)
	add_visual_action_tile(
		reset_grid,
		"↺",
		"Reset All Preferences",
		"RESTORE ALL DEFAULTS",
		{"kind": "reset_all_player_preferences"},
		"Restores every profile-wide preference to its authored default."
	)


func activate_action(action: Dictionary) -> void:
	match str(action.get("kind", "")):
		"cycle_player_preference":
			_cycle_player_preference(str(action.get("preference_id", "")))
		"reset_player_preference_category":
			_reset_player_preference_category()
		"reset_all_player_preferences":
			_reset_all_player_preferences()
		_:
			super.activate_action(action)


func _cycle_player_preference(preference_id: String) -> void:
	var service: PlayerPreferenceService = _get_player_preference_service()
	if service == null:
		return
	var result: Dictionary = service.cycle_value(preference_id, 1, true)
	if bool(result.get("ok", false)):
		_show_settings_message(
			str(result.get("label", preference_id.capitalize()))
			+ ": "
			+ str(result.get("value_label", result.get("value", "Updated")))
		)
	else:
		_show_settings_message(
			"Preference update failed: " + str(result.get("error", "unknown error"))
		)
	_refresh_settings_menu()


func _reset_player_preference_category() -> void:
	var service: PlayerPreferenceService = _get_player_preference_service()
	if service == null:
		return
	var rows: Array[Dictionary] = service.get_rows()
	if rows.is_empty():
		return
	var category: String = str(rows[0].get("category", ""))
	if category == "":
		return
	service.reset_category(category, true)
	_show_settings_message(category + " preferences reset.")
	_refresh_settings_menu()


func _reset_all_player_preferences() -> void:
	var service: PlayerPreferenceService = _get_player_preference_service()
	if service == null:
		return
	service.reset_all(true)
	_show_settings_message("All profile preferences reset.")
	_refresh_settings_menu()


func _get_player_preference_service() -> PlayerPreferenceService:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return null
	return player.get_node_or_null("PlayerPreferenceService") as PlayerPreferenceService


func _refresh_settings_menu() -> void:
	refresh_menu_data()
	rebuild_menu()


func _show_settings_message(text: String) -> void:
	if GameState.has_method("show_system_message"):
		GameState.call("show_system_message", text)
