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


func try_player_ability_channel(
	player: Node3D,
	ability: AbilityDefinition
) -> Dictionary:
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
			push_warning(
				child.name
				+ " claims an ability but cannot begin its channel."
			)
			return {"handled": true, "success": false}
		return {
			"handled": true,
			"success": bool(
				child.call("begin_ability_channel", player, ability)
			),
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
	var started: bool = super.begin_ground_targeting(
		player,
		ability,
		ground_spell
	)
	if started:
		_hide_focus_library_ui()
	return started


func confirm_ground_targeting() -> bool:
	if not is_ground_targeting():
		return false
	var controller: RefCounted = get_ground_targeting_controller()
	if (
		controller.has_method("is_target_valid")
		and not bool(controller.call("is_target_valid"))
	):
		var reason: String = "That spell cannot be placed there."
		if controller.has_method("get_invalid_reason"):
			var reported: String = str(
				controller.call("get_invalid_reason")
			)
			if reported != "":
				reason = reported
		show_feedback(reason)
		return true
	return super.confirm_ground_targeting()


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


# Lock-on may influence only spells that explicitly declare target-lock or
# homing behavior. Aimed, self, burst, movement, detection, and free-fire
# abilities follow the camera or Grace's forward direction instead.
func get_cast_direction(player: Node3D, cast_origin: Vector3) -> Vector3:
	var ability: AbilityDefinition = get_current_ability()
	if _ability_uses_lock_on_direction(ability):
		return super.get_cast_direction(player, cast_origin)

	var direction: Vector3 = -player.global_transform.basis.z
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null:
		direction = -camera.global_transform.basis.z
	if direction.length() <= 0.01:
		return Vector3.FORWARD
	return direction.normalized()


func _ability_uses_lock_on_direction(ability: AbilityDefinition) -> bool:
	if ability == null:
		return false
	var targeting_style: String = ability.get_targeting_style().strip_edges().to_lower()
	var delivery_type: String = ability.get_delivery_type().strip_edges().to_lower()
	return (
		targeting_style in [
			"target",
			"single_target",
			"target_lock",
			"lock_on",
			"homing",
		]
		or delivery_type in ["homing", "target_lock"]
	)


func get_input_mode_debug_data() -> Dictionary:
	var data: Dictionary = {
		"ground_targeting": is_ground_targeting(),
		"focus_modal": focus_spell_menu_open,
		"focus_library_visible": is_focus_library_open(),
	}
	if is_ground_targeting():
		var controller: RefCounted = get_ground_targeting_controller()
		if controller.has_method("get_debug_data"):
			data["targeting"] = controller.call("get_debug_data")
	return data
