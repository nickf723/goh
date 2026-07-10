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
var menu_data: Dictionary = {}

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


func is_open() -> bool:
	return visible


func handle_menu_input(event: InputEvent) -> bool:
	if not visible:
		return false

	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
		select_tab(selected_tab_index - 1)
		return true

	if event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
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
			KEY_A, KEY_Q:
				select_tab(selected_tab_index - 1)
				return true
			KEY_D, KEY_E:
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
	rebuild_menu()


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
	content_box.add_theme_constant_override("separation", 8)
	content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content_box)

	footer_label = Label.new()
	footer_label.text = "A/D or ←/→: tabs   1-7: jump tabs"
	footer_label.add_theme_color_override("font_color", TEXT_DIM)
	footer_label.add_theme_font_size_override("font_size", 11)
	root_box.add_child(footer_label)


func rebuild_menu() -> void:
	rebuild_tabs()
	rebuild_content()


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


func render_equipment() -> void:
	var summary: Dictionary = menu_data.get("loadout_summary", {})
	var summary_lines: Array[String] = []
	summary_lines.append("Spell hotkey slots: " + str(summary.get("quick_slots", 0)))
	summary_lines.append("Known spells in Spellbook: " + str(summary.get("learned_count", 0)))
	summary_lines.append("Active prototype ring: " + str(summary.get("active_ring_count", 0)))
	add_text_card(
		"Ready Equipment",
		"This tab is the belt: weapons, spell hotkeys, item hotkeys, and gadget slots. The Spellbook and Inventory are separate source menus now.\n" + "\n".join(summary_lines)
	)

	var weapon: Dictionary = menu_data.get("weapon", {})

	if not weapon.is_empty():
		render_weapon_card(weapon)
	else:
		add_text_card("Weapon Slot", "No equipped weapon found yet.", false, "Weapon")

	var equipped_slots: Array = menu_data.get("equipped_spell_slots", [])

	if equipped_slots.size() <= 0:
		add_text_card("Spell Hotkeys", "No spell hotkey slots found yet.")
	else:
		add_text_card("Spell Hotkeys", "Future flow: click a hotkey slot, then choose a learned spell from the Spellbook. For now these are display-only shelves.")

		for slot_variant in equipped_slots:
			if slot_variant is Dictionary:
				render_equipped_slot_card(slot_variant as Dictionary)

	render_item_hotkey_placeholders()
	render_gadget_slot_placeholders()


func render_spellbook() -> void:
	add_text_card(
		"Spellbook",
		"This is what Grace knows, not what she has equipped. Later, choosing a spell here can assign it to a spell hotkey or inspect augments."
	)

	var library_sections: Array = menu_data.get("learned_spell_sections", [])

	if library_sections.size() <= 0:
		add_text_card("No learned spells found", "The menu could not find learned spell data yet.")
		return

	for section_variant in library_sections:
		if section_variant is Dictionary:
			render_library_section(section_variant as Dictionary)


func render_inventory() -> void:
	add_text_card(
		"Inventory",
		"This will be the bag: items, potions, crafting materials, quest objects, and usable tools. Equipment decides what gets hotkeyed."
	)
	add_text_card("Item Hotkey Source", "Later flow: pick an item here, then assign it to an item hotkey in Equipment.")
	add_text_card("Consumables", "No item database yet. Potions, food, bombs, remedies, and other use-items will live here.")
	add_text_card("Materials", "No crafting material database yet. Ores, herbs, monster parts, and relic scraps will live here.")
	add_text_card("Key Items", "No key-item database yet. Story objects and dungeon tools will live here.")


func render_item_hotkey_placeholders() -> void:
	add_text_card("Item Hotkeys", "Slot 1: Empty\nSlot 2: Empty\nSlot 3: Empty\nSlot 4: Empty", false, "Items")


func render_gadget_slot_placeholders() -> void:
	add_text_card("Gadget Slots", "Gadget slot: Empty\nVehicle/tool slot: Empty\nSummon slot: Empty", false, "Tools")


func render_equipped_slot_card(spell: Dictionary) -> void:
	var slot_index: int = int(spell.get("slot", 0))
	var title: String = "Spell Hotkey " + str(slot_index + 1) + ": " + str(spell.get("name", "Empty Slot"))

	if bool(spell.get("is_empty", false)):
		add_text_card(title, "Empty combat slot. Later, learned spells can be assigned here.", false, "Empty")
		return

	add_text_card(title, "\n".join(get_spell_detail_lines(spell, true)), bool(spell.get("is_current", false)), get_spell_subtitle(spell))


func render_spell_card(spell: Dictionary) -> void:
	var slot_index: int = int(spell.get("slot", 0))
	var title: String = "Slot " + str(slot_index + 1) + ": " + str(spell.get("name", "Empty Slot"))
	add_text_card(title, "\n".join(get_spell_detail_lines(spell, true)), bool(spell.get("is_current", false)), get_spell_subtitle(spell))


func get_spell_subtitle(spell: Dictionary) -> String:
	var subtitle: String = str(spell.get("element", "neutral")).capitalize()
	subtitle += " | " + str(spell.get("delivery", "delivery"))
	subtitle += " | " + str(spell.get("targeting", "targeting"))
	return subtitle


func get_spell_detail_lines(spell: Dictionary, include_notes: bool = false) -> Array[String]:
	var lines: Array[String] = []
	var description: String = str(spell.get("description", ""))

	if description != "":
		lines.append(description)

	lines.append("Profile: " + str(spell.get("profile", "none")))
	lines.append("Cost: mana " + str(spell.get("mana_cost", 0)) + " / stamina " + str(spell.get("stamina_cost", 0)) + " / focus " + str(spell.get("focus_cost", 0)))
	lines.append("Scaling: " + join_values(spell.get("scaling_stats", [])))
	lines.append("Roles: " + join_values(spell.get("roles", [])))
	lines.append("Combos: " + join_values(spell.get("combo_tags", [])))
	lines.append("Status: " + join_values(spell.get("status_tags", [])))

	var scaling_note: String = str(spell.get("scaling_note", ""))
	if scaling_note != "":
		lines.append("Scaling note: " + scaling_note)

	if include_notes:
		var notes: String = str(spell.get("notes", ""))
		if notes != "":
			lines.append("Notes: " + notes)

	return lines


func render_library_section(section: Dictionary) -> void:
	var element_title: String = str(section.get("title", "Element"))
	var spells: Array = section.get("spells", [])
	var lines: Array[String] = []

	if spells.size() <= 0:
		lines.append("No learned spells yet.")
	else:
		for spell_variant in spells:
			if spell_variant is Dictionary:
				lines.append(get_library_spell_line(spell_variant as Dictionary))

	add_text_card(element_title + " Spells", "\n".join(lines), false, "Spellbook")


func get_library_spell_line(spell: Dictionary) -> String:
	var equipped_suffix: String = ""

	if bool(spell.get("is_equipped", false)):
		var slot_index: int = int(spell.get("equipped_slot", -1))
		if slot_index >= 0:
			equipped_suffix = " [hotkey " + str(slot_index + 1) + "]"
		else:
			equipped_suffix = " [equipped]"

	return (
		str(spell.get("name", "Spell"))
		+ equipped_suffix
		+ " | "
		+ join_values(spell.get("scaling_stats", []))
		+ " | "
		+ join_values(spell.get("roles", []))
	)


func render_weapon_card(weapon: Dictionary) -> void:
	var lines: Array[String] = []
	var description: String = str(weapon.get("description", ""))

	if description != "":
		lines.append(description)

	lines.append("Class: " + str(weapon.get("class", "unknown")))
	lines.append("Damage: " + str(weapon.get("damage", 0)) + " / stance " + str(weapon.get("stance_damage", 0)))
	lines.append("Range: " + str(weapon.get("range", 0.0)) + " / cooldown " + str(weapon.get("cooldown", 0.0)))
	lines.append("Stamina cost: " + str(weapon.get("stamina_cost", 0)))
	lines.append("Scaling: " + join_values(weapon.get("scaling_stats", [])))

	var scaling_note: String = str(weapon.get("scaling_note", ""))
	if scaling_note != "":
		lines.append("Scaling note: " + scaling_note)

	add_text_card("Weapon Slot: " + str(weapon.get("name", "Weapon")), "\n".join(lines), false, "Weapon")


func render_stats() -> void:
	add_text_card(
		"Base Stats Structure",
		"These are Grace's base stats plus elemental affinity hooks. This is still structure only: formulas, leveling, equipment scaling, and proc math can attach later."
	)

	var sections: Array = menu_data.get("stat_sections", [])

	if sections.size() <= 0:
		add_text_card("No stat sections found", "GameState did not provide stat section data yet.")
		return

	for section_variant in sections:
		if section_variant is Dictionary:
			render_stat_section(section_variant as Dictionary)


func render_stat_section(section: Dictionary) -> void:
	var title: String = str(section.get("title", "Stats"))
	var lines: Array[String] = []
	var description: String = str(section.get("description", ""))

	if description != "":
		lines.append(description)

	var stats: Array = section.get("stats", [])

	for stat_variant in stats:
		if not (stat_variant is Dictionary):
			continue

		var stat: Dictionary = stat_variant as Dictionary
		var stat_name: String = str(stat.get("name", stat.get("id", "Stat")))
		var stat_value: String = str(stat.get("value", "0"))
		var summary: String = str(stat.get("summary", ""))
		var use_text: String = str(stat.get("use", ""))

		lines.append(stat_name + ": " + stat_value)

		if summary != "":
			lines.append("  " + summary)

		if use_text != "":
			lines.append("  Use: " + use_text)

	add_text_card(title, "\n".join(lines))


func render_journal() -> void:
	var objective: String = str(menu_data.get("objective", "Look around."))
	add_text_card("Current Objective", objective)
	add_text_card("Main Quest", "Find someone who can help Grace understand where she has landed.")
	add_text_card("Clues", "Placeholder list. Later this can track signs, lore fragments, puzzle notes, and character leads.")
	add_text_card("Quest Structure", "Main quests, side quests, clues, and completed objectives will live here.")


func render_codex() -> void:
	add_text_card("Reaction Codex", "Data rows from ComboRuleRegistry. This is the first in-game window into the magic grammar.")

	var rows: Array[Dictionary] = ComboRuleRegistryScript.get_debug_matrix_rows()

	for row: Dictionary in rows:
		var title: String = str(row.get("reaction", "reaction"))
		var body: String = "Incoming: " + join_values(row.get("incoming", []))
		body += "\nTarget tags: " + join_values(row.get("target_tags", []))
		body += "\nTarget statuses: " + join_values(row.get("target_statuses", []))
		body += "\nTarget method: " + str(row.get("target_method", ""))
		body += "\nRule: " + str(row.get("rule", "combo_rule"))
		add_text_card(title, body)


func render_system() -> void:
	add_text_card("Controls", "Tab / M: open or close menu\nEsc: close menu\nA/D or arrows: switch tabs\n1-7: jump tabs")
	add_text_card("Future Panels", "Settings, save/load, controller mapping, accessibility, and debug toggles can attach here.")	
	add_text_card("Prototype Note", "Equipment is not enforcing hotkey assignment yet. The quick spell focus menu remains the combat-speed selector.")


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
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
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
