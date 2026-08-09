extends "res://scripts/ui/full_menu_shell_familiar_detail.gd"
class_name FullMenuShellPlantSpellDetail

const PreparedPlantLoadoutSpellDetailScript = preload(
	"res://scripts/life/prepared_plant_loadout.gd"
)
const PlantCatalogSpellDetail = preload(
	"res://scripts/life/plant_summon_catalog.gd"
)


func _render_spell_detail(parent: VBoxContainer) -> void:
	super._render_spell_detail(parent)
	if selected_magic_spell_id != "sprout":
		return
	_render_prepared_plant_spell_controls(parent)


func _render_prepared_plant_spell_controls(parent: VBoxContainer) -> void:
	var store: PreparedPlantLoadout = (
		PreparedPlantLoadoutSpellDetailScript.get_or_create(get_tree())
		as PreparedPlantLoadout
	)
	if store == null:
		return

	var snapshot: Dictionary = store.get_prepared_snapshot()
	var prepared_id: String = str(snapshot.get("plant_id", ""))
	var prepared_name: String = str(snapshot.get("display_name", "None"))
	var parameters_value: Variant = snapshot.get("parameters", {})
	var parameters: Dictionary = (
		(parameters_value as Dictionary).duplicate(true)
		if parameters_value is Dictionary
		else {}
	)

	parent.add_child(_make_magic_heading("PREPARED PLANT BLUEPRINT"))

	var summary: PanelContainer = _make_magic_subpanel()
	summary.name = "PlantSummonPreparedSummary"
	parent.add_child(summary)
	var summary_margin := MarginContainer.new()
	summary_margin.add_theme_constant_override("margin_left", 10)
	summary_margin.add_theme_constant_override("margin_top", 7)
	summary_margin.add_theme_constant_override("margin_right", 10)
	summary_margin.add_theme_constant_override("margin_bottom", 7)
	summary.add_child(summary_margin)
	var summary_row := HBoxContainer.new()
	summary_row.add_theme_constant_override("separation", 10)
	summary_margin.add_child(summary_row)
	var title := Label.new()
	title.text = "PREPARED  •  " + prepared_name.to_upper()
	title.custom_minimum_size = Vector2(260.0, 0.0)
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", ACTIVE_SELECTION_BORDER)
	summary_row.add_child(title)
	var field_contract := Label.new()
	field_contract.text = "Field use: select Plant Summon → aim → cast"
	field_contract.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field_contract.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	field_contract.add_theme_font_size_override("font_size", 10)
	field_contract.add_theme_color_override("font_color", TEXT_SOFT)
	summary_row.add_child(field_contract)

	var discovered: Array[String] = store.get_discovered_plant_ids()
	var species_rows: Array[Dictionary] = PlantCatalogSpellDetail.get_catalog_entries(discovered)
	if species_rows.size() > 1:
		var species_grid: GridContainer = make_visual_grid(mini(species_rows.size(), 3))
		species_grid.name = "PlantSummonSpeciesGrid"
		species_grid.add_theme_constant_override("h_separation", 6)
		parent.add_child(species_grid)
		for row: Dictionary in species_rows:
			var plant_id: String = str(row.get("plant_id", ""))
			_add_compact_action_tile(
				species_grid,
				"◆" if plant_id == prepared_id else "◇",
				str(row.get("display_name", plant_id.capitalize())),
				"PREPARED" if plant_id == prepared_id else str(row.get("archetype", "plant")).to_upper(),
				{"kind": "prepare_plant_species", "plant_id": plant_id},
				str(row.get("description", "")),
				52.0,
				9
			)

	var parameter_rows: Array[Dictionary] = (
		PlantCatalogSpellDetail.get_preparation_rows(prepared_id, parameters)
	)
	if parameter_rows.is_empty():
		var fixed := Label.new()
		fixed.text = "This plant has a fixed blueprint. Discover other species to expand Plant Summon."
		fixed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fixed.add_theme_font_size_override("font_size", 10)
		fixed.add_theme_color_override("font_color", TEXT_SOFT)
		parent.add_child(fixed)
		return

	var parameter_grid: GridContainer = make_visual_grid(mini(parameter_rows.size(), 3))
	parameter_grid.name = "PlantSummonParameterGrid"
	parameter_grid.add_theme_constant_override("h_separation", 7)
	parameter_grid.add_theme_constant_override("v_separation", 7)
	parent.add_child(parameter_grid)
	for row: Dictionary in parameter_rows:
		var parameter_id: String = str(row.get("parameter_id", ""))
		_add_compact_action_tile(
			parameter_grid,
			_plant_parameter_icon(parameter_id),
			str(row.get("label", parameter_id.capitalize())),
			str(row.get("value_label", "Prepared")).to_upper(),
			{"kind": "cycle_plant_parameter", "parameter_id": parameter_id},
			str(row.get("description", ""))
			+ "\nPrepared before combat. Select to cycle the blueprint value.",
			58.0,
			9
		)


func _plant_parameter_icon(parameter_id: String) -> String:
	match parameter_id:
		"size":
			return "↕"
		"persistence":
			return "◴"
		"emergence":
			return "↑"
		_:
			return "◇"


func get_plant_spell_detail_debug_data() -> Dictionary:
	var store: PreparedPlantLoadout = (
		PreparedPlantLoadoutSpellDetailScript.get_or_create(get_tree())
		as PreparedPlantLoadout
	)
	return {
		"plant_spell_detail": true,
		"selected_spell_id": selected_magic_spell_id,
		"prepared": store.get_prepared_snapshot() if store != null else {},
		"parameters_render_in_spell_detail": true,
	}
