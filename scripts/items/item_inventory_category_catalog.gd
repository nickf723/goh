extends RefCounted
class_name ItemInventoryCategoryCatalog

const CATEGORY_ORDER: Array[String] = [
	"materials",
	"food",
	"potions",
	"valuables",
	"objects",
	"builds",
	"relics",
]

const CATEGORIES: Dictionary = {
	"materials": {
		"id": "materials",
		"title": "Materials / Ingredients",
		"short_title": "Materials",
		"icon": "✣",
		"description": "Raw substances, reagents, monster parts, plants, ores, and ingredients consumed by crafting or alchemy.",
		"mechanic": "Crafting and alchemy inputs",
	},
	"food": {
		"id": "food",
		"title": "Food",
		"short_title": "Food",
		"icon": "♨",
		"description": "Meals and edible ingredients that restore resources or grant temporary nourishment effects.",
		"mechanic": "Cooking, nourishment, and temporary buffs",
	},
	"potions": {
		"id": "potions",
		"title": "Potions",
		"short_title": "Potions",
		"icon": "⚗",
		"description": "Flasks, tonics, draughts, elixirs, antidotes, and other prepared consumable mixtures.",
		"mechanic": "Immediate and timed consumable effects",
	},
	"valuables": {
		"id": "valuables",
		"title": "Valuables",
		"short_title": "Valuables",
		"icon": "◆",
		"description": "Currency, gems, trade goods, collectible metals, and other objects whose primary use is exchange or wealth.",
		"mechanic": "Currency, trade, appraisal, and collection",
	},
	"objects": {
		"id": "objects",
		"title": "Objects",
		"short_title": "Objects",
		"icon": "▣",
		"description": "Recorded physical objects Grace can reproduce or summon into the world as reusable puzzle and combat tools.",
		"mechanic": "Echo-style object summoning",
	},
	"builds": {
		"id": "builds",
		"title": "Builds",
		"short_title": "Builds",
		"icon": "⚙",
		"description": "Saved contraptions assembled from parts, devices, joints, vehicles, and magical engineering components.",
		"mechanic": "Engineering blueprints and reusable constructions",
	},
	"relics": {
		"id": "relics",
		"title": "Relics / Key Items",
		"short_title": "Relics",
		"icon": "🔑",
		"description": "Story relics, dungeon proofs, blessings, permissions, and unique objects that change what Grace or the world can do.",
		"mechanic": "Persistent progression and world permissions",
	},
}

const EXPLICIT_ITEM_CATEGORIES: Dictionary = {
	"oil_flask": "materials",
	"noise_maker": "objects",
	"healing_flask": "potions",
	"healing_potion": "potions",
	"resonance_tonic": "potions",
	"frost_vigor_draught": "potions",
	"antidote": "potions",
	"conductive_elixir": "potions",
	"swift_tonic": "potions",
	"arcane_draught": "potions",
	"ironbark_brew": "potions",
}


static func has_category(category_id: String) -> bool:
	return CATEGORIES.has(category_id)


static func get_definition(category_id: String) -> Dictionary:
	if not has_category(category_id):
		return {}
	return (CATEGORIES[category_id] as Dictionary).duplicate(true)


static func get_definitions() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for category_id: String in CATEGORY_ORDER:
		rows.append(get_definition(category_id))
	return rows


static func classify_inventory_row(row: Dictionary) -> String:
	var authored: String = str(row.get("inventory_category", "")).strip_edges().to_lower()
	if has_category(authored) and authored != "relics":
		return authored

	var item_id: String = str(row.get("id", "")).strip_edges().to_lower()
	if EXPLICIT_ITEM_CATEGORIES.has(item_id):
		return str(EXPLICIT_ITEM_CATEGORIES[item_id])

	var tags: Array[String] = _string_array(row.get("tags", []))
	for tag: String in tags:
		match tag:
			"food", "meal", "cooking", "edible", "ingredient_food":
				return "food"
			"potion", "tonic", "draught", "elixir", "antidote", "brew", "flask":
				return "potions"
			"valuable", "currency", "gem", "gold", "trade_good", "treasure":
				return "valuables"
			"echo", "object_blueprint", "summonable_object", "deployable_object":
				return "objects"
			"build", "contraption", "vehicle_blueprint", "engineering_blueprint":
				return "builds"
			"material", "ingredient", "reagent", "ore", "monster_part", "plant":
				return "materials"

	var effect: String = str(row.get("effect", "")).to_lower()
	if effect in ["heal", "cleanse", "buff", "restore", "status_cure"]:
		return "potions"
	return "materials"


static func get_rows_for_category(
	inventory_rows: Array,
	category_id: String
) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if category_id == "relics":
		return rows
	for value: Variant in inventory_rows:
		if not value is Dictionary:
			continue
		var row: Dictionary = value as Dictionary
		if classify_inventory_row(row) == category_id:
			rows.append(row.duplicate(true))
	return rows


static func validate_catalog() -> Array[String]:
	var failures: Array[String] = []
	if CATEGORY_ORDER.size() != 7:
		failures.append("item inventory must define seven categories")
	var seen: Dictionary = {}
	for category_id: String in CATEGORY_ORDER:
		if seen.has(category_id):
			failures.append("duplicate item category: " + category_id)
		seen[category_id] = true
		var row: Dictionary = get_definition(category_id)
		if row.is_empty():
			failures.append("missing item category: " + category_id)
			continue
		if str(row.get("title", "")).strip_edges() == "":
			failures.append(category_id + " has no title")
		if str(row.get("description", "")).strip_edges() == "":
			failures.append(category_id + " has no description")
	return failures


static func _string_array(value: Variant) -> Array[String]:
	var rows: Array[String] = []
	if value is Array:
		for entry: Variant in value as Array:
			rows.append(str(entry).to_lower())
	return rows
