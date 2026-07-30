extends "res://scripts/abilities/ability_caster_menu_select.gd"

# Player-owned channeled abilities use the same equipped-spell input as every
# other spell. A matching child component may claim the cast before the normal
# scene-instantiation path runs.


func cast_from_player(
	player: Node3D,
	cast_lock_duration: float = 0.18,
	allow_charge: bool = true
) -> bool:
	var ability: AbilityDefinition = get_current_ability()
	var channel_result: Dictionary = try_player_ability_channel(player, ability)
	if bool(channel_result.get("handled", false)):
		return bool(channel_result.get("success", false))
	return super.cast_from_player(player, cast_lock_duration, allow_charge)


func try_player_ability_channel(player: Node3D, ability: AbilityDefinition) -> Dictionary:
	if player == null or ability == null:
		return {"handled": false, "success": false}
	if action_state != null and not action_state.can_cast():
		return {"handled": true, "success": false}

	for child: Node in player.get_children():
		if not child.has_method("can_handle_ability"):
			continue
		if not bool(child.call("can_handle_ability", ability)):
			continue
		if not child.has_method("begin_ability_channel"):
			push_warning(child.name + " claims an ability but cannot begin its channel.")
			return {"handled": true, "success": false}
		return {
			"handled": true,
			"success": bool(child.call("begin_ability_channel", player, ability)),
		}

	return {"handled": false, "success": false}


# Ground targeting uses the caster's modal input path, but it is not the visible
# spell library. Keeping those states separate prevents the right stick from
# moving an AoE marker and navigating Focus at the same time.
func begin_ground_targeting(
	player: Node3D,
	ability: AbilityDefinition,
	ground_spell: Dictionary
) -> bool:
	var started: bool = super.begin_ground_targeting(player, ability, ground_spell)
	if started:
		_hide_focus_library_ui()
	return started


func is_focus_library_open() -> bool:
	return focus_spell_menu_open and not is_ground_targeting()


func open_focus_spell_menu() -> void:
	if is_ground_targeting():
		return
	super.open_focus_spell_menu()


func update_focus_spell_menu_ui() -> void:
	if is_ground_targeting():
		_hide_focus_library_ui()
		return
	super.update_focus_spell_menu_ui()


func _hide_focus_library_ui() -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("hide_spell_focus_menu"):
		ui.call("hide_spell_focus_menu")
	elif ui != null and ui.has_method("hide_spell_menu"):
		ui.call("hide_spell_menu")


func get_input_mode_debug_data() -> Dictionary:
	return {
		"ground_targeting": is_ground_targeting(),
		"focus_modal": focus_spell_menu_open,
		"focus_library_visible": is_focus_library_open(),
	}
