extends "res://scripts/ui/full_menu_shell_settings.gd"
class_name FullMenuShellLoadoutV1

const MenuEquipmentCatalog = preload("res://scripts/equipment/equipment_catalog.gd")
const MenuInfusionCatalog = preload("res://scripts/weapons/weapon_infusion_catalog.gd")
const GraceLoadoutPreviewScript = preload("res://scripts/ui/grace_loadout_preview.gd")

const MENU_TAB_DEFS: Array[Dictionary] = [
	{"id": "loadout", "title": "Grace", "icon": "◇"},
	{"id": "magic", "title": "Magic", "icon": "✦"},
	{"id": "items", "title": "Items", "icon": "🧪"},
	{"id": "relics", "title": "Relics", "icon": "🔑"},
	{"id": "journal", "title": "Journal", "icon": "📜"},
	{"id": "codex", "title": "Codex", "icon": "🧩"},
	{"id": "system", "title": "System", "icon": "⚙"},
]

const LOADOUT_OVERVIEW: String = "overview"
const LOADOUT_INFUSION: String = "infusion"
const LOADOUT_QUICK_ITEMS: String = "quick_items"
const LOADOUT_QUICK_ITEM_PICKER: String = "quick_item_picker"
const LOADOUT_SPECIAL: String = "special"

var loadout_page: String = LOADOUT_OVERVIEW
var loadout_return_action_index: int = 0
var quick_item_return_action_index: int = 0
var pending_quick_item_slot_index: int = -1


func show_menu(new_menu_data: Dictionary) -> void:
	menu_data = new_menu_data.duplicate(true)
	selected_tab_index = clamp(selected_tab_index, 0, MENU_TAB_DEFS.size() - 1)
	selected_action_index = int(tab_action_memory.get(get_current_tab_id(), selected_action_index))
	visible = true
	rebuild_menu()


func hide_menu() -> void:
	loadout_page = LOADOUT_OVERVIEW
	pending_quick_item_slot_index = -1
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
	if get_current_tab_id() == "loadout" and loadout_page != LOADOUT_OVERVIEW:
		loadout_page = LOADOUT_OVERVIEW
		pending_quick_item_slot_index = -1
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
		selected_action_index = clamp(selected_action_index, 0, selectable_actions.size() - 1)


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
				_return_from_loadout_page()
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
		_return_from_loadout_page()
		return true
	return super.handle_menu_input(event)


func is_menu_cancel_event(event: InputEvent) -> bool:
	if not event is InputEventJoypadButton:
		return event.is_action_pressed("ui_cancel")
	var button_event: InputEventJoypadButton = event as InputEventJoypadButton
	return (
		button_event.pressed
		and button_event.button_index == get_menu_cancel_button(button_event.device)
	)


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
	if action_layout_mode != "loadout_spatial":
		super.select_action_direction(horizontal, vertical)
		return
	if selectable_actions.is_empty() or (horizontal == 0 and vertical == 0):
		return
	selected_action_index = clamp(selected_action_index, 0, selectable_actions.size() - 1)
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
			score = absf(float(row_delta)) * 1000.0 + absf(float(col_delta))
		elif vertical != 0 and row_delta * vertical > 0:
			score = absf(float(row_delta)) * 1000.0 + absf(float(col_delta))
		if score < best_score:
			best_score = score
			best_index = index
	if best_index >= 0:
		select_action(best_index)


func activate_action(action: Dictionary) -> void:
	match str(action.get("kind", "")):
		"open_loadout_page":
			_open_loadout_page(str(action.get("page", LOADOUT_OVERVIEW)))
		"open_quick_item_picker":
			_open_quick_item_picker(int(action.get("slot", -1)))
		"assign_quick_item":
			_assign_quick_item(str(action.get("item_id", "")))
		"select_divine_special":
			_select_divine_special(str(action.get("special_id", "")))
		_:
			super.activate_action(action)


func get_footer_text() -> String:
	if is_assignment_active():
		return super.get_footer_text()
	if get_current_tab_id() == "loadout":
		if loadout_page == LOADOUT_OVERVIEW:
			return "LB/RB: tabs  •  D-pad/Stick: move  •  A: open or equip  •  B: close"
		if loadout_page == LOADOUT_QUICK_ITEM_PICKER:
			return "D-pad/Stick: item  •  A: assign  •  B: quick-item cycle"
		return "D-pad/Stick: move  •  A: select  •  B: Grace"
	return super.get_footer_text()


func render_loadout() -> void:
	if is_assigning_equipment():
		content_title_label.text = "◇ Grace  ›  Equipment"
		render_equipment_picker()
		return
	match loadout_page:
		LOADOUT_INFUSION:
			_render_infusion_page()
		LOADOUT_QUICK_ITEMS:
			_render_quick_items_page()
		LOADOUT_QUICK_ITEM_PICKER:
			_render_quick_item_picker()
		LOADOUT_SPECIAL:
			_render_divine_special_page()
		_:
			_render_grace_loadout()


func _render_grace_loadout() -> void:
	content_title_label.text = "◇ Grace"
	action_layout_mode = "loadout_spatial"
	action_grid_columns = 1

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
	preview_panel.custom_minimum_size = Vector2(390.0, 365.0)
	preview_panel.add_theme_stylebox_override(
		"panel",
		make_panel_style(Color(0.025, 0.035, 0.052, 0.92), CARD_BORDER, 1, 14)
	)
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
	var preview: GraceLoadoutPreview = GraceLoadoutPreviewScript.new()
	preview.configure(_get_equipped_items(), GameState.get_weapon_infusion())
	preview_stack.add_child(preview)
	var preview_name: Label = Label.new()
	preview_name.text = "GRACE"
	preview_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_name.add_theme_font_size_override("font_size", 20)
	preview_name.add_theme_color_override("font_color", ACTIVE_SELECTION_BORDER)
	preview_stack.add_child(preview_name)
	var preview_caption: Label = Label.new()
	preview_caption.text = _get_equipment_summary()
	preview_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_caption.add_theme_font_size_override("font_size", 11)
	preview_caption.add_theme_color_override("font_color", TEXT_SOFT)
	preview_stack.add_child(preview_caption)

	var configuration_stack: VBoxContainer = VBoxContainer.new()
	configuration_stack.add_theme_constant_override("separation", 10)
	configuration_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace.add_child(configuration_stack)
	configuration_stack.add_child(_make_local_header("EQUIPMENT"))
	var equipment_grid: GridContainer = make_visual_grid(2)
	configuration_stack.add_child(equipment_grid)
	var equipment_nav: Array[Vector2i] = [
		Vector2i(5, 0), Vector2i(8, 0), Vector2i(5, 1), Vector2i(8, 1),
	]
	var equipment_index: int = 0
	for slot_id: String in MenuEquipmentCatalog.SLOT_ORDER:
		var equipped_item_id: String = GameState.get_equipped_item(slot_id)
		var definition: Dictionary = MenuEquipmentCatalog.get_definition(equipped_item_id)
		var title: String = str(definition.get("name", "Empty"))
		var badge: String = slot_id.to_upper()
		var modifiers: Dictionary = definition.get("modifiers", {}) as Dictionary
		if not modifiers.is_empty():
			badge += "  •  " + MenuEquipmentCatalog.format_modifiers(modifiers)
		var nav: Vector2i = equipment_nav[equipment_index]
		add_visual_action_tile(
			equipment_grid,
			str(definition.get("icon", "◇")),
			title,
			badge,
			_nav_action({"kind": "choose_equipment_slot", "slot_id": slot_id}, nav.y, nav.x),
			str(definition.get("description", "Choose owned gear for this slot."))
		)
		equipment_index += 1

	configuration_stack.add_child(_make_local_header("FIELD CONFIGURATION"))
	var utility_grid: GridContainer = make_visual_grid(3)
	configuration_stack.add_child(utility_grid)
	var infusion: Dictionary = MenuInfusionCatalog.get_definition(GameState.get_weapon_infusion())
	add_visual_action_tile(
		utility_grid,
		str(infusion.get("icon", "◇")),
		"Weapon Infusion",
		str(infusion.get("name", "Uninfused")).to_upper(),
		_nav_action({"kind": "open_loadout_page", "page": LOADOUT_INFUSION}, 2, 4),
		str(infusion.get("description", "Choose an elemental edge."))
	)
	var quick_slots: Array = menu_data.get("quick_item_slots", [])
	add_visual_action_tile(
		utility_grid,
		"🧪",
		"Quick Items",
		str(_count_nonempty_rows(quick_slots)) + "/" + str(quick_slots.size()) + " IN CYCLE",
		_nav_action({"kind": "open_loadout_page", "page": LOADOUT_QUICK_ITEMS}, 2, 6),
		"D-pad Up taps cycle these items; holding D-pad Up uses the selected item."
	)
	var special_summary: Dictionary = _get_divine_special_summary()
	add_visual_action_tile(
		utility_grid,
		"☀",
		"Divine Special",
		str(special_summary.get("badge", "UNAVAILABLE")),
		_nav_action({"kind": "open_loadout_page", "page": LOADOUT_SPECIAL}, 2, 8),
		str(special_summary.get("description", "Choose the prepared Divine Special."))
	)

	add_section_header("FAVORITE SPELL RING  •  D-PAD LEFT / RIGHT IN GAMEPLAY")
	var spell_grid: GridContainer = make_visual_grid(10)
	content_box.add_child(spell_grid)
	var equipped_slots: Array = menu_data.get("equipped_spell_slots", [])
	for slot_variant: Variant in equipped_slots:
		if not slot_variant is Dictionary:
			continue
		var spell: Dictionary = slot_variant as Dictionary
		_add_compact_spell_tile(spell_grid, spell)


func _render_infusion_page() -> void:
	content_title_label.text = "◇ Grace  ›  Weapon Infusion"
	action_grid_columns = 4
	action_layout_mode = "grid"
	var active_infusion: String = GameState.get_weapon_infusion()
	var active_definition: Dictionary = MenuInfusionCatalog.get_definition(active_infusion)
	add_summary_card([
		"Active " + str(active_definition.get("name", "Uninfused")),
		"Element " + str(active_definition.get("element", "neutral")).capitalize(),
		"Select the active edge again to remove it",
	])
	var infusion_grid: GridContainer = make_visual_grid(4)
	content_box.add_child(infusion_grid)
	for infusion: Dictionary in MenuInfusionCatalog.get_rows():
		var infusion_id: String = str(infusion.get("id", ""))
		var is_active: bool = infusion_id == active_infusion
		add_visual_action_tile(
			infusion_grid,
			str(infusion.get("icon", "◇")),
			str(infusion.get("name", infusion_id.capitalize())),
			"EQUIPPED  •  SELECT TO REMOVE" if is_active else "SELECT TO INFUSE",
			{"kind": "set_weapon_infusion", "infusion_id": infusion_id},
			str(infusion.get("description", ""))
		)


func _render_quick_items_page() -> void:
	content_title_label.text = "◇ Grace  ›  Quick-Item Cycle"
	action_grid_columns = 4
	action_layout_mode = "grid"
	var item_slots: Array = menu_data.get("quick_item_slots", [])
	add_summary_card([
		"Tap D-pad Up to cycle",
		"Hold D-pad Up to use",
		"Left and Right belong to favorite spells",
	])
	var item_grid: GridContainer = make_visual_grid(4)
	content_box.add_child(item_grid)
	for slot_variant: Variant in item_slots:
		if not slot_variant is Dictionary:
			continue
		var slot: Dictionary = slot_variant as Dictionary
		var slot_index: int = int(slot.get("slot", 0))
		var is_empty: bool = bool(slot.get("is_empty", true))
		var name: String = "Empty" if is_empty else str(slot.get("name", "Item"))
		var icon: String = "◇" if is_empty else str(slot.get("icon", "◇"))
		var badge: String = "CYCLE SLOT " + str(slot_index + 1)
		if not is_empty:
			badge += "  •  ×" + str(slot.get("count", 0))
		add_visual_action_tile(
			item_grid,
			icon,
			name,
			badge,
			{"kind": "open_quick_item_picker", "slot": slot_index},
			"Choose the item occupying this position in the D-pad Up cycle."
		)


func _render_quick_item_picker() -> void:
	content_title_label.text = "◇ Grace  ›  Quick-Item Cycle  ›  Slot " + str(pending_quick_item_slot_index + 1)
	action_grid_columns = 3
	action_layout_mode = "grid"
	add_assignment_banner(
		"Choose Quick Item",
		"This changes cycle order only. No stock is consumed."
	)
	var inventory_rows: Array = menu_data.get("inventory_items", [])
	var item_grid: GridContainer = make_visual_grid(3)
	content_box.add_child(item_grid)
	var available_count: int = 0
	for row_value: Variant in inventory_rows:
		if not row_value is Dictionary:
			continue
		var row: Dictionary = row_value as Dictionary
		if int(row.get("count", 0)) <= 0:
			continue
		available_count += 1
		add_visual_action_tile(
			item_grid,
			str(row.get("icon", "◇")),
			str(row.get("name", "Item")),
			"CARRIED ×" + str(row.get("count", 0)),
			{"kind": "assign_quick_item", "item_id": str(row.get("id", ""))},
			str(row.get("description", ""))
		)
	if available_count == 0:
		add_visual_info_card("◇", "No Quick Items", "Collect a usable item before assigning this cycle slot.", "Empty")


func _render_divine_special_page() -> void:
	content_title_label.text = "◇ Grace  ›  Divine Special"
	action_grid_columns = 3
	action_layout_mode = "grid"
	var controller: Node = _get_divine_special_controller()
	if controller == null:
		add_visual_info_card("☀", "Divine Specials Unavailable", "The current player does not contain a Divine Special controller.", "Grace")
		return
	var force_debug: bool = OS.is_debug_build()
	var selected: DivineSpecialDefinition = controller.call("get_selected_special", force_debug) as DivineSpecialDefinition
	var charge: float = float(controller.get("divine_charge"))
	var maximum: float = maxf(float(controller.get("maximum_charge")), 1.0)
	add_summary_card([
		"Selected " + (selected.display_name if selected != null else "None"),
		"Divine Charge " + str(roundi(charge)) + "/" + str(roundi(maximum)),
		"D-pad Down tap activates in gameplay",
		"Hold D-pad Down opens the selector",
	])
	var special_grid: GridContainer = make_visual_grid(3)
	content_box.add_child(special_grid)
	var available_value: Variant = controller.call("get_available_specials", force_debug)
	if not available_value is Array:
		return
	for definition_value: Variant in available_value as Array:
		if not definition_value is DivineSpecialDefinition:
			continue
		var definition: DivineSpecialDefinition = definition_value as DivineSpecialDefinition
		var is_selected: bool = selected != null and selected.special_id == definition.special_id
		var badge: String = ("SELECTED" if is_selected else "SELECT")
		badge += "  •  " + str(roundi(definition.required_charge)) + " CHARGE"
		add_visual_action_tile(
			special_grid,
			"☀",
			definition.display_name,
			badge,
			{"kind": "select_divine_special", "special_id": definition.special_id},
			definition.description
		)


func _open_loadout_page(page: String) -> void:
	if page not in [LOADOUT_INFUSION, LOADOUT_QUICK_ITEMS, LOADOUT_SPECIAL]:
		return
	loadout_return_action_index = selected_action_index
	loadout_page = page
	selected_action_index = 0
	tab_action_memory["loadout"] = 0
	rebuild_menu()


func _open_quick_item_picker(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= 4:
		return
	quick_item_return_action_index = selected_action_index
	pending_quick_item_slot_index = slot_index
	loadout_page = LOADOUT_QUICK_ITEM_PICKER
	selected_action_index = 0
	rebuild_menu()


func _return_from_loadout_page() -> void:
	if loadout_page == LOADOUT_QUICK_ITEM_PICKER:
		loadout_page = LOADOUT_QUICK_ITEMS
		pending_quick_item_slot_index = -1
		selected_action_index = max(quick_item_return_action_index, 0)
	else:
		loadout_page = LOADOUT_OVERVIEW
		selected_action_index = max(loadout_return_action_index, 0)
	tab_action_memory["loadout"] = selected_action_index
	rebuild_menu()


func _assign_quick_item(item_id: String) -> void:
	if pending_quick_item_slot_index < 0 or item_id == "":
		return
	var controller: Node = find_first_node_named(get_tree().current_scene, "PlayerQuickItemController")
	if controller == null or not controller.has_method("assign_slot_by_item_id"):
		return
	if not bool(controller.call("assign_slot_by_item_id", pending_quick_item_slot_index, item_id)):
		return
	loadout_page = LOADOUT_QUICK_ITEMS
	pending_quick_item_slot_index = -1
	selected_action_index = max(quick_item_return_action_index, 0)
	refresh_menu_data()
	rebuild_menu()


func _select_divine_special(special_id: String) -> void:
	var controller: Node = _get_divine_special_controller()
	if controller == null or special_id == "":
		return
	if controller.has_method("select_special_by_id"):
		controller.call("select_special_by_id", special_id, OS.is_debug_build())
	rebuild_menu()


func _add_compact_spell_tile(parent: Container, spell: Dictionary) -> void:
	var slot_index: int = int(spell.get("slot", 0))
	var action: Dictionary = _nav_action(
		{"kind": "choose_spell_slot", "slot": slot_index},
		3,
		slot_index
	)
	var action_index: int = selectable_actions.size()
	selectable_actions.append(action)
	var is_selected: bool = action_index == selected_action_index
	var is_empty: bool = bool(spell.get("is_empty", false))
	var icon: String = "✦" if is_empty else get_spell_icon(str(spell.get("element", "neutral")))
	var name: String = "Empty" if is_empty else str(spell.get("name", "Spell"))
	if name.length() > 14:
		name = name.substr(0, 12) + "…"
	var button: Button = Button.new()
	button.text = icon + "\n" + str(slot_index + 1) + "  " + name
	button.tooltip_text = str(spell.get("description", "Select to assign a learned spell."))
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(98.0, 78.0)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 12 if is_selected else 11)
	button.add_theme_color_override("font_color", TEXT_MAIN if is_selected else TEXT_SOFT)
	button.add_theme_stylebox_override(
		"normal",
		make_panel_style(
			ACTIVE_SELECTION_BACKGROUND if is_selected else CARD_BACKGROUND,
			ACTIVE_SELECTION_BORDER if is_selected else CARD_BORDER,
			3 if is_selected else 1,
			10
		)
	)
	button.add_theme_stylebox_override("focus", make_panel_style(ACTIVE_SELECTION_BACKGROUND, ACTIVE_SELECTION_BORDER, 3, 10))
	button.add_theme_stylebox_override("hover", make_panel_style(Color(0.15, 0.105, 0.08, 0.92), ACTIVE_SELECTION_BORDER, 2, 10))
	button.add_theme_stylebox_override("pressed", make_panel_style(ACTIVE_SELECTION_BACKGROUND, ACTIVE_SELECTION_BORDER, 3, 10))
	button.mouse_entered.connect(_on_action_row_hovered.bind(action_index))
	button.pressed.connect(_on_action_row_pressed.bind(action_index))
	parent.add_child(button)
	if is_selected:
		schedule_selected_control(button)


func _make_local_header(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", TEXT_MAIN)
	label.add_theme_font_size_override("font_size", 15)
	return label


func _nav_action(action: Dictionary, row: int, column: int) -> Dictionary:
	var result: Dictionary = action.duplicate(true)
	result["nav_row"] = row
	result["nav_col"] = column
	return result


func _get_equipped_items() -> Dictionary:
	var equipment: Dictionary = {}
	for slot_id: String in MenuEquipmentCatalog.SLOT_ORDER:
		equipment[slot_id] = GameState.get_equipped_item(slot_id)
	return equipment


func _get_divine_special_controller() -> Node:
	var controller: Node = get_tree().get_first_node_in_group("player_divine_special_controller")
	if controller == null:
		controller = get_tree().get_first_node_in_group("divine_special_controller")
	return controller


func _get_divine_special_summary() -> Dictionary:
	var controller: Node = _get_divine_special_controller()
	if controller == null:
		return {
			"badge": "UNAVAILABLE",
			"description": "The current player does not contain a Divine Special controller.",
		}
	var selected: DivineSpecialDefinition = controller.call("get_selected_special", OS.is_debug_build()) as DivineSpecialDefinition
	var charge: float = float(controller.get("divine_charge"))
	var maximum: float = maxf(float(controller.get("maximum_charge")), 1.0)
	if selected == null:
		return {
			"badge": "NONE  •  " + str(roundi(charge / maximum * 100.0)) + "% CHARGE",
			"description": "Unlock a patron Special to prepare it here.",
		}
	return {
		"badge": selected.display_name.to_upper() + "  •  " + str(roundi(charge / maximum * 100.0)) + "%",
		"description": selected.description,
	}


func _get_equipment_summary() -> String:
	var parts: Array[String] = []
	for slot_id: String in MenuEquipmentCatalog.SLOT_ORDER:
		var item_id: String = GameState.get_equipped_item(slot_id)
		if item_id != "":
			parts.append(MenuEquipmentCatalog.get_display_name(item_id))
	return "  •  ".join(parts) if not parts.is_empty() else "No equipment prepared"


func _count_nonempty_rows(rows: Array) -> int:
	var count: int = 0
	for row_value: Variant in rows:
		if row_value is Dictionary and not bool((row_value as Dictionary).get("is_empty", false)):
			count += 1
	return count
