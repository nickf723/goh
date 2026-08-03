extends RefCounted
class_name MobPersonalityAdapter

const TRAIT_IDS: Array[String] = [
	"aggression",
	"courage",
	"curiosity",
	"sociability",
	"territoriality",
	"protectiveness",
	"patience",
]

const PROFILE_TRAITS: Dictionary = {
	"balanced": {
		"aggression": 0.5,
		"courage": 0.5,
		"curiosity": 0.5,
		"sociability": 0.5,
		"territoriality": 0.5,
		"protectiveness": 0.5,
		"patience": 0.5,
	},
	"cautious": {
		"aggression": 0.24,
		"courage": 0.32,
		"curiosity": 0.42,
		"sociability": 0.56,
		"territoriality": 0.42,
		"protectiveness": 0.68,
		"patience": 0.78,
	},
	"bold": {
		"aggression": 0.82,
		"courage": 0.88,
		"curiosity": 0.62,
		"sociability": 0.58,
		"territoriality": 0.68,
		"protectiveness": 0.58,
		"patience": 0.28,
	},
	"skittish": {
		"aggression": 0.18,
		"courage": 0.12,
		"curiosity": 0.38,
		"sociability": 0.78,
		"territoriality": 0.2,
		"protectiveness": 0.42,
		"patience": 0.36,
	},
	"brute": {
		"aggression": 0.94,
		"courage": 0.92,
		"curiosity": 0.24,
		"sociability": 0.3,
		"territoriality": 0.8,
		"protectiveness": 0.34,
		"patience": 0.12,
	},
	"opportunist": {
		"aggression": 0.62,
		"courage": 0.54,
		"curiosity": 0.76,
		"sociability": 0.46,
		"territoriality": 0.44,
		"protectiveness": 0.36,
		"patience": 0.68,
	},
}


static func from_enemy_profile(profile_id: String) -> Dictionary:
	var normalized: String = EnemyPersonalityTraits.normalize_profile_id(profile_id)
	var value: Variant = PROFILE_TRAITS.get(normalized, PROFILE_TRAITS["balanced"])
	return (value as Dictionary).duplicate(true)


static func merge_traits(base: Dictionary, overrides: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for trait_id: String in TRAIT_IDS:
		result[trait_id] = clampf(float(base.get(trait_id, 0.5)), 0.0, 1.0)
	for raw_key: Variant in overrides.keys():
		var trait_id: String = str(raw_key).to_lower().strip_edges()
		if TRAIT_IDS.has(trait_id):
			result[trait_id] = clampf(float(overrides[raw_key]), 0.0, 1.0)
	return result


static func apply_profile_to_species(
	species_id: String,
	profile_id: String,
	individual_overrides: Dictionary = {}
) -> Dictionary:
	var species: MobSpeciesDefinition = MobSpeciesCatalog.get_definition(species_id)
	if species == null:
		return {}
	var traits: Dictionary = species.get_personality()
	traits = merge_traits(traits, from_enemy_profile(profile_id))
	return merge_traits(traits, individual_overrides)
