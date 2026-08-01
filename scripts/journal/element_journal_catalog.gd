extends RefCounted
class_name ElementJournalCatalog

const ComboRuleRegistryScript = preload(
	"res://scripts/systems/combo_rule_registry.gd"
)

const ELEMENT_ORDER: Array[String] = [
	"water", "earth", "fire", "air",
	"ice", "metal", "lightning", "poison",
	"life", "death", "body", "soul",
	"dreams", "sound", "space", "time",
]

const FAMILIES: Dictionary = {
	"natural": ["water", "earth", "fire", "air"],
	"primal": ["ice", "metal", "lightning", "poison"],
	"vital": ["life", "death", "body", "soul"],
	"mystical": ["dreams", "sound", "space", "time"],
}

const DEFINITIONS: Dictionary = {
	"water": {"icon": "≈", "hue": "Azure", "family": "Natural", "verbs": ["flow", "push", "cleanse", "soak", "conduct"], "properties": ["Wet", "fluid", "cleansing", "conductive setup"]},
	"earth": {"icon": "◆", "hue": "Green", "family": "Natural", "verbs": ["raise", "shape", "anchor", "grow", "crush"], "properties": ["terrain", "weight", "cover", "growth substrate"]},
	"fire": {"icon": "▲", "hue": "Scarlet", "family": "Natural", "verbs": ["burn", "ignite", "melt", "explode", "spread"], "properties": ["Burning", "heat", "combustion", "area denial"]},
	"air": {"icon": "≋", "hue": "Pink", "family": "Natural", "verbs": ["push", "lift", "scatter", "fan", "carry"], "properties": ["force", "airborne", "spread", "projectile steering"]},
	"ice": {"icon": "❄", "hue": "Turquoise", "family": "Primal", "verbs": ["freeze", "slow", "preserve", "bridge", "shatter"], "properties": ["Frozen", "slowing", "brittle", "terrain creation"]},
	"metal": {"icon": "⬡", "hue": "Yellow", "family": "Primal", "verbs": ["forge", "pull", "conduct", "armor", "assemble"], "properties": ["conductive", "magnetic", "structural", "mechanical"]},
	"lightning": {"icon": "ϟ", "hue": "Indigo", "family": "Primal", "verbs": ["shock", "chain", "charge", "interrupt", "accelerate"], "properties": ["electrical", "chain hit", "interrupt", "Wet payoff"]},
	"poison": {"icon": "☣", "hue": "Chartreuse", "family": "Primal", "verbs": ["infect", "corrode", "cloud", "adapt", "weaken"], "properties": ["Toxic", "damage over time", "gas", "exposure"]},
	"life": {"icon": "✿", "hue": "Verdant", "family": "Vital", "verbs": ["heal", "grow", "restore", "multiply", "awaken"], "properties": ["healing", "growth", "regeneration", "ecosystem"]},
	"death": {"icon": "†", "hue": "Red", "family": "Vital", "verbs": ["decay", "end", "reanimate", "harvest", "silence"], "properties": ["decay", "remains", "ending", "necromancy"]},
	"body": {"icon": "✊", "hue": "Magenta", "family": "Vital", "verbs": ["strengthen", "reshape", "adapt", "sense", "endure"], "properties": ["physical alteration", "strength", "instinct", "resistance"]},
	"soul": {"icon": "◎", "hue": "Cyan", "family": "Vital", "verbs": ["bind", "summon", "command", "possess", "remember"], "properties": ["identity", "spirit", "familiar", "will"]},
	"dreams": {"icon": "☾", "hue": "Blue", "family": "Mystical", "verbs": ["sleep", "conceal", "imagine", "distort", "reveal"], "properties": ["illusion", "sleep", "memory", "perception"]},
	"sound": {"icon": "♫", "hue": "Orange", "family": "Mystical", "verbs": ["resonate", "echo", "stun", "reveal", "amplify"], "properties": ["resonance", "wave", "detection", "rhythm"]},
	"space": {"icon": "✦", "hue": "Violet", "family": "Mystical", "verbs": ["warp", "pull", "separate", "fold", "contain"], "properties": ["teleportation", "distance", "gravity", "portal"]},
	"time": {"icon": "◷", "hue": "Amber", "family": "Mystical", "verbs": ["slow", "accelerate", "delay", "repeat", "age"], "properties": ["duration", "sequence", "cooldown", "temporal state"]},
}

const REACTION_AFFINITIES: Dictionary = {
	"water": ["water", "wet", "steam", "cloud", "conductive"],
	"earth": ["earth", "grounded", "terrain", "stone"],
	"fire": ["fire", "burning", "ignite", "flame", "steam", "oily"],
	"air": ["air", "wind", "gust", "cloud", "spread", "fanned"],
	"ice": ["ice", "frozen", "freeze", "shatter", "brittle"],
	"metal": ["metal", "conductive", "armor"],
	"lightning": ["lightning", "electric", "conductive", "shock"],
	"poison": ["poison", "toxic", "gas", "cloud", "corrode"],
	"life": ["life", "growth", "healing"],
	"death": ["death", "decay", "remains"],
	"body": ["body", "physical", "flesh"],
	"soul": ["soul", "spirit", "summon"],
	"dreams": ["dream", "sleep", "illusion"],
	"sound": ["sound", "resonance", "echo"],
	"space": ["space", "gravity", "portal", "warp"],
	"time": ["time", "temporal", "delay", "slow"],
}


static func get_definition(element_id: String) -> Dictionary:
	if not DEFINITIONS.has(element_id):
		return {}
	var row: Dictionary = (DEFINITIONS[element_id] as Dictionary).duplicate(true)
	row["id"] = element_id
	row["name"] = element_id.capitalize()
	return row


static func get_rows(learned_spell_sections: Array = []) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var spell_map: Dictionary = _make_spell_map(learned_spell_sections)
	var reaction_rows: Array[Dictionary] = ComboRuleRegistryScript.get_debug_matrix_rows()
	for element_id: String in ELEMENT_ORDER:
		var definition: Dictionary = get_definition(element_id)
		var spells: Array[Dictionary] = _dictionary_array(spell_map.get(element_id, []))
		var reactions: Array[String] = _get_reaction_lines(element_id, reaction_rows)
		var attack_properties: Array[String] = _collect_spell_properties(spells)
		var spell_names: Array[String] = []
		for spell: Dictionary in spells:
			spell_names.append(str(spell.get("name", spell.get("display_name", "Spell"))))
		var details: Array[String] = [
			"Family: " + str(definition.get("family", "Element")),
			"Hue: " + str(definition.get("hue", element_id.capitalize())),
			"Verbs: " + ", ".join(_string_array(definition.get("verbs", []))),
			"Core properties: " + ", ".join(_string_array(definition.get("properties", []))),
		]
		if spell_names.is_empty():
			details.append("Learned attacks: none recorded")
		else:
			details.append("Learned attacks: " + ", ".join(spell_names))
		if not attack_properties.is_empty():
			details.append("Attack properties: " + ", ".join(attack_properties))
		if reactions.is_empty():
			details.append("Authored reactions: none yet")
		else:
			for reaction_line: String in reactions:
				details.append("Reaction: " + reaction_line)
		rows.append({
			"id": element_id,
			"name": str(definition.get("name", element_id.capitalize())),
			"icon": str(definition.get("icon", "◇")),
			"summary": _make_summary(definition, spells.size(), reactions.size()),
			"learned": true,
			"status": str(definition.get("family", "Element")).to_upper(),
			"source": "Learn spells and reproduce elemental reactions to deepen this record.",
			"details": details,
			"family": str(definition.get("family", "")),
			"hue": str(definition.get("hue", "")),
			"verbs": _string_array(definition.get("verbs", [])),
			"properties": _string_array(definition.get("properties", [])),
			"spell_count": spells.size(),
			"spell_names": spell_names,
			"reaction_count": reactions.size(),
			"reaction_lines": reactions,
		})
	return rows


static func get_reaction_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for raw: Dictionary in ComboRuleRegistryScript.get_debug_matrix_rows():
		var incoming: Array[String] = _string_array(raw.get("incoming", []))
		var target_tags: Array[String] = _string_array(raw.get("target_tags", []))
		var target_statuses: Array[String] = _string_array(raw.get("target_statuses", []))
		var setup_parts: Array[String] = []
		setup_parts.append_array(incoming)
		setup_parts.append_array(target_tags)
		setup_parts.append_array(target_statuses)
		rows.append({
			"id": str(raw.get("rule", "reaction")),
			"name": _pretty(str(raw.get("reaction", "reaction"))),
			"setup": " + ".join(_pretty_array(setup_parts)),
			"result": _pretty(str(raw.get("reaction", "reaction"))),
			"incoming": incoming,
			"target_tags": target_tags,
			"target_statuses": target_statuses,
			"area_radius": float(raw.get("area_radius", 0.0)),
			"priority": int(raw.get("priority", 0)),
		})
	return rows


static func validate_catalog() -> Array[String]:
	var failures: Array[String] = []
	if ELEMENT_ORDER.size() != 16:
		failures.append("element journal must define sixteen elements")
	for element_id: String in ELEMENT_ORDER:
		var row: Dictionary = get_definition(element_id)
		if row.is_empty():
			failures.append("missing element journal definition: " + element_id)
		elif _string_array(row.get("verbs", [])).is_empty():
			failures.append(element_id + " has no gameplay verbs")
	if get_reaction_rows().size() != ComboRuleRegistryScript.get_rules().size():
		failures.append("reaction journal does not match authored combo rules")
	return failures


static func _make_spell_map(sections: Array) -> Dictionary:
	var result: Dictionary = {}
	for raw: Variant in sections:
		if not raw is Dictionary:
			continue
		var section: Dictionary = raw as Dictionary
		var element_id: String = str(section.get("element", ""))
		result[element_id] = _dictionary_array(section.get("spells", []))
	return result


static func _collect_spell_properties(spells: Array[Dictionary]) -> Array[String]:
	var values: Array[String] = []
	for spell: Dictionary in spells:
		for key: String in ["delivery", "delivery_type", "targeting", "targeting_style", "category", "role"]:
			var text: String = str(spell.get(key, "")).strip_edges()
			if text != "":
				_add_unique(values, _pretty(text))
		for tag: String in _string_array(spell.get("tags", [])):
			_add_unique(values, _pretty(tag))
	return values.slice(0, mini(values.size(), 8))


static func _get_reaction_lines(element_id: String, reaction_rows: Array[Dictionary]) -> Array[String]:
	var lines: Array[String] = []
	var affinities: Array[String] = _string_array(REACTION_AFFINITIES.get(element_id, []))
	for raw: Dictionary in reaction_rows:
		var tokens: Array[String] = []
		tokens.append_array(_string_array(raw.get("incoming", [])))
		tokens.append_array(_string_array(raw.get("target_tags", [])))
		tokens.append_array(_string_array(raw.get("target_statuses", [])))
		var relevant: bool = false
		for token: String in tokens:
			for affinity: String in affinities:
				if token.contains(affinity) or affinity.contains(token):
					relevant = true
					break
			if relevant:
				break
		if not relevant:
			continue
		var setup: Array[String] = _pretty_array(tokens)
		var result: String = _pretty(str(raw.get("reaction", "reaction")))
		lines.append(" + ".join(setup) + " → " + result)
	return lines


static func _make_summary(definition: Dictionary, spell_count: int, reaction_count: int) -> String:
	return (
		str(definition.get("family", "Element"))
		+ " element shaped through "
		+ ", ".join(_string_array(definition.get("verbs", [])).slice(0, 3))
		+ ". "
		+ str(spell_count)
		+ " learned attacks and "
		+ str(reaction_count)
		+ " authored reactions recorded."
	)


static func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if value is Array:
		for raw: Variant in value as Array:
			if raw is Dictionary:
				rows.append((raw as Dictionary).duplicate(true))
	return rows


static func _string_array(value: Variant) -> Array[String]:
	var rows: Array[String] = []
	if value is Array:
		for raw: Variant in value as Array:
			var text: String = str(raw).strip_edges().to_lower()
			if text != "":
				rows.append(text)
	return rows


static func _pretty_array(values: Array[String]) -> Array[String]:
	var rows: Array[String] = []
	for value: String in values:
		var pretty: String = _pretty(value)
		if pretty != "" and not rows.has(pretty):
			rows.append(pretty)
	return rows


static func _pretty(value: String) -> String:
	return value.replace("_", " ").strip_edges().capitalize()


static func _add_unique(values: Array[String], value: String) -> void:
	if value != "" and not values.has(value):
		values.append(value)
