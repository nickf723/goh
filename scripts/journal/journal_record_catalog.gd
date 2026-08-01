extends RefCounted
class_name JournalRecordCatalog

const AlchemyCauldronScript = preload(
	"res://scripts/alchemy/alchemy_cauldron.gd"
)
const ItemCategoryCatalogScript = preload(
	"res://scripts/items/item_inventory_category_catalog.gd"
)

const CATEGORY_ORDER: Array[String] = [
	"recipes",
	"potions",
	"crafts",
	"blueprints",
	"fauna",
	"flora",
	"notes",
]

const CATEGORIES: Dictionary = {
	"recipes": {
		"id": "recipes",
		"title": "Recipes",
		"icon": "♨",
		"description": "Learned meals, preparation methods, regional dishes, and food effects.",
		"empty": "Cooking recipes will appear after Grace learns them from people, books, travel, or experimentation.",
	},
	"potions": {
		"id": "potions",
		"title": "Potions",
		"icon": "⚗",
		"description": "Alchemy formulas record ingredients, elemental treatment, output, and discovered effects.",
		"empty": "Experiment at an alchemy cauldron to discover potion formulas.",
	},
	"crafts": {
		"id": "crafts",
		"title": "Crafts",
		"icon": "✂",
		"description": "Handmade tools, consumables, upgrades, ammunition, and repair procedures.",
		"empty": "Crafting instructions will appear when Grace learns a practical recipe.",
	},
	"blueprints": {
		"id": "blueprints",
		"title": "Blueprints",
		"icon": "⌘",
		"description": "Recorded summonable objects and saved engineering constructions live here as reproducible designs.",
		"empty": "Study an object or save a construction to create its blueprint record.",
	},
	"fauna": {
		"id": "fauna",
		"title": "Fauna",
		"icon": "🐾",
		"description": "Animals, monsters, familiars, and other living creatures accumulate observations and mastery ranks.",
		"empty": "Observe a creature in the field to begin its record.",
	},
	"flora": {
		"id": "flora",
		"title": "Flora",
		"icon": "❧",
		"description": "Plants, fungi, magical growths, habitats, harvest traits, and alchemical uses.",
		"empty": "Discover or collect a plant to begin its botanical record.",
	},
	"notes": {
		"id": "notes",
		"title": "Field Notes",
		"icon": "✎",
		"description": "Objectives, clues, people, places, experiments, and other knowledge that needs a durable log.",
		"empty": "Grace has not recorded any field notes yet.",
	},
}

const FLORA_RECORDS: Array[Dictionary] = [
	{
		"id": "life_bloom",
		"name": "Life Bloom",
		"icon": "✿",
		"summary": "A vivid medicinal flower carrying strong Life and Body traits.",
		"habitat": "Warm, fertile ground with abundant living energy.",
		"uses": "Healing mixtures, vigor preparations, and future growth recipes.",
	},
	{
		"id": "echo_reed",
		"name": "Echo Reed",
		"icon": "♪",
		"summary": "A resonant wetland reed whose hollow stem preserves Sound and Air vibrations.",
		"habitat": "Shallow water, caves, and windy riverbanks.",
		"uses": "Resonance tonics, acoustic devices, and signal-making crafts.",
	},
]


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


static func get_cooking_rows() -> Array[Dictionary]:
	# Cooking has its own shelf now, but no authored cooking system exists yet.
	return []


static func get_craft_rows() -> Array[Dictionary]:
	# Crafting records will be supplied by the future recipe service.
	return []


static func get_potion_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for key_value: Variant in AlchemyCauldronScript.RECIPES.keys():
		var ingredient_key: String = str(key_value)
		var recipe: Dictionary = (
			AlchemyCauldronScript.RECIPES[key_value] as Dictionary
		)
		var recipe_id: String = str(recipe.get("id", ""))
		var ingredients: Array[String] = []
		for ingredient_id: String in ingredient_key.split("|", false):
			ingredients.append(_get_ingredient_name(ingredient_id))
		var discovered: bool = GameState.get_flag(
			"recipe_discovered_" + recipe_id
		)
		rows.append({
			"id": recipe_id,
			"name": str(recipe.get("name", recipe_id.capitalize())),
			"icon": "⚗",
			"summary": str(recipe.get("description", "Alchemy formula.")),
			"learned": discovered,
			"status": "DISCOVERED" if discovered else "UNDISCOVERED",
			"source": "Experiment at an alchemy cauldron.",
			"details": [
				"Ingredients: " + " + ".join(ingredients),
				"Treatment: " + str(recipe.get("catalyst", "none")).capitalize(),
				"Produces: " + str(recipe.get("output", recipe_id)).replace("_", " ").capitalize(),
			],
		})
	rows.sort_custom(_sort_records)
	return rows


static func get_blueprint_rows(inventory_rows: Array) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for value: Variant in inventory_rows:
		if not value is Dictionary:
			continue
		var item: Dictionary = value as Dictionary
		var category_id: String = ItemCategoryCatalogScript.classify_inventory_row(
			item
		)
		if category_id not in ["objects", "builds"]:
			continue
		var count: int = int(item.get("count", 0))
		rows.append({
			"id": str(item.get("id", "blueprint")),
			"name": str(item.get("name", "Blueprint")),
			"icon": str(item.get("icon", "⌘")),
			"summary": str(item.get("description", "Recorded reproducible design.")),
			"learned": count > 0,
			"status": "RECORDED" if count > 0 else "UNKNOWN",
			"source": (
				"Recorded from a carried object."
				if category_id == "objects"
				else "Saved from an engineered construction."
			),
			"details": [
				"Blueprint family: " + category_id.capitalize(),
				"Physical copies owned: " + str(count),
			],
		})
	return rows


static func get_flora_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for definition: Dictionary in FLORA_RECORDS:
		var flora_id: String = str(definition.get("id", ""))
		var owned: int = GameState.get_inventory_count(flora_id)
		var observed: bool = owned > 0 or GameState.get_flag(
			"flora_observed_" + flora_id
		)
		rows.append({
			"id": flora_id,
			"name": str(definition.get("name", flora_id.capitalize())),
			"icon": str(definition.get("icon", "❧")),
			"summary": str(definition.get("summary", "Botanical record.")),
			"learned": observed,
			"status": "OBSERVED" if observed else "UNOBSERVED",
			"source": "Collect or study this plant in its habitat.",
			"details": [
				"Habitat: " + str(definition.get("habitat", "Unknown")),
				"Known uses: " + str(definition.get("uses", "Unknown")),
				"Carried samples: " + str(owned),
			],
		})
	return rows


static func validate_catalog() -> Array[String]:
	var failures: Array[String] = []
	if CATEGORY_ORDER.size() != 7:
		failures.append("journal must define seven record shelves")
	var seen: Dictionary = {}
	for category_id: String in CATEGORY_ORDER:
		if seen.has(category_id):
			failures.append("duplicate journal category: " + category_id)
		seen[category_id] = true
		var row: Dictionary = get_definition(category_id)
		if row.is_empty():
			failures.append("missing journal category: " + category_id)
		elif str(row.get("title", "")).strip_edges() == "":
			failures.append(category_id + " has no title")
	if get_potion_rows().size() != 5:
		failures.append("journal potion shelf must expose five authored formulas")
	if FLORA_RECORDS.size() < 2:
		failures.append("journal flora shelf needs starter records")
	return failures


static func _get_ingredient_name(ingredient_id: String) -> String:
	for ingredient: Dictionary in AlchemyCauldronScript.INGREDIENTS:
		if str(ingredient.get("id", "")) == ingredient_id:
			return str(ingredient.get("name", ingredient_id.capitalize()))
	return ingredient_id.replace("_", " ").capitalize()


static func _sort_records(left: Dictionary, right: Dictionary) -> bool:
	return str(left.get("name", "")) < str(right.get("name", ""))
