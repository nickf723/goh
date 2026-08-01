extends "res://scripts/ui/full_menu_shell_items_v1.gd"
class_name FullMenuShellJournalV1

const JournalCatalogScript = preload(
	"res://scripts/journal/journal_record_catalog.gd"
)

const JOURNAL_OVERVIEW: String = "overview"
const JOURNAL_CATEGORY: String = "category"

const JOURNAL_BACKGROUND: Color = Color(0.055, 0.055, 0.082, 0.96)
const JOURNAL_ACTIVE_BACKGROUND: Color = Color(0.115, 0.085, 0.13, 0.98)
const JOURNAL_ACTIVE_BORDER: Color = Color(0.88, 0.58, 0.92, 0.96)

var journal_page: String = JOURNAL_OVERVIEW
var selected_journal_category: String = ""
var selected_journal_record_id: String = ""


func hide_menu() -> void:
	_reset_journal_workspace()
	super.hide_menu()


func select_tab(index: int) -> void:
	if get_current_tab_id() == "journal":
		_reset_journal_workspace()
	super.select_tab(index)


func handle_menu_input(event: InputEvent) -> bool:
	if not visible:
		return false
	if get_current_tab_id() == "journal":
		var cancel_requested: bool = (
			is_menu_cancel_event(event)
			if event is InputEventJoypadButton
			else event.is_action_pressed("ui_cancel")
		)
		if (
			cancel_requested
			and not is_assignment_active()
			and journal_page != JOURNAL_OVERVIEW
		):
			_reset_journal_workspace()
			selected_action_index = 0
			tab_action_memory["journal"] = 0
			rebuild_menu()
			return true
	return super.handle_menu_input(event)


func activate_action(action: Dictionary) -> void:
	match str(action.get("kind", "")):
		"toggle_journal_category":
			_toggle_journal_category(str(action.get("category_id", "")))
		"select_journal_record":
			selected_journal_record_id = str(action.get("record_id", ""))
			rebuild_menu()
		_:
			super.activate_action(action)


func get_footer_text() -> String:
	if get_current_tab_id() == "journal" and not is_assignment_active():
		if journal_page == JOURNAL_OVERVIEW:
			return "L/R: tabs  •  D-pad or left stick: record shelf  •  Right stick: cursor  •  A: open  •  B: close"
		return "D-pad or left stick: navigate  •  Right stick: cursor  •  A: inspect  •  B: collapse shelf"
	return super.get_footer_text()


func render_journal() -> void:
	content_title_label.text = _get_journal_page_title()
	action_layout_mode = "screen_geometry"
	action_grid_columns = 1
	_update_scroll_policy()

	var category_grid: GridContainer = make_visual_grid(7)
	category_grid.name = "JournalCategoryStrip"
	category_grid.add_theme_constant_override("h_separation", 7)
	content_box.add_child(category_grid)
	for category_id: String in JournalCatalogScript.CATEGORY_ORDER:
		_add_journal_category_tile(category_grid, category_id)

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


func _add_journal_category_tile(parent: Container, category_id: String) -> void:
	var definition: Dictionary = JournalCatalogScript.get_definition(category_id)
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
	button.custom_minimum_size = Vector2(118.0, 76.0)
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
		make_panel_style(
			ACTIVE_SELECTION_BACKGROUND,
			ACTIVE_SELECTION_BORDER,
			3,
			9
		)
	)
	button.add_theme_stylebox_override(
		"hover",
		make_panel_style(
			Color(0.14, 0.09, 0.15, 0.98),
			JOURNAL_ACTIVE_BORDER,
			2,
			9
		)
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
		"The Journal records knowledge rather than possessions. Recipes explain how to make things; "
		+ "fauna and flora records explain the living world; Field Notes preserve everything that does not belong in a shelf yet."
	)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_font_size_override("font_size", 12)
	intro.add_theme_color_override("font_color", TEXT_SOFT)
	parent.add_child(intro)

	var all_rows: Array[Dictionary] = []
	for category_id: String in JournalCatalogScript.CATEGORY_ORDER:
		all_rows.append_array(_get_journal_rows(category_id))
	var summary_grid: GridContainer = make_visual_grid(4)
	summary_grid.add_theme_constant_override("h_separation", 8)
	parent.add_child(summary_grid)
	_add_magic_info_panel(
		summary_grid,
		str(_count_learned_records(all_rows)) + " LEARNED",
		"Records currently understood"
	)
	_add_magic_info_panel(
		summary_grid,
		str(all_rows.size()) + " ENTRIES",
		"Known and undiscovered records"
	)
	_add_magic_info_panel(
		summary_grid,
		str(_get_journal_rows("potions").size()) + " FORMULAS",
		"Authored alchemy recipes"
	)
	_add_magic_info_panel(
		summary_grid,
		"7 SHELVES",
		"Expandable learned-system taxonomy"
	)

	parent.add_child(_make_magic_heading("WHAT BELONGS HERE"))
	var map_grid: GridContainer = make_visual_grid(4)
	map_grid.add_theme_constant_override("h_separation", 8)
	map_grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(map_grid)
	for category_id: String in JournalCatalogScript.CATEGORY_ORDER:
		var definition: Dictionary = JournalCatalogScript.get_definition(category_id)
		_add_magic_info_panel(
			map_grid,
			str(definition.get("icon", "◇"))
			+ "  "
			+ str(definition.get("title", category_id.capitalize())).to_upper(),
			str(definition.get("description", "Journal records."))
		)


func _render_journal_category(
	parent: VBoxContainer,
	category_id: String
) -> void:
	var definition: Dictionary = JournalCatalogScript.get_definition(category_id)
	var rows: Array[Dictionary] = _get_journal_rows(category_id)
	parent.add_child(
		_make_magic_heading(
			str(definition.get("icon", "◇"))
			+ "  "
			+ str(definition.get("title", category_id.capitalize())).to_upper()
		)
	)
	var description: Label = Label.new()
	description.text = str(definition.get("description", ""))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 11)
	description.add_theme_color_override("font_color", TEXT_SOFT)
	parent.add_child(description)

	var summary: Label = Label.new()
	summary.text = (
		str(_count_learned_records(rows))
		+ " learned  •  "
		+ str(rows.size())
		+ " total"
		+ ("  •  Showing first 9" if rows.size() > 9 else "")
	)
	summary.add_theme_font_size_override("font_size", 10)
	summary.add_theme_color_override("font_color", JOURNAL_ACTIVE_BORDER)
	parent.add_child(summary)

	var workspace: HBoxContainer = HBoxContainer.new()
	workspace.name = "JournalCategoryWorkspace"
	workspace.add_theme_constant_override("separation", 12)
	workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(workspace)

	var records_panel: PanelContainer = _make_magic_subpanel()
	records_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace.add_child(records_panel)
	var records_margin: MarginContainer = MarginContainer.new()
	records_margin.add_theme_constant_override("margin_left", 10)
	records_margin.add_theme_constant_override("margin_top", 10)
	records_margin.add_theme_constant_override("margin_right", 10)
	records_margin.add_theme_constant_override("margin_bottom", 10)
	records_panel.add_child(records_margin)
	var record_grid: GridContainer = make_visual_grid(3)
	record_grid.name = "JournalRecordGrid"
	record_grid.add_theme_constant_override("h_separation", 7)
	record_grid.add_theme_constant_override("v_separation", 7)
	records_margin.add_child(record_grid)

	if rows.is_empty():
		_add_empty_journal_card(record_grid, definition)
		selected_journal_record_id = ""
	else:
		if _find_journal_row(rows, selected_journal_record_id).is_empty():
			selected_journal_record_id = str(rows[0].get("id", ""))
		for row: Dictionary in rows.slice(0, mini(rows.size(), 9)):
			_add_journal_record_tile(record_grid, row)

	workspace.add_child(
		_make_journal_detail_panel(
			_find_journal_row(rows, selected_journal_record_id),
			definition
		)
	)


func _add_journal_record_tile(parent: Container, row: Dictionary) -> void:
	var record_id: String = str(row.get("id", "record"))
	var learned: bool = bool(row.get("learned", false))
	var action_index: int = selectable_actions.size()
	selectable_actions.append({
		"kind": "select_journal_record",
		"record_id": record_id,
	})
	var selected: bool = action_index == selected_action_index
	var inspected: bool = record_id == selected_journal_record_id
	var title: String = str(row.get("name", record_id.capitalize()))
	if not learned and not OS.is_debug_build():
		title = "Undiscovered"
	var button: Button = Button.new()
	button.text = (
		str(row.get("icon", "◇"))
		+ "\n"
		+ title
		+ "\n"
		+ str(row.get("status", "RECORDED"))
	)
	button.tooltip_text = str(row.get("summary", ""))
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(135.0, 84.0)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_color_override(
		"font_color",
		TEXT_MAIN if selected or inspected else (TEXT_SOFT if learned else TEXT_DIM)
	)
	button.add_theme_stylebox_override(
		"normal",
		make_panel_style(
			ACTIVE_SELECTION_BACKGROUND
			if selected
			else (JOURNAL_ACTIVE_BACKGROUND if inspected else CARD_BACKGROUND),
			ACTIVE_SELECTION_BORDER
			if selected
			else (JOURNAL_ACTIVE_BORDER if inspected else CARD_BORDER),
			3 if selected else (2 if inspected else 1),
			9
		)
	)
	button.add_theme_stylebox_override(
		"focus",
		make_panel_style(
			ACTIVE_SELECTION_BACKGROUND,
			ACTIVE_SELECTION_BORDER,
			3,
			9
		)
	)
	button.add_theme_stylebox_override(
		"hover",
		make_panel_style(
			Color(0.14, 0.09, 0.15, 0.98),
			JOURNAL_ACTIVE_BORDER,
			2,
			9
		)
	)
	button.pressed.connect(_on_action_row_pressed.bind(action_index))
	button.mouse_entered.connect(_on_action_row_hovered.bind(action_index))
	parent.add_child(button)
	_register_action_control(button, action_index)
	if selected:
		schedule_selected_control(button)


func _add_empty_journal_card(
	parent: Container,
	definition: Dictionary
) -> void:
	var panel: PanelContainer = _make_magic_subpanel()
	panel.custom_minimum_size = Vector2(420.0, 220.0)
	parent.add_child(panel)
	var label: Label = Label.new()
	label.text = (
		str(definition.get("icon", "◇"))
		+ "\nNO RECORDS LEARNED YET\n\n"
		+ str(definition.get("empty", "This shelf is empty."))
	)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", TEXT_DIM)
	panel.add_child(label)


func _make_journal_detail_panel(
	row: Dictionary,
	category_definition: Dictionary
) -> PanelContainer:
	var panel: PanelContainer = _make_magic_subpanel()
	panel.name = "JournalDetailPanel"
	panel.custom_minimum_size = Vector2(410.0, 0.0)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 9)
	margin.add_child(stack)

	if row.is_empty():
		var empty_title: Label = Label.new()
		empty_title.text = str(category_definition.get("title", "Journal"))
		empty_title.add_theme_font_size_override("font_size", 20)
		empty_title.add_theme_color_override("font_color", TEXT_MAIN)
		stack.add_child(empty_title)
		var empty_copy: Label = Label.new()
		empty_copy.text = str(category_definition.get("empty", "No records yet."))
		empty_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_copy.add_theme_font_size_override("font_size", 12)
		empty_copy.add_theme_color_override("font_color", TEXT_SOFT)
		stack.add_child(empty_copy)
		return panel

	var learned: bool = bool(row.get("learned", false))
	var icon: Label = Label.new()
	icon.text = str(row.get("icon", "◇"))
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 42)
	icon.add_theme_color_override("font_color", JOURNAL_ACTIVE_BORDER)
	stack.add_child(icon)
	var title: Label = Label.new()
	title.text = str(row.get("name", "Record"))
	if not learned and not OS.is_debug_build():
		title.text = "Undiscovered Record"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", TEXT_MAIN)
	stack.add_child(title)
	var status: Label = Label.new()
	status.text = str(row.get("status", "RECORDED"))
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 10)
	status.add_theme_color_override("font_color", JOURNAL_ACTIVE_BORDER)
	stack.add_child(status)
	var summary: Label = Label.new()
	summary.text = str(row.get("summary", "No notes recorded."))
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_theme_font_size_override("font_size", 12)
	summary.add_theme_color_override("font_color", TEXT_SOFT)
	stack.add_child(summary)

	var details: Array[String] = _journal_string_array(row.get("details", []))
	for detail_text: String in details:
		var detail: Label = Label.new()
		detail.text = detail_text
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.add_theme_font_size_override("font_size", 10)
		detail.add_theme_color_override("font_color", TEXT_MAIN)
		stack.add_child(detail)
	var source: String = str(row.get("source", ""))
	if source != "":
		var source_label: Label = Label.new()
		source_label.text = "HOW TO LEARN  •  " + source
		source_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		source_label.add_theme_font_size_override("font_size", 10)
		source_label.add_theme_color_override("font_color", TEXT_DIM)
		stack.add_child(source_label)
	return panel


func _get_journal_rows(category_id: String) -> Array[Dictionary]:
	match category_id:
		"recipes":
			return JournalCatalogScript.get_cooking_rows()
		"potions":
			return JournalCatalogScript.get_potion_rows()
		"crafts":
			return JournalCatalogScript.get_craft_rows()
		"blueprints":
			return JournalCatalogScript.get_blueprint_rows(
				menu_data.get("inventory_items", [])
			)
		"fauna":
			return _get_fauna_rows()
		"flora":
			return JournalCatalogScript.get_flora_rows()
		"notes":
			return _get_field_note_rows()
	return []


func _get_fauna_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var service: Node = get_node_or_null("/root/SpeciesKnowledge")
	if service == null or not service.has_method("get_all_species_rows"):
		return rows
	var value: Variant = service.call("get_all_species_rows", true)
	if not value is Array:
		return rows
	for raw: Variant in value as Array:
		if not raw is Dictionary:
			continue
		var species: Dictionary = raw as Dictionary
		var observed: bool = bool(species.get("observed", false))
		var discovery_labels: Array[String] = _journal_string_array(
			species.get("discovery_labels", [])
		)
		var unlock_labels: Array[String] = _journal_string_array(
			species.get("unlock_labels", [])
		)
		var details: Array[String] = [
			"Category: " + str(species.get("category", "Species")),
			"Knowledge: " + str(species.get("points", 0)) + " points",
			"Rank: " + str(species.get("rank", 0)) + "/" + str(species.get("max_rank", 0)),
		]
		if not discovery_labels.is_empty():
			details.append("Observed: " + ", ".join(discovery_labels.slice(0, mini(discovery_labels.size(), 4))))
		if not unlock_labels.is_empty():
			details.append("Learned: " + ", ".join(unlock_labels.slice(0, mini(unlock_labels.size(), 4))))
		rows.append({
			"id": str(species.get("id", "species")),
			"name": str(species.get("name", "Species")),
			"icon": str(species.get("icon", "🐾")),
			"summary": str(species.get("summary", "Field observation record.")),
			"learned": observed,
			"status": str(species.get("rank_title", "Unobserved")).to_upper(),
			"source": (
				"Continue observing behavior in the field."
				if observed
				else "Encounter and observe this species."
			),
			"details": details,
		})
	return rows


func _get_field_note_rows() -> Array[Dictionary]:
	var objective: String = str(menu_data.get("objective", "Look around."))
	var key_items: Array[Dictionary] = _journal_dictionary_array(
		menu_data.get("key_items", [])
	)
	return [
		{
			"id": "current_objective",
			"name": "Current Objective",
			"icon": "★",
			"summary": objective,
			"learned": true,
			"status": "ACTIVE",
			"source": "Updated by quests and world events.",
			"details": ["Grace's immediate active lead."],
		},
		{
			"id": "clues",
			"name": "Clues & Evidence",
			"icon": "?",
			"summary": "Story clues, relic evidence, puzzle notes, and unresolved leads.",
			"learned": not key_items.is_empty(),
			"status": str(key_items.size()) + " ENTRIES",
			"source": "Inspect unusual objects and complete investigations.",
			"details": ["Key-item records currently available: " + str(key_items.size())],
		},
		{
			"id": "people",
			"name": "People",
			"icon": "♙",
			"summary": "Relationships, affiliations, promises, suspicions, and remembered conversations.",
			"learned": false,
			"status": "FOUNDATION",
			"source": "Meet people and learn what matters to them.",
			"details": ["Character relationship logging is reserved."],
		},
		{
			"id": "places",
			"name": "Places",
			"icon": "⌖",
			"summary": "Regions, settlements, dungeons, routes, hazards, and local discoveries.",
			"learned": false,
			"status": "FOUNDATION",
			"source": "Explore and map meaningful locations.",
			"details": ["Location discovery logging is reserved."],
		},
		{
			"id": "experiments",
			"name": "Experiments",
			"icon": "⌁",
			"summary": "Player-discovered reactions, construction tests, unusual spell uses, and repeatable findings.",
			"learned": false,
			"status": "FOUNDATION",
			"source": "Discover reproducible behavior in the systemic sandbox.",
			"details": ["Experiment journaling is reserved for future discovery hooks."],
		},
	]


func _toggle_journal_category(category_id: String) -> void:
	if not JournalCatalogScript.has_category(category_id):
		return
	if (
		journal_page == JOURNAL_CATEGORY
		and selected_journal_category == category_id
	):
		_reset_journal_workspace()
	else:
		journal_page = JOURNAL_CATEGORY
		selected_journal_category = category_id
		selected_journal_record_id = ""
		var rows: Array[Dictionary] = _get_journal_rows(category_id)
		if not rows.is_empty():
			selected_journal_record_id = str(rows[0].get("id", ""))
	selected_action_index = JournalCatalogScript.CATEGORY_ORDER.find(category_id)
	tab_action_memory["journal"] = maxi(selected_action_index, 0)
	rebuild_menu()


func _reset_journal_workspace() -> void:
	journal_page = JOURNAL_OVERVIEW
	selected_journal_category = ""
	selected_journal_record_id = ""


func _get_journal_page_title() -> String:
	if journal_page == JOURNAL_CATEGORY and selected_journal_category != "":
		var definition: Dictionary = JournalCatalogScript.get_definition(
			selected_journal_category
		)
		return "📜 Journal  ›  " + str(
			definition.get("title", selected_journal_category.capitalize())
		)
	return "📜 Journal"


func _find_journal_row(
	rows: Array[Dictionary],
	record_id: String
) -> Dictionary:
	for row: Dictionary in rows:
		if str(row.get("id", "")) == record_id:
			return row
	return {}


func _count_learned_records(rows: Array[Dictionary]) -> int:
	var count: int = 0
	for row: Dictionary in rows:
		if bool(row.get("learned", false)):
			count += 1
	return count


func _update_scroll_policy() -> void:
	if scroll_container == null:
		return
	if get_current_tab_id() in ["loadout", "magic", "items", "journal"]:
		scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll_container.scroll_vertical = 0
		scroll_container.scroll_horizontal = 0
	else:
		scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO


func get_journal_debug_data() -> Dictionary:
	return {
		"page": journal_page,
		"selected_category": selected_journal_category,
		"category_count": JournalCatalogScript.CATEGORY_ORDER.size(),
		"potion_count": _get_journal_rows("potions").size(),
		"fauna_count": _get_journal_rows("fauna").size(),
		"flora_count": _get_journal_rows("flora").size(),
		"note_count": _get_journal_rows("notes").size(),
		"category_strip_present": find_child("JournalCategoryStrip", true, false) != null,
		"workspace_present": find_child("JournalWorkspace", true, false) != null,
		"scroll_disabled": (
			scroll_container != null
			and scroll_container.vertical_scroll_mode
			== ScrollContainer.SCROLL_MODE_DISABLED
		),
	}


func _journal_dictionary_array(value: Variant) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if value is Array:
		for entry: Variant in value as Array:
			if entry is Dictionary:
				rows.append((entry as Dictionary).duplicate(true))
	return rows


func _journal_string_array(value: Variant) -> Array[String]:
	var rows: Array[String] = []
	if value is Array:
		for entry: Variant in value as Array:
			rows.append(str(entry))
	return rows
