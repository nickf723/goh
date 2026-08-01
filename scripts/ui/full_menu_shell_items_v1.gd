extends "res://scripts/ui/full_menu_shell_magic_v3.gd"
class_name FullMenuShellItemsV1

const ItemCategoryCatalogScript = preload(
	"res://scripts/items/item_inventory_category_catalog.gd"
)

const FIELD_KIT_TAB_DEFS: Array[Dictionary] = [
	{"id": "loadout", "title": "Grace", "icon": "◇"},
	{"id": "magic", "title": "Magic", "icon": "✦"},
	{"id": "items", "title": "Items", "icon": "🧪"},
	{"id": "journal", "title": "Journal", "icon": "📜"},
	{"id": "codex", "title": "Codex", "icon": "🧩"},
	{"id": "system", "title": "System", "icon": "⚙"},
]

const ITEMS_OVERVIEW: String = "overview"
const ITEMS_CATEGORY: String = "category"

const ITEM_CATEGORY_BACKGROUND: Color = Color(0.055, 0.068, 0.09, 0.94)
const ITEM_CATEGORY_ACTIVE_BACKGROUND: Color = Color(0.07, 0.125, 0.12, 0.98)
const ITEM_CATEGORY_ACTIVE_BORDER: Color = Color(0.36, 0.9, 0.74, 0.96)

var items_page: String = ITEMS_OVERVIEW
var selected_item_category: String = ""
var selected_inventory_item_id: String = ""


func show_menu(new_menu_data: Dictionary) -> void:
	menu_data = new_menu_data.duplicate(true)
	selected_tab_index = clampi(
		selected_tab_index,
		0,
		FIELD_KIT_TAB_DEFS.size() - 1
	)
	selected_action_index = int(
		tab_action_memory.get(get_current_tab_id(), selected_action_index)
	)
	visible = true
	rebuild_menu()


func hide_menu() -> void:
	_reset_item_workspace()
	super.hide_menu()


func get_current_tab_id() -> String:
	if selected_tab_index < 0 or selected_tab_index >= FIELD_KIT_TAB_DEFS.size():
		return "loadout"
	return str(FIELD_KIT_TAB_DEFS[selected_tab_index].get("id", "loadout"))


func get_tab_index(tab_id: String) -> int:
	for index: int in range(FIELD_KIT_TAB_DEFS.size()):
		if str(FIELD_KIT_TAB_DEFS[index].get("id", "")) == tab_id:
			return index
	return 0


func select_tab(index: int) -> void:
	if is_assignment_active():
		return
	remember_current_action()
	match get_current_tab_id():
		"loadout":
			_reset_grace_accordion()
		"magic":
			_reset_magic_workspace()
			selected_patron_id = ""
		"items":
			_reset_item_workspace()
	selected_tab_index = posmod(index, FIELD_KIT_TAB_DEFS.size())
	selected_action_index = int(
		tab_action_memory.get(get_current_tab_id(), 0)
	)
	rebuild_menu()


func rebuild_tabs() -> void:
	clear_children(tab_box)
	for index: int in range(FIELD_KIT_TAB_DEFS.size()):
		var tab_def: Dictionary = FIELD_KIT_TAB_DEFS[index]
		var is_selected: bool = index == selected_tab_index
		var tab_button: Button = Button.new()
		tab_button.text = (
			str(tab_def.get("icon", ""))
			+ "\n"
			+ str(tab_def.get("title", "Tab"))
		)
		tab_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		tab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_button.custom_minimum_size = Vector2(112.0, 58.0)
		tab_button.add_theme_font_size_override("font_size", 13)
		tab_button.add_theme_color_override(
			"font_color",
			TEXT_MAIN if is_selected else TEXT_SOFT
		)
		tab_button.add_theme_stylebox_override(
			"normal",
			make_panel_style(
				ACTIVE_SELECTION_BACKGROUND
				if is_selected
				else Color(0.045, 0.06, 0.083, 0.72),
				ACTIVE_SELECTION_BORDER if is_selected else CARD_BORDER,
				3 if is_selected else 1,
				9
			)
		)
		tab_button.add_theme_stylebox_override(
			"hover",
			make_panel_style(
				Color(0.13, 0.105, 0.08, 0.9),
				ACTIVE_SELECTION_BORDER,
				2,
				9
			)
		)
		tab_button.pressed.connect(_on_tab_pressed.bind(index))
		tab_box.add_child(tab_button)


func rebuild_content() -> void:
	selectable_actions.clear()
	selected_action_control = null
	action_grid_columns = 1
	action_layout_mode = "list"
	clear_children(content_box)

	var tab_def: Dictionary = FIELD_KIT_TAB_DEFS[selected_tab_index]
	var tab_id: String = str(tab_def.get("id", "loadout"))
	content_title_label.text = (
		str(tab_def.get("icon", ""))
		+ " "
		+ str(tab_def.get("title", "Grace"))
	)
	match tab_id:
		"loadout":
			render_loadout()
		"magic":
			render_magic()
		"items":
			render_items()
		"journal":
			render_journal()
		"codex":
			render_codex()
		"system":
			render_system()
		_:
			add_text_card("Coming Soon", "This shelf has not been built yet.")

	if selectable_actions.is_empty():
		selected_action_index = 0
	else:
		selected_action_index = clampi(
			selected_action_index,
			0,
			selectable_actions.size() - 1
		)


func handle_menu_input(event: InputEvent) -> bool:
	if not visible:
		return false
	if get_current_tab_id() == "items":
		var cancel_requested: bool = (
			is_menu_cancel_event(event)
			if event is InputEventJoypadButton
			else event.is_action_pressed("ui_cancel")
		)
		if (
			cancel_requested
			and not is_assignment_active()
			and items_page != ITEMS_OVERVIEW
		):
			_reset_item_workspace()
			selected_action_index = 0
			tab_action_memory["items"] = 0
			rebuild_menu()
			return true
	return super.handle_menu_input(event)


func activate_action(action: Dictionary) -> void:
	match str(action.get("kind", "")):
		"toggle_item_category":
			_toggle_item_category(str(action.get("category_id", "")))
		"select_inventory_record":
			selected_inventory_item_id = str(action.get("item_id", ""))
			rebuild_menu()
		_:
			super.activate_action(action)


func get_footer_text() -> String:
	if get_current_tab_id() == "items" and not is_assignment_active():
		if items_page == ITEMS_OVERVIEW:
			return "L/R: tabs  •  D-pad or left stick: category  •  Right stick: cursor  •  A: expand  •  B: close"
		return "D-pad or left stick: navigate  •  Right stick: cursor  •  A: inspect  •  B: collapse category"
	return super.get_footer_text()


func render_items() -> void:
	if is_assigning_item() or is_assigning_item_slot():
		super.render_items()
		return

	content_title_label.text = _get_items_page_title()
	action_layout_mode = "screen_geometry"
	action_grid_columns = 1
	_update_scroll_policy()

	var category_grid: GridContainer = make_visual_grid(7)
	category_grid.name = "ItemsCategoryStrip"
	category_grid.add_theme_constant_override("h_separation", 7)
	content_box.add_child(category_grid)
	for category_id: String in ItemCategoryCatalogScript.CATEGORY_ORDER:
		_add_item_category_tile(category_grid, category_id)

	var workspace: PanelContainer = PanelContainer.new()
	workspace.name = "ItemsWorkspace"
	workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.add_theme_stylebox_override(
		"panel",
		make_panel_style(
			Color(0.025, 0.035, 0.052, 0.94),
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
	stack.name = "ItemsWorkspaceContent"
	stack.add_theme_constant_override("separation", 9)
	margin.add_child(stack)

	if items_page == ITEMS_CATEGORY and selected_item_category != "":
		if selected_item_category == "relics":
			_render_relics_category(stack)
		else:
			_render_inventory_category(stack, selected_item_category)
	else:
		_render_items_overview(stack)


func _add_item_category_tile(parent: Container, category_id: String) -> void:
	var definition: Dictionary = ItemCategoryCatalogScript.get_definition(category_id)
	var action_index: int = selectable_actions.size()
	selectable_actions.append({
		"kind": "toggle_item_category",
		"category_id": category_id,
	})
	var selected: bool = action_index == selected_action_index
	var active: bool = (
		items_page == ITEMS_CATEGORY
		and selected_item_category == category_id
	)
	var button: Button = Button.new()
	button.text = (
		str(definition.get("icon", "◇"))
		+ "\n"
		+ str(definition.get("short_title", category_id.capitalize()))
		+ "\n"
		+ str(_get_item_category_count(category_id))
		+ " OWNED"
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
			else (
				ITEM_CATEGORY_ACTIVE_BACKGROUND
				if active
				else ITEM_CATEGORY_BACKGROUND
			),
			ACTIVE_SELECTION_BORDER
			if selected
			else (ITEM_CATEGORY_ACTIVE_BORDER if active else CARD_BORDER),
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
			Color(0.08, 0.145, 0.13, 0.96),
			ITEM_CATEGORY_ACTIVE_BORDER,
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


func _render_items_overview(parent: VBoxContainer) -> void:
	parent.add_child(_make_magic_heading("PHYSICAL INVENTORY"))
	var intro: Label = Label.new()
	intro.text = (
		"Items are things Grace carries, consumes, trades, summons, or assembles. "
		+ "Magic remains responsible for spells, traditions, patrons, and supernatural configuration."
	)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_font_size_override("font_size", 12)
	intro.add_theme_color_override("font_color", TEXT_SOFT)
	parent.add_child(intro)

	var summary_grid: GridContainer = make_visual_grid(4)
	summary_grid.add_theme_constant_override("h_separation", 8)
	summary_grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(summary_grid)
	_add_magic_info_panel(
		summary_grid,
		str(_get_total_inventory_count()) + " CARRIED",
		"Physical item quantity"
	)
	_add_magic_info_panel(
		summary_grid,
		str(_get_total_inventory_types()) + " ITEM TYPES",
		"Distinct inventory records"
	)
	_add_magic_info_panel(
		summary_grid,
		str(_get_item_category_count("relics")) + " RELIC RECORDS",
		"Key items, blessings, and permissions"
	)
	_add_magic_info_panel(
		summary_grid,
		"7 SUBTABS",
		"Inventory can grow without changing the main menu"
	)

	parent.add_child(_make_magic_heading("MECHANIC MAP"))
	var mechanic_grid: GridContainer = make_visual_grid(3)
	mechanic_grid.add_theme_constant_override("h_separation", 8)
	mechanic_grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(mechanic_grid)
	for category_id: String in [
		"materials",
		"food",
		"potions",
		"objects",
		"builds",
		"relics",
	]:
		var definition: Dictionary = ItemCategoryCatalogScript.get_definition(
			category_id
		)
		_add_magic_info_panel(
			mechanic_grid,
			str(definition.get("title", category_id.capitalize())).to_upper(),
			str(definition.get("mechanic", "Reserved inventory mechanic"))
		)


func _render_inventory_category(
	parent: VBoxContainer,
	category_id: String
) -> void:
	var definition: Dictionary = ItemCategoryCatalogScript.get_definition(category_id)
	var rows: Array[Dictionary] = ItemCategoryCatalogScript.get_rows_for_category(
		menu_data.get("inventory_items", []),
		category_id
	)
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

	var workspace: HBoxContainer = HBoxContainer.new()
	workspace.name = "ItemsCategoryWorkspace"
	workspace.add_theme_constant_override("separation", 12)
	workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(workspace)

	var collection_panel: PanelContainer = _make_magic_subpanel()
	collection_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace.add_child(collection_panel)
	var collection_margin: MarginContainer = MarginContainer.new()
	collection_margin.add_theme_constant_override("margin_left", 10)
	collection_margin.add_theme_constant_override("margin_top", 10)
	collection_margin.add_theme_constant_override("margin_right", 10)
	collection_margin.add_theme_constant_override("margin_bottom", 10)
	collection_panel.add_child(collection_margin)
	var item_grid: GridContainer = make_visual_grid(3)
	item_grid.name = "ItemsOwnedGrid"
	item_grid.add_theme_constant_override("h_separation", 7)
	item_grid.add_theme_constant_override("v_separation", 7)
	collection_margin.add_child(item_grid)

	if rows.is_empty():
		_add_inventory_empty_card(item_grid, category_id)
		selected_inventory_item_id = ""
	else:
		if _find_inventory_row_by_id(rows, selected_inventory_item_id).is_empty():
			selected_inventory_item_id = str(rows[0].get("id", ""))
		for row: Dictionary in rows.slice(0, mini(rows.size(), 9)):
			_add_inventory_record_tile(item_grid, row)

	var detail_row: Dictionary = _find_inventory_row_by_id(
		rows,
		selected_inventory_item_id
	)
	workspace.add_child(
		_make_inventory_detail_panel(detail_row, definition, rows.size())
	)


func _add_inventory_record_tile(parent: Container, row: Dictionary) -> void:
	var item_id: String = str(row.get("id", ""))
	var action_index: int = selectable_actions.size()
	selectable_actions.append({
		"kind": "select_inventory_record",
		"item_id": item_id,
	})
	var selected: bool = action_index == selected_action_index
	var inspected: bool = item_id == selected_inventory_item_id
	var button: Button = Button.new()
	button.text = (
		str(row.get("icon", "◇"))
		+ "\n"
		+ str(row.get("name", item_id.capitalize()))
		+ "\n×"
		+ str(row.get("count", 0))
	)
	button.tooltip_text = str(row.get("description", ""))
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(135.0, 84.0)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override(
		"font_color",
		TEXT_MAIN if selected or inspected else TEXT_SOFT
	)
	button.add_theme_stylebox_override(
		"normal",
		make_panel_style(
			ACTIVE_SELECTION_BACKGROUND
			if selected
			else (
				ITEM_CATEGORY_ACTIVE_BACKGROUND
				if inspected
				else CARD_BACKGROUND
			),
			ACTIVE_SELECTION_BORDER
			if selected
			else (ITEM_CATEGORY_ACTIVE_BORDER if inspected else CARD_BORDER),
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
			Color(0.08, 0.145, 0.13, 0.96),
			ITEM_CATEGORY_ACTIVE_BORDER,
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


func _add_inventory_empty_card(parent: Container, category_id: String) -> void:
	var definition: Dictionary = ItemCategoryCatalogScript.get_definition(category_id)
	var panel: PanelContainer = _make_magic_subpanel()
	panel.custom_minimum_size = Vector2(420.0, 220.0)
	parent.add_child(panel)
	var label: Label = Label.new()
	label.text = (
		str(definition.get("icon", "◇"))
		+ "\nNO "
		+ str(definition.get("short_title", category_id.capitalize())).to_upper()
		+ " YET\n\n"
		+ str(definition.get("mechanic", "This inventory mechanic is reserved."))
	)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", TEXT_DIM)
	panel.add_child(label)


func _make_inventory_detail_panel(
	row: Dictionary,
	category_definition: Dictionary,
	row_count: int
) -> PanelContainer:
	var panel: PanelContainer = _make_magic_subpanel()
	panel.name = "ItemsDetailPanel"
	panel.custom_minimum_size = Vector2(390.0, 0.0)
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
		empty_title.text = str(category_definition.get("title", "Inventory"))
		empty_title.add_theme_font_size_override("font_size", 20)
		empty_title.add_theme_color_override("font_color", TEXT_MAIN)
		stack.add_child(empty_title)
		var empty_copy: Label = Label.new()
		empty_copy.text = str(category_definition.get("description", ""))
		empty_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_copy.add_theme_font_size_override("font_size", 12)
		empty_copy.add_theme_color_override("font_color", TEXT_SOFT)
		stack.add_child(empty_copy)
		return panel

	var icon: Label = Label.new()
	icon.text = str(row.get("icon", "◇"))
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 42)
	icon.add_theme_color_override("font_color", ITEM_CATEGORY_ACTIVE_BORDER)
	stack.add_child(icon)
	var title: Label = Label.new()
	title.text = str(row.get("name", "Item"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", TEXT_MAIN)
	stack.add_child(title)
	var count: Label = Label.new()
	count.text = (
		"OWNED ×"
		+ str(row.get("count", 0))
		+ "  •  CATEGORY "
		+ str(category_definition.get("short_title", "ITEM")).to_upper()
	)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.add_theme_font_size_override("font_size", 10)
	count.add_theme_color_override("font_color", ITEM_CATEGORY_ACTIVE_BORDER)
	stack.add_child(count)
	var description: Label = Label.new()
	description.text = str(row.get("description", "No description yet."))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 12)
	description.add_theme_color_override("font_color", TEXT_SOFT)
	stack.add_child(description)

	var metadata: Array[String] = []
	var effect: String = str(row.get("effect", ""))
	var element: String = str(row.get("element", ""))
	if effect != "":
		metadata.append("Effect: " + effect.replace("_", " ").capitalize())
	if element != "":
		metadata.append("Element: " + element.capitalize())
	var tags: Array[String] = _items_string_array(row.get("tags", []))
	if not tags.is_empty():
		metadata.append("Tags: " + ", ".join(tags.slice(0, mini(tags.size(), 5))))
	metadata.append("Category records: " + str(row_count))
	var metadata_label: Label = Label.new()
	metadata_label.text = "\n".join(metadata)
	metadata_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	metadata_label.add_theme_font_size_override("font_size", 10)
	metadata_label.add_theme_color_override("font_color", TEXT_DIM)
	stack.add_child(metadata_label)
	return panel


func _render_relics_category(parent: VBoxContainer) -> void:
	parent.add_child(_make_magic_heading("🔑  RELICS / KEY ITEMS"))
	var explanation: Label = Label.new()
	explanation.text = (
		"Unique progression objects now live inside Items. They are carried records, "
		+ "but unlike ordinary inventory they are not consumed, sold, or placed on the quick belt."
	)
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation.add_theme_font_size_override("font_size", 11)
	explanation.add_theme_color_override("font_color", TEXT_SOFT)
	parent.add_child(explanation)

	var columns: GridContainer = make_visual_grid(3)
	columns.name = "ItemsRelicWorkspace"
	columns.add_theme_constant_override("h_separation", 10)
	parent.add_child(columns)
	_add_relic_record_column(
		columns,
		"KEY ITEMS",
		"🔑",
		menu_data.get("key_items", []),
		"Story relics and dungeon proofs appear here."
	)
	_add_relic_record_column(
		columns,
		"BLESSINGS",
		"✦",
		get_unlock_rows_for_type("modifier"),
		"Persistent rewards that change Grace's rules appear here."
	)
	_add_relic_record_column(
		columns,
		"WORLD PERMISSIONS",
		"🚪",
		get_unlock_rows_for_type("permission"),
		"Doors, factions, regions, and systems recognize these records."
	)


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
		var name_label: Label = Label.new()
		name_label.text = str(
			row.get(
				"display_name",
				row.get("name", row.get("id", "Record").to_string().capitalize())
			)
		)
		name_label.add_theme_font_size_override("font_size", 11)
		name_label.add_theme_color_override("font_color", TEXT_MAIN)
		copy.add_child(name_label)
		var description: Label = Label.new()
		description.text = str(row.get("description", row.get("source", "Persistent record")))
		description.clip_text = true
		description.add_theme_font_size_override("font_size", 9)
		description.add_theme_color_override("font_color", TEXT_SOFT)
		copy.add_child(description)


func _toggle_item_category(category_id: String) -> void:
	if not ItemCategoryCatalogScript.has_category(category_id):
		return
	if (
		items_page == ITEMS_CATEGORY
		and selected_item_category == category_id
	):
		_reset_item_workspace()
		selected_action_index = ItemCategoryCatalogScript.CATEGORY_ORDER.find(
			category_id
		)
	else:
		items_page = ITEMS_CATEGORY
		selected_item_category = category_id
		selected_inventory_item_id = ""
		var rows: Array[Dictionary] = ItemCategoryCatalogScript.get_rows_for_category(
			menu_data.get("inventory_items", []),
			category_id
		)
		if not rows.is_empty():
			selected_inventory_item_id = str(rows[0].get("id", ""))
		selected_action_index = ItemCategoryCatalogScript.CATEGORY_ORDER.find(
			category_id
		)
	tab_action_memory["items"] = maxi(selected_action_index, 0)
	rebuild_menu()


func _reset_item_workspace() -> void:
	items_page = ITEMS_OVERVIEW
	selected_item_category = ""
	selected_inventory_item_id = ""


func _get_item_category_count(category_id: String) -> int:
	if category_id == "relics":
		return (
			_items_dictionary_array(menu_data.get("key_items", [])).size()
			+ get_unlock_rows_for_type("modifier").size()
			+ get_unlock_rows_for_type("permission").size()
		)
	return ItemCategoryCatalogScript.get_rows_for_category(
		menu_data.get("inventory_items", []),
		category_id
	).size()


func _get_total_inventory_count() -> int:
	var total: int = 0
	for row: Dictionary in _items_dictionary_array(
		menu_data.get("inventory_items", [])
	):
		total += int(row.get("count", 0))
	return total


func _get_total_inventory_types() -> int:
	return _items_dictionary_array(
		menu_data.get("inventory_items", [])
	).size()


func _find_inventory_row_by_id(
	rows: Array[Dictionary],
	item_id: String
) -> Dictionary:
	for row: Dictionary in rows:
		if str(row.get("id", "")) == item_id:
			return row
	return {}


func _get_items_page_title() -> String:
	if items_page == ITEMS_CATEGORY and selected_item_category != "":
		var definition: Dictionary = ItemCategoryCatalogScript.get_definition(
			selected_item_category
		)
		return "🧪 Items  ›  " + str(
			definition.get("title", selected_item_category.capitalize())
		)
	return "🧪 Items"


func _update_scroll_policy() -> void:
	if scroll_container == null:
		return
	if get_current_tab_id() in ["loadout", "magic", "items"]:
		scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll_container.scroll_vertical = 0
		scroll_container.scroll_horizontal = 0
	else:
		scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO


func get_items_debug_data() -> Dictionary:
	return {
		"page": items_page,
		"selected_category": selected_item_category,
		"category_count": ItemCategoryCatalogScript.CATEGORY_ORDER.size(),
		"top_level_tab_count": FIELD_KIT_TAB_DEFS.size(),
		"relic_top_tab_removed": get_tab_index("relics") == 0,
		"category_strip_present": find_child("ItemsCategoryStrip", true, false) != null,
		"workspace_present": find_child("ItemsWorkspace", true, false) != null,
		"scroll_disabled": (
			scroll_container != null
			and scroll_container.vertical_scroll_mode
			== ScrollContainer.SCROLL_MODE_DISABLED
		),
	}


func _items_dictionary_array(value: Variant) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if value is Array:
		for entry: Variant in value as Array:
			if entry is Dictionary:
				rows.append((entry as Dictionary).duplicate(true))
	return rows


func _items_string_array(value: Variant) -> Array[String]:
	var rows: Array[String] = []
	if value is Array:
		for entry: Variant in value as Array:
			rows.append(str(entry).replace("_", " ").capitalize())
	return rows
