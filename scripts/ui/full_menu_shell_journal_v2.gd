extends "res://scripts/ui/full_menu_shell_journal_v1.gd"
class_name FullMenuShellJournalV2

const ElementJournalCatalogScript = preload(
	"res://scripts/journal/element_journal_catalog.gd"
)

const JOURNAL_V2_CATEGORY_ORDER: Array[String] = [
	"recipes",
	"potions",
	"crafts",
	"blueprints",
	"fauna",
	"flora",
	"elements",
	"notes",
]

const ELEMENT_JOURNAL_DEFINITION: Dictionary = {
	"id": "elements",
	"title": "Elements",
	"icon": "◈",
	"description": "The sixteen elements, their gameplay verbs, attack properties, learned spells, statuses, and authored reactions.",
	"empty": "Learn elemental behavior through spells and experiments.",
}


func render_journal() -> void:
	content_title_label.text = _get_journal_page_title()
	action_layout_mode = "screen_geometry"
	action_grid_columns = 1
	_update_scroll_policy()

	var category_grid: GridContainer = make_visual_grid(4)
	category_grid.name = "JournalCategoryStrip"
	category_grid.add_theme_constant_override("h_separation", 7)
	category_grid.add_theme_constant_override("v_separation", 7)
	content_box.add_child(category_grid)
	for category_id: String in JOURNAL_V2_CATEGORY_ORDER:
		_add_journal_v2_category_tile(category_grid, category_id)

	var workspace: PanelContainer = PanelContainer.new()
	workspace.name = "JournalWorkspace"
	workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.add_theme_stylebox_override(
		"panel",
		make_panel_style(
			Color(0.025, 0.033, 0.052, 0.96),
			CARD_BORDER,
			1,
			13
		)
	)
	content_box.add_child(workspace)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	workspace.add_child(margin)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.name = "JournalWorkspaceContent"
	stack.add_theme_constant_override("separation", 9)
	margin.add_child(stack)

	if journal_page == JOURNAL_CATEGORY and selected_journal_category != "":
		_render_journal_category(stack, selected_journal_category)
	else:
		_render_journal_overview(stack)


func _add_journal_v2_category_tile(parent: Container, category_id: String) -> void:
	var definition: Dictionary = _get_journal_definition(category_id)
	var rows: Array[Dictionary] = _get_journal_rows(category_id)
	var learned_count: int = _count_learned_records(rows)
	var action_index: int = selectable_actions.size()
	selectable_actions.append({
		"kind": "toggle_journal_category",
		"category_id": category_id,
	})
	var selected: bool = action_index == selected_action_index
	var active: bool = (
		journal_page == JOURNAL_CATEGORY
		and selected_journal_category == category_id
	)
	var button: Button = Button.new()
	button.text = (
		str(definition.get("icon", "◇"))
		+ "\n"
		+ str(definition.get("title", category_id.capitalize()))
		+ "\n"
		+ str(learned_count)
		+ "/"
		+ str(rows.size())
	)
	button.tooltip_text = str(definition.get("description", ""))
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(176.0, 68.0)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_color_override(
		"font_color",
		TEXT_MAIN if selected or active else TEXT_SOFT
	)
	button.add_theme_stylebox_override(
		"normal",
		make_panel_style(
			ACTIVE_SELECTION_BACKGROUND
			if selected
			else (JOURNAL_ACTIVE_BACKGROUND if active else JOURNAL_BACKGROUND),
			ACTIVE_SELECTION_BORDER
			if selected
			else (JOURNAL_ACTIVE_BORDER if active else CARD_BORDER),
			3 if selected else (2 if active else 1),
			9
		)
	)
	button.add_theme_stylebox_override(
		"focus",
		make_panel_style(ACTIVE_SELECTION_BACKGROUND, ACTIVE_SELECTION_BORDER, 3, 9)
	)
	button.add_theme_stylebox_override(
		"hover",
		make_panel_style(Color(0.14, 0.09, 0.15, 0.98), JOURNAL_ACTIVE_BORDER, 2, 9)
	)
	button.pressed.connect(_on_action_row_pressed.bind(action_index))
	button.mouse_entered.connect(_on_action_row_hovered.bind(action_index))
	parent.add_child(button)
	_register_action_control(button, action_index)
	if selected:
		schedule_selected_control(button)


func _render_journal_overview(parent: VBoxContainer) -> void:
	parent.add_child(_make_magic_heading("GRACE'S LEARNED RECORDS"))
	var intro: Label = Label.new()
	intro.text = (
		"The Journal records knowledge rather than possessions. The Elements shelf now owns the systemic grammar: "
		+ "verbs, attack properties, statuses, spells, and reactions all meet there."
	)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_font_size_override("font_size", 12)
	intro.add_theme_color_override("font_color", TEXT_SOFT)
	parent.add_child(intro)

	var all_rows: Array[Dictionary] = []
	for category_id: String in JOURNAL_V2_CATEGORY_ORDER:
		all_rows.append_array(_get_journal_rows(category_id))
	var summary_grid: GridContainer = make_visual_grid(4)
	summary_grid.add_theme_constant_override("h_separation", 8)
	parent.add_child(summary_grid)
	_add_magic_info_panel(summary_grid, str(_count_learned_records(all_rows)) + " LEARNED", "Records currently understood")
	_add_magic_info_panel(summary_grid, str(all_rows.size()) + " ENTRIES", "Known and undiscovered records")
	_add_magic_info_panel(summary_grid, "16 ELEMENTS", "Four elemental families")
	_add_magic_info_panel(
		summary_grid,
		str(ElementJournalCatalogScript.get_reaction_rows().size()) + " REACTIONS",
		"Authored systemic combinations"
	)

	parent.add_child(_make_magic_heading("KNOWLEDGE SHELVES"))
	var map_grid: GridContainer = make_visual_grid(4)
	map_grid.add_theme_constant_override("h_separation", 8)
	map_grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(map_grid)
	for category_id: String in JOURNAL_V2_CATEGORY_ORDER:
		var definition: Dictionary = _get_journal_definition(category_id)
		_add_magic_info_panel(
			map_grid,
			str(definition.get("icon", "◇")) + "  " + str(definition.get("title", category_id.capitalize())).to_upper(),
			str(definition.get("description", "Journal records."))
		)


func _render_journal_category(parent: VBoxContainer, category_id: String) -> void:
	if category_id == "elements":
		_render_element_journal(parent)
		return
	super._render_journal_category(parent, category_id)


func _render_element_journal(parent: VBoxContainer) -> void:
	var definition: Dictionary = _get_journal_definition("elements")
	var rows: Array[Dictionary] = _get_journal_rows("elements")
	parent.add_child(_make_magic_heading("◈  ELEMENTS  •  NATURAL / PRIMAL / VITAL / MYSTICAL"))
	var description: Label = Label.new()
	description.text = str(definition.get("description", ""))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 11)
	description.add_theme_color_override("font_color", TEXT_SOFT)
	parent.add_child(description)

	var workspace: HBoxContainer = HBoxContainer.new()
	workspace.name = "ElementJournalWorkspace"
	workspace.add_theme_constant_override("separation", 12)
	workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(workspace)

	var atlas_panel: PanelContainer = _make_magic_subpanel()
	atlas_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace.add_child(atlas_panel)
	var atlas_margin: MarginContainer = MarginContainer.new()
	atlas_margin.add_theme_constant_override("margin_left", 10)
	atlas_margin.add_theme_constant_override("margin_top", 10)
	atlas_margin.add_theme_constant_override("margin_right", 10)
	atlas_margin.add_theme_constant_override("margin_bottom", 10)
	atlas_panel.add_child(atlas_margin)
	var element_grid: GridContainer = make_visual_grid(4)
	element_grid.name = "JournalElementGrid"
	element_grid.add_theme_constant_override("h_separation", 7)
	element_grid.add_theme_constant_override("v_separation", 7)
	atlas_margin.add_child(element_grid)

	if _find_journal_row(rows, selected_journal_record_id).is_empty() and not rows.is_empty():
		selected_journal_record_id = str(rows[0].get("id", "water"))
	for row: Dictionary in rows:
		_add_element_journal_tile(element_grid, row)
	workspace.add_child(
		_make_journal_detail_panel(
			_find_journal_row(rows, selected_journal_record_id),
			definition
		)
	)


func _add_element_journal_tile(parent: Container, row: Dictionary) -> void:
	var record_id: String = str(row.get("id", "element"))
	var action_index: int = selectable_actions.size()
	selectable_actions.append({
		"kind": "select_journal_record",
		"record_id": record_id,
	})
	var selected: bool = action_index == selected_action_index
	var inspected: bool = record_id == selected_journal_record_id
	var button: Button = Button.new()
	button.text = (
		str(row.get("icon", "◇"))
		+ "  "
		+ str(row.get("name", record_id.capitalize()))
		+ "\n"
		+ str(row.get("family", "Element")).to_upper()
		+ "  •  "
		+ str(row.get("spell_count", 0))
		+ " SPELLS  •  "
		+ str(row.get("reaction_count", 0))
		+ " RXN"
	)
	button.tooltip_text = str(row.get("summary", ""))
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(125.0, 62.0)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 9)
	button.add_theme_color_override("font_color", TEXT_MAIN if selected or inspected else TEXT_SOFT)
	button.add_theme_stylebox_override(
		"normal",
		make_panel_style(
			ACTIVE_SELECTION_BACKGROUND if selected else (JOURNAL_ACTIVE_BACKGROUND if inspected else CARD_BACKGROUND),
			ACTIVE_SELECTION_BORDER if selected else (JOURNAL_ACTIVE_BORDER if inspected else CARD_BORDER),
			3 if selected else (2 if inspected else 1),
			8
		)
	)
	button.add_theme_stylebox_override(
		"focus",
		make_panel_style(ACTIVE_SELECTION_BACKGROUND, ACTIVE_SELECTION_BORDER, 3, 8)
	)
	button.add_theme_stylebox_override(
		"hover",
		make_panel_style(Color(0.14, 0.09, 0.15, 0.98), JOURNAL_ACTIVE_BORDER, 2, 8)
	)
	button.pressed.connect(_on_action_row_pressed.bind(action_index))
	button.mouse_entered.connect(_on_action_row_hovered.bind(action_index))
	parent.add_child(button)
	_register_action_control(button, action_index)
	if selected:
		schedule_selected_control(button)


func _get_journal_rows(category_id: String) -> Array[Dictionary]:
	if category_id == "elements":
		return ElementJournalCatalogScript.get_rows(
			menu_data.get("learned_spell_sections", [])
		)
	return super._get_journal_rows(category_id)


func _toggle_journal_category(category_id: String) -> void:
	if not JOURNAL_V2_CATEGORY_ORDER.has(category_id):
		return
	if journal_page == JOURNAL_CATEGORY and selected_journal_category == category_id:
		_reset_journal_workspace()
	else:
		journal_page = JOURNAL_CATEGORY
		selected_journal_category = category_id
		selected_journal_record_id = ""
		var rows: Array[Dictionary] = _get_journal_rows(category_id)
		if not rows.is_empty():
			selected_journal_record_id = str(rows[0].get("id", ""))
	selected_action_index = JOURNAL_V2_CATEGORY_ORDER.find(category_id)
	tab_action_memory["journal"] = maxi(selected_action_index, 0)
	rebuild_menu()


func _get_journal_definition(category_id: String) -> Dictionary:
	if category_id == "elements":
		return ELEMENT_JOURNAL_DEFINITION.duplicate(true)
	return JournalCatalogScript.get_definition(category_id)


func _get_journal_page_title() -> String:
	if journal_page == JOURNAL_CATEGORY and selected_journal_category != "":
		var definition: Dictionary = _get_journal_definition(selected_journal_category)
		return "📜 Journal  ›  " + str(
			definition.get("title", selected_journal_category.capitalize())
		)
	return "📜 Journal"


func get_journal_debug_data() -> Dictionary:
	var data: Dictionary = super.get_journal_debug_data()
	data["category_count"] = JOURNAL_V2_CATEGORY_ORDER.size()
	data["element_count"] = _get_journal_rows("elements").size()
	data["reaction_count"] = ElementJournalCatalogScript.get_reaction_rows().size()
	data["element_grid_present"] = find_child("JournalElementGrid", true, false) != null
	return data
