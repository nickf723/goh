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
	# Never reason about Nintendo/Xbox face-button letters here. The project maps
	# Nintendo A to `interact` (button 1) and Nintendo B to `dodge` (button 0),
	# while Godot's JOY_BUTTON_A/B constants use the Xbox ordering. Semantic input
	# actions keep Focus correct on either layout.
	var confirm_pressed: bool = (
		event.is_action_pressed("interact")
		or event.is_action_pressed("ui_accept")
	)
	var confirm_released: bool = (
		event.is_action_released("interact")
		or event.is_action_released("ui_accept")
	)
	var back_pressed: bool = (
		event.is_action_pressed("dodge")
		or event.is_action_pressed("ui_cancel")
	)
	var back_released: bool = (
		event.is_action_released("dodge")
		or event.is_action_released("ui_cancel")
	)
	if not (
		confirm_pressed
		or confirm_released
		or back_pressed
		or back_released
	):
		return false

	# Consume releases too so confirm/back cannot leak into gameplay on the frame
	# that the Focus page changes or closes.
	if confirm_released or back_released:
		return true
	if ability_caster == null:
		return true

	if back_pressed:
		if (
			ability_caster.has_method("is_focus_spell_grid_active")
			and bool(ability_caster.call("is_focus_spell_grid_active"))
			and ability_caster.has_method("return_to_focus_element_grid")
		):
			ability_caster.call("return_to_focus_element_grid")
		elif ability_caster.has_method("close_focus_spell_menu"):
			ability_caster.call("close_focus_spell_menu")
		return true

	if confirm_pressed:
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
	data["focus_confirm_action"] = "interact"
	data["focus_back_action"] = "dodge_or_cancel"
	data["controller_layout_agnostic"] = true
	return data
