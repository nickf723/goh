extends "res://scripts/input/player_control_router_quickbar.gd"
class_name PlayerControlRouterFocusLibrary

# The quickbar stores ten shortcut spell IDs. Focus stores every learned spell.
# Assignment copies the selected learned spell into a shortcut without treating
# the shortcut array as the source of Focus's contents.


func assign_selected_focus_spell_to_slot(slot_index: int) -> bool:
	_resolve_bindings()
	if (
		ability_caster == null
		or slot_index < 0
		or slot_index >= QUICK_SPELL_SLOT_COUNT
	):
		return false

	var ability: AbilityDefinition = null
	if ability_caster.has_method("get_selected_focus_ability"):
		var selected_value: Variant = ability_caster.call(
			"get_selected_focus_ability"
		)
		if selected_value is AbilityDefinition:
			ability = selected_value as AbilityDefinition
	else:
		# Compatibility fallback for older caster scenes.
		var legacy_index: int = int(
			ability_caster.call("get_selected_focus_spell_global_index")
		)
		var legacy_loadout: AbilityLoadout = _get_current_loadout()
		if legacy_loadout != null and legacy_index >= 0:
			ability = legacy_loadout.get_equipped_ability(legacy_index)

	var loadout: AbilityLoadout = _get_current_loadout()
	if loadout == null or ability == null:
		_show_message("No spell is selected in Focus.")
		return false

	var ability_index: int = _ensure_runtime_ability(loadout, ability)
	if ability_index < 0:
		_show_message("The selected Focus spell could not enter the runtime loadout.")
		return false

	var spell_id: String = ability.get_spell_id()
	var slots: Array[String] = _get_saved_spell_ids()
	var previous_slot: int = slots.find(spell_id)
	var displaced_spell_id: String = slots[slot_index]

	# Keep the old swap behavior: assigning a spell that already occupies another
	# shortcut moves the displaced spell into that previous shortcut.
	if previous_slot >= 0 and previous_slot != slot_index:
		_ensure_runtime_spell_id(loadout, displaced_spell_id)
		GameState.call(
			"set_quick_spell_slot",
			current_quickbar_loadout_id,
			previous_slot,
			displaced_spell_id
		)

	GameState.call(
		"set_quick_spell_slot",
		current_quickbar_loadout_id,
		slot_index,
		spell_id
	)
	_refresh_favorite_indices()
	if selected_favorite_cursor == slot_index:
		ability_caster.call("select_ability", ability_index, false)
	quick_spell_assigned.emit(slot_index, spell_id)
	quick_spell_activity.emit("assignment", slot_index)
	_show_message(
		"Assigned "
		+ ability.display_name
		+ " to quick spell "
		+ QUICK_SPELL_KEY_LABELS[slot_index]
		+ "."
	)
	return true


func _ensure_runtime_spell_id(
	loadout: AbilityLoadout,
	spell_id: String
) -> int:
	if loadout == null or spell_id == "":
		return -1
	var existing: int = _get_equipped_ability_index(loadout, spell_id)
	if existing >= 0:
		return existing
	for learned: AbilityDefinition in loadout.get_learned_abilities():
		if learned != null and learned.get_spell_id() == spell_id:
			return _ensure_runtime_ability(loadout, learned)
	return -1


func _ensure_runtime_ability(
	loadout: AbilityLoadout,
	ability: AbilityDefinition
) -> int:
	if loadout == null or ability == null:
		return -1
	var existing: int = _get_equipped_ability_index(
		loadout,
		ability.get_spell_id()
	)
	if existing >= 0:
		return existing
	loadout.equipped_abilities.append(ability)
	return loadout.equipped_abilities.size() - 1


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["focus_library_assignment"] = true
	data["quickbar_mutates_focus_library"] = false
	return data
