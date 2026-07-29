extends "res://scripts/divine_specials/player_divine_special_input_router.gd"


func _input(event: InputEvent) -> void:
	if not (event is InputEventJoypadButton):
		return
	var button_event: InputEventJoypadButton = event as InputEventJoypadButton
	var handled: bool = false
	if button_event.button_index == special_button:
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
