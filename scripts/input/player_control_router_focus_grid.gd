extends "res://scripts/input/player_control_router_focus_library.gd"
class_name PlayerControlRouterFocusGrid


func _input(event: InputEvent) -> void:
	_resolve_bindings()
	if (
		event is InputEventJoypadButton
		and is_focus_open()
		and _handle_focus_grid_action_button(event as InputEventJoypadButton)
	):
		get_viewport().set_input_as_handled()
		return
	super._input(event)


func _handle_focus_grid_action_button(event: InputEventJoypadButton) -> bool:
	if event.button_index not in [JOY_BUTTON_A, JOY_BUTTON_B]:
		return false
	# Consume releases too so A/B cannot leak into gameplay on the same frame the
	# Focus state changes.
	if not event.pressed:
		return true
	if ability_caster == null:
		return true

	if event.button_index == JOY_BUTTON_B:
		if (
			ability_caster.has_method("is_focus_spell_grid_active")
			and bool(ability_caster.call("is_focus_spell_grid_active"))
			and ability_caster.has_method("return_to_focus_element_grid")
		):
			ability_caster.call("return_to_focus_element_grid")
		elif ability_caster.has_method("close_focus_spell_menu"):
			ability_caster.call("close_focus_spell_menu")
		return true

	if event.button_index == JOY_BUTTON_A:
		if (
			ability_caster.has_method("is_focus_spell_grid_active")
			and bool(ability_caster.call("is_focus_spell_grid_active"))
		):
			if ability_caster.has_method("equip_selected_focus_spell_and_close"):
				ability_caster.call("equip_selected_focus_spell_and_close")
		elif ability_caster.has_method("enter_focus_spell_grid"):
			ability_caster.call("enter_focus_spell_grid")
		return true

	return false


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
	_resolve_bindings()
	if ability_caster == null:
		return true

	var delta := Vector2i.ZERO
	match event.button_index:
		JOY_BUTTON_DPAD_LEFT:
			delta.x = -1
		JOY_BUTTON_DPAD_RIGHT:
			delta.x = 1
		JOY_BUTTON_DPAD_UP:
			delta.y = -1
		JOY_BUTTON_DPAD_DOWN:
			delta.y = 1

	if ability_caster.has_method("navigate_focus_grid"):
		ability_caster.call("navigate_focus_grid", delta.x, delta.y)
		return true
	return super._handle_focus_dpad(event)


# Focus v2 is deliberately D-pad driven. Consume right-stick motion while Focus
# is open so camera input cannot leak through, but do not create a second,
# competing navigation grammar.
func handle_focus_stick_motion(_event: InputEventJoypadMotion) -> bool:
	return is_focus_open()


func assign_selected_focus_spell_to_slot(slot_index: int) -> bool:
	_resolve_bindings()
	if (
		ability_caster != null
		and ability_caster.has_method("is_focus_spell_grid_active")
		and not bool(ability_caster.call("is_focus_spell_grid_active"))
	):
		_show_message("Choose an element before assigning a spell slot.")
		return false
	return super.assign_selected_focus_spell_to_slot(slot_index)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["focus_grid_navigation"] = true
	data["focus_dpad_only"] = true
	data["focus_a_confirms"] = true
	data["focus_b_backs_out"] = true
	return data
