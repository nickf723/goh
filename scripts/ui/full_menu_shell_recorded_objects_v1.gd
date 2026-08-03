extends "res://scripts/ui/full_menu_shell_feedback_v1.gd"
class_name FullMenuShellRecordedObjectsV1

signal recorded_object_prepare_requested(blueprint_id: String)

const RecordedObjectCatalogScript = preload(
	"res://scripts/objects/recorded_object_catalog.gd"
)
const EngineeringPartCatalogScript = preload(
	"res://scripts/builds/engineering_part_catalog.gd"
)
const EngineeringBuildCatalogScript = preload(
	"res://scripts/builds/engineering_build_catalog.gd"
)

var armed_recorded_object_item_id: String = ""


func show_menu(new_menu_data: Dictionary) -> void:
	armed_recorded_object_item_id = ""
	EngineeringPartCatalogScript.ensure_prototype_baseline()
	super.show_menu(new_menu_data)


func hide_menu() -> void:
	armed_recorded_object_item_id = ""
	super.hide_menu()


func activate_action(action: Dictionary) -> void:
	var kind: String = str(action.get("kind", ""))
	match kind:
		"equip_recorded_object_spell_blueprint":
			_equip_recorded_object_blueprint(str(action.get("blueprint_id", "")))
			return
		"select_artificer_part":
			_select_artificer_part(str(action.get("part_id", "")))
			return
		"select_artificer_slot":
			_select_artificer_slot(str(action.get("slot_id", "")))
			return
		"select_artificer_blueprint":
			_select_artificer_blueprint(str(action.get("build_id", "")))
			return

	if (
		kind == "select_inventory_record"
		and get_current_tab_id() == "items"
		and selected_item_category == "objects"
	):
		var item_id: String = str(action.get("item_id", ""))
		var blueprint_id: String = RecordedObjectCatalogScript.get_blueprint_id_for_item(item_id)
		if blueprint_id != "" and RecordedObjectCatalogScript.is_recorded(blueprint_id):
			if armed_recorded_object_item_id != item_id:
				armed_recorded_object_item_id = item_id
				selected_inventory_item_id = item_id
				RecordedObjectCatalogScript.select_blueprint(blueprint_id)
				rebuild_menu()
				return
			RecordedObjectCatalogScript.select_blueprint(blueprint_id)
			recorded_object_prepare_requested.emit(blueprint_id)
			return

	if (
		kind == "select_inventory_record"
		and get_current_tab_id() == "items"
		and selected_item_category == "builds"
	):
		var build_item_id: String = str(action.get("item_id", ""))
		var build_id: String = EngineeringBuildCatalogScript.get_build_id_for_item(
			build_item_id
		)
		if build_id != "" and EngineeringBuildCatalogScript.select_build(build_id):
			selected_inventory_item_id = build_item_id
			_show_recorded_object_message(
				"Prepared "
				+ str(EngineeringBuildCatalogScript.get_definition(build_id).get(
					"display_name",
					build_id.capitalize()
				))
				+ " for Deploy Contraption."
			)
			rebuild_menu()
			return

	if (
		kind == "select_journal_record"
		and get_current_tab_id() == "journal"
		and selected_journal_category == "blueprints"
	):
		var record_id: String = str(action.get("record_id", ""))
		if record_id != "" and record_id == selected_journal_record_id:
			var journal_blueprint_id: String = (
				RecordedObjectCatalogScript.get_blueprint_id_for_item(record_id)
			)
			if (
				journal_blueprint_id != ""
				and RecordedObjectCatalogScript.is_recorded(journal_blueprint_id)
			):
				RecordedObjectCatalogScript.select_blueprint(journal_blueprint_id)
				recorded_object_prepare_requested.emit(journal_blueprint_id)
				return

	if kind == "select_inventory_record":
		armed_recorded_object_item_id = ""
	super.activate_action(action)


func _render_spell_augmentation_summary(
	parent: VBoxContainer,
	spell: Dictionary
) -> void:
	var spell_id: String = SpellProgressionCatalogScript.get_spell_id(spell)
	match spell_id:
		"recorded_object_summon":
			_render_recorded_object_spell_blueprints(parent)
		"artificer_assembly":
			_render_artificer_assembly_configuration(parent)
		"deploy_contraption":
			_render_artificer_deploy_configuration(parent)
		_:
			super._render_spell_augmentation_summary(parent, spell)


func _render_recorded_object_spell_blueprints(parent: VBoxContainer) -> void:
	parent.add_child(_make_magic_heading("REPRODUCE OBJECT • BLUEPRINT"))
	var selected_id: String = RecordedObjectCatalogScript.get_selected_blueprint_id()
	var selected_definition: Dictionary = RecordedObjectCatalogScript.get_definition(selected_id)
	var summary: GridContainer = make_visual_grid(3)
	summary.add_theme_constant_override("h_separation", 7)
	parent.add_child(summary)
	_add_magic_info_panel(
		summary,
		str(selected_definition.get("display_name", "None")).to_upper()
		if selected_id != "" else "NONE PREPARED",
		"Simple object pattern used when this spell is cast"
	)
	_add_magic_info_panel(
		summary,
		str(selected_definition.get("mana_cost", 0)) + " MANA"
		if selected_id != "" else "NO COST",
		"Paid only when placement is confirmed"
	)
	_add_magic_info_panel(
		summary,
		str(selected_definition.get("maximum_active", 0)) + " ACTIVE MAX"
		if selected_id != "" else "NO BLUEPRINT",
		"Selection persists with the save slot"
	)

	var grid: GridContainer = make_visual_grid(4)
	grid.name = "RecordedObjectSpellBlueprintGrid"
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 7)
	parent.add_child(grid)
	for blueprint_id: String in RecordedObjectCatalogScript.BLUEPRINT_ORDER:
		var definition: Dictionary = RecordedObjectCatalogScript.get_definition(blueprint_id)
		var recorded: bool = RecordedObjectCatalogScript.is_recorded(blueprint_id)
		var selected: bool = blueprint_id == selected_id
		if recorded:
			_add_compact_action_tile(
				grid,
				str(definition.get("icon", "▣")),
				str(definition.get("display_name", blueprint_id.capitalize())),
				"PREPARED" if selected else str(definition.get("mana_cost", 0)) + " MANA",
				{"kind": "equip_recorded_object_spell_blueprint", "blueprint_id": blueprint_id},
				str(definition.get("description", "Recorded object.")),
				68.0,
				9
			)
		else:
			_add_magic_info_panel(
				grid,
				"🔒 " + str(definition.get("display_name", blueprint_id.capitalize())).to_upper(),
				"Study this object in the world to record its pattern."
			)


func _render_artificer_assembly_configuration(parent: VBoxContainer) -> void:
	EngineeringPartCatalogScript.ensure_prototype_baseline()
	var selected_part_id: String = EngineeringPartCatalogScript.get_selected_part_id()
	var selected_part: Dictionary = EngineeringPartCatalogScript.get_definition(selected_part_id)
	var selected_slot: String = EngineeringBuildCatalogScript.get_selected_custom_slot()
	var slot_saved: bool = EngineeringBuildCatalogScript.is_custom_build(selected_slot)
	var slot_definition: Dictionary = EngineeringBuildCatalogScript.get_definition(selected_slot)

	parent.add_child(_make_magic_heading("ARTIFICER ASSEMBLY • WORKSHOP LOADOUT"))
	var summary: GridContainer = make_visual_grid(3)
	summary.add_theme_constant_override("h_separation", 7)
	parent.add_child(summary)
	_add_magic_info_panel(
		summary,
		str(selected_part.get("display_name", "None")).to_upper(),
		"Prepared engineering part"
	)
	_add_magic_info_panel(
		summary,
		EngineeringBuildCatalogScript.get_custom_slot_display_name(selected_slot).to_upper(),
		"Blueprint slot finalized by Y"
	)
	_add_magic_info_panel(
		summary,
		(
			str((slot_definition.get("parts", []) as Array).size()) + " SAVED PARTS"
			if slot_saved else "EMPTY SLOT"
		),
		"Finalizing replaces the selected slot"
	)

	parent.add_child(_make_magic_heading("BLUEPRINT SLOT"))
	var slot_grid: GridContainer = make_visual_grid(4)
	slot_grid.name = "ArtificerBlueprintSlotGrid"
	slot_grid.add_theme_constant_override("h_separation", 7)
	parent.add_child(slot_grid)
	for slot_id: String in EngineeringBuildCatalogScript.CUSTOM_SLOT_ORDER:
		var saved: bool = EngineeringBuildCatalogScript.is_custom_build(slot_id)
		var definition: Dictionary = EngineeringBuildCatalogScript.get_definition(slot_id)
		_add_compact_action_tile(
			slot_grid,
			"⌬",
			EngineeringBuildCatalogScript.get_custom_slot_display_name(slot_id),
			("ACTIVE • " if slot_id == selected_slot else "")
			+ (str((definition.get("parts", []) as Array).size()) + " PARTS" if saved else "EMPTY"),
			{"kind": "select_artificer_slot", "slot_id": slot_id},
			"Choose which personal blueprint the next finalized draft will overwrite.",
			64.0,
			9
		)

	parent.add_child(_make_magic_heading("ENGINEERING PART PALETTE"))
	var part_grid: GridContainer = make_visual_grid(4)
	part_grid.name = "ArtificerPartPaletteGrid"
	part_grid.add_theme_constant_override("h_separation", 7)
	part_grid.add_theme_constant_override("v_separation", 7)
	parent.add_child(part_grid)
	for part_id: String in EngineeringPartCatalogScript.PART_ORDER:
		var definition: Dictionary = EngineeringPartCatalogScript.get_definition(part_id)
		var unlocked: bool = EngineeringPartCatalogScript.is_unlocked(part_id)
		if unlocked:
			_add_compact_action_tile(
				part_grid,
				str(definition.get("icon", "⚙")),
				str(definition.get("display_name", part_id.capitalize())),
				"PREPARED" if part_id == selected_part_id else str(definition.get("mana_cost", 0)) + " COST",
				{"kind": "select_artificer_part", "part_id": part_id},
				str(definition.get("description", "Engineering part.")),
				68.0,
				9
			)
		else:
			_add_magic_info_panel(
				part_grid,
				"🔒 " + str(definition.get("display_name", part_id.capitalize())).to_upper(),
				"Learn this engineering pattern through Artificer progression."
			)
	var note := Label.new()
	note.text = (
		"Cast to open a field workshop. D-pad left/right cycles learned parts; A attaches; "
		+ "X undoes; Y finalizes, saves, and manifests the machine. The draft itself costs no mana."
	)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 10)
	note.add_theme_color_override("font_color", TEXT_SOFT)
	parent.add_child(note)


func _render_artificer_deploy_configuration(parent: VBoxContainer) -> void:
	var selected_id: String = EngineeringBuildCatalogScript.get_selected_build_id()
	var selected: Dictionary = EngineeringBuildCatalogScript.get_definition(selected_id)
	parent.add_child(_make_magic_heading("DEPLOY CONTRAPTION • BLUEPRINT"))
	var summary: GridContainer = make_visual_grid(3)
	summary.add_theme_constant_override("h_separation", 7)
	parent.add_child(summary)
	_add_magic_info_panel(
		summary,
		str(selected.get("display_name", "None")).to_upper()
		if selected_id != "" else "NONE PREPARED",
		"Machine manifested when the spell is cast"
	)
	_add_magic_info_panel(
		summary,
		str((selected.get("parts", []) as Array).size()) + " PARTS"
		if selected_id != "" else "NO PARTS",
		"Runtime abilities emerge from the part recipe"
	)
	_add_magic_info_panel(
		summary,
		str(selected.get("mana_cost", 0)) + " MANA"
		if selected_id != "" else "NO COST",
		"Paid when deployment is confirmed"
	)

	parent.add_child(_make_magic_heading("STARTER SCHEMATICS"))
	var starter_grid: GridContainer = make_visual_grid(4)
	starter_grid.name = "ArtificerStarterBlueprintGrid"
	starter_grid.add_theme_constant_override("h_separation", 7)
	parent.add_child(starter_grid)
	for build_id: String in EngineeringBuildCatalogScript.BUILD_ORDER:
		_render_artificer_blueprint_tile(starter_grid, build_id, selected_id)

	parent.add_child(_make_magic_heading("PERSONAL CONTRAPTIONS"))
	var custom_grid: GridContainer = make_visual_grid(4)
	custom_grid.name = "ArtificerCustomBlueprintGrid"
	custom_grid.add_theme_constant_override("h_separation", 7)
	parent.add_child(custom_grid)
	for slot_id: String in EngineeringBuildCatalogScript.CUSTOM_SLOT_ORDER:
		_render_artificer_blueprint_tile(custom_grid, slot_id, selected_id)


func _render_artificer_blueprint_tile(
	parent: Container,
	build_id: String,
	selected_id: String
) -> void:
	var saved: bool = EngineeringBuildCatalogScript.is_saved(build_id)
	var definition: Dictionary = EngineeringBuildCatalogScript.get_definition(build_id)
	if saved:
		_add_compact_action_tile(
			parent,
			str(definition.get("icon", "⌬")),
			str(definition.get("display_name", build_id.capitalize())),
			"PREPARED" if build_id == selected_id else (
				str((definition.get("parts", []) as Array).size()) + " PARTS • "
				+ str(definition.get("mana_cost", 0)) + " MANA"
			),
			{"kind": "select_artificer_blueprint", "build_id": build_id},
			str(definition.get("description", "Saved contraption.")),
			72.0,
			9
		)
	else:
		var title: String = (
			EngineeringBuildCatalogScript.get_custom_slot_display_name(build_id)
			if EngineeringBuildCatalogScript.CUSTOM_SLOT_ORDER.has(build_id)
			else str(definition.get("display_name", build_id.capitalize()))
		)
		_add_magic_info_panel(
			parent,
			"◇ " + title.to_upper(),
			(
				"Finalize an Artificer draft into this slot."
				if EngineeringBuildCatalogScript.CUSTOM_SLOT_ORDER.has(build_id)
				else "Save this starter schematic at an engineering station."
			)
		)


func _equip_recorded_object_blueprint(blueprint_id: String) -> void:
	if not RecordedObjectCatalogScript.select_blueprint(blueprint_id):
		_show_recorded_object_message("That object pattern has not been recorded yet.")
		return
	var definition: Dictionary = RecordedObjectCatalogScript.get_definition(blueprint_id)
	_show_recorded_object_message(
		"Prepared " + str(definition.get("display_name", blueprint_id.capitalize()))
		+ " for Reproduce Object."
	)
	refresh_menu_data()
	rebuild_menu()


func _select_artificer_part(part_id: String) -> void:
	if not EngineeringPartCatalogScript.select_part(part_id):
		_show_recorded_object_message("That engineering part has not been learned yet.")
		return
	var definition: Dictionary = EngineeringPartCatalogScript.get_definition(part_id)
	_show_recorded_object_message(
		"Prepared " + str(definition.get("display_name", part_id.capitalize()))
		+ " for Artificer Assembly."
	)
	rebuild_menu()


func _select_artificer_slot(slot_id: String) -> void:
	if not EngineeringBuildCatalogScript.select_custom_slot(slot_id):
		return
	_show_recorded_object_message(
		EngineeringBuildCatalogScript.get_custom_slot_display_name(slot_id)
		+ " selected for the next finalized contraption."
	)
	rebuild_menu()


func _select_artificer_blueprint(build_id: String) -> void:
	if not EngineeringBuildCatalogScript.select_build(build_id):
		_show_recorded_object_message("That contraption blueprint has not been saved yet.")
		return
	var definition: Dictionary = EngineeringBuildCatalogScript.get_definition(build_id)
	_show_recorded_object_message(
		"Prepared " + str(definition.get("display_name", build_id.capitalize()))
		+ " for Deploy Contraption."
	)
	rebuild_menu()


func _toggle_item_category(category_id: String) -> void:
	armed_recorded_object_item_id = ""
	super._toggle_item_category(category_id)


func _reset_item_workspace() -> void:
	armed_recorded_object_item_id = ""
	super._reset_item_workspace()


func _make_inventory_detail_panel(
	row: Dictionary,
	category_definition: Dictionary,
	row_count: int
) -> PanelContainer:
	var panel: PanelContainer = super._make_inventory_detail_panel(row, category_definition, row_count)
	if row.is_empty():
		return panel
	var item_id: String = str(row.get("id", ""))
	var blueprint_id: String = RecordedObjectCatalogScript.get_blueprint_id_for_item(item_id)
	if blueprint_id == "":
		var build_id: String = EngineeringBuildCatalogScript.get_build_id_for_item(item_id)
		if build_id != "":
			_append_build_detail(panel, build_id)
		return panel
	var margin: MarginContainer = panel.get_child(0) as MarginContainer
	if margin == null or margin.get_child_count() == 0:
		return panel
	var stack: VBoxContainer = margin.get_child(0) as VBoxContainer
	if stack == null:
		return panel
	var definition: Dictionary = RecordedObjectCatalogScript.get_definition(blueprint_id)
	var selected: bool = RecordedObjectCatalogScript.get_selected_blueprint_id() == blueprint_id
	var armed: bool = armed_recorded_object_item_id == item_id
	stack.add_child(HSeparator.new())
	var heading := Label.new()
	heading.text = "REPRODUCTION BLUEPRINT"
	heading.add_theme_font_size_override("font_size", 10)
	heading.add_theme_color_override("font_color", ITEM_CATEGORY_ACTIVE_BORDER)
	stack.add_child(heading)
	var state := Label.new()
	state.text = (
		("SELECTED • " if selected else "RECORDED • ")
		+ str(definition.get("mana_cost", 0)) + " MANA • "
		+ str(definition.get("maximum_active", 1)) + " ACTIVE MAX"
	)
	state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	state.add_theme_font_size_override("font_size", 11)
	state.add_theme_color_override("font_color", TEXT_MAIN)
	stack.add_child(state)
	var instruction := Label.new()
	instruction.text = (
		"Press A again to close the menu and begin placement."
		if armed else "Press A to prepare this blueprint."
	)
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction.add_theme_font_size_override("font_size", 11)
	instruction.add_theme_color_override(
		"font_color",
		ACTIVE_SELECTION_BORDER if armed else TEXT_SOFT
	)
	stack.add_child(instruction)
	return panel


func _append_build_detail(panel: PanelContainer, build_id: String) -> void:
	var margin: MarginContainer = panel.get_child(0) as MarginContainer
	if margin == null or margin.get_child_count() == 0:
		return
	var stack: VBoxContainer = margin.get_child(0) as VBoxContainer
	if stack == null:
		return
	var definition: Dictionary = EngineeringBuildCatalogScript.get_definition(build_id)
	stack.add_child(HSeparator.new())
	var heading := Label.new()
	heading.text = "ARTIFICER BLUEPRINT"
	heading.add_theme_font_size_override("font_size", 10)
	heading.add_theme_color_override("font_color", ITEM_CATEGORY_ACTIVE_BORDER)
	stack.add_child(heading)
	var state := Label.new()
	state.text = (
		("PREPARED • " if EngineeringBuildCatalogScript.get_selected_build_id() == build_id else "SAVED • ")
		+ str((definition.get("parts", []) as Array).size()) + " PARTS • "
		+ str(definition.get("mana_cost", 0)) + " MANA"
	)
	state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	state.add_theme_font_size_override("font_size", 11)
	state.add_theme_color_override("font_color", TEXT_MAIN)
	stack.add_child(state)
	var instruction := Label.new()
	instruction.text = "Press A to prepare this machine for Deploy Contraption."
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction.add_theme_font_size_override("font_size", 11)
	instruction.add_theme_color_override("font_color", TEXT_SOFT)
	stack.add_child(instruction)


func get_footer_text() -> String:
	if (
		get_current_tab_id() == "items"
		and selected_item_category == "objects"
		and items_page == ITEMS_CATEGORY
		and not is_assignment_active()
	):
		return "D-pad: choose blueprint  •  A: prepare / press again to place  •  B: collapse  •  ZL/ZR: main tabs  •  L/R: subtabs"
	if (
		get_current_tab_id() == "items"
		and selected_item_category == "builds"
		and items_page == ITEMS_CATEGORY
		and not is_assignment_active()
	):
		return "D-pad: choose schematic  •  A: prepare for Deploy Contraption  •  B: collapse  •  ZL/ZR: main tabs"
	if (
		get_current_tab_id() == "journal"
		and selected_journal_category == "blueprints"
		and not is_assignment_active()
	):
		return "D-pad: choose record  •  A: inspect / press again to reproduce object  •  B: collapse  •  ZL/ZR: main tabs"
	return super.get_footer_text()


func _show_recorded_object_message(text: String) -> void:
	if GameState.has_method("show_system_message"):
		GameState.call("show_system_message", text)


func get_recorded_object_menu_debug_data() -> Dictionary:
	return {
		"armed_item_id": armed_recorded_object_item_id,
		"selected_blueprint_id": RecordedObjectCatalogScript.get_selected_blueprint_id(),
		"recorded_count": RecordedObjectCatalogScript.get_recorded_blueprint_ids().size(),
		"prepare_signal": has_signal("recorded_object_prepare_requested"),
		"spell_detail_blueprint_configuration": true,
		"artificer_part_configuration": true,
		"artificer_blueprint_configuration": true,
		"selected_artificer_part": EngineeringPartCatalogScript.get_selected_part_id(),
		"selected_artificer_build": EngineeringBuildCatalogScript.get_selected_build_id(),
		"selected_artificer_slot": EngineeringBuildCatalogScript.get_selected_custom_slot(),
		"journal_direct_reproduction": true,
	}
