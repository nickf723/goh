extends "res://scripts/animals/navigation_bonded_animal_actor.gd"
class_name SummonedBondedAnimalFamiliar

signal familiar_defeated(familiar: Node3D)

const BondedFamiliarRosterScript: Script = preload(
	"res://scripts/summons/bonded_familiar_roster.gd"
)

@export var display_name: String = "Bonded Animal Familiar"
@export var summon_as_bonded: bool = true
@export var summon_as_rescued: bool = true

var summoner: Node3D
var summon_manager: Node
var familiar_definition: SummonDefinition
var familiar_loadout: Dictionary = {}
var bonded_roster: BondedFamiliarRoster
var bonded_record: Dictionary = {}
var roster_animal_id: String = ""


func _ready() -> void:
	_resolve_roster_record_before_ready()
	super._ready()
	add_to_group("player_summon")
	add_to_group("friendly_actor")
	add_to_group("animal_familiar")
	_apply_roster_identity_after_ready()


func _exit_tree() -> void:
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


func get_familiar_command_data() -> Dictionary:
	var data: Dictionary = get_companion_command_data()
	data["display_name"] = display_name
	data["species_id"] = species_id
	data["animal_name"] = animal_name
	data["animal_id"] = roster_animal_id if roster_animal_id != "" else persistent_animal_id
	data["summoned_familiar"] = true
	data["bonded_individual"] = not bonded_record.is_empty()
	if relationship != null:
		data["trust"] = relationship.trust
		data["familiarity"] = relationship.familiarity
	return data


func get_bonded_familiar_record() -> Dictionary:
	return bonded_record.duplicate(true)


func dismiss_familiar() -> void:
	_release_roster_manifestation()
	queue_free()


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
	}
	return data
