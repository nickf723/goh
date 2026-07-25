extends RefCounted

const INFUSION_IDS: Array[String] = ["fire", "ice", "lightning", "poison"]
const DEFAULT_INFUSION_ID: String = "none"

const DEFINITIONS: Dictionary = {
	"none": {
		"id": "none",
		"name": "Uninfused",
		"icon": "◇",
		"element": "neutral",
		"color": Color(0.86, 0.9, 1.0),
		"description": "Pure physical strikes with no elemental status.",
		"status": "",
		"duration": 0.0,
		"strength": 1.0,
	},
	"fire": {
		"id": "fire",
		"name": "Fire Edge",
		"icon": "🔥",
		"element": "fire",
		"color": Color(1.0, 0.25, 0.06),
		"description": "Ignites targets and feeds combustion reactions.",
		"status": "burning",
		"duration": 3.0,
		"strength": 1.0,
	},
	"ice": {
		"id": "ice",
		"name": "Frost Edge",
		"icon": "❄",
		"element": "ice",
		"color": Color(0.25, 0.82, 1.0),
		"description": "Chills targets and primes freeze or shatter reactions.",
		"status": "chill",
		"duration": 2.6,
		"strength": 0.72,
	},
	"lightning": {
		"id": "lightning",
		"name": "Storm Edge",
		"icon": "⚡",
		"element": "lightning",
		"color": Color(0.72, 0.48, 1.0),
		"description": "Briefly stuns targets and conducts through compatible materials.",
		"status": "stunned",
		"duration": 0.28,
		"strength": 1.0,
	},
	"poison": {
		"id": "poison",
		"name": "Venom Edge",
		"icon": "☠",
		"element": "poison",
		"color": Color(0.42, 0.95, 0.18),
		"description": "Poisons targets with a short damage-over-time effect.",
		"status": "poisoned",
		"duration": 3.2,
		"strength": 1.0,
	},
}


static func is_valid(infusion_id: String) -> bool:
	return DEFINITIONS.has(infusion_id)


static func get_definition(infusion_id: String) -> Dictionary:
	var resolved_id: String = infusion_id if is_valid(infusion_id) else DEFAULT_INFUSION_ID
	return (DEFINITIONS[resolved_id] as Dictionary).duplicate(true)


static func get_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for infusion_id: String in INFUSION_IDS:
		rows.append(get_definition(infusion_id))
	return rows


static func get_display_name(infusion_id: String) -> String:
	return str(get_definition(infusion_id).get("name", "Uninfused"))


static func get_color(infusion_id: String) -> Color:
	return get_definition(infusion_id).get("color", Color.WHITE) as Color


static func apply_to_payload(payload: DamagePayload, infusion_id: String) -> void:
	if payload == null or infusion_id == DEFAULT_INFUSION_ID:
		return
	var definition: Dictionary = get_definition(infusion_id)
	payload.element = str(definition.get("element", "neutral"))
	payload.status_effect = str(definition.get("status", ""))
	payload.status_duration = float(definition.get("duration", 0.0))
	payload.status_strength = float(definition.get("strength", 1.0))
	append_tag(payload.tags, "weapon_infusion")
	append_tag(payload.tags, payload.element)
	append_tag(payload.tags, infusion_id)
	if payload.status_effect != "":
		append_tag(payload.tags, payload.status_effect)


static func append_tag(tags: Array[String], tag: String) -> void:
	if tag != "" and not tags.has(tag):
		tags.append(tag)
