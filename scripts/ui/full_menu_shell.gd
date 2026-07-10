extends PanelContainer
class_name FullMenuShell

const ComboRuleRegistryScript = preload("res://scripts/systems/combo_rule_registry.gd")

const TAB_DEFS = [
	{"id": "equipment", "title": "Equipment", "icon": "✦"},
	{"id": "spellbook", "title": "Spellbook", "icon": "✧"},
	{"id": "inventory", "title": "Inventory", "icon": "▣"},
	{"id": "stats", "title": "Stats", "icon": "◇"},
	{"id": "journal", "title": "Journal", "icon": "?"},
	{"id": "codex", "title": "Codex", "icon": "#"},
	{"id": "system", "title": "System", "icon": "⚙"},
]

const PANEL_BACKGROUND: Color = Color(0.025, 0.032, 0.045, 0.92)
const PANEL_BORDER: Color = Color(0.58, 0.66, 0.9, 0.72)
const SIDE_BACKGROUND: Color = Color(0.04, 0.052, 0.073, 0.86)
const CARD_BACKGROUND: Color = Color(0.07, 0.085, 0.115, 0.72)
const CARD_SELECTED_BACKGROUND: Color = Color(0.12, 0.09, 0.22, 0.82)
const CARD_BORDER: Color = Color(0.28, 0.34, 0.5, 0.5)
const CARD_SELECTED_BORDER: Color = Color(0.72, 0.48, 1.0, 0.95)
const TEXT_MAIN: Color = Color(0.93, 0.96, 1.0, 0.98)
const TEXT_SOFT: Color = Color(0.64, 0.72, 0.84, 0.86)
const TEXT_DIM: Color = Color(0.48, 0.56, 0.68, 0.72)

var selected_tab_index: int = 0
var selected_action_index: int = 0
var menu_data: Dictionary = {}
var selectable_actions: Array = []

var assignment_mode: String = ""
var pending_spell_slot_index: int = -1

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
		if is_assigning_spell():
			cancel_assignment()
			return true
		return false

	if event.is_action_pressed("ui_up"):
		select_action(selected_action_index - 1)
		return true

	if event.is_action_pressed("ui_down"):
		select_action(selected_action_index + 1)
		return true

	if event.is_action_pressed("ui_accept"):
		activate_selected_action()
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
				return true
			KEY_2:
				select_tab(1)
				return true
			KEY_3:
				select_tab(2)
				return true
			KEY_4:
				select_tab(3)
				return true
			KEY_5:
				select_tab(4)
				return true
			KEY_6:
				select_tab(5)
				return true
			KEY_7:
				select_tab(6)
				return true
			KEY_W, KEY_UP:
				select_action(selected_action_index - 1)
				return true
			KEY_S, KEY_DOWN:
				select_action(selected_action_index + 1)
				return true
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				activate_selected_action()
				return true
			KEY_A, KEY_Q, KEY_LEFT:
				select_tab(selected_tab_index - 1)
				return true
			KEY_D, KEY_E, KEY_RIGHT:
				select_tab(selected_tab_index + 1)
				return true
			_:
				return true

	if event is InputEventMouseButton:
		return true

	if event is InputEventMouseMotion:
		return true

	return true


func select_tab(index: int) -> void:
	selected_tab_index = (index + TAB_DEFS.size()) % TAB_DEFS.size()
	selected_action_index = 0
	rebuild_menu()


func select_action(index: int) -> void:
	if selectable_actions.size() <= 0:
		selected_action_index = 0
		return

	selected_action_index = (index + selectable_actions.size()) % selectable_actions.size()
	rebuild_menu()


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
		_:
			return


func start_spell_assignment(slot_index: int) -> void:
	if slot_index < 0:
		return

	assignment_mode = "spell"
	pending_spell_slot_index = slot_index
	selected_tab_index = get_tab_index("spellbook")
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
	loadout.equip_ability(assigned_slot, ability)

	if ability_caster != null and ability_caster.has_method("select_ability"):
		ability_caster.call("select_ability", assigned_slot, true)

	assignment_mode = ""
	pending_spell_slot_index = -1
	selected_tab_index = get_tab_index("equipment")
	selected_action_index = assigned_slot
	refresh_menu_data()
	rebuild_menu()


func cancel_assignment(should_rebuild: bool = true) -> void:
	assignment_mode = ""
	pending_spell_slot_index = -1

	if should_rebuild:
		rebuild_menu()


func is_assigning_spell() -> bool:
	return assignment_mode == "spell" and pending_spell_slot_index >= 0


func refresh_menu_data() -> void:
	var director: Node = get_node_or_null("/root/FullMenuDirector")

	if director == null:
		return

	if not director.has_method("build_menu_data"):
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
	title_label.text = "Grace Menu"
	title_label.add_theme_color_override("font_color", TEXT_MAIN)
	title_label.add_theme_font_size_override("font_size", 24)
	header_text_box.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.text = "Equipment, spellbook, inventory, stats, journals, codex, and future augments."
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
	content_panel.add_theme_stylebox_override("panel", make_panel_style(Color(0.04, 0.05, 0.068, 0.72), CARD_BORDER, 1, 14))
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
	content_title_label.text = "Equipment"
	content_title_label.add_theme_color_override("font_color", TEXT_MAIN)
	content_title_label.add_theme_font_size_override("font_size", 20)
	content_root.add_child(content_title_label)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_root.add_child(scroll)

	content_box = VBoxContainer.new()
	content_box.add_theme_constant_override("separation", 6)
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
		tab_button.text = str(tab_def.get("icon", "")) + "  " + str(tab_def.get("title", "Tab"))
		tab_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tab_button.custom_minimum_size = Vector2(0.0, 44.0)
		tab_button.add_theme_font_size_override("font_size", 15)
		tab_button.add_theme_color_override("font_color", TEXT_MAIN if is_selected else TEXT_SOFT)
		tab_button.add_theme_stylebox_override(
			"normal",
			make_panel_style(CARD_SELECTED_BACKGROUND if is_selected else Color(0.06, 0.072, 0.095, 0.6), CARD_SELECTED_BORDER if is_selected else CARD_BORDER, 2 if is_selected else 1, 10)
		)
		tab_button.add_theme_stylebox_override(
			"hover",
			make_panel_style(Color(0.11, 0.1, 0.17, 0.76), CARD_SELECTED_BORDER, 2, 10)
		)
		tab_button.pressed.connect(_on_tab_pressed.bind(i))
		tab_box.add_child(tab_button)


func _on_tab_pressed(index: int) -> void:
	select_tab(index)


func rebuild_content() -> void:
	selectable_actions.clear()
	clear_children(content_box)

	var tab_def: Dictionary = TAB_DEFS[selected_tab_index]
	var tab_id: String = str(tab_def.get("id", "equipment"))
	content_title_label.text = str(tab_def.get("title", "Equipment"))

	match tab_id:
		"equipment":
			render_equipment()
		"spellbook":
			render_spellbook()
		"inventory":
			render_inventory()
		"stats":
			render_stats()
		"journal":
			render_journal()
		"codex":
			render_codex()
		"system":
			render_system()
		_:
			add_text_card("Coming Soon", "This tab is only a placeholder right now.")

	if selectable_actions.size() <= 0:
		selected_action_index = 0
	else:
		selected_action_index = clamp(selected_action_index, 0, selectable_actions.size() - 1)


func render_equipment() -> void:
	var summary: Dictionary = menu_data.get("loadout_summary", {})
	var summary_lines: Array[String] = []
	summary_lines.append("Spell hotkeys: " + str(summary.get("quick_slots", 0)))
	summary_lines.append("Known spells: " + str(summary.get("learned_count", 0)))
	summary_lines.append("Prototype ring: " + str(summary.get("active_ring_count", 0)))
	add_text_card("Ready Equipment", "The belt: weapon, spell hotkeys, item hotkeys, and gadget slots. " + "  |  ".join(summary_lines))

	var weapon: Dictionary = menu_data.get("weapon", {})

	if not weapon.is_empty():
		render_weapon_card(weapon)
	else:
		add_compact_card("Weapon  ·  Empty", false, "Weapon")

	var equipped_slots: Array = menu_data.get("equipped_spell_slots", [])

	if equipped_slots.size() <= 0:
		add_text_card("Spell Hotkeys", "No spell hotkey slots found yet.")
	else:
		add_text_card("Spell Hotkeys", "Select a spell hotkey, then choose a learned spell from the Spellbook.")

		for slot_variant in equipped_slots:
			if slot_variant is Dictionary:
				render_equipped_slot_card(slot_variant as Dictionary)

	render_item_hotkey_placeholders()
	render_gadget_slot_placeholders()


func render_spellbook() -> void:
	if is_assigning_spell():
		add_text_card("Assign Spell", "Choose a learned spell for Spell Hotkey " + str(pending_spell_slot_index + 1) + ". Enter or click assigns it. Esc cancels.")
	else:
		add_text_card("Spellbook", "Known spells grouped by element. Select a hotkey in Equipment first to assign from here.")

	var library_sections: Array = menu_data.get("learned_spell_sections", [])

	if library_sections.size() <= 0:
		add_text_card("No learned spells found", "The menu could not find learned spell data yet.")
		return

	for section_variant in library_sections:
		if section_variant is Dictionary:
			render_library_section(section_variant as Dictionary)


func render_inventory() -> void:
	add_text_card("Inventory", "The bag: items, potions, crafting materials, quest objects, and usable tools. Equipment decides what gets hotkeyed.")
	add_compact_card("Item Source  ·  choose item later  ·  assign to Equipment hotkey", false, "Items")
	add_compact_card("Consumables  ·  no item database yet  ·  potions / food / bombs / remedies", false, "Items")
	add_compact_card("Materials  ·  no material database yet  ·  ores / herbs / monster parts / relic scraps", false, "Materials")
	add_compact_card("Key Items  ·  no key-item database yet  ·  story objects / dungeon tools", false, "Key Items")


func render_item_hotkey_placeholders() -> void:
	add_compact_card("Item Hotkeys  ·  1 Empty  ·  2 Empty  ·  3 Empty  ·  4 Empty", false, "Items")


func render_gadget_slot_placeholders() -> void:
	add_compact_card("Tools  ·  Gadget Empty  ·  Vehicle/Tool Empty  ·  Summon Empty", false, "Tools")


func render_equipped_slot_card(spell: Dictionary) -> void:
	var slot_index: int = int(spell.get("slot", 0))
	var line: String = ""

	if bool(spell.get("is_empty", false)):
		line = "Spell Hotkey " + str(slot_index + 1) + "  ·  Empty  ·  choose to assign"
	else:
		line = get_spell_compact_line(spell, "Spell Hotkey " + str(slot_index + 1))

	add_action_row(line, {"kind": "choose_spell_slot", "slot": slot_index}, "Hotkey")


func render_spell_card(spell: Dictionary) -> void:
	add_compact_card(get_spell_compact_line(spell, "Slot " + str(int(spell.get("slot", 0)) + 1)), bool(spell.get("is_current", false)), "Spell")


func render_library_section(section: Dictionary) -> void:
	var element_title: String = str(section.get("title", "Element"))
	var spells: Array = section.get("spells", [])

	if spells.size() <= 0:
		add_compact_card(element_title + "  ·  No learned spells yet", false, "Spellbook")
		return

	add_section_header(element_title + " Spells")

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


func get_spell_compact_line(spell: Dictionary, prefix: String = "Spell") -> String:
	var parts: Array[String] = []
	parts.append(prefix)
	parts.append(str(spell.get("name", "Spell")))
	parts.append(get_spell_element_label(spell))
	parts.append(get_spell_cost_label(spell))
	parts.append(get_scaling_label(spell.get("scaling_stats", [])))
	parts.append(get_short_list_label(spell.get("roles", []), 2, "role"))
	return "  ·  ".join(parts)


func get_spell_equipped_subtitle(spell: Dictionary) -> String:
	if bool(spell.get("is_equipped", false)):
		var slot_index: int = int(spell.get("equipped_slot", -1))
		if slot_index >= 0:
			return "Hotkey " + str(slot_index + 1)
		return "Equipped"

	return "Spellbook"


func get_spell_element_label(spell: Dictionary) -> String:
	var element: String = str(spell.get("element", "neutral"))
	if element == "":
		return "Neutral"
	return element.capitalize()


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
		return "No scaling"

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
		"darkness":
			return "Dark"
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


func render_weapon_card(weapon: Dictionary) -> void:
	var line: String = "Weapon"
	line += "  ·  " + str(weapon.get("name", "Weapon"))
	line += "  ·  " + str(weapon.get("class", "unknown")).capitalize()
	line += "  ·  dmg " + str(weapon.get("damage", 0)) + " / stance " + str(weapon.get("stance_damage", 0))
	line += "  ·  " + get_scaling_label(weapon.get("scaling_stats", []))
	add_compact_card(line, false, "Weapon")


func render_stats() -> void:
	add_text_card("Base Stats", "Grace's current spread and elemental affinity hooks. Formulas, leveling, and equipment scaling can attach later.")

	var sections: Array = menu_data.get("stat_sections", [])

	if sections.size() <= 0:
		add_text_card("No stat sections found", "GameState did not provide stat section data yet.")
		return

	for section_variant in sections:
		if section_variant is Dictionary:
			render_stat_section(section_variant as Dictionary)


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
		lines.append(stat_name + ": " + stat_value)

	add_text_card(title, "  |  ".join(lines))


func render_journal() -> void:
	var objective: String = str(menu_data.get("objective", "Look around."))
	add_text_card("Current Objective", objective)
	add_text_card("Main Quest", "Find someone who can help Grace understand where she has landed.")
	add_text_card("Clues", "Placeholder list. Later this can track signs, lore fragments, puzzle notes, and character leads.")
	add_text_card("Quest Structure", "Main quests, side quests, clues, and completed objectives will live here.")


func render_codex() -> void:
	add_text_card("Reaction Codex", "Data rows from ComboRuleRegistry. This is the first in-game window into the magic grammar.")

	var rows: Array = ComboRuleRegistryScript.get_debug_matrix_rows()

	for row_variant in rows:
		if not (row_variant is Dictionary):
			continue

		var row: Dictionary = row_variant as Dictionary
		var line: String = str(row.get("reaction", "reaction"))
		line += "  ·  in " + join_values(row.get("incoming", []))
		line += "  ·  target " + join_values(row.get("target_tags", []))
		line += "  ·  status " + join_values(row.get("target_statuses", []))
		add_compact_card(line, false, "Reaction")


func render_system() -> void:
	add_text_card("Controls", "Tab / M: open or close menu\nEsc: cancel assignment or close menu\nA/D or left/right: switch tabs\nW/S or up/down: move row selection\nEnter/click: choose row\n1-7: jump tabs")
	add_text_card("Future Panels", "Settings, save/load, controller mapping, accessibility, and debug toggles can attach here.")
	add_text_card("Prototype Note", "Equipment spell hotkeys can now be assigned from the Spellbook. Items, weapons, and gadgets are still display-only.")


func add_section_header(title: String) -> void:
	var header: Label = Label.new()
	header.text = title
	header.add_theme_color_override("font_color", TEXT_MAIN)
	header.add_theme_font_size_override("font_size", 15)
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_box.add_child(header)


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
		var subtitle_label: Label = Label.new()
		subtitle_label.text = subtitle
		subtitle_label.custom_minimum_size = Vector2(84.0, 0.0)
		subtitle_label.add_theme_color_override("font_color", TEXT_DIM)
		subtitle_label.add_theme_font_size_override("font_size", 11)
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
	button.text = (subtitle + "  ·  " if subtitle != "" else "") + line
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0.0, 32.0)
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", TEXT_MAIN if is_selected else TEXT_SOFT)
	button.add_theme_stylebox_override(
		"normal",
		make_panel_style(CARD_SELECTED_BACKGROUND if is_selected else CARD_BACKGROUND, CARD_SELECTED_BORDER if is_selected else CARD_BORDER, 2 if is_selected else 1, 10)
	)
	button.add_theme_stylebox_override(
		"hover",
		make_panel_style(Color(0.11, 0.1, 0.17, 0.76), CARD_SELECTED_BORDER, 2, 10)
	)
	button.add_theme_stylebox_override(
		"pressed",
		make_panel_style(CARD_SELECTED_BACKGROUND, CARD_SELECTED_BORDER, 2, 10)
	)
	button.pressed.connect(_on_action_row_pressed.bind(action_index))
	content_box.add_child(button)


func _on_action_row_pressed(action_index: int) -> void:
	if action_index < 0 or action_index >= selectable_actions.size():
		return

	selected_action_index = action_index
	activate_action(selectable_actions[action_index])


func add_text_card(title: String, body: String, selected: bool = false, subtitle: String = "") -> void:
	var card: PanelContainer = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override(
		"panel",
		make_panel_style(CARD_SELECTED_BACKGROUND if selected else CARD_BACKGROUND, CARD_SELECTED_BORDER if selected else CARD_BORDER, 2 if selected else 1, 12)
	)
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

	var header: Label = Label.new()
	header.text = title
	header.add_theme_color_override("font_color", TEXT_MAIN)
	header.add_theme_font_size_override("font_size", 16)
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(header)

	if subtitle != "":
		var subtitle_label: Label = Label.new()
		subtitle_label.text = subtitle
		subtitle_label.add_theme_color_override("font_color", TEXT_DIM)
		subtitle_label.add_theme_font_size_override("font_size", 11)
		box.add_child(subtitle_label)

	if body != "":
		var body_label: Label = Label.new()
		body_label.text = body
		body_label.add_theme_color_override("font_color", TEXT_SOFT)
		body_label.add_theme_font_size_override("font_size", 12)
		body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(body_label)


func get_footer_text() -> String:
	if is_assigning_spell():
		return "Assigning Spell Hotkey " + str(pending_spell_slot_index + 1) + "   W/S or ↑/↓: spell rows   Enter/click: assign   Esc: cancel"

	return "A/D or ←/→: tabs   W/S or ↑/↓: rows   Enter/click: choose   1-7: jump tabs"


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
