extends PanelContainer

const ComboRuleRegistryScript = preload("res://scripts/systems/combo_rule_registry.gd")
const EquipmentCatalogScript = preload("res://scripts/equipment/equipment_catalog.gd")

const TAB_DEFS: Array[Dictionary] = [
	{"id": "loadout", "title": "Loadout", "icon": "⚔"},
	{"id": "magic", "title": "Magic", "icon": "✦"},
	{"id": "items", "title": "Items", "icon": "🧪"},
	{"id": "relics", "title": "Relics", "icon": "🔑"},
	{"id": "grace", "title": "Grace", "icon": "◇"},
	{"id": "journal", "title": "Journal", "icon": "📜"},
	{"id": "codex", "title": "Codex", "icon": "🧩"},
	{"id": "system", "title": "System", "icon": "⚙"},
]

const PANEL_BACKGROUND: Color = Color(0.025, 0.032, 0.045, 0.94)
const PANEL_BORDER: Color = Color(0.58, 0.66, 0.9, 0.72)
const SIDE_BACKGROUND: Color = Color(0.04, 0.052, 0.073, 0.9)
const CARD_BACKGROUND: Color = Color(0.07, 0.085, 0.115, 0.76)
const CARD_SELECTED_BACKGROUND: Color = Color(0.12, 0.09, 0.22, 0.86)
const CARD_BORDER: Color = Color(0.28, 0.34, 0.5, 0.5)
const CARD_SELECTED_BORDER: Color = Color(0.72, 0.48, 1.0, 0.95)
const ACTIVE_SELECTION_BACKGROUND: Color = Color(0.2, 0.115, 0.035, 0.98)
const ACTIVE_SELECTION_BORDER: Color = Color(1.0, 0.74, 0.2, 1.0)
const CHIP_BACKGROUND: Color = Color(0.12, 0.14, 0.19, 0.86)
const CHIP_BORDER: Color = Color(0.36, 0.42, 0.56, 0.68)
const TEXT_MAIN: Color = Color(0.93, 0.96, 1.0, 0.98)
const TEXT_SOFT: Color = Color(0.66, 0.74, 0.86, 0.9)
const TEXT_DIM: Color = Color(0.48, 0.56, 0.68, 0.76)

var selected_tab_index: int = 0
var selected_action_index: int = 0
var menu_data: Dictionary = {}
var selectable_actions: Array = []

var assignment_mode: String = ""
var pending_spell_slot_index: int = -1
var pending_item_slot_index: int = -1
var pending_spell_return_action_index: int = -1
var pending_item_return_action_index: int = -1
var tab_action_memory: Dictionary = {}
var action_grid_columns: int = 1
var action_layout_mode: String = "list"
var pending_inventory_item_id: String = ""
var pending_item_grid_return_action_index: int = -1
var pending_equipment_slot_id: String = ""
var pending_equipment_return_action_index: int = -1

var title_label: Label
var subtitle_label: Label
var tab_box: HBoxContainer
var content_title_label: Label
var content_box: VBoxContainer
var scroll_container: ScrollContainer
var selected_action_control: Control
var footer_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 32.0
	offset_top = 32.0
	offset_right = -32.0
	offset_bottom = -32.0
	add_theme_stylebox_override("panel", make_panel_style(PANEL_BACKGROUND, PANEL_BORDER, 2, 18))
	build_layout()


func show_menu(new_menu_data: Dictionary) -> void:
	menu_data = new_menu_data.duplicate(true)
	selected_tab_index = clamp(selected_tab_index, 0, TAB_DEFS.size() - 1)
	selected_action_index = int(tab_action_memory.get(get_current_tab_id(), selected_action_index))
	visible = true
	rebuild_menu()


func hide_menu() -> void:
	visible = false
	cancel_assignment(false)


func is_open() -> bool:
	return visible


func handle_menu_input(event: InputEvent) -> bool:
	if not visible:
		return false

	if event.is_action_pressed("ui_cancel"):
		if is_assignment_active():
			cancel_assignment()
			return true
		return false

	if event is InputEventJoypadButton:
		var joy_button: InputEventJoypadButton = event as InputEventJoypadButton
		if not joy_button.pressed:
			return true
		match joy_button.button_index:
			JOY_BUTTON_LEFT_SHOULDER:
				select_tab(selected_tab_index - 1)
				return true
			JOY_BUTTON_RIGHT_SHOULDER:
				select_tab(selected_tab_index + 1)
				return true
			JOY_BUTTON_DPAD_LEFT:
				select_action_direction(-1, 0)
				return true
			JOY_BUTTON_DPAD_RIGHT:
				select_action_direction(1, 0)
				return true
			_:
				pass

	if event.is_action_pressed("ui_up"):
		select_action_direction(0, -1)
		return true

	if event.is_action_pressed("ui_down"):
		select_action_direction(0, 1)
		return true

	if event.is_action_pressed("ui_accept"):
		activate_selected_action()
		return true

	if event.is_action_pressed("ui_left"):
		select_action_direction(-1, 0)
		return true

	if event.is_action_pressed("ui_right"):
		select_action_direction(1, 0)
		return true

	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return true

		match key_event.physical_keycode:
			KEY_1:
				select_tab(0)
			KEY_2:
				select_tab(1)
			KEY_3:
				select_tab(2)
			KEY_4:
				select_tab(3)
			KEY_5:
				select_tab(4)
			KEY_6:
				select_tab(5)
			KEY_7:
				select_tab(6)
			KEY_8:
				select_tab(7)
			KEY_Q:
				select_tab(selected_tab_index - 1)
			KEY_E:
				select_tab(selected_tab_index + 1)
			KEY_W, KEY_UP:
				select_action_direction(0, -1)
			KEY_S, KEY_DOWN:
				select_action_direction(0, 1)
			KEY_A, KEY_LEFT:
				select_action_direction(-1, 0)
			KEY_D, KEY_RIGHT:
				select_action_direction(1, 0)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				activate_selected_action()
			_:
				pass
		return true

	if event is InputEventMouseButton:
		return true

	if event is InputEventMouseMotion:
		return true

	return true


func select_tab(index: int) -> void:
	if is_assignment_active():
		return
	remember_current_action()
	selected_tab_index = (index + TAB_DEFS.size()) % TAB_DEFS.size()
	selected_action_index = int(tab_action_memory.get(get_current_tab_id(), 0))
	rebuild_menu()


func select_action(index: int) -> void:
	if selectable_actions.size() <= 0:
		selected_action_index = 0
		return

	selected_action_index = (index + selectable_actions.size()) % selectable_actions.size()
	tab_action_memory[get_current_tab_id()] = selected_action_index
	rebuild_menu()


func select_action_direction(horizontal: int, vertical: int) -> void:
	if selectable_actions.is_empty():
		if vertical != 0:
			scroll_content(vertical)
		return

	if action_layout_mode == "cross":
		var cross_target: int = selected_action_index
		if horizontal < 0:
			cross_target = 1
		elif horizontal > 0:
			cross_target = 2
		elif vertical < 0:
			cross_target = 0
		elif vertical > 0:
			cross_target = 3
		select_action(cross_target)
		return

	if action_grid_columns <= 1:
		if vertical != 0:
			select_action(selected_action_index + vertical)
		return

	var row: int = selected_action_index / action_grid_columns
	var column: int = selected_action_index % action_grid_columns
	var target_row: int = row + vertical
	var target_column: int = column + horizontal
	target_row = max(target_row, 0)
	target_column = clamp(target_column, 0, action_grid_columns - 1)
	var target_index: int = target_row * action_grid_columns + target_column
	if target_index >= selectable_actions.size():
		target_index = selectable_actions.size() - 1
	select_action(target_index)


func get_current_tab_id() -> String:
	if selected_tab_index < 0 or selected_tab_index >= TAB_DEFS.size():
		return "loadout"
	return str(TAB_DEFS[selected_tab_index].get("id", "loadout"))


func remember_current_action() -> void:
	tab_action_memory[get_current_tab_id()] = selected_action_index


func activate_selected_action() -> void:
	if selectable_actions.size() <= 0:
		return

	selected_action_index = clamp(selected_action_index, 0, selectable_actions.size() - 1)
	activate_action(selectable_actions[selected_action_index])


func activate_action(action: Dictionary) -> void:
	match str(action.get("kind", "")):
		"choose_spell_slot":
			start_spell_assignment(int(action.get("slot", -1)))
		"assign_spell":
			complete_spell_assignment(int(action.get("learned_index", -1)))
		"choose_item_slot":
			start_item_assignment(int(action.get("slot", -1)))
		"assign_item":
			complete_item_assignment(str(action.get("item_id", "")))
		"choose_item_for_belt":
			start_item_slot_assignment(str(action.get("item_id", "")))
		"assign_item_slot":
			complete_item_slot_assignment(int(action.get("slot", -1)))
		"choose_equipment_slot":
			start_equipment_assignment(str(action.get("slot_id", "")))
		"equip_item":
			complete_equipment_assignment(str(action.get("item_id", "")))
		"inspect_spell":
			return
		_:
			return


func start_equipment_assignment(slot_id: String) -> void:
	if not EquipmentCatalogScript.SLOT_ORDER.has(slot_id):
		return

	pending_equipment_return_action_index = selected_action_index
	tab_action_memory["loadout"] = selected_action_index
	assignment_mode = "equipment"
	pending_equipment_slot_id = slot_id
	selected_tab_index = get_tab_index("loadout")
	selected_action_index = 0
	rebuild_menu()


func complete_equipment_assignment(item_id: String) -> void:
	if not is_assigning_equipment():
		return
	if EquipmentCatalogScript.get_slot(item_id) != pending_equipment_slot_id:
		return
	if not GameState.equip_item(item_id):
		return

	var return_action_index: int = pending_equipment_return_action_index
	assignment_mode = ""
	pending_equipment_slot_id = ""
	pending_equipment_return_action_index = -1
	selected_tab_index = get_tab_index("loadout")
	selected_action_index = max(return_action_index, 0)
	tab_action_memory["loadout"] = selected_action_index
	refresh_menu_data()
	rebuild_menu()


func start_spell_assignment(slot_index: int) -> void:
	if slot_index < 0:
		return

	pending_spell_return_action_index = selected_action_index
	tab_action_memory["loadout"] = selected_action_index
	assignment_mode = "spell"
	pending_spell_slot_index = slot_index
	selected_tab_index = get_tab_index("magic")
	selected_action_index = 0
	rebuild_menu()


func complete_spell_assignment(learned_index: int) -> void:
	if not is_assigning_spell():
		return

	var ability_caster: Node = get_ability_caster()
	var loadout: AbilityLoadout = get_ability_loadout(ability_caster)

	if loadout == null:
		return

	var learned: Array = get_learned_abilities(loadout)

	if learned_index < 0 or learned_index >= learned.size():
		return

	var ability: AbilityDefinition = learned[learned_index]

	if ability == null:
		return

	var assigned_slot: int = pending_spell_slot_index
	var return_action_index: int = pending_spell_return_action_index
	loadout.equip_ability(assigned_slot, ability)

	if ability_caster != null and ability_caster.has_method("select_ability"):
		ability_caster.call("select_ability", assigned_slot, true)

	assignment_mode = ""
	pending_spell_slot_index = -1
	pending_spell_return_action_index = -1
	selected_tab_index = get_tab_index("loadout")
	selected_action_index = max(return_action_index, 0)
	tab_action_memory["loadout"] = selected_action_index
	refresh_menu_data()
	rebuild_menu()


func start_item_assignment(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= 4:
		return
	pending_item_return_action_index = selected_action_index
	tab_action_memory["loadout"] = selected_action_index
	assignment_mode = "item"
	pending_item_slot_index = slot_index
	selected_tab_index = get_tab_index("items")
	selected_action_index = 0
	rebuild_menu()


func complete_item_assignment(item_id: String) -> void:
	if not is_assigning_item():
		return
	var controller: Node = find_first_node_named(get_tree().current_scene, "PlayerQuickItemController")
	if controller == null or not controller.has_method("assign_slot_by_item_id"):
		return
	if not bool(controller.call("assign_slot_by_item_id", pending_item_slot_index, item_id)):
		return
	var return_action_index: int = pending_item_return_action_index
	assignment_mode = ""
	pending_item_slot_index = -1
	pending_item_return_action_index = -1
	selected_tab_index = get_tab_index("loadout")
	selected_action_index = max(return_action_index, 0)
	tab_action_memory["loadout"] = selected_action_index
	refresh_menu_data()
	rebuild_menu()


func start_item_slot_assignment(item_id: String) -> void:
	if item_id == "" or GameState.get_inventory_count(item_id) <= 0:
		return
	pending_inventory_item_id = item_id
	pending_item_grid_return_action_index = selected_action_index
	assignment_mode = "item_slot"
	selected_action_index = 0
	rebuild_menu()


func complete_item_slot_assignment(slot_index: int) -> void:
	if not is_assigning_item_slot() or slot_index < 0 or slot_index >= 4:
		return
	var controller: Node = find_first_node_named(get_tree().current_scene, "PlayerQuickItemController")
	if controller == null or not controller.has_method("assign_slot_by_item_id"):
		return
	if not bool(controller.call("assign_slot_by_item_id", slot_index, pending_inventory_item_id)):
		return
	var return_action_index: int = pending_item_grid_return_action_index
	assignment_mode = ""
	pending_inventory_item_id = ""
	pending_item_grid_return_action_index = -1
	selected_tab_index = get_tab_index("items")
	selected_action_index = max(return_action_index, 0)
	tab_action_memory["items"] = selected_action_index
	refresh_menu_data()
	rebuild_menu()


func cancel_assignment(should_rebuild: bool = true) -> void:
	var was_spell_assignment: bool = is_assigning_spell()
	var was_item_assignment: bool = is_assigning_item()
	var was_item_slot_assignment: bool = is_assigning_item_slot()
	var was_equipment_assignment: bool = is_assigning_equipment()
	var return_action_index: int = -1
	if was_spell_assignment:
		return_action_index = pending_spell_return_action_index
	elif was_item_assignment:
		return_action_index = pending_item_return_action_index
	elif was_item_slot_assignment:
		return_action_index = pending_item_grid_return_action_index
	elif was_equipment_assignment:
		return_action_index = pending_equipment_return_action_index

	assignment_mode = ""
	pending_spell_slot_index = -1
	pending_item_slot_index = -1
	pending_spell_return_action_index = -1
	pending_item_return_action_index = -1
	pending_inventory_item_id = ""
	pending_item_grid_return_action_index = -1
	pending_equipment_slot_id = ""
	pending_equipment_return_action_index = -1

	if was_item_slot_assignment:
		selected_tab_index = get_tab_index("items")
		selected_action_index = max(return_action_index, 0)
		tab_action_memory["items"] = selected_action_index
	elif was_spell_assignment or was_item_assignment or was_equipment_assignment:
		selected_tab_index = get_tab_index("loadout")
		selected_action_index = max(return_action_index, 0)
		tab_action_memory["loadout"] = selected_action_index

	if should_rebuild:
		rebuild_menu()



func is_assigning_spell() -> bool:
	return assignment_mode == "spell" and pending_spell_slot_index >= 0


func is_assigning_item() -> bool:
	return assignment_mode == "item" and pending_item_slot_index >= 0


func is_assigning_item_slot() -> bool:
	return assignment_mode == "item_slot" and pending_inventory_item_id != ""


func is_assigning_equipment() -> bool:
	return assignment_mode == "equipment" and pending_equipment_slot_id != ""


func is_assignment_active() -> bool:
	return is_assigning_spell() or is_assigning_item() or is_assigning_item_slot() or is_assigning_equipment()


func refresh_menu_data() -> void:
	var director: Node = get_node_or_null("/root/FullMenuDirector")

	if director == null or not director.has_method("build_menu_data"):
		return

	var data_variant: Variant = director.call("build_menu_data")

	if data_variant is Dictionary:
		menu_data = (data_variant as Dictionary).duplicate(true)


func get_tab_index(tab_id: String) -> int:
	for i: int in range(TAB_DEFS.size()):
		var tab_def: Dictionary = TAB_DEFS[i]
		if str(tab_def.get("id", "")) == tab_id:
			return i

	return 0


func build_layout() -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var root_box: VBoxContainer = VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 10)
	margin.add_child(root_box)

	var header_box: HBoxContainer = HBoxContainer.new()
	header_box.add_theme_constant_override("separation", 12)
	root_box.add_child(header_box)

	var header_text_box: VBoxContainer = VBoxContainer.new()
	header_text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_box.add_child(header_text_box)

	title_label = Label.new()
	title_label.text = "GRACE'S FIELD KIT"
	title_label.add_theme_color_override("font_color", TEXT_MAIN)
	title_label.add_theme_font_size_override("font_size", 27)
	header_text_box.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.text = "Equipment  •  Magic  •  Supplies  •  Records"
	subtitle_label.add_theme_color_override("font_color", TEXT_SOFT)
	subtitle_label.add_theme_font_size_override("font_size", 12)
	header_text_box.add_child(subtitle_label)

	var close_label: Label = Label.new()
	close_label.text = "Tab / M / Menu: close"
	close_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	close_label.add_theme_color_override("font_color", TEXT_DIM)
	close_label.add_theme_font_size_override("font_size", 12)
	header_box.add_child(close_label)

	var tab_panel: PanelContainer = PanelContainer.new()
	tab_panel.add_theme_stylebox_override("panel", make_panel_style(SIDE_BACKGROUND, CARD_BORDER, 1, 12))
	root_box.add_child(tab_panel)

	var tab_margin: MarginContainer = MarginContainer.new()
	tab_margin.add_theme_constant_override("margin_left", 8)
	tab_margin.add_theme_constant_override("margin_top", 7)
	tab_margin.add_theme_constant_override("margin_right", 8)
	tab_margin.add_theme_constant_override("margin_bottom", 7)
	tab_panel.add_child(tab_margin)

	tab_box = HBoxContainer.new()
	tab_box.add_theme_constant_override("separation", 7)
	tab_margin.add_child(tab_box)

	var content_panel: PanelContainer = PanelContainer.new()
	content_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_panel.add_theme_stylebox_override("panel", make_panel_style(Color(0.035, 0.045, 0.062, 0.9), CARD_BORDER, 1, 14))
	root_box.add_child(content_panel)

	var content_margin: MarginContainer = MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 18)
	content_margin.add_theme_constant_override("margin_top", 14)
	content_margin.add_theme_constant_override("margin_right", 18)
	content_margin.add_theme_constant_override("margin_bottom", 14)
	content_panel.add_child(content_margin)

	var content_root: VBoxContainer = VBoxContainer.new()
	content_root.add_theme_constant_override("separation", 10)
	content_margin.add_child(content_root)

	content_title_label = Label.new()
	content_title_label.text = "Loadout"
	content_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_title_label.add_theme_color_override("font_color", ACTIVE_SELECTION_BORDER)
	content_title_label.add_theme_font_size_override("font_size", 20)
	content_root.add_child(content_title_label)

	scroll_container = ScrollContainer.new()
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.follow_focus = true
	content_root.add_child(scroll_container)

	content_box = VBoxContainer.new()
	content_box.add_theme_constant_override("separation", 10)
	content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(content_box)

	footer_label = Label.new()
	footer_label.text = get_footer_text()
	footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer_label.add_theme_color_override("font_color", TEXT_SOFT)
	footer_label.add_theme_font_size_override("font_size", 12)
	root_box.add_child(footer_label)



func rebuild_menu() -> void:
	rebuild_tabs()
	rebuild_content()
	footer_label.text = get_footer_text()


func rebuild_tabs() -> void:
	clear_children(tab_box)

	for i: int in range(TAB_DEFS.size()):
		var tab_def: Dictionary = TAB_DEFS[i]
		var is_selected: bool = i == selected_tab_index
		var tab_button: Button = Button.new()
		tab_button.text = str(tab_def.get("icon", "")) + "\n" + str(tab_def.get("title", "Tab"))
		tab_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		tab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_button.custom_minimum_size = Vector2(96.0, 58.0)
		tab_button.add_theme_font_size_override("font_size", 13)
		tab_button.add_theme_color_override("font_color", TEXT_MAIN if is_selected else TEXT_SOFT)
		tab_button.add_theme_stylebox_override(
			"normal",
			make_panel_style(ACTIVE_SELECTION_BACKGROUND if is_selected else Color(0.045, 0.06, 0.083, 0.72), ACTIVE_SELECTION_BORDER if is_selected else CARD_BORDER, 3 if is_selected else 1, 9)
		)
		tab_button.add_theme_stylebox_override("hover", make_panel_style(Color(0.13, 0.105, 0.08, 0.9), ACTIVE_SELECTION_BORDER, 2, 9))
		tab_button.pressed.connect(_on_tab_pressed.bind(i))
		tab_box.add_child(tab_button)



func _on_tab_pressed(index: int) -> void:
	select_tab(index)


func rebuild_content() -> void:
	selectable_actions.clear()
	selected_action_control = null
	action_grid_columns = 1
	action_layout_mode = "list"
	clear_children(content_box)

	var tab_def: Dictionary = TAB_DEFS[selected_tab_index]
	var tab_id: String = str(tab_def.get("id", "loadout"))
	content_title_label.text = str(tab_def.get("icon", "")) + " " + str(tab_def.get("title", "Loadout"))

	match tab_id:
		"loadout":
			render_loadout()
		"magic":
			render_magic()
		"items":
			render_items()
		"relics":
			render_relics()
		"grace":
			render_grace()
		"journal":
			render_journal()
		"codex":
			render_codex()
		"system":
			render_system()
		_:
			add_text_card("Coming Soon", "This shelf has not been built yet.")

	if selectable_actions.size() <= 0:
		selected_action_index = 0
	else:
		selected_action_index = clamp(selected_action_index, 0, selectable_actions.size() - 1)


func render_loadout() -> void:
	action_grid_columns = 4
	action_layout_mode = "grid"

	if is_assigning_equipment():
		render_equipment_picker()
		return

	var summary: Dictionary = menu_data.get("loadout_summary", {})
	add_summary_card([
		"Known spells " + str(summary.get("learned_count", 0)),
		"Active ring " + str(summary.get("active_ring_count", 0)),
		"Four quick-item directions",
	])

	add_section_header("EQUIPMENT")
	var equipment_grid: GridContainer = make_visual_grid(4)
	content_box.add_child(equipment_grid)
	for slot_id: String in EquipmentCatalogScript.SLOT_ORDER:
		var equipped_item_id: String = GameState.get_equipped_item(slot_id)
		var definition: Dictionary = EquipmentCatalogScript.get_definition(equipped_item_id)
		var item_name: String = str(definition.get("name", "Empty"))
		var item_icon: String = str(definition.get("icon", "◇"))
		var modifiers: Dictionary = definition.get("modifiers", {})
		var badge: String = slot_id.to_upper()
		if not modifiers.is_empty():
			badge += "  •  " + EquipmentCatalogScript.format_modifiers(modifiers)
		add_visual_action_tile(
			equipment_grid,
			item_icon,
			item_name,
			badge,
			{"kind": "choose_equipment_slot", "slot_id": slot_id},
			str(definition.get("description", "Choose owned gear for this slot."))
		)

	add_section_header("SPELL RING")
	var spell_grid: GridContainer = GridContainer.new()
	spell_grid.columns = 4
	spell_grid.add_theme_constant_override("h_separation", 10)
	spell_grid.add_theme_constant_override("v_separation", 10)
	content_box.add_child(spell_grid)
	var equipped_slots: Array = menu_data.get("equipped_spell_slots", [])
	for slot_variant in equipped_slots:
		if not (slot_variant is Dictionary):
			continue
		var spell: Dictionary = slot_variant as Dictionary
		var slot_index: int = int(spell.get("slot", 0))
		var is_empty: bool = bool(spell.get("is_empty", false))
		var icon_text: String = "✦" if is_empty else get_spell_icon(str(spell.get("element", "neutral")))
		var spell_name: String = "Empty" if is_empty else str(spell.get("name", "Spell"))
		var badge: String = "HOTKEY " + str(slot_index + 1)
		if not is_empty:
			badge += "  •  " + get_spell_cost_label(spell)
		add_visual_action_tile(spell_grid, icon_text, spell_name, badge, {"kind": "choose_spell_slot", "slot": slot_index}, str(spell.get("description", "")))

	add_section_header("QUICK BELT")
	var belt_grid: GridContainer = GridContainer.new()
	belt_grid.columns = 4
	belt_grid.add_theme_constant_override("h_separation", 10)
	belt_grid.add_theme_constant_override("v_separation", 10)
	content_box.add_child(belt_grid)
	var item_slots: Array = menu_data.get("quick_item_slots", [])
	for slot_variant in item_slots:
		if not (slot_variant is Dictionary):
			continue
		var item_slot: Dictionary = slot_variant as Dictionary
		var item_name: String = "Empty" if bool(item_slot.get("is_empty", true)) else str(item_slot.get("name", "Item"))
		var item_icon: String = "◇" if bool(item_slot.get("is_empty", true)) else str(item_slot.get("icon", "◇"))
		var direction: String = str(item_slot.get("direction", "Slot"))
		var badge: String = get_direction_symbol(direction) + "  D-PAD " + direction.to_upper()
		if not bool(item_slot.get("is_empty", true)):
			badge += "  •  ×" + str(item_slot.get("count", 0))
		add_visual_action_tile(belt_grid, item_icon, item_name, badge, {"kind": "choose_item_slot", "slot": int(item_slot.get("slot", 0))})

	add_visual_info_card("🛠", "Gadgets", "Vehicles, summons, and deployable devices will occupy this bay later.", "Future")


func render_equipment_picker() -> void:
	action_grid_columns = 3
	action_layout_mode = "grid"
	var slot_title: String = pending_equipment_slot_id.capitalize()
	add_assignment_banner("Choose " + slot_title, "Owned gear only  •  Confirm equips  •  Cancel returns to Loadout")

	var equipment_grid: GridContainer = make_visual_grid(3)
	content_box.add_child(equipment_grid)
	var owned_count: int = 0
	for definition: Dictionary in EquipmentCatalogScript.get_rows_for_slot(pending_equipment_slot_id):
		var item_id: String = str(definition.get("id", ""))
		if item_id == "" or not GameState.owns_equipment(item_id):
			continue
		owned_count += 1
		var badge: String = EquipmentCatalogScript.format_modifiers(definition.get("modifiers", {}))
		if GameState.is_equipment_equipped(item_id):
			badge = "EQUIPPED  •  " + badge
		add_visual_action_tile(
			equipment_grid,
			str(definition.get("icon", "◇")),
			str(definition.get("name", item_id.capitalize())),
			badge,
			{"kind": "equip_item", "item_id": item_id},
			str(definition.get("description", ""))
		)

	if owned_count <= 0:
		add_visual_info_card("◇", "Nothing owned", "Purchase or discover gear for this slot before equipping it.", slot_title)


func render_items() -> void:
	var inventory_rows: Array = menu_data.get("inventory_items", [])
	if is_assigning_item_slot():
		render_item_slot_picker(inventory_rows)
		return

	action_grid_columns = 3
	action_layout_mode = "grid"

	var total_count: int = 0
	for row_variant in inventory_rows:
		if row_variant is Dictionary:
			total_count += int((row_variant as Dictionary).get("count", 0))

	if is_assigning_item():
		var directions: Array[String] = ["Up", "Left", "Right", "Down"]
		add_assignment_banner("Choose an item for " + get_direction_symbol(directions[pending_item_slot_index]) + " D-pad " + directions[pending_item_slot_index], "Confirm assigns it. Cancel returns to the belt.")
	else:
		add_summary_card(["Carried " + str(total_count), "Item types " + str(inventory_rows.size()), "Select an item to assign"])

	if inventory_rows.is_empty():
		add_visual_info_card("◇", "No Supplies", "Explore containers, enemies, and hidden caches to fill this pouch.", "Empty")
		if is_assigning_item():
			var empty_grid: GridContainer = make_visual_grid(3)
			content_box.add_child(empty_grid)
			add_visual_action_tile(empty_grid, "×", "Clear Slot", "EMPTY", {"kind": "assign_item", "item_id": ""})
		return

	selected_action_index = clamp(selected_action_index, 0, inventory_rows.size() - 1 + (1 if is_assigning_item() else 0))
	var workspace: HBoxContainer = HBoxContainer.new()
	workspace.add_theme_constant_override("separation", 16)
	workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_box.add_child(workspace)

	var grid_panel: PanelContainer = PanelContainer.new()
	grid_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_panel.add_theme_stylebox_override("panel", make_panel_style(Color(0.025, 0.035, 0.05, 0.72), CARD_BORDER, 1, 12))
	workspace.add_child(grid_panel)
	var grid_margin: MarginContainer = MarginContainer.new()
	grid_margin.add_theme_constant_override("margin_left", 12)
	grid_margin.add_theme_constant_override("margin_top", 12)
	grid_margin.add_theme_constant_override("margin_right", 12)
	grid_margin.add_theme_constant_override("margin_bottom", 12)
	grid_panel.add_child(grid_margin)
	var item_grid: GridContainer = make_visual_grid(3)
	grid_margin.add_child(item_grid)

	for row_variant in inventory_rows:
		if not (row_variant is Dictionary):
			continue
		var row: Dictionary = row_variant as Dictionary
		var item_id: String = str(row.get("id", ""))
		var count: int = int(row.get("count", 0))
		var badge: String = "×" + str(count)
		var assigned_label: String = get_item_assignment_label(item_id)
		if assigned_label != "":
			badge += "  •  " + assigned_label.replace("Assigned: ", "")
		var action: Dictionary = {"kind": "assign_item", "item_id": item_id} if is_assigning_item() else {"kind": "choose_item_for_belt", "item_id": item_id}
		add_visual_action_tile(item_grid, str(row.get("icon", "◇")), str(row.get("name", item_id.capitalize())), badge, action, str(row.get("description", "")))

	if is_assigning_item():
		add_visual_action_tile(item_grid, "×", "Clear Slot", "EMPTY", {"kind": "assign_item", "item_id": ""})

	var detail_row: Dictionary = {}
	if selected_action_index >= 0 and selected_action_index < inventory_rows.size():
		detail_row = inventory_rows[selected_action_index] as Dictionary
	add_item_detail_panel(workspace, detail_row)


func render_item_slot_picker(inventory_rows: Array) -> void:
	action_layout_mode = "cross"
	action_grid_columns = 3
	var item_row: Dictionary = find_inventory_row(pending_inventory_item_id, inventory_rows)
	add_assignment_banner("Place " + str(item_row.get("name", pending_inventory_item_id.capitalize())) + " on the quick belt", "Choose a direction. Existing assignments are replaced, but no stock is consumed.")
	add_visual_info_card(str(item_row.get("icon", "◇")), str(item_row.get("name", "Item")), str(item_row.get("description", "")), "×" + str(item_row.get("count", 0)))

	var center: CenterContainer = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_box.add_child(center)
	var cross_grid: GridContainer = make_visual_grid(3)
	cross_grid.custom_minimum_size = Vector2(560.0, 360.0)
	center.add_child(cross_grid)

	add_cross_spacer(cross_grid)
	add_item_slot_choice(cross_grid, 0, "Up")
	add_cross_spacer(cross_grid)
	add_item_slot_choice(cross_grid, 1, "Left")
	add_cross_spacer(cross_grid)
	add_item_slot_choice(cross_grid, 2, "Right")
	add_cross_spacer(cross_grid)
	add_item_slot_choice(cross_grid, 3, "Down")
	add_cross_spacer(cross_grid)


func add_item_slot_choice(parent: Container, slot_index: int, direction: String) -> void:
	var slots: Array = menu_data.get("quick_item_slots", [])
	var current_name: String = "Empty"
	if slot_index >= 0 and slot_index < slots.size() and slots[slot_index] is Dictionary:
		current_name = str((slots[slot_index] as Dictionary).get("name", "Empty"))
	add_visual_action_tile(parent, get_direction_symbol(direction), "D-pad " + direction, "Currently: " + current_name, {"kind": "assign_item_slot", "slot": slot_index})


func add_cross_spacer(parent: Container) -> void:
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(150.0, 108.0)
	parent.add_child(spacer)


func find_inventory_row(item_id: String, inventory_rows: Array) -> Dictionary:
	for row_variant in inventory_rows:
		if row_variant is Dictionary and str((row_variant as Dictionary).get("id", "")) == item_id:
			return row_variant as Dictionary
	return {}



func render_magic() -> void:
	action_grid_columns = 4
	action_layout_mode = "grid"
	if is_assigning_spell():
		add_assignment_banner("Choose a spell for Hotkey " + str(pending_spell_slot_index + 1), "Confirm assigns it. Cancel returns to the ring.")
	else:
		add_summary_card(["Sixteen elements", "Four active hotkeys", "Select a spell to inspect"])

	var library_sections: Array = menu_data.get("learned_spell_sections", [])
	if library_sections.is_empty():
		add_visual_info_card("✦", "No Learned Spells", "New magic will appear here as Grace learns it.", "Spellbook")
		return

	for section_variant in library_sections:
		if not (section_variant is Dictionary):
			continue
		var section: Dictionary = section_variant as Dictionary
		var spells: Array = section.get("spells", [])
		if spells.is_empty():
			continue
		var element_id: String = str(section.get("element", "neutral"))
		add_section_header(get_spell_icon(element_id) + "  " + str(section.get("title", "Element")).to_upper())
		var spell_grid: GridContainer = make_visual_grid(4)
		content_box.add_child(spell_grid)
		for spell_variant in spells:
			if not (spell_variant is Dictionary):
				continue
			var spell: Dictionary = spell_variant as Dictionary
			var action: Dictionary = {"kind": "assign_spell", "learned_index": int(spell.get("learned_index", -1))} if is_assigning_spell() else {"kind": "inspect_spell"}
			var badge: String = get_spell_cost_label(spell)
			var equipped: String = get_spell_equipped_subtitle(spell)
			if equipped != "Spellbook":
				badge += "  •  " + equipped
			add_visual_action_tile(spell_grid, get_spell_icon(str(spell.get("element", element_id))), str(spell.get("name", "Spell")), badge, action, get_short_list_label(spell.get("roles", []), 3, "Utility"))



func render_relics() -> void:
	var key_items: Array = get_key_item_rows_for_menu()
	var blessings: Array = get_unlock_rows_for_type("modifier")
	var permissions: Array = get_unlock_rows_for_type("permission")
	add_summary_card([
		"Key items " + str(key_items.size()),
		"Blessings " + str(blessings.size()),
		"Permissions " + str(permissions.size()),
	])

	add_section_header("Blessings")
	if blessings.size() <= 0:
		add_text_card("No blessings yet", "Challenge rewards that change Grace's rules will appear here.", "🛡", "Empty")
	else:
		for unlock_variant in blessings:
			if unlock_variant is Dictionary:
				render_unlock_card(unlock_variant as Dictionary)

	add_section_header("Key Items")
	if key_items.size() <= 0:
		add_text_card("No key items yet", "Story relics and dungeon proofs will appear here.", "🔑", "Empty")
	else:
		for item_variant in key_items:
			if item_variant is Dictionary:
				render_key_item_card(item_variant as Dictionary)

	add_section_header("World Permissions")
	if permissions.size() <= 0:
		add_text_card("No permissions yet", "Doors, factions, and regions will recognize earned permissions later.", "🚪", "Empty")
	else:
		for unlock_variant in permissions:
			if unlock_variant is Dictionary:
				render_unlock_card(unlock_variant as Dictionary)


func render_grace() -> void:
	add_summary_card([
		"HP " + stat_pair("health", "max_health"),
		"Mana " + stat_pair("mana", "max_mana"),
		"Guard " + stat_pair("guard", "max_guard"),
	])
	add_text_card("Core Resources", "Stamina " + stat_pair("stamina", "max_stamina") + "  ·  Stance " + stat_pair("stance", "max_stance"), "◇", "Vitals")

	var sections: Array = menu_data.get("stat_sections", [])
	if sections.size() <= 0:
		add_text_card("No stat sections found", "GameState did not provide stat section data yet.", "◇", "Stats")
		return

	for section_variant in sections:
		if section_variant is Dictionary:
			render_stat_section(section_variant as Dictionary)


func render_journal() -> void:
	var objective: String = str(menu_data.get("objective", "Look around."))
	add_text_card("Current Objective", objective, "📜", "Now")
	add_text_card("Main Thread", "Find someone who can help Grace understand where she has landed.", "★", "Story")
	add_text_card("Clues", "Signs, lore fragments, puzzle notes, and character leads will be organized here.", "?", "Coming later")


func render_codex() -> void:
	var rows: Array = ComboRuleRegistryScript.get_debug_matrix_rows()
	add_summary_card(["Reaction rules " + str(rows.size()), "Element grammar", "Combo hints"])

	for row_variant in rows:
		if not (row_variant is Dictionary):
			continue

		var row: Dictionary = row_variant as Dictionary
		var title: String = "🧩 " + str(row.get("reaction", "Reaction"))
		var body: String = "In: " + join_values(row.get("incoming", []))
		body += "  ·  Target: " + join_values(row.get("target_tags", []))
		body += "  ·  Status: " + join_values(row.get("target_statuses", []))
		add_text_card(title, body, "🧩", "Rule")


func render_system() -> void:
	add_text_card("Controls", "Tab/M toggles menu  ·  A/D switches tabs  ·  W/S moves rows  ·  Enter chooses  ·  Esc backs out", "⚙", "Input")
	add_text_card("Prototype", "Spell hotkeys and the four-slot quick-item belt can be assigned. Relics show progression unlocks. Settings come later.", "🛠", "Build note")


func add_section_header(title: String) -> void:
	var header: Label = Label.new()
	header.text = title
	header.add_theme_color_override("font_color", TEXT_MAIN)
	header.add_theme_font_size_override("font_size", 15)
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_box.add_child(header)


func add_summary_card(parts: Array) -> void:
	var clean_parts: Array[String] = []
	for part in parts:
		clean_parts.append(str(part))
	add_compact_card("  ·  ".join(clean_parts), false, "Summary")


func add_compact_card(line: String, selected: bool = false, subtitle: String = "") -> void:
	var card: PanelContainer = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override(
		"panel",
		make_panel_style(CARD_SELECTED_BACKGROUND if selected else CARD_BACKGROUND, CARD_SELECTED_BORDER if selected else CARD_BORDER, 2 if selected else 1, 10)
	)
	content_box.add_child(card)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 6)
	card.add_child(margin)

	var row_box: HBoxContainer = HBoxContainer.new()
	row_box.add_theme_constant_override("separation", 8)
	margin.add_child(row_box)

	if subtitle != "":
		var subtitle_label: Label = make_chip_label(subtitle)
		row_box.add_child(subtitle_label)

	var line_label: Label = Label.new()
	line_label.text = line
	line_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_label.clip_text = true
	line_label.add_theme_color_override("font_color", TEXT_MAIN if selected else TEXT_SOFT)
	line_label.add_theme_font_size_override("font_size", 12)
	row_box.add_child(line_label)


func make_visual_grid(columns: int) -> GridContainer:
	var grid: GridContainer = GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return grid


func add_visual_action_tile(parent: Container, icon_text: String, title: String, badge: String, action: Dictionary, tooltip: String = "") -> void:
	var action_index: int = selectable_actions.size()
	selectable_actions.append(action.duplicate(true))
	var is_selected: bool = action_index == selected_action_index
	var button: Button = Button.new()
	button.text = icon_text + "\n" + title + "\n" + badge
	button.tooltip_text = tooltip
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(150.0, 108.0)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 14 if is_selected else 13)
	button.add_theme_color_override("font_color", TEXT_MAIN if is_selected else TEXT_SOFT)
	button.add_theme_stylebox_override("normal", make_panel_style(ACTIVE_SELECTION_BACKGROUND if is_selected else CARD_BACKGROUND, ACTIVE_SELECTION_BORDER if is_selected else CARD_BORDER, 3 if is_selected else 1, 12))
	button.add_theme_stylebox_override("focus", make_panel_style(ACTIVE_SELECTION_BACKGROUND, ACTIVE_SELECTION_BORDER, 3, 12))
	button.add_theme_stylebox_override("hover", make_panel_style(Color(0.15, 0.105, 0.08, 0.92), ACTIVE_SELECTION_BORDER, 2, 12))
	button.add_theme_stylebox_override("pressed", make_panel_style(ACTIVE_SELECTION_BACKGROUND, ACTIVE_SELECTION_BORDER, 3, 12))
	button.mouse_entered.connect(_on_action_row_hovered.bind(action_index))
	button.pressed.connect(_on_action_row_pressed.bind(action_index))
	parent.add_child(button)
	if is_selected:
		schedule_selected_control(button)


func add_visual_info_card(icon_text: String, title: String, body: String, badge: String = "") -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", make_panel_style(Color(0.055, 0.07, 0.095, 0.88), CARD_BORDER, 1, 12))
	content_box.add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)
	var icon_label: Label = Label.new()
	icon_label.text = icon_text
	icon_label.custom_minimum_size = Vector2(54.0, 0.0)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 34)
	icon_label.add_theme_color_override("font_color", ACTIVE_SELECTION_BORDER)
	row.add_child(icon_label)
	var copy: VBoxContainer = VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(copy)
	var title_line: Label = Label.new()
	title_line.text = title
	title_line.add_theme_font_size_override("font_size", 18)
	title_line.add_theme_color_override("font_color", TEXT_MAIN)
	copy.add_child(title_line)
	var body_line: Label = Label.new()
	body_line.text = body
	body_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_line.add_theme_font_size_override("font_size", 12)
	body_line.add_theme_color_override("font_color", TEXT_SOFT)
	copy.add_child(body_line)
	if badge != "":
		var badge_label: Label = make_chip_label(badge)
		row.add_child(badge_label)


func add_assignment_banner(title: String, instruction: String) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", make_panel_style(Color(0.16, 0.095, 0.025, 0.96), ACTIVE_SELECTION_BORDER, 2, 12))
	content_box.add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 9)
	panel.add_child(margin)
	var box: VBoxContainer = VBoxContainer.new()
	margin.add_child(box)
	var title_label_local: Label = Label.new()
	title_label_local.text = title
	title_label_local.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label_local.add_theme_font_size_override("font_size", 18)
	title_label_local.add_theme_color_override("font_color", ACTIVE_SELECTION_BORDER)
	box.add_child(title_label_local)
	var instruction_label: Label = Label.new()
	instruction_label.text = instruction
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_label.add_theme_font_size_override("font_size", 12)
	instruction_label.add_theme_color_override("font_color", TEXT_MAIN)
	box.add_child(instruction_label)


func add_item_detail_panel(parent: Container, row: Dictionary) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(300.0, 0.0)
	panel.add_theme_stylebox_override("panel", make_panel_style(Color(0.055, 0.07, 0.095, 0.92), CARD_BORDER, 1, 12))
	parent.add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	var icon_label: Label = Label.new()
	icon_label.text = str(row.get("icon", "◇"))
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 56)
	icon_label.add_theme_color_override("font_color", ACTIVE_SELECTION_BORDER)
	box.add_child(icon_label)
	var name_label: Label = Label.new()
	name_label.text = str(row.get("name", "Empty Slot"))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 21)
	name_label.add_theme_color_override("font_color", TEXT_MAIN)
	box.add_child(name_label)
	var count_label: Label = Label.new()
	count_label.text = "Carried  ×" + str(row.get("count", 0))
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.add_theme_font_size_override("font_size", 14)
	count_label.add_theme_color_override("font_color", ACTIVE_SELECTION_BORDER)
	box.add_child(count_label)
	var description_label: Label = Label.new()
	description_label.text = str(row.get("description", "Select an item to see its details."))
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.add_theme_font_size_override("font_size", 13)
	description_label.add_theme_color_override("font_color", TEXT_SOFT)
	box.add_child(description_label)
	var item_id: String = str(row.get("id", ""))
	if item_id != "":
		var assigned: String = get_item_assignment_label(item_id)
		var rule: String = "Refills at rest" if bool(row.get("refill_on_rest", false)) else "Consumed on use"
		var rule_label: Label = make_chip_label(rule)
		box.add_child(rule_label)
		if assigned != "":
			var assigned_label: Label = make_chip_label(assigned)
			box.add_child(assigned_label)
	var prompt: Label = Label.new()
	prompt.text = "A / Enter  •  Assign to quick belt" if not is_assigning_item() else "A / Enter  •  Assign to selected direction"
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.add_theme_font_size_override("font_size", 12)
	prompt.add_theme_color_override("font_color", TEXT_DIM)
	box.add_child(prompt)


func get_direction_symbol(direction: String) -> String:
	match direction.to_lower():
		"up":
			return "↑"
		"left":
			return "←"
		"right":
			return "→"
		"down":
			return "↓"
	return "◇"


func add_action_row(line: String, action: Dictionary, subtitle: String = "") -> void:
	var action_index: int = selectable_actions.size()
	selectable_actions.append(action.duplicate(true))

	var button: Button = Button.new()
	var is_selected: bool = action_index == selected_action_index
	var row_text: String = (subtitle + "  ·  " if subtitle != "" else "") + line
	button.text = ("▶  " if is_selected else "    ") + row_text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0.0, 36.0)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 13 if is_selected else 12)
	button.add_theme_color_override("font_color", TEXT_MAIN if is_selected else TEXT_SOFT)
	button.add_theme_stylebox_override("normal", make_panel_style(ACTIVE_SELECTION_BACKGROUND if is_selected else CARD_BACKGROUND, ACTIVE_SELECTION_BORDER if is_selected else CARD_BORDER, 3 if is_selected else 1, 10))
	button.add_theme_stylebox_override("focus", make_panel_style(ACTIVE_SELECTION_BACKGROUND, ACTIVE_SELECTION_BORDER, 3, 10))
	button.add_theme_stylebox_override("hover", make_panel_style(Color(0.15, 0.105, 0.08, 0.9), ACTIVE_SELECTION_BORDER, 2, 10))
	button.add_theme_stylebox_override("pressed", make_panel_style(ACTIVE_SELECTION_BACKGROUND, ACTIVE_SELECTION_BORDER, 3, 10))
	button.mouse_entered.connect(_on_action_row_hovered.bind(action_index))
	button.pressed.connect(_on_action_row_pressed.bind(action_index))
	content_box.add_child(button)
	if is_selected:
		schedule_selected_control(button)


func schedule_selected_control(control: Control) -> void:
	selected_action_control = control
	call_deferred("reveal_selected_control")


func reveal_selected_control() -> void:
	await get_tree().process_frame
	if scroll_container == null or not is_instance_valid(selected_action_control):
		return
	selected_action_control.grab_focus()
	scroll_container.ensure_control_visible(selected_action_control)


func scroll_content(direction: int) -> void:
	if scroll_container == null or direction == 0:
		return
	scroll_container.scroll_vertical += direction * 160


func _on_action_row_pressed(action_index: int) -> void:
	if action_index < 0 or action_index >= selectable_actions.size():
		return

	selected_action_index = action_index
	tab_action_memory[get_current_tab_id()] = selected_action_index
	activate_action(selectable_actions[action_index])


func _on_action_row_hovered(action_index: int) -> void:
	if action_index < 0 or action_index >= selectable_actions.size():
		return
	if action_index == selected_action_index:
		return
	selected_action_index = action_index
	tab_action_memory[get_current_tab_id()] = selected_action_index
	rebuild_menu()


func add_text_card(title: String, body: String, icon: String = "", subtitle: String = "", selected: bool = false) -> void:
	var card: PanelContainer = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", make_panel_style(CARD_SELECTED_BACKGROUND if selected else CARD_BACKGROUND, CARD_SELECTED_BORDER if selected else CARD_BORDER, 2 if selected else 1, 12))
	content_box.add_child(card)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 9)
	card.add_child(margin)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	margin.add_child(box)

	var header_box: HBoxContainer = HBoxContainer.new()
	header_box.add_theme_constant_override("separation", 8)
	box.add_child(header_box)

	if icon != "":
		var icon_label: Label = Label.new()
		icon_label.text = icon
		icon_label.add_theme_font_size_override("font_size", 17)
		header_box.add_child(icon_label)

	var header: Label = Label.new()
	header.text = title
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_color_override("font_color", TEXT_MAIN)
	header.add_theme_font_size_override("font_size", 16)
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header_box.add_child(header)

	if subtitle != "":
		header_box.add_child(make_chip_label(subtitle))

	if body != "":
		var body_label: Label = Label.new()
		body_label.text = body
		body_label.add_theme_color_override("font_color", TEXT_SOFT)
		body_label.add_theme_font_size_override("font_size", 12)
		body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(body_label)


func make_chip_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(74.0, 0.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", TEXT_DIM)
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_stylebox_override("normal", make_panel_style(CHIP_BACKGROUND, CHIP_BORDER, 1, 8))
	return label


func render_quick_item_slot_card(item_slot: Dictionary) -> void:
	var slot_index: int = int(item_slot.get("slot", 0))
	var direction: String = str(item_slot.get("direction", "Slot"))
	var line: String = "D-pad " + direction + "  ·  "
	if bool(item_slot.get("is_empty", true)):
		line += "Empty  ·  choose to assign"
	else:
		line += str(item_slot.get("icon", "◇")) + " " + str(item_slot.get("name", "Item"))
		line += " ×" + str(item_slot.get("count", 0))
	add_action_row(line, {"kind": "choose_item_slot", "slot": slot_index}, "Item")


func render_equipped_slot_card(spell: Dictionary) -> void:
	var slot_index: int = int(spell.get("slot", 0))
	var line: String = ""

	if bool(spell.get("is_empty", false)):
		line = "Hotkey " + str(slot_index + 1) + "  ·  Empty  ·  choose to assign"
	else:
		line = get_spell_compact_line(spell, "Hotkey " + str(slot_index + 1))

	add_action_row(line, {"kind": "choose_spell_slot", "slot": slot_index}, "Hotkey")


func render_library_section(section: Dictionary) -> void:
	var element_title: String = str(section.get("title", "Element"))
	var element_id: String = str(section.get("element", element_title.to_lower()))
	var spells: Array = section.get("spells", [])

	if spells.size() <= 0:
		return

	add_section_header(get_spell_icon(element_id) + " " + element_title)

	for spell_variant in spells:
		if not (spell_variant is Dictionary):
			continue

		var spell: Dictionary = spell_variant as Dictionary
		var line: String = get_spell_compact_line(spell, "Known")
		var subtitle: String = get_spell_equipped_subtitle(spell)

		if is_assigning_spell():
			add_action_row(line, {"kind": "assign_spell", "learned_index": int(spell.get("learned_index", -1))}, subtitle)
		else:
			add_compact_card(line, bool(spell.get("is_current", false)), subtitle)


func render_key_item_card(item: Dictionary) -> void:
	var item_name: String = str(item.get("name", item.get("id", "Key Item")))
	var item_kind: String = str(item.get("kind", "Key Item"))
	var item_source: String = str(item.get("source", "Unknown"))
	var description: String = str(item.get("description", "A key item Grace carries."))
	add_text_card(item_name, description, "🔑", item_kind + " · " + item_source)


func render_unlock_card(unlock: Dictionary) -> void:
	var unlock_id: String = str(unlock.get("id", "unlock"))
	var unlock_type: String = str(unlock.get("type", "unlock"))
	var display_name: String = str(unlock.get("display_name", unlock_id.capitalize()))
	var description: String = str(unlock.get("description", "A progression unlock."))
	var source: String = str(unlock.get("source", "Unknown"))
	add_text_card(display_name, description, get_unlock_icon(unlock), get_unlock_type_label(unlock_type) + " · " + source)


func render_weapon_card(weapon: Dictionary) -> void:
	var body: String = "Damage " + str(weapon.get("damage", 0))
	body += "  ·  Stance " + str(weapon.get("stance_damage", 0))
	body += "  ·  Scaling " + get_scaling_label(weapon.get("scaling_stats", []))
	add_text_card(str(weapon.get("name", "Weapon")), body, "⚔", str(weapon.get("class", "weapon")).capitalize())


func render_stat_section(section: Dictionary) -> void:
	var title: String = str(section.get("title", "Stats"))
	var stats: Array = section.get("stats", [])
	var lines: Array[String] = []

	for stat_variant in stats:
		if not (stat_variant is Dictionary):
			continue

		var stat: Dictionary = stat_variant as Dictionary
		var stat_name: String = str(stat.get("name", stat.get("id", "Stat")))
		var stat_value: String = str(stat.get("value", "0"))
		lines.append(stat_name + " " + stat_value)

	add_text_card(title, "  ·  ".join(lines), "◇", "Stats")


func get_spell_compact_line(spell: Dictionary, prefix: String = "Spell") -> String:
	if bool(spell.get("is_empty", false)):
		return prefix + "  ·  Empty"

	var element: String = str(spell.get("element", "neutral"))
	var parts: Array[String] = []
	parts.append(prefix)
	parts.append(get_spell_icon(element) + " " + str(spell.get("name", "Spell")))
	parts.append(get_spell_cost_label(spell))
	parts.append(get_short_list_label(spell.get("roles", []), 2, "role"))
	return "  ·  ".join(parts)


func get_spell_equipped_subtitle(spell: Dictionary) -> String:
	if bool(spell.get("is_equipped", false)):
		var slot_index: int = int(spell.get("equipped_slot", -1))
		if slot_index >= 0:
			return "Hotkey " + str(slot_index + 1)
		return "Equipped"

	return "Spellbook"


func get_spell_cost_label(spell: Dictionary) -> String:
	var costs: Array[String] = []
	var mana_cost: int = int(spell.get("mana_cost", 0))
	var stamina_cost: int = int(spell.get("stamina_cost", 0))
	var focus_cost: int = int(spell.get("focus_cost", 0))

	if mana_cost > 0:
		costs.append("M" + str(mana_cost))
	if stamina_cost > 0:
		costs.append("S" + str(stamina_cost))
	if focus_cost > 0:
		costs.append("F" + str(focus_cost))
	if costs.size() <= 0:
		return "Free"

	return "/".join(costs)


func get_scaling_label(values: Variant) -> String:
	if not (values is Array):
		return str(values)

	var array_values: Array = values as Array
	if array_values.size() <= 0:
		return "None"

	var labels: Array[String] = []
	for value in array_values:
		labels.append(abbreviate_stat_name(str(value)))

	return "/".join(labels)


func abbreviate_stat_name(value: String) -> String:
	match value.to_lower():
		"power":
			return "Pow"
		"dexterity":
			return "Dex"
		"arcana":
			return "Arc"
		"intelligence":
			return "Int"
		"defense":
			return "Def"
		"resilience":
			return "Res"
		"constitution":
			return "Con"
		"evasion":
			return "Eva"
		"focus":
			return "Foc"
		"charisma":
			return "Cha"
		"skill":
			return "Skl"
		"luck":
			return "Lck"
		"lightning":
			return "Lgt"
		"dreams", "dream":
			return "Drm"
		_:
			if value.length() <= 4:
				return value.capitalize()
			return value.substr(0, 4).capitalize()


func get_short_list_label(values: Variant, max_count: int = 2, fallback: String = "tag") -> String:
	if not (values is Array):
		return str(values)

	var array_values: Array = values as Array
	if array_values.size() <= 0:
		return "no " + fallback

	var labels: Array[String] = []
	var limit: int = min(max_count, array_values.size())

	for i: int in range(limit):
		labels.append(str(array_values[i]))

	if array_values.size() > max_count:
		labels.append("+" + str(array_values.size() - max_count))

	return "/".join(labels)


func get_key_item_rows_for_menu() -> Array:
	if GameState.has_method("get_key_item_rows"):
		return GameState.get_key_item_rows()
	return menu_data.get("key_items", [])


func get_unlock_rows_for_type(unlock_type: String) -> Array:
	if GameState.has_method("get_unlock_rows_by_type"):
		return GameState.get_unlock_rows_by_type(unlock_type)
	return []


func stat_pair(stat_name: String, max_stat_name: String) -> String:
	return str(GameState.get_stat(stat_name)) + "/" + str(GameState.get_stat(max_stat_name))


func get_spell_icon(element: String) -> String:
	match element.to_lower():
		"fire":
			return "🔥"
		"water":
			return "💧"
		"earth":
			return "🌿"
		"air":
			return "🌬"
		"ice":
			return "❄"
		"metal":
			return "⚙"
		"lightning":
			return "⚡"
		"poison":
			return "☠"
		"life":
			return "✚"
		"death":
			return "✖"
		"body":
			return "✊"
		"soul":
			return "☼"
		"dreams":
			return "☾"
		"sound":
			return "🔊"
		"space":
			return "◈"
		"time":
			return "⏳"
		_:
			return "✦"


func get_unlock_icon(unlock: Dictionary) -> String:
	var unlock_type: String = str(unlock.get("type", ""))
	var unlock_id: String = str(unlock.get("id", ""))

	if unlock_id.find("door") >= 0 or unlock_type == "permission":
		return "🚪"
	if unlock_type == "modifier" or unlock_id.find("blessing") >= 0:
		return "🛡"
	if unlock_type == "key_item":
		return "🔑"
	if unlock_type == "spell":
		return "✦"
	if unlock_type == "passive":
		return "★"
	return "◇"


func get_unlock_type_label(unlock_type: String) -> String:
	match unlock_type:
		"key_item":
			return "Key Item"
		"modifier":
			return "Blessing"
		"permission":
			return "Permission"
		"spell":
			return "Spell"
		"passive":
			return "Passive"
		_:
			return unlock_type.capitalize()


func get_item_assignment_label(item_id: String) -> String:
	var directions: Array[String] = []
	var slots: Array = menu_data.get("quick_item_slots", [])
	for slot_variant in slots:
		if not (slot_variant is Dictionary):
			continue
		var slot: Dictionary = slot_variant as Dictionary
		if str(slot.get("item_id", "")) == item_id:
			directions.append(str(slot.get("direction", "Slot")))
	if directions.is_empty():
		return ""
	return "Assigned: " + ", ".join(directions)


func get_footer_text() -> String:
	if is_assigning_equipment():
		return "D-pad/Stick or WASD: owned gear  •  A/Enter: equip  •  B/Esc: back"
	if is_assigning_spell():
		return "D-pad/Stick or W/S: spells  •  A/Enter: assign  •  B/Esc: back"
	if is_assigning_item():
		return "D-pad/Stick or WASD: items  •  A/Enter: assign  •  B/Esc: back"
	if is_assigning_item_slot():
		return "D-pad/Stick or WASD: choose direction  •  A/Enter: equip  •  B/Esc: back"

	return "LB/RB or Q/E: tabs  •  D-pad/Stick or WASD: move  •  A/Enter: choose  •  B/Esc: back"


func join_values(values: Variant) -> String:
	if not (values is Array):
		return str(values)

	var array_values: Array = values as Array
	if array_values.size() <= 0:
		return "none"

	var text_values: Array[String] = []
	for value in array_values:
		text_values.append(str(value))

	return " / ".join(text_values)


func get_ability_caster() -> Node:
	return find_first_node_named(get_tree().current_scene, "AbilityCaster")


func get_ability_loadout(ability_caster: Node) -> AbilityLoadout:
	if ability_caster == null:
		return null

	var loadout_variant: Variant = ability_caster.get("loadout")
	if not (loadout_variant is AbilityLoadout):
		return null

	return loadout_variant as AbilityLoadout


func get_learned_abilities(loadout: AbilityLoadout) -> Array:
	var abilities: Array = []

	if loadout == null:
		return abilities

	if loadout.has_method("get_learned_abilities"):
		var learned_variant: Variant = loadout.call("get_learned_abilities")

		if learned_variant is Array:
			for ability_variant in learned_variant:
				if ability_variant is AbilityDefinition:
					abilities.append(ability_variant as AbilityDefinition)

		return abilities

	for ability: AbilityDefinition in loadout.learned_abilities:
		if ability != null and not abilities.has(ability):
			abilities.append(ability)

	if abilities.size() <= 0:
		for ability: AbilityDefinition in loadout.equipped_abilities:
			if ability != null and not abilities.has(ability):
				abilities.append(ability)

	return abilities


func find_first_node_named(root: Node, node_name: String) -> Node:
	if root == null:
		return null

	if root.name == node_name:
		return root

	for child: Node in root.get_children():
		var found: Node = find_first_node_named(child, node_name)

		if found != null:
			return found

	return null


func clear_children(parent: Node) -> void:
	if parent == null:
		return

	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func make_panel_style(background_color: Color, border_color: Color, border_width: int = 1, corner_radius: int = 10) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner_radius)
	return style
