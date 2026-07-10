extends Node
class_name StatCatalog

# Central stat dictionary for Grace's RPG skeleton.
# This is intentionally structural first: names, groupings, defaults, and descriptions.
# Scaling formulas can hook into these ids later without changing menu/UI structure.

const DEFAULT_STATS: Dictionary = {
	"level": 1,

	# Action resources. Current prototype keeps these playable rather than making
	# every resource pool tiny. The stat system can later derive max values from
	# the base rating.
	"health": 5,
	"max_health": 5,
	"stamina": 5,
	"max_stamina": 5,
	"mana": 5,
	"max_mana": 5,
	"stance": 5,
	"max_stance": 5,

	# 16 base stats.
	"power": 1,
	"dexterity": 1,
	"arcana": 1,
	"intelligence": 1,
	"defense": 1,
	"resilience": 1,
	"constitution": 1,
	"evasion": 1,
	"focus": 5,
	"charisma": 1,
	"skill": 1,
	"luck": 1,

	# Elemental affinities. These are separate from the 16 base stats, but useful
	# to show early so new spells have obvious affinity hooks later.
	"fire": 1,
	"water": 1,
	"earth": 1,
	"air": 1,
	"ice": 1,
	"metal": 1,
	"lightning": 1,
	"poison": 1,
	"life": 1,
	"death": 1,
	"body": 1,
	"soul": 1,
	"dreams": 1,
	"sound": 1,
	"space": 1,
	"time": 1,

	# Primordial / non-core affinity hooks.
	"light": 1,
	"darkness": 1,
	"dark": 1,
	"void": 1,
}

const ACTION_RESOURCE_IDS: Array[String] = [
	"health",
	"stamina",
	"mana",
	"stance",
]

const BASE_STAT_DEFINITIONS: Array[Dictionary] = [
	{
		"id": "health",
		"name": "Health",
		"group": "Action Resources",
		"summary": "How much direct punishment Grace can take before falling.",
		"use": "Taking hits, survival checks, future injury systems.",
	},
	{
		"id": "stamina",
		"name": "Stamina",
		"group": "Action Resources",
		"summary": "Physical action fuel.",
		"use": "Weapon attacks, dodges, climbing, sprinting, heavy physical actions.",
	},
	{
		"id": "mana",
		"name": "Mana",
		"group": "Action Resources",
		"summary": "Magical action fuel.",
		"use": "Spell costs, magical tools, future rituals, high-output casting.",
	},
	{
		"id": "stance",
		"name": "Stance",
		"group": "Action Resources",
		"summary": "Poise and stability before Grace is staggered or broken open.",
		"use": "Taking pressure, blocking, resisting interruption, future guard systems.",
	},
	{
		"id": "power",
		"name": "Power",
		"group": "Physical Offense",
		"summary": "Raw physical force.",
		"use": "Physical damage, heavy weapon pressure, knockback, impact-based actions.",
	},
	{
		"id": "dexterity",
		"name": "Dexterity",
		"group": "Physical Offense",
		"summary": "Physical handling and attack support.",
		"use": "Swing speed, start lag, end lag, weapon handling, precision actions.",
	},
	{
		"id": "arcana",
		"name": "Arcana",
		"group": "Magic Offense",
		"summary": "Raw magical force.",
		"use": "Spell damage, magical pressure, elemental output, magical payload strength.",
	},
	{
		"id": "intelligence",
		"name": "Intelligence",
		"group": "Magic Offense",
		"summary": "Magical handling and spellcraft support.",
		"use": "Cast support, spell control, magical start/end lag, complex spell behavior.",
	},
	{
		"id": "defense",
		"name": "Defense",
		"group": "Protection and Recovery",
		"summary": "Physical damage protection.",
		"use": "Reducing weapon, impact, creature, trap, and other physical damage.",
	},
	{
		"id": "resilience",
		"name": "Resilience",
		"group": "Protection and Recovery",
		"summary": "Magical damage protection.",
		"use": "Reducing spell, elemental, curse, spirit, and other magic damage.",
	},
	{
		"id": "constitution",
		"name": "Constitution",
		"group": "Protection and Recovery",
		"summary": "Recovery and bodily endurance.",
		"use": "Regenerating health, stamina, mana, and stance. Future status resistance.",
	},
	{
		"id": "evasion",
		"name": "Evasion",
		"group": "Protection and Recovery",
		"summary": "Avoidance and dodge support.",
		"use": "Dodging, avoiding attacks, i-frame support, future miss/graze logic.",
	},
	{
		"id": "focus",
		"name": "Focus",
		"group": "Utility",
		"summary": "Decision-space control while the game world keeps moving.",
		"use": "Quick menus, time-slow strength, planning while enemies remain active.",
	},
	{
		"id": "charisma",
		"name": "Charisma",
		"group": "Utility",
		"summary": "Social leverage and presence.",
		"use": "NPC conversations, persuasion, trust, bargaining, faction/social checks.",
	},
	{
		"id": "skill",
		"name": "Skill",
		"group": "Utility",
		"summary": "A flexible technique/proficiency catch-all for now.",
		"use": "Crafty actions, proc support, precision interactions, future specialist checks.",
	},
	{
		"id": "luck",
		"name": "Luck",
		"group": "Utility",
		"summary": "Provisional chance/proc stat. The name may change later.",
		"use": "Percentage-based effects, lucky triggers, drops, rare reactions, proc chance.",
	},
]

const BASE_STAT_GROUPS: Array[Dictionary] = [
	{
		"id": "action_resources",
		"title": "Action Resources",
		"description": "Taking hits and paying for actions. These still use current/max values in the prototype.",
		"stats": ["health", "stamina", "mana", "stance"],
	},
	{
		"id": "physical_offense",
		"title": "Physical Offense",
		"description": "Weapon damage and attack feel.",
		"stats": ["power", "dexterity"],
	},
	{
		"id": "magic_offense",
		"title": "Magic Offense",
		"description": "Spell damage and spell handling.",
		"stats": ["arcana", "intelligence"],
	},
	{
		"id": "protection_recovery",
		"title": "Protection and Recovery",
		"description": "Damage reduction, recovery, and avoiding hits.",
		"stats": ["defense", "resilience", "constitution", "evasion"],
	},
	{
		"id": "utility",
		"title": "Utility",
		"description": "Menus, NPCs, flexible checks, and chance effects.",
		"stats": ["focus", "charisma", "skill", "luck"],
	},
]

const ELEMENTAL_AFFINITY_GROUPS: Array[Dictionary] = [
	{
		"id": "natural_affinity",
		"title": "Natural Affinities",
		"description": "Future scaling hooks for natural magic.",
		"stats": ["water", "earth", "fire", "air"],
	},
	{
		"id": "primal_affinity",
		"title": "Primal Affinities",
		"description": "Future scaling hooks for primal magic.",
		"stats": ["ice", "metal", "lightning", "poison"],
	},
	{
		"id": "vital_affinity",
		"title": "Vital Affinities",
		"description": "Future scaling hooks for vital magic.",
		"stats": ["life", "death", "body", "soul"],
	},
	{
		"id": "mystical_affinity",
		"title": "Mystical Affinities",
		"description": "Future scaling hooks for mystical magic.",
		"stats": ["dreams", "sound", "space", "time"],
	},
	{
		"id": "primordial_affinity",
		"title": "Primordial Affinities",
		"description": "Non-core hooks for Light, Darkness, and Void.",
		"stats": ["light", "darkness", "void"],
	},
]


static func get_default_stats() -> Dictionary:
	return DEFAULT_STATS.duplicate(true)


static func get_base_stat_sections(values: Dictionary) -> Array[Dictionary]:
	return make_sections(BASE_STAT_GROUPS, values, true)


static func get_elemental_affinity_sections(values: Dictionary) -> Array[Dictionary]:
	return make_sections(ELEMENTAL_AFFINITY_GROUPS, values, false)


static func get_menu_sections(values: Dictionary) -> Array[Dictionary]:
	var sections: Array[Dictionary] = []
	sections.append_array(get_base_stat_sections(values))
	sections.append_array(get_elemental_affinity_sections(values))
	return sections


static func make_sections(group_defs: Array[Dictionary], values: Dictionary, include_descriptions: bool) -> Array[Dictionary]:
	var sections: Array[Dictionary] = []

	for group_def: Dictionary in group_defs:
		var section: Dictionary = {
			"id": str(group_def.get("id", "stat_group")),
			"title": str(group_def.get("title", "Stats")),
			"description": str(group_def.get("description", "")),
			"stats": [],
		}
		var stat_ids: Array = group_def.get("stats", [])

		for stat_id_variant in stat_ids:
			var stat_id: String = str(stat_id_variant)
			section["stats"].append(make_stat_row(stat_id, values, include_descriptions))

		sections.append(section)

	return sections


static func make_stat_row(stat_id: String, values: Dictionary, include_description: bool) -> Dictionary:
	var definition: Dictionary = get_stat_definition(stat_id)
	var row: Dictionary = definition.duplicate(true)
	row["value"] = get_stat_value_text(stat_id, values)

	if not include_description:
		row["summary"] = "Affinity hook for future scaling."
		row["use"] = "Elemental scaling, combo tuning, resistance checks, and spell identity."

	return row


static func get_stat_definition(stat_id: String) -> Dictionary:
	for definition: Dictionary in BASE_STAT_DEFINITIONS:
		if str(definition.get("id", "")) == stat_id:
			return definition.duplicate(true)

	return {
		"id": stat_id,
		"name": stat_id.capitalize(),
		"group": "Affinity",
		"summary": "Affinity hook for future scaling.",
		"use": "Elemental scaling, combo tuning, resistance checks, and spell identity.",
	}


static func get_stat_value_text(stat_id: String, values: Dictionary) -> String:
	if ACTION_RESOURCE_IDS.has(stat_id):
		var max_key: String = "max_" + stat_id

		if values.has(max_key):
			return str(int(values.get(stat_id, 0))) + " / " + str(int(values.get(max_key, 0)))

	return str(int(values.get(stat_id, 0)))


static func get_base_stat_ids() -> Array[String]:
	var ids: Array[String] = []

	for definition: Dictionary in BASE_STAT_DEFINITIONS:
		ids.append(str(definition.get("id", "")))

	return ids
