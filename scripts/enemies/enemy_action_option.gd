extends Resource
class_name EnemyActionOption

@export var attack: EnemyAttackDefinition
@export var presentation: EnemyActionPresentation

@export_group("Selection")
@export var selection_role: String = "melee"
@export var minimum_start_distance: float = 0.0
@export var maximum_start_distance: float = 1.5
@export var selection_weight: float = 1.0

@export_group("Contact")
@export var contact_range_override: float = -1.0
@export var stop_movement_on_hit: bool = false

@export_group("Debug")
@export var debug_label: String = ""


func is_valid_at_distance(distance: float) -> bool:
	if attack == null:
		return false

	return distance >= get_minimum_start_distance() and distance <= get_maximum_start_distance()


func get_minimum_start_distance() -> float:
	return max(minimum_start_distance, 0.0)


func get_maximum_start_distance() -> float:
	var minimum: float = get_minimum_start_distance()
	return max(maximum_start_distance, minimum)


func get_contact_range() -> float:
	if contact_range_override > 0.0:
		return contact_range_override

	return attack.get_range() if attack != null else 0.0


func get_selection_weight() -> float:
	return max(selection_weight, 0.0)


func get_display_name() -> String:
	if debug_label != "":
		return debug_label

	return attack.get_display_name() if attack != null else "No Action"


func get_role_tags() -> Array[String]:
	if attack == null:
		return []

	return attack.get_role_tags()


func apply_presentation(telegraph: Node) -> void:
	if presentation != null:
		presentation.apply_to(telegraph)
