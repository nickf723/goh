extends Resource
class_name LootEntry

@export var item_definition: QuickItemDefinition
@export_range(1, 99, 1) var minimum_quantity: int = 1
@export_range(1, 99, 1) var maximum_quantity: int = 1
@export_range(0.0, 1000.0, 0.05) var weight: float = 1.0
@export_range(0.0, 1.0, 0.01) var drop_chance: float = 1.0
@export var guaranteed: bool = false


func is_valid() -> bool:
	return item_definition != null and item_definition.item_id != "" and maximum_quantity > 0


func roll_quantity(random: RandomNumberGenerator) -> int:
	if random == null:
		return maxi(minimum_quantity, 1)
	var low: int = maxi(minimum_quantity, 1)
	var high: int = maxi(maximum_quantity, low)
	return random.randi_range(low, high)


func get_debug_summary() -> String:
	if item_definition == null:
		return "invalid loot entry"
	var rule: String = "guaranteed" if guaranteed else "weight " + str(snappedf(weight, 0.01))
	return item_definition.display_name + " ×" + str(minimum_quantity) + "-" + str(maximum_quantity) + " • " + rule
