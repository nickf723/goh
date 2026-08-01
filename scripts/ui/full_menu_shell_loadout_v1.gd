extends "res://scripts/ui/full_menu_shell_settings.gd"
class_name FullMenuShellLoadoutV1

const MenuEquipmentCatalog = preload("res://scripts/equipment/equipment_catalog.gd")
const MenuInfusionCatalog = preload("res://scripts/weapons/weapon_infusion_catalog.gd")

const LOADOUT_OVERVIEW: String = "overview"
const LOADOUT_EQUIPMENT: String = "equipment"
const LOADOUT_INFUSION: String = "infusion"
const LOADOUT_SPELLS: String = "spells"
const LOADOUT_BELT: String = "belt"
const LOADOUT_SPECIAL: String = "special"
const LOADOUT_FAMILIAR: String = "familiar"

var loadout_page: String = LOADOUT_OVERVIEW
var loadout_return_action_index: int = 0


func hide_menu() -> void:
	loadout_page = LOADOUT_OVERVIEW
	super.hide_menu()


func select_tab(index: int) -> void:
	if get_current_tab_id() == "loadout" and loadout_page != LOADOUT_OVERVIEW:
		loadout_page = LOADOUT_OVERVIEW
	super.select_tab(index)


func handle_menu_input(event: InputEvent) -> bool:
	if (
		visible
		and event.is_action_pressed("ui_cancel")
		and get_current_tab_id() == "loadout"
		and loadout_page != LOADOUT_OVERVIEW
		and not is_assignment_active()
	):
		_return_to_loadout_overview()
		return true
	return super.handle_menu_input(event)


func activate_action(action: Dictionary) -> void:
	match str(action.get("kind", "")):
		"open_loadout_page":
			_open_loadout_page(str(action.get("page", LOADOUT_OVERVIEW)))
		"select_divine_special":
			_select_divine_special(str(action.get("special_id", "")))
		_:
			super.activate_action(action)


func get_footer_text() -> String:
	if is_assignment_active():
		return super.get_footer_text()
	if get_current_tab_id() == "loadout":
		if loadout_page == LOADOUT_OVERVIEW:
			return "LB/RB or Q/E: tabs  •  D-pad/Stick or WASD: category  •  A/Enter: open  •  B/Esc: close"
		return "D-pad/Stick or WASD: move  •  A/Enter: equip or select  •  B/Esc: Loadout overview"
	return super.get_footer_text()


func render_loadout() -> void:
	if is_assigning_equipment():
		render_equipment_picker()
		return

	match loadout_page:
		LOADOUT_EQUIPMENT:
			_render_equipment_page()
		LOADOUT_INFUSION:
			_render_infusion_page()
		LOADOUT_SPELLS:
			_render_spell_ring_page()
		LOADOUT_BELT:
			_render_quick_belt_page()
		LOADOUT_SPECIAL:
			_render_divine_special_page()
		LOADOUT_FAMILIAR:
			_render_familiar_page()
		_:
			_render_loadout_overview()


func _render_loadout_overview() -> void:
	content_title_label.text = "⚔ Loadout"
	action_grid_columns = 3
	action_layout_mode = "grid"

	var summary: Dictionary = menu_data.get("loadout_summary", {})
	var special_summary: Dictionary = _get_divine_special_summary()
	var familiar_data: Dictionary = _familiar_dictionary(menu_data.get("familiar_mastery", {}))
	var equipped_spell_slots: Array = menu_data.get("equipped_spell_slots", [])
	var quick_item_slots: Array = menu_data.get("quick_item_slots", [])

	add_summary_card([
		"Equipment " + _get_equipment_slot_count_label(),
		"Spell Ring " + str(_count_nonempty_rows(equipped_spell_slots)) + "/" + str(equipped_spell_slots.size()),
		"Quick Belt " + str(_count_nonempty_rows(quick_item_slots)) + "/" + str(quick_item_slots.size()),
		"Known spells " + str(summary.get("learned_count", 0)),
	])

	add_section_header("ACTIVE FIELD KIT")
	var overview_grid: GridContainer = make_visual_grid(3)
	content_box.add_child(overview_grid)

	add_visual_action_tile(
		overview_grid,
		"⚔",
		"Equipment",
		_get_equipment_summary(),
		{"kind": "open_loadout_page", "page": LOADOUT_EQUIPMENT},
		"Choose Grace's weapon, outfit, charm, and relic slots."
	)

	var infusion_id: String = GameState.get_weapon_infusion()
	var infusion: Dictionary = MenuInfusionCatalog.get_definition(infusion_id)
	add_visual_action_tile(
		overview_grid,
		str(infusion.get("icon", "◇")),
		"Weapon Infusion",
		str(infusion.get("name", "Uninfused")).to_upper(),
		{"kind": "open_loadout_page", "page": LOADOUT_INFUSION},
		str(infusion.get("description", "Choose an elemental edge for the active weapon."))
	)

	add_visual_action_tile(
		overview_grid,
		"✦",
		"Spell Ring",
		str(_count_nonempty_rows(equipped_spell_slots)) + "/" + str(equipped_spell_slots.size()) + " EQUIPPED",
		{"kind": "open_loadout_page", "page": LOADOUT_SPELLS},
		"Assign learned spells to the active ten-slot combat ring."
	)

	add_visual_action_tile(
		overview_grid,
		"🧪",
		"Quick Belt",
		str(_count_nonempty_rows(quick_item_slots)) + "/" + str(quick_item_slots.size()) + " DIRECTIONS",
		{"kind": "open_loadout_page", "page": LOADOUT_BELT},
		"Assign consumables to the four quick-item D-pad directions."
	)

	add_visual_action_tile(
		overview_grid,
		"☀",
		"Divine Special",
		str(special_summary.get("badge", "UNAVAILABLE")),
		{"kind": "open_loadout_page", "page": LOADOUT_SPECIAL},
		str(special_summary.get("description", "Choose Grace's currently prepared Divine Special."))
	)

	var familiar_name: String = str(familiar_data.get("equipped_name", "None"))
	var familiar_summary: Dictionary = _familiar_dictionary(familiar_data.get("summary", {}))
	add_visual_action_tile(
		overview_grid,
		"◇",
		"Familiar Blueprint",
		(familiar_name.to_upper() if familiar_name != "" else "NONE")
		+ "  •  "
		+ str(familiar_summary.get("familiars_unlocked", 0))
		+ " UNLOCKED",
		{"kind": "open_loadout_page", "page": LOADOUT_FAMILIAR},
		"Prepare a creature role, temperament, opening command, and equipped techniques."
	)

	add_text_card(
		"Close-to-Play Contract",
		"Every choice on this page should be active the moment the menu closes. The menu pauses the world and never spends items, casts spells, or activates Divine Specials while navigating.",
		"✓",
		"Prepared loadout"
	)


func _render_equipment_page() -> void:
	content_title_label.text = "⚔ Loadout  ›  Equipment"
	action_grid_columns = 4
	action_layout_mode = "grid"
	add_assignment_banner(
		"Equipment",
		"Choose a slot, then choose owned gear  •  B/Esc returns to the Loadout overview"
	)
	var equipment_grid: GridContainer = make_visual_grid(4)
	content_box.add_child(equipment_grid)
	for slot_id: String in MenuEquipmentCatalog.SLOT_ORDER:
		var equipped_item_id: String = GameState.get_equipped_item(slot_id)
		var definition: Dictionary = MenuEquipmentCatalog.get_definition(equipped_item_id)
		var item_name: String = str(definition.get("name", "Empty"))
		var item_icon: String = str(definition.get("icon", "◇"))
		var modifiers: Dictionary = definition.get("modifiers", {}) as Dictionary
		var badge: String = slot_id.to_upper()
		if not modifiers.is_empty():
			badge += "  •  " + MenuEquipmentCatalog.format_modifiers(modifiers)
		var effect_names: String = MenuEquipmentCatalog.format_effects(equipped_item_id)
		if effect_names != "":
			badge += "  •  " + effect_names
		var tooltip: String = str(definition.get("description", "Choose owned gear for this slot."))
		var effect_details: String = MenuEquipmentCatalog.format_effects(equipped_item_id, true)
		if effect_details != "":
			tooltip += "\n" + effect_details
		add_visual_action_tile(
			equipment_grid,
			item_icon,
			item_name,
			badge,
			{"kind": "choose_equipment_slot", "slot_id": slot_id},
			tooltip
		)


func _render_infusion_page() -> void:
	content_title_label.text = "⚔ Loadout  ›  Weapon Infusion"
	action_grid_columns = 4
	action_layout_mode = "grid"
	var active_infusion: String = GameState.get_weapon_infusion()
	var active_definition: Dictionary = MenuInfusionCatalog.get_definition(active_infusion)
	add_summary_card([
		"Active " + str(active_definition.get("name", "Uninfused")),
		"Element " + str(active_definition.get("element", "neutral")).capitalize(),
		"Select the active edge again to remove it",
	])
	add_section_header("ELEMENTAL EDGES")
	var infusion_grid: GridContainer = make_visual_grid(4)
	content_box.add_child(infusion_grid)
	for infusion: Dictionary in MenuInfusionCatalog.get_rows():
		var infusion_id: String = str(infusion.get("id", ""))
		var is_active: bool = infusion_id == active_infusion
		var badge: String = "EQUIPPED  •  SELECT TO REMOVE" if is_active else "SELECT TO INFUSE"
		add_visual_action_tile(
			infusion_grid,
			str(infusion.get("icon", "◇")),
			str(infusion.get("name", infusion_id.capitalize())),
			badge,
			{"kind": "set_weapon_infusion", "infusion_id": infusion_id},
			str(infusion.get("description", ""))
		)


func _render_spell_ring_page() -> void:
	content_title_label.text = "⚔ Loadout  ›  Spell Ring"
	action_grid_columns = 4
	action_layout_mode = "grid"
	var equipped_slots: Array = menu_data.get("equipped_spell_slots", [])
	add_summary_card([
		"Equipped " + str(_count_nonempty_rows(equipped_slots)) + "/" + str(equipped_slots.size()),
		"Select a slot to browse learned spells",
		"Assignments update combat immediately",
	])
	var spell_grid: GridContainer = make_visual_grid(4)
	content_box.add_child(spell_grid)
	for slot_variant: Variant in equipped_slots:
		if not slot_variant is Dictionary:
			continue
		var spell: Dictionary = slot_variant as Dictionary
		var slot_index: int = int(spell.get("slot", 0))
		var is_empty: bool = bool(spell.get("is_empty", false))
		var icon_text: String = "✦" if is_empty else get_spell_icon(str(spell.get("element", "neutral")))
		var spell_name: String = "Empty" if is_empty else str(spell.get("name", "Spell"))
		var badge: String = "RING " + str(slot_index + 1)
		if not is_empty:
			badge += "  •  " + get_spell_cost_label(spell)
		add_visual_action_tile(
			spell_grid,
			icon_text,
			spell_name,
			badge,
			{"kind": "choose_spell_slot", "slot": slot_index},
			str(spell.get("description", "Select to assign a learned spell."))
		)


func _render_quick_belt_page() -> void:
	content_title_label.text = "⚔ Loadout  ›  Quick Belt"
	action_grid_columns = 4
	action_layout_mode = "grid"
	var item_slots: Array = menu_data.get("quick_item_slots", [])
	var total_charges: int = 0
	for slot_variant: Variant in item_slots:
		if slot_variant is Dictionary:
			total_charges += int((slot_variant as Dictionary).get("count", 0))
	add_summary_card([
		"Assigned " + str(_count_nonempty_rows(item_slots)) + "/" + str(item_slots.size()),
		"Available charges " + str(total_charges),
		"Select a direction to assign an owned quick item",
	])
	var belt_grid: GridContainer = make_visual_grid(4)
	content_box.add_child(belt_grid)
	for slot_variant: Variant in item_slots:
		if not slot_variant is Dictionary:
			continue
		var item_slot: Dictionary = slot_variant as Dictionary
		var is_empty: bool = bool(item_slot.get("is_empty", true))
		var item_name: String = "Empty" if is_empty else str(item_slot.get("name", "Item"))
		var item_icon: String = "◇" if is_empty else str(item_slot.get("icon", "◇"))
		var direction: String = str(item_slot.get("direction", "Slot"))
		var badge: String = get_direction_symbol(direction) + "  D-PAD " + direction.to_upper()
		if not is_empty:
			badge += "  •  ×" + str(item_slot.get("count", 0))
		add_visual_action_tile(
			belt_grid,
			item_icon,
			item_name,
			badge,
			{"kind": "choose_item_slot", "slot": int(item_slot.get("slot", 0))},
			"Choose the item assigned to this quick direction."
		)


func _render_divine_special_page() -> void:
	content_title_label.text = "⚔ Loadout  ›  Divine Special"
	action_grid_columns = 3
	action_layout_mode = "grid"
	var controller: Node = _get_divine_special_controller()
	if controller == null:
		add_visual_info_card(
			"☀",
			"Divine Specials Unavailable",
			"The current player does not contain a Divine Special controller.",
			"Loadout"
		)
		return

	var force_debug: bool = OS.is_debug_build()
	var selected: DivineSpecialDefinition = controller.call("get_selected_special", force_debug) as DivineSpecialDefinition
	var charge: float = float(controller.get("divine_charge"))
	var maximum: float = maxf(float(controller.get("maximum_charge")), 1.0)
	add_summary_card([
		"Selected " + (selected.display_name if selected != null else "None"),
		"Divine Charge " + str(roundi(charge)) + "/" + str(roundi(maximum)),
		"D-pad Down tap activates in gameplay",
		"Hold D-pad Down opens the radial selector",
	])
	add_section_header("UNLOCKED SPECIALS")
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
		var badge: String = "SELECTED" if is_selected else "SELECT"
		badge += "  •  " + str(roundi(definition.required_charge)) + " CHARGE"
		badge += "  •  " + str(roundi(definition.recharge_seconds)) + "S RECHARGE"
		add_visual_action_tile(
			special_grid,
			"☀",
			definition.display_name,
			badge,
			{"kind": "select_divine_special", "special_id": definition.special_id},
			definition.description
		)


func _render_familiar_page() -> void:
	content_title_label.text = "⚔ Loadout  ›  Familiar Blueprint"
	action_grid_columns = 4
	action_layout_mode = "grid"
	_render_familiar_mastery()


func _open_loadout_page(page: String) -> void:
	if page not in [
		LOADOUT_EQUIPMENT,
		LOADOUT_INFUSION,
		LOADOUT_SPELLS,
		LOADOUT_BELT,
		LOADOUT_SPECIAL,
		LOADOUT_FAMILIAR,
	]:
		return
	loadout_return_action_index = selected_action_index
	loadout_page = page
	selected_action_index = 0
	tab_action_memory["loadout"] = 0
	rebuild_menu()


func _return_to_loadout_overview() -> void:
	loadout_page = LOADOUT_OVERVIEW
	selected_action_index = max(loadout_return_action_index, 0)
	tab_action_memory["loadout"] = selected_action_index
	rebuild_menu()


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
		return {
			"badge": "UNAVAILABLE",
			"description": "The current player does not contain a Divine Special controller.",
		}
	var selected: DivineSpecialDefinition = controller.call(
		"get_selected_special",
		OS.is_debug_build()
	) as DivineSpecialDefinition
	var charge: float = float(controller.get("divine_charge"))
	var maximum: float = maxf(float(controller.get("maximum_charge")), 1.0)
	if selected == null:
		return {
			"badge": "NONE SELECTED  •  " + str(roundi(charge / maximum * 100.0)) + "% CHARGE",
			"description": "Unlock a patron Special to prepare it here.",
		}
	return {
		"badge": selected.display_name.to_upper() + "  •  " + str(roundi(charge / maximum * 100.0)) + "% CHARGE",
		"description": selected.description,
	}


func _get_equipment_slot_count_label() -> String:
	var occupied: int = 0
	for slot_id: String in MenuEquipmentCatalog.SLOT_ORDER:
		if GameState.get_equipped_item(slot_id) != "":
			occupied += 1
	return str(occupied) + "/" + str(MenuEquipmentCatalog.SLOT_ORDER.size())


func _get_equipment_summary() -> String:
	var weapon_id: String = GameState.get_equipped_item("weapon")
	var weapon: Dictionary = MenuEquipmentCatalog.get_definition(weapon_id)
	return str(weapon.get("name", "No Weapon")).to_upper() + "  •  " + _get_equipment_slot_count_label() + " SLOTS"


func _count_nonempty_rows(rows: Array) -> int:
	var count: int = 0
	for row_value: Variant in rows:
		if not row_value is Dictionary:
			continue
		if not bool((row_value as Dictionary).get("is_empty", false)):
			count += 1
	return count
