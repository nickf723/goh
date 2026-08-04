extends "res://scripts/animals/navigation_bonded_animal_actor.gd"
class_name SummonedBondedAnimalFamiliar

signal familiar_defeated(familiar: Node3D)

@export var display_name: String = "Bonded Animal Familiar"
@export var summon_as_bonded: bool = true
@export var summon_as_rescued: bool = true

var summoner: Node3D
var summon_manager: Node
var familiar_definition: SummonDefinition
var familiar_loadout: Dictionary = {}


func _ready() -> void:
	super._ready()
	add_to_group("player_summon")
	add_to_group("friendly_actor")
	add_to_group("animal_familiar")


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


func configure_familiar(loadout: Dictionary, definition: Resource = null) -> void:
	familiar_loadout = loadout.duplicate(true)
	familiar_definition = definition as SummonDefinition if definition is SummonDefinition else null
	if familiar_definition != null:
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
	data["summoned_familiar"] = true
	return data


func dismiss_familiar() -> void:
	queue_free()


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
	}
	return data
