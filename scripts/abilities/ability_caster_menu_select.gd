extends "res://scripts/abilities/ability_caster.gd"

# Prototype wrapper for the focus spell menu.
# The base AbilityCaster still owns casting, loadout, charge logic, and menu data.
# This wrapper only changes the focus menu contract:
# selecting a highlighted spell equips it, instead of quick-casting it.


func handle_focus_menu_input(event: InputEvent) -> bool:
	if not focus_spell_menu_open:
		return false

	if event.is_action_pressed("focus_element_left"):
		cycle_focus_element(-1)
		return true

	if event.is_action_pressed("focus_element_right"):
		cycle_focus_element(1)
		return true

	if event.is_action_pressed("focus_spell_up"):
		cycle_focus_spell(-1)
		return true

	if event.is_action_pressed("focus_spell_down"):
		cycle_focus_spell(1)
		return true

	# In menu mode, cast/accept means "equip highlighted spell".
	# It should not spend mana or fire a projectile.
	if event.is_action_pressed("cast_spell") or event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		equip_selected_focus_spell_and_close()
		return true

	if event.is_action_pressed("ui_cancel"):
		close_focus_spell_menu()
		return true

	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey

		if not key_event.pressed or key_event.echo:
			return true

		match key_event.keycode:
			KEY_LEFT:
				cycle_focus_element(-1)
				return true
			KEY_RIGHT:
				cycle_focus_element(1)
				return true
			KEY_UP:
				cycle_focus_spell(-1)
				return true
			KEY_DOWN:
				cycle_focus_spell(1)
				return true
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				equip_selected_focus_spell_and_close()
				return true
			KEY_ESCAPE:
				close_focus_spell_menu()
				return true
			_:
				return true

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton

		if not mouse_event.pressed:
			return true

		match mouse_event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				cycle_focus_spell(-1)
				return true
			MOUSE_BUTTON_WHEEL_DOWN:
				cycle_focus_spell(1)
				return true
			MOUSE_BUTTON_LEFT:
				equip_selected_focus_spell_and_close()
				return true
			MOUSE_BUTTON_RIGHT:
				close_focus_spell_menu()
				return true
			_:
				return true

	return true


func equip_selected_focus_spell_and_close() -> void:
	var selected_index: int = get_selected_focus_spell_global_index()

	if selected_index < 0:
		show_feedback("No learned " + get_selected_focus_element_display_name() + " spells yet.")
		update_focus_spell_menu_ui()
		return

	select_ability(selected_index)
	close_focus_spell_menu()
