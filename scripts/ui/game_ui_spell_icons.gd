extends "res://scripts/ui/game_ui_controller_prompts.gd"
class_name GameUISpellIcons

const SpellIcons = preload("res://scripts/ui/spell_icon_factory.gd")

var icon_spell_badges: Array[PanelContainer] = []
var icon_spell_quick_labels: Array[Label] = []
var icon_spell_equipped_labels: Array[Label] = []
var icon_spell_entries: Array[Dictionary] = []
var icon_equipped_row_count: int = 0
var icon_texture_row_count: int = 0


func rebuild_spell_rows(
	_spell_names: Array,
	selected_spell_index: int,
	selected_element: String
) -> void:
	if focus_spell_list == null:
		return
	var entries: Array[Dictionary] = _get_focus_spell_entries(
		selected_element
	)
	var next_signature: Array[String] = []
	for entry: Dictionary in entries:
		next_signature.append(
			str(entry.get("spell_id", ""))
			+ "|"
			+ str(entry.get("name", "Spell"))
		)

	if next_signature != focus_spell_signature:
		focus_spell_signature = next_signature.duplicate()
		focus_structure_rebuilds += 1
		clear_children(focus_spell_list)
		focus_cached_spell_rows.clear()
		focus_cached_spell_labels.clear()
		icon_spell_badges.clear()
		icon_spell_quick_labels.clear()
		icon_spell_equipped_labels.clear()
		if entries.is_empty():
			var empty_data: Dictionary = _make_icon_spell_row({
				"name": "No learned spells",
				"spell_id": "",
				"element": selected_element,
			})
			focus_spell_list.add_child(
				empty_data.get("row") as PanelContainer
			)
			focus_cached_spell_rows.append(
				empty_data.get("row") as PanelContainer
			)
			focus_cached_spell_labels.append(
				empty_data.get("label") as Label
			)
			icon_spell_badges.append(
				empty_data.get("badge") as PanelContainer
			)
			icon_spell_quick_labels.append(
				empty_data.get("quick_label") as Label
			)
			icon_spell_equipped_labels.append(
				empty_data.get("equipped_label") as Label
			)
		else:
			for entry: Dictionary in entries:
				var row_data: Dictionary = _make_icon_spell_row(entry)
				focus_spell_list.add_child(
					row_data.get("row") as PanelContainer
				)
				focus_cached_spell_rows.append(
					row_data.get("row") as PanelContainer
				)
				focus_cached_spell_labels.append(
					row_data.get("label") as Label
				)
				icon_spell_badges.append(
					row_data.get("badge") as PanelContainer
				)
				icon_spell_quick_labels.append(
					row_data.get("quick_label") as Label
				)
				icon_spell_equipped_labels.append(
					row_data.get("equipped_label") as Label
				)

	icon_spell_entries = entries.duplicate(true)
	icon_equipped_row_count = 0
	icon_texture_row_count = 0
	if entries.is_empty():
		_apply_empty_icon_row(selected_element)
		return

	var element_color: Color = get_element_color(selected_element)
	for index: int in range(entries.size()):
		var entry: Dictionary = entries[index]
		var highlighted: bool = index == selected_spell_index
		var equipped: bool = bool(entry.get("equipped", false))
		if equipped:
			icon_equipped_row_count += 1
		var row: PanelContainer = focus_cached_spell_rows[index]
		var label: Label = focus_cached_spell_labels[index]
		var badge: PanelContainer = icon_spell_badges[index]
		var quick_label: Label = icon_spell_quick_labels[index]
		var equipped_label: Label = icon_spell_equipped_labels[index]
		row.add_theme_stylebox_override(
			"panel",
			_get_icon_spell_row_style(
				selected_element,
				element_color,
				highlighted,
				equipped
			)
		)
		row.modulate = Color(
			1.0,
			1.0,
			1.0,
			1.0 if highlighted or equipped else 0.8
		)
		SpellIcons.update_badge(
			badge,
			entry,
			highlighted,
			equipped
		)
		if bool(badge.get_meta("spell_icon_has_texture", false)):
			icon_texture_row_count += 1
		label.text = (
			("›  " if highlighted else "   ")
			+ str(entry.get("name", "Spell"))
		)
		label.add_theme_color_override(
			"font_color",
			Color(1.0, 0.82, 0.36, 1.0)
			if equipped
			else (
				Color(0.96, 0.98, 1.0, 1.0)
				if highlighted
				else TEXT_MAIN
			)
		)
		var quick_slots: String = _get_quick_slots_for_spell_id(
			str(entry.get("spell_id", ""))
		)
		quick_label.text = (
			"SLOT " + quick_slots
			if quick_slots != ""
			else ""
		)
		quick_label.visible = quick_slots != ""
		quick_label.add_theme_color_override(
			"font_color",
			Color(0.54, 0.74, 1.0, 0.94)
		)
		equipped_label.visible = equipped
		equipped_label.text = "★ EQUIPPED"


func _get_focus_spell_entries(element: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var caster: Node = _get_player_ability_caster()
	if caster == null:
		return entries
	var loadout_value: Variant = caster.get("loadout")
	if not loadout_value is AbilityLoadout:
		return entries
	var loadout: AbilityLoadout = loadout_value as AbilityLoadout
	var current_index: int = int(caster.get("current_ability_index"))
	var indices: Array[int] = []
	if caster.has_method("get_spell_indices_for_element"):
		var indices_value: Variant = caster.call(
			"get_spell_indices_for_element",
			element
		)
		if indices_value is Array:
			for raw_index: Variant in indices_value as Array:
				indices.append(int(raw_index))
	else:
		for index: int in range(loadout.get_equipped_ability_count()):
			var candidate: AbilityDefinition = loadout.get_equipped_ability(index)
			if candidate != null and candidate.element == element:
				indices.append(index)
	for global_index: int in indices:
		var ability: AbilityDefinition = loadout.get_equipped_ability(global_index)
		if ability == null:
			continue
		entries.append(SpellIcons.entry_from_ability(
			ability,
			global_index,
			global_index == current_index
		))
	return entries


func _make_icon_spell_row(entry: Dictionary) -> Dictionary:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0.0, 45.0)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 4)
	row.add_child(margin)
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)

	var badge: PanelContainer = SpellIcons.create_badge(
		entry,
		34.0,
		false,
		false
	)
	content.add_child(badge)

	var label := Label.new()
	label.text = str(entry.get("name", "Spell"))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", 12)
	content.add_child(label)

	var quick_label := Label.new()
	quick_label.text = ""
	quick_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	quick_label.add_theme_font_size_override("font_size", 8)
	quick_label.visible = false
	content.add_child(quick_label)

	var equipped_label := Label.new()
	equipped_label.text = "★ EQUIPPED"
	equipped_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	equipped_label.add_theme_font_size_override("font_size", 8)
	equipped_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.72, 0.22, 1.0)
	)
	equipped_label.visible = false
	content.add_child(equipped_label)
	return {
		"row": row,
		"label": label,
		"badge": badge,
		"quick_label": quick_label,
		"equipped_label": equipped_label,
	}


func _apply_empty_icon_row(selected_element: String) -> void:
	if focus_cached_spell_rows.is_empty():
		return
	var row: PanelContainer = focus_cached_spell_rows[0]
	var label: Label = focus_cached_spell_labels[0]
	var badge: PanelContainer = icon_spell_badges[0]
	row.add_theme_stylebox_override(
		"panel",
		_get_focus_style(
			"spell_icon_empty",
			Color(0.018, 0.026, 0.042, 0.86),
			Color(0.18, 0.25, 0.38, 0.5),
			1,
			9
		)
	)
	SpellIcons.update_badge(badge, {
		"name": "No learned spells",
		"spell_id": "",
		"element": selected_element,
	}, false, false)
	label.text = "No learned spells in this element"
	label.add_theme_color_override("font_color", TEXT_SOFT)
	icon_spell_quick_labels[0].visible = false
	icon_spell_equipped_labels[0].visible = false


func _get_icon_spell_row_style(
	element: String,
	color: Color,
	highlighted: bool,
	equipped: bool
) -> StyleBoxFlat:
	if equipped:
		return _get_focus_style(
			"spell_icon_equipped|" + element + "|" + str(highlighted),
			Color(0.12, 0.064, 0.018, 0.98),
			Color(1.0, 0.68, 0.18, 1.0),
			3 if highlighted else 2,
			9
		)
	if highlighted:
		return _get_focus_style(
			"spell_icon_highlighted|" + element,
			Color(color.r * 0.2, color.g * 0.2, color.b * 0.2, 0.94),
			Color(color.r, color.g, color.b, 0.96),
			2,
			9
		)
	return _get_focus_style(
		"spell_icon_normal|" + element,
		Color(0.022, 0.032, 0.049, 0.86),
		Color(color.r, color.g, color.b, 0.34),
		1,
		9
	)


func get_spell_icon_presentation_debug_data() -> Dictionary:
	var current_index: int = -1
	var caster: Node = _get_player_ability_caster()
	if caster != null:
		current_index = int(caster.get("current_ability_index"))
	return {
		"enabled": true,
		"icon_rows": icon_spell_entries.size(),
		"badge_count": icon_spell_badges.size(),
		"equipped_rows": icon_equipped_row_count,
		"texture_rows": icon_texture_row_count,
		"current_ability_index": current_index,
		"entries": icon_spell_entries.duplicate(true),
	}
