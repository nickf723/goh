extends "res://scripts/input/player_control_router_contextual.gd"

signal quick_spell_activity(source: String, slot_index: int)
signal quick_spell_assigned(slot_index: int, spell_id: String)

const QUICK_SPELL_SLOT_COUNT: int = 10
const QUICK_SPELL_ACTIONS: Array[StringName] = [
	&"ability_slot_1",
	&"ability_slot_2",
	&"ability_slot_3",
	&"ability_slot_4",
	&"ability_slot_5",
	&"ability_slot_6",
	&"ability_slot_7",
	&"ability_slot_8",
	&"ability_slot_9",
	&"ability_slot_0",
]
const QUICK_SPELL_KEY_LABELS: Array[String] = [
	"1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
]

var current_quickbar_loadout_id: String = ""
var quickbar_initialized: bool = false


func _finish_setup() -> void:
	super._finish_setup()
	_refresh_favorite_indices()
	_select_saved_slot_for_current_loadout()
	quickbar_initialized = true


func _input(event: InputEvent) -> void:
	_resolve_bindings()
	if _handle_keyboard_quickbar(event):
		get_viewport().set_input_as_handled()
		return
	super._input(event)


func _handle_keyboard_quickbar(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo or get_tree().paused:
		return false
	var slot_index: int = _get_quickbar_slot_from_event(event)
	if slot_index < 0:
		return false
	if is_focus_open():
		assign_selected_focus_spell_to_slot(slot_index)
	else:
		select_quick_spell_slot(slot_index, "keyboard")
	return true


func _get_quickbar_slot_from_event(event: InputEvent) -> int:
	for slot_index: int in range(QUICK_SPELL_ACTIONS.size()):
		if event.is_action_pressed(QUICK_SPELL_ACTIONS[slot_index]):
			return slot_index
	return -1


func cycle_quick_spell(direction: int) -> bool:
	_resolve_bindings()
	_refresh_favorite_indices()
	if ability_caster == null or resolved_favorite_indices.is_empty() or direction == 0:
		_show_message("No quick spells are configured.")
		return false
	for step: int in range(1, QUICK_SPELL_SLOT_COUNT + 1):
		var candidate: int = posmod(
			selected_favorite_cursor + step * signi(direction),
			QUICK_SPELL_SLOT_COUNT
		)
		if candidate >= resolved_favorite_indices.size():
			continue
		if resolved_favorite_indices[candidate] < 0:
			continue
		return select_quick_spell_slot(candidate, "controller")
	_show_message("No quick spells are configured.")
	return false


func select_quick_spell_slot(
	slot_index: int,
	source: String = "system",
	show_feedback: bool = true
) -> bool:
	_resolve_bindings()
	_refresh_favorite_indices()
	if slot_index < 0 or slot_index >= QUICK_SPELL_SLOT_COUNT:
		return false
	if slot_index >= resolved_favorite_indices.size():
		return false
	var ability_index: int = resolved_favorite_indices[slot_index]
	if ability_index < 0 or ability_caster == null:
		if show_feedback:
			_show_message("Quick spell slot " + QUICK_SPELL_KEY_LABELS[slot_index] + " is empty.")
		quick_spell_activity.emit(source, slot_index)
		return false
	selected_favorite_cursor = slot_index
	if GameState.has_method("set_selected_quick_spell_slot"):
		GameState.call(
			"set_selected_quick_spell_slot",
			current_quickbar_loadout_id,
			selected_favorite_cursor
		)
	ability_caster.call("select_ability", ability_index, false)
	quick_spell_changed.emit(selected_favorite_cursor, ability_index)
	quick_spell_activity.emit(source, selected_favorite_cursor)
	if show_feedback:
		_show_message(
			"Quick spell "
			+ QUICK_SPELL_KEY_LABELS[selected_favorite_cursor]
			+ ": "
			+ get_selected_quick_spell_name()
		)
	return true


func assign_selected_focus_spell_to_slot(slot_index: int) -> bool:
	_resolve_bindings()
	if ability_caster == null or slot_index < 0 or slot_index >= QUICK_SPELL_SLOT_COUNT:
		return false
	if not ability_caster.has_method("get_selected_focus_spell_global_index"):
		return false
	var ability_index: int = int(
		ability_caster.call("get_selected_focus_spell_global_index")
	)
	var loadout: AbilityLoadout = _get_current_loadout()
	if loadout == null or ability_index < 0:
		_show_message("No spell is selected in Focus.")
		return false
	var ability: AbilityDefinition = loadout.get_equipped_ability(ability_index)
	if ability == null:
		_show_message("No spell is selected in Focus.")
		return false
	var spell_id: String = ability.get_spell_id()
	var slots: Array[String] = _get_saved_spell_ids()
	var previous_slot: int = slots.find(spell_id)
	var displaced_spell_id: String = slots[slot_index]
	if previous_slot >= 0 and previous_slot != slot_index:
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


func _refresh_favorite_indices() -> void:
	_resolve_bindings()
	resolved_favorite_indices.clear()
	var loadout: AbilityLoadout = _get_current_loadout()
	if loadout == null:
		current_quickbar_loadout_id = ""
		selected_favorite_cursor = 0
		return
	var next_loadout_id: String = _get_loadout_id(loadout)
	var loadout_changed: bool = next_loadout_id != current_quickbar_loadout_id
	current_quickbar_loadout_id = next_loadout_id
	var defaults: Array[String] = _get_default_spell_ids(loadout)
	if GameState.has_method("ensure_quick_spell_loadout"):
		GameState.call(
			"ensure_quick_spell_loadout",
			current_quickbar_loadout_id,
			defaults
		)
	var spell_ids: Array[String] = _get_saved_spell_ids()
	for spell_id: String in spell_ids:
		resolved_favorite_indices.append(
			_get_equipped_ability_index(loadout, spell_id)
		)
	while resolved_favorite_indices.size() < QUICK_SPELL_SLOT_COUNT:
		resolved_favorite_indices.append(-1)
	if loadout_changed:
		selected_favorite_cursor = _get_saved_selected_slot()
	selected_favorite_cursor = clampi(
		selected_favorite_cursor,
		0,
		QUICK_SPELL_SLOT_COUNT - 1
	)
	if resolved_favorite_indices[selected_favorite_cursor] < 0:
		selected_favorite_cursor = _find_first_occupied_slot()


func _select_saved_slot_for_current_loadout() -> void:
	_refresh_favorite_indices()
	if resolved_favorite_indices.is_empty():
		return
	if selected_favorite_cursor < 0 or selected_favorite_cursor >= resolved_favorite_indices.size():
		return
	var ability_index: int = resolved_favorite_indices[selected_favorite_cursor]
	if ability_index >= 0 and ability_caster != null:
		ability_caster.call("select_ability", ability_index, false)


func _find_first_occupied_slot() -> int:
	for slot_index: int in range(resolved_favorite_indices.size()):
		if resolved_favorite_indices[slot_index] >= 0:
			return slot_index
	return 0


func get_quick_spell_names() -> Array[String]:
	_refresh_favorite_indices()
	var names: Array[String] = []
	var loadout: AbilityLoadout = _get_current_loadout()
	for ability_index: int in resolved_favorite_indices:
		var name: String = "Empty"
		if loadout != null and ability_index >= 0:
			var ability: AbilityDefinition = loadout.get_equipped_ability(ability_index)
			if ability != null:
				name = ability.display_name
		names.append(name)
	return names


func get_quick_spell_slot_rows() -> Array[Dictionary]:
	var names: Array[String] = get_quick_spell_names()
	var spell_ids: Array[String] = _get_saved_spell_ids()
	var rows: Array[Dictionary] = []
	for slot_index: int in range(QUICK_SPELL_SLOT_COUNT):
		rows.append({
			"slot_index": slot_index,
			"key_label": QUICK_SPELL_KEY_LABELS[slot_index],
			"spell_id": spell_ids[slot_index] if slot_index < spell_ids.size() else "",
			"ability_index": (
				resolved_favorite_indices[slot_index]
				if slot_index < resolved_favorite_indices.size()
				else -1
			),
			"name": names[slot_index] if slot_index < names.size() else "Empty",
			"selected": slot_index == selected_favorite_cursor,
		})
	return rows


func get_quick_spell_window_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = get_quick_spell_slot_rows()
	var window: Array[Dictionary] = []
	for offset: int in [-1, 0, 1]:
		var slot_index: int = posmod(
			selected_favorite_cursor + offset,
			QUICK_SPELL_SLOT_COUNT
		)
		window.append(rows[slot_index])
	return window


func get_selected_quick_spell_name() -> String:
	var names: Array[String] = get_quick_spell_names()
	if names.is_empty():
		return "None"
	return names[clampi(selected_favorite_cursor, 0, names.size() - 1)]


func get_selected_quick_spell_cursor() -> int:
	_refresh_favorite_indices()
	return selected_favorite_cursor


func get_selected_quick_spell_slot() -> int:
	return get_selected_quick_spell_cursor()


func _get_current_loadout() -> AbilityLoadout:
	if ability_caster == null:
		return null
	var loadout_value: Variant = ability_caster.get("loadout")
	return loadout_value as AbilityLoadout if loadout_value is AbilityLoadout else null


func _get_loadout_id(loadout: AbilityLoadout) -> String:
	if loadout == null:
		return "default"
	if loadout.resource_path != "":
		return loadout.resource_path.get_file().get_basename()
	return "runtime_" + str(loadout.get_instance_id())


func _get_default_spell_ids(loadout: AbilityLoadout) -> Array[String]:
	var spell_ids: Array[String] = []
	if loadout == null:
		return spell_ids
	for ability: AbilityDefinition in loadout.equipped_abilities:
		if ability == null:
			continue
		var spell_id: String = ability.get_spell_id()
		if spell_id == "" or spell_ids.has(spell_id):
			continue
		spell_ids.append(spell_id)
		if spell_ids.size() >= QUICK_SPELL_SLOT_COUNT:
			break
	return spell_ids


func _get_saved_spell_ids() -> Array[String]:
	var spell_ids: Array[String] = []
	if (
		current_quickbar_loadout_id != ""
		and GameState.has_method("get_quick_spell_slots")
	):
		var result: Variant = GameState.call(
			"get_quick_spell_slots",
			current_quickbar_loadout_id
		)
		if result is Array:
			for value: Variant in result as Array:
				spell_ids.append(str(value))
	while spell_ids.size() < QUICK_SPELL_SLOT_COUNT:
		spell_ids.append("")
	if spell_ids.size() > QUICK_SPELL_SLOT_COUNT:
		spell_ids.resize(QUICK_SPELL_SLOT_COUNT)
	return spell_ids


func _get_saved_selected_slot() -> int:
	if (
		current_quickbar_loadout_id != ""
		and GameState.has_method("get_selected_quick_spell_slot")
	):
		return int(GameState.call(
			"get_selected_quick_spell_slot",
			current_quickbar_loadout_id
		))
	return 0


func _get_equipped_ability_index(
	loadout: AbilityLoadout,
	spell_id: String
) -> int:
	if loadout == null or spell_id == "":
		return -1
	for ability_index: int in range(loadout.get_equipped_ability_count()):
		var ability: AbilityDefinition = loadout.get_equipped_ability(ability_index)
		if ability != null and ability.get_spell_id() == spell_id:
			return ability_index
	return -1


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["quickbar_loadout_id"] = current_quickbar_loadout_id
	data["quickbar_slot_count"] = QUICK_SPELL_SLOT_COUNT
	data["quickbar_selected_slot"] = selected_favorite_cursor
	data["quickbar_spell_ids"] = _get_saved_spell_ids()
	data["favorite_indices"] = resolved_favorite_indices.duplicate()
	return data
