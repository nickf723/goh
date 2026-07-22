extends Resource
class_name PickupDefinition

@export var pickup_id: String = "resource_pickup"
@export var display_name: String = "Resource Mote"
@export_enum("health", "mana", "stamina", "stance") var resource_type: String = "health"
@export_range(1, 999, 1) var amount: int = 1

@export_group("Presentation")
@export var primary_color: Color = Color(0.45, 1.0, 0.55, 1.0)
@export var secondary_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var visual_scale: float = 1.0
@export var hover_height: float = 0.55
@export var hover_amplitude: float = 0.12
@export var hover_speed: float = 2.4
@export var spin_speed_degrees: float = 110.0

@export_group("Collection")
@export var attraction_radius: float = 4.5
@export var collection_radius: float = 0.55
@export var attraction_speed: float = 7.5
@export var attraction_acceleration: float = 18.0
@export var lifetime_seconds: float = 18.0
@export var collect_when_full: bool = false


func can_apply() -> bool:
	if collect_when_full:
		return true
	return get_current_value() < get_max_value()


func apply_to_game_state() -> int:
	var before: int = get_current_value()

	match resource_type:
		"health":
			GameState.heal(amount)
		"mana":
			GameState.restore_mana(amount)
		"stamina":
			GameState.restore_stamina(amount)
		"stance":
			GameState.restore_stance(amount)
		_:
			return 0

	return max(get_current_value() - before, 0)


func get_current_value() -> int:
	return GameState.get_stat(resource_type)


func get_max_value() -> int:
	return GameState.get_stat("max_" + resource_type)


func get_collection_label(applied_amount: int) -> String:
	var shown_amount: int = applied_amount if applied_amount > 0 else amount
	return "+" + str(shown_amount) + " " + resource_type.to_upper()


func get_debug_data() -> Dictionary:
	return {
		"pickup_id": pickup_id,
		"resource_type": resource_type,
		"amount": amount,
		"attraction_radius": attraction_radius,
		"collection_radius": collection_radius,
	}
