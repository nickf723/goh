extends "res://scripts/ui/full_menu_shell_journal_v2.gd"
class_name FullMenuShellCodexV1

const CodexCatalogScript = preload(
	"res://scripts/codex/codex_progress_catalog.gd"
)

const CODEX_OVERVIEW: String = "overview"
const CODEX_CATEGORY: String = "category"
const CODEX_PAGE_SIZE: int = 8

const CODEX_BACKGROUND: Color = Color(0.052, 0.06, 0.085, 0.96)
const CODEX_ACTIVE_BACKGROUND: Color = Color(0.105, 0.085, 0.045, 0.98)
const CODEX_ACTIVE_BORDER: Color = Color(0.98, 0.72, 0.25, 0.98)

var codex_page: String = CODEX_OVERVIEW
var selected_codex_category: String = ""
var selected_codex_record_id: String = ""
var codex_record_page: int = 0


func hide_menu() -> void:
	_reset_codex_workspace()
	super.hide_menu()


func select_tab(index: int) -> void:
	if get_current_tab_id() == "codex":
		_reset_codex_workspace()
	super.select_tab(index)


func handle_menu_input(event: InputEvent) -> bool:
	if not visible:
		return false
	if get_current_tab_id() == "codex":
		var cancel_requested: bool = (
			is_menu_cancel_event(event)
			if event is InputEventJoypadButton
			else event.is_action_pressed("ui_cancel")
		)
		if cancel_requested and not is_assignment_active() and codex_page != CODEX_OVERVIEW:
			_reset_codex_workspace()
			selected_action_index = 0
			tab_action_memory["codex"] = 0
			rebuild_menu()
			return true
	return super.handle_menu_input(event)


func activate_action(action: Dictionary) -> void:
	match str(action.get("kind", "")):
		"toggle_codex_category":
			_toggle_codex_category(str(action.get("category_id", "")))
		"select_codex_record":
			selected_codex_record_id = str(action.get("record_id", ""))
			rebuild_menu()
		"codex_page_delta":
			_change_codex_page(int(action.get("delta", 0)))
		_:
			super.activate_action(action)


func get_footer_text() -> String:
	if get_current_tab_id() == "codex" and not is_assignment_active():
		if codex_page == CODEX_OVERVIEW:
			return "L/R: tabs  •  D-pad or left stick: pursuit  •  Right stick: cursor  •  A: open  •  B: close"
		return "D-pad or left stick: navigate  •  Right stick: cursor  •  A: inspect/page  •  B: Codex overview"
	return super.get_footer_text()


func render_codex() -> void:
	content_title_label.text = _get_codex_page_title()
	action_layout_mode = "screen_geometry"
	action_grid_columns = 1
	_update_scroll_policy()

	var category_grid: GridContainer = make_visual_grid(5)
	category_grid.name = "CodexCategoryStrip"
	category_grid.add_theme_constant_override("h_separation", 8)
	content_box.add_child(category_grid)
	for category_id: String in CodexCatalogScript.CATEGORY_ORDER:
		_add_codex_category_tile(category_grid, category_id)

	var workspace: PanelContainer = PanelContainer.new()
	workspace.name = "CodexWorkspace"
	workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.add_theme_stylebox_override(
		"panel",
		make_panel_style(Color(0.025, 0.033, 0.052, 0.96), CARD_BORDER, 1, 13)
	)
	content_box.add_child(workspace)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	workspace.add_child(margin)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.name = "CodexWorkspaceContent"
	stack.add_theme_constant_override("separation", 9)
	margin.add_child(stack)

	if codex_page == CODEX_CATEGORY and selected_codex_category != "":
		_render_codex_category(stack, selected_codex_category)
	else:
		_render_codex_overview(stack)


func _add_codex_category_tile(parent: Container, category_id: String) -> void:
	var definition: Dictionary = CodexCatalogScript.get_definition(category_id)
	var rows: Array[Dictionary] = CodexCatalogScript.get_rows(category_id)
	var completed: int = _count_codex_complete(rows)
	var action_index: int = selectable_actions.size()
	selectable_actions.append({"kind": "toggle_codex_category", "category_id": category_id})
	var selected: bool = action_index == selected_action_index
	var active: bool = codex_page == CODEX_CATEGORY and selected_codex_category == category_id
	var button: Button = Button.new()
	button.text = (
		str(definition.get("icon", "◇")) + "\n"
		+ str(definition.get("title", category_id.capitalize())) + "\n"
		+ str(completed) + "/" + str(rows.size())
	)
	button.tooltip_text = str(definition.get("description", ""))
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(150.0, 72.0)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_color_override("font_color", TEXT_MAIN if selected or active else TEXT_SOFT)
	button.add_theme_stylebox_override(
		"normal",
		make_panel_style(
			ACTIVE_SELECTION_BACKGROUND if selected else (CODEX_ACTIVE_BACKGROUND if active else CODEX_BACKGROUND),
			ACTIVE_SELECTION_BORDER if selected else (CODEX_ACTIVE_BORDER if active else CARD_BORDER),
			3 if selected else (2 if active else 1),
			9
		)
	)
	button.add_theme_stylebox_override("focus", make_panel_style(ACTIVE_SELECTION_BACKGROUND, ACTIVE_SELECTION_BORDER, 3, 9))
	button.add_theme_stylebox_override("hover", make_panel_style(Color(0.15, 0.11, 0.045, 0.98), CODEX_ACTIVE_BORDER, 2, 9))
	button.pressed.connect(_on_action_row_pressed.bind(action_index))
	button.mouse_entered.connect(_on_action_row_hovered.bind(action_index))
	parent.add_child(button)
	_register_action_control(button, action_index)
	if selected:
		schedule_selected_control(button)


func _render_codex_overview(parent: VBoxContainer) -> void:
	parent.add_child(_make_magic_heading("PURSUITS, CHALLENGES & COMPLETION"))
	var intro: Label = Label.new()
	intro.text = (
		"The Codex tracks what Grace is pursuing and what each pursuit unlocks. "
		+ "The Journal now owns learned knowledge, including the complete elemental reaction grammar."
	)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_font_size_override("font_size", 12)
	intro.add_theme_color_override("font_color", TEXT_SOFT)
	parent.add_child(intro)

	var summary: Dictionary = CodexCatalogScript.get_summary()
	var summary_grid: GridContainer = make_visual_grid(4)
	summary_grid.add_theme_constant_override("h_separation", 8)
	parent.add_child(summary_grid)
	_add_magic_info_panel(summary_grid, str(summary.get("story_active", 0)) + " STORY ACTIVE", "Primary quest paths")
	_add_magic_info_panel(summary_grid, str(summary.get("side_active", 0)) + " SIDE ACTIVE", "Optional quest paths")
	_add_magic_info_panel(
		summary_grid,
		str(summary.get("challenges_complete", 0)) + "/" + str(summary.get("challenges_total", 0)) + " UNLOCKS",
		"Challenge rewards claimed"
	)
	_add_magic_info_panel(
		summary_grid,
		str(summary.get("achievements_complete", 0)) + "/" + str(summary.get("achievements_total", 0)) + " ACHIEVEMENTS",
		"Persistent milestones"
	)

	parent.add_child(_make_magic_heading("HOW THE CODEX WORKS"))
	var map_grid: GridContainer = make_visual_grid(5)
	map_grid.add_theme_constant_override("h_separation", 8)
	parent.add_child(map_grid)
	for category_id: String in CodexCatalogScript.CATEGORY_ORDER:
		var definition: Dictionary = CodexCatalogScript.get_definition(category_id)
		_add_magic_info_panel(
			map_grid,
			str(definition.get("icon", "◇")) + "  " + str(definition.get("title", category_id.capitalize())).to_upper(),
			str(definition.get("description", "Tracked progress."))
		)


func _render_codex_category(parent: VBoxContainer, category_id: String) -> void:
	var definition: Dictionary = CodexCatalogScript.get_definition(category_id)
	var rows: Array[Dictionary] = CodexCatalogScript.get_rows(category_id)
	var page_count: int = maxi(ceili(float(rows.size()) / float(CODEX_PAGE_SIZE)), 1)
	codex_record_page = clampi(codex_record_page, 0, page_count - 1)
	var page_start: int = codex_record_page * CODEX_PAGE_SIZE
	var page_end: int = mini(page_start + CODEX_PAGE_SIZE, rows.size())
	var page_rows: Array[Dictionary] = []
	for index: int in range(page_start, page_end):
		page_rows.append(rows[index])

	parent.add_child(
		_make_magic_heading(
			str(definition.get("icon", "◇")) + "  "
			+ str(definition.get("title", category_id.capitalize())).to_upper()
			+ "  •  PAGE " + str(codex_record_page + 1) + "/" + str(page_count)
		)
	)
	var description: Label = Label.new()
	description.text = str(definition.get("description", ""))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 11)
	description.add_theme_color_override("font_color", TEXT_SOFT)
	parent.add_child(description)

	var workspace: HBoxContainer = HBoxContainer.new()
	workspace.name = "CodexCategoryWorkspace"
	workspace.add_theme_constant_override("separation", 12)
	workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(workspace)

	var left_stack: VBoxContainer = VBoxContainer.new()
	left_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_stack.add_theme_constant_override("separation", 7)
	workspace.add_child(left_stack)
	var record_panel: PanelContainer = _make_magic_subpanel()
	record_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_stack.add_child(record_panel)
	var record_margin: MarginContainer = MarginContainer.new()
	record_margin.add_theme_constant_override("margin_left", 10)
	record_margin.add_theme_constant_override("margin_top", 10)
	record_margin.add_theme_constant_override("margin_right", 10)
	record_margin.add_theme_constant_override("margin_bottom", 10)
	record_panel.add_child(record_margin)
	var record_grid: GridContainer = make_visual_grid(4)
	record_grid.name = "CodexRecordGrid"
	record_grid.add_theme_constant_override("h_separation", 7)
	record_grid.add_theme_constant_override("v_separation", 7)
	record_margin.add_child(record_grid)

	if rows.is_empty():
		_add_empty_codex_card(record_grid, definition)
		selected_codex_record_id = ""
	else:
		if _find_codex_row(rows, selected_codex_record_id).is_empty() or not _page_contains(page_rows, selected_codex_record_id):
			selected_codex_record_id = str(page_rows[0].get("id", "")) if not page_rows.is_empty() else ""
		for row: Dictionary in page_rows:
			_add_codex_record_tile(record_grid, row)

	var pager: HBoxContainer = HBoxContainer.new()
	pager.alignment = BoxContainer.ALIGNMENT_CENTER
	pager.add_theme_constant_override("separation", 10)
	left_stack.add_child(pager)
	_add_codex_pager_button(pager, "‹", "Previous", -1, codex_record_page > 0)
	var page_label: Label = Label.new()
	page_label.text = "PAGE " + str(codex_record_page + 1) + " / " + str(page_count)
	page_label.add_theme_font_size_override("font_size", 11)
	page_label.add_theme_color_override("font_color", CODEX_ACTIVE_BORDER)
	pager.add_child(page_label)
	_add_codex_pager_button(pager, "›", "Next", 1, codex_record_page < page_count - 1)

	workspace.add_child(
		_make_codex_detail_panel(
			_find_codex_row(rows, selected_codex_record_id),
			definition
		)
	)


func _add_codex_record_tile(parent: Container, row: Dictionary) -> void:
	var record_id: String = str(row.get("id", "record"))
	var complete: bool = bool(row.get("complete", false))
	var action_index: int = selectable_actions.size()
	selectable_actions.append({"kind": "select_codex_record", "record_id": record_id})
	var selected: bool = action_index == selected_action_index
	var inspected: bool = record_id == selected_codex_record_id
	var percent: int = roundi(clampf(float(row.get("progress_fraction", 0.0)), 0.0, 1.0) * 100.0)
	var button: Button = Button.new()
	button.text = (
		str(row.get("icon", "◇")) + "  " + str(row.get("name", record_id.capitalize()))
		+ "\n" + str(row.get("status", "ACTIVE")) + "  •  " + str(percent) + "%"
	)
	button.tooltip_text = str(row.get("summary", ""))
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(128.0, 76.0)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 9)
	button.add_theme_color_override("font_color", TEXT_MAIN if selected or inspected else (TEXT_SOFT if not complete else Color(0.56, 0.9, 0.7)))
	button.add_theme_stylebox_override(
		"normal",
		make_panel_style(
			ACTIVE_SELECTION_BACKGROUND if selected else (CODEX_ACTIVE_BACKGROUND if inspected else CARD_BACKGROUND),
			ACTIVE_SELECTION_BORDER if selected else (CODEX_ACTIVE_BORDER if inspected else CARD_BORDER),
			3 if selected else (2 if inspected else 1),
			8
		)
	)
	button.add_theme_stylebox_override("focus", make_panel_style(ACTIVE_SELECTION_BACKGROUND, ACTIVE_SELECTION_BORDER, 3, 8))
	button.add_theme_stylebox_override("hover", make_panel_style(Color(0.15, 0.11, 0.045, 0.98), CODEX_ACTIVE_BORDER, 2, 8))
	button.pressed.connect(_on_action_row_pressed.bind(action_index))
	button.mouse_entered.connect(_on_action_row_hovered.bind(action_index))
	parent.add_child(button)
	_register_action_control(button, action_index)
	if selected:
		schedule_selected_control(button)


func _add_codex_pager_button(parent: Container, icon: String, title: String, delta: int, enabled: bool) -> void:
	if not enabled:
		var spacer: Label = Label.new()
		spacer.text = icon + "  " + title
		spacer.custom_minimum_size = Vector2(120.0, 34.0)
		spacer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		spacer.add_theme_color_override("font_color", TEXT_DIM)
		parent.add_child(spacer)
		return
	var action_index: int = selectable_actions.size()
	selectable_actions.append({"kind": "codex_page_delta", "delta": delta})
	var button: Button = Button.new()
	button.text = icon + "  " + title
	button.custom_minimum_size = Vector2(120.0, 34.0)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_stylebox_override("normal", make_panel_style(CODEX_BACKGROUND, CARD_BORDER, 1, 8))
	button.add_theme_stylebox_override("focus", make_panel_style(ACTIVE_SELECTION_BACKGROUND, ACTIVE_SELECTION_BORDER, 3, 8))
	button.add_theme_stylebox_override("hover", make_panel_style(CODEX_ACTIVE_BACKGROUND, CODEX_ACTIVE_BORDER, 2, 8))
	button.pressed.connect(_on_action_row_pressed.bind(action_index))
	button.mouse_entered.connect(_on_action_row_hovered.bind(action_index))
	parent.add_child(button)
	_register_action_control(button, action_index)


func _add_empty_codex_card(parent: Container, definition: Dictionary) -> void:
	var panel: PanelContainer = _make_magic_subpanel()
	panel.custom_minimum_size = Vector2(520.0, 220.0)
	parent.add_child(panel)
	var label: Label = Label.new()
	label.text = str(definition.get("icon", "◇")) + "\nNO ACTIVE RECORDS\n\n" + str(definition.get("description", "Nothing tracked yet."))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", TEXT_DIM)
	panel.add_child(label)


func _make_codex_detail_panel(row: Dictionary, definition: Dictionary) -> PanelContainer:
	var panel: PanelContainer = _make_magic_subpanel()
	panel.name = "CodexDetailPanel"
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
		var empty: Label = Label.new()
		empty.text = str(definition.get("description", "No records."))
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_color_override("font_color", TEXT_SOFT)
		stack.add_child(empty)
		return panel

	var icon: Label = Label.new()
	icon.text = str(row.get("icon", "◇"))
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 40)
	icon.add_theme_color_override("font_color", CODEX_ACTIVE_BORDER)
	stack.add_child(icon)
	var title: Label = Label.new()
	title.text = str(row.get("name", "Codex Record"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", TEXT_MAIN)
	stack.add_child(title)
	var status: Label = Label.new()
	status.text = str(row.get("status", "ACTIVE"))
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 10)
	status.add_theme_color_override("font_color", CODEX_ACTIVE_BORDER)
	stack.add_child(status)

	var progress: ProgressBar = ProgressBar.new()
	progress.name = "CodexProgressBar"
	progress.min_value = 0.0
	progress.max_value = float(maxi(int(row.get("progress_target", 1)), 1))
	progress.value = float(row.get("progress_current", 0))
	progress.show_percentage = true
	progress.custom_minimum_size = Vector2(0.0, 24.0)
	stack.add_child(progress)
	var fraction_label: Label = Label.new()
	fraction_label.text = str(row.get("progress_current", 0)) + " / " + str(row.get("progress_target", 1))
	fraction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fraction_label.add_theme_font_size_override("font_size", 10)
	fraction_label.add_theme_color_override("font_color", TEXT_SOFT)
	stack.add_child(fraction_label)

	for heading_and_text: Array[String] in [
		["SUMMARY", str(row.get("summary", ""))],
		["REQUIREMENT", str(row.get("requirement", ""))],
		["REWARD", str(row.get("reward", ""))],
	]:
		var label: Label = Label.new()
		label.text = heading_and_text[0] + "  •  " + heading_and_text[1]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", TEXT_MAIN if heading_and_text[0] != "SUMMARY" else TEXT_SOFT)
		stack.add_child(label)
	for detail_text: String in _codex_string_array(row.get("details", [])):
		var detail: Label = Label.new()
		detail.text = detail_text
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.add_theme_font_size_override("font_size", 9)
		detail.add_theme_color_override("font_color", TEXT_DIM)
		stack.add_child(detail)
	return panel


func _toggle_codex_category(category_id: String) -> void:
	if not CodexCatalogScript.CATEGORY_ORDER.has(category_id):
		return
	if codex_page == CODEX_CATEGORY and selected_codex_category == category_id:
		_reset_codex_workspace()
	else:
		codex_page = CODEX_CATEGORY
		selected_codex_category = category_id
		selected_codex_record_id = ""
		codex_record_page = 0
		var rows: Array[Dictionary] = CodexCatalogScript.get_rows(category_id)
		if not rows.is_empty():
			selected_codex_record_id = str(rows[0].get("id", ""))
	selected_action_index = CodexCatalogScript.CATEGORY_ORDER.find(category_id)
	tab_action_memory["codex"] = maxi(selected_action_index, 0)
	rebuild_menu()


func _change_codex_page(delta: int) -> void:
	var rows: Array[Dictionary] = CodexCatalogScript.get_rows(selected_codex_category)
	var page_count: int = maxi(ceili(float(rows.size()) / float(CODEX_PAGE_SIZE)), 1)
	codex_record_page = clampi(codex_record_page + delta, 0, page_count - 1)
	var first_index: int = codex_record_page * CODEX_PAGE_SIZE
	selected_codex_record_id = str(rows[first_index].get("id", "")) if first_index < rows.size() else ""
	rebuild_menu()


func _reset_codex_workspace() -> void:
	codex_page = CODEX_OVERVIEW
	selected_codex_category = ""
	selected_codex_record_id = ""
	codex_record_page = 0


func _get_codex_page_title() -> String:
	if codex_page == CODEX_CATEGORY and selected_codex_category != "":
		return "🧩 Codex  ›  " + str(CodexCatalogScript.get_definition(selected_codex_category).get("title", selected_codex_category.capitalize()))
	return "🧩 Codex"


func _find_codex_row(rows: Array[Dictionary], record_id: String) -> Dictionary:
	for row: Dictionary in rows:
		if str(row.get("id", "")) == record_id:
			return row
	return {}


func _page_contains(rows: Array[Dictionary], record_id: String) -> bool:
	return not _find_codex_row(rows, record_id).is_empty()


func _count_codex_complete(rows: Array[Dictionary]) -> int:
	var count: int = 0
	for row: Dictionary in rows:
		if bool(row.get("complete", false)):
			count += 1
	return count


func _codex_string_array(value: Variant) -> Array[String]:
	var rows: Array[String] = []
	if value is Array:
		for raw: Variant in value as Array:
			rows.append(str(raw))
	return rows


func _update_scroll_policy() -> void:
	if scroll_container == null:
		return
	if get_current_tab_id() in ["loadout", "magic", "items", "journal", "codex"]:
		scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll_container.scroll_vertical = 0
		scroll_container.scroll_horizontal = 0
	else:
		scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO


func get_codex_debug_data() -> Dictionary:
	return {
		"page": codex_page,
		"selected_category": selected_codex_category,
		"category_count": CodexCatalogScript.CATEGORY_ORDER.size(),
		"story_count": CodexCatalogScript.get_rows("story").size(),
		"side_count": CodexCatalogScript.get_rows("side").size(),
		"challenge_count": CodexCatalogScript.get_rows("challenges").size(),
		"achievement_count": CodexCatalogScript.get_rows("achievements").size(),
		"completion_count": CodexCatalogScript.get_rows("completion").size(),
		"record_page": codex_record_page,
		"category_strip_present": find_child("CodexCategoryStrip", true, false) != null,
		"workspace_present": find_child("CodexWorkspace", true, false) != null,
		"scroll_disabled": (
			scroll_container != null
			and scroll_container.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED
		),
	}
