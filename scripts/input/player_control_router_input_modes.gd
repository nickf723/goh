extends "res://scripts/input/player_control_router_quickbar.gd"
class_name PlayerControlRouterInputModes


func is_ground_targeting_active() -> bool:
	return (
		ability_caster != null
		and ability_caster.has_method("is_ground_targeting")
		and bool(ability_caster.call("is_ground_targeting"))
	)


func is_focus_open() -> bool:
	if is_ground_targeting_active():
		return false
	if (
		ability_caster != null
		and ability_caster.has_method("is_focus_library_open")
	):
		return bool(ability_caster.call("is_focus_library_open"))
	return super.is_focus_open()


func handle_focus_action(pressed: bool) -> bool:
	if is_ground_targeting_active():
		focus_axis_x_latched = false
		focus_axis_y_latched = false
		# Ground targeting is already the active magic mode. Consume the bumper so
		# it cannot reopen or close the spell library underneath the target cursor.
		return true
	return super.handle_focus_action(pressed)


func _input(event: InputEvent) -> void:
	_resolve_bindings()
	if is_ground_targeting_active():
		if event is InputEventJoypadButton:
			var button_event: InputEventJoypadButton = event as InputEventJoypadButton
			if button_event.button_index in [
				JOY_BUTTON_DPAD_UP,
				JOY_BUTTON_DPAD_DOWN,
				JOY_BUTTON_DPAD_LEFT,
				JOY_BUTTON_DPAD_RIGHT,
			]:
				get_viewport().set_input_as_handled()
				return
		if event is InputEventKey and _get_quickbar_slot_from_event(event) >= 0:
			get_viewport().set_input_as_handled()
			return
	super._input(event)


func get_input_mode_debug_data() -> Dictionary:
	return {
		"ground_targeting": is_ground_targeting_active(),
		"focus_library": is_focus_open(),
		"right_stick_owner": (
			"ground_target"
			if is_ground_targeting_active()
			else ("focus_library" if is_focus_open() else "camera")
		),
	}
