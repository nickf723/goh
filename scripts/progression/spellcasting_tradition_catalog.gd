extends RefCounted
class_name SpellcastingTraditionCatalog

const STAGE_IDS: Array[String] = [
	"initiation",
	"practice",
	"trial",
	"mastery",
]
const STAGE_DISPLAY_NAMES: Dictionary = {
	"initiation": "Initiation",
	"practice": "Practice",
	"trial": "Trial",
	"mastery": "Mastery",
}
const TRADITION_IDS: Array[String] = [
	"sorcery",
	"wizardry",
	"druidry",
	"warlock",
	"theurgy",
	"bardic",
	"artifice",
	"ritualism",
]

# These are development-facing magical relationships, not mutually exclusive classes.
# Their labels and prose can be replaced by setting-specific names without changing the IDs.
const TRADITIONS: Dictionary = {
	"sorcery": {
		"id": "sorcery",
		"display_name": "Sorcery",
		"relationship": "Magic inherited through bloodline and expressed through instinct.",
		"verbs": ["improvise", "overchannel", "cast_in_motion"],
		"automatic_for_all_spells": true,
		"compatibility_elements": [],
		"compatibility_tags": ["instinctive", "quick_cast", "overchannel"],
		"compatibility_categories": [],
		"capstone": {
			"id": "spellcasting.capstone.sorcery",
			"display_name": "Sorcery Capstone",
			"description": "Reserved hook for the final instinctive-casting mechanic.",
			"implemented": false,
		},
	},
	"wizardry": {
		"id": "wizardry",
		"display_name": "Wizardry",
		"relationship": "Magic understood through study, analysis, preparation, and deliberate shaping.",
		"verbs": ["analyze", "prepare", "reshape"],
		"automatic_for_all_spells": true,
		"compatibility_elements": [],
		"compatibility_tags": ["studied", "formula", "prepared", "shaping", "analysis"],
		"compatibility_categories": [],
		"capstone": {
			"id": "spellcasting.capstone.wizardry",
			"display_name": "Wizardry Capstone",
			"description": "Reserved hook for the final spell-shaping mechanic.",
			"implemented": false,
		},
	},
	"druidry": {
		"id": "druidry",
		"display_name": "Druidry",
		"relationship": "Magic reached through communion with living systems and the physical world.",
		"verbs": ["listen", "borrow", "cultivate"],
		"automatic_for_all_spells": false,
		"compatibility_elements": ["water", "earth", "fire", "air", "ice", "poison", "life"],
		"compatibility_tags": ["nature", "environmental_source", "terrain", "plant", "creature", "weather", "growth", "ecosystem"],
		"compatibility_categories": [],
		"capstone": {
			"id": "spellcasting.capstone.druidry",
			"display_name": "Druidry Capstone",
			"description": "Reserved hook for casting through compatible world sources.",
			"implemented": false,
		},
	},
	"warlock": {
		"id": "warlock",
		"display_name": "Warlock",
		"relationship": "Magic borrowed through a reciprocal covenant with a patron.",
		"verbs": ["covenant", "invoke", "manifest", "incarnate"],
		"automatic_for_all_spells": false,
		"compatibility_elements": [
			"water", "earth", "fire", "air", "ice", "metal", "lightning", "poison",
			"life", "death", "body", "soul", "dreams", "sound", "space", "time",
			"light", "darkness", "void",
		],
		"compatibility_tags": ["patron", "divine", "covenant", "invocation", "manifestation", "incarnation"],
		"compatibility_categories": ["summon"],
		"capstone": {
			"id": "divine_incarnation",
			"display_name": "Divine Incarnation",
			"description": "Reserved gateway for manifesting a patron god as the active playable avatar.",
			"implemented": false,
		},
	},
	"theurgy": {
		"id": "theurgy",
		"display_name": "Theurgy",
		"relationship": "Magic shaped through devotion, protection, service, and shared conviction.",
		"verbs": ["bless", "ward", "restore"],
		"automatic_for_all_spells": false,
		"compatibility_elements": ["light", "life", "soul"],
		"compatibility_tags": ["heal", "healing", "protection", "ward", "blessing", "revival", "cleanse", "support"],
		"compatibility_categories": [],
		"capstone": {
			"id": "spellcasting.capstone.theurgy",
			"display_name": "Theurgy Capstone",
			"description": "Reserved hook for the final communal miracle mechanic.",
			"implemented": false,
		},
	},
	"bardic": {
		"id": "bardic",
		"display_name": "Bardic Magic",
		"relationship": "Magic expressed through sound, rhythm, performance, memory, and emotion.",
		"verbs": ["perform", "resonate", "echo"],
		"automatic_for_all_spells": false,
		"compatibility_elements": ["sound", "dreams"],
		"compatibility_tags": ["resonance", "echo", "rhythm", "performance", "song", "emotion", "cadence"],
		"compatibility_categories": [],
		"capstone": {
			"id": "spellcasting.capstone.bardic",
			"display_name": "Bardic Capstone",
			"description": "Reserved hook for the final resonant chain-casting mechanic.",
			"implemented": false,
		},
	},
	"artifice": {
		"id": "artifice",
		"display_name": "Artifice",
		"relationship": "Magic captured, stored, and expressed through crafted objects and mechanisms.",
		"verbs": ["capture", "imbue", "construct"],
		"automatic_for_all_spells": false,
		"compatibility_elements": ["metal", "lightning"],
		"compatibility_tags": ["device", "gadget", "trap", "construct", "automaton", "imbue", "stored_spell", "machinery"],
		"compatibility_categories": [],
		"capstone": {
			"id": "spellcasting.capstone.artifice",
			"display_name": "Artifice Capstone",
			"description": "Reserved hook for persistent spellcraft and advanced magical devices.",
			"implemented": false,
		},
	},
	"ritualism": {
		"id": "ritualism",
		"display_name": "Ritualism",
		"relationship": "Magic assembled through symbols, ingredients, timing, space, and preparation.",
		"verbs": ["inscribe", "prepare", "sustain"],
		"automatic_for_all_spells": false,
		"compatibility_elements": [],
		"compatibility_tags": ["ritual", "circle", "delayed", "persistent", "prepared", "large_scale", "ceremony"],
		"compatibility_categories": ["summon", "transformation"],
		"capstone": {
			"id": "spellcasting.capstone.ritualism",
			"display_name": "Ritualism Capstone",
			"description": "Reserved hook for the final grand-ritual mechanic.",
			"implemented": false,
		},
	},
}


static func has_tradition(tradition_id: String) -> bool:
	return TRADITIONS.has(tradition_id)


static func has_stage(stage_id: String) -> bool:
	return STAGE_IDS.has(stage_id)


static func get_definition(tradition_id: String) -> Dictionary:
	if not has_tradition(tradition_id):
		return {}
	return (TRADITIONS[tradition_id] as Dictionary).duplicate(true)


static func get_definitions() -> Array[Dictionary]:
	var definitions: Array[Dictionary] = []
	for tradition_id: String in TRADITION_IDS:
		definitions.append(get_definition(tradition_id))
	return definitions


static func get_display_name(tradition_id: String) -> String:
	return str(get_definition(tradition_id).get("display_name", tradition_id.capitalize()))


static func get_stage_rank(stage_id: String) -> int:
	var stage_index: int = STAGE_IDS.find(stage_id)
	return stage_index + 1 if stage_index >= 0 else 0


static func get_stage_id(rank: int) -> String:
	if rank <= 0 or rank > STAGE_IDS.size():
		return ""
	return STAGE_IDS[rank - 1]


static func get_stage_display_name(stage_id: String) -> String:
	return str(STAGE_DISPLAY_NAMES.get(stage_id, stage_id.capitalize()))


static func get_capstone(tradition_id: String) -> Dictionary:
	var definition: Dictionary = get_definition(tradition_id)
	var raw_capstone: Variant = definition.get("capstone", {})
	if not raw_capstone is Dictionary:
		return {}
	return (raw_capstone as Dictionary).duplicate(true)


static func get_achievement_id(tradition_id: String, stage_id: String) -> String:
	if not has_tradition(tradition_id) or not has_stage(stage_id):
		return ""
	return "spellcasting." + tradition_id + "." + stage_id


static func get_achievement_definition(tradition_id: String, stage_id: String) -> Dictionary:
	var achievement_id: String = get_achievement_id(tradition_id, stage_id)
	if achievement_id == "":
		return {}

	var tradition_name: String = get_display_name(tradition_id)
	var stage_name: String = get_stage_display_name(stage_id)
	var stage_rank: int = get_stage_rank(stage_id)
	var capstone: Dictionary = get_capstone(tradition_id)
	var description: String = _get_stage_description(tradition_id, stage_id)
	var reward_hooks: Array[String] = []
	if stage_id == "mastery":
		var capstone_id: String = str(capstone.get("id", ""))
		if capstone_id != "":
			reward_hooks.append(capstone_id)

	return {
		"id": achievement_id,
		"display_name": tradition_name + ": " + stage_name,
		"description": description,
		"type": "achievement",
		"menu_category": "Spellcasting Mastery",
		"source": "Spellcasting Traditions",
		"source_id": "spellcasting_mastery",
		"tradition_id": tradition_id,
		"stage_id": stage_id,
		"stage_rank": stage_rank,
		"is_mastery": stage_id == "mastery",
		"reward_hooks": reward_hooks,
		"sort_index": TRADITION_IDS.find(tradition_id) * 10 + stage_rank,
		"tags": ["achievement", "spellcasting", "tradition", tradition_id, stage_id],
	}


static func get_achievement_definitions() -> Array[Dictionary]:
	var definitions: Array[Dictionary] = []
	for tradition_id: String in TRADITION_IDS:
		for stage_id: String in STAGE_IDS:
			definitions.append(get_achievement_definition(tradition_id, stage_id))
	return definitions


static func validate_catalog() -> Array[String]:
	var errors: Array[String] = []
	var seen_ids: Dictionary = {}

	if TRADITION_IDS.size() != 8:
		errors.append("spellcasting tradition catalog must define eight traditions")
	if STAGE_IDS != ["initiation", "practice", "trial", "mastery"]:
		errors.append("spellcasting mastery stages changed order")

	for tradition_id: String in TRADITION_IDS:
		if seen_ids.has(tradition_id):
			errors.append("duplicate spellcasting tradition id: " + tradition_id)
		seen_ids[tradition_id] = true
		if not TRADITIONS.has(tradition_id):
			errors.append("missing spellcasting tradition definition: " + tradition_id)
			continue

		var definition: Dictionary = TRADITIONS[tradition_id] as Dictionary
		if str(definition.get("id", "")) != tradition_id:
			errors.append(tradition_id + " definition id does not match its key")
		if str(definition.get("display_name", "")).strip_edges() == "":
			errors.append(tradition_id + " has no display name")
		if str(definition.get("relationship", "")).strip_edges() == "":
			errors.append(tradition_id + " has no magical relationship description")
		if not definition.get("verbs", null) is Array or (definition.get("verbs", []) as Array).is_empty():
			errors.append(tradition_id + " must define at least one gameplay verb")
		if not definition.get("compatibility_elements", null) is Array:
			errors.append(tradition_id + " compatibility_elements must be an Array")
		if not definition.get("compatibility_tags", null) is Array:
			errors.append(tradition_id + " compatibility_tags must be an Array")
		if not definition.get("compatibility_categories", null) is Array:
			errors.append(tradition_id + " compatibility_categories must be an Array")

		var capstone: Dictionary = get_capstone(tradition_id)
		if str(capstone.get("id", "")).strip_edges() == "":
			errors.append(tradition_id + " has no capstone hook id")
		if str(capstone.get("display_name", "")).strip_edges() == "":
			errors.append(tradition_id + " has no capstone display name")

		for stage_id: String in STAGE_IDS:
			var achievement: Dictionary = get_achievement_definition(tradition_id, stage_id)
			if str(achievement.get("id", "")).strip_edges() == "":
				errors.append(tradition_id + " " + stage_id + " has no achievement id")
			if str(achievement.get("description", "")).strip_edges() == "":
				errors.append(tradition_id + " " + stage_id + " has no achievement description")

	return errors


static func _get_stage_description(tradition_id: String, stage_id: String) -> String:
	var tradition_name: String = get_display_name(tradition_id)
	match stage_id:
		"initiation":
			return "Grace deliberately recognizes " + tradition_name + " as a distinct relationship with magic."
		"practice":
			return "Grace demonstrates " + tradition_name + " through varied, meaningful gameplay contexts."
		"trial":
			return "Grace completes the dedicated " + tradition_name + " trial."
		"mastery":
			return "Grace masters " + tradition_name + " and activates its capstone hook."
		_:
			return "Grace advances her understanding of " + tradition_name + "."