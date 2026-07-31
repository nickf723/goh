extends "res://scripts/ui/full_menu_shell_mastery.gd"
class_name FullMenuShellFamiliar


func render_magic() -> void:
	super.render_magic()
	if is_assigning_spell():
		return
	_render_familiar_mastery()


func activate_action(action: Dictionary) -> void:
	match str(action.get("kind", "")):
		"equip_familiar":
			_equip_familiar(str(action.get("species_id", "")))
		"cycle_familiar_role":
			_cycle_familiar_field(str(action.get("species_id", "")), "role")
		"cycle_familiar_temperament":
			_cycle_familiar_field(str(action.get("species_id", "")), "temperament")
		"cycle_familiar_command":
			_cycle_familiar_field(str(action.get("species_id", "")), "command")
		"toggle_familiar_technique":
			_toggle_familiar_technique(
				str(action.get("species_id", "")),
				str(action.get("technique_id", ""))
			)
		_:
			super.activate_action(action)


func get_footer_text() -> String:
	if get_current_tab_id() == "magic" and not is_assignment_active():
		return "LB/RB or Q/E: tabs  •  D-pad/Stick or WASD: move  •  A/Enter: configure  •  B/Esc: back"
	return super.get_footer_text()


func _render_familiar_mastery() -> void:
	var familiar_data: Dictionary = menu_data.get("familiar_mastery", {})
	var rows_value: Variant = familiar_data.get("rows", [])
	var rows: Array = rows_value as Array if rows_value is Array else []
	var summary: Dictionary = familiar_data.get("summary", {})
	add_section_header("FAMILIAR BLUEPRINTS")
	add_summary_card([
		"Unlocked " + str(summary.get("familiars_unlocked", 0)) + "/" + str(summary.get("familiars_available", rows.size())),
		"Equipped " + str(familiar_data.get("equipped_name", "None")),
		"Presence capacity 1",
		"Prepared outside combat",
	])
	if rows.is_empty():
		add_text_card(
			"No Familiar Blueprints",
			"Study creatures to translate their behavior into summonable forms.",
			"◇",
			"Creature Mastery"
		)
		return
	for row_value: Variant in rows:
		if row_value is Dictionary:
			_render_familiar_row(row_value as Dictionary)


func _render_familiar_row(row: Dictionary) -> void:
	var species_id: String = str(row.get("species_id", ""))
	var display_name: String = str(row.get("display_name", species_id.capitalize()))
	var unlocked: bool = bool(row.get("unlocked", false))
	var equipped: bool = bool(row.get("equipped", false))
	var rank: int = int(row.get("rank", 0))
	var rank_title: String = str(row.get("rank_title", "Unknown"))
	var loadout: Dictionary = row.get("loadout", {})
	var selected_techniques: Array[String] = _familiar_string_array(
		loadout.get("technique_ids", [])
	)
	var subtitle: String = (
		("EQUIPPED" if equipped else "UNLOCKED")
		if unlocked
		else "LOCKED"
	)
	subtitle += "  •  " + rank_title.to_upper() + " RANK " + str(rank)
	add_text_card(
		display_name,
		str(row.get("summary", ""))
		+ "\nPresence cost: " + str(row.get("presence_cost", 1))
		+ "  •  Technique slots: " + str(selected_techniques.size()) + "/" + str(row.get("max_techniques", 1)),
		str(row.get("icon", "◇")),
		subtitle
	)
	if not unlocked:
		add_visual_info_card(
			"🔒",
			"Familiar Locked",
			"Record enough unique Gremlin behavior to form a stable summon blueprint.",
			"Study progression"
		)
		_render_locked_techniques(row)
		return
	var control_grid: GridContainer = make_visual_grid(4)
	content_box.add_child(control_grid)
	add_visual_action_tile(
		control_grid,
		"✦",
		"Equip " + display_name,
		"ACTIVE BLUEPRINT" if equipped else "SELECT BLUEPRINT",
		{"kind": "equip_familiar", "species_id": species_id},
		"The summon spell will create this prepared familiar."
	)
	add_visual_action_tile(
		control_grid,
		"⚔",
		"Role",
		str(loadout.get("role", "skirmisher")).replace("_", " ").to_upper(),
		{"kind": "cycle_familiar_role", "species_id": species_id},
		"Cycles the familiar's group-AI role and target priorities."
	)
	add_visual_action_tile(
		control_grid,
		"◈",
		"Temperament",
		str(loadout.get("temperament", "balanced")).to_upper(),
		{"kind": "cycle_familiar_temperament", "species_id": species_id},
		"Adjusts how readily the creature commits, retreats, or takes risks."
	)
	add_visual_action_tile(
		control_grid,
		"⌁",
		"Opening Command",
		str(loadout.get("command", "ASSIST")).to_upper(),
		{"kind": "cycle_familiar_command", "species_id": species_id},
		"Rally escorts Grace, Focus obeys lock-on, Assist allocates targets, and Hold defends its position."
	)
	add_section_header(display_name.to_upper() + " TECHNIQUES")
	var technique_grid: GridContainer = make_visual_grid(4)
	content_box.add_child(technique_grid)
	var technique_rows_value: Variant = row.get("techniques", [])
	if technique_rows_value is Array:
		for technique_value: Variant in technique_rows_value as Array:
			if not technique_value is Dictionary:
				continue
			var technique: Dictionary = technique_value as Dictionary
			var technique_id: String = str(technique.get("id", ""))
			var technique_unlocked: bool = bool(technique.get("unlocked", false))
			var technique_equipped: bool = bool(technique.get("equipped", false))
			if technique_unlocked:
				add_visual_action_tile(
					technique_grid,
					"◆" if technique_equipped else "◇",
					str(technique.get("label", technique_id.capitalize())),
					"EQUIPPED" if technique_equipped else "AVAILABLE",
					{
						"kind": "toggle_familiar_technique",
						"species_id": species_id,
						"technique_id": technique_id,
					},
					str(technique.get("description", ""))
				)
			else:
				add_visual_info_card(
					"🔒",
					str(technique.get("label", technique_id.capitalize())),
					str(technique.get("description", "")),
					"Requires " + str(technique.get("unlock_id", "more study")).replace("_", " ").capitalize()
				)


func _render_locked_techniques(row: Dictionary) -> void:
	var technique_rows_value: Variant = row.get("techniques", [])
	if not technique_rows_value is Array:
		return
	var labels: Array[String] = []
	for technique_value: Variant in technique_rows_value as Array:
		if technique_value is Dictionary:
			labels.append(str((technique_value as Dictionary).get("label", "Technique")))
	if not labels.is_empty():
		add_text_card(
			"Potential Techniques",
			", ".join(labels),
			"◇",
			"Study preview"
		)


func _equip_familiar(species_id: String) -> void:
	var service: Node = get_node_or_null("/root/SpeciesKnowledge")
	if service == null or not service.has_method("set_equipped_familiar_species"):
		return
	var result_value: Variant = service.call("set_equipped_familiar_species", species_id)
	var result: Dictionary = result_value as Dictionary if result_value is Dictionary else {}
	_show_familiar_message(
		("Equipped " + species_id.capitalize() + " familiar.")
		if bool(result.get("ok", false))
		else "Familiar equip failed: " + str(result.get("error", "unknown error"))
	)
	_refresh_familiar_menu()


func _cycle_familiar_field(species_id: String, field_name: String) -> void:
	var service: Node = get_node_or_null("/root/SpeciesKnowledge")
	if service == null:
		return
	var method_name: String = "cycle_familiar_" + field_name
	if not service.has_method(method_name):
		return
	var result_value: Variant = service.call(method_name, species_id, 1)
	var result: Dictionary = result_value as Dictionary if result_value is Dictionary else {}
	if bool(result.get("ok", false)):
		var loadout: Dictionary = result.get("loadout", {})
		_show_familiar_message(
			field_name.capitalize() + ": " + str(loadout.get(field_name, "updated")).replace("_", " ").capitalize()
		)
	else:
		_show_familiar_message(
			"Familiar update failed: " + str(result.get("error", "unknown error"))
		)
	_refresh_familiar_menu()


func _toggle_familiar_technique(species_id: String, technique_id: String) -> void:
	var service: Node = get_node_or_null("/root/SpeciesKnowledge")
	if service == null or not service.has_method("toggle_familiar_technique"):
		return
	var result_value: Variant = service.call("toggle_familiar_technique", species_id, technique_id)
	var result: Dictionary = result_value as Dictionary if result_value is Dictionary else {}
	_show_familiar_message(
		("Updated " + technique_id.replace("_", " ").capitalize() + ".")
		if bool(result.get("ok", false))
		else "Technique update failed: " + str(result.get("error", "unknown error"))
	)
	_refresh_familiar_menu()


func _refresh_familiar_menu() -> void:
	refresh_menu_data()
	rebuild_menu()


func _show_familiar_message(text: String) -> void:
	if GameState.has_method("show_system_message"):
		GameState.call("show_system_message", text)


func _familiar_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value as Array:
			result.append(str(raw))
	return result
