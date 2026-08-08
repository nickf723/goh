extends "res://scripts/ui/game_ui_unified.gd"
class_name GameUIFocusGrid

const SpellIconsGrid = preload("res://scripts/ui/spell_icon_factory.gd")
const FocusGridLayoutScript = preload("res://scripts/ui/focus_grid_layout.gd")
const VineTargetPreviewScript = preload(
	"res://scripts/player/vine_grapple_target_preview.gd"
)

const PAGE_ELEMENTS: String = "elements"
const PAGE_SPELLS: String = "spells"
const PANEL_WIDTH: float = 424.0
const PANEL_HEIGHT: float = 236.0
const ELEMENT_CELL_SIZE: Vector2 = Vector2(88.0, 46.0)
const SPELL_CELL_SIZE: Vector2 = Vector2(120.0, 64.0)

var focus_grid_host: CenterContainer
var focus_element_grid: GridContainer
var focus_spell_grid: GridContainer
var focus_element_cells: Array[PanelContainer] = []
var focus_element_labels: Array[Label] = []
var focus_element_ids: Array[String] = []
var focus_spell_cells: Array[PanelContainer] = []
var focus_spell_labels: Array[Label] = []
var focus_spell_badges: Array[PanelContainer] = []
var focus_spell_entries: Array[Dictionary] = []
var focus_spell_slots: Array[int] = []
var focus_grid_page: String = PAGE_ELEMENTS
var focus_grid_signature: String = ""
var vine_target_preview: Node


func _ready() -> void:
	super._ready()
	call_deferred("_ensure_vine_target_preview")


# The inherited UI stack used to decorate Focus as a dashboard. Grid Focus owns
# its complete presentation, so those upgrade hooks intentionally become no-ops.
func _upgrade_focus_presentation() -> void:
	pass


func update_focus_help_copy() -> void:
	pass


func ensure_focus_spell_selector_ui() -> void:
	if focus_spell_panel != null:
		return

	focus_spell_panel = PanelContainer.new()
	focus_spell_panel.name = "FocusGridPanel"
	focus_spell_panel.visible = false
	focus_spell_panel.anchor_left = 0.5
	focus_spell_panel.anchor_top = 1.0
	focus_spell_panel.anchor_right = 0.5
	focus_spell_panel.anchor_bottom = 1.0
	focus_spell_panel.offset_left = -PANEL_WIDTH * 0.5
	focus_spell_panel.offset_top = -354.0
	focus_spell_panel.offset_right = PANEL_WIDTH * 0.5
	focus_spell_panel.offset_bottom = -118.0
	focus_spell_panel.add_theme_stylebox_override(
		"panel",
		make_panel_style(
			Color(0.008, 0.014, 0.024, 0.955),
			Color(0.26, 0.38, 0.58, 0.72),
			1,
			14
		)
	)
	add_child(focus_spell_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 9)
	focus_spell_panel.add_child(margin)

	focus_grid_host = CenterContainer.new()
	focus_grid_host.name = "FocusGridHost"
	focus_grid_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	focus_grid_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(focus_grid_host)

	focus_element_grid = GridContainer.new()
	focus_element_grid.name = "ElementGrid4x4"
	focus_element_grid.columns = 4
	focus_element_grid.add_theme_constant_override("h_separation", 6)
	focus_element_grid.add_theme_constant_override("v_separation", 6)
	focus_grid_host.add_child(focus_element_grid)
	focus_spell_element_grid = focus_element_grid

	focus_spell_grid = GridContainer.new()
	focus_spell_grid.name = "SpellGrid3x3"
	focus_spell_grid.columns = 3
	focus_spell_grid.add_theme_constant_override("h_separation", 6)
	focus_spell_grid.add_theme_constant_override("v_separation", 6)
	focus_spell_grid.visible = false
	focus_grid_host.add_child(focus_spell_grid)

	# Compatibility references stay null/hidden by design. The two-state renderer
	# does not have title/current/detail/help rows or a vertical spell-list panel.
	focus_spell_title_label = null
	focus_spell_current_label = null
	focus_spell_header_label = null
	focus_spell_selected_label = null
	focus_spell_help_label = null


func show_spell_focus_menu(menu_data: Dictionary) -> void:
	ensure_focus_spell_selector_ui()
	spell_menu_label.visible = false
	focus_grid_page = str(menu_data.get("focus_page", PAGE_ELEMENTS))

	if not focus_spell_panel.visible:
		focus_spell_panel.modulate.a = 0.0
		focus_spell_panel.visible = true
		var tween: Tween = create_tween()
		tween.tween_property(focus_spell_panel, "modulate:a", 1.0, 0.06)
	else:
		focus_spell_panel.visible = true

	_update_element_grid(menu_data)
	if focus_grid_page == PAGE_SPELLS:
		_update_spell_grid(menu_data)

	focus_element_grid.visible = focus_grid_page == PAGE_ELEMENTS
	focus_spell_grid.visible = focus_grid_page == PAGE_SPELLS


func hide_spell_focus_menu() -> void:
	if focus_spell_panel != null:
		focus_spell_panel.visible = false
	focus_grid_page = PAGE_ELEMENTS
	hide_spell_menu()


func _update_element_grid(menu_data: Dictionary) -> void:
	var raw_order: Array = menu_data.get("element_order", []) as Array
	var next_ids: Array[String] = []
	for raw_element: Variant in raw_order:
		next_ids.append(str(raw_element))

	if next_ids != focus_element_ids:
		focus_element_ids = next_ids.duplicate()
		clear_children(focus_element_grid)
		focus_element_cells.clear()
		focus_element_labels.clear()
		focus_cached_element_ids.clear()
		focus_cached_element_tiles.clear()
		focus_cached_element_labels.clear()
		for element: String in focus_element_ids:
			var cell_data: Dictionary = _make_element_cell(element)
			var cell: PanelContainer = cell_data.get("cell") as PanelContainer
			var label: Label = cell_data.get("label") as Label
			focus_element_grid.add_child(cell)
			focus_element_cells.append(cell)
			focus_element_labels.append(label)
			focus_cached_element_ids.append(element)
			focus_cached_element_tiles.append(cell)
			focus_cached_element_labels.append(label)

	var selected: String = str(menu_data.get("selected_element", ""))
	for index: int in range(focus_element_ids.size()):
		var element: String = focus_element_ids[index]
		var highlighted: bool = element == selected
		var cell: PanelContainer = focus_element_cells[index]
		var label: Label = focus_element_labels[index]
		var color: Color = get_element_color(element)
		cell.add_theme_stylebox_override(
			"panel",
			_get_focus_style(
				"grid_element|" + element + "|" + str(highlighted),
				Color(color.r * 0.22, color.g * 0.22, color.b * 0.22, 0.96)
				if highlighted
				else Color(0.018, 0.027, 0.043, 0.94),
				Color(color.r, color.g, color.b, 1.0 if highlighted else 0.48),
				3 if highlighted else 1,
				10
			)
		)
		label.add_theme_color_override(
			"font_color",
			Color(0.98, 1.0, 0.96, 1.0) if highlighted else TEXT_MAIN
		)


func _make_element_cell(element: String) -> Dictionary:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = ELEMENT_CELL_SIZE
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_theme_constant_override("margin_bottom", 4)
	cell.add_child(margin)
	var label := Label.new()
	label.text = get_short_element_name(element)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", 11)
	margin.add_child(label)
	return {"cell": cell, "label": label}


func _update_spell_grid(menu_data: Dictionary) -> void:
	var element: String = str(menu_data.get("selected_element", ""))
	var selected_index: int = int(menu_data.get("selected_spell_index", 0))
	var entries: Array[Dictionary] = _get_focus_spell_entries(element)
	if entries.size() > 8:
		entries.resize(8)
	var signature_parts: Array[String] = [element]
	for entry: Dictionary in entries:
		signature_parts.append(
			str(entry.get("spell_id", "")) + "|" + str(entry.get("name", "Spell"))
		)
	var signature: String = ";".join(signature_parts)
	if signature != focus_grid_signature:
		focus_grid_signature = signature
		_rebuild_spell_grid(element, entries)

	focus_spell_entries = entries.duplicate(true)
	focus_spell_slots = FocusGridLayoutScript.get_spell_slots(entries.size())
	for index: int in range(focus_spell_entries.size()):
		if index >= focus_spell_cells.size():
			break
		var cell: PanelContainer = focus_spell_cells[index]
		var label: Label = focus_spell_labels[index]
		var badge: PanelContainer = focus_spell_badges[index]
		var highlighted: bool = index == selected_index
		var color: Color = get_element_color(element)
		cell.add_theme_stylebox_override(
			"panel",
			_get_focus_style(
				"grid_spell|" + element + "|" + str(highlighted),
				Color(color.r * 0.2, color.g * 0.2, color.b * 0.2, 0.97)
				if highlighted
				else Color(0.018, 0.027, 0.043, 0.94),
				Color(color.r, color.g, color.b, 1.0 if highlighted else 0.42),
				3 if highlighted else 1,
				10
			)
		)
		label.add_theme_color_override(
			"font_color",
			Color(0.98, 1.0, 0.96, 1.0) if highlighted else TEXT_MAIN
		)
		SpellIconsGrid.update_badge(
			badge,
			focus_spell_entries[index],
			highlighted,
			false
		)


func _rebuild_spell_grid(element: String, entries: Array[Dictionary]) -> void:
	clear_children(focus_spell_grid)
	focus_spell_cells.clear()
	focus_spell_labels.clear()
	focus_spell_badges.clear()
	focus_cached_spell_rows.clear()
	focus_cached_spell_labels.clear()

	var slots: Array[int] = FocusGridLayoutScript.get_spell_slots(entries.size())
	var spell_index_by_slot: Dictionary = {}
	for spell_index: int in range(slots.size()):
		spell_index_by_slot[slots[spell_index]] = spell_index

	for grid_slot: int in range(9):
		if grid_slot == 4:
			focus_spell_grid.add_child(_make_element_center_cell(element))
			continue
		if not spell_index_by_slot.has(grid_slot):
			focus_spell_grid.add_child(_make_empty_spell_cell())
			continue
		var spell_index: int = int(spell_index_by_slot[grid_slot])
		var entry: Dictionary = entries[spell_index]
		var cell_data: Dictionary = _make_spell_cell(entry)
		var cell: PanelContainer = cell_data.get("cell") as PanelContainer
		var label: Label = cell_data.get("label") as Label
		var badge: PanelContainer = cell_data.get("badge") as PanelContainer
		focus_spell_grid.add_child(cell)
		focus_spell_cells.append(cell)
		focus_spell_labels.append(label)
		focus_spell_badges.append(badge)
		focus_cached_spell_rows.append(cell)
		focus_cached_spell_labels.append(label)

	# The arrays above were appended in grid-slot order, while selection indices
	# are spell order. Rebuild them into spell-index order for O(1) highlighting.
	var ordered_cells: Array[PanelContainer] = []
	var ordered_labels: Array[Label] = []
	var ordered_badges: Array[PanelContainer] = []
	for spell_index: int in range(entries.size()):
		var target_slot: int = slots[spell_index]
		var target_cell: PanelContainer = focus_spell_grid.get_child(target_slot) as PanelContainer
		ordered_cells.append(target_cell)
		var target_label: Label = target_cell.get_meta("spell_label") as Label
		var target_badge: PanelContainer = target_cell.get_meta("spell_badge") as PanelContainer
		ordered_labels.append(target_label)
		ordered_badges.append(target_badge)
	focus_spell_cells = ordered_cells
	focus_spell_labels = ordered_labels
	focus_spell_badges = ordered_badges
	focus_cached_spell_rows = ordered_cells.duplicate()
	focus_cached_spell_labels = ordered_labels.duplicate()


func _make_spell_cell(entry: Dictionary) -> Dictionary:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = SPELL_CELL_SIZE
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 5)
	cell.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	margin.add_child(row)

	var badge: PanelContainer = SpellIconsGrid.create_badge(entry, 28.0, false, false)
	row.add_child(badge)
	var label := Label.new()
	label.text = str(entry.get("name", "Spell"))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", 10)
	row.add_child(label)
	cell.set_meta("spell_label", label)
	cell.set_meta("spell_badge", badge)
	return {"cell": cell, "label": label, "badge": badge}


func _make_element_center_cell(element: String) -> PanelContainer:
	var color: Color = get_element_color(element)
	var cell := PanelContainer.new()
	cell.name = "ElementCenter"
	cell.custom_minimum_size = SPELL_CELL_SIZE
	cell.add_theme_stylebox_override(
		"panel",
		_get_focus_style(
			"grid_center|" + element,
			Color(color.r * 0.26, color.g * 0.26, color.b * 0.26, 0.98),
			Color(color.r, color.g, color.b, 0.88),
			2,
			14
		)
	)
	var label := Label.new()
	label.text = element.capitalize().to_upper()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.98, 1.0, 0.96, 1.0))
	cell.add_child(label)
	return cell


func _make_empty_spell_cell() -> PanelContainer:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = SPELL_CELL_SIZE
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_theme_stylebox_override(
		"panel",
		_get_focus_style(
			"grid_empty_spell",
			Color(0.0, 0.0, 0.0, 0.0),
			Color(0.0, 0.0, 0.0, 0.0),
			0,
			10
		)
	)
	return cell


func _ensure_vine_target_preview() -> void:
	if get_tree() == null:
		return
	var existing: Node = get_tree().get_first_node_in_group(
		"vine_grapple_target_previews"
	)
	if existing != null:
		vine_target_preview = existing
		return
	var host: Node = get_tree().current_scene
	if host == null:
		host = get_parent()
	if host == null:
		return
	vine_target_preview = VineTargetPreviewScript.new()
	vine_target_preview.name = "VineGrappleTargetPreview"
	host.add_child(vine_target_preview)


func get_focus_grid_debug_data() -> Dictionary:
	return {
		"two_state": true,
		"page": focus_grid_page,
		"panel_width": PANEL_WIDTH,
		"panel_height": PANEL_HEIGHT,
		"panel_visible": focus_spell_panel != null and focus_spell_panel.visible,
		"element_columns": focus_element_grid.columns if focus_element_grid != null else 0,
		"element_count": focus_element_ids.size(),
		"family_labels": 0,
		"spell_columns": focus_spell_grid.columns if focus_spell_grid != null else 0,
		"spell_center_slot": 4,
		"spell_count": focus_spell_entries.size(),
		"spell_slots": focus_spell_slots.duplicate(),
		"fixed_panel": true,
	}


func get_focus_presentation_debug_data() -> Dictionary:
	return {
		"upgraded": true,
		"two_state_grid": true,
		"cached_elements": focus_element_ids.size(),
		"cached_spells": focus_spell_entries.size(),
		"structure_rebuilds": 0,
		"visual_updates": 0,
		"style_cache_size": focus_style_cache.size(),
		"panel_visible": focus_spell_panel != null and focus_spell_panel.visible,
	}
