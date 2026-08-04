extends "res://scripts/ui/full_menu_shell_mastery.gd"

const BondedFamiliarRosterScript: Script = preload(
	"res://scripts/summons/bonded_familiar_roster.gd"
)


func render_magic() -> void:
	super.render_magic()
	if is_assigning_spell():
		return
	_render_familiar_mastery()


func activate_action(action: Dictionary) -> void:
	match str(action.get("kind", "")):
		"equip_bonded_familiar":
			_equip_bonded_familiar(str(action.get("animal_id", "")))
		"clear_bonded_familiar":
			_clear_bonded_familiar()
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
	var familiar_data: Dictionary = _familiar_dictionary(menu_data.get("familiar_mastery", {}))
	var rows: Array = []
	var rows_value: Variant = familiar_data.get("rows", [])
	if rows_value is Array:
		rows = rows_value as Array
	var summary: Dictionary = _familiar_dictionary(familiar_data.get("summary", {}))
	var bonded_roster: BondedFamiliarRoster = _get_bonded_roster()
	var bonded_rows: Array[Dictionary] = (
		bonded_roster.get_roster_rows()
		if bonded_roster != null
		else []
	)
	var bonded_summary: Dictionary = (
		bonded_roster.get_summary()
		if bonded_roster != null
		else {}
	)
	var bonded_equipped_name: String = str(
		bonded_summary.get("equipped_name", "None")
	)
	var blueprint_equipped_name: String = str(
		familiar_data.get("equipped_name", "None")
	)
	var summon_slot_name: String = (
		bonded_equipped_name
		if bonded_equipped_name != "None"
		else blueprint_equipped_name
	)

	add_section_header("BONDED FAMILIARS")
	add_summary_card([
		"Eligible named animals " + str(bonded_rows.size()),
		"Summon slot " + summon_slot_name,
		"One active familiar",
		"Bond and rescue animals in the world",
	])
	if bonded_rows.is_empty():
		add_text_card(
			"No Bonded Animals Yet",
			"Rescue an animal, earn its trust, and form a bond. Named companions will appear here automatically.",
			"✦",
			"World relationships"
		)
	else:
		for bonded_value: Variant in bonded_rows:
			if bonded_value is Dictionary:
				_render_bonded_familiar_row(bonded_value as Dictionary)

	add_section_header("SPECIES FAMILIAR BLUEPRINTS")
	add_summary_card([
		"Unlocked " + str(summary.get("familiars_unlocked", 0)) + "/" + str(summary.get("familiars_available", rows.size())),
		"Prepared blueprint " + blueprint_equipped_name,
		"Presence capacity 1",
		"Named familiars override the prepared blueprint",
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


func _render_bonded_familiar_row(row: Dictionary) -> void:
	var animal_id: String = str(row.get("animal_id", ""))
	var animal_name: String = str(row.get("animal_name", animal_id.capitalize()))
	var species_name: String = str(row.get("species_name", "Animal"))
	var equipped: bool = bool(row.get("equipped", false))
	var manifested: bool = bool(row.get("manifested", false))
	var trust_percent: int = roundi(clampf(float(row.get("trust", 0.0)), 0.0, 1.0) * 100.0)
	var familiarity_percent: int = roundi(
		clampf(float(row.get("familiarity", 0.0)), 0.0, 1.0) * 100.0
	)
	var subtitle: String = "EQUIPPED" if equipped else "BONDED"
	if manifested:
		subtitle = "MANIFESTED"
	add_text_card(
		animal_name,
		species_name
		+ "  •  " + str(row.get("trust_tier", "Bonded"))
		+ "\nTrust " + str(trust_percent) + "%"
		+ "  •  Familiarity " + str(familiarity_percent) + "%"
		+ "  •  Commands: Follow, Stay, Come Here, Go There",
		str(row.get("icon", "✦")),
		subtitle
	)
	var control_grid: GridContainer = make_visual_grid(4)
	content_box.add_child(control_grid)
	add_visual_action_tile(
		control_grid,
		"◆" if equipped else "✦",
		"Equip " + animal_name,
		"ACTIVE FAMILIAR" if equipped else "SELECT NAMED FAMILIAR",
		{"kind": "equip_bonded_familiar", "animal_id": animal_id},
		"Summon Familiar will manifest this individual and preserve its name, species, trust, and bond."
	)
	if equipped:
		add_visual_action_tile(
			control_grid,
			"◇",
			"Use Blueprint Instead",
			"CLEAR NAMED SLOT",
			{"kind": "clear_bonded_familiar"},
			"Restores the previously prepared species familiar blueprint."
		)


func _render_familiar_row(row: Dictionary) -> void:
	var species_id: String = str(row.get("species_id", ""))
	var display_name: String = str(row.get("display_name", species_id.capitalize()))
	var unlocked: bool = bool(row.get("unlocked", false))
	var equipped: bool = bool(row.get("equipped", false))
	var rank: int = int(row.get("rank", 0))
	var rank_title: String = str(row.get("rank_title", "Unknown"))
	var loadout: Dictionary = _familiar_dictionary(row.get("loadout", {}))
	var selected_techniques: Array[String] = _familiar_string_array(
		loadout.get("technique_ids", [])
	)
	var subtitle: String = "LOCKED"
	if unlocked:
		subtitle = "EQUIPPED" if equipped else "UNLOCKED"
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
			"Record enough unique behavior to form a stable summon blueprint.",
			"Study progression"
		)
		_render_locked_techniques(row)
		return
	var control_grid: GridContainer = make_visual_grid(4)
	content_box.add_child(control_grid)
	var equip_badge: String = "SELECT BLUEPRINT"
	if equipped:
		equip_badge = "ACTIVE BLUEPRINT"
	add_visual_action_tile(
		control_grid,
		"✦",
		"Equip " + display_name,
		equip_badge,
		{"kind": "equip_familiar", "species_id": species_id},
		"The summon spell will create this prepared species familiar and clear any named familiar slot."
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
	if not technique_rows_value is Array:
		return
	for technique_value: Variant in technique_rows_value as Array:
		if not technique_value is Dictionary:
			continue
		var technique: Dictionary = technique_value as Dictionary
		var technique_id: String = str(technique.get("id", ""))
		var technique_unlocked: bool = bool(technique.get("unlocked", false))
		var technique_equipped: bool = bool(technique.get("equipped", false))
		if technique_unlocked:
			var technique_icon: String = "◇"
			var technique_badge: String = "AVAILABLE"
			if technique_equipped:
				technique_icon = "◆"
				technique_badge = "EQUIPPED"
			add_visual_action_tile(
				technique_grid,
				technique_icon,
				str(technique.get("label", technique_id.capitalize())),
				technique_badge,
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


func _equip_bonded_familiar(animal_id: String) -> void:
	var roster: BondedFamiliarRoster = _get_bonded_roster()
	if roster == null:
		return
	var result: Dictionary = roster.equip_animal(animal_id, true)
	var message: String = "Bonded familiar equip failed: " + str(result.get("error", "unknown error"))
	if bool(result.get("ok", false)):
		var record: Dictionary = _familiar_dictionary(result.get("record", {}))
		message = "Equipped " + str(record.get("animal_name", animal_id.capitalize())) + " as Grace's familiar."
	_show_familiar_message(message)
	_refresh_familiar_menu()


func _clear_bonded_familiar() -> void:
	var roster: BondedFamiliarRoster = _get_bonded_roster()
	if roster == null:
		return
	var result: Dictionary = roster.clear_equipped(true, true)
	var restored: String = str(result.get("restored_species_id", ""))
	var message: String = "Named familiar slot cleared."
	if restored != "":
		message += " Restored " + restored.replace("_", " ").capitalize() + " blueprint."
	_show_familiar_message(message)
	_refresh_familiar_menu()


func _equip_familiar(species_id: String) -> void:
	var roster: BondedFamiliarRoster = _get_bonded_roster()
	if roster != null:
		roster.clear_equipped(false, true)
	var service: Node = get_node_or_null("/root/SpeciesKnowledge")
	if service == null or not service.has_method("set_equipped_familiar_species"):
		return
	var result: Dictionary = _familiar_dictionary(
		service.call("set_equipped_familiar_species", species_id)
	)
	var message: String = "Familiar equip failed: " + str(result.get("error", "unknown error"))
	if bool(result.get("ok", false)):
		message = "Equipped " + species_id.capitalize() + " familiar blueprint."
	_show_familiar_message(message)
	_refresh_familiar_menu()


func _cycle_familiar_field(species_id: String, field_name: String) -> void:
	var service: Node = get_node_or_null("/root/SpeciesKnowledge")
	if service == null:
		return
	var method_name: String = "cycle_familiar_" + field_name
	if not service.has_method(method_name):
		return
	var result: Dictionary = _familiar_dictionary(
		service.call(method_name, species_id, 1)
	)
	if bool(result.get("ok", false)):
		var loadout: Dictionary = _familiar_dictionary(result.get("loadout", {}))
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
	var result: Dictionary = _familiar_dictionary(
		service.call("toggle_familiar_technique", species_id, technique_id)
	)
	var message: String = "Technique update failed: " + str(result.get("error", "unknown error"))
	if bool(result.get("ok", false)):
		message = "Updated " + technique_id.replace("_", " ").capitalize() + "."
	_show_familiar_message(message)
	_refresh_familiar_menu()


func _get_bonded_roster() -> BondedFamiliarRoster:
	if get_tree() == null:
		return null
	return BondedFamiliarRosterScript.get_or_create(
		get_tree()
	) as BondedFamiliarRoster


func _refresh_familiar_menu() -> void:
	refresh_menu_data()
	rebuild_menu()


func _show_familiar_message(text: String) -> void:
	if GameState.has_method("show_system_message"):
		GameState.call("show_system_message", text)


func _familiar_dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _familiar_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value:
			var text: String = str(raw)
			if text != "":
				result.append(text)
	return result
