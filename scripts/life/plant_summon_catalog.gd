extends RefCounted
class_name PlantSummonCatalog

const BroadleafSprout: PlantSummonDefinition = preload(
	"res://data/plants/broadleaf_sprout.tres"
)

const PLANT_DEFINITIONS: Dictionary = {
	"broadleaf_sprout": BroadleafSprout,
}

const SPELL_TO_PLANT_ID: Dictionary = {
	"sprout": "broadleaf_sprout",
}

const DEFAULT_DISCOVERED_PLANTS: Array[String] = [
	"broadleaf_sprout",
]


static func get_definition(plant_id: String) -> PlantSummonDefinition:
	var normalized: String = plant_id.strip_edges().to_lower()
	var value: Variant = PLANT_DEFINITIONS.get(normalized)
	return value as PlantSummonDefinition if value is PlantSummonDefinition else null


static func get_all_plant_ids() -> Array[String]:
	var ids: Array[String] = []
	for key: Variant in PLANT_DEFINITIONS.keys():
		ids.append(str(key))
	ids.sort()
	return ids


static func get_default_discovered_plant_ids() -> Array[String]:
	return DEFAULT_DISCOVERED_PLANTS.duplicate()


static func get_plant_id_for_ability(ability: AbilityDefinition) -> String:
	if ability == null:
		return ""
	var spell_id: String = ability.get_spell_id()
	return str(SPELL_TO_PLANT_ID.get(spell_id, ""))


static func get_definition_for_ability(
	ability: AbilityDefinition
) -> PlantSummonDefinition:
	return get_definition(get_plant_id_for_ability(ability))


static func get_ground_spell_definition_for_ability(
	ability: AbilityDefinition
) -> Dictionary:
	var plant_id: String = get_plant_id_for_ability(ability)
	if plant_id == "":
		return {}
	return get_ground_spell_definition(plant_id, ability.get_spell_id())


static func get_ground_spell_definition_for_key(spell_key: String) -> Dictionary:
	var prefix: String = "plant_summon:"
	if not spell_key.begins_with(prefix):
		return {}
	var plant_id: String = spell_key.trim_prefix(prefix)
	return get_ground_spell_definition(plant_id, "")


static func is_plant_ground_spell_key(spell_key: String) -> bool:
	return spell_key.begins_with("plant_summon:") and get_definition(
		spell_key.trim_prefix("plant_summon:")
	) != null


static func get_ground_spell_definition(
	plant_id: String,
	spell_id: String = ""
) -> Dictionary:
	var definition: PlantSummonDefinition = get_definition(plant_id)
	if definition == null:
		return {}
	var resolved_spell_id: String = spell_id
	if resolved_spell_id == "":
		for candidate_value: Variant in SPELL_TO_PLANT_ID.keys():
			var candidate: String = str(candidate_value)
			if str(SPELL_TO_PLANT_ID[candidate]) == plant_id:
				resolved_spell_id = candidate
				break
	var marker_radius: float = maxf(definition.canopy_radius, 0.7)
	return {
		"spell_key": "plant_summon:" + plant_id,
		"spell_ids": [resolved_spell_id] if resolved_spell_id != "" else [],
		"display_names": [definition.display_name.to_lower()],
		"element": "life",
		"effect_type": "spawn_field",
		"post_spawn_method": "activate_from_ground_target",
		"plant_id": plant_id,
		"begin_message": (
			"Place " + definition.display_name
			+ ". Right stick moves the growth mark. Cast confirms. Cancel backs out."
		),
		"cancel_message": definition.display_name + " growth canceled.",
		"confirm_message": definition.display_name + " bursts from the ground.",
		"target": {
			"marker_name": "PlantSummonTargetMarker",
			"disc_name": "PlantSummonGrowthDisc",
			"center_name": "PlantSummonGrowthCenter",
			"shape": "circle",
			"placement": "free_ground",
			"radius": marker_radius,
			"range": 15.0,
			"minimum_range": 0.0,
			"initial_distance": 5.5,
			"speed": 8.5,
			"deadzone": 0.18,
			"ground_y_offset": 0.04,
			"cast_lock_duration": 0.2,
			"require_ground": true,
			"require_line_of_sight": true,
			"allow_through_obstacles": false,
			"show_direction_line": true,
			"disc_color": Color(0.12, 0.72, 0.18, 0.28),
			"center_color": Color(0.38, 0.95, 0.2, 0.88),
			"disc_alpha": 0.28,
			"center_alpha": 0.88,
			"outline_alpha": 0.96,
			"pulse_speed": 4.6,
			"pulse_size": 0.06,
			"emission_energy": 0.82,
			"preview_label": (
				definition.display_name.to_upper()
				+ " • "
				+ definition.growth_archetype.to_upper()
			),
		},
		"payload": {
			"source_name": definition.display_name,
			"hit_type": "plant_summon",
			"tags": [
				"life",
				"plant_summon",
				plant_id,
				definition.growth_archetype,
			],
		},
	}


static func get_catalog_entries(plant_ids: Array[String] = []) -> Array[Dictionary]:
	var ids: Array[String] = plant_ids
	if ids.is_empty():
		ids = get_all_plant_ids()
	var rows: Array[Dictionary] = []
	for plant_id: String in ids:
		var definition: PlantSummonDefinition = get_definition(plant_id)
		if definition == null:
			continue
		rows.append({
			"plant_id": definition.plant_id,
			"display_name": definition.display_name,
			"archetype": definition.growth_archetype,
			"roles": definition.roles.duplicate(),
			"description": definition.description,
		})
	return rows
