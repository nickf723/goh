extends "res://scripts/ui/full_menu_shell_loadout_v2.gd"
class_name FullMenuShellMagicV1

const ElementalAugmentationCatalogScript = preload(
	"res://scripts/abilities/elemental_augmentation_catalog.gd"
)
const SpellProgressionCatalogScript = preload(
	"res://scripts/abilities/spell_progression_catalog.gd"
)
const SpellcastingTraditionCatalogScript = preload(
	"res://scripts/progression/spellcasting_tradition_catalog.gd"
)

const MAGIC_OVERVIEW: String = "overview"
const MAGIC_ELEMENT: String = "element"
const MAGIC_SPELL: String = "spell"
const MAGIC_TRADITION: String = "tradition"
const MAGIC_AUGMENTATION: String = "augmentation"

const ELEMENT_ORDER: Array[String] = [
	"water", "earth", "fire", "air",
	"ice", "metal", "lightning", "poison",
	"life", "death", "body", "soul",
	"dreams", "sound", "space", "time",
]

var magic_page: String = MAGIC_OVERVIEW
var selected_magic_element: String = ""
var selected_magic_spell_id: String = ""
var selected_magic_tradition_id: String = ""
var selected_familiar_species_id: String = ""


func hide_menu() -> void:
	_reset_magic_workspace()
	super.hide_menu()


func select_tab(index: int) -> void:
	if get_current_tab_id() == "magic":
		_reset_magic_workspace()
	super.select_tab(index)


func handle_menu_input(event: InputEvent) -> bool:
	if not visible:
		return false
	if get_current_tab_id() == "magic":
		var cancel_requested: bool = (
			is_menu_cancel_event(event)
			if event is InputEventJoypadButton
			else event.is_action_pressed("ui_cancel")
		)
		if cancel_requested and not is_assignment_active():
			if magic_page != MAGIC_OVERVIEW:
				_back_magic_workspace()
				return true
	return super.handle_menu_input(event)


func activate_action(action: Dictionary) -> void:
	match str(action.get("kind", "")):
		"toggle_magic_element":
			_toggle_magic_element(str(action.get("element", "")))
		"open_magic_spell":
			_open_magic_spell(str(action.get("spell_id", "")))
		"toggle_magic_tradition":
			_toggle_magic_tradition(str(action.get("tradition_id", "")))
		"open_element_augmentation":
			_open_element_augmentation(str(action.get("element", "")))
		"set_elemental_augmentation":
			_set_elemental_augmentation(
				str(action.get("source", "")),
				str(action.get("target", ""))
			)
		"inspect_spell_property":
			_show_magic_message(
				str(action.get("message", "This property is currently authored by the spell resource."))
			)
		"inspect_spell_upgrade":
			_show_magic_message(
				str(action.get("message", "This upgrade branch is reserved for spell proficiency."))
			)
		"select_familiar_species":
			selected_familiar_species_id = str(action.get("species_id", ""))
			rebuild_menu()
		_:
			super.activate_action(action)


func get_footer_text() -> String:
	if get_current_tab_id() == "magic" and not is_assignment_active():
		if magic_page == MAGIC_OVERVIEW:
			return "L/R: tabs  •  D-pad or left stick: navigate  •  Right stick: cursor  •  A: expand  •  B: close"
		return "D-pad or left stick: navigate  •  Right stick: cursor  •  A: choose  •  B: collapse one level"
	return super.get_footer_text()


func render_magic() -> void:
	content_title_label.text = _get_magic_page_title()
	action_layout_mode = "screen_geometry"
	action_grid_columns = 1
	_update_scroll_policy()

	var workspace: HBoxContainer = HBoxContainer.new()
	workspace.name = "MagicAtlasWorkspace"
	workspace.add_theme_constant_override("separation", 12)
	workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_box.add_child(workspace)

	workspace.add_child(_make_magic_atlas_panel())
	workspace.add_child(_make_magic_expansion_panel())


func _make_magic_atlas_panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "MagicAtlasPanel"
	panel.custom_minimum_size = Vector2(730.0, 0.0)
	panel.add_theme_stylebox_override(
		"panel",
		make_panel_style(Color(0.025, 0.035, 0.052, 0.94), CARD_BORDER, 1, 13)
	)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	margin.add_child(stack)

	stack.add_child(_make_magic_heading("ELEMENTS  •  NATURAL / PRIMAL / VITAL / MYSTICAL"))
	var element_grid: GridContainer = make_visual_grid(4)
	element_grid.name = "MagicElementGrid"
	element_grid.add_theme_constant_override("h_separation", 6)
	element_grid.add_theme_constant_override("v_separation", 6)
	stack.add_child(element_grid)
	for element_id: String in ELEMENT_ORDER:
		_add_element_tile(element_grid, element_id)

	stack.add_child(_make_magic_heading("SPELLCASTING TRADITIONS"))
	var tradition_grid: GridContainer = make_visual_grid(4)
	tradition_grid.name = "MagicTraditionGrid"
	tradition_grid.add_theme_constant_override("h_separation", 6)
	tradition_grid.add_theme_constant_override("v_separation", 6)
	stack.add_child(tradition_grid)
	for tradition_id: String in SpellcastingTraditionCatalogScript.TRADITION_IDS:
		_add_tradition_tile(tradition_grid, tradition_id)
	return panel


func _make_magic_expansion_panel() -> PanelContainer:
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
		MAGIC_ELEMENT:
			_render_element_spell_list(stack)
		MAGIC_SPELL:
			_render_spell_detail(stack)
		MAGIC_TRADITION:
			_render_tradition_detail(stack)
		MAGIC_AUGMENTATION:
			_render_augmentation_detail(stack)
		_:
			_render_magic_overview(stack)
	return panel


func _add_element_tile(parent: Container, element_id: String) -> void:
	var spell_count: int = _get_element_spells(element_id).size()
	var badge: String = str(spell_count) + (" SPELL" if spell_count == 1 else " SPELLS")
	var augmentation: String = _get_active_augmentation(element_id)
	if augmentation != "":
		badge += "  •  +" + augmentation.to_upper()
	var is_open: bool = (
		selected_magic_element == element_id
		and magic_page in [MAGIC_ELEMENT, MAGIC_SPELL, MAGIC_AUGMENTATION]
	)
	_add_compact_action_tile(
		parent,
		("▾ " if is_open else "▸ ") + get_spell_icon(element_id),
		element_id.capitalize(),
		badge,
		{"kind": "toggle_magic_element", "element": element_id},
		"Open the learned " + element_id.capitalize() + " spells in the adjacent workspace.",
		58.0,
		10
	)


func _add_tradition_tile(parent: Container, tradition_id: String) -> void:
	var row: Dictionary = _get_tradition_row(tradition_id)
	var rank: int = int(row.get("rank", 0))
	var stage: String = str(row.get("current_stage_name", "Uninitiated"))
	var open: bool = (
		magic_page == MAGIC_TRADITION
		and selected_magic_tradition_id == tradition_id
	)
	_add_compact_action_tile(
		parent,
		("▾ " if open else "▸ ")
		+ str(row.get("icon", SpellcastingTraditionCatalogScript.get_icon(tradition_id))),
		str(row.get("display_name", SpellcastingTraditionCatalogScript.get_display_name(tradition_id))),
		stage.to_upper() + "  " + str(rank) + "/4",
		{"kind": "toggle_magic_tradition", "tradition_id": tradition_id},
		str(row.get("relationship", "Open this spellcasting tradition.")),
		50.0,
		9
	)


func _render_magic_overview(parent: VBoxContainer) -> void:
	parent.add_child(_make_magic_heading("MAGIC ATLAS"))
	var summary: Dictionary = menu_data.get("loadout_summary", {})
	var mastery: Dictionary = menu_data.get("spellcasting_mastery", {})
	var mastery_summary: Dictionary = _magic_dictionary(mastery.get("summary", {}))
	var augmentation_count: int = 0
	if GameState.has_method("get_elemental_augmentations_snapshot"):
		augmentation_count = (
			GameState.call("get_elemental_augmentations_snapshot") as Dictionary
		).size()
	var overview_grid: GridContainer = make_visual_grid(2)
	overview_grid.add_theme_constant_override("h_separation", 8)
	overview_grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(overview_grid)
	_add_magic_info_panel(
		overview_grid,
		"16 ELEMENTS",
		"Four fixed rows preserve the elemental families and make every school reachable without scrolling."
	)
	_add_magic_info_panel(
		overview_grid,
		str(summary.get("learned_count", 0)) + " LEARNED SPELLS",
		"Select an element, then select a spell to open properties, upgrades, proficiency, and specialized configuration."
	)
	_add_magic_info_panel(
		overview_grid,
		str(mastery_summary.get("initiated_count", 0)) + "/8 TRADITIONS INITIATED",
		"Traditions describe Grace's relationship to magic rather than replacing elemental spell schools."
	)
	_add_magic_info_panel(
		overview_grid,
		str(augmentation_count) + " ACTIVE AUGMENTATIONS",
		"Late-game augmentations are directed. Lightning → Fire does not automatically authorize Fire → Lightning."
	)
	var note: Label = Label.new()
	note.text = (
		"Soul contains Summon Familiar. Its creature blueprint controls now live inside that spell rather than floating as a separate magic section."
	)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", TEXT_SOFT)
	parent.add_child(note)


func _render_element_spell_list(parent: VBoxContainer) -> void:
	parent.add_child(
		_make_magic_heading(
			get_spell_icon(selected_magic_element)
			+ "  "
			+ selected_magic_element.to_upper()
			+ " SPELLS"
		)
	)
	var spells: Array[Dictionary] = _get_element_spells(selected_magic_element)
	var guide: Label = Label.new()
	guide.text = (
		"Choose a spell to unfold its craft."
		if not is_assigning_spell()
		else "Choose the spell assigned to quick slot " + str(pending_spell_slot_index + 1) + "."
	)
	guide.add_theme_font_size_override("font_size", 11)
	guide.add_theme_color_override("font_color", TEXT_SOFT)
	parent.add_child(guide)
	var spell_grid: GridContainer = make_visual_grid(2)
	spell_grid.name = "MagicElementSpellGrid"
	spell_grid.add_theme_constant_override("h_separation", 8)
	spell_grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(spell_grid)
	for spell: Dictionary in spells:
		var spell_id: String = SpellProgressionCatalogScript.get_spell_id(spell)
		var action: Dictionary = (
			{
				"kind": "assign_spell",
				"learned_index": int(spell.get("learned_index", -1)),
			}
			if is_assigning_spell()
			else {"kind": "open_magic_spell", "spell_id": spell_id}
		)
		var badge: String = get_spell_cost_label(spell)
		var equipped: String = get_spell_equipped_subtitle(spell)
		if equipped != "Spellbook":
			badge += "  •  " + equipped
		_add_compact_action_tile(
			spell_grid,
			get_spell_icon(selected_magic_element),
			_get_magic_spell_name(spell),
			badge,
			action,
			str(spell.get("description", "")),
			76.0,
			11
		)
	if spells.is_empty():
		_add_magic_info_panel(
			spell_grid,
			"NO LEARNED SPELLS",
			"Grace has not learned a " + selected_magic_element.capitalize() + " spell yet."
		)
	if not is_assigning_spell():
		var target: String = _get_active_augmentation(selected_magic_element)
		_add_compact_action_tile(
			spell_grid,
			"◇→" + (get_spell_icon(target) if target != "" else "◇"),
			"Elemental Augmentation",
			(
				ElementalAugmentationCatalogScript.get_pair_label(
					selected_magic_element,
					target
				).to_upper()
				if target != ""
				else "PURE " + selected_magic_element.to_upper()
			),
			{
				"kind": "open_element_augmentation",
				"element": selected_magic_element,
			},
			"Choose one of the authored elements that can augment every spell in this school.",
			76.0,
			10
		)


func _render_spell_detail(parent: VBoxContainer) -> void:
	var spell: Dictionary = _get_spell_row(selected_magic_spell_id)
	if spell.is_empty():
		magic_page = MAGIC_ELEMENT
		_render_element_spell_list(parent)
		return
	parent.add_child(
		_make_magic_heading(
			get_spell_icon(str(spell.get("element", selected_magic_element)))
			+ "  "
			+ _get_magic_spell_name(spell).to_upper()
		)
	)
	var description: Label = Label.new()
	description.text = str(spell.get("description", "No spell description yet."))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 12)
	description.add_theme_color_override("font_color", TEXT_SOFT)
	parent.add_child(description)

	var cost_label: Label = Label.new()
	cost_label.text = (
		get_spell_cost_label(spell)
		+ "  •  "
		+ str(spell.get("category", "Spell"))
		+ "  •  "
		+ SpellProgressionCatalogScript.get_combo_summary(spell).replace("\n", "  •  ")
	)
	cost_label.clip_text = true
	cost_label.add_theme_font_size_override("font_size", 10)
	cost_label.add_theme_color_override("font_color", TEXT_DIM)
	parent.add_child(cost_label)

	parent.add_child(_make_magic_heading("PROPERTIES"))
	var property_grid: GridContainer = make_visual_grid(4)
	property_grid.add_theme_constant_override("h_separation", 6)
	parent.add_child(property_grid)
	for property: Dictionary in SpellProgressionCatalogScript.get_property_rows(spell):
		_add_compact_action_tile(
			property_grid,
			"◇",
			str(property.get("name", "Property")),
			str(property.get("value", "Authored")),
			{
				"kind": "inspect_spell_property",
				"message": str(property.get("description", "Property editing is reserved.")),
			},
			str(property.get("description", "")),
			58.0,
			9
		)

	parent.add_child(_make_magic_heading("UPGRADE BRANCHES"))
	var upgrade_grid: GridContainer = make_visual_grid(3)
	upgrade_grid.add_theme_constant_override("h_separation", 7)
	parent.add_child(upgrade_grid)
	for upgrade: Dictionary in SpellProgressionCatalogScript.get_upgrade_rows(spell):
		_add_compact_action_tile(
			upgrade_grid,
			"◇",
			str(upgrade.get("name", "Upgrade")),
			"RANK " + str(upgrade.get("rank", 0)) + "/" + str(upgrade.get("rank_max", 3)),
			{
				"kind": "inspect_spell_upgrade",
				"message": str(upgrade.get("unlock_hint", "Raise spell proficiency.")),
			},
			str(upgrade.get("description", "")),
			58.0,
			9
		)

	_render_proficiency_guide(parent, spell)
	if selected_magic_spell_id == "spectral_familiar":
		_render_compact_familiar_customization(parent)
	else:
		_render_spell_augmentation_summary(parent, spell)


func _render_proficiency_guide(parent: VBoxContainer, spell: Dictionary) -> void:
	var guide: Dictionary = SpellProgressionCatalogScript.get_proficiency_guide(spell)
	var methods: Array[String] = _magic_string_array(guide.get("methods", []))
	var panel: PanelContainer = _make_magic_subpanel()
	parent.add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 9)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 9)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	var title: Label = Label.new()
	title.text = "PROFICIENCY  •  " + str(guide.get("rank_name", "Unpracticed")).to_upper()
	title.custom_minimum_size = Vector2(210.0, 0.0)
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", ACTIVE_SELECTION_BORDER)
	row.add_child(title)
	var copy: Label = Label.new()
	copy.text = "  •  ".join(methods.slice(0, mini(methods.size(), 3)))
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_font_size_override("font_size", 10)
	copy.add_theme_color_override("font_color", TEXT_SOFT)
	row.add_child(copy)


func _render_spell_augmentation_summary(
	parent: VBoxContainer,
	spell: Dictionary
) -> void:
	var source: String = str(spell.get("element", selected_magic_element))
	var target: String = _get_active_augmentation(source)
	var grid: GridContainer = make_visual_grid(1)
	parent.add_child(grid)
	_add_compact_action_tile(
		grid,
		get_spell_icon(source) + " → " + (get_spell_icon(target) if target != "" else "◇"),
		"Elemental Augmentation",
		(
			ElementalAugmentationCatalogScript.get_pair_label(source, target).to_upper()
			if target != ""
			else "PURE " + source.to_upper()
		),
		{"kind": "open_element_augmentation", "element": source},
		"The selected directed augmentation applies to the entire element, not only this spell.",
		54.0,
		10
	)


func _render_compact_familiar_customization(parent: VBoxContainer) -> void:
	var familiar_data: Dictionary = _magic_dictionary(
		menu_data.get("familiar_mastery", {})
	)
	var rows: Array[Dictionary] = _magic_dictionary_array(
		familiar_data.get("rows", [])
	)
	parent.add_child(_make_magic_heading("FAMILIAR BLUEPRINT"))
	if rows.is_empty():
		var none: Label = Label.new()
		none.text = "Study creatures to translate their behavior into summonable blueprints."
		none.add_theme_color_override("font_color", TEXT_SOFT)
		parent.add_child(none)
		return
	if selected_familiar_species_id == "":
		selected_familiar_species_id = str(
			familiar_data.get("equipped_species_id", "")
		)
	if selected_familiar_species_id == "":
		selected_familiar_species_id = str(rows[0].get("species_id", ""))

	var species_grid: GridContainer = make_visual_grid(mini(maxi(rows.size(), 1), 3))
	species_grid.add_theme_constant_override("h_separation", 6)
	parent.add_child(species_grid)
	for row: Dictionary in rows:
		var species_id: String = str(row.get("species_id", ""))
		_add_compact_action_tile(
			species_grid,
			str(row.get("icon", "◇")),
			str(row.get("display_name", species_id.capitalize())),
			(
				"SELECTED"
				if species_id == selected_familiar_species_id
				else ("UNLOCKED" if bool(row.get("unlocked", false)) else "LOCKED")
			),
			{"kind": "select_familiar_species", "species_id": species_id},
			str(row.get("summary", "")),
			48.0,
			9
		)
	var selected_row: Dictionary = _get_familiar_row(
		rows,
		selected_familiar_species_id
	)
	if selected_row.is_empty() or not bool(selected_row.get("unlocked", false)):
		var locked: Label = Label.new()
		locked.text = "Record enough unique creature behavior to unlock this blueprint."
		locked.add_theme_color_override("font_color", TEXT_SOFT)
		parent.add_child(locked)
		return
	var species_id: String = str(selected_row.get("species_id", ""))
	var loadout: Dictionary = _magic_dictionary(selected_row.get("loadout", {}))
	var control_grid: GridContainer = make_visual_grid(4)
	control_grid.add_theme_constant_override("h_separation", 6)
	parent.add_child(control_grid)
	_add_compact_action_tile(
		control_grid,
		"✦",
		"Blueprint",
		"EQUIPPED" if bool(selected_row.get("equipped", false)) else "SELECT",
		{"kind": "equip_familiar", "species_id": species_id},
		"The Summon Familiar spell creates the equipped creature blueprint.",
		50.0,
		8
	)
	_add_compact_action_tile(
		control_grid,
		"⚔",
		"Role",
		str(loadout.get("role", "skirmisher")).replace("_", " ").to_upper(),
		{"kind": "cycle_familiar_role", "species_id": species_id},
		"Cycle the familiar's tactical role.",
		50.0,
		8
	)
	_add_compact_action_tile(
		control_grid,
		"◈",
		"Temperament",
		str(loadout.get("temperament", "balanced")).to_upper(),
		{"kind": "cycle_familiar_temperament", "species_id": species_id},
		"Adjust commitment, caution, and retreat behavior.",
		50.0,
		8
	)
	_add_compact_action_tile(
		control_grid,
		"⌁",
		"Command",
		str(loadout.get("command", "assist")).to_upper(),
		{"kind": "cycle_familiar_command", "species_id": species_id},
		"Choose the familiar's opening command.",
		50.0,
		8
	)
	var technique_rows: Array[Dictionary] = _magic_dictionary_array(
		selected_row.get("techniques", [])
	)
	if technique_rows.is_empty():
		return
	var technique_grid: GridContainer = make_visual_grid(mini(maxi(technique_rows.size(), 1), 4))
	technique_grid.add_theme_constant_override("h_separation", 6)
	parent.add_child(technique_grid)
	for technique: Dictionary in technique_rows:
		var technique_id: String = str(technique.get("id", ""))
		var unlocked: bool = bool(technique.get("unlocked", false))
		var action: Dictionary = (
			{
				"kind": "toggle_familiar_technique",
				"species_id": species_id,
				"technique_id": technique_id,
			}
			if unlocked
			else {
				"kind": "inspect_spell_property",
				"message": "Requires " + str(technique.get("unlock_id", "more creature study")).replace("_", " ").capitalize() + ".",
			}
		)
		_add_compact_action_tile(
			technique_grid,
			"◆" if bool(technique.get("equipped", false)) else "◇",
			str(technique.get("label", technique_id.capitalize())),
			(
				"EQUIPPED"
				if bool(technique.get("equipped", false))
				else ("AVAILABLE" if unlocked else "LOCKED")
			),
			action,
			str(technique.get("description", "")),
			46.0,
			8
		)


func _render_tradition_detail(parent: VBoxContainer) -> void:
	var row: Dictionary = _get_tradition_row(selected_magic_tradition_id)
	parent.add_child(
		_make_magic_heading(
			str(row.get("icon", "✦"))
			+ "  "
			+ str(row.get("display_name", "Tradition")).to_upper()
		)
	)
	var relationship: Label = Label.new()
	relationship.text = str(row.get("relationship", ""))
	relationship.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	relationship.add_theme_font_size_override("font_size", 12)
	relationship.add_theme_color_override("font_color", TEXT_SOFT)
	parent.add_child(relationship)

	var stages: Array[Dictionary] = _magic_dictionary_array(
		row.get("stage_rows", [])
	)
	var stage_grid: GridContainer = make_visual_grid(4)
	stage_grid.add_theme_constant_override("h_separation", 7)
	parent.add_child(stage_grid)
	if stages.is_empty():
		for stage_id: String in SpellcastingTraditionCatalogScript.STAGE_IDS:
			stages.append({
				"id": stage_id,
				"name": SpellcastingTraditionCatalogScript.get_stage_display_name(stage_id),
				"unlocked": false,
			})
	for stage: Dictionary in stages:
		_add_magic_info_panel(
			stage_grid,
			("◆ " if bool(stage.get("unlocked", false)) else "◇ ")
			+ str(stage.get("name", "Stage")).to_upper(),
			"COMPLETE" if bool(stage.get("unlocked", false)) else "LOCKED"
		)

	var compatible: Array[String] = _magic_string_array(
		row.get("compatible_spell_names", [])
	)
	var compatibility: Label = Label.new()
	compatibility.text = (
		"Compatible learned spells: none yet"
		if compatible.is_empty()
		else "Compatible learned spells: " + ", ".join(compatible)
	)
	compatibility.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	compatibility.add_theme_font_size_override("font_size", 11)
	compatibility.add_theme_color_override("font_color", TEXT_SOFT)
	parent.add_child(compatibility)
	var capstone: Dictionary = _magic_dictionary(row.get("capstone", {}))
	_add_magic_info_panel(
		parent,
		"CAPSTONE  •  " + str(capstone.get("display_name", "Reserved")),
		str(capstone.get("description", "Final mastery mechanic reserved."))
	)


func _render_augmentation_detail(parent: VBoxContainer) -> void:
	parent.add_child(
		_make_magic_heading(
			get_spell_icon(selected_magic_element)
			+ "  "
			+ selected_magic_element.to_upper()
			+ " AUGMENTATION"
		)
	)
	var unlocked: bool = (
		GameState.has_method("is_elemental_augmentation_unlocked")
		and bool(GameState.call("is_elemental_augmentation_unlocked"))
	)
	var debug_preview: bool = OS.is_debug_build() and not unlocked
	var explanation: Label = Label.new()
	explanation.text = (
		"Choose one directed secondary element for every spell in this school. "
		+ ("Unlocked." if unlocked else ("Debug preview enabled." if debug_preview else "Late-game system locked."))
	)
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation.add_theme_font_size_override("font_size", 11)
	explanation.add_theme_color_override("font_color", TEXT_SOFT)
	parent.add_child(explanation)
	var current: String = _get_active_augmentation(selected_magic_element)
	var grid: GridContainer = make_visual_grid(3)
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(grid)
	_add_compact_action_tile(
		grid,
		"◇",
		"Pure " + selected_magic_element.capitalize(),
		"SELECTED" if current == "" else "CLEAR AUGMENTATION",
		{
			"kind": "set_elemental_augmentation",
			"source": selected_magic_element,
			"target": "",
		},
		"Remove the secondary element and restore the school's pure identity.",
		78.0,
		10
	)
	for option: Dictionary in ElementalAugmentationCatalogScript.get_options(
		selected_magic_element
	):
		var target: String = str(option.get("target", ""))
		var action: Dictionary = {
			"kind": "set_elemental_augmentation",
			"source": selected_magic_element,
			"target": target,
		}
		if not unlocked and not debug_preview:
			action = {
				"kind": "inspect_spell_property",
				"message": "Elemental Augmentation unlocks late in Grace's progression.",
			}
		_add_compact_action_tile(
			grid,
			get_spell_icon(selected_magic_element) + " → " + get_spell_icon(target),
			str(option.get("name", target.capitalize())),
			(
				"SELECTED"
				if current == target
				else ("DEBUG PREVIEW" if debug_preview else ("AVAILABLE" if unlocked else "LOCKED"))
			),
			action,
			str(option.get("result", "")),
			78.0,
			10
		)
	var note: Label = Label.new()
	note.text = "Directed recipe: authoring " + selected_magic_element.capitalize() + " → Fire does not create Fire → " + selected_magic_element.capitalize() + ". Gameplay payload transformation is the next integration layer."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 10)
	note.add_theme_color_override("font_color", TEXT_DIM)
	parent.add_child(note)


func _toggle_magic_element(element_id: String) -> void:
	if not ELEMENT_ORDER.has(element_id):
		return
	if (
		selected_magic_element == element_id
		and magic_page in [MAGIC_ELEMENT, MAGIC_SPELL, MAGIC_AUGMENTATION]
	):
		_reset_magic_workspace()
	else:
		magic_page = MAGIC_ELEMENT
		selected_magic_element = element_id
		selected_magic_spell_id = ""
		selected_magic_tradition_id = ""
	selected_action_index = ELEMENT_ORDER.find(element_id)
	tab_action_memory["magic"] = selected_action_index
	rebuild_menu()


func _open_magic_spell(spell_id: String) -> void:
	var spell: Dictionary = _get_spell_row(spell_id)
	if spell.is_empty():
		return
	magic_page = MAGIC_SPELL
	selected_magic_spell_id = spell_id
	selected_magic_element = str(spell.get("element", selected_magic_element))
	selected_magic_tradition_id = ""
	selected_action_index = 24
	rebuild_menu()


func _toggle_magic_tradition(tradition_id: String) -> void:
	if not SpellcastingTraditionCatalogScript.has_tradition(tradition_id):
		return
	if (
		magic_page == MAGIC_TRADITION
		and selected_magic_tradition_id == tradition_id
	):
		_reset_magic_workspace()
	else:
		magic_page = MAGIC_TRADITION
		selected_magic_tradition_id = tradition_id
		selected_magic_element = ""
		selected_magic_spell_id = ""
	selected_action_index = 16 + SpellcastingTraditionCatalogScript.TRADITION_IDS.find(
		tradition_id
	)
	tab_action_memory["magic"] = selected_action_index
	rebuild_menu()


func _open_element_augmentation(element_id: String) -> void:
	if not ELEMENT_ORDER.has(element_id):
		return
	magic_page = MAGIC_AUGMENTATION
	selected_magic_element = element_id
	selected_magic_spell_id = ""
	selected_magic_tradition_id = ""
	selected_action_index = 24
	rebuild_menu()


func _set_elemental_augmentation(
	source_element: String,
	target_element: String
) -> void:
	if not GameState.has_method("set_elemental_augmentation"):
		return
	var changed: bool = bool(
		GameState.call(
			"set_elemental_augmentation",
			source_element,
			target_element,
			OS.is_debug_build()
		)
	)
	if changed:
		_show_magic_message(
			"Augmentation: "
			+ ElementalAugmentationCatalogScript.get_pair_label(
				source_element,
				target_element
			)
			+ "."
		)
	else:
		_show_magic_message("That directed augmentation is unavailable.")
	rebuild_menu()


func _back_magic_workspace() -> void:
	match magic_page:
		MAGIC_SPELL, MAGIC_AUGMENTATION:
			magic_page = MAGIC_ELEMENT
			selected_magic_spell_id = ""
		MAGIC_ELEMENT, MAGIC_TRADITION:
			_reset_magic_workspace()
		_:
			_reset_magic_workspace()
	selected_action_index = (
		ELEMENT_ORDER.find(selected_magic_element)
		if selected_magic_element != ""
		else 0
	)
	tab_action_memory["magic"] = maxi(selected_action_index, 0)
	rebuild_menu()


func _reset_magic_workspace() -> void:
	magic_page = MAGIC_OVERVIEW
	selected_magic_element = ""
	selected_magic_spell_id = ""
	selected_magic_tradition_id = ""
	selected_familiar_species_id = ""


func _get_element_spells(element_id: String) -> Array[Dictionary]:
	for section_value: Variant in menu_data.get("learned_spell_sections", []):
		if not section_value is Dictionary:
			continue
		var section: Dictionary = section_value as Dictionary
		if str(section.get("element", "")) != element_id:
			continue
		return _magic_dictionary_array(section.get("spells", []))
	return []


func _get_spell_row(spell_id: String) -> Dictionary:
	for element_id: String in ELEMENT_ORDER:
		for spell: Dictionary in _get_element_spells(element_id):
			if SpellProgressionCatalogScript.get_spell_id(spell) == spell_id:
				return spell
	return {}


func _get_tradition_row(tradition_id: String) -> Dictionary:
	var mastery: Dictionary = _magic_dictionary(
		menu_data.get("spellcasting_mastery", {})
	)
	for value: Variant in mastery.get("rows", []):
		if not value is Dictionary:
			continue
		var row: Dictionary = value as Dictionary
		if str(row.get("id", "")) == tradition_id:
			return row
	var definition: Dictionary = SpellcastingTraditionCatalogScript.get_definition(
		tradition_id
	)
	definition["rank"] = 0
	definition["rank_max"] = 4
	definition["current_stage_name"] = "Uninitiated"
	definition["stage_rows"] = []
	definition["compatible_spell_names"] = []
	return definition


func _get_active_augmentation(element_id: String) -> String:
	if GameState.has_method("get_elemental_augmentation"):
		return str(GameState.call("get_elemental_augmentation", element_id))
	return ""


func _get_magic_spell_name(spell: Dictionary) -> String:
	if SpellProgressionCatalogScript.get_spell_id(spell) == "spectral_familiar":
		return "Summon Familiar"
	return str(spell.get("name", "Spell"))


func _get_familiar_row(
	rows: Array[Dictionary],
	species_id: String
) -> Dictionary:
	for row: Dictionary in rows:
		if str(row.get("species_id", "")) == species_id:
			return row
	return {}


func _get_magic_page_title() -> String:
	match magic_page:
		MAGIC_ELEMENT:
			return "✦ Magic  ›  " + selected_magic_element.capitalize()
		MAGIC_SPELL:
			var spell: Dictionary = _get_spell_row(selected_magic_spell_id)
			return "✦ Magic  ›  " + selected_magic_element.capitalize() + "  ›  " + _get_magic_spell_name(spell)
		MAGIC_TRADITION:
			return "✦ Magic  ›  " + SpellcastingTraditionCatalogScript.get_display_name(selected_magic_tradition_id)
		MAGIC_AUGMENTATION:
			return "✦ Magic  ›  " + selected_magic_element.capitalize() + " Augmentation"
	return "✦ Magic"


func _make_magic_heading(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", ACTIVE_SELECTION_BORDER)
	return label


func _make_magic_subpanel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override(
		"panel",
		make_panel_style(Color(0.05, 0.062, 0.082, 0.88), CARD_BORDER, 1, 9)
	)
	return panel


func _add_magic_info_panel(
	parent: Container,
	title_text: String,
	body_text: String
) -> void:
	var panel: PanelContainer = _make_magic_subpanel()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 7)
	panel.add_child(margin)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 3)
	margin.add_child(stack)
	var title: Label = Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", TEXT_MAIN)
	stack.add_child(title)
	var body: Label = Label.new()
	body.text = body_text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 10)
	body.add_theme_color_override("font_color", TEXT_SOFT)
	stack.add_child(body)


func _show_magic_message(text: String) -> void:
	if GameState.has_method("show_system_message"):
		GameState.call("show_system_message", text)


func _update_scroll_policy() -> void:
	if scroll_container == null:
		return
	if get_current_tab_id() in ["loadout", "magic"]:
		scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll_container.scroll_vertical = 0
		scroll_container.scroll_horizontal = 0
	else:
		scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO


func get_magic_debug_data() -> Dictionary:
	return {
		"page": magic_page,
		"element_count": ELEMENT_ORDER.size(),
		"tradition_count": SpellcastingTraditionCatalogScript.TRADITION_IDS.size(),
		"selected_element": selected_magic_element,
		"selected_spell": selected_magic_spell_id,
		"selected_tradition": selected_magic_tradition_id,
		"scroll_disabled": (
			scroll_container != null
			and scroll_container.vertical_scroll_mode
			== ScrollContainer.SCROLL_MODE_DISABLED
		),
		"atlas_present": find_child("MagicAtlasPanel", true, false) != null,
		"expansion_present": find_child("MagicExpansionPanel", true, false) != null,
	}


func _magic_dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _magic_dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for raw: Variant in value as Array:
			if raw is Dictionary:
				result.append((raw as Dictionary).duplicate(true))
	return result


func _magic_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value as Array:
			var text: String = str(raw)
			if text != "":
				result.append(text)
	return result
