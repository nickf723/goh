extends "res://scripts/ui/game_ui_focus_grid.gd"
class_name GameUIFocusMinimal

# Compatibility entry point retained by game_ui.tscn. Focus shrink-wraps the
# standardized 4x4 -> 3x3 grids. This class now applies the compact geometry both
# before and after every visible refresh so the inherited first render can never
# flash the older, larger Focus frame.

const COMPACT_PANEL_WIDTH: float = 316.0
const COMPACT_PANEL_HEIGHT: float = 192.0
const COMPACT_ELEMENT_CELL_SIZE: Vector2 = Vector2(68.0, 34.0)
const COMPACT_SPELL_CELL_SIZE: Vector2 = Vector2(94.0, 54.0)


func _ready() -> void:
	super._ready()
	_force_compact_focus_geometry()
	call_deferred("_force_compact_focus_geometry")


func ensure_focus_spell_selector_ui() -> void:
	super.ensure_focus_spell_selector_ui()
	_force_compact_focus_geometry()


func show_spell_focus_menu(menu_data: Dictionary) -> void:
	# The old large border came from the inherited grid geometry owning the first
	# visible frame, then this compatibility layer correcting it on navigation.
	# Apply the compact contract before visibility changes and again afterward.
	_force_compact_focus_geometry()
	super.show_spell_focus_menu(menu_data)
	_force_compact_focus_geometry()
	call_deferred("_force_compact_focus_geometry")


func _force_compact_focus_geometry() -> void:
	if focus_spell_panel == null:
		return
	focus_spell_panel.offset_left = -COMPACT_PANEL_WIDTH * 0.5
	focus_spell_panel.offset_top = -310.0
	focus_spell_panel.offset_right = COMPACT_PANEL_WIDTH * 0.5
	focus_spell_panel.offset_bottom = -118.0

	var margin: MarginContainer = focus_spell_panel.get_child(0) as MarginContainer
	if margin != null:
		margin.add_theme_constant_override("margin_left", 6)
		margin.add_theme_constant_override("margin_top", 6)
		margin.add_theme_constant_override("margin_right", 6)
		margin.add_theme_constant_override("margin_bottom", 6)

	if focus_element_grid != null:
		focus_element_grid.add_theme_constant_override("h_separation", 5)
		focus_element_grid.add_theme_constant_override("v_separation", 5)
	if focus_spell_grid != null:
		focus_spell_grid.add_theme_constant_override("h_separation", 5)
		focus_spell_grid.add_theme_constant_override("v_separation", 5)

	# Correct any cells that may have been constructed by an inherited first-pass
	# renderer before this most-derived compatibility layer received control.
	for cell: PanelContainer in focus_element_cells:
		if cell != null:
			cell.custom_minimum_size = COMPACT_ELEMENT_CELL_SIZE
	for cell: PanelContainer in focus_spell_cells:
		if cell != null:
			cell.custom_minimum_size = COMPACT_SPELL_CELL_SIZE


func get_short_element_name(element: String) -> String:
	if element == "lightning":
		return "Lightning"
	return super.get_short_element_name(element)


func _make_element_cell(element: String) -> Dictionary:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = COMPACT_ELEMENT_CELL_SIZE
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 3)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_right", 3)
	margin.add_theme_constant_override("margin_bottom", 2)
	cell.add_child(margin)

	var label := Label.new()
	label.text = get_short_element_name(element)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override(
		"font_size",
		9 if element == "lightning" else 10
	)
	margin.add_child(label)
	return {"cell": cell, "label": label}


func _make_spell_cell(entry: Dictionary) -> Dictionary:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = COMPACT_SPELL_CELL_SIZE
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_top", 3)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_bottom", 3)
	cell.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 1)
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(stack)

	var badge: PanelContainer = SpellIconsGrid.create_badge(
		entry,
		22.0,
		false,
		false
	)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.add_child(badge)

	var label := Label.new()
	label.text = str(entry.get("name", "Spell"))
	label.custom_minimum_size = Vector2(82.0, 14.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", 8)
	stack.add_child(label)

	cell.set_meta("spell_label", label)
	cell.set_meta("spell_badge", badge)
	return {"cell": cell, "label": label, "badge": badge}


func _make_element_center_cell(element: String) -> PanelContainer:
	var color: Color = get_element_color(element)
	var cell := PanelContainer.new()
	cell.name = "ElementCenter"
	cell.custom_minimum_size = COMPACT_SPELL_CELL_SIZE
	cell.add_theme_stylebox_override(
		"panel",
		_get_focus_style(
			"compact_grid_center|" + element,
			Color(color.r * 0.26, color.g * 0.26, color.b * 0.26, 0.98),
			Color(color.r, color.g, color.b, 0.9),
			2,
			12
		)
	)
	var label := Label.new()
	label.text = element.capitalize().to_upper()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.98, 1.0, 0.96, 1.0))
	cell.add_child(label)
	return cell


func _make_empty_spell_cell() -> PanelContainer:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = COMPACT_SPELL_CELL_SIZE
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_theme_stylebox_override(
		"panel",
		_get_focus_style(
			"compact_grid_empty",
			Color(0.01, 0.016, 0.026, 0.28),
			Color(0.12, 0.18, 0.28, 0.18),
			1,
			10
		)
	)
	return cell


func get_compact_focus_grid_debug_data() -> Dictionary:
	var data: Dictionary = get_focus_grid_debug_data()
	data["compact_width"] = COMPACT_PANEL_WIDTH
	data["compact_height"] = COMPACT_PANEL_HEIGHT
	data["lightning_label"] = get_short_element_name("lightning")
	data["spell_labels_visible"] = true
	data["compact_applied_before_show"] = true
	return data
