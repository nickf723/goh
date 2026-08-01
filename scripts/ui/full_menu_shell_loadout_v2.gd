extends "res://scripts/ui/full_menu_shell_loadout_v1.gd"
class_name FullMenuShellLoadoutV2

const StatCatalogScript = preload("res://scripts/systems/stat_catalog.gd")

const STAT_QUADRANTS: Array[Dictionary] = [
	{
		"title": "VITALS",
		"stats": ["health", "stamina", "mana", "stance"],
	},
	{
		"title": "OFFENSE",
		"stats": ["power", "dexterity", "arcana", "intelligence"],
	},
	{
		"title": "DEFENSE",
		"stats": ["defense", "resilience", "constitution", "evasion"],
	},
	{
		"title": "UTILITY",
		"stats": ["focus", "charisma", "skill", "luck"],
	},
]

const CURSOR_DEADZONE: float = 0.22
const CURSOR_SPEED: float = 920.0
const DIRECTION_MIN_PROJECTION: float = 4.0

var action_controls: Array[Control] = []
var tab_controls: Array[Button] = []

var virtual_cursor_layer: CanvasLayer
var virtual_cursor_label: Label
var virtual_cursor_position: Vector2 = Vector2.ZERO
var right_stick_vector: Vector2 = Vector2.ZERO
var virtual_cursor_active: bool = false
var virtual_cursor_tab_target: int = -1


func show_menu(new_menu_data: Dictionary) -> void:
	_ensure_virtual_cursor()
	super.show_menu(new_menu_data)
	_update_scroll_policy()


func hide_menu() -> void:
	right_stick_vector = Vector2.ZERO
	virtual_cursor_active = false
	virtual_cursor_tab_target = -1
	if virtual_cursor_layer != null:
		virtual_cursor_layer.visible = false
	super.hide_menu()


func select_tab(index: int) -> void:
	super.select_tab(index)
	_update_scroll_policy()
	virtual_cursor_tab_target = -1


func rebuild_tabs() -> void:
	super.rebuild_tabs()
	tab_controls.clear()
	for child: Node in tab_box.get_children():
		if child is Button:
			tab_controls.append(child as Button)


func rebuild_content() -> void:
	action_controls.clear()
	super.rebuild_content()
	_update_scroll_policy()
	call_deferred("_refresh_cursor_target_after_layout")


func add_visual_action_tile(
	parent: Container,
	icon_text: String,
	title: String,
	badge: String,
	action: Dictionary,
	tooltip: String = ""
) -> void:
	super.add_visual_action_tile(parent, icon_text, title, badge, action, tooltip)
	_register_last_action_control(parent)


func add_action_row(line: String, action: Dictionary, subtitle: String = "") -> void:
	super.add_action_row(line, action, subtitle)
	_register_last_action_control(content_box)


func handle_menu_input(event: InputEvent) -> bool:
	if not visible:
		return false

	if event is InputEventJoypadMotion:
		var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
		if motion.axis == JOY_AXIS_RIGHT_X:
			right_stick_vector.x = motion.axis_value
			_activate_virtual_cursor_if_needed()
			return true
		if motion.axis == JOY_AXIS_RIGHT_Y:
			right_stick_vector.y = motion.axis_value
			_activate_virtual_cursor_if_needed()
			return true

	if event is InputEventJoypadButton:
		var button: InputEventJoypadButton = event as InputEventJoypadButton
		if (
			button.pressed
			and virtual_cursor_active
			and virtual_cursor_tab_target >= 0
			and button.button_index == get_menu_confirm_button(button.device)
		):
			select_tab(virtual_cursor_tab_target)
			return true

	return super.handle_menu_input(event)


func _process(delta: float) -> void:
	if not visible or not virtual_cursor_active:
		return
	var magnitude: float = right_stick_vector.length()
	if magnitude < CURSOR_DEADZONE:
		return
	var resolved_vector: Vector2 = right_stick_vector
	if magnitude > 1.0:
		resolved_vector = resolved_vector.normalized()
	virtual_cursor_position += resolved_vector * CURSOR_SPEED * maxf(delta, 0.0)
	_clamp_virtual_cursor()
	_position_virtual_cursor_label()
	_update_virtual_cursor_target()


func select_action_direction(horizontal: int, vertical: int) -> void:
	if _select_action_from_screen_geometry(horizontal, vertical):
		return
	super.select_action_direction(horizontal, vertical)


func render_loadout() -> void:
	content_title_label.text = _get_grace_page_title()
	action_layout_mode = "screen_geometry"
	action_grid_columns = 1
	_update_scroll_policy()

	_render_compact_category_strip()
	_render_persistent_grace_workspace()
	_render_persistent_spell_ribbon()


func _render_compact_category_strip() -> void:
	var strip: GridContainer = make_visual_grid(5)
	strip.add_theme_constant_override("h_separation", 8)
	content_box.add_child(strip)

	var weapon_id: String = GameState.get_equipped_item(MenuEquipmentCatalog.SLOT_WEAPON)
	var weapon_name: String = (
		MenuEquipmentCatalog.get_display_name(weapon_id)
		if weapon_id != ""
		else "None"
	)
	var wardrobe_count: int = 0
	for slot_id: String in MenuEquipmentCatalog.WARDROBE_SLOT_ORDER:
		if GameState.get_equipped_item(slot_id) != "":
			wardrobe_count += 1
	var infusion: Dictionary = MenuInfusionCatalog.get_definition(
		GameState.get_weapon_infusion()
	)
	var quick_slots: Array = menu_data.get("quick_item_slots", [])
	var special: Dictionary = _get_divine_special_summary()

	_add_compact_action_tile(
		strip,
		("▾ " if _category_is_open(CATEGORY_WEAPON) else "▸ ") + "⚔",
		"Weapon",
		weapon_name.to_upper(),
		{"kind": "toggle_grace_category", "category": CATEGORY_WEAPON},
		"Open the sixteen weapon classes."
	)
	_add_compact_action_tile(
		strip,
		("▾ " if _category_is_open(CATEGORY_WARDROBE) else "▸ ") + "♧",
		"Wardrobe",
		str(wardrobe_count) + "/" + str(MenuEquipmentCatalog.WARDROBE_SLOT_ORDER.size()),
		{"kind": "toggle_grace_category", "category": CATEGORY_WARDROBE},
		"Open Grace's six clothing and accessory components."
	)
	_add_compact_action_tile(
		strip,
		("▾ " if _category_is_open(CATEGORY_INFUSION) else "▸ ")
		+ str(infusion.get("icon", "◇")),
		"Infusion",
		str(infusion.get("name", "Uninfused")).to_upper(),
		{"kind": "toggle_grace_category", "category": CATEGORY_INFUSION},
		str(infusion.get("description", "Choose a weapon infusion."))
	)
	_add_compact_action_tile(
		strip,
		("▾ " if _category_is_open(CATEGORY_QUICK_ITEMS) else "▸ ") + "🧪",
		"Quick Items",
		str(_count_nonempty_rows(quick_slots)) + "/" + str(quick_slots.size()),
		{"kind": "toggle_grace_category", "category": CATEGORY_QUICK_ITEMS},
		"Edit the D-pad Up item cycle."
	)
	_add_compact_action_tile(
		strip,
		("▾ " if _category_is_open(CATEGORY_SPECIAL) else "▸ ") + "☀",
		"Divine Special",
		str(special.get("badge", "UNAVAILABLE")),
		{"kind": "toggle_grace_category", "category": CATEGORY_SPECIAL},
		str(special.get("description", "Choose a Divine Special."))
	)


func _render_persistent_grace_workspace() -> void:
	var workspace: HBoxContainer = HBoxContainer.new()
	workspace.name = "GracePersistentWorkspace"
	workspace.add_theme_constant_override("separation", 12)
	workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_box.add_child(workspace)

	workspace.add_child(_make_persistent_grace_preview())

	var right_panel: PanelContainer = PanelContainer.new()
	right_panel.name = "GraceEquipmentWorkspace"
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.add_theme_stylebox_override(
		"panel",
		make_panel_style(Color(0.035, 0.045, 0.062, 0.92), CARD_BORDER, 1, 13)
	)
	workspace.add_child(right_panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	right_panel.add_child(margin)

	var right_stack: VBoxContainer = VBoxContainer.new()
	right_stack.add_theme_constant_override("separation", 8)
	margin.add_child(right_stack)

	var expansion_box: VBoxContainer = VBoxContainer.new()
	expansion_box.name = "GraceExpansionContent"
	expansion_box.add_theme_constant_override("separation", 6)
	expansion_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_stack.add_child(expansion_box)
	_render_active_grace_expansion(expansion_box)

	_render_stat_quadrants(right_stack)


func _make_persistent_grace_preview() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "GracePreviewPanel"
	panel.custom_minimum_size = Vector2(372.0, 0.0)
	panel.add_theme_stylebox_override(
		"panel",
		make_panel_style(Color(0.025, 0.035, 0.052, 0.94), CARD_BORDER, 1, 13)
	)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 4)
	panel.add_child(margin)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 0)
	margin.add_child(stack)
	var preview: GraceComponentLoadoutPreview = GraceComponentPreviewScript.new()
	preview.name = "GracePreview"
	preview.configure(_get_equipped_items(), GameState.get_weapon_infusion())
	stack.add_child(preview)
	var label: Label = Label.new()
	label.text = "GRACE"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", ACTIVE_SELECTION_BORDER)
	stack.add_child(label)
	return panel


func _render_active_grace_expansion(parent: VBoxContainer) -> void:
	match loadout_page:
		LOADOUT_WEAPON_CLASSES:
			_render_compact_weapon_classes(parent)
		LOADOUT_WEAPON_VARIANTS:
			_render_compact_weapon_variants(parent)
		LOADOUT_WARDROBE:
			_render_compact_wardrobe_slots(parent)
		LOADOUT_WARDROBE_SLOT:
			_render_compact_wardrobe_items(parent)
		LOADOUT_INFUSION:
			_render_compact_infusions(parent)
		LOADOUT_QUICK_ITEMS:
			_render_compact_quick_items(parent)
		LOADOUT_QUICK_ITEM_PICKER:
			_render_compact_quick_item_picker(parent)
		LOADOUT_SPECIAL:
			_render_compact_divine_specials(parent)
		_:
			_render_compact_field_kit(parent)


func _render_compact_field_kit(parent: VBoxContainer) -> void:
	parent.add_child(_make_workspace_heading("CURRENT FIELD KIT"))
	var grid: GridContainer = make_visual_grid(2)
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 4)
	parent.add_child(grid)
	for slot_id: String in MenuEquipmentCatalog.SLOT_ORDER:
		var item_id: String = GameState.get_equipped_item(slot_id)
		var definition: Dictionary = MenuEquipmentCatalog.get_definition(item_id)
		var row: Label = Label.new()
		row.text = (
			MenuEquipmentCatalog.get_slot_display_name(slot_id)
			+ "  "
			+ str(definition.get("icon", "◇"))
			+ "  "
			+ str(definition.get("name", "Empty"))
		)
		row.add_theme_font_size_override("font_size", 12)
		row.add_theme_color_override("font_color", TEXT_SOFT)
		grid.add_child(row)
	var hint: Label = Label.new()
	hint.text = "Expand one category above. Grace, stats, and spells remain anchored."
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", TEXT_DIM)
	parent.add_child(hint)


func _render_compact_weapon_classes(parent: VBoxContainer) -> void:
	parent.add_child(_make_workspace_heading("WEAPON CLASSES  •  4 × 4"))
	var grid: GridContainer = make_visual_grid(4)
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	parent.add_child(grid)
	var current_class: String = MenuEquipmentCatalog.get_weapon_class(
		GameState.get_equipped_item(MenuEquipmentCatalog.SLOT_WEAPON)
	)
	for row: Dictionary in WeaponVariantCatalogScript.get_class_rows():
		var weapon_class: String = str(row.get("id", ""))
		var rank: int = GameState.get_weapon_mastery_rank(weapon_class)
		var badge: String = WeaponMasteryCatalogScript.get_rank_name(rank).to_upper()
		if weapon_class == current_class:
			badge = "EQUIPPED  •  " + badge
		_add_compact_action_tile(
			grid,
			str(row.get("icon", "◇")),
			str(row.get("name", weapon_class.capitalize())),
			badge,
			{"kind": "open_weapon_class", "weapon_class": weapon_class},
			str(row.get("description", "")),
			58.0
		)


func _render_compact_weapon_variants(parent: VBoxContainer) -> void:
	var class_data: Dictionary = WeaponVariantCatalogScript.get_class_definition(
		selected_weapon_class
	)
	parent.add_child(
		_make_workspace_heading(
			str(class_data.get("name", selected_weapon_class.capitalize())).to_upper()
			+ " TYPES"
		)
	)
	var grid: GridContainer = make_visual_grid(4)
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 7)
	parent.add_child(grid)
	for variant: Dictionary in WeaponVariantCatalogScript.get_variants(selected_weapon_class):
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
				badge = (
					"EQUIPPED"
					if GameState.is_equipment_equipped(item_id)
					else "OWNED"
				)
			else:
				badge = "NOT OWNED"
		_add_compact_action_tile(
			grid,
			str(class_data.get("icon", "◇")),
			str(variant.get("name", "Weapon Type")),
			badge,
			action,
			str(variant.get("description", "")),
			74.0
		)


func _render_compact_wardrobe_slots(parent: VBoxContainer) -> void:
	parent.add_child(_make_workspace_heading("WARDROBE COMPONENTS"))
	var grid: GridContainer = make_visual_grid(3)
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 7)
	parent.add_child(grid)
	for slot_id: String in MenuEquipmentCatalog.WARDROBE_SLOT_ORDER:
		var item_id: String = GameState.get_equipped_item(slot_id)
		var definition: Dictionary = MenuEquipmentCatalog.get_definition(item_id)
		_add_compact_action_tile(
			grid,
			str(definition.get("icon", "◇")),
			MenuEquipmentCatalog.get_slot_display_name(slot_id),
			str(definition.get("name", "Empty")).to_upper(),
			{"kind": "open_wardrobe_slot", "slot_id": slot_id},
			"Open this component.",
			72.0
		)


func _render_compact_wardrobe_items(parent: VBoxContainer) -> void:
	parent.add_child(
		_make_workspace_heading(
			MenuEquipmentCatalog.get_slot_display_name(selected_wardrobe_slot).to_upper()
		)
	)
	var grid: GridContainer = make_visual_grid(3)
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 7)
	parent.add_child(grid)
	for row: Dictionary in MenuEquipmentCatalog.get_rows_for_slot(selected_wardrobe_slot):
		var item_id: String = str(row.get("id", ""))
		var owned: bool = GameState.owns_equipment(item_id)
		var action: Dictionary = (
			{"kind": "equip_wardrobe_item", "item_id": item_id}
			if owned
			else {
				"kind": "inspect_locked_equipment",
				"message": str(row.get("name", "Item")) + " has not been acquired yet.",
			}
		)
		var badge: String = (
			"EQUIPPED"
			if GameState.is_equipment_equipped(item_id)
			else ("OWNED" if owned else "NOT OWNED")
		)
		_add_compact_action_tile(
			grid,
			str(row.get("icon", "◇")),
			str(row.get("name", item_id.capitalize())),
			badge,
			action,
			str(row.get("description", "")),
			74.0
		)


func _render_compact_infusions(parent: VBoxContainer) -> void:
	parent.add_child(_make_workspace_heading("WEAPON INFUSION"))
	var grid: GridContainer = make_visual_grid(4)
	grid.add_theme_constant_override("h_separation", 7)
	parent.add_child(grid)
	var active: String = GameState.get_weapon_infusion()
	for row: Dictionary in MenuInfusionCatalog.get_rows():
		var infusion_id: String = str(row.get("id", ""))
		_add_compact_action_tile(
			grid,
			str(row.get("icon", "◇")),
			str(row.get("name", infusion_id.capitalize())),
			"EQUIPPED" if infusion_id == active else "SELECT",
			{"kind": "set_weapon_infusion", "infusion_id": infusion_id},
			str(row.get("description", "")),
			76.0
		)


func _render_compact_quick_items(parent: VBoxContainer) -> void:
	parent.add_child(_make_workspace_heading("QUICK-ITEM CYCLE  •  UP TAP / HOLD"))
	var grid: GridContainer = make_visual_grid(4)
	grid.add_theme_constant_override("h_separation", 7)
	parent.add_child(grid)
	var slots: Array = menu_data.get("quick_item_slots", [])
	for index: int in range(slots.size()):
		if not slots[index] is Dictionary:
			continue
		var slot: Dictionary = slots[index] as Dictionary
		var empty: bool = bool(slot.get("is_empty", true))
		var badge: String = "SLOT " + str(index + 1)
		if not empty:
			badge += "  •  ×" + str(slot.get("count", 0))
		_add_compact_action_tile(
			grid,
			"◇" if empty else str(slot.get("icon", "◇")),
			"Empty" if empty else str(slot.get("name", "Item")),
			badge,
			{"kind": "open_quick_item_picker", "slot": int(slot.get("slot", index))},
			"Choose this cycle position.",
			76.0
		)


func _render_compact_quick_item_picker(parent: VBoxContainer) -> void:
	parent.add_child(
		_make_workspace_heading(
			"QUICK ITEM  •  SLOT " + str(pending_quick_item_slot_index + 1)
		)
	)
	var grid: GridContainer = make_visual_grid(3)
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 7)
	parent.add_child(grid)
	for value: Variant in menu_data.get("inventory_items", []):
		if not value is Dictionary:
			continue
		var row: Dictionary = value as Dictionary
		if int(row.get("count", 0)) <= 0:
			continue
		_add_compact_action_tile(
			grid,
			str(row.get("icon", "◇")),
			str(row.get("name", "Item")),
			"×" + str(row.get("count", 0)),
			{"kind": "assign_quick_item", "item_id": str(row.get("id", ""))},
			str(row.get("description", "")),
			72.0
		)
	_add_compact_action_tile(
		grid,
		"×",
		"Clear Slot",
		"EMPTY",
		{"kind": "assign_quick_item", "item_id": ""},
		"Remove this position from the cycle.",
		72.0
	)


func _render_compact_divine_specials(parent: VBoxContainer) -> void:
	parent.add_child(_make_workspace_heading("DIVINE SPECIAL"))
	var controller: Node = _get_divine_special_controller()
	if controller == null:
		var missing: Label = Label.new()
		missing.text = "No Divine Special controller is available."
		missing.add_theme_color_override("font_color", TEXT_SOFT)
		parent.add_child(missing)
		return
	var force_debug: bool = OS.is_debug_build()
	var selected: DivineSpecialDefinition = controller.call(
		"get_selected_special",
		force_debug
	) as DivineSpecialDefinition
	var available: Variant = controller.call("get_available_specials", force_debug)
	if not available is Array:
		return
	var grid: GridContainer = make_visual_grid(3)
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 7)
	parent.add_child(grid)
	for value: Variant in available as Array:
		if not value is DivineSpecialDefinition:
			continue
		var definition: DivineSpecialDefinition = value as DivineSpecialDefinition
		_add_compact_action_tile(
			grid,
			"☀",
			definition.display_name,
			(
				"SELECTED"
				if selected != null and selected.special_id == definition.special_id
				else "SELECT"
			),
			{"kind": "select_divine_special", "special_id": definition.special_id},
			definition.description,
			82.0
		)


func _render_stat_quadrants(parent: VBoxContainer) -> void:
	var stat_grid: GridContainer = make_visual_grid(4)
	stat_grid.name = "GraceStatQuadrants"
	stat_grid.add_theme_constant_override("h_separation", 7)
	parent.add_child(stat_grid)
	for quadrant: Dictionary in STAT_QUADRANTS:
		var panel: PanelContainer = PanelContainer.new()
		panel.add_theme_stylebox_override(
			"panel",
			make_panel_style(Color(0.05, 0.062, 0.082, 0.88), CARD_BORDER, 1, 9)
		)
		stat_grid.add_child(panel)
		var margin: MarginContainer = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 9)
		margin.add_theme_constant_override("margin_top", 6)
		margin.add_theme_constant_override("margin_right", 9)
		margin.add_theme_constant_override("margin_bottom", 6)
		panel.add_child(margin)
		var stack: VBoxContainer = VBoxContainer.new()
		stack.add_theme_constant_override("separation", 1)
		margin.add_child(stack)
		var title: Label = Label.new()
		title.text = str(quadrant.get("title", "STATS"))
		title.add_theme_font_size_override("font_size", 11)
		title.add_theme_color_override("font_color", ACTIVE_SELECTION_BORDER)
		stack.add_child(title)
		for stat_value: Variant in quadrant.get("stats", []):
			var stat_id: String = str(stat_value)
			var row: HBoxContainer = HBoxContainer.new()
			stack.add_child(row)
			var name_label: Label = Label.new()
			name_label.text = str(
				StatCatalogScript.get_stat_definition(stat_id).get(
					"name",
					stat_id.capitalize()
				)
			)
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_label.add_theme_font_size_override("font_size", 10)
			name_label.add_theme_color_override("font_color", TEXT_SOFT)
			row.add_child(name_label)
			var value_label: Label = Label.new()
			value_label.text = _get_compact_stat_value(stat_id)
			value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			value_label.add_theme_font_size_override("font_size", 10)
			value_label.add_theme_color_override("font_color", TEXT_MAIN)
			row.add_child(value_label)


func _render_persistent_spell_ribbon() -> void:
	var label: Label = Label.new()
	label.text = "FAVORITE SPELL RING  •  D-PAD LEFT / RIGHT IN GAMEPLAY"
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", TEXT_MAIN)
	content_box.add_child(label)
	var grid: GridContainer = make_visual_grid(10)
	grid.name = "GraceSpellRibbon"
	grid.add_theme_constant_override("h_separation", 6)
	content_box.add_child(grid)
	for value: Variant in menu_data.get("equipped_spell_slots", []):
		if not value is Dictionary:
			continue
		var spell: Dictionary = value as Dictionary
		var slot_index: int = int(spell.get("slot", 0))
		var empty: bool = bool(spell.get("is_empty", false))
		_add_compact_action_tile(
			grid,
			"✦" if empty else get_spell_icon(str(spell.get("element", "neutral"))),
			"Empty" if empty else str(spell.get("name", "Spell")),
			str(slot_index + 1),
			{"kind": "choose_spell_slot", "slot": slot_index},
			str(spell.get("description", "Select to assign a learned spell.")),
			58.0,
			10
		)


func _add_compact_action_tile(
	parent: Container,
	icon_text: String,
	title: String,
	badge: String,
	action: Dictionary,
	tooltip: String = "",
	minimum_height: float = 72.0,
	font_size: int = 11
) -> void:
	var action_index: int = selectable_actions.size()
	selectable_actions.append(action.duplicate(true))
	var selected: bool = action_index == selected_action_index
	var button: Button = Button.new()
	button.text = icon_text + "\n" + title + "\n" + badge
	button.tooltip_text = tooltip
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(72.0, minimum_height)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", TEXT_MAIN if selected else TEXT_SOFT)
	button.add_theme_stylebox_override(
		"normal",
		make_panel_style(
			ACTIVE_SELECTION_BACKGROUND if selected else CARD_BACKGROUND,
			ACTIVE_SELECTION_BORDER if selected else CARD_BORDER,
			3 if selected else 1,
			9
		)
	)
	button.add_theme_stylebox_override(
		"focus",
		make_panel_style(ACTIVE_SELECTION_BACKGROUND, ACTIVE_SELECTION_BORDER, 3, 9)
	)
	button.add_theme_stylebox_override(
		"hover",
		make_panel_style(Color(0.15, 0.105, 0.08, 0.92), ACTIVE_SELECTION_BORDER, 2, 9)
	)
	button.pressed.connect(_on_action_row_pressed.bind(action_index))
	button.mouse_entered.connect(_on_action_row_hovered.bind(action_index))
	parent.add_child(button)
	_register_action_control(button, action_index)
	if selected:
		schedule_selected_control(button)


func _make_workspace_heading(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", ACTIVE_SELECTION_BORDER)
	return label


func _get_compact_stat_value(stat_id: String) -> String:
	if StatCatalogScript.ACTION_RESOURCE_IDS.has(stat_id):
		return (
			str(GameState.get_stat(stat_id))
			+ "/"
			+ str(GameState.get_stat("max_" + stat_id))
		)
	return str(GameState.get_stat(stat_id))


func _get_grace_page_title() -> String:
	match loadout_page:
		LOADOUT_WEAPON_CLASSES:
			return "◇ Grace  ›  Weapon Classes"
		LOADOUT_WEAPON_VARIANTS:
			return "◇ Grace  ›  " + WeaponMasteryCatalogScript.get_display_name(
				selected_weapon_class
			)
		LOADOUT_WARDROBE:
			return "◇ Grace  ›  Wardrobe"
		LOADOUT_WARDROBE_SLOT:
			return "◇ Grace  ›  " + MenuEquipmentCatalog.get_slot_display_name(
				selected_wardrobe_slot
			)
		LOADOUT_INFUSION:
			return "◇ Grace  ›  Infusion"
		LOADOUT_QUICK_ITEMS, LOADOUT_QUICK_ITEM_PICKER:
			return "◇ Grace  ›  Quick Items"
		LOADOUT_SPECIAL:
			return "◇ Grace  ›  Divine Special"
	return "◇ Grace"


func _register_last_action_control(parent: Container) -> void:
	if parent == null or parent.get_child_count() <= 0:
		return
	var child: Node = parent.get_child(parent.get_child_count() - 1)
	if child is Control:
		_register_action_control(child as Control, selectable_actions.size() - 1)


func _register_action_control(control: Control, action_index: int) -> void:
	if control == null or action_index < 0:
		return
	control.set_meta("menu_action_index", action_index)
	while action_controls.size() <= action_index:
		action_controls.append(null)
	action_controls[action_index] = control


func _select_action_from_screen_geometry(horizontal: int, vertical: int) -> bool:
	if selectable_actions.is_empty() or action_controls.size() != selectable_actions.size():
		return false
	if horizontal == 0 and vertical == 0:
		return false
	selected_action_index = clampi(
		selected_action_index,
		0,
		selectable_actions.size() - 1
	)
	var current: Control = action_controls[selected_action_index]
	if not _control_has_geometry(current):
		return false
	var direction: Vector2 = Vector2(float(horizontal), float(vertical)).normalized()
	var current_rect: Rect2 = current.get_global_rect()
	var current_center: Vector2 = current_rect.get_center()
	var best_index: int = -1
	var best_score: float = INF
	for index: int in range(action_controls.size()):
		if index == selected_action_index:
			continue
		var candidate: Control = action_controls[index]
		if not _control_has_geometry(candidate):
			continue
		var candidate_rect: Rect2 = candidate.get_global_rect()
		var delta: Vector2 = candidate_rect.get_center() - current_center
		var projection: float = delta.dot(direction)
		if projection <= DIRECTION_MIN_PROJECTION:
			continue
		var distance: float = maxf(delta.length(), 0.001)
		var alignment: float = projection / distance
		if alignment < 0.18:
			continue
		var perpendicular: float = absf(
			delta.x * direction.y - delta.y * direction.x
		)
		var score: float = projection + perpendicular * 4.0
		if horizontal != 0 and absf(delta.y) <= maxf(
			current_rect.size.y,
			candidate_rect.size.y
		) * 0.62:
			score *= 0.18
		elif vertical != 0 and absf(delta.x) <= maxf(
			current_rect.size.x,
			candidate_rect.size.x
		) * 0.62:
			score *= 0.18
		if score < best_score:
			best_score = score
			best_index = index
	if best_index < 0:
		return false
	select_action(best_index)
	return true


func _control_has_geometry(control: Control) -> bool:
	return (
		control != null
		and is_instance_valid(control)
		and control.is_visible_in_tree()
		and control.size.x > 2.0
		and control.size.y > 2.0
	)


func _ensure_virtual_cursor() -> void:
	if virtual_cursor_layer != null and is_instance_valid(virtual_cursor_layer):
		return
	virtual_cursor_layer = CanvasLayer.new()
	virtual_cursor_layer.name = "MenuRightStickCursorLayer"
	virtual_cursor_layer.layer = 120
	virtual_cursor_layer.visible = false
	add_child(virtual_cursor_layer)
	virtual_cursor_label = Label.new()
	virtual_cursor_label.name = "MenuRightStickCursor"
	virtual_cursor_label.text = "◎"
	virtual_cursor_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	virtual_cursor_label.size = Vector2(36.0, 36.0)
	virtual_cursor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	virtual_cursor_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	virtual_cursor_label.add_theme_font_size_override("font_size", 28)
	virtual_cursor_label.add_theme_color_override("font_color", ACTIVE_SELECTION_BORDER)
	virtual_cursor_label.add_theme_color_override("font_outline_color", Color(0.01, 0.012, 0.02, 0.96))
	virtual_cursor_label.add_theme_constant_override("outline_size", 6)
	virtual_cursor_layer.add_child(virtual_cursor_label)
	virtual_cursor_position = get_viewport_rect().size * 0.5
	_position_virtual_cursor_label()


func _activate_virtual_cursor_if_needed() -> void:
	if right_stick_vector.length() < CURSOR_DEADZONE:
		return
	_ensure_virtual_cursor()
	if not virtual_cursor_active:
		virtual_cursor_active = true
		virtual_cursor_layer.visible = true
		var selected: Control = (
			action_controls[selected_action_index]
			if selected_action_index >= 0
			and selected_action_index < action_controls.size()
			else null
		)
		if _control_has_geometry(selected):
			virtual_cursor_position = selected.get_global_rect().get_center()
		else:
			virtual_cursor_position = get_viewport_rect().size * 0.5
		_position_virtual_cursor_label()


func _clamp_virtual_cursor() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	virtual_cursor_position.x = clampf(virtual_cursor_position.x, 12.0, viewport_size.x - 12.0)
	virtual_cursor_position.y = clampf(virtual_cursor_position.y, 12.0, viewport_size.y - 12.0)


func _position_virtual_cursor_label() -> void:
	if virtual_cursor_label == null:
		return
	virtual_cursor_label.position = virtual_cursor_position - virtual_cursor_label.size * 0.5


func _update_virtual_cursor_target() -> void:
	virtual_cursor_tab_target = -1
	for index: int in range(tab_controls.size()):
		var tab: Button = tab_controls[index]
		if _control_has_geometry(tab) and tab.get_global_rect().has_point(
			virtual_cursor_position
		):
			virtual_cursor_tab_target = index
			return
	for index: int in range(action_controls.size()):
		var control: Control = action_controls[index]
		if not _control_has_geometry(control):
			continue
		if not control.get_global_rect().has_point(virtual_cursor_position):
			continue
		if index != selected_action_index:
			selected_action_index = index
			tab_action_memory[get_current_tab_id()] = selected_action_index
			rebuild_menu()
		return


func _refresh_cursor_target_after_layout() -> void:
	await get_tree().process_frame
	if virtual_cursor_active:
		_update_virtual_cursor_target()


func _update_scroll_policy() -> void:
	if scroll_container == null:
		return
	if get_current_tab_id() == "loadout":
		scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll_container.scroll_vertical = 0
	else:
		scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO


func get_navigation_debug_data() -> Dictionary:
	return {
		"action_count": selectable_actions.size(),
		"control_count": action_controls.size(),
		"stat_quadrants": STAT_QUADRANTS.size(),
		"stat_count": 16,
		"virtual_cursor_active": virtual_cursor_active,
		"right_stick": right_stick_vector,
		"scroll_disabled": (
			scroll_container != null
			and scroll_container.vertical_scroll_mode
			== ScrollContainer.SCROLL_MODE_DISABLED
		),
	}
