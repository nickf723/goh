extends PanelContainer

const ComboRuleRegistryScript = preload("res://scripts/systems/combo_rule_registry.gd")

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

var title_label: Label
var subtitle_label: Label
var tab_box: VBoxContainer
var content_title_label: Label
var content_box: VBoxContainer
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
		if is_assigning_spell() or is_assigning_item():
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
			JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT:
				return true
			_:
				pass

	if event.is_action_pressed("ui_up"):
		select_action(selected_action_index - 1)
		return true

	if event.is_action_pressed("ui_down"):
		select_action(selected_action_index + 1)
		return true

	if event.is_action_pressed("ui_accept"):
		activate_selected_action()
		return true

	if event is InputEventJoypadMotion:
		var joy_motion: InputEventJoypadMotion = event as InputEventJoypadMotion
		if joy_motion.axis == JOY_AXIS_LEFT_X or joy_motion.axis == JOY_AXIS_RIGHT_X:
			return true

	if event.is_action_pressed("ui_left"):
		select_tab(selected_tab_index - 1)
		return true

	if event.is_action_pressed("ui_right"):
		select_tab(selected_tab_index + 1)
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
			KEY_W, KEY_UP:
				select_action(selected_action_index - 1)
			KEY_S, KEY_DOWN:
				select_action(selected_action_index + 1)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				activate_selected_action()
			KEY_A, KEY_Q, KEY_LEFT:
				select_tab(selected_tab_index - 1)
			KEY_D, KEY_E, KEY_RIGHT:
				select_tab(selected_tab_index + 1)
			_:
				pass
		return true

	if event is InputEventMouseButton:
		return true

	if event is InputEventMouseMotion:
		return true

	return true


func select_tab(index: int) -> void:
	if is_assigning_spell() or is_assigning_item():
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
		_:
			return


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


func cancel_assignment(should_rebuild: bool = true) -> void:
	var was_assigning: bool = is_assigning_spell() or is_assigning_item()
	var return_action_index: int = pending_spell_return_action_index if is_assigning_spell() else pending_item_return_action_index
	assignment_mode = ""
	pending_spell_slot_index = -1
	pending_item_slot_index = -1
	pending_spell_return_action_index = -1
	pending_item_return_action_index = -1

	if was_assigning:
		selected_tab_index = get_tab_index("loadout")
		selected_action_index = max(return_action_index, 0)
		tab_action_memory["loadout"] = selected_action_index

	if should_rebuild:
		rebuild_menu()


func is_assigning_spell() -> bool:
	return assignment_mode == "spell" and pending_spell_slot_index >= 0


func is_assigning_item() -> bool:
	return assignment_mode == "item" and pending_item_slot_index >= 0


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
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var root_box: VBoxContainer = VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 12)
	margin.add_child(root_box)

	var header_box: HBoxContainer = HBoxContainer.new()
	header_box.add_theme_constant_override("separation", 12)
	root_box.add_child(header_box)

	var header_text_box: VBoxContainer = VBoxContainer.new()
	header_text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_box.add_child(header_text_box)

	title_label = Label.new()
	title_label.text = "Grace Field Kit"
	title_label.add_theme_color_override("font_color", TEXT_MAIN)
	title_label.add_theme_font_size_override("font_size", 24)
	header_text_box.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.text = "Loadout, magic, relics, growth, notes, and rules."
	subtitle_label.add_theme_color_override("font_color", TEXT_SOFT)
	subtitle_label.add_theme_font_size_override("font_size", 12)
	header_text_box.add_child(subtitle_label)

	var close_label: Label = Label.new()
	close_label.text = "Tab / M / Esc: close"
	close_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	close_label.add_theme_color_override("font_color", TEXT_DIM)
	close_label.add_theme_font_size_override("font_size", 12)
	header_box.add_child(close_label)

	var body_box: HBoxContainer = HBoxContainer.new()
	body_box.add_theme_constant_override("separation", 14)
	body_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(body_box)

	var side_panel: PanelContainer = PanelContainer.new()
	side_panel.custom_minimum_size = Vector2(190.0, 0.0)
	side_panel.add_theme_stylebox_override("panel", make_panel_style(SIDE_BACKGROUND, CARD_BORDER, 1, 14))
	body_box.add_child(side_panel)

	var side_margin: MarginContainer = MarginContainer.new()
	side_margin.add_theme_constant_override("margin_left", 9)
	side_margin.add_theme_constant_override("margin_top", 9)
	side_margin.add_theme_constant_override("margin_right", 9)
	side_margin.add_theme_constant_override("margin_bottom", 9)
	side_panel.add_child(side_margin)

	tab_box = VBoxContainer.new()
	tab_box.add_theme_constant_override("separation", 8)
	side_margin.add_child(tab_box)

	var content_panel: PanelContainer = PanelContainer.new()
	content_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_panel.add_theme_stylebox_override("panel", make_panel_style(Color(0.04, 0.05, 0.068, 0.74), CARD_BORDER, 1, 14))
	body_box.add_child(content_panel)

	var content_margin: MarginContainer = MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 13)
	content_margin.add_theme_constant_override("margin_top", 12)
	content_margin.add_theme_constant_override("margin_right", 13)
	content_margin.add_theme_constant_override("margin_bottom", 12)
	content_panel.add_child(content_margin)

	var content_root: VBoxContainer = VBoxContainer.new()
	content_root.add_theme_constant_override("separation", 10)
	content_margin.add_child(content_root)

	content_title_label = Label.new()
	content_title_label.text = "Loadout"
	content_title_label.add_theme_color_override("font_color", TEXT_MAIN)
	content_title_label.add_theme_font_size_override("font_size", 20)
	content_root.add_child(content_title_label)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_root.add_child(scroll)

	content_box = VBoxContainer.new()
	content_box.add_theme_constant_override("separation", 7)
	content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content_box)

	footer_label = Label.new()
	footer_label.text = get_footer_text()
	footer_label.add_theme_color_override("font_color", TEXT_DIM)
	footer_label.add_theme_font_size_override("font_size", 11)
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
		tab_button.text = ("▶  " if is_selected else "    ") + str(tab_def.get("icon", "")) + "  " + str(tab_def.get("title", "Tab"))
		tab_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tab_button.custom_minimum_size = Vector2(0.0, 42.0)
		tab_button.add_theme_font_size_override("font_size", 15)
		tab_button.add_theme_color_override("font_color", TEXT_MAIN if is_selected else TEXT_SOFT)
		tab_button.add_theme_stylebox_override(
			"normal",
			make_panel_style(ACTIVE_SELECTION_BACKGROUND if is_selected else Color(0.06, 0.072, 0.095, 0.62), ACTIVE_SELECTION_BORDER if is_selected else CARD_BORDER, 3 if is_selected else 1, 10)
		)
		tab_button.add_theme_stylebox_override("hover", make_panel_style(Color(0.11, 0.1, 0.17, 0.78), CARD_SELECTED_BORDER, 2, 10))
		tab_button.pressed.connect(_on_tab_pressed.bind(i))
		tab_box.add_child(tab_button)


func _on_tab_pressed(index: int) -> void:
	select_tab(index)


func rebuild_content() -> void:
	selectable_actions.clear()
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
	var summary: Dictionary = menu_data.get("loadout_summary", {})
	add_summary_card([
		"Spell slots " + str(summary.get("quick_slots", 0)),
		"Known " + str(summary.get("learned_count", 0)),
		"Active " + str(summary.get("active_ring_count", 0)),
	])

	var weapon: Dictionary = menu_data.get("weapon", {})
	if not weapon.is_empty():
		render_weapon_card(weapon)
	else:
		add_text_card("Weapon", "No weapon equipped yet.", "⚔", "Empty")

	add_section_header("Spell Hotkeys")
	var equipped_slots: Array = menu_data.get("equipped_spell_slots", [])

	if equipped_slots.size() <= 0:
		add_text_card("No spell slots found", "The loadout could not find Grace's spell belt.", "✦", "Hotkeys")
	else:
		for slot_variant in equipped_slots:
			if slot_variant is Dictionary:
				render_equipped_slot_card(slot_variant as Dictionary)

	add_section_header("Quick Items")
	var item_slots: Array = menu_data.get("quick_item_slots", [])
	if item_slots.size() <= 0:
		add_text_card("No item belt found", "The Field Kit could not find Grace's quick-item controller.", "🧪", "Unavailable")
	else:
		for slot_variant in item_slots:
			if slot_variant is Dictionary:
				render_quick_item_slot_card(slot_variant as Dictionary)
	add_compact_card("🛠 Gadgets  ·  vehicle / summon / device slots later", false, "Future")


func render_items() -> void:
	var inventory_rows: Array = menu_data.get("inventory_items", [])
	var total_count: int = 0
	for row_variant in inventory_rows:
		if row_variant is Dictionary:
			total_count += int((row_variant as Dictionary).get("count", 0))

	if is_assigning_item():
		var directions: Array[String] = ["Up", "Left", "Right", "Down"]
		add_text_card("Assign Quick Item", "Choose an owned item for D-pad " + directions[pending_item_slot_index] + ".", "🧪", "A / Enter assigns")
	else:
		add_summary_card(["Types " + str(inventory_rows.size()), "Carried " + str(total_count), "D-pad ready"])

	if inventory_rows.size() <= 0:
		add_text_card("No usable items", "Explore containers, enemies, and hidden supply caches.", "🧪", "Empty")
		if is_assigning_item():
			add_action_row("Clear this quick slot", {"kind": "assign_item", "item_id": ""}, "Empty")
		return

	for row_variant in inventory_rows:
		if not (row_variant is Dictionary):
			continue
		var row: Dictionary = row_variant as Dictionary
		var item_id: String = str(row.get("id", ""))
		var count: int = int(row.get("count", 0))
		var title: String = str(row.get("icon", "◇")) + " " + str(row.get("name", item_id.capitalize()))
		var line: String = title + "  ×" + str(count) + "  ·  " + str(row.get("description", ""))
		var subtitle: String = "Refills at rest" if bool(row.get("refill_on_rest", false)) else "Consumable"
		var assigned_label: String = get_item_assignment_label(item_id)
		if assigned_label != "":
			subtitle += "  ·  " + assigned_label
		if is_assigning_item():
			add_action_row(line, {"kind": "assign_item", "item_id": item_id}, subtitle)
		else:
			add_compact_card(line, false, subtitle)

	if is_assigning_item():
		add_section_header("Slot Options")
		add_action_row("Clear this quick slot", {"kind": "assign_item", "item_id": ""}, "Empty")



func render_magic() -> void:
	if is_assigning_spell():
		add_text_card("Assign Spell", "Choose a learned spell for Hotkey " + str(pending_spell_slot_index + 1) + ".", "✦", "Enter assigns")
	else:
		add_summary_card(["Elements 16", "Assign from Loadout", "Focus ring ready"])

	var library_sections: Array = menu_data.get("learned_spell_sections", [])

	if library_sections.size() <= 0:
		add_text_card("No learned spells found", "The menu could not find learned spell data yet.", "✦", "Magic")
		return

	for section_variant in library_sections:
		if section_variant is Dictionary:
			render_library_section(section_variant as Dictionary)


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
		button.call_deferred("grab_focus")


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
	if is_assigning_spell():
		return "D-pad/Stick or W/S: spells  •  A/Enter: assign  •  B/Esc: back"
	if is_assigning_item():
		return "D-pad/Stick or W/S: items  •  A/Enter: assign  •  B/Esc: back"

	return "LB/RB or Q/E: tabs  •  D-pad/Stick or W/S: rows  •  A/Enter: choose  •  B/Esc: close"


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
