extends "res://scripts/input/player_control_router_focus_library.gd"
class_name PlayerControlRouterFocusGrid


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
	return data
