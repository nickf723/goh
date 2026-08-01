extends "res://scripts/ui/full_menu_shell_items_v1_legacy.gd"

# Keep the large Items workspace stable while correcting record-name fallback.
# Godot Strings do not expose to_string(); str(...) is the universal conversion.


func _add_relic_record_column(
	parent: Container,
	title_text: String,
	icon_text: String,
	rows_value: Variant,
	empty_text: String
) -> void:
	var panel: PanelContainer = _make_magic_subpanel()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 7)
	margin.add_child(stack)
	var title: Label = Label.new()
	title.text = icon_text + "  " + title_text
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", ACTIVE_SELECTION_BORDER)
	stack.add_child(title)

	var rows: Array[Dictionary] = _items_dictionary_array(rows_value)
	if rows.is_empty():
		var empty: Label = Label.new()
		empty.text = empty_text
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_font_size_override("font_size", 11)
		empty.add_theme_color_override("font_color", TEXT_DIM)
		stack.add_child(empty)
		return

	for row: Dictionary in rows.slice(0, mini(rows.size(), 6)):
		var card: PanelContainer = PanelContainer.new()
		card.add_theme_stylebox_override(
			"panel",
			make_panel_style(
				Color(0.055, 0.07, 0.095, 0.88),
				CARD_BORDER,
				1,
				8
			)
		)
		stack.add_child(card)
		var card_margin: MarginContainer = MarginContainer.new()
		card_margin.add_theme_constant_override("margin_left", 8)
		card_margin.add_theme_constant_override("margin_top", 6)
		card_margin.add_theme_constant_override("margin_right", 8)
		card_margin.add_theme_constant_override("margin_bottom", 6)
		card.add_child(card_margin)
		var copy: VBoxContainer = VBoxContainer.new()
		card_margin.add_child(copy)
		var fallback_name: String = str(row.get("id", "Record")).capitalize()
		var name_label: Label = Label.new()
		name_label.text = str(
			row.get(
				"display_name",
				row.get("name", fallback_name)
			)
		)
		name_label.add_theme_font_size_override("font_size", 11)
		name_label.add_theme_color_override("font_color", TEXT_MAIN)
		copy.add_child(name_label)
		var description: Label = Label.new()
		description.text = str(
			row.get(
				"description",
				row.get("source", "Persistent record")
			)
		)
		description.clip_text = true
		description.add_theme_font_size_override("font_size", 9)
		description.add_theme_color_override("font_color", TEXT_SOFT)
		copy.add_child(description)
