extends Node
class_name PreparedPlantLoadout

signal preparation_changed(snapshot: Dictionary)
signal plant_discovered(plant_id: String)

const STORE_NODE_NAME: String = "PreparedPlantLoadout"
const DEFAULT_SAVE_PATH: String = "user://goh_prepared_plant_loadout.json"
const SAVE_VERSION: int = 1
const PlantCatalog = preload("res://scripts/life/plant_summon_catalog.gd")

var save_path: String = DEFAULT_SAVE_PATH
var prepared_plant_id: String = ""
var prepared_parameters: Dictionary = {}
var discovered_plant_ids: Array[String] = []
var loaded_once: bool = false


static func get_or_create(
	tree: SceneTree,
	requested_path: String = ""
) -> PreparedPlantLoadout:
	if tree == null or tree.root == null:
		return null
	var existing: Node = tree.root.get_node_or_null(STORE_NODE_NAME)
	if existing is PreparedPlantLoadout:
		var store := existing as PreparedPlantLoadout
		if requested_path != "" and requested_path != store.save_path:
			store.save_path = requested_path
			store.load_from_disk()
		return store
	var store := PreparedPlantLoadout.new()
	store.name = STORE_NODE_NAME
	if requested_path != "":
		store.save_path = requested_path
	tree.root.add_child(store)
	return store


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("prepared_plant_loadouts")
	add_to_group("debuggable")
	load_from_disk()
	_ensure_defaults()


func get_prepared_snapshot() -> Dictionary:
	_ensure_defaults()
	var definition: PlantSummonDefinition = PlantCatalog.get_definition(
		prepared_plant_id
	)
	return {
		"plant_id": prepared_plant_id,
		"display_name": (
			definition.display_name if definition != null else "None"
		),
		"parameters": prepared_parameters.duplicate(true),
		"schema": PlantCatalog.get_preparation_schema(prepared_plant_id),
		"discovered": discovered_plant_ids.duplicate(),
	}


func get_prepared_plant_id() -> String:
	_ensure_defaults()
	return prepared_plant_id


func get_prepared_parameters() -> Dictionary:
	_ensure_defaults()
	return prepared_parameters.duplicate(true)


func get_discovered_plant_ids() -> Array[String]:
	_ensure_defaults()
	return discovered_plant_ids.duplicate()


func is_plant_discovered(plant_id: String) -> bool:
	return discovered_plant_ids.has(_normalize_id(plant_id))


func discover_plant(plant_id: String, save_now: bool = true) -> Dictionary:
	var normalized: String = _normalize_id(plant_id)
	if PlantCatalog.get_definition(normalized) == null:
		return {"ok": false, "error": "Unknown plant species."}
	var is_new: bool = not discovered_plant_ids.has(normalized)
	if is_new:
		discovered_plant_ids.append(normalized)
		discovered_plant_ids.sort()
		plant_discovered.emit(normalized)
	if prepared_plant_id == "":
		prepare_plant(normalized, false)
	if save_now:
		save_to_disk()
	if is_new:
		preparation_changed.emit(get_prepared_snapshot())
	return {"ok": true, "plant_id": normalized, "new": is_new}


func prepare_plant(plant_id: String, save_now: bool = true) -> Dictionary:
	var normalized: String = _normalize_id(plant_id)
	if not is_plant_discovered(normalized):
		return {"ok": false, "error": "Plant has not been discovered."}
	var definition: PlantSummonDefinition = PlantCatalog.get_definition(normalized)
	if definition == null:
		return {"ok": false, "error": "Plant definition is unavailable."}
	prepared_plant_id = normalized
	prepared_parameters = PlantCatalog.sanitize_preparation(
		normalized,
		{}
	)
	if save_now:
		save_to_disk()
	preparation_changed.emit(get_prepared_snapshot())
	return {"ok": true, "snapshot": get_prepared_snapshot()}


func set_parameter(
	parameter_id: String,
	value: String,
	save_now: bool = true
) -> Dictionary:
	_ensure_defaults()
	var normalized_parameter: String = _normalize_id(parameter_id)
	var candidate: Dictionary = prepared_parameters.duplicate(true)
	candidate[normalized_parameter] = value.strip_edges().to_lower()
	var sanitized: Dictionary = PlantCatalog.sanitize_preparation(
		prepared_plant_id,
		candidate
	)
	if not sanitized.has(normalized_parameter):
		return {"ok": false, "error": "Parameter is unavailable for this plant."}
	prepared_parameters = sanitized
	if save_now:
		save_to_disk()
	preparation_changed.emit(get_prepared_snapshot())
	return {"ok": true, "snapshot": get_prepared_snapshot()}


func cycle_parameter(
	parameter_id: String,
	direction: int = 1,
	save_now: bool = true
) -> Dictionary:
	_ensure_defaults()
	var normalized_parameter: String = _normalize_id(parameter_id)
	var schema: Dictionary = PlantCatalog.get_preparation_schema(prepared_plant_id)
	var parameter_value: Variant = schema.get(normalized_parameter)
	if not parameter_value is Dictionary:
		return {"ok": false, "error": "Parameter is unavailable for this plant."}
	var parameter: Dictionary = parameter_value as Dictionary
	var options_value: Variant = parameter.get("options", [])
	if not options_value is Array or (options_value as Array).is_empty():
		return {"ok": false, "error": "Parameter has no options."}
	var options: Array = options_value as Array
	var current: String = str(
		prepared_parameters.get(
			normalized_parameter,
			parameter.get("default", options[0])
		)
	)
	var index: int = options.find(current)
	if index < 0:
		index = 0
	var step: int = 1 if direction >= 0 else -1
	var next_value: String = str(options[posmod(index + step, options.size())])
	return set_parameter(normalized_parameter, next_value, save_now)


func save_to_disk() -> Dictionary:
	_ensure_defaults()
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return {
			"ok": false,
			"error": "Plant preparation save failed: " + str(FileAccess.get_open_error()),
		}
	file.store_string(JSON.stringify({
		"version": SAVE_VERSION,
		"prepared_plant_id": prepared_plant_id,
		"prepared_parameters": prepared_parameters,
		"discovered_plant_ids": discovered_plant_ids,
	}, "\t"))
	file.close()
	return {"ok": true, "path": save_path}


func load_from_disk() -> bool:
	loaded_once = true
	prepared_plant_id = ""
	prepared_parameters = {}
	discovered_plant_ids.clear()
	if not FileAccess.file_exists(save_path):
		_ensure_defaults()
		return false
	var parsed: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(save_path)
	)
	if not parsed is Dictionary:
		_ensure_defaults()
		return false
	var data: Dictionary = parsed as Dictionary
	var discovered_value: Variant = data.get("discovered_plant_ids", [])
	if discovered_value is Array:
		for value: Variant in discovered_value as Array:
			var plant_id: String = _normalize_id(str(value))
			if (
				plant_id != ""
				and PlantCatalog.get_definition(plant_id) != null
				and not discovered_plant_ids.has(plant_id)
			):
				discovered_plant_ids.append(plant_id)
	prepared_plant_id = _normalize_id(str(data.get("prepared_plant_id", "")))
	var parameters_value: Variant = data.get("prepared_parameters", {})
	prepared_parameters = (
		(parameters_value as Dictionary).duplicate(true)
		if parameters_value is Dictionary
		else {}
	)
	_ensure_defaults()
	return true


func _ensure_defaults() -> void:
	for default_id: String in PlantCatalog.get_default_discovered_plant_ids():
		if (
			PlantCatalog.get_definition(default_id) != null
			and not discovered_plant_ids.has(default_id)
		):
			discovered_plant_ids.append(default_id)
	discovered_plant_ids.sort()
	if (
		prepared_plant_id == ""
		or not discovered_plant_ids.has(prepared_plant_id)
		or PlantCatalog.get_definition(prepared_plant_id) == null
	):
		prepared_plant_id = (
			discovered_plant_ids[0] if not discovered_plant_ids.is_empty() else ""
		)
	prepared_parameters = PlantCatalog.sanitize_preparation(
		prepared_plant_id,
		prepared_parameters
	)


func _normalize_id(value: String) -> String:
	return value.strip_edges().to_lower().replace(" ", "_")


func get_debug_data() -> Dictionary:
	var snapshot: Dictionary = get_prepared_snapshot()
	return {
		"prepared_plant_id": prepared_plant_id,
		"prepared_parameters": prepared_parameters.duplicate(true),
		"discovered_count": discovered_plant_ids.size(),
		"combat_configuration_required": false,
		"snapshot": snapshot,
	}
