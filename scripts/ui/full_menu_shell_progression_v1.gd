extends "res://scripts/ui/full_menu_shell_codex_v1.gd"
class_name FullMenuShellProgressionV1

const ChallengeCatalogScript = preload(
	"res://scripts/progression/progression_challenge_catalog.gd"
)

const TRIGGER_THRESHOLD: float = 0.55
const GRACE_SUBTABS: Array[String] = [
	CATEGORY_WEAPON,
	CATEGORY_WARDROBE,
	CATEGORY_INFUSION,
	CATEGORY_QUICK_ITEMS,
	CATEGORY_SPECIAL,
]

var left_trigger_latched: bool = false
var right_trigger_latched: bool = false


func hide_menu() -> void:
	left_trigger_latched = false
	right_trigger_latched = false
	super.hide_menu()


func handle_menu_input(event: InputEvent) -> bool:
	if not visible:
		return false
	if event is InputEventJoypadMotion:
		var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
		if motion.axis == JOY_AXIS_TRIGGER_LEFT:
			var pressed_left: bool = motion.axis_value > TRIGGER_THRESHOLD
			if pressed_left and not left_trigger_latched:
				left_trigger_latched = true
				_dismiss_virtual_cursor_for_directional_input()
				select_tab(selected_tab_index - 1)
			elif not pressed_left:
				left_trigger_latched = false
			return true
		if motion.axis == JOY_AXIS_TRIGGER_RIGHT:
			var pressed_right: bool = motion.axis_value > TRIGGER_THRESHOLD
			if pressed_right and not right_trigger_latched:
				right_trigger_latched = true
				_dismiss_virtual_cursor_for_directional_input()
				select_tab(selected_tab_index + 1)
			elif not pressed_right:
				right_trigger_latched = false
			return true
	if event is InputEventJoypadButton:
		var button: InputEventJoypadButton = event as InputEventJoypadButton
		if button.pressed and button.button_index == JOY_BUTTON_LEFT_SHOULDER:
			_dismiss_virtual_cursor_for_directional_input()
			cycle_local_subtab(-1)
			return true
		if button.pressed and button.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			_dismiss_virtual_cursor_for_directional_input()
			cycle_local_subtab(1)
			return true
	return super.handle_menu_input(event)


func get_footer_text() -> String:
	var text: String = super.get_footer_text()
	text = text.replace("L/R: tabs", "ZL/ZR: tabs  •  L/R: subtabs")
	if not text.contains("ZL/ZR"):
		text = "ZL/ZR: tabs  •  L/R: subtabs  •  " + text
	return text


func activate_action(action: Dictionary) -> void:
	if str(action.get("kind", "")) == "select_codex_record":
		var record_id: String = str(action.get("record_id", ""))
		if (
			record_id != ""
			and record_id == selected_codex_record_id
			and selected_codex_category in ["story", "side"]
		):
			var tracker: Node = _get_progression_tracker()
			if tracker != null and tracker.has_method("track_quest"):
				tracker.call("track_quest", record_id)
				rebuild_menu()
				return
	super.activate_action(action)


func cycle_local_subtab(delta: int) -> void:
	var entries: Array[String] = _get_local_subtab_entries()
	if entries.is_empty() or delta == 0:
		return
	var current_id: String = _get_current_local_subtab_id()
	var current_index: int = entries.find(current_id)
	var next_index: int = 0 if current_index < 0 else posmod(current_index + delta, entries.size())
	if current_index < 0 and delta < 0:
		next_index = entries.size() - 1
	_open_local_subtab(entries[next_index])


func _get_local_subtab_entries() -> Array[String]:
	match get_current_tab_id():
		"loadout":
			return GRACE_SUBTABS.duplicate()
		"magic":
			var rows: Array[String] = []
			for element_id: String in ELEMENT_ORDER:
				rows.append("element:" + element_id)
			for tradition_id: String in SpellcastingTraditionCatalogScript.TRADITION_IDS:
				rows.append("tradition:" + tradition_id)
			rows.append("patrons")
			rows.append("incarnations")
			return rows
		"items":
			return ItemCategoryCatalogScript.CATEGORY_ORDER.duplicate()
		"journal":
			return JOURNAL_V2_CATEGORY_ORDER.duplicate()
		"codex":
			return CodexCatalogScript.CATEGORY_ORDER.duplicate()
	return []


func _get_current_local_subtab_id() -> String:
	match get_current_tab_id():
		"loadout":
			return _grace_category_for_page()
		"magic":
			if magic_page in [MAGIC_PATRONS, MAGIC_PATRON]:
				return "patrons"
			if magic_page in [MAGIC_INCARNATIONS, MAGIC_INCARNATION]:
				return "incarnations"
			if magic_page == MAGIC_TRADITION:
				return "tradition:" + selected_magic_tradition_id
			if selected_magic_element != "":
				return "element:" + selected_magic_element
		"items":
			return selected_item_category
		"journal":
			return selected_journal_category
		"codex":
			return selected_codex_category
	return ""


func _open_local_subtab(entry_id: String) -> void:
	match get_current_tab_id():
		"loadout":
			_toggle_grace_category(entry_id)
		"magic":
			if entry_id.begins_with("element:"):
				_toggle_magic_element(entry_id.trim_prefix("element:"))
			elif entry_id.begins_with("tradition:"):
				_toggle_magic_tradition(entry_id.trim_prefix("tradition:"))
			elif entry_id == "patrons":
				if magic_page not in [MAGIC_PATRONS, MAGIC_PATRON]:
					_toggle_patron_roster()
			elif entry_id == "incarnations":
				if magic_page not in [MAGIC_INCARNATIONS, MAGIC_INCARNATION]:
					_toggle_incarnation_roster()
		"items":
			_toggle_item_category(entry_id)
		"journal":
			_toggle_journal_category(entry_id)
		"codex":
			_toggle_codex_category(entry_id)


func _grace_category_for_page() -> String:
	if loadout_page in [LOADOUT_WEAPON_CLASSES, LOADOUT_WEAPON_VARIANTS]:
		return CATEGORY_WEAPON
	if loadout_page in [LOADOUT_WARDROBE, LOADOUT_WARDROBE_SLOT]:
		return CATEGORY_WARDROBE
	if loadout_page == LOADOUT_INFUSION:
		return CATEGORY_INFUSION
	if loadout_page in [LOADOUT_QUICK_ITEMS, LOADOUT_QUICK_ITEM_PICKER]:
		return CATEGORY_QUICK_ITEMS
	if loadout_page == LOADOUT_SPECIAL:
		return CATEGORY_SPECIAL
	return ""


func _get_journal_rows(category_id: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = super._get_journal_rows(category_id)
	if category_id != "elements":
		return rows
	var tracker: Node = _get_progression_tracker()
	if tracker == null or not tracker.has_method("has_discovery"):
		return rows
	var reaction_records: Array[Dictionary] = ElementJournalCatalogScript.get_reaction_rows()
	for row: Dictionary in rows:
		var visible_lines: Array[String] = []
		for raw_line: Variant in row.get("reaction_lines", []):
			var line: String = str(raw_line)
			var replacement: String = line
			for reaction: Dictionary in reaction_records:
				var result_name: String = str(reaction.get("result", ""))
				var reaction_id: String = result_name.to_lower().replace(" ", "_")
				if result_name != "" and line.ends_with("→ " + result_name):
					if not bool(tracker.call("has_discovery", "reaction", reaction_id)):
						replacement = line.get_slice("→", 0).strip_edges() + " → ???"
					break
			visible_lines.append(replacement)
		row["reaction_lines"] = visible_lines
		var details: Array[String] = []
		for raw_detail: Variant in row.get("details", []):
			var detail: String = str(raw_detail)
			if not detail.begins_with("Reaction:"):
				details.append(detail)
		for line: String in visible_lines:
			details.append("Reaction: " + line)
		row["details"] = details
	return rows


func _add_codex_category_tile(parent: Container, category_id: String) -> void:
	if category_id != "challenges":
		super._add_codex_category_tile(parent, category_id)
		return
	var definition: Dictionary = CodexCatalogScript.get_definition(category_id)
	var rows: Array[Dictionary] = _get_progression_challenge_rows()
	var completed: int = _count_codex_complete(rows)
	var action_index: int = selectable_actions.size()
	selectable_actions.append({"kind": "toggle_codex_category", "category_id": category_id})
	var selected: bool = action_index == selected_action_index
	var active: bool = codex_page == CODEX_CATEGORY and selected_codex_category == category_id
	var button: Button = Button.new()
	button.text = str(definition.get("icon", "◆")) + "\nChallenges\n" + str(completed) + "/" + str(rows.size())
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(150.0, 72.0)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_color_override("font_color", TEXT_MAIN if selected or active else TEXT_SOFT)
	button.add_theme_stylebox_override("normal", make_panel_style(ACTIVE_SELECTION_BACKGROUND if selected else (CODEX_ACTIVE_BACKGROUND if active else CODEX_BACKGROUND), ACTIVE_SELECTION_BORDER if selected else (CODEX_ACTIVE_BORDER if active else CARD_BORDER), 3 if selected else (2 if active else 1), 9))
	button.add_theme_stylebox_override("focus", make_panel_style(ACTIVE_SELECTION_BACKGROUND, ACTIVE_SELECTION_BORDER, 3, 9))
	button.add_theme_stylebox_override("hover", make_panel_style(Color(0.15, 0.11, 0.045, 0.98), CODEX_ACTIVE_BORDER, 2, 9))
	button.pressed.connect(_on_action_row_pressed.bind(action_index))
	button.mouse_entered.connect(_on_action_row_hovered.bind(action_index))
	parent.add_child(button)
	_register_action_control(button, action_index)
	if selected:
		schedule_selected_control(button)


func _render_codex_category(parent: VBoxContainer, category_id: String) -> void:
	if category_id != "challenges":
		super._render_codex_category(parent, category_id)
		return
	var definition: Dictionary = CodexCatalogScript.get_definition(category_id)
	var rows: Array[Dictionary] = _get_progression_challenge_rows()
	parent.add_child(_make_magic_heading("◆  STARTER CHALLENGES  •  LIVE PROGRESSION"))
	var description: Label = Label.new()
	description.text = "Gameplay events feed these records directly. Completing one grants its listed mechanic or progression hook."
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
	var record_panel: PanelContainer = _make_magic_subpanel()
	record_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace.add_child(record_panel)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	record_panel.add_child(margin)
	var grid: GridContainer = make_visual_grid(3)
	grid.name = "CodexRecordGrid"
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 7)
	margin.add_child(grid)
	if _find_codex_row(rows, selected_codex_record_id).is_empty() and not rows.is_empty():
		selected_codex_record_id = str(rows[0].get("id", ""))
	for row: Dictionary in rows:
		_add_codex_record_tile(grid, row)
	workspace.add_child(_make_codex_detail_panel(_find_codex_row(rows, selected_codex_record_id), definition))


func _render_codex_overview(parent: VBoxContainer) -> void:
	super._render_codex_overview(parent)
	parent.add_child(_make_magic_heading("PROGRESSION BACKBONE  •  STARTER SET"))
	var grid: GridContainer = make_visual_grid(5)
	grid.add_theme_constant_override("h_separation", 8)
	parent.add_child(grid)
	for row: Dictionary in _get_progression_challenge_rows():
		_add_magic_info_panel(
			grid,
			str(row.get("icon", "◆")) + "  " + str(row.get("name", "Challenge")).to_upper(),
			str(row.get("progress_current", 0)) + "/" + str(row.get("progress_target", 1)) + "  •  " + str(row.get("reward", "Reward"))
		)


func get_codex_debug_data() -> Dictionary:
	var data: Dictionary = super.get_codex_debug_data()
	data["challenge_count"] = _get_progression_challenge_rows().size()
	data["hierarchical_shoulders"] = true
	data["tracked_quest_id"] = _get_tracked_quest_id()
	return data


func _get_progression_challenge_rows() -> Array[Dictionary]:
	var tracker: Node = _get_progression_tracker()
	if tracker != null and tracker.has_method("get_challenge_rows"):
		var value: Variant = tracker.call("get_challenge_rows")
		if value is Array:
			var rows: Array[Dictionary] = []
			for raw: Variant in value as Array:
				if raw is Dictionary:
					rows.append((raw as Dictionary).duplicate(true))
			return rows
	return []


func _get_tracked_quest_id() -> String:
	var tracker: Node = _get_progression_tracker()
	if tracker != null and tracker.has_method("get_tracked_quest_id"):
		return str(tracker.call("get_tracked_quest_id"))
	return ""


func _get_progression_tracker() -> Node:
	return get_node_or_null("/root/FullMenuDirector/ProgressionTracker")
