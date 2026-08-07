extends "res://scripts/abilities/ability_caster_player_channels.gd"
class_name AbilityCasterFocusLibrary

# Focus is Grace's complete learned spell library. The permanent ten-slot belt is
# only a shortcut surface. Keeping these collections separate prevents replacing
# a quick slot from deleting, duplicating, or reordering the same spell in Focus.


func get_focus_library_abilities() -> Array[AbilityDefinition]:
	if loadout == null:
		return []
	return loadout.get_learned_abilities()


func get_focus_abilities_for_element(element: String) -> Array[AbilityDefinition]:
	var abilities: Array[AbilityDefinition] = []
	for ability: AbilityDefinition in get_focus_library_abilities():
		if ability != null and ability.element == element:
			abilities.append(ability)
	return abilities


func get_spell_indices_for_element(element: String) -> Array[int]:
	var indices: Array[int] = []
	var learned: Array[AbilityDefinition] = get_focus_library_abilities()
	for ability_index: int in range(learned.size()):
		var ability: AbilityDefinition = learned[ability_index]
		if ability != null and ability.element == element:
			indices.append(ability_index)
	return indices


func get_selected_focus_spell_global_index() -> int:
	var spell_indices: Array[int] = get_spell_indices_for_element(
		get_selected_focus_element()
	)
	if spell_indices.is_empty():
		return -1
	focus_spell_index = clampi(
		focus_spell_index,
		0,
		spell_indices.size() - 1
	)
	return spell_indices[focus_spell_index]


func get_selected_focus_ability() -> AbilityDefinition:
	var selected_index: int = get_selected_focus_spell_global_index()
	var learned: Array[AbilityDefinition] = get_focus_library_abilities()
	if selected_index < 0 or selected_index >= learned.size():
		return null
	return learned[selected_index]


func get_focus_spell_names_for_element(element: String) -> Array[String]:
	var names: Array[String] = []
	for ability: AbilityDefinition in get_focus_abilities_for_element(element):
		names.append(ability.display_name)
	return names


func align_focus_menu_to_current_ability() -> void:
	var ability: AbilityDefinition = get_current_ability()
	if ability == null:
		return
	var element_index: int = get_element_index(ability.element)
	if element_index < 0:
		return
	focus_element_index = element_index
	var element_abilities: Array[AbilityDefinition] = get_focus_abilities_for_element(
		ability.element
	)
	focus_spell_index = 0
	var spell_id: String = ability.get_spell_id()
	for local_index: int in range(element_abilities.size()):
		var candidate: AbilityDefinition = element_abilities[local_index]
		if candidate != null and candidate.get_spell_id() == spell_id:
			focus_spell_index = local_index
			break


func select_focus_spell_by_id(spell_id: String) -> bool:
	var normalized: String = spell_id.strip_edges().to_lower()
	if normalized == "":
		return false
	var learned: Array[AbilityDefinition] = get_focus_library_abilities()
	for ability: AbilityDefinition in learned:
		if ability == null or ability.get_spell_id() != normalized:
			continue
		var element_index: int = get_element_index(ability.element)
		if element_index < 0:
			return false
		focus_element_index = element_index
		var element_abilities: Array[AbilityDefinition] = get_focus_abilities_for_element(
			ability.element
		)
		focus_spell_index = element_abilities.find(ability)
		if focus_spell_index < 0:
			focus_spell_index = 0
		update_focus_spell_menu_ui()
		return true
	return false


func confirm_focus_spell_menu() -> void:
	if not _select_current_focus_ability(true):
		show_feedback(
			"No learned "
			+ get_selected_focus_element_display_name()
			+ " spells yet."
		)
	update_focus_spell_menu_ui()


func equip_selected_focus_spell_and_close() -> void:
	if not _select_current_focus_ability(true):
		show_feedback(
			"No learned "
			+ get_selected_focus_element_display_name()
			+ " spells yet."
		)
		update_focus_spell_menu_ui()
		return
	close_focus_spell_menu()


func quick_cast_selected_focus_spell() -> void:
	if not _select_current_focus_ability(false):
		show_feedback(
			"No learned "
			+ get_selected_focus_element_display_name()
			+ " spells yet."
		)
		update_focus_spell_menu_ui()
		return
	var player: Node3D = get_focus_player()
	if player == null:
		show_feedback("No player found for quick-cast.")
		update_focus_spell_menu_ui()
		return
	cast_from_player(player, focus_quick_cast_lock_duration, false)
	update_focus_spell_menu_ui()


func _select_current_focus_ability(
	should_show_feedback: bool
) -> bool:
	var ability: AbilityDefinition = get_selected_focus_ability()
	if ability == null or loadout == null:
		return false
	var runtime_index: int = _ensure_runtime_ability(ability)
	if runtime_index < 0:
		return false
	select_ability(runtime_index, should_show_feedback)
	return true


func _ensure_runtime_ability(ability: AbilityDefinition) -> int:
	if ability == null or loadout == null:
		return -1
	var spell_id: String = ability.get_spell_id()
	for ability_index: int in range(loadout.equipped_abilities.size()):
		var candidate: AbilityDefinition = loadout.equipped_abilities[ability_index]
		if candidate != null and candidate.get_spell_id() == spell_id:
			return ability_index
	# Quick-slot replacements may remove the only runtime copy of a learned spell.
	# Append a reserve runtime entry without touching any of the ten shortcut IDs.
	loadout.equipped_abilities.append(ability)
	return loadout.equipped_abilities.size() - 1


func get_focus_menu_data() -> Dictionary:
	var selected_element: String = get_selected_focus_element()
	var selected_ability: AbilityDefinition = get_selected_focus_ability()
	var selected_name: String = (
		selected_ability.display_name
		if selected_ability != null
		else "None"
	)
	var selected_id: String = (
		selected_ability.get_spell_id()
		if selected_ability != null
		else ""
	)
	return {
		"groups": ELEMENT_GROUPS,
		"element_order": ELEMENT_ORDER,
		"selected_element": selected_element,
		"selected_element_name": get_element_display_name(selected_element),
		"selected_spell_index": focus_spell_index,
		"selected_spell_name": selected_name,
		"selected_spell_id": selected_id,
		"spell_names": get_focus_spell_names_for_element(selected_element),
		"current_ability_name": get_current_ability_name(),
		"current_ability_index": current_ability_index,
		"library_source": "learned_abilities",
		"quickbar_independent": true,
	}


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	var selected: AbilityDefinition = get_selected_focus_ability()
	data["focus_library_source"] = "learned_abilities"
	data["focus_quickbar_independent"] = true
	data["focus_learned_count"] = get_focus_library_abilities().size()
	data["focus_selected_spell_id"] = (
		selected.get_spell_id() if selected != null else ""
	)
	return data
