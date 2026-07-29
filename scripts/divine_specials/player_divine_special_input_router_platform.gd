extends "res://scripts/divine_specials/player_divine_special_input_router.gd"


func _input(event: InputEvent) -> void:
	if not (event is InputEventJoypadButton):
		return
	var button_event: InputEventJoypadButton = event as InputEventJoypadButton
	var handled: bool = false
	if button_event.button_index in [left_shoulder_button, right_shoulder_button]:
		handled = handle_shoulder_button(
			button_event.device,
			button_event.button_index,
			button_event.pressed,
			Time.get_ticks_msec()
		)
	elif (
		button_event.pressed
		and button_event.button_index
		== get_cancel_button_for_device(button_event.device)
		and is_chord_active(button_event.device)
	):
		handled = cancel_active_chord(button_event.device, "player_cancel")
	if handled:
		get_viewport().set_input_as_handled()


func get_cancel_button_for_device(device: int) -> int:
	var controller_name: String = Input.get_joy_name(device).to_lower()
	if (
		"nintendo" in controller_name
		or "switch" in controller_name
		or "pro controller" in controller_name
	):
		# Godot/SDL normalizes the physical bottom face button to logical A.
		# On Nintendo hardware that physical button is labelled B.
		return 0
	# Xbox B and PlayStation Circle use the logical right face button.
	return cancel_button
