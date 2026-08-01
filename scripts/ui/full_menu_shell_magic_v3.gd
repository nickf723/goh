extends "res://scripts/ui/full_menu_shell_magic_v2.gd"
class_name FullMenuShellMagicV3

const DivinePatronCatalogScript = preload(
	"res://scripts/divine/divine_patron_catalog.gd"
)

const MAGIC_PATRONS: String = "patrons"
const MAGIC_PATRON: String = "patron"
const MAGIC_INCARNATIONS: String = "incarnations"
const MAGIC_INCARNATION: String = "incarnation"

const DIVINE_GATE_BACKGROUND: Color = Color(0.105, 0.055, 0.145, 0.97)
const DIVINE_GATE_BORDER: Color = Color(0.88, 0.52, 1.0, 0.92)
const DIVINE_ACTIVE_BORDER: Color = Color(1.0, 0.78, 0.25, 1.0)

var selected_patron_id: String = ""


func activate_action(action: Dictionary) -> void:
	match str(action.get("kind", "")):
		"toggle_patron_roster":
			_toggle_patron_roster()
		"open_patron_detail":
			_open_patron_detail(str(action.get("patron_id", "")))
		"toggle_incarnation_roster":
			_toggle_incarnation_roster()
		"open_incarnation_detail":
			_open_incarnation_detail(str(action.get("patron_id", "")))
		"manifest_divine_incarnation":
			_manifest_divine_incarnation(str(action.get("avatar_id", "")))
		"dismiss_divine_incarnation":
			_dismiss_divine_incarnation()
		_:
			super.activate_action(action)


func _make_magic_atlas_panel() -> PanelContainer:
	var panel: PanelContainer = super._make_magic_atlas_panel()
	var stack: VBoxContainer = _find_first_vbox(panel)
	if stack == null:
		return panel

	stack.add_child(_make_magic_heading("DIVINE RELATIONSHIPS  •  LATE-GAME MAGIC"))
	var divine_grid: GridContainer = make_visual_grid(2)
	divine_grid.name = "MagicDivineGateGrid"
	divine_grid.add_theme_constant_override("h_separation", 8)
	stack.add_child(divine_grid)

	var contacted_count: int = 0
	for patron_id: String in DivinePatronCatalogScript.PATRON_ORDER:
		if DivinePatronCatalogScript.get_relationship_rank(patron_id) > 0:
			contacted_count += 1
	var available_incarnations: int = _get_available_incarnation_count()

	_add_divine_gate_tile(
		divine_grid,
		"✧",
		"Patrons",
		str(contacted_count) + "/16 CONTACTED",
		{"kind": "toggle_patron_roster"},
		magic_page in [MAGIC_PATRONS, MAGIC_PATRON],
		"Track Grace's relationship with each elemental patron, their covenant gifts, and the road to incarnation."
	)
	_add_divine_gate_tile(
		divine_grid,
		"♛",
		"Divine Incarnations",
		str(available_incarnations) + "/16 AVAILABLE",
		{"kind": "toggle_incarnation_roster"},
		magic_page in [MAGIC_INCARNATIONS, MAGIC_INCARNATION],
		"Inspect playable divine forms that preserve Grace as the health, camera, position, and progression anchor."
	)
	return panel


func _make_magic_expansion_panel() -> PanelContainer:
	if magic_page not in [
		MAGIC_PATRONS,
		MAGIC_PATRON,
		MAGIC_INCARNATIONS,
		MAGIC_INCARNATION,
	]:
		return super._make_magic_expansion_panel()

	var panel: PanelContainer = PanelContainer.new()
	panel.name = "MagicExpansionPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override(
		"panel",
		make_panel_style(Color(0.035, 0.045, 0.062, 0.94), CARD_BORDER, 1, 13)
	)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 9)
	panel.add_child(margin)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.name = "MagicExpansionContent"
	stack.add_theme_constant_override("separation", 7)
	margin.add_child(stack)
	match magic_page:
		MAGIC_PATRONS:
			_render_patron_roster(stack)
		MAGIC_PATRON:
			_render_patron_detail(stack)
		MAGIC_INCARNATIONS:
			_render_incarnation_roster(stack)
		MAGIC_INCARNATION:
			_render_incarnation_detail(stack)
	return panel


func _render_patron_roster(parent: VBoxContainer) -> void:
	parent.add_child(_make_magic_heading("DIVINE PATRONS  •  4 × 4"))
	var explanation: Label = Label.new()
	explanation.text = (
		"Patrons are relationships, not equipment slots. Contact opens a channel; "
		+ "Covenant grants invocations; Communion deepens authority; Incarnation permits manifestation."
	)
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation.add_theme_font_size_override("font_size", 11)
	explanation.add_theme_color_override("font_color", TEXT_SOFT)
	parent.add_child(explanation)

	var grid: GridContainer = make_visual_grid(4)
	grid.name = "MagicPatronGrid"
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 7)
	parent.add_child(grid)
	for row: Dictionary in DivinePatronCatalogScript.get_definitions():
		var patron_id: String = str(row.get("id", ""))
		var rank: int = DivinePatronCatalogScript.get_relationship_rank(patron_id)
		var badge: String = (
			DivinePatronCatalogScript.get_relationship_stage_name(patron_id).to_upper()
			+ "  "
			+ str(rank)
			+ "/4"
		)
		_add_divine_roster_tile(
			grid,
			get_spell_icon(str(row.get("element", "neutral"))),
			str(row.get("name", patron_id.capitalize())),
			badge,
			{"kind": "open_patron_detail", "patron_id": patron_id},
			str(row.get("relationship", "")),
			false
		)


func _render_patron_detail(parent: VBoxContainer) -> void:
	var patron: Dictionary = DivinePatronCatalogScript.get_definition(
		selected_patron_id
	)
	if patron.is_empty():
		magic_page = MAGIC_PATRONS
		_render_patron_roster(parent)
		return
	var element_id: String = str(patron.get("element", "neutral"))
	var rank: int = DivinePatronCatalogScript.get_relationship_rank(
		selected_patron_id
	)
	parent.add_child(
		_make_magic_heading(
			get_spell_icon(element_id)
			+ "  "
			+ str(patron.get("name", selected_patron_id.capitalize())).to_upper()
			+ "  •  "
			+ element_id.to_upper()
		)
	)

	var summary: GridContainer = make_visual_grid(4)
	summary.add_theme_constant_override("h_separation", 7)
	parent.add_child(summary)
	_add_magic_info_panel(summary, str(patron.get("hue", "Elemental")).to_upper(), "Color identity")
	_add_magic_info_panel(summary, str(patron.get("weapon", "Unknown")).to_upper(), "Signature weapon")
	_add_magic_info_panel(
		summary,
		DivinePatronCatalogScript.get_relationship_stage_name(selected_patron_id).to_upper(),
		"Relationship " + str(rank) + "/4"
	)
	_add_magic_info_panel(
		summary,
		_get_incarnation_status(selected_patron_id),
		"Divine Incarnation"
	)

	var relationship: Label = Label.new()
	relationship.text = str(patron.get("relationship", "No relationship description yet."))
	relationship.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	relationship.add_theme_font_size_override("font_size", 12)
	relationship.add_theme_color_override("font_color", TEXT_SOFT)
	parent.add_child(relationship)

	parent.add_child(_make_magic_heading("RELATIONSHIP PATH"))
	var stage_grid: GridContainer = make_visual_grid(4)
	stage_grid.add_theme_constant_override("h_separation", 7)
	parent.add_child(stage_grid)
	for stage_index: int in range(DivinePatronCatalogScript.RELATIONSHIP_STAGES.size()):
		var stage: Dictionary = DivinePatronCatalogScript.RELATIONSHIP_STAGES[stage_index]
		var unlocked: bool = rank > stage_index
		_add_magic_info_panel(
			stage_grid,
			("◆ " if unlocked else "◇ ")
			+ str(stage.get("name", "Stage")).to_upper(),
			("COMPLETE  •  " if unlocked else "LOCKED  •  ")
			+ str(stage.get("description", ""))
		)

	parent.add_child(_make_magic_heading("COVENANT GIFTS"))
	var gift_grid: GridContainer = make_visual_grid(3)
	gift_grid.add_theme_constant_override("h_separation", 7)
	parent.add_child(gift_grid)
	_add_magic_info_panel(
		gift_grid,
		"DIVINE SPECIALS",
		"Covenant unlocks prepared patron miracles and their charge economy."
	)
	_add_magic_info_panel(
		gift_grid,
		"ELEMENTAL AUTHORITY",
		"Communion strengthens the patron's element, techniques, and world interactions."
	)
	_add_magic_info_panel(
		gift_grid,
		"DIVINE INCARNATION",
		"The final bond manifests the patron while Grace remains the stable world anchor."
	)

	var jump_grid: GridContainer = make_visual_grid(1)
	parent.add_child(jump_grid)
	_add_divine_roster_tile(
		jump_grid,
		"♛",
		"View Incarnation",
		_get_incarnation_status(selected_patron_id),
		{"kind": "open_incarnation_detail", "patron_id": selected_patron_id},
		"Open this patron's playable-form record.",
		true
	)


func _render_incarnation_roster(parent: VBoxContainer) -> void:
	parent.add_child(_make_magic_heading("DIVINE INCARNATIONS  •  4 × 4"))
	var explanation: Label = Label.new()
	explanation.text = (
		"Each incarnation replaces Grace's active combat kit and presentation without replacing her health, "
		+ "position, camera, inventory, or progression. Most forms remain sealed until the matching patron bond matures."
	)
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation.add_theme_font_size_override("font_size", 11)
	explanation.add_theme_color_override("font_color", TEXT_SOFT)
	parent.add_child(explanation)

	var grid: GridContainer = make_visual_grid(4)
	grid.name = "MagicIncarnationGrid"
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 7)
	parent.add_child(grid)
	var active_id: String = _get_active_avatar_id()
	for row: Dictionary in DivinePatronCatalogScript.get_definitions():
		var patron_id: String = str(row.get("id", ""))
		var status: String = _get_incarnation_status(patron_id)
		_add_divine_roster_tile(
			grid,
			get_spell_icon(str(row.get("element", "neutral"))),
			str(row.get("name", patron_id.capitalize())),
			"ACTIVE" if active_id == patron_id else status,
			{"kind": "open_incarnation_detail", "patron_id": patron_id},
			"Inspect the " + str(row.get("element", "elemental")).capitalize() + " Divine Incarnation.",
			active_id == patron_id or status in ["AVAILABLE", "DEBUG PROTOTYPE"]
		)


func _render_incarnation_detail(parent: VBoxContainer) -> void:
	var patron: Dictionary = DivinePatronCatalogScript.get_definition(
		selected_patron_id
	)
	if patron.is_empty():
		magic_page = MAGIC_INCARNATIONS
		_render_incarnation_roster(parent)
		return
	var element_id: String = str(patron.get("element", "neutral"))
	var definition: PlayableAvatarDefinition = _get_avatar_definition(
		selected_patron_id
	)
	parent.add_child(
		_make_magic_heading(
			"♛  "
			+ str(patron.get("name", selected_patron_id.capitalize())).to_upper()
			+ "  •  DIVINE INCARNATION"
		)
	)

	var summary: GridContainer = make_visual_grid(4)
	summary.add_theme_constant_override("h_separation", 7)
	parent.add_child(summary)
	_add_magic_info_panel(summary, element_id.to_upper(), "Absolute element")
	_add_magic_info_panel(summary, str(patron.get("weapon", "Unknown")).to_upper(), "Signature weapon")
	_add_magic_info_panel(summary, _get_incarnation_status(selected_patron_id), "Availability")
	_add_magic_info_panel(
		summary,
		("IMPLEMENTED" if definition != null else "PLANNED"),
		"Runtime form"
	)

	if definition == null:
		var planned: Label = Label.new()
		planned.text = (
			"This incarnation has a reserved place in the sixteen-form atlas. Its weapon language, elemental authority, "
			+ "movement identity, spell kit, and presentation profile will attach to the same stable-avatar contract used by Ruvia."
		)
		planned.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		planned.add_theme_font_size_override("font_size", 12)
		planned.add_theme_color_override("font_color", TEXT_SOFT)
		parent.add_child(planned)
		_render_incarnation_contract(parent)
		return

	var description: Label = Label.new()
	description.text = definition.description
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 12)
	description.add_theme_color_override("font_color", TEXT_SOFT)
	parent.add_child(description)

	var kit_grid: GridContainer = make_visual_grid(4)
	kit_grid.add_theme_constant_override("h_separation", 7)
	parent.add_child(kit_grid)
	_add_magic_info_panel(
		kit_grid,
		definition.weapon_definition.display_name.to_upper()
		if definition.weapon_definition != null
		else "NO WEAPON",
		"Incarnation weapon"
	)
	_add_magic_info_panel(
		kit_grid,
		str(
			definition.ability_loadout.get_equipped_ability_count()
			if definition.ability_loadout != null
			else 0
		) + " SPELLS",
		"Prepared authority kit"
	)
	_add_magic_info_panel(
		kit_grid,
		("PERMANENT" if definition.manifestation_duration <= 0.0 else str(roundi(definition.manifestation_duration)) + " SEC"),
		"Manifestation duration"
	)
	_add_magic_info_panel(
		kit_grid,
		definition.required_unlock_id.replace("_", " ").to_upper(),
		"Unlock requirement"
	)

	_render_incarnation_contract(parent)
	var action_grid: GridContainer = make_visual_grid(1)
	parent.add_child(action_grid)
	var active_id: String = _get_active_avatar_id()
	if active_id == definition.avatar_id:
		_add_divine_roster_tile(
			action_grid,
			"◇",
			"Return to Grace",
			"ACTIVE INCARNATION",
			{"kind": "dismiss_divine_incarnation"},
			"Dismiss the current incarnation while preserving Grace's world anchor.",
			true
		)
	elif _is_avatar_available(definition):
		_add_divine_roster_tile(
			action_grid,
			"♛",
			"Manifest " + definition.display_name,
			"DEBUG PROTOTYPE" if OS.is_debug_build() and definition.debug_available else "AVAILABLE",
			{"kind": "manifest_divine_incarnation", "avatar_id": definition.avatar_id},
			"Activate this playable divine form. The full menu remains open until dismissed normally.",
			true
		)
	else:
		_add_magic_info_panel(
			action_grid,
			"INCARNATION SEALED",
			"Complete the required patron and spellcasting milestones before this form can manifest."
		)


func _render_incarnation_contract(parent: VBoxContainer) -> void:
	parent.add_child(_make_magic_heading("STABLE AVATAR CONTRACT"))
	var contract: GridContainer = make_visual_grid(4)
	contract.add_theme_constant_override("h_separation", 7)
	parent.add_child(contract)
	_add_magic_info_panel(contract, "SHARED HEALTH", "Grace remains the life anchor.")
	_add_magic_info_panel(contract, "SHARED WORLD POSITION", "No teleport or replacement actor.")
	_add_magic_info_panel(contract, "SHARED CAMERA", "The player's viewpoint remains stable.")
	_add_magic_info_panel(contract, "SHARED PROGRESSION", "Inventory and records remain Grace's.")


func _add_divine_gate_tile(
	parent: Container,
	icon_text: String,
	title: String,
	badge: String,
	action: Dictionary,
	is_open: bool,
	tooltip: String
) -> void:
	_add_divine_styled_action(
		parent,
		("▾ " if is_open else "▸ ") + icon_text,
		title,
		badge,
		action,
		tooltip,
		52.0,
		is_open
	)


func _add_divine_roster_tile(
	parent: Container,
	icon_text: String,
	title: String,
	badge: String,
	action: Dictionary,
	tooltip: String,
	is_available: bool
) -> void:
	_add_divine_styled_action(
		parent,
		icon_text,
		title,
		badge,
		action,
		tooltip,
		64.0,
		is_available
	)


func _add_divine_styled_action(
	parent: Container,
	icon_text: String,
	title: String,
	badge: String,
	action: Dictionary,
	tooltip: String,
	minimum_height: float,
	accented: bool
) -> void:
	var action_index: int = selectable_actions.size()
	selectable_actions.append(action.duplicate(true))
	var selected: bool = action_index == selected_action_index
	var button: Button = Button.new()
	button.text = icon_text + "\n" + title + "\n" + badge
	button.tooltip_text = tooltip
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(104.0, minimum_height)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 9 if minimum_height <= 54.0 else 10)
	button.add_theme_color_override("font_color", TEXT_MAIN if selected or accented else TEXT_SOFT)
	button.add_theme_stylebox_override(
		"normal",
		make_panel_style(
			ACTIVE_SELECTION_BACKGROUND if selected else DIVINE_GATE_BACKGROUND,
			ACTIVE_SELECTION_BORDER if selected else (DIVINE_ACTIVE_BORDER if accented else DIVINE_GATE_BORDER.darkened(0.28)),
			3 if selected else (2 if accented else 1),
			10
		)
	)
	button.add_theme_stylebox_override(
		"focus",
		make_panel_style(ACTIVE_SELECTION_BACKGROUND, ACTIVE_SELECTION_BORDER, 3, 10)
	)
	button.add_theme_stylebox_override(
		"hover",
		make_panel_style(Color(0.17, 0.08, 0.21, 0.98), DIVINE_GATE_BORDER, 2, 10)
	)
	button.pressed.connect(_on_action_row_pressed.bind(action_index))
	button.mouse_entered.connect(_on_action_row_hovered.bind(action_index))
	parent.add_child(button)
	_register_action_control(button, action_index)
	if selected:
		schedule_selected_control(button)


func _toggle_patron_roster() -> void:
	if magic_page in [MAGIC_PATRONS, MAGIC_PATRON]:
		_reset_magic_workspace()
	else:
		magic_page = MAGIC_PATRONS
		selected_patron_id = ""
		selected_magic_element = ""
		selected_magic_spell_id = ""
		selected_magic_tradition_id = ""
	selected_action_index = 24
	tab_action_memory["magic"] = selected_action_index
	rebuild_menu()


func _open_patron_detail(patron_id: String) -> void:
	if not DivinePatronCatalogScript.has_patron(patron_id):
		return
	magic_page = MAGIC_PATRON
	selected_patron_id = patron_id
	selected_magic_element = ""
	selected_magic_spell_id = ""
	selected_magic_tradition_id = ""
	selected_action_index = 26 + DivinePatronCatalogScript.PATRON_ORDER.find(patron_id)
	rebuild_menu()


func _toggle_incarnation_roster() -> void:
	if magic_page in [MAGIC_INCARNATIONS, MAGIC_INCARNATION]:
		_reset_magic_workspace()
	else:
		magic_page = MAGIC_INCARNATIONS
		selected_patron_id = ""
		selected_magic_element = ""
		selected_magic_spell_id = ""
		selected_magic_tradition_id = ""
	selected_action_index = 25
	tab_action_memory["magic"] = selected_action_index
	rebuild_menu()


func _open_incarnation_detail(patron_id: String) -> void:
	if not DivinePatronCatalogScript.has_patron(patron_id):
		return
	magic_page = MAGIC_INCARNATION
	selected_patron_id = patron_id
	selected_magic_element = ""
	selected_magic_spell_id = ""
	selected_magic_tradition_id = ""
	selected_action_index = 26 + DivinePatronCatalogScript.PATRON_ORDER.find(patron_id)
	rebuild_menu()


func _manifest_divine_incarnation(avatar_id: String) -> void:
	var manager: Node = _get_avatar_manager()
	if manager == null or not manager.has_method("incarnate_by_id"):
		_show_magic_message("No Divine Incarnation manager is available.")
		return
	var success: bool = bool(
		manager.call("incarnate_by_id", avatar_id, OS.is_debug_build())
	)
	_show_magic_message(
		("Incarnated as " + avatar_id.capitalize() + ".")
		if success
		else ("Incarnation failed: " + avatar_id.capitalize() + ".")
	)
	rebuild_menu()


func _dismiss_divine_incarnation() -> void:
	var manager: Node = _get_avatar_manager()
	if manager == null or not manager.has_method("dismiss_avatar"):
		_show_magic_message("No active Divine Incarnation manager is available.")
		return
	var success: bool = bool(manager.call("dismiss_avatar", "magic_menu"))
	_show_magic_message("Grace restored." if success else "The incarnation could not be dismissed.")
	rebuild_menu()


func _back_magic_workspace() -> void:
	match magic_page:
		MAGIC_PATRON:
			magic_page = MAGIC_PATRONS
			selected_action_index = 24
		MAGIC_PATRONS:
			_reset_magic_workspace()
			selected_action_index = 24
		MAGIC_INCARNATION:
			magic_page = MAGIC_INCARNATIONS
			selected_action_index = 25
		MAGIC_INCARNATIONS:
			_reset_magic_workspace()
			selected_action_index = 25
		_:
			super._back_magic_workspace()
			return
	tab_action_memory["magic"] = selected_action_index
	rebuild_menu()


func _reset_magic_workspace() -> void:
	super._reset_magic_workspace()
	selected_patron_id = ""


func _get_magic_page_title() -> String:
	match magic_page:
		MAGIC_PATRONS:
			return "✦ Magic  ›  Patrons"
		MAGIC_PATRON:
			var patron: Dictionary = DivinePatronCatalogScript.get_definition(selected_patron_id)
			return "✦ Magic  ›  Patron  ›  " + str(patron.get("name", selected_patron_id.capitalize()))
		MAGIC_INCARNATIONS:
			return "✦ Magic  ›  Divine Incarnations"
		MAGIC_INCARNATION:
			var patron: Dictionary = DivinePatronCatalogScript.get_definition(selected_patron_id)
			return "✦ Magic  ›  Incarnation  ›  " + str(patron.get("name", selected_patron_id.capitalize()))
	return super._get_magic_page_title()


func _get_avatar_manager() -> Node:
	return get_tree().get_first_node_in_group("player_avatar_manager")


func _get_avatar_definition(patron_id: String) -> PlayableAvatarDefinition:
	var manager: Node = _get_avatar_manager()
	if manager == null or not manager.has_method("get_avatar_definition"):
		return null
	return manager.call("get_avatar_definition", patron_id) as PlayableAvatarDefinition


func _is_avatar_available(definition: PlayableAvatarDefinition) -> bool:
	if definition == null:
		return false
	var manager: Node = _get_avatar_manager()
	if manager != null and manager.has_method("is_avatar_unlocked"):
		if bool(manager.call("is_avatar_unlocked", definition)):
			return true
	return OS.is_debug_build() and definition.debug_available


func _get_active_avatar_id() -> String:
	var manager: Node = _get_avatar_manager()
	if manager != null and manager.has_method("get_active_avatar_id"):
		return str(manager.call("get_active_avatar_id"))
	return ""


func _get_incarnation_status(patron_id: String) -> String:
	if _get_active_avatar_id() == patron_id:
		return "ACTIVE"
	var definition: PlayableAvatarDefinition = _get_avatar_definition(patron_id)
	if definition != null:
		if _is_avatar_available(definition):
			return "DEBUG PROTOTYPE" if OS.is_debug_build() and definition.debug_available else "AVAILABLE"
		return "IMPLEMENTED • SEALED"
	if DivinePatronCatalogScript.is_incarnation_unlocked(patron_id):
		return "UNLOCKED • UNBUILT"
	return "SEALED"


func _get_available_incarnation_count() -> int:
	var count: int = 0
	for patron_id: String in DivinePatronCatalogScript.PATRON_ORDER:
		var definition: PlayableAvatarDefinition = _get_avatar_definition(patron_id)
		if _is_avatar_available(definition):
			count += 1
	return count


func _find_first_vbox(node: Node) -> VBoxContainer:
	if node is VBoxContainer:
		return node as VBoxContainer
	for child: Node in node.get_children():
		var found: VBoxContainer = _find_first_vbox(child)
		if found != null:
			return found
	return null


func get_magic_debug_data() -> Dictionary:
	var data: Dictionary = super.get_magic_debug_data()
	data["patron_count"] = DivinePatronCatalogScript.PATRON_ORDER.size()
	data["divine_gate_count"] = 2
	data["selected_patron"] = selected_patron_id
	data["divine_gates_present"] = find_child("MagicDivineGateGrid", true, false) != null
	data["patron_grid_present"] = find_child("MagicPatronGrid", true, false) != null
	data["incarnation_grid_present"] = find_child("MagicIncarnationGrid", true, false) != null
	return data
