extends RefCounted
class_name DivinePatronCatalog

const PATRON_ORDER: Array[String] = [
	"tirisi", "auriaga", "ruvia", "soficcori",
	"forcado", "accencia", "giavolo", "ossevi",
	"erbamia", "igifani", "ovananni", "assiziati",
	"lacara", "schicesse", "vocillio", "vermegullo",
]

const DEFINITIONS: Dictionary = {
	"tirisi": {
		"id": "tirisi", "name": "Tirisi", "element": "water", "hue": "Azure",
		"weapon": "Flail", "relationship": "A distant current of empathy, memory, and motion.",
	},
	"auriaga": {
		"id": "auriaga", "name": "Auriaga", "element": "earth", "hue": "Green",
		"weapon": "Hammer", "relationship": "A covenant of stewardship, endurance, and living terrain.",
	},
	"ruvia": {
		"id": "ruvia", "name": "Ruvia", "element": "fire", "hue": "Scarlet",
		"weapon": "Halberd", "relationship": "A fierce bond of protection, heat, and decisive action.",
		"incarnation_prototype": true,
	},
	"soficcori": {
		"id": "soficcori", "name": "Soficcori", "element": "air", "hue": "Pink",
		"weapon": "Boomerang", "relationship": "A social wind shaped through trust, movement, and return.",
	},
	"forcado": {
		"id": "forcado", "name": "Forcado", "element": "ice", "hue": "Turquoise",
		"weapon": "Lance", "relationship": "A quiet pact of patience, preservation, and exact pursuit.",
	},
	"accencia": {
		"id": "accencia", "name": "Accencia", "element": "metal", "hue": "Yellow",
		"weapon": "Sword", "relationship": "A practical alliance of craft, leverage, and unyielding structure.",
	},
	"giavolo": {
		"id": "giavolo", "name": "Giavolo", "element": "lightning", "hue": "Indigo",
		"weapon": "Shuriken", "relationship": "A disciplined circuit of precision, speed, and stored charge.",
	},
	"ossevi": {
		"id": "ossevi", "name": "Ossevi", "element": "poison", "hue": "Chartreuse",
		"weapon": "Whip", "relationship": "A volatile understanding of adaptation, exposure, and consequence.",
	},
	"erbamia": {
		"id": "erbamia", "name": "Erbamia", "element": "life", "hue": "Verdant",
		"weapon": "Twin Daggers", "relationship": "A nurturing bond of growth, ecosystems, and difficult mercy.",
	},
	"igifani": {
		"id": "igifani", "name": "Igifani", "element": "death", "hue": "Red",
		"weapon": "Scythe", "relationship": "A clinical compact with endings, remains, and forbidden inquiry.",
	},
	"ovananni": {
		"id": "ovananni", "name": "Ovananni", "element": "body", "hue": "Magenta",
		"weapon": "Gauntlets", "relationship": "A tactile pact of flesh, instinct, adaptation, and force.",
	},
	"assiziati": {
		"id": "assiziati", "name": "Assiziati", "element": "soul", "hue": "Cyan",
		"weapon": "Staff", "relationship": "A commanding link between identity, spirit, and living will.",
	},
	"lacara": {
		"id": "lacara", "name": "Lacara", "element": "dreams", "hue": "Blue",
		"weapon": "Axe", "relationship": "A guarded intimacy with imagination, memory, and impossible spaces.",
	},
	"schicesse": {
		"id": "schicesse", "name": "Schicesse", "element": "sound", "hue": "Orange",
		"weapon": "Mace", "relationship": "A resonant friendship expressed through performance, rhythm, and echo.",
	},
	"vocillio": {
		"id": "vocillio", "name": "Vocillio", "element": "space", "hue": "Violet",
		"weapon": "Chains", "relationship": "A dangerous fascination with distance, freedom, and cosmic play.",
	},
	"vermegullo": {
		"id": "vermegullo", "name": "Vermegullo", "element": "time", "hue": "Amber",
		"weapon": "Bow", "relationship": "A measured contract with sequence, preparation, and irreversible choice.",
	},
}

const RELATIONSHIP_STAGES: Array[Dictionary] = [
	{"id": "contact", "name": "Contact", "description": "Grace establishes a stable channel to the patron."},
	{"id": "covenant", "name": "Covenant", "description": "The patron grants invocations and Divine Specials."},
	{"id": "communion", "name": "Communion", "description": "Grace can freely combine the patron's authority with her own kit."},
	{"id": "incarnation", "name": "Incarnation", "description": "The patron may manifest as a playable Divine Incarnation."},
]


static func has_patron(patron_id: String) -> bool:
	return DEFINITIONS.has(patron_id)


static func get_definition(patron_id: String) -> Dictionary:
	if not has_patron(patron_id):
		return {}
	return (DEFINITIONS[patron_id] as Dictionary).duplicate(true)


static func get_definitions() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for patron_id: String in PATRON_ORDER:
		rows.append(get_definition(patron_id))
	return rows


static func get_patron_for_element(element_id: String) -> Dictionary:
	for patron_id: String in PATRON_ORDER:
		var row: Dictionary = get_definition(patron_id)
		if str(row.get("element", "")) == element_id:
			return row
	return {}


static func get_unlock_id(patron_id: String, stage_id: String) -> String:
	return "patron." + patron_id + "." + stage_id


static func get_relationship_rank(patron_id: String) -> int:
	if not has_patron(patron_id):
		return 0
	var rank: int = 0
	for stage_index: int in range(RELATIONSHIP_STAGES.size()):
		var stage_id: String = str(RELATIONSHIP_STAGES[stage_index].get("id", ""))
		if GameState.has_unlock(get_unlock_id(patron_id, stage_id)):
			rank = stage_index + 1
	return rank


static func get_relationship_stage_name(patron_id: String) -> String:
	var rank: int = get_relationship_rank(patron_id)
	if rank <= 0:
		return "Uncontacted"
	return str(RELATIONSHIP_STAGES[rank - 1].get("name", "Known"))


static func is_incarnation_unlocked(patron_id: String) -> bool:
	return GameState.has_unlock(get_unlock_id(patron_id, "incarnation"))


static func validate_catalog() -> Array[String]:
	var failures: Array[String] = []
	if PATRON_ORDER.size() != 16:
		failures.append("divine patron catalog must contain sixteen patrons")
	var seen_elements: Dictionary = {}
	for patron_id: String in PATRON_ORDER:
		var row: Dictionary = get_definition(patron_id)
		if row.is_empty():
			failures.append("missing patron definition: " + patron_id)
			continue
		var element_id: String = str(row.get("element", ""))
		if seen_elements.has(element_id):
			failures.append("duplicate patron element: " + element_id)
		seen_elements[element_id] = true
		if str(row.get("name", "")).strip_edges() == "":
			failures.append(patron_id + " has no display name")
		if str(row.get("weapon", "")).strip_edges() == "":
			failures.append(patron_id + " has no signature weapon")
	return failures
