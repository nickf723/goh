extends "res://scripts/divine_specials/player_divine_special_input_router.gd"


func _input(event: InputEvent) -> void:
	if _is_full_menu_open():
		if event is InputEventJoypadButton:
			var blocked_button: InputEventJoypadButton = event as InputEventJoypadButton
			if is_gesture_active(blocked_button.device):
				cancel_active_gesture(blocked_button.device, "full_menu")
		return
	if not (event is InputEventJoypadButton):
		return
	var button_event: InputEventJoypadButton = event as InputEventJoypadButton
	var handled: bool = false
	if button_event.button_index == special_button:
		if (
			_is_focus_spell_menu_open()
			and not is_gesture_active(button_event.device)
		):
			return
		handled = handle_special_button(
			button_event.device,
			button_event.pressed,
			Time.get_ticks_msec()
		)
	elif (
		button_event.pressed
		and button_event.button_index
		== get_cancel_button_for_device(button_event.device)
		and is_gesture_active(button_event.device)
	):
		handled = cancel_active_gesture(button_event.device, "player_cancel")
	if handled:
		get_viewport().set_input_as_handled()


func get_gesture_availability() -> Dictionary:
	_resolve_bindings()
	if special_controller == null:
		return {
			"valid": false,
			"reason": "Divine Special controller is missing.",
		}
	var definitions: Array[DivineSpecialDefinition] = (
		special_controller.get_available_specials(_force_debug_access())
	)
	if definitions.is_empty():
		return {
			"valid": false,
			"reason": "No Divine Specials are unlocked.",
		}
	if special_controller.active_effect != null:
		return {
			"valid": false,
			"reason": "A Divine Special is already active.",
		}
	if action_state != null and (
		action_state.is_defeated or action_state.is_staggered
	):
		return {
			"valid": false,
			"reason": "Grace cannot call a patron while incapacitated.",
		}
	if action_state != null and action_state.is_attacking:
		return {
			"valid": false,
			"reason": "Finish the current attack before choosing a Divine Special.",
		}
	return {
		"valid": true,
		"definition": special_controller.get_selected_special(
			_force_debug_access()
		),
	}


func finish_active_gesture(
	device: int,
	cancelled: bool = false,
	reason: String = "release"
) -> bool:
	if active_device != device or not gesture_active:
		return false
	var radial_was_open: bool = radial_open
	if radial_was_open:
		_close_radial_context()
	gesture_active = false
	radial_open = false
	button_down = false
	active_device = -1

	if cancelled:
		last_activation_succeeded = false
		return true
	if special_controller == null:
		last_activation_succeeded = false
		return true
	if radial_was_open:
		last_activation_succeeded = false
		last_availability_reason = ""
		_show_selected_special_feedback()
		return true

	last_activation_succeeded = special_controller.activate_selected_special(
		_force_debug_access()
	)
	if not last_activation_succeeded:
		last_availability_reason = special_controller.last_failure
		if reason != "" and last_availability_reason != "":
			_show_message(last_availability_reason)
	return true


func get_cancel_button_for_device(device: int) -> int:
	var controller_name: String = Input.get_joy_name(device).to_lower()
	if (
		"nintendo" in controller_name
		or "switch" in controller_name
		or "pro controller" in controller_name
	):
		# Godot/SDL normalizes Nintendo's physical B button to logical A.
		return 0
	# Xbox B and PlayStation Circle use the logical right face button.
	return cancel_button


func _is_focus_spell_menu_open() -> bool:
	_resolve_bindings()
	if actor == null:
		return false
	var ability_caster: Node = actor.get_node_or_null("AbilityCaster")
	return (
		ability_caster != null
		and ability_caster.has_method("is_focus_spell_menu_open")
		and bool(ability_caster.call("is_focus_spell_menu_open"))
	)


func _is_full_menu_open() -> bool:
	var director: Node = get_node_or_null("/root/FullMenuDirector")
	return (
		director != null
		and director.has_method("is_full_menu_open")
		and bool(director.call("is_full_menu_open"))
	)


func _show_selected_special_feedback() -> void:
	if special_controller == null:
		return
	var selected: DivineSpecialDefinition = special_controller.get_selected_special(
		_force_debug_access()
	)
	if selected != null:
		_show_message("Divine Special selected: " + selected.display_name + ".")
