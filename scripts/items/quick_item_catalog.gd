extends RefCounted
class_name QuickItemCatalog

const HealingFlask: QuickItemDefinition = preload("res://data/items/healing_flask.tres")
const OilFlask: QuickItemDefinition = preload("res://data/items/oil_flask.tres")
const NoiseMaker: QuickItemDefinition = preload("res://data/items/noise_maker.tres")

const ITEM_IDS: Array[String] = [
	"healing_flask",
	"oil_flask",
	"noise_maker",
]


static func get_item(item_id: String) -> QuickItemDefinition:
	match item_id:
		"healing_flask":
			return HealingFlask
		"oil_flask":
			return OilFlask
		"noise_maker":
			return NoiseMaker
		_:
			return null


static func get_all_items() -> Array[QuickItemDefinition]:
	return [HealingFlask, OilFlask, NoiseMaker]


static func get_inventory_rows(inventory: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for item_id: String in ITEM_IDS:
		var item := get_item(item_id)
		if item == null:
			continue
		var count: int = int(inventory.get(item_id, 0))
		if count <= 0 and not inventory.has(item_id):
			continue
		rows.append({
			"id": item.item_id,
			"name": item.display_name,
			"short_label": item.short_label,
			"description": item.description,
			"icon": item.icon_symbol,
			"count": count,
			"maximum": item.get_max_stack(),
			"refill_on_rest": item.refill_on_rest,
			"effect": item.effect_type,
			"element": item.element,
			"tags": item.tags.duplicate(),
		})
	return rows
