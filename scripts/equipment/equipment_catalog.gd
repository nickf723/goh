extends RefCounted
class_name EquipmentCatalog

const EffectCatalogScript = preload("res://scripts/effects/gameplay_effect_catalog.gd")

const SLOT_WEAPON: String = "weapon"
const SLOT_OUTFIT: String = "outfit"
const SLOT_CHARM: String = "charm"
const SLOT_RELIC: String = "relic"
const SLOT_ORDER: Array[String] = [SLOT_WEAPON, SLOT_OUTFIT, SLOT_CHARM, SLOT_RELIC]

const DEFINITIONS: Dictionary = {
	"practice_sword": {
		"id": "practice_sword", "name": "Practice Sword", "slot": SLOT_WEAPON, "icon": "⚔",
		"description": "A balanced sword with flexible Light and Heavy branches.",
		"weapon_path": "res://data/weapons/practice_sword.tres", "buy": 0, "sell": 0, "modifiers": {},
	},
	"training_hammer": {
		"id": "training_hammer", "name": "Training Hammer", "slot": SLOT_WEAPON, "icon": "◆",
		"description": "A committed hammer with broad force and high stance pressure.",
		"weapon_path": "res://data/weapons/training_hammer.tres", "buy": 55, "sell": 24, "modifiers": {"power": 1},
	},
	"training_spear": {
		"id": "training_spear", "name": "Training Spear", "slot": SLOT_WEAPON, "icon": "↟",
		"description": "A fast spear with long, narrow advancing thrusts.",
		"weapon_path": "res://data/weapons/training_spear.tres", "buy": 52, "sell": 23, "modifiers": {"dexterity": 1},
	},
	"travelers_coat": {
		"id": "travelers_coat", "name": "Traveler's Coat", "slot": SLOT_OUTFIT, "icon": "♧",
		"description": "A practical coat that leaves Grace room to run and climb.",
		"buy": 34, "sell": 15, "modifiers": {"max_stamina": 2}, "effects": ["wayfarer_stride"],
	},
	"apprentice_robe": {
		"id": "apprentice_robe", "name": "Apprentice Robe", "slot": SLOT_OUTFIT, "icon": "✦",
		"description": "Layered magical cloth that supports sustained spellcasting.",
		"buy": 38, "sell": 17, "modifiers": {"max_mana": 2}, "effects": ["apprentice_flow"],
	},
	"ironweave_jacket": {
		"id": "ironweave_jacket", "name": "Ironweave Jacket", "slot": SLOT_OUTFIT, "icon": "▧",
		"description": "Metal-threaded clothing that helps Grace hold her ground.",
		"buy": 42, "sell": 19, "modifiers": {"max_stance": 2}, "effects": ["ironweave_guard"],
	},
	"vital_knot": {
		"id": "vital_knot", "name": "Vital Knot", "slot": SLOT_CHARM, "icon": "♥",
		"description": "A woven charm that reinforces Grace's living energy.",
		"buy": 30, "sell": 13, "modifiers": {"max_health": 2}, "effects": ["vital_restoration"],
	},
	"resonance_charm": {
		"id": "resonance_charm", "name": "Resonance Charm", "slot": SLOT_CHARM, "icon": "◉",
		"description": "A humming charm that steadies attention during Focus.",
		"buy": 36, "sell": 16, "modifiers": {"focus": 1}, "effects": ["resonant_focus"],
	},
	"merchants_token": {
		"id": "merchants_token", "name": "Merchant's Token", "slot": SLOT_RELIC, "icon": "◇",
		"description": "A respected trade token that strengthens social presence.",
		"buy": 44, "sell": 20, "modifiers": {"charisma": 1}, "effects": ["merchant_rapport"],
	},
	"lucky_shard": {
		"id": "lucky_shard", "name": "Lucky Shard", "slot": SLOT_RELIC, "icon": "✧",
		"description": "A polished fragment carried by travelers courting fortune.",
		"buy": 48, "sell": 22, "modifiers": {"luck": 1}, "effects": ["fortunes_favor"],
	},
}


static func has_item(item_id: String) -> bool:
	return DEFINITIONS.has(item_id)


static func get_definition(item_id: String) -> Dictionary:
	if not DEFINITIONS.has(item_id):
		return {}
	return (DEFINITIONS[item_id] as Dictionary).duplicate(true)


static func get_display_name(item_id: String) -> String:
	return str(get_definition(item_id).get("name", item_id.capitalize()))


static func get_slot(item_id: String) -> String:
	return str(get_definition(item_id).get("slot", ""))


static func get_modifiers(item_id: String) -> Dictionary:
	return (get_definition(item_id).get("modifiers", {}) as Dictionary).duplicate(true)


static func get_effect_ids(item_id: String) -> Array[String]:
	var effect_ids: Array[String] = []
	var values: Array = get_definition(item_id).get("effects", []) as Array
	for value: Variant in values:
		effect_ids.append(str(value))
	return effect_ids


static func get_weapon(item_id: String) -> WeaponDefinition:
	var path: String = str(get_definition(item_id).get("weapon_path", ""))
	if path == "":
		return null
	var resource: Resource = load(path)
	if resource is WeaponDefinition:
		return resource as WeaponDefinition
	return null


static func get_all_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for item_id_variant: Variant in DEFINITIONS.keys():
		var row: Dictionary = get_definition(str(item_id_variant))
		rows.append(row)
	rows.sort_custom(sort_rows)
	return rows


static func get_rows_for_slot(slot_id: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for row: Dictionary in get_all_rows():
		if str(row.get("slot", "")) == slot_id:
			rows.append(row)
	return rows


static func format_effects(item_id: String, include_descriptions: bool = false) -> String:
	var parts: Array[String] = []
	for effect_id: String in get_effect_ids(item_id):
		var label: String = EffectCatalogScript.get_display_name(effect_id)
		if include_descriptions:
			var description: String = EffectCatalogScript.get_description(effect_id)
			if description != "":
				label += " — " + description
		parts.append(label)
	return "  •  ".join(parts)


static func format_modifiers(modifiers: Dictionary) -> String:
	var parts: Array[String] = []
	for stat_variant: Variant in modifiers.keys():
		var stat_id: String = str(stat_variant)
		var amount: int = int(modifiers[stat_variant])
		parts.append(("+" if amount >= 0 else "") + str(amount) + " " + stat_id.replace("max_", "Max ").capitalize())
	return "  •  ".join(parts) if not parts.is_empty() else "No stat modifier"


static func sort_rows(a: Dictionary, b: Dictionary) -> bool:
	var a_slot: int = SLOT_ORDER.find(str(a.get("slot", "")))
	var b_slot: int = SLOT_ORDER.find(str(b.get("slot", "")))
	if a_slot == b_slot:
		return str(a.get("name", "")) < str(b.get("name", ""))
	return a_slot < b_slot
