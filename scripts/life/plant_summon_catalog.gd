extends RefCounted
class_name PlantSummonCatalog

const BroadleafSprout: PlantSummonDefinition = preload(
	"res://data/plants/broadleaf_sprout.tres"
)

const PLANT_DEFINITIONS: Dictionary = {
	"broadleaf_sprout": BroadleafSprout,
}

# Compatibility mapping for the original Sprout spell id. The combat spell no
# longer hard-selects this species; PreparedPlantLoadout owns that choice.
const PLANT_SUMMON_SPELL_IDS: Array[String] = [
	"sprout",
	"plant_summon",
]

const DEFAULT_DISCOVERED_PLANTS: Array[String] = [
	"broadleaf_sprout",
]

# Preparation happens outside combat, like familiar role/temperament/techniques.
# Every option is deliberately discrete so a saved blueprint is deterministic and
# easy to display in the full Magic menu. Future species can expose completely
# different parameter sets without changing Plant Summon's combat input grammar.
const PREPARATION_SCHEMAS: Dictionary = {
	"broadleaf_sprout": {
		"size": {
			"label": "Growth Size",
			"default": "standard",
			"options": ["compact", "standard", "large"],
			"descriptions": {
				"compact": "Smaller crown and step; easier to fit into tight spaces.",
				"standard": "Balanced traversal footprint.",
				"large": "Wider and taller platform with a larger growth footprint.",
			},
		},
		"persistence": {
			"label": "Persistence",
			"default": "standard",
			"options": ["brief", "standard", "persistent"],
			"descriptions": {
				"brief": "Short-lived growth for quick traversal tricks.",
				"standard": "Balanced lifetime.",
				"persistent": "Longer-lived temporary terrain.",
			},
		},
		"emergence": {
			"label": "Emergence Force",
			"default": "balanced",
			"options": ["gentle", "balanced", "forceful"],
			"descriptions": {
				"gentle": "Minimal lift when the plant emerges.",
				"balanced": "Normal growth lift.",
				"forceful": "Stronger upward shove for bodies caught over the sprout.",
			},
		},
	},
}


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


static func is_plant_summon_ability(ability: AbilityDefinition) -> bool:
	return (
		ability != null
		and PLANT_SUMMON_SPELL_IDS.has(ability.get_spell_id())
	)


static func get_preparation_schema(plant_id: String) -> Dictionary:
	var normalized: String = plant_id.strip_edges().to_lower()
	var value: Variant = PREPARATION_SCHEMAS.get(normalized, {})
	return (
		(value as Dictionary).duplicate(true)
		if value is Dictionary
		else {}
	)


static func get_default_preparation(plant_id: String) -> Dictionary:
	var schema: Dictionary = get_preparation_schema(plant_id)
	var result: Dictionary = {}
	for parameter_value: Variant in schema.keys():
		var parameter_id: String = str(parameter_value)
		var definition_value: Variant = schema[parameter_value]
		if not definition_value is Dictionary:
			continue
		var parameter: Dictionary = definition_value as Dictionary
		var options_value: Variant = parameter.get("options", [])
		var fallback: String = ""
		if options_value is Array and not (options_value as Array).is_empty():
			fallback = str((options_value as Array)[0])
		result[parameter_id] = str(parameter.get("default", fallback))
	return result


static func sanitize_preparation(
	plant_id: String,
	candidate: Dictionary
) -> Dictionary:
	var schema: Dictionary = get_preparation_schema(plant_id)
	var defaults: Dictionary = get_default_preparation(plant_id)
	var result: Dictionary = {}
	for parameter_value: Variant in schema.keys():
		var parameter_id: String = str(parameter_value)
		var definition_value: Variant = schema[parameter_value]
		if not definition_value is Dictionary:
			continue
		var parameter: Dictionary = definition_value as Dictionary
		var options_value: Variant = parameter.get("options", [])
		var options: Array = options_value as Array if options_value is Array else []
		var selected: String = str(
			candidate.get(parameter_id, defaults.get(parameter_id, ""))
		).strip_edges().to_lower()
		if options.is_empty() or not options.has(selected):
			selected = str(defaults.get(parameter_id, ""))
		result[parameter_id] = selected
	return result


static func get_preparation_rows(
	plant_id: String,
	prepared: Dictionary
) -> Array[Dictionary]:
	var schema: Dictionary = get_preparation_schema(plant_id)
	var sanitized: Dictionary = sanitize_preparation(plant_id, prepared)
	var rows: Array[Dictionary] = []
	for parameter_value: Variant in schema.keys():
		var parameter_id: String = str(parameter_value)
		var definition_value: Variant = schema[parameter_value]
		if not definition_value is Dictionary:
			continue
		var parameter: Dictionary = definition_value as Dictionary
		var selected: String = str(sanitized.get(parameter_id, ""))
		var descriptions_value: Variant = parameter.get("descriptions", {})
		var descriptions: Dictionary = (
			descriptions_value as Dictionary
			if descriptions_value is Dictionary
			else {}
		)
		rows.append({
			"parameter_id": parameter_id,
			"label": str(parameter.get("label", parameter_id.capitalize())),
			"value": selected,
			"value_label": selected.replace("_", " ").capitalize(),
			"description": str(descriptions.get(selected, "")),
			"options": (
				(parameter.get("options", []) as Array).duplicate()
				if parameter.get("options", []) is Array
				else []
			),
		})
	return rows


static func get_ground_spell_definition_for_ability(
	ability: AbilityDefinition
) -> Dictionary:
	if not is_plant_summon_ability(ability):
		return {}
	var plant_id: String = DEFAULT_DISCOVERED_PLANTS[0] if not DEFAULT_DISCOVERED_PLANTS.is_empty() else ""
	return get_ground_spell_definition(plant_id, ability.get_spell_id(), {})


static func get_ground_spell_definition_for_prepared(
	ability: AbilityDefinition,
	plant_id: String,
	prepared_parameters: Dictionary
) -> Dictionary:
	if not is_plant_summon_ability(ability):
		return {}
	return get_ground_spell_definition(
		plant_id,
		ability.get_spell_id(),
		prepared_parameters
	)


static func get_ground_spell_definition_for_key(spell_key: String) -> Dictionary:
	var prefix: String = "plant_summon:"
	if not spell_key.begins_with(prefix):
		return {}
	var plant_id: String = spell_key.trim_prefix(prefix)
	return get_ground_spell_definition(plant_id, "", {})


static func is_plant_ground_spell_key(spell_key: String) -> bool:
	return spell_key.begins_with("plant_summon:") and get_definition(
		spell_key.trim_prefix("plant_summon:")
	) != null


static func get_ground_spell_definition(
	plant_id: String,
	spell_id: String = "",
	prepared_parameters: Dictionary = {}
) -> Dictionary:
	var definition: PlantSummonDefinition = get_definition(plant_id)
	if definition == null:
		return {}
	var preparation: Dictionary = sanitize_preparation(
		plant_id,
		prepared_parameters
	)
	var size_multiplier: float = get_size_multiplier(preparation)
	var marker_radius: float = maxf(
		definition.canopy_radius * size_multiplier,
		0.7
	)
	return {
		"spell_key": "plant_summon:" + plant_id,
		"spell_ids": [spell_id] if spell_id != "" else [],
		"display_names": ["plant summon", definition.display_name.to_lower()],
		"element": "life",
		"effect_type": "spawn_field",
		"post_spawn_method": "activate_from_ground_target",
		"plant_id": plant_id,
		"prepared_parameters": preparation.duplicate(true),
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
				+ " • PREPARED "
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


static func get_size_multiplier(preparation: Dictionary) -> float:
	match str(preparation.get("size", "standard")):
		"compact":
			return 0.78
		"large":
			return 1.24
		_:
			return 1.0


static func get_persistence_multiplier(preparation: Dictionary) -> float:
	match str(preparation.get("persistence", "standard")):
		"brief":
			return 0.68
		"persistent":
			return 1.55
		_:
			return 1.0


static func get_emergence_multiplier(preparation: Dictionary) -> float:
	match str(preparation.get("emergence", "balanced")):
		"gentle":
			return 0.62
		"forceful":
			return 1.42
		_:
			return 1.0


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
			"preparation_schema": get_preparation_schema(plant_id),
		})
	return rows
