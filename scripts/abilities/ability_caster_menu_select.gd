extends "res://scripts/abilities/ability_caster.gd"

# Prototype wrapper for the focus spell menu.
# The base AbilityCaster still owns casting, loadout, charge logic, and menu data.
# This wrapper changes the focus menu contract and hosts tiny prototype upgrade hooks
# that are safer to iterate before a full modifier engine exists.

const PIERCE_ICE_LANCE_UNLOCK_ID: String = "piercing_ice_lance"
const ICE_LANCE_SPELL_ID: String = "ice_lance"

@export_group("Piercing Ice Lance")
@export var piercing_ice_lance_extra_mana_cost: int = 0
@export var piercing_ice_lance_lock_duration: float = 0.18


func cast_from_player(player: Node3D, cast_lock_duration: float = 0.18, allow_charge: bool = true) -> bool:
	var ability: AbilityDefinition = get_current_ability()

	if should_use_piercing_ice_lance(ability):
		var payload_override: Resource = make_piercing_ice_lance_payload(ability)
		var did_cast: bool = execute_ability_from_player(
			player,
			ability,
			max(cast_lock_duration, piercing_ice_lance_lock_duration),
			payload_override,
			0.0,
			piercing_ice_lance_extra_mana_cost
		)

		if did_cast:
			show_feedback("Piercing Ice Lance.")

		return did_cast

	return super.cast_from_player(player, cast_lock_duration, allow_charge)


func should_use_piercing_ice_lance(ability: AbilityDefinition) -> bool:
	if ability == null:
		return false

	if not GameState.has_method("has_unlock"):
		return false

	if not GameState.has_unlock(PIERCE_ICE_LANCE_UNLOCK_ID):
		return false

	if ability.element.to_lower() != "ice":
		return false

	if ability.has_method("get_spell_id"):
		return ability.get_spell_id() == ICE_LANCE_SPELL_ID

	return ability.display_name.to_lower() == "ice lance"


func make_piercing_ice_lance_payload(ability: AbilityDefinition) -> Resource:
	if ability == null:
		return null

	var base_payload: Resource = null

	if ability.has_method("get_action_payload"):
		base_payload = ability.get_action_payload()
	elif ability.payload != null:
		base_payload = ability.payload

	if not (base_payload is DamagePayload):
		return base_payload

	var duplicate_payload: Resource = base_payload.duplicate(true)

	if not (duplicate_payload is DamagePayload):
		return base_payload

	var piercing_payload: DamagePayload = duplicate_payload as DamagePayload
	piercing_payload.amount = max(piercing_payload.amount, 2)
	piercing_payload.stance_damage = max(piercing_payload.stance_damage + 1, 5)
	piercing_payload.status_duration *= 1.15
	piercing_payload.source_name = "Piercing Ice Lance"

	var piercing_tags: Array[String] = []
	for tag: String in piercing_payload.tags:
		piercing_tags.append(tag)

	for tag: String in ["piercing", "upgrade", "ice_lance"]:
		if not piercing_tags.has(tag):
			piercing_tags.append(tag)

	piercing_payload.tags = piercing_tags
	return piercing_payload


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
