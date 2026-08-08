extends "res://scripts/ui/game_ui_compact_focus_resolved.gd"
class_name GameUIFocusMinimal

# Focus is intentionally only the two things Grace needs in combat:
# 1. the sixteen-element matrix
# 2. the spells inside the highlighted element
# Everything else belongs to the permanent HUD or the full Magic menu.


func _ready() -> void:
	super._ready()
	call_deferred("_apply_minimal_focus_layout")


func show_spell_focus_menu(menu_data: Dictionary) -> void:
	super.show_spell_focus_menu(menu_data)
	_apply_minimal_focus_layout()


func _apply_minimal_focus_layout() -> void:
	if focus_spell_panel == null:
		return

	# Remove the dashboard chrome. Hidden children do not consume Container
	# layout space, so the inherited cached selector stays intact and cheap.
	for label: Label in [
		focus_spell_title_label,
		focus_spell_current_label,
		focus_spell_header_label,
		focus_spell_selected_label,
		focus_spell_help_label,
	]:
		if label != null:
			label.visible = false

	focus_spell_panel.offset_left = -322.0
	focus_spell_panel.offset_top = -306.0
	focus_spell_panel.offset_right = 322.0
	focus_spell_panel.offset_bottom = -112.0
	focus_spell_panel.add_theme_stylebox_override(
		"panel",
		make_panel_style(
			Color(0.0, 0.0, 0.0, 0.0),
			Color(0.0, 0.0, 0.0, 0.0),
			0,
			0
		)
	)

	var outer_margin: MarginContainer = focus_spell_panel.get_child(0) as MarginContainer
	if outer_margin != null:
		outer_margin.add_theme_constant_override("margin_left", 2)
		outer_margin.add_theme_constant_override("margin_top", 2)
		outer_margin.add_theme_constant_override("margin_right", 2)
		outer_margin.add_theme_constant_override("margin_bottom", 2)

	if compact_focus_element_panel != null:
		compact_focus_element_panel.custom_minimum_size = Vector2(236.0, 184.0)
		compact_focus_element_panel.add_theme_stylebox_override(
			"panel",
			make_panel_style(
				Color(0.012, 0.021, 0.033, 0.91),
				Color(0.24, 0.34, 0.5, 0.62),
				1,
				11
			)
		)

	if compact_focus_detail_panel != null:
		compact_focus_detail_panel.custom_minimum_size = Vector2(396.0, 184.0)
		compact_focus_detail_panel.add_theme_stylebox_override(
			"panel",
			make_panel_style(
				Color(0.012, 0.021, 0.033, 0.91),
				Color(0.24, 0.34, 0.5, 0.62),
				1,
				11
			)
		)

	if focus_spell_scroll != null:
		focus_spell_scroll.custom_minimum_size = Vector2(0.0, 172.0)


func get_minimal_focus_debug_data() -> Dictionary:
	return {
		"minimal": true,
		"panel_width": (
			focus_spell_panel.offset_right - focus_spell_panel.offset_left
			if focus_spell_panel != null
			else 0.0
		),
		"panel_height": (
			focus_spell_panel.offset_bottom - focus_spell_panel.offset_top
			if focus_spell_panel != null
			else 0.0
		),
		"title_hidden": focus_spell_title_label != null and not focus_spell_title_label.visible,
		"active_hidden": focus_spell_current_label != null and not focus_spell_current_label.visible,
		"element_header_hidden": focus_spell_header_label != null and not focus_spell_header_label.visible,
		"detail_hidden": focus_spell_selected_label != null and not focus_spell_selected_label.visible,
		"help_hidden": focus_spell_help_label != null and not focus_spell_help_label.visible,
		"element_matrix": focus_cached_element_tiles.size(),
		"spell_rows": focus_cached_spell_rows.size(),
	}
