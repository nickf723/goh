extends "res://scripts/ui/full_menu_shell_settings.gd"
class_name FullMenuShellLoadoutV1

const MenuEquipmentCatalog = preload("res://scripts/equipment/equipment_catalog.gd")
const MenuInfusionCatalog = preload("res://scripts/weapons/weapon_infusion_catalog.gd")
const WeaponMasteryCatalogScript = preload("res://scripts/weapons/weapon_mastery_catalog.gd")
const WeaponVariantCatalogScript = preload("res://scripts/weapons/weapon_variant_catalog.gd")
const GraceComponentPreviewScript = preload("res://scripts/ui/grace_component_loadout_preview.gd")

const MENU_TAB_DEFS: Array[Dictionary] = [
	{"id": "loadout", "title": "Grace", "icon": "◇"},
	{"id": "magic", "title": "Magic", "icon": "✦"},
	{"id": "items", "title": "Items", "icon": "🧪"},
	{"id": "relics", "title": "Relics", "icon": "🔑"},
	{"id": "journal", "title": "Journal", "icon": "📜"},
	{"id": "codex", "title": "Codex", "icon": "🧩"},
	{"id": "system", "title": "System", "icon": "⚙"},
]

# Kept as public compatibility state for the focused menu regression.
const LOADOUT_OVERVIEW: String = "overview"
const LOADOUT_WEAPON_CLASSES: String = "weapon_classes"
const LOADOUT_WEAPON_VARIANTS: String = "weapon_variants"
const LOADOUT_WARDROBE: String = "wardrobe"
const LOADOUT_WARDROBE_SLOT: String = "wardrobe_slot"
const LOADOUT_INFUSION: String = "infusion"
const LOADOUT_QUICK_ITEMS: String = "quick_items"
const LOADOUT_QUICK_ITEM_PICKER: String = "quick_item_picker"
const LOADOUT_SPECIAL: String = "special"

const CATEGORY_WEAPON: String = "weapon"
const CATEGORY_WARDROBE: String = "wardrobe"
const CATEGORY_INFUSION: String = "infusion"
const CATEGORY_QUICK_ITEMS: String = "quick_items"
const CATEGORY_SPECIAL: String = "special"

var loadout_page: String = LOADOUT_OVERVIEW
var selected_weapon_class: String = ""
var selected_wardrobe_slot: String = ""
var pending_quick_item_slot_index: int = -1
var accordion_return_action_index: int = 0


func show_menu(new_menu_data: Dictionary) -> void:
	menu_data = new_menu_data.duplicate(true)
	selected_tab_index = clampi(selected_tab_index, 0, MENU_TAB_DEFS.size() - 1)
	selected_action_index = int(tab_action_memory.get(get_current_tab_id(), selected_action_index))
	visible = true
	rebuild_menu()


func hide_menu() -> void:
	_reset_grace_accordion()
	super.hide_menu()


func get_current_tab_id() -> String:
	if selected_tab_index < 0 or selected_tab_index >= MENU_TAB_DEFS.size():
		return "loadout"
	return str(MENU_TAB_DEFS[selected_tab_index].get("id", "loadout"))


func get_tab_index(tab_id: String) -> int:
	for index: int in range(MENU_TAB_DEFS.size()):
		if str(MENU_TAB_DEFS[index].get("id", "")) == tab_id:
			return index
	return 0


func select_tab(index: int) -> void:
	if is_assignment_active():
		return
	remember_current_action()
	if get_current_tab_id() == "loadout":
		_reset_grace_accordion()
	selected_tab_index = posmod(index, MENU_TAB_DEFS.size())
	selected_action_index = int(tab_action_memory.get(get_current_tab_id(), 0))
	rebuild_menu()


func rebuild_tabs() -> void:
	clear_children(tab_box)
	for index: int in range(MENU_TAB_DEFS.size()):
		var tab_def: Dictionary = MENU_TAB_DEFS[index]
		var is_selected: bool = index == selected_tab_index
		var tab_button: Button = Button.new()
		tab_button.text = str(tab_def.get("icon", "")) + "\n" + str(tab_def.get("title", "Tab"))
		tab_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		tab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_button.custom_minimum_size = Vector2(96.0, 58.0)
		tab_button.add_theme_font_size_override("font_size", 13)
		tab_button.add_theme_color_override("font_color", TEXT_MAIN if is_selected else TEXT_SOFT)
		tab_button.add_theme_stylebox_override(
			"normal",
			make_panel_style(
				ACTIVE_SELECTION_BACKGROUND if is_selected else Color(0.045, 0.06, 0.083, 0.72),
				ACTIVE_SELECTION_BORDER if is_selected else CARD_BORDER,
				3 if is_selected else 1,
				9
			)
		)
		tab_button.add_theme_stylebox_override(
			"hover",
			make_panel_style(Color(0.13, 0.105, 0.08, 0.9), ACTIVE_SELECTION_BORDER, 2, 9)
		)
		tab_button.pressed.connect(_on_tab_pressed.bind(index))
		tab_box.add_child(tab_button)


func rebuild_content() -> void:
	selectable_actions.clear()
	selected_action_control = null
	action_grid_columns = 1
	action_layout_mode = "list"
	clear_children(content_box)

	var tab_def: Dictionary = MENU_TAB_DEFS[selected_tab_index]
	var tab_id: String = str(tab_def.get("id", "loadout"))
	content_title_label.text = str(tab_def.get("icon", "")) + " " + str(tab_def.get("title", "Grace"))
	match tab_id:
		"loadout":
			render_loadout()
		"magic":
			render_magic()
		"items":
			render_items()
		"relics":
			render_relics()
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
		selected_action_index = clampi(selected_action_index, 0, selectable_actions.size() - 1)


func handle_menu_input(event: InputEvent) -> bool:
	if not visible:
		return false
	if event is InputEventJoypadButton:
		var button_event: InputEventJoypadButton = event as InputEventJoypadButton
		if not button_event.pressed:
			return true
		if is_menu_cancel_event(button_event):
			if is_assignment_active():
				cancel_assignment()
				return true
			if get_current_tab_id() == "loadout" and loadout_page != LOADOUT_OVERVIEW:
				_back_grace_accordion()
				return true
			return false
		if button_event.button_index == get_menu_confirm_button(button_event.device):
			activate_selected_action()
			return true
		match button_event.button_index:
			JOY_BUTTON_LEFT_SHOULDER:
				select_tab(selected_tab_index - 1)
				return true
			JOY_BUTTON_RIGHT_SHOULDER:
				select_tab(selected_tab_index + 1)
				return true
			JOY_BUTTON_DPAD_UP:
				select_action_direction(0, -1)
				return true
			JOY_BUTTON_DPAD_DOWN:
				select_action_direction(0, 1)
				return true
			JOY_BUTTON_DPAD_LEFT:
				select_action_direction(-1, 0)
				return true
			JOY_BUTTON_DPAD_RIGHT:
				select_action_direction(1, 0)
				return true
			_:
				return true

	if (
		event.is_action_pressed("ui_cancel")
		and get_current_tab_id() == "loadout"
		and loadout_page != LOADOUT_OVERVIEW
		and not is_assignment_active()
	):
		_back_grace_accordion()
		return true
	return super.handle_menu_input(event)


func is_menu_cancel_event(event: InputEvent) -> bool:
	if not event is InputEventJoypadButton:
		return event.is_action_pressed("ui_cancel")
	var button_event: InputEventJoypadButton = event as InputEventJoypadButton
	return button_event.pressed and button_event.button_index == get_menu_cancel_button(button_event.device)


func get_menu_confirm_button(device: int) -> int:
	return get_menu_confirm_button_for_name(Input.get_joy_name(device))


func get_menu_cancel_button(device: int) -> int:
	return get_menu_cancel_button_for_name(Input.get_joy_name(device))


func get_menu_confirm_button_for_name(controller_name: String) -> int:
	return JOY_BUTTON_B if _is_nintendo_controller_name(controller_name) else JOY_BUTTON_A


func get_menu_cancel_button_for_name(controller_name: String) -> int:
	return JOY_BUTTON_A if _is_nintendo_controller_name(controller_name) else JOY_BUTTON_B


func _is_nintendo_controller_name(controller_name: String) -> bool:
	var normalized: String = controller_name.to_lower()
	return "nintendo" in normalized or "switch" in normalized or "pro controller" in normalized


func select_action_direction(horizontal: int, vertical: int) -> void:
	if action_layout_mode != "accordion_spatial":
		super.select_action_direction(horizontal, vertical)
		return
	if selectable_actions.is_empty() or (horizontal == 0 and vertical == 0):
		return
	selected_action_index = clampi(selected_action_index, 0, selectable_actions.size() - 1)
	var current: Dictionary = selectable_actions[selected_action_index] as Dictionary
	if not current.has("nav_row") or not current.has("nav_col"):
		super.select_action_direction(horizontal, vertical)
		return
	var current_row: int = int(current.get("nav_row", 0))
	var current_col: int = int(current.get("nav_col", 0))
	var best_index: int = -1
	var best_score: float = INF
	for index: int in range(selectable_actions.size()):
		if index == selected_action_index:
			continue
		var candidate: Dictionary = selectable_actions[index] as Dictionary
		if not candidate.has("nav_row") or not candidate.has("nav_col"):
			continue
		var row_delta: int = int(candidate.get("nav_row", 0)) - current_row
		var col_delta: int = int(candidate.get("nav_col", 0)) - current_col
		var score: float = INF
		if horizontal != 0 and col_delta * horizontal > 0:
			score = absf(float(col_delta)) * 100.0 + absf(float(row_delta))
		elif vertical != 0 and row_delta * vertical > 0:
			score = absf(float(row_delta)) * 100.0 + absf(float(col_delta))
		if score < best_score:
			best_score = score
			best_index = index
	if best_index >= 0:
		select_action(best_index)


func activate_action(action: Dictionary) -> void:
	match str(action.get("kind", "")):
		"toggle_grace_category":
			_toggle_grace_category(str(action.get("category", "")))
		"open_weapon_class":
			_open_weapon_class(str(action.get("weapon_class", "")))
		"equip_weapon_variant":
			_equip_equipment_item(str(action.get("item_id", "")))
		"inspect_weapon_variant":
			_inspect_weapon_variant(action)
		"open_wardrobe_slot":
			_open_wardrobe_slot(str(action.get("slot_id", "")))
		"equip_wardrobe_item":
			_equip_equipment_item(str(action.get("item_id", "")))
		"inspect_locked_equipment":
			_show_loadout_message(str(action.get("message", "This item has not been acquired.")))
		"open_quick_item_picker":
			_open_quick_item_picker(int(action.get("slot", -1)))
		"assign_quick_item":
			_assign_quick_item(str(action.get("item_id", "")))
		"select_divine_special":
			_select_divine_special(str(action.get("special_id", "")))
		"choose_spell_slot":
			_reset_grace_accordion()
			super.activate_action(action)
		_:
			super.activate_action(action)


func get_footer_text() -> String:
	if is_assignment_active():
		return super.get_footer_text()
	if get_current_tab_id() == "loadout":
		if loadout_page == LOADOUT_OVERVIEW:
			return "L/R: tabs  •  D-pad/Stick: move  •  A: expand or equip  •  B: close"
		return "L/R: tabs  •  D-pad/Stick: move  •  A: choose  •  B: collapse one level"
	return super.get_footer_text()


func render_loadout() -> void:
	content_title_label.text = "◇ Grace"
	action_layout_mode = "accordion_spatial"
	action_grid_columns = 1
	_render_category_strip()
	match loadout_page:
		LOADOUT_WEAPON_CLASSES:
			_render_weapon_classes()
		LOADOUT_WEAPON_VARIANTS:
			_render_weapon_variants()
		LOADOUT_WARDROBE:
			_render_wardrobe_slots()
		LOADOUT_WARDROBE_SLOT:
			_render_wardrobe_items()
		LOADOUT_INFUSION:
			_render_infusions()
		LOADOUT_QUICK_ITEMS:
			_render_quick_items()
		LOADOUT_QUICK_ITEM_PICKER:
			_render_quick_item_picker()
		LOADOUT_SPECIAL:
			_render_divine_specials()
		_:
			_render_grace_overview()


func _render_category_strip() -> void:
	add_section_header("EQUIPMENT CATEGORIES  •  SELECT AN OPEN CATEGORY TO COLLAPSE IT")
	var strip: GridContainer = make_visual_grid(5)
	content_box.add_child(strip)
	var weapon_id: String = GameState.get_equipped_item(MenuEquipmentCatalog.SLOT_WEAPON)
	var weapon_name: String = MenuEquipmentCatalog.get_display_name(weapon_id) if weapon_id != "" else "None"
	var wardrobe_count: int = 0
	for slot_id: String in MenuEquipmentCatalog.WARDROBE_SLOT_ORDER:
		if GameState.get_equipped_item(slot_id) != "":
			wardrobe_count += 1
	var infusion: Dictionary = MenuInfusionCatalog.get_definition(GameState.get_weapon_infusion())
	var quick_slots: Array = menu_data.get("quick_item_slots", [])
	var special: Dictionary = _get_divine_special_summary()
	_add_category_tile(strip, CATEGORY_WEAPON, "⚔", "Weapon", weapon_name.to_upper(), 0)
	_add_category_tile(strip, CATEGORY_WARDROBE, "♧", "Wardrobe", str(wardrobe_count) + "/" + str(MenuEquipmentCatalog.WARDROBE_SLOT_ORDER.size()) + " COMPONENTS", 2)
	_add_category_tile(strip, CATEGORY_INFUSION, str(infusion.get("icon", "◇")), "Infusion", str(infusion.get("name", "Uninfused")).to_upper(), 4)
	_add_category_tile(strip, CATEGORY_QUICK_ITEMS, "🧪", "Quick Items", str(_count_nonempty_rows(quick_slots)) + "/" + str(quick_slots.size()) + " IN CYCLE", 6)
	_add_category_tile(strip, CATEGORY_SPECIAL, "☀", "Divine Special", str(special.get("badge", "UNAVAILABLE")), 8)


func _add_category_tile(parent: Container, category: String, icon: String, title: String, badge: String, column: int) -> void:
	var open: bool = _category_is_open(category)
	add_visual_action_tile(
		parent,
		("▾ " if open else "▸ ") + icon,
		title,
		badge,
		_nav_action({"kind": "toggle_grace_category", "category": category}, 0, column),
		"Expand this category inside the Grace tab. Opening another category collapses the current one."
	)


func _render_grace_overview() -> void:
	add_summary_card([
		"HP " + stat_pair("health", "max_health"),
		"Mana " + stat_pair("mana", "max_mana"),
		"Stamina " + stat_pair("stamina", "max_stamina"),
		"Stance " + stat_pair("stance", "max_stance"),
	])
	var workspace: HBoxContainer = HBoxContainer.new()
	workspace.add_theme_constant_override("separation", 16)
	workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_box.add_child(workspace)

	var preview_panel: PanelContainer = PanelContainer.new()
	preview_panel.custom_minimum_size = Vector2(410.0, 365.0)
	preview_panel.add_theme_stylebox_override("panel", make_panel_style(Color(0.025, 0.035, 0.052, 0.92), CARD_BORDER, 1, 14))
	workspace.add_child(preview_panel)
	var preview_margin: MarginContainer = MarginContainer.new()
	preview_margin.add_theme_constant_override("margin_left", 12)
	preview_margin.add_theme_constant_override("margin_top", 10)
	preview_margin.add_theme_constant_override("margin_right", 12)
	preview_margin.add_theme_constant_override("margin_bottom", 10)
	preview_panel.add_child(preview_margin)
	var preview_stack: VBoxContainer = VBoxContainer.new()
	preview_stack.add_theme_constant_override("separation", 4)
	preview_margin.add_child(preview_stack)
	var preview: GraceComponentLoadoutPreview = GraceComponentPreviewScript.new()
	preview.configure(_get_equipped_items(), GameState.get_weapon_infusion())
	preview_stack.add_child(preview)
	var name_label: Label = Label.new()
	name_label.text = "GRACE"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", ACTIVE_SELECTION_BORDER)
	preview_stack.add_child(name_label)

	workspace.add_child(_make_equipment_snapshot_panel())
	add_section_header("FAVORITE SPELL RING  •  D-PAD LEFT / RIGHT IN GAMEPLAY")
	var spell_grid: GridContainer = make_visual_grid(10)
	spell_grid.add_theme_constant_override("h_separation", 6)
	content_box.add_child(spell_grid)
	var equipped_slots: Array = menu_data.get("equipped_spell_slots", [])
	for slot_value: Variant in equipped_slots:
		if slot_value is Dictionary:
			_add_spell_ribbon_tile(spell_grid, slot_value as Dictionary)


func _make_equipment_snapshot_panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", make_panel_style(Color(0.04, 0.052, 0.073, 0.9), CARD_BORDER, 1, 14))
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 9)
	margin.add_child(stack)
	var header: Label = Label.new()
	header.text = "CURRENT FIELD KIT"
	header.add_theme_font_size_override("font_size", 17)
	header.add_theme_color_override("font_color", TEXT_MAIN)
	stack.add_child(header)
	for slot_id: String in MenuEquipmentCatalog.SLOT_ORDER:
		var item_id: String = GameState.get_equipped_item(slot_id)
		var definition: Dictionary = MenuEquipmentCatalog.get_definition(item_id)
		var row: Label = Label.new()
		row.text = MenuEquipmentCatalog.get_slot_display_name(slot_id).to_upper() + "  •  " + str(definition.get("icon", "◇")) + " " + str(definition.get("name", "Empty"))
		row.add_theme_font_size_override("font_size", 13)
		row.add_theme_color_override("font_color", TEXT_SOFT)
		stack.add_child(row)
	var hint: Label = Label.new()
	hint.text = "Expand a category above. The other categories stay visible and collapse whatever was open."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", TEXT_DIM)
	stack.add_child(hint)
	return panel


func _render_weapon_classes() -> void:
	content_title_label.text = "◇ Grace  ›  Weapon Classes"
	add_summary_card(["16 weapon classes", "Select a class to reveal its weapon types", "Mastery is shared by class"])
	var grid: GridContainer = make_visual_grid(4)
	content_box.add_child(grid)
	var current_class: String = MenuEquipmentCatalog.get_weapon_class(GameState.get_equipped_item(MenuEquipmentCatalog.SLOT_WEAPON))
	var rows: Array[Dictionary] = WeaponVariantCatalogScript.get_class_rows()
	for index: int in range(rows.size()):
		var row: Dictionary = rows[index]
		var weapon_class: String = str(row.get("id", ""))
		var rank: int = GameState.get_weapon_mastery_rank(weapon_class)
		var badge: String = WeaponMasteryCatalogScript.get_rank_name(rank).to_upper() + "  •  " + str(row.get("variant_count", 0)) + " TYPES"
		if weapon_class == current_class:
			badge = "EQUIPPED CLASS  •  " + badge
		add_visual_action_tile(
			grid,
			str(row.get("icon", "◇")),
			str(row.get("name", weapon_class.capitalize())),
			badge,
			_nav_action({"kind": "open_weapon_class", "weapon_class": weapon_class}, 2 + index / 4, (index % 4) * 2),
			str(row.get("description", ""))
		)


func _render_weapon_variants() -> void:
	var class_data: Dictionary = WeaponVariantCatalogScript.get_class_definition(selected_weapon_class)
	content_title_label.text = "◇ Grace  ›  Weapon  ›  " + str(class_data.get("name", selected_weapon_class.capitalize()))
	var rank: int = GameState.get_weapon_mastery_rank(selected_weapon_class)
	add_summary_card([
		WeaponMasteryCatalogScript.get_rank_name(rank) + " mastery",
		str(WeaponVariantCatalogScript.get_variants(selected_weapon_class).size()) + " authored types",
		"Owned weapons can equip now; blueprints define future drops",
	])
	var grid: GridContainer = make_visual_grid(4)
	content_box.add_child(grid)
	var variants: Array[Dictionary] = WeaponVariantCatalogScript.get_variants(selected_weapon_class)
	for index: int in range(variants.size()):
		var variant: Dictionary = variants[index]
		var item_id: String = str(variant.get("item_id", ""))
		var action: Dictionary = {
			"kind": "inspect_weapon_variant",
			"weapon_class": selected_weapon_class,
			"variant_id": str(variant.get("id", "")),
			"name": str(variant.get("name", "Weapon Type")),
		}
		var badge: String = "BLUEPRINT"
		if item_id != "" and MenuEquipmentCatalog.has_item(item_id):
			if GameState.owns_equipment(item_id):
				action = {"kind": "equip_weapon_variant", "item_id": item_id}
				badge = "EQUIPPED" if GameState.is_equipment_equipped(item_id) else "OWNED  •  A TO EQUIP"
			else:
				badge = "KNOWN  •  NOT OWNED"
		add_visual_action_tile(
			grid,
			str(class_data.get("icon", "◇")),
			str(variant.get("name", "Weapon Type")),
			badge,
			_nav_action(action, 2 + index / 4, (index % 4) * 2),
			str(variant.get("description", ""))
		)
	add_text_card(
		"Variant Grammar",
		"A weapon class owns the shared mastery and combo language. Individual types reshape reach, speed, hit geometry, scaling, and authored techniques without becoming entirely separate progression tracks.",
		str(class_data.get("icon", "◇")),
		"Class → Type → Individual weapon"
	)


func _render_wardrobe_slots() -> void:
	content_title_label.text = "◇ Grace  ›  Wardrobe Components"
	add_summary_card(["Headwear", "Torso", "Handwear", "Footwear", "Charm", "Relic"])
	var grid: GridContainer = make_visual_grid(3)
	content_box.add_child(grid)
	for index: int in range(MenuEquipmentCatalog.WARDROBE_SLOT_ORDER.size()):
		var slot_id: String = MenuEquipmentCatalog.WARDROBE_SLOT_ORDER[index]
		var item_id: String = GameState.get_equipped_item(slot_id)
		var definition: Dictionary = MenuEquipmentCatalog.get_definition(item_id)
		add_visual_action_tile(
			grid,
			str(definition.get("icon", "◇")),
			MenuEquipmentCatalog.get_slot_display_name(slot_id),
			str(definition.get("name", "Empty")).to_upper(),
			_nav_action({"kind": "open_wardrobe_slot", "slot_id": slot_id}, 2 + index / 3, (index % 3) * 3),
			"Open this wardrobe component without leaving the Grace tab."
		)


func _render_wardrobe_items() -> void:
	content_title_label.text = "◇ Grace  ›  Wardrobe  ›  " + MenuEquipmentCatalog.get_slot_display_name(selected_wardrobe_slot)
	var grid: GridContainer = make_visual_grid(3)
	content_box.add_child(grid)
	var rows: Array[Dictionary] = MenuEquipmentCatalog.get_rows_for_slot(selected_wardrobe_slot)
	for index: int in range(rows.size()):
		var row: Dictionary = rows[index]
		var item_id: String = str(row.get("id", ""))
		var owned: bool = GameState.owns_equipment(item_id)
		var badge: String = "EQUIPPED" if GameState.is_equipment_equipped(item_id) else ("OWNED  •  A TO EQUIP" if owned else "NOT OWNED")
		var action: Dictionary = {"kind": "equip_wardrobe_item", "item_id": item_id} if owned else {"kind": "inspect_locked_equipment", "message": str(row.get("name", "Item")) + " has not been acquired yet."}
		var details: String = str(row.get("description", ""))
		var modifiers: Dictionary = row.get("modifiers", {}) as Dictionary
		if not modifiers.is_empty():
			details += "\n" + MenuEquipmentCatalog.format_modifiers(modifiers)
		add_visual_action_tile(
			grid,
			str(row.get("icon", "◇")),
			str(row.get("name", item_id.capitalize())),
			badge,
			_nav_action(action, 2 + index / 3, (index % 3) * 3),
			details
		)


func _render_infusions() -> void:
	content_title_label.text = "◇ Grace  ›  Weapon Infusion"
	var active: String = GameState.get_weapon_infusion()
	var grid: GridContainer = make_visual_grid(4)
	content_box.add_child(grid)
	var rows: Array[Dictionary] = MenuInfusionCatalog.get_rows()
	for index: int in range(rows.size()):
		var row: Dictionary = rows[index]
		var infusion_id: String = str(row.get("id", ""))
		var equipped: bool = infusion_id == active
		add_visual_action_tile(
			grid,
			str(row.get("icon", "◇")),
			str(row.get("name", infusion_id.capitalize())),
			"EQUIPPED  •  SELECT TO REMOVE" if equipped else "SELECT TO INFUSE",
			_nav_action({"kind": "set_weapon_infusion", "infusion_id": infusion_id}, 2, index * 2),
			str(row.get("description", ""))
		)


func _render_quick_items() -> void:
	content_title_label.text = "◇ Grace  ›  Quick-Item Cycle"
	add_summary_card(["D-pad Up tap cycles", "D-pad Up hold uses", "Left and Right remain favorite spells"])
	var slots: Array = menu_data.get("quick_item_slots", [])
	var grid: GridContainer = make_visual_grid(4)
	content_box.add_child(grid)
	for index: int in range(slots.size()):
		if not slots[index] is Dictionary:
			continue
		var slot: Dictionary = slots[index] as Dictionary
		var empty: bool = bool(slot.get("is_empty", true))
		var badge: String = "CYCLE SLOT " + str(index + 1)
		if not empty:
			badge += "  •  ×" + str(slot.get("count", 0))
		add_visual_action_tile(
			grid,
			"◇" if empty else str(slot.get("icon", "◇")),
			"Empty" if empty else str(slot.get("name", "Item")),
			badge,
			_nav_action({"kind": "open_quick_item_picker", "slot": int(slot.get("slot", index))}, 2, index * 2),
			"Choose which item occupies this position in the Up-button cycle."
		)


func _render_quick_item_picker() -> void:
	content_title_label.text = "◇ Grace  ›  Quick Items  ›  Slot " + str(pending_quick_item_slot_index + 1)
	var inventory: Array = menu_data.get("inventory_items", [])
	var grid: GridContainer = make_visual_grid(3)
	content_box.add_child(grid)
	var visual_index: int = 0
	for row_value: Variant in inventory:
		if not row_value is Dictionary:
			continue
		var row: Dictionary = row_value as Dictionary
		if int(row.get("count", 0)) <= 0:
			continue
		add_visual_action_tile(
			grid,
			str(row.get("icon", "◇")),
			str(row.get("name", "Item")),
			"CARRIED ×" + str(row.get("count", 0)),
			_nav_action({"kind": "assign_quick_item", "item_id": str(row.get("id", ""))}, 2 + visual_index / 3, (visual_index % 3) * 3),
			str(row.get("description", ""))
		)
		visual_index += 1
	add_visual_action_tile(
		grid,
		"×",
		"Clear Slot",
		"EMPTY",
		_nav_action({"kind": "assign_quick_item", "item_id": ""}, 2 + visual_index / 3, (visual_index % 3) * 3),
		"Remove this position from the quick-item cycle."
	)


func _render_divine_specials() -> void:
	content_title_label.text = "◇ Grace  ›  Divine Special"
	var controller: Node = _get_divine_special_controller()
	if controller == null:
		add_visual_info_card("☀", "Divine Specials Unavailable", "The current player does not contain a Divine Special controller.", "Grace")
		return
	var force_debug: bool = OS.is_debug_build()
	var selected: DivineSpecialDefinition = controller.call("get_selected_special", force_debug) as DivineSpecialDefinition
	var available: Variant = controller.call("get_available_specials", force_debug)
	if not available is Array:
		return
	var grid: GridContainer = make_visual_grid(3)
	content_box.add_child(grid)
	var index: int = 0
	for value: Variant in available as Array:
		if not value is DivineSpecialDefinition:
			continue
		var definition: DivineSpecialDefinition = value as DivineSpecialDefinition
		var badge: String = "SELECTED" if selected != null and selected.special_id == definition.special_id else "SELECT"
		badge += "  •  " + str(roundi(definition.required_charge)) + " CHARGE"
		add_visual_action_tile(
			grid,
			"☀",
			definition.display_name,
			badge,
			_nav_action({"kind": "select_divine_special", "special_id": definition.special_id}, 2 + index / 3, (index % 3) * 3),
			definition.description
		)
		index += 1


func _add_spell_ribbon_tile(parent: Container, spell: Dictionary) -> void:
	var action_index: int = selectable_actions.size()
	var slot_index: int = int(spell.get("slot", action_index))
	var action: Dictionary = _nav_action({"kind": "choose_spell_slot", "slot": slot_index}, 8, slot_index)
	selectable_actions.append(action)
	var selected: bool = action_index == selected_action_index
	var empty: bool = bool(spell.get("is_empty", false))
	var button: Button = Button.new()
	button.text = ("✦" if empty else get_spell_icon(str(spell.get("element", "neutral")))) + "\n" + ("Empty" if empty else str(spell.get("name", "Spell"))) + "\n" + str(slot_index + 1)
	button.tooltip_text = str(spell.get("description", "Select to assign a learned spell."))
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(92.0, 82.0)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", TEXT_MAIN if selected else TEXT_SOFT)
	button.add_theme_stylebox_override("normal", make_panel_style(ACTIVE_SELECTION_BACKGROUND if selected else CARD_BACKGROUND, ACTIVE_SELECTION_BORDER if selected else CARD_BORDER, 3 if selected else 1, 10))
	button.add_theme_stylebox_override("focus", make_panel_style(ACTIVE_SELECTION_BACKGROUND, ACTIVE_SELECTION_BORDER, 3, 10))
	button.add_theme_stylebox_override("hover", make_panel_style(Color(0.15, 0.105, 0.08, 0.92), ACTIVE_SELECTION_BORDER, 2, 10))
	button.pressed.connect(_on_action_row_pressed.bind(action_index))
	button.mouse_entered.connect(_on_action_row_hovered.bind(action_index))
	parent.add_child(button)
	if selected:
		schedule_selected_control(button)


func _toggle_grace_category(category: String) -> void:
	accordion_return_action_index = selected_action_index
	if _category_is_open(category):
		_reset_grace_accordion()
	else:
		selected_weapon_class = ""
		selected_wardrobe_slot = ""
		pending_quick_item_slot_index = -1
		match category:
			CATEGORY_WEAPON:
				loadout_page = LOADOUT_WEAPON_CLASSES
			CATEGORY_WARDROBE:
				loadout_page = LOADOUT_WARDROBE
			CATEGORY_INFUSION:
				loadout_page = LOADOUT_INFUSION
			CATEGORY_QUICK_ITEMS:
				loadout_page = LOADOUT_QUICK_ITEMS
			CATEGORY_SPECIAL:
				loadout_page = LOADOUT_SPECIAL
			_:
				loadout_page = LOADOUT_OVERVIEW
	selected_action_index = accordion_return_action_index
	tab_action_memory["loadout"] = selected_action_index
	rebuild_menu()


func _category_is_open(category: String) -> bool:
	match category:
		CATEGORY_WEAPON:
			return loadout_page in [LOADOUT_WEAPON_CLASSES, LOADOUT_WEAPON_VARIANTS]
		CATEGORY_WARDROBE:
			return loadout_page in [LOADOUT_WARDROBE, LOADOUT_WARDROBE_SLOT]
		CATEGORY_INFUSION:
			return loadout_page == LOADOUT_INFUSION
		CATEGORY_QUICK_ITEMS:
			return loadout_page in [LOADOUT_QUICK_ITEMS, LOADOUT_QUICK_ITEM_PICKER]
		CATEGORY_SPECIAL:
			return loadout_page == LOADOUT_SPECIAL
	return false


func _open_weapon_class(weapon_class: String) -> void:
	if not WeaponMasteryCatalogScript.is_weapon_class(weapon_class):
		return
	selected_weapon_class = weapon_class
	loadout_page = LOADOUT_WEAPON_VARIANTS
	selected_action_index = 5
	rebuild_menu()


func _open_wardrobe_slot(slot_id: String) -> void:
	if not MenuEquipmentCatalog.WARDROBE_SLOT_ORDER.has(slot_id):
		return
	selected_wardrobe_slot = slot_id
	loadout_page = LOADOUT_WARDROBE_SLOT
	selected_action_index = 5
	rebuild_menu()


func _open_quick_item_picker(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= 4:
		return
	pending_quick_item_slot_index = slot_index
	loadout_page = LOADOUT_QUICK_ITEM_PICKER
	selected_action_index = 5
	rebuild_menu()


func _assign_quick_item(item_id: String) -> void:
	var controller: Node = find_first_node_named(get_tree().current_scene, "PlayerQuickItemController")
	if controller == null or not controller.has_method("assign_slot_by_item_id"):
		return
	if not bool(controller.call("assign_slot_by_item_id", pending_quick_item_slot_index, item_id)):
		return
	refresh_menu_data()
	loadout_page = LOADOUT_QUICK_ITEMS
	pending_quick_item_slot_index = -1
	selected_action_index = 5
	rebuild_menu()


func _equip_equipment_item(item_id: String) -> void:
	if item_id == "" or not GameState.equip_item(item_id):
		return
	_show_loadout_message("Equipped " + MenuEquipmentCatalog.get_display_name(item_id) + ".")
	refresh_menu_data()
	rebuild_menu()


func _inspect_weapon_variant(action: Dictionary) -> void:
	var name: String = str(action.get("name", "Weapon type"))
	_show_loadout_message(name + " is catalogued as a future weapon blueprint.")


func _select_divine_special(special_id: String) -> void:
	var controller: Node = _get_divine_special_controller()
	if controller == null or special_id == "":
		return
	if controller.has_method("select_special_by_id"):
		controller.call("select_special_by_id", special_id, OS.is_debug_build())
	rebuild_menu()


func _get_divine_special_controller() -> Node:
	var controller: Node = get_tree().get_first_node_in_group("player_divine_special_controller")
	if controller == null:
		controller = get_tree().get_first_node_in_group("divine_special_controller")
	return controller


func _get_divine_special_summary() -> Dictionary:
	var controller: Node = _get_divine_special_controller()
	if controller == null:
		return {"badge": "UNAVAILABLE", "description": "No Divine Special controller."}
	var selected: DivineSpecialDefinition = controller.call("get_selected_special", OS.is_debug_build()) as DivineSpecialDefinition
	var charge: float = float(controller.get("divine_charge"))
	var maximum: float = maxf(float(controller.get("maximum_charge")), 1.0)
	return {
		"badge": (selected.display_name.to_upper() if selected != null else "NONE") + "  •  " + str(roundi(charge / maximum * 100.0)) + "%",
		"description": selected.description if selected != null else "No Divine Special selected.",
	}


func _back_grace_accordion() -> void:
	match loadout_page:
		LOADOUT_WEAPON_VARIANTS:
			loadout_page = LOADOUT_WEAPON_CLASSES
			selected_weapon_class = ""
		LOADOUT_WARDROBE_SLOT:
			loadout_page = LOADOUT_WARDROBE
			selected_wardrobe_slot = ""
		LOADOUT_QUICK_ITEM_PICKER:
			loadout_page = LOADOUT_QUICK_ITEMS
			pending_quick_item_slot_index = -1
		_:
			loadout_page = LOADOUT_OVERVIEW
	selected_action_index = clampi(accordion_return_action_index, 0, 4)
	tab_action_memory["loadout"] = selected_action_index
	rebuild_menu()


func _reset_grace_accordion() -> void:
	loadout_page = LOADOUT_OVERVIEW
	selected_weapon_class = ""
	selected_wardrobe_slot = ""
	pending_quick_item_slot_index = -1


func _nav_action(action: Dictionary, row: int, column: int) -> Dictionary:
	var result: Dictionary = action.duplicate(true)
	result["nav_row"] = row
	result["nav_col"] = column
	return result


func _get_equipped_items() -> Dictionary:
	var result: Dictionary = {}
	for slot_id: String in MenuEquipmentCatalog.SLOT_ORDER:
		result[slot_id] = GameState.get_equipped_item(slot_id)
	return result


func _count_nonempty_rows(rows: Array) -> int:
	var count: int = 0
	for value: Variant in rows:
		if value is Dictionary and not bool((value as Dictionary).get("is_empty", false)):
			count += 1
	return count


func _show_loadout_message(text: String) -> void:
	if GameState.has_method("show_system_message"):
		GameState.call("show_system_message", text)
