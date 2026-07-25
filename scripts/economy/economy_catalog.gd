extends RefCounted
class_name EconomyCatalog

const ITEM_DEFINITIONS: Dictionary = {
	"healing_flask": {"name": "Healing Flask", "icon": "✚", "buy": 18, "sell": 7, "category": "Supplies", "description": "A reusable field flask restored at beds."},
	"oil_flask": {"name": "Oil Flask", "icon": "◉", "buy": 14, "sell": 6, "category": "Supplies", "description": "Thrown oil that prepares surfaces for Fire."},
	"noise_maker": {"name": "Noise Maker", "icon": "♫", "buy": 12, "sell": 5, "category": "Tools", "description": "A throwable distraction for stealth."},
	"healing_potion": {"name": "Healing Potion", "icon": "♥", "buy": 24, "sell": 10, "category": "Potions", "description": "Restores health and does not replenish at beds."},
	"resonance_tonic": {"name": "Resonance Tonic", "icon": "◌", "buy": 28, "sell": 12, "category": "Potions", "description": "Restores mana through suspended resonance."},
	"frost_vigor_draught": {"name": "Frost Vigor Draught", "icon": "❄", "buy": 28, "sell": 12, "category": "Potions", "description": "Restores stamina with bracing cold."},
	"antidote": {"name": "Clarifying Antidote", "icon": "◇", "buy": 22, "sell": 9, "category": "Potions", "description": "A cleansing alchemical preparation."},
	"conductive_elixir": {"name": "Conductive Elixir", "icon": "ϟ", "buy": 30, "sell": 13, "category": "Potions", "description": "Restores stance with charged metallic salts."},
	"life_bloom": {"name": "Life Bloom", "icon": "✿", "buy": 8, "sell": 3, "category": "Ingredients", "description": "An alchemy ingredient carrying Life and Body traits."},
	"springwater": {"name": "Springwater", "icon": "≈", "buy": 5, "sell": 2, "category": "Ingredients", "description": "A clean Water solvent used in many recipes."},
	"echo_reed": {"name": "Echo Reed", "icon": "◉", "buy": 9, "sell": 4, "category": "Ingredients", "description": "A resonant reed carrying Sound and Air traits."},
	"frost_salt": {"name": "Frost Salt", "icon": "❄", "buy": 10, "sell": 4, "category": "Ingredients", "description": "Cold mineral crystals with Ice and Poison traits."},
	"spark_ore": {"name": "Spark Ore", "icon": "ϟ", "buy": 12, "sell": 5, "category": "Ingredients", "description": "Conductive ore carrying Metal and Lightning traits."},
	"starlit_gem": {"name": "Starlit Gem", "icon": "◆", "buy": 0, "sell": 35, "category": "Valuables", "description": "A rare trade good whose only practical purpose is selling."},
}

const DEFAULT_STOCK: Array[Dictionary] = [
	{"item_id": "healing_potion", "stock": 3},
	{"item_id": "oil_flask", "stock": 4},
	{"item_id": "noise_maker", "stock": 3},
	{"item_id": "life_bloom", "stock": 5},
	{"item_id": "springwater", "stock": 8},
	{"item_id": "echo_reed", "stock": 4},
	{"item_id": "frost_salt", "stock": 4},
	{"item_id": "spark_ore", "stock": 3},
]


static func has_item(item_id: String) -> bool:
	return ITEM_DEFINITIONS.has(item_id)


static func get_item(item_id: String) -> Dictionary:
	if not ITEM_DEFINITIONS.has(item_id):
		return {}
	return (ITEM_DEFINITIONS[item_id] as Dictionary).duplicate(true)


static func get_display_name(item_id: String) -> String:
	return str(get_item(item_id).get("name", item_id.capitalize()))


static func get_buy_price(item_id: String) -> int:
	return maxi(int(get_item(item_id).get("buy", 0)), 0)


static func get_sell_price(item_id: String) -> int:
	return maxi(int(get_item(item_id).get("sell", 0)), 0)


static func get_sellable_rows(inventory: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for item_id_variant: Variant in ITEM_DEFINITIONS.keys():
		var item_id: String = str(item_id_variant)
		var count: int = int(inventory.get(item_id, 0))
		var price: int = get_sell_price(item_id)
		if count <= 0 or price <= 0:
			continue
		var row: Dictionary = get_item(item_id)
		row["item_id"] = item_id
		row["count"] = count
		row["price"] = price
		rows.append(row)
	rows.sort_custom(sort_rows)
	return rows


static func sort_rows(a: Dictionary, b: Dictionary) -> bool:
	var category_compare: String = str(a.get("category", "")) + str(a.get("name", ""))
	var other_compare: String = str(b.get("category", "")) + str(b.get("name", ""))
	return category_compare < other_compare
