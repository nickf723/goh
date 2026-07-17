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
		"description": "After Grace sleeps at a save bed, she gains Guard. Guard absorbs the next incoming hit before health is damaged.",
		"source": "Animated Armor Trial",
		"requires": ["church_trial_sigil"],
		"hooks": ["on_sleep", "on_damage_taken", "on_room_enter"],
		"tags": ["blessing", "defense", "bed", "prototype"],
		"effect_preview": "Sleep at a save bed to gain 1 Guard. The next hit consumes Guard instead of health.",
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
		"description": "Hold Firebolt, then release to launch a stronger projectile. Quick taps still cast a normal Firebolt.",
		"source": "Church Trial Sigil",
		"requires": ["firebolt"],
		"hooks": ["on_cast_start", "on_cast_release", "on_projectile_spawned", "on_hit"],
		"tags": ["fire", "charge", "projectile", "upgrade", "controller"],
		"effect_preview": "Hold the cast action on keyboard or controller to charge Firebolt. Release to fire.",
	},
	"piercing_ice_lance": {
		"id": "piercing_ice_lance",
		"display_name": "Piercing Ice Lance",
		"type": TYPE_MODIFIER,
		"menu_category": "Spell Upgrades",
		"description": "Ice Lance becomes a faster piercing projectile that can pass through several targets in a line.",
		"source": "Prototype Upgrade Lab",
		"requires": ["ice_lance"],
		"hooks": ["on_cast", "on_projectile_spawned", "on_hit"],
		"tags": ["ice", "projectile", "piercing", "upgrade", "control"],
		"effect_preview": "Cast Ice Lance after unlocking this upgrade. The lance can pierce multiple targets before fading.",
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
