extends "res://scripts/ui/full_menu_shell_key_items.gd"
class_name FullMenuShellMastery

const SpellcastingMasteryServiceScript = preload(
	"res://scripts/progression/spellcasting_mastery_service.gd"
)


func render_magic() -> void:
	super.render_magic()
	if is_assigning_spell():
		return
	_render_spellcasting_mastery()


func activate_action(action: Dictionary) -> void:
	match str(action.get("kind", "")):
		"debug_advance_warlock_mastery":
			_debug_advance_warlock_mastery()
		"debug_master_all_spellcasting":
			_debug_master_all_spellcasting()
		"debug_reset_spellcasting_mastery":
			_debug_reset_spellcasting_mastery()
		_:
			super.activate_action(action)


func _render_spellcasting_mastery() -> void:
	var mastery_data: Dictionary = menu_data.get("spellcasting_mastery", {})
	var summary: Dictionary = mastery_data.get("summary", {})
	var rows: Array = mastery_data.get("rows", [])

	add_section_header("SPELLCASTING TRADITIONS")
	add_summary_card([
		"Initiated " + str(summary.get("initiated_count", 0)) + "/" + str(summary.get("tradition_count", 8)),
		"Mastered " + str(summary.get("mastered_count", 0)) + "/" + str(summary.get("tradition_count", 8)),
		"Milestones " + str(summary.get("achievement_unlocked", 0)) + "/" + str(summary.get("achievement_total", 32)),
		"Active capstones " + str((summary.get("active_capstones", []) as Array).size()),
	])

	for row_variant: Variant in rows:
		if row_variant is Dictionary:
			_render_spellcasting_tradition_card(row_variant as Dictionary)

	if OS.is_debug_build():
		_render_mastery_debug_controls()


func _render_spellcasting_tradition_card(row: Dictionary) -> void:
	var display_name: String = str(row.get("display_name", "Tradition"))
	var relationship: String = str(row.get("relationship", ""))
	var rank: int = int(row.get("rank", 0))
	var rank_max: int = int(row.get("rank_max", 4))
	var current_stage: String = str(row.get("current_stage_name", "Uninitiated"))
	var body_parts: Array[String] = []
	if relationship != "":
		body_parts.append(relationship)

	body_parts.append("Milestones: " + _get_stage_track(row))
	var compatible_spells: Array[String] = _copy_string_array(
		row.get("compatible_spell_names", [])
	)
	if compatible_spells.is_empty():
		body_parts.append("Compatible learned spells: none yet")
	else:
		body_parts.append(
			"Compatible learned spells: "
			+ ", ".join(compatible_spells)
		)

	var capstone: Dictionary = row.get("capstone", {})
	var capstone_name: String = str(capstone.get("display_name", "Capstone"))
	var capstone_description: String = str(capstone.get("description", ""))
	match str(row.get("capstone_state", "locked")):
		"active":
			body_parts.append("Capstone active: " + capstone_name)
		"reserved":
			body_parts.append("Mastered. Reserved capstone: " + capstone_name)
		_:
			body_parts.append("Capstone at Mastery: " + capstone_name)
	if capstone_description != "":
		body_parts.append(capstone_description)

	var subtitle: String = current_stage.to_upper() + "  •  " + str(rank) + "/" + str(rank_max)
	if str(row.get("baseline_stage_id", "")) != "":
		subtitle = "STORY BASELINE  •  " + subtitle
	add_text_card(
		display_name,
		"\n".join(body_parts),
		str(row.get("icon", "✦")),
		subtitle
	)


func _render_mastery_debug_controls() -> void:
	add_section_header("DEVELOPER MASTERY CONTROLS")
	var grid: GridContainer = make_visual_grid(3)
	content_box.add_child(grid)
	var warlock_rank: int = SpellcastingMasteryServiceScript.get_rank("warlock")
	var warlock_next: String = SpellcastingMasteryServiceScript.get_next_stage_id("warlock")
	var next_label: String = (
		"Complete"
		if warlock_next == ""
		else warlock_next.capitalize()
	)
	add_visual_action_tile(
		grid,
		"♢",
		"Advance Warlock",
		"RANK " + str(warlock_rank) + "/4  •  NEXT " + next_label.to_upper(),
		{"kind": "debug_advance_warlock_mastery"},
		"Advances exactly one ordered Warlock milestone. Mastery unlocks the production Divine Incarnation requirement."
	)
	add_visual_action_tile(
		grid,
		"✦",
		"Master All",
		"32 MILESTONES",
		{"kind": "debug_master_all_spellcasting"},
		"Completes all eight traditions for systems and menu testing."
	)
	add_visual_action_tile(
		grid,
		"↺",
		"Reset Mastery",
		"KEEP STORY BASELINE",
		{"kind": "debug_reset_spellcasting_mastery"},
		"Clears mastery progress, then restores Sorcery and Wizardry Initiation."
	)


func _debug_advance_warlock_mastery() -> void:
	var result: Dictionary = SpellcastingMasteryServiceScript.advance(
		"warlock",
		{"source": "field_kit_debug"}
	)
	if bool(result.get("already_complete", false)):
		_show_mastery_message("Warlock Mastery is already complete.")
	elif not bool(result.get("ok", false)):
		_show_mastery_message(
			"Warlock advancement failed: " + str(result.get("error", "unknown error"))
		)
	_refresh_mastery_menu()


func _debug_master_all_spellcasting() -> void:
	var result: Dictionary = SpellcastingMasteryServiceScript.master_all_for_debug()
	if bool(result.get("ok", false)):
		_show_mastery_message("All spellcasting traditions mastered for debugging.")
	else:
		_show_mastery_message("Debug mastery did not complete every tradition.")
	_refresh_mastery_menu()


func _debug_reset_spellcasting_mastery() -> void:
	SpellcastingMasteryServiceScript.reset_all(true)
	_show_mastery_message("Spellcasting mastery reset to Grace's story baseline.")
	_refresh_mastery_menu()


func _refresh_mastery_menu() -> void:
	refresh_menu_data()
	rebuild_menu()


func _show_mastery_message(text: String) -> void:
	if GameState.has_method("show_system_message"):
		GameState.call("show_system_message", text)


func _get_stage_track(row: Dictionary) -> String:
	var labels: Array[String] = []
	var stage_rows: Variant = row.get("stage_rows", [])
	if not stage_rows is Array:
		return "Uninitiated"
	for stage_variant: Variant in stage_rows as Array:
		if not stage_variant is Dictionary:
			continue
		var stage: Dictionary = stage_variant as Dictionary
		var marker: String = "◆" if bool(stage.get("unlocked", false)) else "◇"
		labels.append(marker + " " + str(stage.get("name", "Stage")))
	return "  ·  ".join(labels)


func _copy_string_array(raw_values: Variant) -> Array[String]:
	var values: Array[String] = []
	if not raw_values is Array:
		return values
	for raw_value: Variant in raw_values as Array:
		var value: String = str(raw_value)
		if value != "":
			values.append(value)
	return values
