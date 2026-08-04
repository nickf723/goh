extends Node
class_name BondedFamiliarRoster

signal roster_changed(rows: Array[Dictionary])
signal equipped_familiar_changed(animal_id: String, record: Dictionary)
signal manifestation_changed(animal_id: String, active: bool)

const STORE_NODE_NAME: String = "BondedFamiliarRoster"
const DEFAULT_SAVE_PATH: String = "user://goh_bonded_familiar_roster.json"
const SAVE_VERSION: int = 1
const REFRESH_INTERVAL: float = 0.18

const BondedFamiliarScene: PackedScene = preload(
	"res://scenes/actors/summons/bonded_animal_familiar.tscn"
)
const SummonDefinitionScript: Script = preload(
	"res://scripts/summons/summon_definition.gd"
)

var save_path: String = DEFAULT_SAVE_PATH
var bond_save_path: String = ""
var bond_store: AnimalBondStore
var equipped_animal_id: String = ""
var fallback_species_id: String = ""
var manifested_animal_id: String = ""

var runtime_definition: SummonDefinition
var runtime_definition_signature: String = ""
var manager_original_definitions: Dictionary = {}
var hidden_actor_states: Dictionary = {}
var refresh_remaining: float = 0.0
var loaded_once: bool = false


static func get_or_create(
	tree: SceneTree,
	requested_path: String = "",
	requested_bond_path: String = ""
) -> BondedFamiliarRoster:
	if tree == null or tree.root == null:
		return null
	var existing: Node = tree.root.get_node_or_null(STORE_NODE_NAME)
	if existing is BondedFamiliarRoster:
		var roster := existing as BondedFamiliarRoster
		var reload_requested: bool = false
		if requested_path != "" and roster.save_path != requested_path:
			roster.save_path = requested_path
			reload_requested = true
		if requested_bond_path != "" and roster.bond_save_path != requested_bond_path:
			roster.bond_save_path = requested_bond_path
			roster._resolve_bond_store(true)
		if reload_requested:
			roster.load_from_disk()
		roster._refresh_runtime()
		return roster
	var roster := BondedFamiliarRoster.new()
	roster.name = STORE_NODE_NAME
	if requested_path != "":
		roster.save_path = requested_path
	if requested_bond_path != "":
		roster.bond_save_path = requested_bond_path
	tree.root.add_child(roster)
	return roster


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -40
	add_to_group("bonded_familiar_rosters")
	add_to_group("debuggable")
	_resolve_bond_store(true)
	load_from_disk()
	_validate_equipped_record(true)
	_apply_named_slot_to_species_service()
	_refresh_runtime()
	if not get_tree().node_added.is_connected(_on_tree_node_added):
		get_tree().node_added.connect(_on_tree_node_added)


func _process(delta: float) -> void:
	refresh_remaining -= maxf(delta, 0.0)
	if refresh_remaining > 0.0:
		return
	refresh_remaining = REFRESH_INTERVAL
	_resolve_bond_store(false)
	_validate_equipped_record(true)
	_apply_named_slot_to_species_service()
	_refresh_runtime()


func _exit_tree() -> void:
	_restore_all_world_actors()
	_restore_all_manager_definitions()
	if get_tree() != null and get_tree().node_added.is_connected(_on_tree_node_added):
		get_tree().node_added.disconnect(_on_tree_node_added)
	_disconnect_bond_store()


func get_roster_rows() -> Array[Dictionary]:
	_resolve_bond_store(false)
	var rows: Array[Dictionary] = []
	if bond_store == null:
		return rows
	var snapshot: Dictionary = bond_store.get_snapshot()
	for animal_id_value: Variant in snapshot.keys():
		var animal_id: String = _normalize_id(str(animal_id_value))
		var record_value: Variant = snapshot[animal_id_value]
		if animal_id == "" or not record_value is Dictionary:
			continue
		var record: Dictionary = (record_value as Dictionary).duplicate(true)
		if not is_record_eligible(record):
			continue
		var relationship: Dictionary = _dictionary(record.get("relationship", {}))
		var trust: float = clampf(float(relationship.get("trust", 0.0)), -1.0, 1.0)
		var familiarity: float = clampf(float(relationship.get("familiarity", 0.0)), 0.0, 1.0)
		var species_id: String = str(record.get("species_id", "unknown")).to_lower()
		rows.append({
			"animal_id": animal_id,
			"animal_name": str(record.get("animal_name", animal_id.capitalize())),
			"species_id": species_id,
			"species_name": species_id.replace("_", " ").capitalize(),
			"personality_profile_id": str(record.get("personality_profile_id", "balanced")),
			"trust": trust,
			"familiarity": familiarity,
			"fear_association": clampf(float(relationship.get("fear_association", 0.0)), 0.0, 1.0),
			"trust_tier": _trust_tier(trust, familiarity),
			"rescued": bool(record.get("rescued", record.get("bonded", false))),
			"bonded": bool(record.get("bonded", false)),
			"equipped": animal_id == equipped_animal_id,
			"manifested": animal_id == manifested_animal_id,
			"icon": _species_icon(species_id),
			"commands": ["follow", "stay", "come_here", "move_to"],
		})
	rows.sort_custom(_sort_roster_rows)
	return rows


func get_summary() -> Dictionary:
	var rows: Array[Dictionary] = get_roster_rows()
	var equipped: Dictionary = get_equipped_record()
	return {
		"eligible_count": rows.size(),
		"equipped_animal_id": equipped_animal_id,
		"equipped_name": str(equipped.get("animal_name", "None")),
		"equipped_species_id": str(equipped.get("species_id", "")),
		"fallback_species_id": fallback_species_id,
		"manifested_animal_id": manifested_animal_id,
		"manifested": manifested_animal_id != "",
	}


func get_equipped_animal_id() -> String:
	return equipped_animal_id


func get_equipped_record() -> Dictionary:
	return _get_eligible_record(equipped_animal_id)


func has_equipped_bonded_familiar() -> bool:
	return not get_equipped_record().is_empty()


func equip_animal(animal_id: String, save_now: bool = true) -> Dictionary:
	var normalized: String = _normalize_id(animal_id)
	var record: Dictionary = _get_eligible_record(normalized)
	if record.is_empty():
		return {"ok": false, "error": "Animal is not rescued and bonded."}
	var species_service: Node = get_node_or_null("/root/SpeciesKnowledge")
	if species_service != null and species_service.has_method("get_equipped_familiar_species_id"):
		var current_species: String = str(
			species_service.call("get_equipped_familiar_species_id")
		)
		if current_species != "":
			fallback_species_id = current_species
	equipped_animal_id = normalized
	runtime_definition = null
	runtime_definition_signature = ""
	_apply_named_slot_to_species_service()
	_refresh_runtime()
	if save_now:
		save_to_disk()
	equipped_familiar_changed.emit(normalized, record.duplicate(true))
	roster_changed.emit(get_roster_rows())
	return {
		"ok": true,
		"animal_id": normalized,
		"record": record.duplicate(true),
	}


func clear_equipped(
	restore_fallback: bool = true,
	save_now: bool = true
) -> Dictionary:
	var previous_id: String = equipped_animal_id
	var restore_species: String = fallback_species_id if restore_fallback else ""
	if manifested_animal_id == previous_id:
		end_manifestation(previous_id)
	equipped_animal_id = ""
	fallback_species_id = ""
	runtime_definition = null
	runtime_definition_signature = ""
	_restore_all_manager_definitions()
	if restore_species != "":
		var service: Node = get_node_or_null("/root/SpeciesKnowledge")
		if service != null and service.has_method("set_equipped_familiar_species"):
			service.call("set_equipped_familiar_species", restore_species)
	if save_now:
		save_to_disk()
	equipped_familiar_changed.emit("", {})
	roster_changed.emit(get_roster_rows())
	return {
		"ok": true,
		"previous_animal_id": previous_id,
		"restored_species_id": restore_species,
	}


func begin_manifestation(animal_id: String) -> bool:
	var normalized: String = _normalize_id(animal_id)
	if normalized == "" or normalized != equipped_animal_id:
		return false
	if _get_eligible_record(normalized).is_empty():
		return false
	manifested_animal_id = normalized
	_refresh_world_duplicates()
	manifestation_changed.emit(normalized, true)
	roster_changed.emit(get_roster_rows())
	return true


func end_manifestation(animal_id: String = "") -> bool:
	var normalized: String = _normalize_id(animal_id)
	if manifested_animal_id == "":
		return false
	if normalized != "" and normalized != manifested_animal_id:
		return false
	var previous_id: String = manifested_animal_id
	manifested_animal_id = ""
	_refresh_world_duplicates()
	manifestation_changed.emit(previous_id, false)
	roster_changed.emit(get_roster_rows())
	return true


func is_manifested(animal_id: String) -> bool:
	return manifested_animal_id != "" and manifested_animal_id == _normalize_id(animal_id)


func get_runtime_summon_definition() -> SummonDefinition:
	var record: Dictionary = get_equipped_record()
	if record.is_empty():
		return null
	var signature: String = (
		equipped_animal_id
		+ "|"
		+ str(record.get("animal_name", "Familiar"))
		+ "|"
		+ str(record.get("species_id", "unknown"))
	)
	if runtime_definition != null and runtime_definition_signature == signature:
		return runtime_definition
	var definition := SummonDefinitionScript.new() as SummonDefinition
	definition.summon_id = "bonded_familiar:" + equipped_animal_id
	definition.species_id = ""
	definition.unlock_id = ""
	definition.display_name = str(record.get("animal_name", "Bonded Familiar"))
	definition.summon_scene = BondedFamiliarScene
	definition.maximum_active = 1
	definition.presence_cost = 1
	definition.mana_cost = 3
	definition.defeat_cooldown = 8.0
	definition.summon_offset = Vector3(1.8, 0.2, -1.5)
	definition.roles = ["companion", "animal", "bonded"]
	definition.supported_familiar_roles = ["companion"]
	runtime_definition = definition
	runtime_definition_signature = signature
	return runtime_definition


func save_to_disk() -> Dictionary:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return {
			"ok": false,
			"error": "Bonded familiar roster save failed: " + str(FileAccess.get_open_error()),
		}
	file.store_string(JSON.stringify({
		"version": SAVE_VERSION,
		"equipped_animal_id": equipped_animal_id,
		"fallback_species_id": fallback_species_id,
	}, "\t"))
	file.close()
	return {
		"ok": true,
		"path": save_path,
		"equipped_animal_id": equipped_animal_id,
	}


func load_from_disk() -> bool:
	loaded_once = true
	equipped_animal_id = ""
	fallback_species_id = ""
	manifested_animal_id = ""
	if not FileAccess.file_exists(save_path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not parsed is Dictionary:
		return false
	var data: Dictionary = parsed as Dictionary
	equipped_animal_id = _normalize_id(str(data.get("equipped_animal_id", "")))
	fallback_species_id = str(data.get("fallback_species_id", "")).to_lower().strip_edges()
	runtime_definition = null
	runtime_definition_signature = ""
	return true


func _resolve_bond_store(force: bool) -> void:
	if bond_store != null and is_instance_valid(bond_store) and not force:
		return
	_disconnect_bond_store()
	bond_store = AnimalBondStore.get_or_create(get_tree(), bond_save_path)
	if bond_store == null:
		return
	var callback := Callable(self, "_on_bond_record_changed")
	if not bond_store.record_changed.is_connected(callback):
		bond_store.record_changed.connect(callback)


func _disconnect_bond_store() -> void:
	if bond_store == null or not is_instance_valid(bond_store):
		return
	var callback := Callable(self, "_on_bond_record_changed")
	if bond_store.record_changed.is_connected(callback):
		bond_store.record_changed.disconnect(callback)


func _on_bond_record_changed(animal_id: String, _record: Dictionary) -> void:
	if _normalize_id(animal_id) == equipped_animal_id:
		runtime_definition = null
		runtime_definition_signature = ""
		_validate_equipped_record(true)
	_refresh_runtime()
	roster_changed.emit(get_roster_rows())


func _validate_equipped_record(save_if_changed: bool) -> bool:
	if equipped_animal_id == "":
		return true
	if not _get_eligible_record(equipped_animal_id).is_empty():
		return true
	var restore_species: String = fallback_species_id
	equipped_animal_id = ""
	fallback_species_id = ""
	manifested_animal_id = ""
	runtime_definition = null
	runtime_definition_signature = ""
	_restore_all_manager_definitions()
	if restore_species != "":
		var service: Node = get_node_or_null("/root/SpeciesKnowledge")
		if service != null and service.has_method("set_equipped_familiar_species"):
			service.call("set_equipped_familiar_species", restore_species)
	if save_if_changed and loaded_once:
		save_to_disk()
	return false


func _get_eligible_record(animal_id: String) -> Dictionary:
	var normalized: String = _normalize_id(animal_id)
	if normalized == "" or bond_store == null:
		return {}
	var record: Dictionary = bond_store.get_record(normalized)
	return record if is_record_eligible(record) else {}


func is_record_eligible(record: Dictionary) -> bool:
	if record.is_empty() or not bool(record.get("bonded", false)):
		return false
	return bool(record.get("rescued", record.get("bonded", false)))


func _apply_named_slot_to_species_service() -> void:
	if equipped_animal_id == "":
		return
	var service: Node = get_node_or_null("/root/SpeciesKnowledge")
	if service == null or not service.has_method("get_equipped_familiar_species_id"):
		return
	var current_species: String = str(service.call("get_equipped_familiar_species_id"))
	if current_species != "" and fallback_species_id == "":
		fallback_species_id = current_species
		save_to_disk()
	if current_species != "" and service.has_method("set_equipped_familiar_species"):
		service.call("set_equipped_familiar_species", "")


func _refresh_runtime() -> void:
	_refresh_manager_definitions()
	_refresh_world_duplicates()


func _refresh_manager_definitions() -> void:
	var definition: SummonDefinition = get_runtime_summon_definition()
	var active_named_slot: bool = definition != null
	var live_ids: Array[int] = []
	for manager: Node in get_tree().get_nodes_in_group("summon_managers"):
		if manager == null or not is_instance_valid(manager):
			continue
		var manager_id: int = manager.get_instance_id()
		live_ids.append(manager_id)
		if not manager_original_definitions.has(manager_id):
			manager_original_definitions[manager_id] = {
				"manager": manager,
				"definition": manager.get("summon_definition"),
			}
		if active_named_slot:
			manager.set("summon_definition", definition)
		else:
			_restore_manager_definition(manager_id)
	for raw_id: Variant in manager_original_definitions.keys().duplicate():
		var manager_id: int = int(raw_id)
		if not live_ids.has(manager_id):
			manager_original_definitions.erase(manager_id)


func _restore_manager_definition(manager_id: int) -> void:
	if not manager_original_definitions.has(manager_id):
		return
	var state: Dictionary = manager_original_definitions[manager_id] as Dictionary
	var manager_value: Variant = state.get("manager")
	if manager_value is Node and is_instance_valid(manager_value as Node):
		(manager_value as Node).set("summon_definition", state.get("definition"))


func _restore_all_manager_definitions() -> void:
	for raw_id: Variant in manager_original_definitions.keys().duplicate():
		_restore_manager_definition(int(raw_id))
	manager_original_definitions.clear()


func _refresh_world_duplicates() -> void:
	var should_hide_ids: Array[int] = []
	for candidate: Node in get_tree().get_nodes_in_group("generic_animals"):
		if candidate == null or not is_instance_valid(candidate):
			continue
		if candidate.is_in_group("animal_familiar"):
			continue
		var persistent_value: Variant = candidate.get("persistent_animal_id")
		var animal_id: String = _normalize_id(str(persistent_value)) if persistent_value != null else ""
		var candidate_id: int = candidate.get_instance_id()
		if manifested_animal_id != "" and animal_id == manifested_animal_id:
			should_hide_ids.append(candidate_id)
			_hide_world_actor(candidate)
		elif hidden_actor_states.has(candidate_id):
			_restore_world_actor(candidate_id)
	for raw_id: Variant in hidden_actor_states.keys().duplicate():
		var actor_id: int = int(raw_id)
		if not should_hide_ids.has(actor_id):
			_restore_world_actor(actor_id)


func _hide_world_actor(actor: Node) -> void:
	var actor_id: int = actor.get_instance_id()
	if hidden_actor_states.has(actor_id):
		return
	var state: Dictionary = {
		"actor": actor,
		"visible": actor.visible if actor is Node3D else true,
		"physics_processing": actor.is_physics_processing(),
	}
	if actor is CollisionObject3D:
		state["collision_layer"] = (actor as CollisionObject3D).collision_layer
		state["collision_mask"] = (actor as CollisionObject3D).collision_mask
	hidden_actor_states[actor_id] = state
	if actor is Node3D:
		(actor as Node3D).visible = false
	if actor is CollisionObject3D:
		(actor as CollisionObject3D).collision_layer = 0
		(actor as CollisionObject3D).collision_mask = 0
	actor.set_physics_process(false)
	actor.set_meta("bonded_familiar_world_suppressed", true)


func _restore_world_actor(actor_id: int) -> void:
	if not hidden_actor_states.has(actor_id):
		return
	var state: Dictionary = hidden_actor_states[actor_id] as Dictionary
	hidden_actor_states.erase(actor_id)
	var actor_value: Variant = state.get("actor")
	if not actor_value is Node or not is_instance_valid(actor_value as Node):
		return
	var actor: Node = actor_value as Node
	if actor is Node3D:
		(actor as Node3D).visible = bool(state.get("visible", true))
	if actor is CollisionObject3D:
		(actor as CollisionObject3D).collision_layer = int(state.get("collision_layer", 1))
		(actor as CollisionObject3D).collision_mask = int(state.get("collision_mask", 1))
	actor.set_physics_process(bool(state.get("physics_processing", true)))
	actor.remove_meta("bonded_familiar_world_suppressed")


func _restore_all_world_actors() -> void:
	for raw_id: Variant in hidden_actor_states.keys().duplicate():
		_restore_world_actor(int(raw_id))


func _on_tree_node_added(_node: Node) -> void:
	call_deferred("_refresh_runtime")


func _sort_roster_rows(a: Dictionary, b: Dictionary) -> bool:
	var a_equipped: bool = bool(a.get("equipped", false))
	var b_equipped: bool = bool(b.get("equipped", false))
	if a_equipped != b_equipped:
		return a_equipped
	return str(a.get("animal_name", "")) < str(b.get("animal_name", ""))


func _trust_tier(trust: float, familiarity: float) -> String:
	if trust >= 0.82 and familiarity >= 0.72:
		return "Devoted"
	if trust >= 0.68 and familiarity >= 0.55:
		return "Bonded"
	if trust >= 0.52:
		return "Trusting"
	return "New Bond"


func _species_icon(species_id: String) -> String:
	match species_id:
		"sheep": return "🐑"
		"goose": return "🪿"
		"capybara": return "◉"
		"wolf": return "◇"
		"gremlin": return "◆"
		_: return "✦"


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _normalize_id(value: String) -> String:
	return value.to_lower().strip_edges().replace(" ", "_")


func get_debug_data() -> Dictionary:
	return {
		"save_path": save_path,
		"bond_save_path": bond_store.save_path if bond_store != null else bond_save_path,
		"eligible_count": get_roster_rows().size(),
		"equipped_animal_id": equipped_animal_id,
		"fallback_species_id": fallback_species_id,
		"manifested_animal_id": manifested_animal_id,
		"manager_override_count": manager_original_definitions.size(),
		"hidden_world_actor_count": hidden_actor_states.size(),
		"runtime_definition": (
			runtime_definition.summon_id if runtime_definition != null else "none"
		),
	}
