extends "res://scripts/ui/full_menu_shell_familiar.gd"
class_name FullMenuShellPlants

const PreparedPlantLoadoutScript = preload(
	"res://scripts/life/prepared_plant_loadout.gd"
)
const PlantCatalog = preload(
	"res://scripts/life/plant_summon_catalog.gd"
)


func render_magic() -> void:
	super.render_magic()
	if is_assigning_spell():
		return
	_render_plant_preparation()


func activate_action(action: Dictionary) -> void:
	match str(action.get("kind", "")):
		"prepare_plant_species":
			_prepare_plant_species(str(action.get("plant_id", "")))
		"cycle_plant_parameter":
			_cycle_plant_parameter(str(action.get("parameter_id", "")))
		_:
			super.activate_action(action)


func _render_plant_preparation() -> void:
	var store: PreparedPlantLoadout = _get_prepared_plant_store()
	if store == null:
		return
	var snapshot: Dictionary = store.get_prepared_snapshot()
	var prepared_plant_id: String = str(snapshot.get("plant_id", ""))
	var prepared_name: String = str(snapshot.get("display_name", "None"))
	var parameters_value: Variant = snapshot.get("parameters", {})
	var prepared_parameters: Dictionary = (
		(parameters_value as Dictionary).duplicate(true)
		if parameters_value is Dictionary
		else {}
	)
	var discovered: Array[String] = store.get_discovered_plant_ids()
	var entries: Array[Dictionary] = PlantCatalog.get_catalog_entries(discovered)

	add_section_header("PLANT SUMMON PREPARATION")
	add_summary_card([
		"Prepared blueprint " + prepared_name,
		"Discovered plants " + str(discovered.size()),
		"Configure here • aim and cast in the field",
		"Plant Summon never opens a combat submenu",
	])

	if entries.is_empty():
		add_text_card(
			"No Plant Blueprints",
			"Discover plants in the world before Grace can prepare them for summoning.",
			"🌱",
			"Life magic"
		)
		return

	var species_grid: GridContainer = make_visual_grid(3)
	content_box.add_child(species_grid)
	for entry: Dictionary in entries:
		var plant_id: String = str(entry.get("plant_id", ""))
		var is_prepared: bool = plant_id == prepared_plant_id
		add_visual_action_tile(
			species_grid,
			"◆" if is_prepared else "◇",
			str(entry.get("display_name", plant_id.capitalize())),
			"PREPARED" if is_prepared else str(entry.get("archetype", "plant")).to_upper(),
			{"kind": "prepare_plant_species", "plant_id": plant_id},
			str(entry.get("description", ""))
			+ "\nRoles: "
			+ ", ".join(_plant_string_array(entry.get("roles", [])))
		)

	if prepared_plant_id == "":
		return

	add_section_header(prepared_name.to_upper() + " BLUEPRINT")
	var parameter_rows: Array[Dictionary] = PlantCatalog.get_preparation_rows(
		prepared_plant_id,
		prepared_parameters
	)
	if parameter_rows.is_empty():
		add_text_card(
			"Fixed Blueprint",
			"This species has no tunable preparation parameters. Selecting the species completely defines its summon.",
			"◆",
			"Ready to cast"
		)
		return

	var parameter_grid: GridContainer = make_visual_grid(3)
	content_box.add_child(parameter_grid)
	for row: Dictionary in parameter_rows:
		var parameter_id: String = str(row.get("parameter_id", ""))
		add_visual_action_tile(
			parameter_grid,
			_get_plant_parameter_icon(parameter_id),
			str(row.get("label", parameter_id.capitalize())),
			str(row.get("value_label", "Prepared")).to_upper(),
			{
				"kind": "cycle_plant_parameter",
				"parameter_id": parameter_id,
			},
			str(row.get("description", ""))
			+ "\nSelect to cycle. The chosen value is baked into future casts."
		)

	add_text_card(
		"Field Contract",
		"Once this blueprint is prepared, Plant Summon only asks Grace to aim and cast. Species, size, persistence, emergence force, and future species-specific parameters are already decided.",
		"✓",
		"No combat configuration"
	)


func _prepare_plant_species(plant_id: String) -> void:
	var store: PreparedPlantLoadout = _get_prepared_plant_store()
	if store == null:
		return
	var result: Dictionary = store.prepare_plant(plant_id, true)
	if bool(result.get("ok", false)):
		var snapshot_value: Variant = result.get("snapshot", {})
		var snapshot: Dictionary = (
			snapshot_value as Dictionary if snapshot_value is Dictionary else {}
		)
		_show_plant_message(
			"Prepared " + str(snapshot.get("display_name", plant_id.capitalize())) + "."
		)
	else:
		_show_plant_message(
			"Plant preparation failed: " + str(result.get("error", "unknown error"))
		)
	_refresh_plant_menu()


func _cycle_plant_parameter(parameter_id: String) -> void:
	var store: PreparedPlantLoadout = _get_prepared_plant_store()
	if store == null:
		return
	var result: Dictionary = store.cycle_parameter(parameter_id, 1, true)
	if bool(result.get("ok", false)):
		var snapshot_value: Variant = result.get("snapshot", {})
		var snapshot: Dictionary = (
			snapshot_value as Dictionary if snapshot_value is Dictionary else {}
		)
		var parameters_value: Variant = snapshot.get("parameters", {})
		var parameters: Dictionary = (
			parameters_value as Dictionary if parameters_value is Dictionary else {}
		)
		_show_plant_message(
			parameter_id.replace("_", " ").capitalize()
			+ ": "
			+ str(parameters.get(parameter_id, "updated")).replace("_", " ").capitalize()
		)
	else:
		_show_plant_message(
			"Plant update failed: " + str(result.get("error", "unknown error"))
		)
	_refresh_plant_menu()


func _get_prepared_plant_store() -> PreparedPlantLoadout:
	if get_tree() == null:
		return null
	return PreparedPlantLoadoutScript.get_or_create(
		get_tree()
	) as PreparedPlantLoadout


func _refresh_plant_menu() -> void:
	refresh_menu_data()
	rebuild_menu()


func _show_plant_message(text: String) -> void:
	if GameState.has_method("show_system_message"):
		GameState.call("show_system_message", text)


func _get_plant_parameter_icon(parameter_id: String) -> String:
	match parameter_id:
		"size":
			return "↕"
		"persistence":
			return "◴"
		"emergence":
			return "↑"
		_:
			return "◇"


func _plant_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value as Array:
			var text: String = str(raw)
			if text != "":
				result.append(text.replace("_", " ").capitalize())
	return result
