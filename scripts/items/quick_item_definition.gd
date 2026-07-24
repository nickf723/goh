extends Resource
class_name QuickItemDefinition

@export var item_id: String = "quick_item"
@export var display_name: String = "Quick Item"
@export var short_label: String = "ITEM"
@export_multiline var description: String = "A reusable quick-slot item."

@export_group("Charges")
@export_range(0, 99, 1) var max_charges: int = 1
@export var refill_on_rest: bool = true

@export_group("Use Commitment")
@export_range(0.05, 5.0, 0.05) var use_duration: float = 0.8
@export_range(0.0, 1.0, 0.05) var movement_multiplier: float = 0.35
@export var requires_grounded: bool = true
@export var can_use_at_maximum: bool = false

@export_group("Resource Effect")
@export_enum("health", "mana", "stamina", "stance") var restore_resource_id: String = "health"
@export_range(0, 99, 1) var restore_amount: int = 1

@export_group("Identity")
@export var element: String = "neutral"
@export var tags: Array[String] = ["consumable", "quick_item"]


func get_max_charges() -> int:
	return maxi(max_charges, 0)


func get_use_duration() -> float:
	return maxf(use_duration, 0.05)


func get_movement_multiplier() -> float:
	return clampf(movement_multiplier, 0.0, 1.0)


func get_current_resource() -> int:
	return GameState.get_stat(restore_resource_id)


func get_maximum_resource() -> int:
	return GameState.get_stat("max_" + restore_resource_id)


func can_apply() -> bool:
	if restore_amount <= 0:
		return false
	if can_use_at_maximum:
		return true
	return get_current_resource() < get_maximum_resource()


func apply_effect() -> int:
	var before: int = get_current_resource()
	match restore_resource_id:
		"health":
			GameState.heal(restore_amount)
		"mana":
			GameState.restore_mana(restore_amount)
		"stamina":
			GameState.restore_stamina(restore_amount)
		"stance":
			GameState.restore_stance(restore_amount)
		_:
			return 0
	return GameState.get_stat(restore_resource_id) - before


func get_debug_data() -> Dictionary:
	return {
		"id": item_id,
		"name": display_name,
		"charges": get_max_charges(),
		"duration": get_use_duration(),
		"movement": get_movement_multiplier(),
		"restore_resource": restore_resource_id,
		"restore_amount": restore_amount,
		"refill_on_rest": refill_on_rest,
	}
