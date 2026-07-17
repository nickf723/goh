extends RefCounted

const TYPE_KEY_ITEM: String = "key_item"
const TYPE_SPELL: String = "spell"
const TYPE_MODIFIER: String = "modifier"
const TYPE_PASSIVE: String = "passive"
const TYPE_PERMISSION: String = "permission"

const UNLOCK_DEFS: Dictionary = {
	"church_trial_sigil": {
		"id": "church_trial_sigil",
		"display_name": "Church Trial Sigil",
		"type": TYPE_KEY_ITEM,
		"menu_category": "Key Items",
		"description": "Proof that Grace survived the Church's first trial and defeated the Animated Armor.",
		"source": "First Church Trial",
		"tags": ["church", "trial", "sigil", "progression"],
		"related_key_item": "church_trial_sigil",
	},
	"church_trial_doors": {
		"id": "church_trial_doors",
		"display_name": "Church Trial Passage",
		"type": TYPE_PERMISSION,
		"menu_category": "World Permissions",
		"description": "Trial exits recognize Grace as a proven challenger while she carries the Church Trial Sigil.",
		"source": "Church Trial Sigil",
		"requires": ["church_trial_sigil"],
		"tags": ["church", "door", "permission"],
	},
	"armor_trial_blessing": {
		"id": "armor_trial_blessing",
		"display_name": "Armor Trial Blessing",
		"type": TYPE_MODIFIER,
		"menu_category": "Blessings",
		"description": "Prototype modifier hook. Later, this can alter beds, damage taken, or stance recovery after boss victories.",
		"source": "Animated Armor Trial",
		"requires": ["church_trial_sigil"],
		"hooks": ["on_sleep", "on_damage_taken", "on_room_enter"],
		"tags": ["blessing", "defense", "bed", "prototype"],
		"effect_preview": "Beds and retry flow can now query this blessing before applying future rest bonuses.",
	},
	"firebolt": {
		"id": "firebolt",
		"display_name": "Firebolt",
		"type": TYPE_SPELL,
		"menu_category": "Spells",
		"description": "A baseline fire projectile. Listed here so spell unlocks can eventually join the same progression ledger.",
		"source": "Starting Spell Pack",
		"tags": ["fire", "projectile", "damage"],
	},
	"blink": {
		"id": "blink",
		"display_name": "Blink",
		"type": TYPE_SPELL,
		"menu_category": "Spells",
		"description": "A baseline space movement spell. Future upgrades can depend on this unlock.",
		"source": "Starting Spell Pack",
		"tags": ["space", "movement", "traversal"],
	},
	"charged_firebolt": {
		"id": "charged_firebolt",
		"display_name": "Charged Firebolt",
		"type": TYPE_MODIFIER,
		"menu_category": "Spell Upgrades",
		"description": "Placeholder upgrade definition: holding Firebolt could charge a stronger projectile.",
		"source": "Future Reward",
		"requires": ["firebolt"],
		"hooks": ["on_cast_start", "on_projectile_spawned", "on_hit"],
		"tags": ["fire", "charge", "projectile", "upgrade"],
		"effect_preview": "Hold Firebolt to charge. Not active until granted by a future reward.",
	},
}


static func has_definition(unlock_id: String) -> bool:
	return UNLOCK_DEFS.has(unlock_id)


static func get_definition(unlock_id: String) -> Dictionary:
	if UNLOCK_DEFS.has(unlock_id):
		return (UNLOCK_DEFS[unlock_id] as Dictionary).duplicate(true)

	return make_unknown_definition(unlock_id)


static func make_unknown_definition(unlock_id: String) -> Dictionary:
	return {
		"id": unlock_id,
		"display_name": unlock_id.capitalize(),
		"type": "unknown",
		"menu_category": "Other Unlocks",
		"description": "An unlock Grace has earned, but the catalog has not described it yet.",
		"source": "Unknown",
		"tags": [],
	}


static func normalize_unlock(unlock_id: String, unlock_data: Dictionary = {}) -> Dictionary:
	var row: Dictionary = get_definition(unlock_id)

	for key in unlock_data.keys():
		row[str(key)] = unlock_data[key]

	row["id"] = unlock_id
	row["unlocked"] = true
	return row


static func get_rows(unlocks: Dictionary) -> Array:
	var rows: Array = []

	for unlock_id in unlocks.keys():
		if unlocks[unlock_id] is Dictionary:
			var row: Dictionary = normalize_unlock(str(unlock_id), unlocks[unlock_id] as Dictionary)
			rows.append(row)
		else:
			rows.append(normalize_unlock(str(unlock_id)))

	rows.sort_custom(sort_unlock_rows)
	return rows


static func get_rows_by_type(unlocks: Dictionary, unlock_type: String) -> Array:
	var rows: Array = []

	for row_variant in get_rows(unlocks):
		if not (row_variant is Dictionary):
			continue

		var row: Dictionary = row_variant as Dictionary
		if str(row.get("type", "")) == unlock_type:
			rows.append(row)

	return rows


static func get_type_counts(unlocks: Dictionary) -> Dictionary:
	var counts: Dictionary = {}

	for row_variant in get_rows(unlocks):
		if not (row_variant is Dictionary):
			continue

		var row: Dictionary = row_variant as Dictionary
		var unlock_type: String = str(row.get("type", "unknown"))
		counts[unlock_type] = int(counts.get(unlock_type, 0)) + 1

	return counts


static func sort_unlock_rows(a: Dictionary, b: Dictionary) -> bool:
	var category_a: String = str(a.get("menu_category", "Other Unlocks"))
	var category_b: String = str(b.get("menu_category", "Other Unlocks"))

	if category_a == category_b:
		return str(a.get("display_name", "")) < str(b.get("display_name", ""))

	return category_a < category_b
