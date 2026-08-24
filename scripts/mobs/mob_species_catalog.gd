extends RefCounted
class_name MobSpeciesCatalog

const BodyPlanCatalog = preload(
	"res://scripts/mobs/mob_body_plan_catalog.gd"
)

const ADDITIVE_VARIANT_ARRAY_KEYS: Array[String] = [
	"taxonomy_tags",
	"body_tags",
	"locomotion_tags",
	"ecology_tags",
]

const DEFINITIONS: Dictionary = {
	"wolf": {
		"id": "wolf",
		"display_name": "Wolf",
		"category": "animal",
		"taxonomy_tags": ["animal", "mammal", "canid", "predator"],
		"body_tags": ["quadruped", "mouth", "jaw", "head", "legs", "voice"],
		"locomotion_tags": ["ground", "runner", "jumper"],
		"ecology_tags": ["pack", "territorial", "hunter", "forest", "tundra"],
		"ecology_profile": {
			"scale_band": "large",
			"breathing_media": ["air"],
			"diet_tags": ["carnivore", "hunter"],
			"activity_cycle_tags": ["crepuscular", "nocturnal"],
			"social_structure": "pack",
			"aggregation_mode": "group",
			"any_habitat_tags": ["forest", "tundra"],
			"preferred_habitat_tags": ["forest"],
			"minimum_temperature": -40.0,
			"maximum_temperature": 38.0,
			"home_range": 30.0,
		},
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
		"ecology_profile": {
			"scale_band": "large",
			"breathing_media": ["air"],
			"diet_tags": ["herbivore", "grazer"],
			"activity_cycle_tags": ["diurnal"],
			"social_structure": "herd",
			"aggregation_mode": "group",
			"any_habitat_tags": ["grassland", "domestic"],
			"preferred_habitat_tags": ["grassland"],
			"minimum_temperature": -20.0,
			"maximum_temperature": 38.0,
			"home_range": 12.0,
		},
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
		"ecology_profile": {
			"scale_band": "large",
			"breathing_media": ["air"],
			"diet_tags": ["herbivore", "grazer"],
			"activity_cycle_tags": ["crepuscular", "diurnal"],
			"social_structure": "herd",
			"aggregation_mode": "group",
			"any_habitat_tags": ["wetland", "riverbank"],
			"preferred_habitat_tags": ["wetland", "water"],
			"minimum_temperature": 5.0,
			"maximum_temperature": 42.0,
			"home_range": 14.0,
		},
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
	"bear": {
		"id": "bear",
		"display_name": "Bear",
		"category": "animal",
		"body_plan_id": "quadruped",
		"taxonomy_tags": ["animal", "mammal", "ursid", "predator"],
		"body_tags": ["mammal", "jaw", "claws", "voice"],
		"anatomy_counts": {"jaw": 1, "claws": 4, "voice": 1},
		"locomotion_tags": ["ground", "runner"],
		"ecology_tags": ["solitary", "territorial", "omnivore", "forager"],
		"ecology_profile": {
			"scale_band": "huge",
			"breathing_media": ["air"],
			"diet_tags": ["omnivore", "forager"],
			"activity_cycle_tags": ["variable"],
			"social_structure": "solitary",
			"aggregation_mode": "individual",
			"any_habitat_tags": ["forest", "tundra", "mountain"],
			"preferred_habitat_tags": ["forest"],
			"minimum_temperature": -35.0,
			"maximum_temperature": 38.0,
			"home_range": 28.0,
		},
		"base_stats": {
			"health": 34,
			"speed": 5.8,
			"mass": 280.0,
			"sight": 15.0,
			"hearing": 18.0,
		},
		"default_personality": {
			"aggression": 0.5,
			"courage": 0.82,
			"curiosity": 0.48,
			"sociability": 0.22,
			"territoriality": 0.72,
			"protectiveness": 0.64,
			"patience": 0.58,
		},
		"move_policies": [
			{
				"move_id": "bite",
				"base_weight": 1.2,
				"maximum_target_distance": 1.8,
				"any_context_tags": [
					"hostile",
					"threatened",
					"hunting",
					"protecting_young",
				],
				"personality_weights": {
					"aggression": 0.7,
					"courage": 0.35,
					"protectiveness": 0.45,
				},
				"policy_tags": ["standard_attack"],
			},
			{
				"move_id": "graze",
				"base_weight": 0.75,
				"any_context_tags": ["safe", "hungry"],
				"forbidden_context_tags": ["threatened", "cornered"],
				"personality_weights": {
					"curiosity": 0.2,
					"patience": 0.35,
				},
				"policy_tags": ["forage"],
			},
			{
				"move_id": "flee",
				"base_weight": 0.35,
				"maximum_health_ratio": 0.25,
				"any_context_tags": ["injured", "overwhelmed"],
				"personality_weights": {
					"courage": -1.0,
				},
				"policy_tags": ["survival"],
			},
			{
				"move_id": "idle",
				"base_weight": 0.5,
				"required_context_tags": ["safe"],
			},
		],
		"familiar_eligible": true,
		"familiar_profile": {
			"level_thresholds": [0, 12, 30, 60, 105],
			"starting_moves": ["graze", "flee"],
			"default_equipped_moves": ["graze", "flee"],
			"move_unlock_levels": {"bite": 2, "idle": 1},
			"max_equipped_moves": 4,
		},
	},
	"brown_bear": {
		"id": "brown_bear",
		"display_name": "Brown Bear",
		"parent_species_id": "bear",
		"taxonomy_tags": ["brown_bear"],
		"ecology_tags": ["mountain", "river", "salmon_hunter"],
		"ecology_profile": {
			"any_habitat_tags": ["mountain", "river", "forest"],
			"preferred_habitat_tags": ["mountain", "river"],
			"minimum_temperature": -25.0,
			"maximum_temperature": 35.0,
			"home_range": 32.0,
		},
		"base_stats": {"health": 40, "speed": 5.6, "mass": 360.0},
		"default_personality": {
			"aggression": 0.56,
			"territoriality": 0.76,
		},
	},
	"black_bear": {
		"id": "black_bear",
		"display_name": "Black Bear",
		"parent_species_id": "bear",
		"taxonomy_tags": ["black_bear"],
		"ecology_tags": ["woodland", "climber"],
		"ecology_profile": {
			"scale_band": "large",
			"any_habitat_tags": ["forest", "woodland"],
			"preferred_habitat_tags": ["woodland"],
			"minimum_temperature": -20.0,
			"maximum_temperature": 38.0,
			"home_range": 24.0,
		},
		"base_stats": {"health": 30, "speed": 6.2, "mass": 145.0},
		"default_personality": {
			"aggression": 0.36,
			"curiosity": 0.62,
			"courage": 0.64,
		},
	},
	"polar_bear": {
		"id": "polar_bear",
		"display_name": "Polar Bear",
		"parent_species_id": "bear",
		"taxonomy_tags": ["polar_bear"],
		"body_tags": ["swimmer"],
		"locomotion_tags": ["swimmer"],
		"ecology_tags": ["arctic", "sea_ice", "marine_hunter"],
		"ecology_profile": {
			"diet_tags": ["carnivore", "marine_hunter"],
			"any_habitat_tags": ["arctic", "sea_ice", "coast"],
			"preferred_habitat_tags": ["sea_ice"],
			"minimum_temperature": -55.0,
			"maximum_temperature": 10.0,
			"home_range": 40.0,
		},
		"base_stats": {"health": 46, "speed": 5.5, "mass": 450.0},
		"default_personality": {
			"aggression": 0.68,
			"courage": 0.9,
			"territoriality": 0.58,
		},
	},
	"panda": {
		"id": "panda",
		"display_name": "Panda",
		"parent_species_id": "bear",
		"taxonomy_tags": ["panda", "herbivore"],
		"ecology_tags": ["bamboo_forest", "browser"],
		"ecology_profile": {
			"scale_band": "large",
			"diet_tags": ["herbivore", "browser"],
			"activity_cycle_tags": ["crepuscular"],
			"any_habitat_tags": ["bamboo_forest", "forest"],
			"preferred_habitat_tags": ["bamboo_forest"],
			"minimum_temperature": -5.0,
			"maximum_temperature": 30.0,
			"home_range": 14.0,
		},
		"base_stats": {"health": 32, "speed": 4.8, "mass": 110.0},
		"default_personality": {
			"aggression": 0.18,
			"curiosity": 0.58,
			"courage": 0.46,
			"patience": 0.78,
		},
	},
	"goose": {
		"id": "goose",
		"display_name": "Goose",
		"category": "animal",
		"taxonomy_tags": [
			"animal",
			"bird",
			"waterfowl",
			"prey",
		],
		"body_tags": [
			"bird",
			"mouth",
			"beak",
			"head",
			"legs",
			"wings",
			"voice",
			"swimmer",
			"tail",
		],
		"locomotion_tags": [
			"ground",
			"swimmer",
			"flight",
			"hover",
		],
		"ecology_tags": [
			"flock",
			"grazer",
			"wetland",
			"riverbank",
			"waterfowl",
			"social",
		],
		"ecology_profile": {
			"scale_band": "medium",
			"breathing_media": ["air"],
			"diet_tags": ["herbivore", "grazer", "omnivore"],
			"activity_cycle_tags": ["diurnal", "migratory"],
			"social_structure": "flock",
			"aggregation_mode": "group",
			"any_habitat_tags": ["wetland", "riverbank", "water"],
			"preferred_habitat_tags": ["wetland", "water"],
			"minimum_temperature": -25.0,
			"maximum_temperature": 40.0,
			"home_range": 24.0,
		},
		"base_stats": {
			"health": 12,
			"speed": 6.0,
			"mass": 5.0,
			"sight": 18.0,
			"hearing": 16.0,
		},
		"default_personality": {
			"aggression": 0.34,
			"courage": 0.58,
			"curiosity": 0.56,
			"sociability": 0.82,
			"territoriality": 0.46,
			"protectiveness": 0.64,
			"patience": 0.48,
		},
		"move_policies": [
			{
				"move_id": "wade",
				"base_weight": 1.35,
				"any_context_tags": [
					"water_near",
					"hot",
				],
				"forbidden_context_tags": [
					"cornered",
					"predator_near",
				],
				"personality_weights": {
					"curiosity": 0.35,
					"patience": 0.25,
				},
				"context_score_modifiers": {
					"water_near": 0.8,
				},
				"policy_tags": ["habitat"],
			},
			{
				"move_id": "graze",
				"base_weight": 0.9,
				"any_context_tags": [
					"safe",
					"hungry",
				],
				"forbidden_context_tags": [
					"threatened",
					"cornered",
				],
				"personality_weights": {
					"patience": 0.35,
				},
			},
			{
				"move_id": "flee",
				"base_weight": 1.45,
				"any_context_tags": [
					"threatened",
					"predator_near",
					"attacked",
				],
				"personality_weights": {
					"courage": -0.75,
					"protectiveness": 0.25,
				},
				"policy_tags": ["aerial_escape"],
			},
			{
				"move_id": "peck",
				"base_weight": 0.8,
				"maximum_target_distance": 1.6,
				"any_context_tags": [
					"cornered",
					"target_close",
					"protecting_young",
					"hostile",
				],
				"personality_weights": {
					"aggression": 0.8,
					"courage": 0.45,
					"protectiveness": 0.7,
				},
				"policy_tags": ["conditional_defense"],
			},
			{
				"move_id": "idle",
				"base_weight": 0.45,
				"required_context_tags": ["safe"],
			},
		],
		"familiar_eligible": true,
		"familiar_profile": {
			"level_thresholds": [0, 8, 20, 40, 72],
			"starting_moves": ["wade", "flee"],
			"default_equipped_moves": ["wade", "flee"],
			"move_unlock_levels": {
				"peck": 2,
				"graze": 3,
				"idle": 1,
			},
			"max_equipped_moves": 4,
		},
	},
	"trout": {
		"id": "trout",
		"display_name": "Trout",
		"category": "animal",
		"taxonomy_tags": [
			"animal",
			"fish",
			"aquatic",
			"prey",
		],
		"body_tags": [
			"fish",
			"mouth",
			"jaw",
			"head",
			"fins",
			"gills",
			"tail",
			"swimmer",
		],
		"locomotion_tags": ["swimmer"],
		"ecology_tags": [
			"school",
			"aquatic",
			"river",
			"freshwater",
		],
		"ecology_profile": {
			"scale_band": "small",
			"breathing_media": ["water"],
			"diet_tags": ["insectivore", "omnivore"],
			"activity_cycle_tags": ["variable"],
			"social_structure": "school",
			"aggregation_mode": "group",
			"required_habitat_tags": ["freshwater"],
			"any_habitat_tags": ["river", "stream", "lake"],
			"preferred_habitat_tags": ["river", "cold_water"],
			"minimum_temperature": -1.0,
			"maximum_temperature": 24.0,
			"home_range": 18.0,
		},
		"base_stats": {
			"health": 8,
			"speed": 5.8,
			"mass": 2.0,
			"sight": 11.0,
			"hearing": 8.0,
		},
		"default_personality": {
			"aggression": 0.08,
			"courage": 0.2,
			"curiosity": 0.3,
			"sociability": 0.78,
			"territoriality": 0.08,
			"protectiveness": 0.18,
			"patience": 0.62,
		},
		"move_policies": [
			{
				"move_id": "flee",
				"base_weight": 1.8,
				"any_context_tags": [
					"threatened",
					"predator_near",
					"attacked",
				],
				"personality_weights": {
					"courage": -1.2,
					"sociability": 0.2,
				},
				"policy_tags": ["default_defense"],
			},
			{
				"move_id": "bite",
				"base_weight": 0.25,
				"maximum_target_distance": 1.5,
				"any_context_tags": [
					"cornered",
					"target_close",
				],
				"personality_weights": {
					"aggression": 0.9,
					"courage": 0.4,
				},
				"policy_tags": ["desperation_attack"],
			},
			{
				"move_id": "idle",
				"base_weight": 1.0,
				"required_context_tags": ["safe"],
				"policy_tags": ["aquatic_patrol"],
			},
		],
		"familiar_eligible": false,
		"familiar_profile": {},
	},
	"gecko": {
		"id": "gecko",
		"display_name": "Gecko",
		"category": "animal",
		"taxonomy_tags": [
			"animal",
			"reptile",
			"lizard",
			"prey",
		],
		"body_tags": [
			"reptile",
			"mouth",
			"jaw",
			"head",
			"legs",
			"claws",
			"adhesive_pads",
			"tail",
		],
		"locomotion_tags": [
			"ground",
			"climber",
		],
		"ecology_tags": [
			"solitary",
			"insectivore",
			"rock_face",
			"cliff",
		],
		"ecology_profile": {
			"scale_band": "tiny",
			"breathing_media": ["air"],
			"diet_tags": ["insectivore"],
			"activity_cycle_tags": ["nocturnal"],
			"social_structure": "solitary",
			"aggregation_mode": "individual",
			"any_habitat_tags": ["rock_face", "cliff", "woodland"],
			"preferred_habitat_tags": ["vertical_surface"],
			"minimum_temperature": 8.0,
			"maximum_temperature": 42.0,
			"home_range": 5.0,
		},
		"base_stats": {
			"health": 7,
			"speed": 6.4,
			"mass": 0.2,
			"sight": 13.0,
			"hearing": 9.0,
		},
		"default_personality": {
			"aggression": 0.12,
			"courage": 0.28,
			"curiosity": 0.66,
			"sociability": 0.18,
			"territoriality": 0.22,
			"protectiveness": 0.12,
			"patience": 0.58,
		},
		"move_policies": [
			{
				"move_id": "climb",
				"base_weight": 1.65,
				"required_context_tags": ["safe"],
				"required_self_tags": ["locomotion_mode:climber"],
				"personality_weights": {
					"curiosity": 0.45,
					"patience": 0.2,
				},
				"policy_tags": ["habitat", "surface_patrol"],
			},
			{
				"move_id": "flee",
				"base_weight": 1.7,
				"any_context_tags": [
					"threatened",
					"predator_near",
					"attacked",
				],
				"personality_weights": {
					"courage": -1.0,
					"curiosity": -0.2,
				},
				"policy_tags": ["default_defense"],
			},
			{
				"move_id": "bite",
				"base_weight": 0.18,
				"maximum_target_distance": 1.1,
				"any_context_tags": ["cornered", "target_close"],
				"personality_weights": {
					"aggression": 0.8,
					"courage": 0.35,
				},
				"policy_tags": ["desperation_attack"],
			},
			{
				"move_id": "idle",
				"base_weight": 0.55,
				"required_context_tags": ["safe"],
			},
		],
		"familiar_eligible": false,
		"familiar_profile": {},
	},
	"mole": {
		"id": "mole",
		"display_name": "Mole",
		"category": "animal",
		"taxonomy_tags": [
			"animal",
			"mammal",
			"burrower",
			"prey",
		],
		"body_tags": [
			"mammal",
			"mouth",
			"jaw",
			"head",
			"legs",
			"claws",
			"digging_limbs",
			"tail",
		],
		"locomotion_tags": [
			"ground",
			"burrower",
		],
		"ecology_tags": [
			"solitary",
			"insectivore",
			"soil",
			"tunnel",
		],
		"ecology_profile": {
			"scale_band": "tiny",
			"breathing_media": ["air"],
			"diet_tags": ["insectivore"],
			"activity_cycle_tags": ["variable"],
			"social_structure": "solitary",
			"aggregation_mode": "individual",
			"any_habitat_tags": ["soil", "tunnel"],
			"preferred_habitat_tags": ["soil", "root_tunnel"],
			"minimum_temperature": -8.0,
			"maximum_temperature": 34.0,
			"home_range": 7.0,
		},
		"base_stats": {
			"health": 9,
			"speed": 4.8,
			"mass": 0.12,
			"sight": 4.0,
			"hearing": 18.0,
		},
		"default_personality": {
			"aggression": 0.08,
			"courage": 0.24,
			"curiosity": 0.42,
			"sociability": 0.12,
			"territoriality": 0.38,
			"protectiveness": 0.1,
			"patience": 0.7,
		},
		"move_policies": [
			{
				"move_id": "burrow",
				"base_weight": 1.7,
				"required_context_tags": ["safe"],
				"required_self_tags": ["locomotion_mode:burrower"],
				"personality_weights": {
					"patience": 0.45,
					"curiosity": 0.2,
				},
				"policy_tags": ["habitat", "tunnel_patrol"],
			},
			{
				"move_id": "flee",
				"base_weight": 1.75,
				"any_context_tags": [
					"threatened",
					"predator_near",
					"attacked",
				],
				"personality_weights": {
					"courage": -1.1,
					"patience": -0.2,
				},
				"policy_tags": ["default_defense"],
			},
			{
				"move_id": "bite",
				"base_weight": 0.15,
				"maximum_target_distance": 1.0,
				"any_context_tags": ["cornered", "target_close"],
				"personality_weights": {
					"aggression": 0.8,
					"courage": 0.35,
				},
				"policy_tags": ["desperation_attack"],
			},
			{
				"move_id": "idle",
				"base_weight": 0.5,
				"required_context_tags": ["safe"],
			},
		],
		"familiar_eligible": false,
		"familiar_profile": {},
	},
	"bullfrog": {
		"id": "bullfrog",
		"display_name": "Bullfrog",
		"category": "animal",
		"body_plan_id": "amphibian",
		"taxonomy_tags": ["animal", "amphibian", "frog", "predator", "prey"],
		"body_tags": ["jaw", "tongue", "voice"],
		"anatomy_counts": {"jaw": 1, "tongue": 1, "voice": 1},
		"ecology_tags": ["solitary", "insectivore", "wetland", "freshwater"],
		"ecology_profile": {
			"scale_band": "small",
			"breathing_media": ["air", "water"],
			"diet_tags": ["insectivore", "carnivore"],
			"activity_cycle_tags": ["nocturnal", "crepuscular"],
			"social_structure": "solitary",
			"aggregation_mode": "individual",
			"any_habitat_tags": ["wetland", "freshwater", "riverbank"],
			"preferred_habitat_tags": ["wetland", "water"],
			"minimum_temperature": 2.0,
			"maximum_temperature": 38.0,
			"home_range": 8.0,
		},
		"base_stats": {"health": 9, "speed": 5.6, "mass": 0.6, "sight": 12.0, "hearing": 11.0},
		"default_personality": {
			"aggression": 0.24,
			"courage": 0.34,
			"curiosity": 0.48,
			"sociability": 0.12,
			"territoriality": 0.42,
			"protectiveness": 0.08,
			"patience": 0.72,
		},
		"move_policies": [
			{
				"move_id": "pounce",
				"base_weight": 1.1,
				"minimum_target_distance": 1.8,
				"maximum_target_distance": 6.0,
				"any_context_tags": ["hunting", "threatened", "opening"],
				"personality_weights": {"patience": 0.5, "aggression": 0.3},
			},
			{
				"move_id": "bite",
				"base_weight": 0.45,
				"maximum_target_distance": 1.2,
				"any_context_tags": ["cornered", "target_close"],
			},
			{
				"move_id": "flee",
				"base_weight": 1.35,
				"any_context_tags": ["threatened", "predator_near", "attacked"],
				"personality_weights": {"courage": -0.9},
			},
			{"move_id": "idle", "base_weight": 0.7, "required_context_tags": ["safe"]},
		],
		"familiar_eligible": false,
		"familiar_profile": {},
	},
	"cobra": {
		"id": "cobra",
		"display_name": "Cobra",
		"category": "animal",
		"body_plan_id": "serpentine",
		"taxonomy_tags": ["animal", "reptile", "snake", "predator", "venomous"],
		"body_tags": ["fangs", "venom_glands", "voice"],
		"anatomy_counts": {"fangs": 2, "venom_glands": 2, "voice": 1},
		"ecology_tags": ["solitary", "ambush_predator", "grassland", "forest"],
		"ecology_profile": {
			"scale_band": "medium",
			"breathing_media": ["air"],
			"diet_tags": ["carnivore", "ambush_predator"],
			"activity_cycle_tags": ["diurnal", "crepuscular"],
			"social_structure": "solitary",
			"aggregation_mode": "individual",
			"any_habitat_tags": ["grassland", "forest", "scrubland"],
			"preferred_habitat_tags": ["warm"],
			"minimum_temperature": 10.0,
			"maximum_temperature": 44.0,
			"home_range": 14.0,
		},
		"base_stats": {"health": 11, "speed": 5.9, "mass": 4.5, "sight": 13.0, "hearing": 9.0},
		"default_personality": {
			"aggression": 0.58,
			"courage": 0.6,
			"curiosity": 0.24,
			"sociability": 0.06,
			"territoriality": 0.64,
			"protectiveness": 0.08,
			"patience": 0.84,
		},
		"move_policies": [
			{
				"move_id": "bite",
				"base_weight": 1.4,
				"maximum_target_distance": 1.7,
				"any_context_tags": ["hunting", "hostile", "cornered", "target_close"],
				"personality_weights": {"patience": 0.45, "aggression": 0.55},
			},
			{
				"move_id": "flee",
				"base_weight": 0.7,
				"any_context_tags": ["injured", "overwhelmed", "attacked"],
				"personality_weights": {"courage": -0.75},
			},
			{"move_id": "idle", "base_weight": 0.65, "required_context_tags": ["safe"]},
		],
		"familiar_eligible": false,
		"familiar_profile": {},
	},
	"octopus": {
		"id": "octopus",
		"display_name": "Octopus",
		"category": "animal",
		"body_plan_id": "cephalopod",
		"taxonomy_tags": ["animal", "mollusk", "cephalopod", "predator"],
		"body_tags": ["jaw", "beak", "camouflage_skin"],
		"anatomy_counts": {"jaw": 1, "beak": 1, "camouflage_skin": 1},
		"ecology_tags": ["solitary", "hunter", "ocean", "reef", "seafloor"],
		"ecology_profile": {
			"scale_band": "medium",
			"breathing_media": ["water"],
			"diet_tags": ["carnivore", "hunter"],
			"activity_cycle_tags": ["nocturnal"],
			"social_structure": "solitary",
			"aggregation_mode": "individual",
			"required_habitat_tags": ["ocean"],
			"any_habitat_tags": ["reef", "seafloor", "cavern"],
			"preferred_habitat_tags": ["reef", "cover"],
			"minimum_temperature": 2.0,
			"maximum_temperature": 32.0,
			"home_range": 12.0,
		},
		"base_stats": {"health": 16, "speed": 4.9, "mass": 12.0, "sight": 17.0, "hearing": 7.0},
		"default_personality": {
			"aggression": 0.32,
			"courage": 0.48,
			"curiosity": 0.92,
			"sociability": 0.08,
			"territoriality": 0.46,
			"protectiveness": 0.06,
			"patience": 0.78,
		},
		"move_policies": [
			{
				"move_id": "climb",
				"base_weight": 1.2,
				"required_context_tags": ["safe"],
				"required_self_tags": ["locomotion_mode:climber"],
				"personality_weights": {"curiosity": 0.55, "patience": 0.2},
			},
			{
				"move_id": "bite",
				"base_weight": 0.6,
				"maximum_target_distance": 1.3,
				"any_context_tags": ["cornered", "hunting", "target_close"],
			},
			{
				"move_id": "flee",
				"base_weight": 1.25,
				"any_context_tags": ["threatened", "attacked", "predator_near"],
			},
			{"move_id": "idle", "base_weight": 0.8, "required_context_tags": ["safe"]},
		],
		"familiar_eligible": false,
		"familiar_profile": {},
	},
	"butterfly": {
		"id": "butterfly",
		"display_name": "Butterfly",
		"category": "animal",
		"body_plan_id": "insectoid",
		"taxonomy_tags": ["animal", "insect", "pollinator", "prey"],
		"body_tags": ["wings", "proboscis"],
		"anatomy_counts": {"wings": 4, "proboscis": 1},
		"locomotion_tags": ["ground", "flight", "hover"],
		"ecology_tags": ["solitary", "pollinator", "garden", "meadow"],
		"ecology_profile": {
			"scale_band": "micro",
			"breathing_media": ["air"],
			"diet_tags": ["nectarivore"],
			"activity_cycle_tags": ["diurnal"],
			"social_structure": "solitary",
			"aggregation_mode": "individual",
			"any_habitat_tags": ["meadow", "garden", "forest"],
			"preferred_habitat_tags": ["flowers", "warm"],
			"minimum_temperature": 8.0,
			"maximum_temperature": 42.0,
			"home_range": 6.0,
		},
		"base_stats": {"health": 2, "speed": 5.2, "mass": 0.001, "sight": 10.0, "hearing": 3.0},
		"default_personality": {
			"aggression": 0.0,
			"courage": 0.08,
			"curiosity": 0.52,
			"sociability": 0.18,
			"territoriality": 0.02,
			"protectiveness": 0.0,
			"patience": 0.42,
		},
		"move_policies": [
			{
				"move_id": "flee",
				"base_weight": 1.8,
				"any_context_tags": ["threatened", "predator_near", "attacked"],
				"personality_weights": {"courage": -1.2},
				"policy_tags": ["aerial_escape"],
			},
			{"move_id": "idle", "base_weight": 1.0, "required_context_tags": ["safe"]},
		],
		"familiar_eligible": false,
		"familiar_profile": {},
	},
	"anemone": {
		"id": "anemone",
		"display_name": "Anemone",
		"category": "animal",
		"body_plan_id": "sessile",
		"taxonomy_tags": ["animal", "cnidarian", "aquatic", "sessile"],
		"body_tags": ["mouth", "tentacles", "stinging_cells"],
		"anatomy_counts": {"mouth": 1, "tentacles": 24, "stinging_cells": 1},
		"ecology_tags": ["solitary", "ocean", "reef", "substrate"],
		"ecology_profile": {
			"scale_band": "small",
			"breathing_media": ["water"],
			"diet_tags": ["carnivore", "filter_feeder"],
			"activity_cycle_tags": ["variable"],
			"social_structure": "solitary",
			"aggregation_mode": "individual",
			"required_habitat_tags": ["ocean", "substrate"],
			"any_habitat_tags": ["reef", "seafloor"],
			"preferred_habitat_tags": ["reef"],
			"minimum_temperature": 2.0,
			"maximum_temperature": 34.0,
			"home_range": 0.0,
		},
		"base_stats": {"health": 6, "speed": 0.0, "mass": 0.4, "sight": 0.0, "hearing": 1.0},
		"default_personality": {
			"aggression": 0.1,
			"courage": 1.0,
			"curiosity": 0.0,
			"sociability": 0.05,
			"territoriality": 0.18,
			"protectiveness": 0.0,
			"patience": 1.0,
		},
		"move_policies": [
			{"move_id": "idle", "base_weight": 1.0, "required_context_tags": ["safe"]},
		],
		"familiar_eligible": false,
		"familiar_profile": {},
	},
	"slime": {
		"id": "slime",
		"display_name": "Slime",
		"category": "monster",
		"body_plan_id": "amorphous",
		"taxonomy_tags": ["monster", "amorphous", "scavenger"],
		"body_tags": ["pseudopod", "absorbent_body"],
		"anatomy_counts": {"pseudopod": 1, "absorbent_body": 1},
		"ecology_tags": ["solitary", "scavenger", "ruins", "swamp"],
		"ecology_profile": {
			"scale_band": "medium",
			"breathing_media": ["none"],
			"diet_tags": ["omnivore", "scavenger"],
			"activity_cycle_tags": ["variable"],
			"social_structure": "solitary",
			"aggregation_mode": "individual",
			"any_habitat_tags": ["ruins", "swamp", "cavern"],
			"preferred_habitat_tags": ["damp"],
			"minimum_temperature": -10.0,
			"maximum_temperature": 48.0,
			"home_range": 8.0,
		},
		"base_stats": {"health": 22, "speed": 3.6, "mass": 35.0, "sight": 5.0, "hearing": 8.0},
		"default_personality": {
			"aggression": 0.28,
			"courage": 0.7,
			"curiosity": 0.38,
			"sociability": 0.08,
			"territoriality": 0.26,
			"protectiveness": 0.0,
			"patience": 0.86,
		},
		"move_policies": [
			{
				"move_id": "flee",
				"base_weight": 0.45,
				"maximum_health_ratio": 0.2,
				"any_context_tags": ["injured", "overwhelmed"],
			},
			{"move_id": "idle", "base_weight": 0.9, "required_context_tags": ["safe"]},
		],
		"familiar_eligible": false,
		"familiar_profile": {},
	},
	"hydra": {
		"id": "hydra",
		"display_name": "Hydra",
		"category": "monster",
		"body_plan_id": "composite",
		"taxonomy_tags": ["monster", "mythic", "draconic", "serpentine", "multipart"],
		"body_tags": [
			"serpentine_body",
			"heads",
			"mouth",
			"jaw",
			"tail",
			"voice",
			"swimmer",
		],
		"anatomy_counts": {"heads": 3, "mouth": 3, "jaw": 3, "tail": 1, "voice": 3},
		"locomotion_tags": ["ground", "serpentine", "swimmer"],
		"ecology_tags": ["solitary", "territorial", "wetland", "marsh", "ruins"],
		"ecology_profile": {
			"scale_band": "huge",
			"breathing_media": ["air"],
			"diet_tags": ["carnivore", "apex_predator"],
			"activity_cycle_tags": ["nocturnal"],
			"social_structure": "solitary",
			"aggregation_mode": "multipart",
			"any_habitat_tags": ["wetland", "marsh", "ruins"],
			"preferred_habitat_tags": ["wetland", "water"],
			"minimum_temperature": 0.0,
			"maximum_temperature": 44.0,
			"home_range": 32.0,
		},
		"base_stats": {"health": 72, "speed": 4.9, "mass": 620.0, "sight": 19.0, "hearing": 17.0},
		"default_personality": {
			"aggression": 0.78,
			"courage": 0.92,
			"curiosity": 0.18,
			"sociability": 0.02,
			"territoriality": 0.96,
			"protectiveness": 0.18,
			"patience": 0.7,
		},
		"move_policies": [
			{
				"move_id": "bite",
				"base_weight": 1.5,
				"maximum_target_distance": 2.2,
				"any_context_tags": ["hostile", "hunting", "target_close"],
			},
			{
				"move_id": "tail_sweep",
				"base_weight": 1.3,
				"maximum_target_distance": 3.2,
				"any_context_tags": ["crowded", "surrounded", "multiple_targets"],
			},
			{"move_id": "idle", "base_weight": 0.2, "required_context_tags": ["safe"]},
		],
		"familiar_eligible": false,
		"familiar_profile": {},
	},
	"gorgon": {
		"id": "gorgon",
		"display_name": "Gorgon",
		"category": "monster",
		"taxonomy_tags": ["monster", "mythic", "serpentine", "humanoid"],
		"body_tags": ["biped", "mouth", "jaw", "head", "legs", "voice", "gaze", "tail"],
		"locomotion_tags": ["ground", "serpentine"],
		"ecology_tags": ["solitary", "territorial", "ruins", "ambush_predator"],
		"ecology_profile": {
			"scale_band": "large",
			"breathing_media": ["air"],
			"diet_tags": ["carnivore", "ambush_predator"],
			"activity_cycle_tags": ["nocturnal"],
			"social_structure": "solitary",
			"aggregation_mode": "individual",
			"any_habitat_tags": ["ruins", "cavern"],
			"preferred_habitat_tags": ["ruins"],
			"minimum_temperature": -5.0,
			"maximum_temperature": 45.0,
			"home_range": 20.0,
		},
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
		"ecology_profile": {
			"scale_band": "small",
			"breathing_media": ["air"],
			"diet_tags": ["omnivore", "scavenger"],
			"activity_cycle_tags": ["nocturnal"],
			"social_structure": "pack",
			"aggregation_mode": "group",
			"any_habitat_tags": ["ruins", "sewer"],
			"preferred_habitat_tags": ["sewer"],
			"minimum_temperature": -5.0,
			"maximum_temperature": 42.0,
			"home_range": 12.0,
		},
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


static func get_raw_definition(species_id: String) -> Dictionary:
	return _resolve_raw_definition(
		species_id.to_lower().strip_edges(),
		[]
	)


static func get_definition(species_id: String) -> MobSpeciesDefinition:
	var value: Dictionary = get_raw_definition(species_id)
	if value.is_empty():
		return null
	return MobSpeciesDefinition.from_dictionary(value)


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


static func get_variant_ids(parent_species_id: String) -> Array[String]:
	var variants: Array[String] = []
	var normalized_parent: String = parent_species_id.to_lower().strip_edges()
	for species_id: String in get_species_ids():
		var value: Variant = DEFINITIONS.get(species_id)
		if (
			value is Dictionary
			and str(
				(value as Dictionary).get("parent_species_id", "")
			).to_lower().strip_edges() == normalized_parent
		):
			variants.append(species_id)
	return variants


static func get_move_policy(species_id: String, move_id: String) -> MobMovePolicy:
	var definition: MobSpeciesDefinition = get_definition(species_id)
	return definition.get_move_policy(move_id) if definition != null else null


static func get_move_ids(species_id: String) -> Array[String]:
	var definition: MobSpeciesDefinition = get_definition(species_id)
	return definition.get_move_ids() if definition != null else []


static func validate_catalog() -> Array[String]:
	var failures: Array[String] = MobMoveCatalog.validate_catalog()
	failures.append_array(MobLocomotionCatalog.validate_catalog())
	failures.append_array(BodyPlanCatalog.validate_catalog())
	for species_id: String in get_species_ids():
		failures.append_array(_validate_inheritance(species_id))
		var definition: MobSpeciesDefinition = get_definition(species_id)
		if definition == null:
			failures.append("could not resolve species " + species_id)
			continue
		for failure: String in definition.validate(MobMoveCatalog):
			failures.append(failure)
	return failures


static func _resolve_raw_definition(
	species_id: String,
	lineage: Array[String]
) -> Dictionary:
	if species_id == "" or lineage.has(species_id):
		return {}
	var value: Variant = DEFINITIONS.get(species_id)
	if not value is Dictionary:
		return {}
	var own: Dictionary = (value as Dictionary).duplicate(true)
	var parent_species_id: String = str(
		own.get("parent_species_id", "")
	).to_lower().strip_edges()
	if parent_species_id == "":
		return own
	var next_lineage: Array[String] = lineage.duplicate()
	next_lineage.append(species_id)
	var inherited: Dictionary = _resolve_raw_definition(
		parent_species_id,
		next_lineage
	)
	if inherited.is_empty():
		return {}
	return _merge_definition_dictionaries(inherited, own)


static func _merge_definition_dictionaries(
	inherited: Dictionary,
	own: Dictionary
) -> Dictionary:
	var result: Dictionary = inherited.duplicate(true)
	for raw_key: Variant in own.keys():
		var key: String = str(raw_key)
		var own_value: Variant = own[raw_key]
		var inherited_value: Variant = result.get(key)
		if own_value is Dictionary and inherited_value is Dictionary:
			result[key] = _merge_definition_dictionaries(
				inherited_value as Dictionary,
				own_value as Dictionary
			)
		elif (
			own_value is Array
			and inherited_value is Array
			and ADDITIVE_VARIANT_ARRAY_KEYS.has(key)
		):
			var merged_values: Array = (inherited_value as Array).duplicate(true)
			for raw_item: Variant in own_value as Array:
				if not merged_values.has(raw_item):
					merged_values.append(raw_item)
			result[key] = merged_values
		else:
			result[key] = own_value
	for array_key: String in ADDITIVE_VARIANT_ARRAY_KEYS:
		var remove_key: String = "remove_" + array_key
		var removals: Variant = own.get(remove_key, [])
		var inherited_array: Variant = result.get(array_key, [])
		if not removals is Array or not inherited_array is Array:
			continue
		var filtered_values: Array = (
			inherited_array as Array
		).duplicate(true)
		for raw_item: Variant in removals as Array:
			filtered_values.erase(raw_item)
		result[array_key] = filtered_values
	return result


static func _validate_inheritance(species_id: String) -> Array[String]:
	var failures: Array[String] = []
	var lineage: Array[String] = []
	var current_id: String = species_id
	while current_id != "":
		if lineage.has(current_id):
			lineage.append(current_id)
			failures.append(
				species_id + " has inheritance cycle " + " -> ".join(lineage)
			)
			break
		lineage.append(current_id)
		var value: Variant = DEFINITIONS.get(current_id)
		if not value is Dictionary:
			failures.append(
				species_id + " references missing parent species " + current_id
			)
			break
		current_id = str(
			(value as Dictionary).get("parent_species_id", "")
		).to_lower().strip_edges()
	return failures


static func get_debug_data() -> Dictionary:
	var rows: Array[Dictionary] = []
	for definition: MobSpeciesDefinition in get_definitions():
		rows.append(definition.to_dictionary())
	var variant_count: int = 0
	for species_id: String in get_species_ids():
		var value: Variant = DEFINITIONS.get(species_id)
		if (
			value is Dictionary
			and str(
				(value as Dictionary).get("parent_species_id", "")
			).strip_edges() != ""
		):
			variant_count += 1
	return {
		"species_count": rows.size(),
		"variant_count": variant_count,
		"species": rows,
		"body_plan_count": BodyPlanCatalog.get_body_plan_ids().size(),
		"locomotion_capability_count": MobLocomotionCatalog.get_capability_ids().size(),
		"failures": validate_catalog(),
	}
