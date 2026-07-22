extends Resource
class_name PickupDropEntry

@export var pickup_definition: PickupDefinition
@export_range(0.0, 1.0, 0.01) var chance: float = 1.0
@export_range(0, 12, 1) var minimum_count: int = 1
@export_range(0, 12, 1) var maximum_count: int = 1
@export var guaranteed: bool = false
@export_range(0.0, 100.0, 0.1) var random_weight: float = 1.0


func roll_count() -> int:
	if pickup_definition == null:
		return 0

	if not guaranteed and randf() > clampf(chance, 0.0, 1.0):
		return 0

	var safe_minimum: int = max(minimum_count, 0)
	var safe_maximum: int = max(maximum_count, safe_minimum)
	return randi_range(safe_minimum, safe_maximum)


func get_debug_data() -> Dictionary:
	return {
		"pickup": pickup_definition.pickup_id if pickup_definition != null else "none",
		"chance": chance,
		"minimum": minimum_count,
		"maximum": maximum_count,
		"guaranteed": guaranteed,
		"weight": random_weight,
	}
