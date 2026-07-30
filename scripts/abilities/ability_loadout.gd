extends Resource
class_name AbilityLoadout

const DEFAULT_ELEMENT_ORDER: Array[String] = [
	"water",
	"earth",
	"fire",
	"air",
	"ice",
	"metal",
	"lightning",
	"poison",
	"life",
	"death",
	"body",
	"soul",
	"dreams",
	"sound",
	"space",
	"time",
]

@export var learned_abilities: Array[AbilityDefinition] = []
@export var equipped_abilities: Array[AbilityDefinition] = []

# Keyboard 1-9 and 0 map to ten combat-ready spell slots. The learned library
# may remain much larger, while controller input cycles this same ten-slot belt.
@export var quick_slot_count: int = 10


func get_equipped_ability(index: int) -> AbilityDefinition:
	if index < 0 or index >= equipped_abilities.size():
		return null

	return equipped_abilities[index]


func get_equipped_ability_count() -> int:
	return equipped_abilities.size()


func get_quick_slot_count() -> int:
	return 10


func get_equipped_ability_names() -> Array[String]:
	var names: Array[String] = []

	for ability: AbilityDefinition in equipped_abilities:
		if ability == null:
			names.append("Empty Slot")
		else:
			names.append(ability.display_name)

	return names


func get_equipped_slot_rows(current_ability_index: int = -1) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var slot_count: int = get_quick_slot_count()

	for slot_index: int in range(slot_count):
		var ability: AbilityDefinition = get_equipped_ability(slot_index)
		rows.append({
			"slot": slot_index,
			"ability": ability,
			"is_empty": ability == null,
			"is_current": slot_index == current_ability_index,
		})

	return rows


func get_learned_abilities() -> Array[AbilityDefinition]:
	var abilities: Array[AbilityDefinition] = []

	for ability: AbilityDefinition in learned_abilities:
		append_unique_ability(abilities, ability)

	# Safety fallback for older resources or testing files that only filled equipped.
	if abilities.size() <= 0:
		for ability: AbilityDefinition in equipped_abilities:
			append_unique_ability(abilities, ability)

	return abilities


func get_learned_spell_sections() -> Array[Dictionary]:
	var sections: Array[Dictionary] = []
	var learned: Array[AbilityDefinition] = get_learned_abilities()

	for element: String in DEFAULT_ELEMENT_ORDER:
		var element_spells: Array[AbilityDefinition] = []

		for ability: AbilityDefinition in learned:
			if ability == null:
				continue

			if ability.element == element:
				element_spells.append(ability)

		sections.append({
			"element": element,
			"title": element.capitalize(),
			"spells": element_spells,
		})

	return sections


func get_unassigned_learned_abilities() -> Array[AbilityDefinition]:
	var unassigned: Array[AbilityDefinition] = []

	for ability: AbilityDefinition in get_learned_abilities():
		if ability == null:
			continue

		if not equipped_abilities.has(ability):
			unassigned.append(ability)

	return unassigned


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


func append_unique_ability(target: Array[AbilityDefinition], ability: AbilityDefinition) -> void:
	if ability == null:
		return

	if target.has(ability):
		return

	target.append(ability)
