extends Resource
class_name ConcentrationEffectDefinition

@export var effect_id: String = "concentration_effect"
@export var display_name: String = "Concentration Effect"
@export_multiline var description: String = ""

@export_range(0.0, 0.95, 0.01) var mana_reservation_fraction: float = 0.25
@export var free_elements: Array[String] = []
@export var discounted_elements: Dictionary = {}
@export var effect_tags: Array[String] = []


func get_reserved_mana(maximum_mana: int) -> int:
	var safe_maximum: int = max(maximum_mana, 0)
	return int(ceil(float(safe_maximum) * clampf(mana_reservation_fraction, 0.0, 0.95)))


func get_usable_mana_cap(maximum_mana: int) -> int:
	return max(maximum_mana - get_reserved_mana(maximum_mana), 0)


func makes_element_free(element: String) -> bool:
	return free_elements.has(element.to_lower().strip_edges())


func get_element_cost_multiplier(element: String) -> float:
	var normalized_element: String = element.to_lower().strip_edges()
	if makes_element_free(normalized_element):
		return 0.0
	if discounted_elements.has(normalized_element):
		return clampf(float(discounted_elements[normalized_element]), 0.0, 1.0)
	return 1.0


func get_debug_data() -> Dictionary:
	return {
		"effect_id": effect_id,
		"display_name": display_name,
		"reservation_fraction": mana_reservation_fraction,
		"free_elements": free_elements,
		"discounted_elements": discounted_elements,
		"tags": effect_tags,
	}
