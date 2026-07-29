extends Node
class_name PlayerControlRouter

signal quick_spell_changed(cursor: int, ability_index: int)
signal quick_item_selection_changed(slot_index: int)
signal focus_hold_changed(is_open: bool)

const QUICK_ITEM_ACTION: StringName = &"quick_item_cycle_use"
const QUICK_SPELL_PREVIOUS_ACTION: StringName = &"quick_spell_previous"
const QUICK_SPELL_NEXT_ACTION: StringName = &"quick_spell_next"

const LEGACY_DPAD_ACTIONS: Array[StringName] = [
	&"focus_element_left",
	&"focus_element_right",
	&"focus_spell_up",
	&"focus_spell_down",
	&"quick_item_up",
	&"quick_item_left",
	&"quick_item_right",
	&"quick_item_down",
	&"special_context",
]

@export_range(0.1, 0.6, 0.01) var quick_item_hold_seconds: float = 0.28
@export_range(0.4, 0.95, 0.05) var focus_stick_enter_deadzone: float = 0.72
@export_range(0.1, 0.7, 0.05) var focus_stick_exit_deadzone: float = 0.35
@export var favorite_spell_indices: Array[int] = [0, 1, 2]

var actor: CharacterBody3D
var ability_caster: Node
var quick_item_controller: Node
var action_state: PlayerActionState
var input_bootstrap: Node

var resolved_favorite_indices: Array[int] = []
var selected_favorite_cursor: int = 0
var selected_quick_item_slot: int = 0

var quick_item_button_down: bool = false
var quick_item_hold_elapsed: float = 0.0
var quick_item_hold_consumed: bool = false
var quick_item_device: int = -1

var focus_axis_x_latched: bool = false
var focus_axis_y_latched: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	actor = get_parent() as CharacterBody3D
	_resolve_bindings()
	call_deferred("_finish_setup")
	add_to_group("player_control_router")


func _finish_setup() -> void:
	_resolve_bindings()
	_sanitize_legacy_dpad_bindings()
	_refresh_favorite_indices()
	_initialize_selected_quick_item()
	_ensure_quick_loadout_hud()


func _process(delta: float) -> void:
	if quick_item_button_down and not quick_item_hold_consumed:
		quick_item_hold_elapsed += maxf(delta, 0.0)
		if quick_item_hold_elapsed >= quick_item_hold_seconds:
			quick_item_hold_consumed = true
			_use_selected_quick_item()


func _input(event: InputEvent) -> void:
	_resolve_bindings()

	if event.is_action_pressed("spell_menu"):
		if handle_focus_action(true):
			get_viewport().set_input_as_handled()
		return
	if event.is_action_released("spell_menu"):
		if handle_focus_action(false):
			get_viewport().set_input_as_handled()
		return

	if event is InputEventJoypadMotion and is_focus_open():
		if handle_focus_stick_motion(event as InputEventJoypadMotion):
			get_viewport().set_input_as_handled()
		return

	if not (event is InputEventJoypadButton):
		return
	var button_event: InputEventJoypadButton = event as InputEventJoypadButton

	if is_focus_open() and button_event.button_index in [
		JOY_BUTTON_DPAD_UP,
		JOY_BUTTON_DPAD_DOWN,
		JOY_BUTTON_DPAD_LEFT,
		JOY_BUTTON_DPAD_RIGHT,
	]:
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed(QUICK_SPELL_PREVIOUS_ACTION):
		cycle_quick_spell(-1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(QUICK_SPELL_NEXT_ACTION):
		cycle_quick_spell(1)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed(QUICK_ITEM_ACTION):
		handle_quick_item_button(button_event.device, true)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_released(QUICK_ITEM_ACTION):
		handle_quick_item_button(button_event.device, false)
		get_viewport().set_input_as_handled()


func handle_focus_action(pressed: bool) -> bool:
	_resolve_bindings()
	if ability_caster == null:
		return false
	if pressed:
		if ability_caster.has_method("open_focus_spell_menu"):
			ability_caster.call("open_focus_spell_menu")
			focus_hold_changed.emit(true)
			return true
		return false
	if ability_caster.has_method("close_focus_spell_menu"):
		ability_caster.call("close_focus_spell_menu")
		focus_axis_x_latched = false
		focus_axis_y_latched = false
		focus_hold_changed.emit(false)
		return true
	return false


func is_focus_open() -> bool:
	return (
		ability_caster != null
		and ability_caster.has_method("is_focus_spell_menu_open")
		and bool(ability_caster.call("is_focus_spell_menu_open"))
	)


func handle_focus_stick_motion(event: InputEventJoypadMotion) -> bool:
	if ability_caster == null:
		return false
	if event.axis == JOY_AXIS_RIGHT_X:
		if absf(event.axis_value) <= focus_stick_exit_deadzone:
			focus_axis_x_latched = false
			return false
		if focus_axis_x_latched or absf(event.axis_value) < focus_stick_enter_deadzone:
			return false
		focus_axis_x_latched = true
		if ability_caster.has_method("cycle_focus_element"):
			ability_caster.call("cycle_focus_element", 1 if event.axis_value > 0.0 else -1)
			return true
	if event.axis == JOY_AXIS_RIGHT_Y:
		if absf(event.axis_value) <= focus_stick_exit_deadzone:
			focus_axis_y_latched = false
			return false
		if focus_axis_y_latched or absf(event.axis_value) < focus_stick_enter_deadzone:
			return false
		focus_axis_y_latched = true
		if ability_caster.has_method("cycle_focus_spell"):
			ability_caster.call("cycle_focus_spell", 1 if event.axis_value > 0.0 else -1)
			return true
	return false


func cycle_quick_spell(direction: int) -> bool:
	_resolve_bindings()
	_refresh_favorite_indices()
	if ability_caster == null or resolved_favorite_indices.is_empty():
		_show_message("No quick spells are configured.")
		return false
	selected_favorite_cursor = wrapi(
		selected_favorite_cursor + direction,
		0,
		resolved_favorite_indices.size()
	)
	var ability_index: int = resolved_favorite_indices[selected_favorite_cursor]
	ability_caster.call("select_ability", ability_index, false)
	quick_spell_changed.emit(selected_favorite_cursor, ability_index)
	_show_message(
		"Quick spell "
		+ str(selected_favorite_cursor + 1)
		+ "/"
		+ str(resolved_favorite_indices.size())
		+ ": "
		+ get_selected_quick_spell_name()
	)
	return true


func _refresh_favorite_indices() -> void:
	resolved_favorite_indices.clear()
	if ability_caster == null:
		return
	var loadout: Variant = ability_caster.get("loadout")
	if loadout == null or not loadout.has_method("get_equipped_ability_count"):
		return
	var ability_count: int = int(loadout.call("get_equipped_ability_count"))
	for configured_index: int in favorite_spell_indices:
		if configured_index >= 0 and configured_index < ability_count:
			if not resolved_favorite_indices.has(configured_index):
				resolved_favorite_indices.append(configured_index)
		if resolved_favorite_indices.size() >= 3:
			break
	for ability_index: int in range(ability_count):
		if resolved_favorite_indices.size() >= 3:
			break
		if not resolved_favorite_indices.has(ability_index):
			resolved_favorite_indices.append(ability_index)
	if resolved_favorite_indices.is_empty():
		selected_favorite_cursor = 0
		return
	var current_index: int = int(ability_caster.get("current_ability_index"))
	var current_cursor: int = resolved_favorite_indices.find(current_index)
	if current_cursor >= 0:
		selected_favorite_cursor = current_cursor
	else:
		selected_favorite_cursor = clampi(
			selected_favorite_cursor,
			0,
			resolved_favorite_indices.size() - 1
		)


func get_quick_spell_names() -> Array[String]:
	_refresh_favorite_indices()
	var names: Array[String] = []
	if ability_caster == null:
		return names
	var loadout: Variant = ability_caster.get("loadout")
	if loadout == null or not loadout.has_method("get_equipped_ability"):
		return names
	for ability_index: int in resolved_favorite_indices:
		var ability: Variant = loadout.call("get_equipped_ability", ability_index)
		names.append(str(ability.get("display_name")) if ability != null else "Empty")
	return names


func get_selected_quick_spell_name() -> String:
	var names: Array[String] = get_quick_spell_names()
	if names.is_empty():
		return "None"
	selected_favorite_cursor = clampi(selected_favorite_cursor, 0, names.size() - 1)
	return names[selected_favorite_cursor]


func get_selected_quick_spell_cursor() -> int:
	_refresh_favorite_indices()
	return selected_favorite_cursor


func handle_quick_item_button(device: int, pressed: bool) -> bool:
	if pressed:
		if quick_item_button_down:
			return false
		quick_item_button_down = true
		quick_item_hold_elapsed = 0.0
		quick_item_hold_consumed = false
		quick_item_device = device
		return true
	if not quick_item_button_down or (quick_item_device >= 0 and device != quick_item_device):
		return false
	quick_item_button_down = false
	quick_item_device = -1
	if not quick_item_hold_consumed:
		cycle_quick_item()
	quick_item_hold_elapsed = 0.0
	quick_item_hold_consumed = false
	return true


func cycle_quick_item() -> bool:
	_resolve_bindings()
	if quick_item_controller == null:
		return false
	for step: int in range(1, 5):
		var candidate: int = (selected_quick_item_slot + step) % 4
		var item: Variant = quick_item_controller.call("get_slot_item", candidate)
		if item == null:
			continue
		selected_quick_item_slot = candidate
		quick_item_selection_changed.emit(selected_quick_item_slot)
		_show_selected_quick_item()
		return true
	_show_message("No quick items are equipped.")
	return false


func _use_selected_quick_item() -> bool:
	_resolve_bindings()
	if quick_item_controller == null:
		return false
	return bool(quick_item_controller.call("try_use_slot", selected_quick_item_slot))


func _initialize_selected_quick_item() -> void:
	if quick_item_controller == null:
		return
	for slot_index: int in range(4):
		if quick_item_controller.call("get_slot_item", slot_index) != null:
			selected_quick_item_slot = slot_index
			return


func get_selected_quick_item_slot() -> int:
	return selected_quick_item_slot


func get_quick_item_neighbor_slot(direction: int) -> int:
	if quick_item_controller == null:
		return -1
	for step: int in range(1, 5):
		var candidate: int = posmod(selected_quick_item_slot + step * direction, 4)
		if quick_item_controller.call("get_slot_item", candidate) != null:
			return candidate
	return -1


func get_hand_role_summary() -> Dictionary:
	_resolve_bindings()
	if input_bootstrap != null and input_bootstrap.has_method("get_hand_role_summary"):
		return input_bootstrap.call("get_hand_role_summary") as Dictionary
	return {
		"preset": "combat_right_magic_left",
		"focus": "L",
		"cast": "ZL",
		"light": "R",
		"heavy": "ZR",
	}


func _show_selected_quick_item() -> void:
	if quick_item_controller == null:
		return
	var item: Variant = quick_item_controller.call(
		"get_slot_item",
		selected_quick_item_slot
	)
	if item == null:
		_show_message("Quick item slot is empty.")
		return
	var count: int = int(quick_item_controller.call(
		"get_slot_charges",
		selected_quick_item_slot
	))
	_show_message("Quick item: " + str(item.get("display_name")) + " ×" + str(count))


func _sanitize_legacy_dpad_bindings() -> void:
	for action_name: StringName in LEGACY_DPAD_ACTIONS:
		if not InputMap.has_action(action_name):
			continue
		for input_event: InputEvent in InputMap.action_get_events(action_name):
			if not (input_event is InputEventJoypadButton):
				continue
			var button: int = (input_event as InputEventJoypadButton).button_index
			if button in [
				JOY_BUTTON_DPAD_UP,
				JOY_BUTTON_DPAD_DOWN,
				JOY_BUTTON_DPAD_LEFT,
				JOY_BUTTON_DPAD_RIGHT,
			]:
				InputMap.action_erase_event(action_name, input_event)


func _ensure_quick_loadout_hud() -> void:
	if actor == null or actor.get_node_or_null("QuickLoadoutHUD") != null:
		return
	var hud_script: Script = load("res://scripts/ui/player_quick_loadout_hud.gd") as Script
	if hud_script == null:
		return
	var hud: Node = hud_script.new()
	hud.name = "QuickLoadoutHUD"
	actor.add_child(hud)


func _resolve_bindings() -> void:
	if actor == null or not is_instance_valid(actor):
		actor = get_parent() as CharacterBody3D
	if actor == null:
		return
	if ability_caster == null or not is_instance_valid(ability_caster):
		ability_caster = actor.get_node_or_null("AbilityCaster")
	if quick_item_controller == null or not is_instance_valid(quick_item_controller):
		quick_item_controller = actor.get_node_or_null("PlayerQuickItemController")
	if action_state == null or not is_instance_valid(action_state):
		action_state = actor.get_node_or_null("PlayerActionState") as PlayerActionState
	if input_bootstrap == null or not is_instance_valid(input_bootstrap):
		input_bootstrap = actor.get_node_or_null("WeaponController/WeaponInputBootstrap")


func _show_message(message: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", message)
	else:
		print(message)


func get_debug_data() -> Dictionary:
	return {
		"focus_open": is_focus_open(),
		"favorite_indices": resolved_favorite_indices.duplicate(),
		"favorite_cursor": selected_favorite_cursor,
		"favorite_name": get_selected_quick_spell_name(),
		"quick_item_slot": selected_quick_item_slot,
		"quick_item_down": quick_item_button_down,
		"quick_item_hold": snappedf(quick_item_hold_elapsed, 0.01),
		"quick_item_consumed": quick_item_hold_consumed,
		"hand_roles": get_hand_role_summary(),
	}
