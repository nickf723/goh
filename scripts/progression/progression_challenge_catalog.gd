extends RefCounted
class_name ProgressionChallengeCatalog

const CHALLENGE_ORDER: Array[String] = [
	"trial_by_flame",
	"live_wire",
	"shatterproof",
	"kitchen_chemistry",
	"pack_scholar",
]

const CHALLENGES: Dictionary = {
	"trial_by_flame": {
		"id": "trial_by_flame",
		"display_name": "Trial by Flame",
		"icon": "▲",
		"description": "Discover combustion by igniting an Oily target.",
		"event_type": "reaction_triggered",
		"event_key": "ignite_oil",
		"mode": "count",
		"target": 1,
		"reward_id": "charged_firebolt",
		"reward_name": "Charged Firebolt",
		"requirement": "Trigger Ignite Oil once.",
	},
	"live_wire": {
		"id": "live_wire",
		"display_name": "Live Wire",
		"icon": "ϟ",
		"description": "Use Water as a conductor instead of treating elements as isolated damage colors.",
		"event_type": "reaction_triggered",
		"event_key": "wet_conduction",
		"mode": "count",
		"target": 3,
		"reward_id": "chain_lightning",
		"reward_name": "Chain Lightning",
		"requirement": "Trigger Wet Conduction three times.",
	},
	"shatterproof": {
		"id": "shatterproof",
		"display_name": "Shatterproof",
		"icon": "❄",
		"description": "Learn that Frozen is a setup state, not merely a pause button.",
		"event_type": "reaction_triggered",
		"event_key": "shatter",
		"mode": "count",
		"target": 5,
		"reward_id": "piercing_ice_lance",
		"reward_name": "Piercing Ice Lance",
		"requirement": "Shatter five Frozen targets.",
	},
	"kitchen_chemistry": {
		"id": "kitchen_chemistry",
		"display_name": "Kitchen Chemistry",
		"icon": "⚗",
		"description": "Turn experimentation into repeatable alchemical knowledge.",
		"event_type": "recipe_discovered",
		"event_key": "*",
		"mode": "unique",
		"target": 3,
		"reward_id": "alchemy_recipe_insight",
		"reward_name": "Alchemy Recipe Insight",
		"requirement": "Discover three different potion formulas.",
		"reward_definition": {
			"id": "alchemy_recipe_insight",
			"display_name": "Alchemy Recipe Insight",
			"type": "passive",
			"menu_category": "Alchemy Upgrades",
			"description": "Grace can recognize promising ingredient relationships before committing a brew. Runtime preview hooks are reserved for the alchemy upgrade pass.",
			"source": "Kitchen Chemistry",
			"tags": ["alchemy", "recipe", "insight", "challenge"],
			"effect_preview": "Future cauldrons can preview whether an ingredient pair has a known relationship.",
		},
	},
	"pack_scholar": {
		"id": "pack_scholar",
		"display_name": "Pack Scholar",
		"icon": "◇",
		"description": "Study Gremlins deeply enough to reproduce one of their committed techniques.",
		"event_type": "species_rank",
		"event_key": "gremlin",
		"mode": "absolute",
		"target": 3,
		"reward_id": "gremlin_pounce",
		"reward_name": "Gremlin Pounce Technique",
		"requirement": "Reach Gremlin Knowledge Rank 3.",
		"reward_definition": {
			"id": "gremlin_pounce",
			"display_name": "Gremlin Pounce Technique",
			"type": "passive",
			"menu_category": "Familiar Techniques",
			"description": "The Gremlin familiar may equip Pounce after Grace understands the species deeply enough.",
			"source": "Pack Scholar",
			"tags": ["gremlin", "familiar", "pounce", "challenge"],
		},
	},
}


static func has_challenge(challenge_id: String) -> bool:
	return CHALLENGES.has(challenge_id)


static func get_definition(challenge_id: String) -> Dictionary:
	if not has_challenge(challenge_id):
		return {}
	return (CHALLENGES[challenge_id] as Dictionary).duplicate(true)


static func get_definitions() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for challenge_id: String in CHALLENGE_ORDER:
		rows.append(get_definition(challenge_id))
	return rows


static func get_matching(event_type: String, event_key: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for definition: Dictionary in get_definitions():
		if str(definition.get("event_type", "")) != event_type:
			continue
		var required_key: String = str(definition.get("event_key", "*"))
		if required_key != "*" and required_key != event_key:
			continue
		rows.append(definition)
	return rows


static func validate_catalog() -> Array[String]:
	var failures: Array[String] = []
	var seen: Dictionary = {}
	for challenge_id: String in CHALLENGE_ORDER:
		if seen.has(challenge_id):
			failures.append("duplicate challenge id: " + challenge_id)
		seen[challenge_id] = true
		var row: Dictionary = get_definition(challenge_id)
		if row.is_empty():
			failures.append("missing challenge: " + challenge_id)
			continue
		if int(row.get("target", 0)) <= 0:
			failures.append(challenge_id + " needs a positive target")
		if str(row.get("reward_id", "")) == "":
			failures.append(challenge_id + " needs a reward")
		if str(row.get("mode", "")) not in ["count", "unique", "absolute"]:
			failures.append(challenge_id + " has an unsupported mode")
	return failures
