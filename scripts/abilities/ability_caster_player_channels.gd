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
