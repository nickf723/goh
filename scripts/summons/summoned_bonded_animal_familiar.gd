extends "res://scripts/animals/navigation_bonded_animal_actor.gd"
class_name SummonedBondedAnimalFamiliar

signal familiar_defeated(familiar: Node3D)
signal familiar_task_changed(task_data: Dictionary)
signal familiar_task_completed(task_data: Dictionary)

const BondedFamiliarRosterScript: Script = preload(
	"res://scripts/summons/bonded_familiar_roster.gd"
)

@export var display_name: String = "Bonded Animal Familiar"
@export var summon_as_bonded: bool = true
@export var summon_as_rescued: bool = true
@export var additional_task_capabilities: Array[String] = []

var summoner: Node3D
var summon_manager: Node
var familiar_definition: SummonDefinition
var familiar_loadout: Dictionary = {}
var bonded_roster: BondedFamiliarRoster
var bonded_record: Dictionary = {}
var roster_animal_id: String = ""

var active_task_receiver: Node
var active_task_id: String = ""
var active_task_phase: String = "none"
var active_task_anchor: Vector3 = Vector3.ZERO
var completed_task_count: int = 0
var last_task_result: Dictionary = {}


func _ready() -> void:
	_resolve_roster_record_before_ready()
	super._ready()
	add_to_group("player_summon")
	add_to_group("friendly_actor")
	add_to_group("animal_familiar")
	_apply_roster_identity_after_ready()
	var completion_callback := Callable(self, "_on_companion_command_completed")
	if not companion_command_completed.is_connected(completion_callback):
		companion_command_completed.connect(completion_callback)


func _exit_tree() -> void:
	_cancel_active_task("familiar removed")
	_release_roster_manifestation()
	super._exit_tree()


func initialize(owner: Node3D, manager: Node) -> void:
	summoner = owner
	summon_manager = manager
	if display_name == "" or display_name == "Bonded Animal Familiar":
		display_name = animal_name if animal_name != "" else "Animal Familiar"
	if summon_as_rescued:
		set_rescued(true, false)
	if summon_as_bonded:
		bonded = true
		follow_enabled = true
		issue_follow_command(false)
	set_navigation_ready(true)
	if bonded_roster != null and roster_animal_id != "":
		bonded_roster.begin_manifestation(roster_animal_id)


func configure_familiar(loadout: Dictionary, definition: Resource = null) -> void:
	familiar_loadout = loadout.duplicate(true)
	familiar_definition = definition as SummonDefinition if definition is SummonDefinition else null
	if familiar_definition != null and bonded_record.is_empty():
		if familiar_definition.display_name != "":
			display_name = familiar_definition.display_name
		if familiar_definition.species_id != "":
			species_id = familiar_definition.species_id
	var preferred_command: String = str(loadout.get("command", "follow")).to_lower()
	match preferred_command:
		"stay", "hold":
			issue_stay_command(global_position, false)
		_:
			issue_follow_command(false)


func get_available_familiar_commands() -> Array[String]:
	return ["follow", "stay", "come_here", "move_to"]


func get_familiar_task_capabilities() -> Array[String]:
	var capabilities: Array[String] = ["hold", "forage"]
	var normalized_species: String = species_id.to_lower().strip_edges()
	if normalized_species in ["sheep", "ram", "goat", "boar", "buffalo"]:
		capabilities.append("ram")
	if normalized_species in ["dog", "wolf", "fox", "goose", "bird"]:
		capabilities.append("scout")
	if normalized_species in ["dog", "wolf", "fox"]:
		capabilities.append("track")
	for raw: String in additional_task_capabilities:
		var capability: String = _normalize_task_id(raw)
		if capability != "" and not capabilities.has(capability):
			capabilities.append(capability)
	return capabilities


func has_familiar_task_capability(capability: String) -> bool:
	return get_familiar_task_capabilities().has(_normalize_task_id(capability))


func issue_familiar_task(receiver: Node) -> Dictionary:
	if receiver == null or not is_instance_valid(receiver):
		return {"ok": false, "error": "Familiar task target is unavailable."}
	if not receiver.has_method("get_familiar_task_preview") or not receiver.has_method("begin_familiar_task"):
		return {"ok": false, "error": "That target does not accept familiar tasks."}
	var preview_value: Variant = receiver.call("get_familiar_task_preview", self)
	if not preview_value is Dictionary:
		return {"ok": false, "error": "Familiar task preview is unavailable."}
	var preview: Dictionary = preview_value as Dictionary
	if not bool(preview.get("valid", false)):
		return {"ok": false, "error": str(preview.get("description", "That task is unavailable."))}
	_cancel_active_task("replaced")
	active_task_receiver = receiver
	active_task_id = _normalize_task_id(str(preview.get("task_id", "task")))
	active_task_phase = "moving"
	var fallback_anchor: Vector3 = global_position
	if receiver is Node3D:
		fallback_anchor = (receiver as Node3D).global_position
	active_task_anchor = preview.get("position", fallback_anchor) as Vector3
	last_task_result = {
		"ok": true,
		"task_id": active_task_id,
		"phase": active_task_phase,
		"receiver": receiver,
		"position": active_task_anchor,
		"message": display_name + " is moving to " + str(preview.get("label", "the task")) + ".",
	}
	var move_result: Dictionary = super.issue_move_to_command(active_task_anchor, false)
	if not bool(move_result.get("ok", false)):
		_cancel_active_task("navigation failed")
		return move_result
	_emit_task_state()
	return last_task_result.duplicate(true)


func cancel_familiar_task(reason: String = "cancelled") -> bool:
	if active_task_receiver == null and active_task_id == "":
		return false
	_cancel_active_task(reason)
	return true


func get_familiar_task_state() -> Dictionary:
	return {
		"active": active_task_id != "",
		"task_id": active_task_id,
		"phase": active_task_phase,
		"position": active_task_anchor,
		"receiver": active_task_receiver,
		"completed_count": completed_task_count,
		"last_result": last_task_result.duplicate(true),
		"capabilities": get_familiar_task_capabilities(),
	}


func issue_follow_command(save_now: bool = true) -> Dictionary:
	_cancel_active_task("follow command")
	return super.issue_follow_command(save_now)


func issue_stay_command(anchor: Vector3 = Vector3.INF, save_now: bool = true) -> Dictionary:
	_cancel_active_task("stay command")
	return super.issue_stay_command(anchor, save_now)


func issue_come_here_command(save_now: bool = true) -> Dictionary:
	_cancel_active_task("come here command")
	return super.issue_come_here_command(save_now)


func issue_move_to_command(destination: Vector3, save_now: bool = true) -> Dictionary:
	_cancel_active_task("move command")
	return super.issue_move_to_command(destination, save_now)


func get_familiar_command_data() -> Dictionary:
	var data: Dictionary = get_companion_command_data()
	data["display_name"] = display_name
	data["species_id"] = species_id
	data["animal_name"] = animal_name
	data["animal_id"] = roster_animal_id if roster_animal_id != "" else persistent_animal_id
	data["summoned_familiar"] = true
	data["bonded_individual"] = not bonded_record.is_empty()
	data["utility_task"] = get_familiar_task_state()
	if relationship != null:
		data["trust"] = relationship.trust
		data["familiarity"] = relationship.familiarity
	return data


func get_bonded_familiar_record() -> Dictionary:
	return bonded_record.duplicate(true)


func dismiss_familiar() -> void:
	_cancel_active_task("dismissed")
	_release_roster_manifestation()
	queue_free()


func _on_companion_command_completed(command_name: String, _completion_count: int) -> void:
	if command_name != COMMAND_MOVE_TO or active_task_phase != "moving":
		return
	if active_task_receiver == null or not is_instance_valid(active_task_receiver):
		_cancel_active_task("target unavailable")
		return
	var result_value: Variant = active_task_receiver.call("begin_familiar_task", self)
	var result: Dictionary = (
		(result_value as Dictionary).duplicate(true)
		if result_value is Dictionary
		else {"ok": bool(result_value)}
	)
	if not bool(result.get("ok", false)):
		last_task_result = result
		_cancel_active_task(str(result.get("error", "task failed")))
		return
	last_task_result = result
	if bool(result.get("ongoing", false)):
		active_task_phase = "active"
		super.issue_stay_command(active_task_anchor, false)
	else:
		active_task_phase = "completed"
		completed_task_count += 1
		familiar_task_completed.emit(get_familiar_task_state())
		active_task_receiver = null
		active_task_id = ""
		active_task_phase = "none"
	_emit_task_state()


func _cancel_active_task(reason: String) -> void:
	if active_task_receiver != null and is_instance_valid(active_task_receiver):
		if active_task_receiver.has_method("end_familiar_task"):
			active_task_receiver.call("end_familiar_task", self)
	if active_task_id != "":
		last_task_result = {
			"ok": true,
			"task_id": active_task_id,
			"cancelled": true,
			"reason": reason,
		}
	active_task_receiver = null
	active_task_id = ""
	active_task_phase = "none"
	active_task_anchor = Vector3.ZERO
	_emit_task_state()


func _emit_task_state() -> void:
	familiar_task_changed.emit(get_familiar_task_state())


func _normalize_task_id(value: String) -> String:
	return value.to_lower().strip_edges().replace(" ", "_")


func _resolve_roster_record_before_ready() -> void:
	if get_tree() == null:
		return
	bonded_roster = BondedFamiliarRosterScript.get_or_create(get_tree()) as BondedFamiliarRoster
	if bonded_roster == null:
		return
	bonded_record = bonded_roster.get_equipped_record()
	if bonded_record.is_empty():
		return
	roster_animal_id = str(bonded_record.get("animal_id", "")).to_lower().strip_edges()
	if roster_animal_id == "":
		roster_animal_id = bonded_roster.get_equipped_animal_id()
	persistent_animal_id = roster_animal_id
	animal_name = str(bonded_record.get("animal_name", animal_name))
	display_name = animal_name
	species_id = str(bonded_record.get("species_id", species_id)).to_lower().strip_edges()
	personality_profile_id = str(
		bonded_record.get("personality_profile_id", personality_profile_id)
	)


func _apply_roster_identity_after_ready() -> void:
	if bonded_record.is_empty():
		return
	animal_name = str(bonded_record.get("animal_name", animal_name))
	display_name = animal_name
	species_id = str(bonded_record.get("species_id", species_id)).to_lower().strip_edges()
	personality_profile_id = str(
		bonded_record.get("personality_profile_id", personality_profile_id)
	)
	var saved_relationship: Dictionary = bonded_record.get("relationship", {}) as Dictionary
	if relationship != null:
		relationship.trust = clampf(
			float(saved_relationship.get("trust", relationship.trust)),
			-1.0,
			1.0
		)
		relationship.familiarity = clampf(
			float(saved_relationship.get("familiarity", relationship.familiarity)),
			0.0,
			1.0
		)
		relationship.fear_association = clampf(
			float(saved_relationship.get(
				"fear_association",
				relationship.fear_association
			)),
			0.0,
			1.0
		)
		relationship_label = relationship.get_relationship_label(get_drive("fear"))
		previous_relationship_label = relationship_label


func _release_roster_manifestation() -> void:
	if bonded_roster == null or roster_animal_id == "":
		return
	bonded_roster.end_manifestation(roster_animal_id)


func _get_grace_target() -> Node3D:
	if summoner != null and is_instance_valid(summoner):
		return summoner
	return super._get_grace_target()


func _is_grace_threatening() -> bool:
	return false


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["summoned_familiar"] = {
		"display_name": display_name,
		"summoner": summoner.name if summoner != null and is_instance_valid(summoner) else "none",
		"definition": familiar_definition.summon_id if familiar_definition != null else "none",
		"commands": get_available_familiar_commands(),
		"bonded_individual": not bonded_record.is_empty(),
		"animal_id": roster_animal_id,
		"species_id": species_id,
		"utility_tasks": get_familiar_task_state(),
	}
	return data
