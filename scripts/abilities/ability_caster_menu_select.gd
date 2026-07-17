extends "res://scripts/abilities/ability_caster.gd"

# Prototype wrapper for the focus spell menu.
# The base AbilityCaster still owns casting, loadout, charge logic, and menu data.
# This wrapper changes the focus menu contract and delegates simple spell upgrade
# payload hooks to SpellModifierRegistry.

const SpellModifiers = preload("res://scripts/abilities/spell_modifier_registry.gd")


func cast_from_player(player: Node3D, cast_lock_duration: float = 0.18, allow_charge: bool = true) -> bool:
	var ability: AbilityDefinition = get_current_ability()

	if SpellModifiers.has_active_payload_modifier_for_ability(ability):
		return cast_with_spell_modifier(player, ability, cast_lock_duration)

	return super.cast_from_player(player, cast_lock_duration, allow_charge)


func cast_with_spell_modifier(player: Node3D, ability: AbilityDefinition, cast_lock_duration: float) -> bool:
	if ability == null:
		return false

	var payload_override: Resource = SpellModifiers.build_modified_payload_for_ability(ability)
	var modifier_lock_duration: float = SpellModifiers.get_cast_lock_duration_for_ability(ability, cast_lock_duration)
	var modifier_extra_mana_cost: int = SpellModifiers.get_cast_extra_mana_cost_for_ability(ability)

	var did_cast: bool = execute_ability_from_player(
		player,
		ability,
		modifier_lock_duration,
		payload_override,
		0.0,
		modifier_extra_mana_cost
	)

	if did_cast:
		var cast_message: String = SpellModifiers.get_cast_message_for_ability(ability)
		if cast_message != "":
			show_feedback(cast_message)

	return did_cast


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
