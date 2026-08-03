extends RefCounted
class_name CreatureAbilityCatalog

const MobMoveCatalogScript = preload("res://scripts/mobs/mob_move_catalog.gd")
const MobSpeciesCatalogScript = preload("res://scripts/mobs/mob_species_catalog.gd")
const MobProgressionServiceScript = preload("res://scripts/mobs/mob_progression_service.gd")
const MobMoveAugmentCatalogScript = preload("res://scripts/mobs/mob_move_augment_catalog.gd")

const GremlinBiteOption: Resource = preload(
	"res://data/enemy_action_options/gremlin_bite_option.tres"
)
const GremlinBackstepOption: Resource = preload(
	"res://data/enemy_action_options/gremlin_backstep_option.tres"
)
const GremlinPounceOption: Resource = preload(
	"res://data/enemy_action_options/gremlin_pounce_option.tres"
)
const GremlinMireSpitOption: Resource = preload(
	"res://data/enemy_action_options/storm_drain_mire_spit_option.tres"
)

# Existing runtime action resources remain here as execution adapters. The
# generic mob catalog owns move identity, eligibility, progression, and
# augmentation; an actor may still resolve a move into one of these legacy
# EnemyActionOption resources until its animation/execution driver is migrated.
const SPECIES_TECHNIQUES: Dictionary = {
	"gremlin": {
		"bite": GremlinBiteOption,
		"backstep": GremlinBackstepOption,
		"pounce": GremlinPounceOption,
		"mire_spit": GremlinMireSpitOption,
	},
}


static func get_option(species_id: String, technique_id: String) -> Resource:
	var species_value: Variant = SPECIES_TECHNIQUES.get(species_id, {})
	if not species_value is Dictionary:
		return null
	var species: Dictionary = species_value as Dictionary
	var option_value: Variant = species.get(technique_id)
	return option_value as Resource if option_value is Resource else null


static func get_action(species_id: String, technique_id: String) -> Resource:
	var option: Resource = get_option(species_id, technique_id)
	if option == null or not option.has_method("get_action"):
		return null
	var action_value: Variant = option.call("get_action")
	return action_value as Resource if action_value is Resource else null


static func get_technique_ids(species_id: String) -> Array[String]:
	# Compatibility API: this returns only techniques that currently have a live
	# EnemyActionOption execution adapter.
	var result: Array[String] = []
	var species_value: Variant = SPECIES_TECHNIQUES.get(species_id, {})
	if not species_value is Dictionary:
		return result
	for technique_value: Variant in (species_value as Dictionary).keys():
		result.append(str(technique_value))
	result.sort()
	return result


static func get_move_definition(
	species_id: String,
	move_id: String
) -> MobMoveDefinition:
	if MobSpeciesCatalogScript.get_move_policy(species_id, move_id) == null:
		return null
	return MobMoveCatalogScript.get_definition(move_id)


static func get_move_policy(
	species_id: String,
	move_id: String
) -> MobMovePolicy:
	return MobSpeciesCatalogScript.get_move_policy(species_id, move_id)


static func get_mob_move_ids(species_id: String) -> Array[String]:
	return MobSpeciesCatalogScript.get_move_ids(species_id)


static func get_resolved_move(species_id: String, move_id: String) -> Dictionary:
	return MobProgressionServiceScript.resolve_move(species_id, move_id)


static func get_compatible_augments(
	species_id: String,
	move_id: String
) -> Array[String]:
	var move: MobMoveDefinition = get_move_definition(species_id, move_id)
	return (
		MobMoveAugmentCatalogScript.get_compatible_augments(move)
		if move != null
		else []
	)


static func get_technique_debug_row(
	species_id: String,
	technique_id: String
) -> Dictionary:
	var option: Resource = get_option(species_id, technique_id)
	var action: Resource = get_action(species_id, technique_id)
	var move: MobMoveDefinition = get_move_definition(species_id, technique_id)
	return {
		"species_id": species_id,
		"technique_id": technique_id,
		"option_available": option != null,
		"action_available": action != null,
		"mob_move_available": move != null,
		"display_name": (
			move.display_name
			if move != null
			else str(option.call("get_display_name"))
			if option != null and option.has_method("get_display_name")
			else technique_id.replace("_", " ").capitalize()
		),
		"action_kind": (
			move.action_kind
			if move != null
			else str(option.call("get_action_kind"))
			if option != null and option.has_method("get_action_kind")
			else "none"
		),
		"compatible_augments": get_compatible_augments(species_id, technique_id),
	}


static func get_debug_data() -> Dictionary:
	var legacy_rows: Array[Dictionary] = []
	for species_value: Variant in SPECIES_TECHNIQUES.keys():
		var species_id: String = str(species_value)
		for technique_id: String in get_technique_ids(species_id):
			legacy_rows.append(get_technique_debug_row(species_id, technique_id))
	return {
		"legacy_species_count": SPECIES_TECHNIQUES.size(),
		"legacy_technique_count": legacy_rows.size(),
		"legacy_techniques": legacy_rows,
		"mob_species_count": MobSpeciesCatalogScript.get_species_ids().size(),
		"mob_move_count": MobMoveCatalogScript.get_move_ids().size(),
		"mob_catalog_failures": MobSpeciesCatalogScript.validate_catalog(),
	}
