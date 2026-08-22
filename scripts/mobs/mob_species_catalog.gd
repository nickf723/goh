extends RefCounted
class_name MobSpeciesCatalog

const DEFINITIONS: Dictionary = {
	"wolf": {
		"id": "wolf",
		"display_name": "Wolf",
		"category": "animal",
		"taxonomy_tags": ["animal", "mammal", "canid", "predator"],
		"body_tags": ["quadruped", "mouth", "jaw", "head", "legs", "voice"],
		"locomotion_tags": ["ground", "runner", "jumper"],
		"ecology_tags": ["pack", "territorial", "hunter", "forest", "tundra"],
		"base_stats": {"health": 18, "speed": 6.8, "mass": 42.0, "sight": 18.0, "hearing": 22.0},
		"default_personality": {
			"aggression": 0.72,
			"courage": 0.72,
			"curiosity": 0.38,
			"sociability": 0.78,
			"territoriality": 0.68,
			"protectiveness": 0.62,
			"patience": 0.48,
		},
		"move_policies": [
			{
				"move_id": "bite",
				"base_weight": 1.45,
				"any_context_tags": ["hunting", "threatened", "protecting_pack", "hostile"],
				"personality_weights": {"aggression": 0.9, "courage": 0.35},
				"context_score_modifiers": {"target_vulnerable": 0.75, "cornered": 0.3},
				"policy_tags": ["standard_attack"],
			},
			{
				"move_id": "pounce",
				"base_weight": 1.2,
				"minimum_target_distance": 2.2,
				"maximum_target_distance": 7.0,
				"any_context_tags": ["hunting", "threatened", "protecting_pack", "hostile"],
				"personality_weights": {"aggression": 0.7, "courage": 0.55, "patience": -0.2},
				"context_score_modifiers": {"target_fleeing": 1.0, "opening": 0.5},
				"policy_tags": ["gap_closer"],
			},
			{
				"move_id": "howl",
				"base_weight": 0.75,
				"minimum_allies": 1,
				"any_context_tags": ["hunting", "threatened", "protecting_pack"],
				"personality_weights": {"sociability": 0.9, "protectiveness": 0.7},
				"context_score_modifiers": {"pack_scattered": 1.25, "ally_injured": 0.6},
				"policy_tags": ["pack_support"],
			},
			{
				"move_id": "flee",
				"base_weight": 0.35,
				"maximum_health_ratio": 0.35,
				"any_context_tags": ["injured", "overwhelmed", "pack_broken"],
				"personality_weights": {"courage": -1.25, "protectiveness": -0.4},
				"context_score_modifiers": {"alone": 0.7, "outnumbered": 0.8},
				"policy_tags": ["survival"],
			},
			{"move_id": "idle", "base_weight": 0.35, "required_context_tags": ["safe"]},
		],
		"familiar_eligible": true,
		"familiar_profile": {
			"level_thresholds": [0, 10, 25, 50, 90],
			"starting_moves": ["bite"],
			"default_equipped_moves": ["bite"],
			"move_unlock_levels": {"howl": 2, "pounce": 3, "flee": 4},
			"max_equipped_moves": 4,
		},
	},
	"sheep": {
		"id": "sheep",
		"display_name": "Sheep",
		"category": "animal",
		"taxonomy_tags": ["animal", "mammal", "bovid", "prey"],
		"body_tags": ["quadruped", "mouth", "jaw", "head", "legs", "voice", "hoofed"],
		"locomotion_tags": ["ground", "runner"],
		"ecology_tags": ["herd", "grazer", "grassland", "domestic"],
		"base_stats": {"health": 14, "speed": 5.4, "mass": 68.0, "sight": 14.0, "hearing": 16.0},
		"default_personality": {
			"aggression": 0.12,
			"courage": 0.28,
			"curiosity": 0.42,
			"sociability": 0.88,
			"territoriality": 0.18,
			"protectiveness": 0.58,
			"patience": 0.72,
		},
		"move_policies": [
			{
				"move_id": "graze",
				"base_weight": 1.55,
				"any_context_tags": ["safe", "hungry"],
				"forbidden_context_tags": ["threatened", "cornered"],
				"personality_weights": {"patience": 0.6},
				"context_score_modifiers": {"lush_forage": 0.8},
			},
			{
				"move_id": "flee",
				"base_weight": 1.8,
				"any_context_tags": ["threatened", "predator_near", "attacked"],
				"personality_weights": {"courage": -1.3, "sociability": 0.25},
				"context_score_modifiers": {"herd_fleeing": 0.9, "outnumbered": 0.7},
				"policy_tags": ["default_defense"],
			},
			{
				"move_id": "headbutt",
				"base_weight": 0.95,
				"any_context_tags": ["cornered", "protecting_young"],
				"personality_weights": {"aggression": 1.0, "courage": 0.75, "protectiveness": 1.0},
				"context_score_modifiers": {"target_close": 0.6},
				"policy_tags": ["conditional_defense"],
			},
			{
				"move_id": "bite",
				"base_weight": 0.35,
				"any_context_tags": ["cornered", "protecting_young"],
				"personality_weights": {"aggression": 1.45, "courage": 0.8, "protectiveness": 0.65},
				"context_score_modifiers": {"headbutt_unavailable": 0.8},
				"policy_tags": ["desperation_attack"],
			},
			{"move_id": "idle", "base_weight": 0.75, "required_context_tags": ["safe"]},
		],
		"familiar_eligible": true,
		"familiar_profile": {
			"level_thresholds": [0, 8, 22, 45, 80],
			"starting_moves": ["flee", "graze"],
			"default_equipped_moves": ["flee", "graze"],
			"move_unlock_levels": {"headbutt": 2, "bite": 4},
			"max_equipped_moves": 4,
		},
	},
	"capybara": {
		"id": "capybara",
		"display_name": "Capybara",
		"category": "animal",
		"taxonomy_tags": ["animal", "mammal", "rodent", "prey"],
		"body_tags": ["quadruped", "mouth", "jaw", "head", "legs", "voice", "swimmer"],
		"locomotion_tags": ["ground", "swimmer"],
		"ecology_tags": ["herd", "grazer", "wetland", "riverbank", "social"],
		"base_stats": {"health": 20, "speed": 4.8, "mass": 52.0, "sight": 12.0, "hearing": 14.0},
		"default_personality": {
			"aggression": 0.08,
			"courage": 0.44,
			"curiosity": 0.62,
			"sociability": 0.92,
			"territoriality": 0.08,
			"protectiveness": 0.48,
			"patience": 0.86,
		},
		"move_policies": [
			{
				"move_id": "graze",
				"base_weight": 1.35,
				"any_context_tags": ["safe", "hungry"],
				"forbidden_context_tags": ["threatened", "cornered"],
				"personality_weights": {"patience": 0.55, "curiosity": 0.2},
			},
			{
				"move_id": "wade",
				"base_weight": 1.25,
				"any_context_tags": ["water_near", "hot", "threatened"],
				"personality_weights": {"curiosity": 0.35, "patience": 0.2},
				"context_score_modifiers": {"hot": 0.9, "predator_near": 0.45},
			},
			{
				"move_id": "flee",
				"base_weight": 1.1,
				"any_context_tags": ["threatened", "predator_near", "attacked"],
				"personality_weights": {"courage": -0.8, "sociability": 0.2},
				"context_score_modifiers": {"water_near": 0.5},
			},
			{
				"move_id": "bite",
				"base_weight": 0.3,
				"any_context_tags": ["cornered", "protecting_young"],
				"personality_weights": {"aggression": 1.5, "courage": 0.65, "protectiveness": 0.8},
				"policy_tags": ["desperation_attack"],
			},
			{"move_id": "idle", "base_weight": 1.0, "required_context_tags": ["safe"]},
		],
		"familiar_eligible": true,
		"familiar_profile": {
			"level_thresholds": [0, 8, 20, 42, 75],
			"starting_moves": ["graze", "wade"],
			"default_equipped_moves": ["graze", "wade"],
			"move_unlock_levels": {"flee": 2, "bite": 4},
			"max_equipped_moves": 4,
		},
	},
	"gorgon": {
		"id": "gorgon",
		"display_name": "Gorgon",
		"category": "monster",
		"taxonomy_tags": ["monster", "mythic", "serpentine", "humanoid"],
		"body_tags": ["biped", "mouth", "jaw", "head", "legs", "voice", "gaze", "tail"],
		"locomotion_tags": ["ground", "serpentine"],
		"ecology_tags": ["solitary", "territorial", "ruins", "ambush_predator"],
		"base_stats": {"health": 42, "speed": 5.2, "mass": 96.0, "sight": 24.0, "hearing": 16.0},
		"default_personality": {
			"aggression": 0.66,
			"courage": 0.82,
			"curiosity": 0.32,
			"sociability": 0.18,
			"territoriality": 0.92,
			"protectiveness": 0.28,
			"patience": 0.78,
		},
		"move_policies": [
			{
				"move_id": "stone_gaze",
				"base_weight": 1.85,
				"required_context_tags": ["line_of_sight"],
				"forbidden_target_tags": ["gaze_immune", "stone", "blind"],
				"minimum_target_distance": 3.0,
				"maximum_target_distance": 12.0,
				"personality_weights": {"patience": 0.85, "territoriality": 0.45, "aggression": 0.3},
				"context_score_modifiers": {"target_stationary": 0.9, "target_recovering": 0.65},
				"policy_tags": ["signature_move"],
			},
			{
				"move_id": "tail_sweep",
				"base_weight": 1.3,
				"any_context_tags": ["crowded", "target_close", "surrounded"],
				"maximum_target_distance": 3.2,
				"personality_weights": {"aggression": 0.55, "courage": 0.3},
				"context_score_modifiers": {"multiple_targets": 1.2},
			},
			{
				"move_id": "bite",
				"base_weight": 1.0,
				"any_context_tags": ["hostile", "target_close", "cornered"],
				"personality_weights": {"aggression": 0.7},
			},
			{
				"move_id": "backstep",
				"base_weight": 0.55,
				"any_context_tags": ["crowded", "threatened", "gaze_interrupted"],
				"personality_weights": {"patience": 0.45, "courage": -0.25},
			},
			{"move_id": "idle", "base_weight": 0.2, "required_context_tags": ["safe"]},
		],
		"familiar_eligible": false,
		"familiar_profile": {},
	},
	"gremlin": {
		"id": "gremlin",
		"display_name": "Gremlin",
		"category": "monster",
		"taxonomy_tags": ["monster", "scavenger", "social"],
		"body_tags": ["biped", "mouth", "jaw", "head", "legs", "voice"],
		"locomotion_tags": ["ground", "runner", "jumper"],
		"ecology_tags": ["pack", "scavenger", "ruins", "sewer"],
		"base_stats": {"health": 12, "speed": 6.2, "mass": 24.0, "sight": 14.0, "hearing": 18.0},
		"default_personality": {
			"aggression": 0.52,
			"courage": 0.46,
			"curiosity": 0.76,
			"sociability": 0.74,
			"territoriality": 0.42,
			"protectiveness": 0.36,
			"patience": 0.28,
		},
		"move_policies": [
			{
				"move_id": "bite",
				"base_weight": 1.25,
				"any_context_tags": ["hostile", "threatened", "hunting"],
				"personality_weights": {"aggression": 0.75, "courage": 0.25},
			},
			{
				"move_id": "pounce",
				"base_weight": 1.15,
				"minimum_target_distance": 2.0,
				"maximum_target_distance": 7.0,
				"any_context_tags": ["hostile", "hunting", "opening"],
				"personality_weights": {"aggression": 0.55, "curiosity": 0.35, "patience": -0.3},
			},
			{
				"move_id": "backstep",
				"base_weight": 0.9,
				"any_context_tags": ["crowded", "threatened", "post_attack"],
				"personality_weights": {"courage": -0.55, "curiosity": 0.2},
			},
			{
				"move_id": "mire_spit",
				"base_weight": 1.0,
				"minimum_target_distance": 3.0,
				"maximum_target_distance": 10.0,
				"any_context_tags": ["ranged_opening", "primer_command", "target_dry"],
				"personality_weights": {"curiosity": 0.45, "patience": 0.2},
				"context_score_modifiers": {"ally_lightning_ready": 1.0},
			},
			{"move_id": "idle", "base_weight": 0.25, "required_context_tags": ["safe"]},
		],
		"familiar_eligible": true,
		"familiar_profile": {
			"level_thresholds": [0, 8, 20, 40, 72],
			"starting_moves": ["bite", "backstep"],
			"default_equipped_moves": ["bite", "backstep"],
			"move_unlock_levels": {"pounce": 2, "mire_spit": 3},
			"max_equipped_moves": 4,
		},
	},
}


static func has_species(species_id: String) -> bool:
	return DEFINITIONS.has(species_id)


static func get_definition(species_id: String) -> MobSpeciesDefinition:
	var value: Variant = DEFINITIONS.get(species_id)
	if not value is Dictionary:
		return null
	return MobSpeciesDefinition.from_dictionary(value as Dictionary)


static func get_species_ids() -> Array[String]:
	var ids: Array[String] = []
	for raw: Variant in DEFINITIONS.keys():
		ids.append(str(raw))
	ids.sort()
	return ids


static func get_definitions() -> Array[MobSpeciesDefinition]:
	var rows: Array[MobSpeciesDefinition] = []
	for species_id: String in get_species_ids():
		var definition: MobSpeciesDefinition = get_definition(species_id)
		if definition != null:
			rows.append(definition)
	return rows


static func get_move_policy(species_id: String, move_id: String) -> MobMovePolicy:
	var definition: MobSpeciesDefinition = get_definition(species_id)
	return definition.get_move_policy(move_id) if definition != null else null


static func get_move_ids(species_id: String) -> Array[String]:
	var definition: MobSpeciesDefinition = get_definition(species_id)
	return definition.get_move_ids() if definition != null else []


static func validate_catalog() -> Array[String]:
	var failures: Array[String] = MobMoveCatalog.validate_catalog()
	failures.append_array(MobLocomotionCatalog.validate_catalog())
	for definition: MobSpeciesDefinition in get_definitions():
		for failure: String in definition.validate(MobMoveCatalog):
			failures.append(failure)
	return failures


static func get_debug_data() -> Dictionary:
	var rows: Array[Dictionary] = []
	for definition: MobSpeciesDefinition in get_definitions():
		rows.append(definition.to_dictionary())
	return {
		"species_count": rows.size(),
		"species": rows,
		"locomotion_capability_count": MobLocomotionCatalog.get_capability_ids().size(),
		"failures": validate_catalog(),
	}
