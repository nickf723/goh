extends "res://scripts/input/player_control_router.gd"


func _input(event: InputEvent) -> void:
	_resolve_bindings()
	if (
		event is InputEventJoypadButton
		and is_focus_open()
		and _handle_focus_dpad(event as InputEventJoypadButton)
	):
		get_viewport().set_input_as_handled()
		return
	super._input(event)


func _handle_focus_dpad(event: InputEventJoypadButton) -> bool:
	if event.button_index not in [
		JOY_BUTTON_DPAD_UP,
		JOY_BUTTON_DPAD_DOWN,
		JOY_BUTTON_DPAD_LEFT,
		JOY_BUTTON_DPAD_RIGHT,
	]:
		return false
	if not event.pressed:
		return true
	if ability_caster == null:
		return true
	match event.button_index:
		JOY_BUTTON_DPAD_LEFT:
			if ability_caster.has_method("cycle_focus_element"):
				ability_caster.call("cycle_focus_element", -1)
		JOY_BUTTON_DPAD_RIGHT:
			if ability_caster.has_method("cycle_focus_element"):
				ability_caster.call("cycle_focus_element", 1)
		JOY_BUTTON_DPAD_UP:
			if ability_caster.has_method("cycle_focus_spell"):
				ability_caster.call("cycle_focus_spell", -1)
		JOY_BUTTON_DPAD_DOWN:
			if ability_caster.has_method("cycle_focus_spell"):
				ability_caster.call("cycle_focus_spell", 1)
	return true
