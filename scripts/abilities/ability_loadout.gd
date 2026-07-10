extends Resource
class_name AbilityLoadout

@export var learned_abilities: Array[AbilityDefinition] = []
@export var equipped_abilities: Array[AbilityDefinition] = []


func get_equipped_ability(index: int) -> AbilityDefinition:
	if index < 0 or index >= equipped_abilities.size():
		return null

	return equipped_abilities[index]


func get_equipped_ability_count() -> int:
	return equipped_abilities.size()


func get_equipped_ability_names() -> Array[String]:
	var names: Array[String] = []

	for ability: AbilityDefinition in equipped_abilities:
		if ability == null:
			names.append("Empty Slot")
		else:
			names.append(ability.display_name)

	return names


func equip_ability(slot_index: int, ability: AbilityDefinition) -> void:
	if slot_index < 0:
		return

	while equipped_abilities.size() <= slot_index:
		equipped_abilities.append(null)

	equipped_abilities[slot_index] = ability


func learn_ability(ability: AbilityDefinition) -> void:
	if ability == null:
		return

	if learned_abilities.has(ability):
		return

	learned_abilities.append(ability)


func knows_ability(ability: AbilityDefinition) -> bool:
	if ability == null:
		return false

	return learned_abilities.has(ability)
