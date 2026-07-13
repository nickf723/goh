extends Node
class_name WeaponInputBootstrap

@export var heavy_action_name: String = "weapon_heavy_attack"
@export var keyboard_key: Key = KEY_K
@export var joypad_button_index: int = 5
@export var preserve_existing_input_categories: bool = true


func _ready() -> void:
	ensure_action(heavy_action_name)
	ensure_key_event(heavy_action_name, keyboard_key)
	ensure_joypad_event(heavy_action_name, joypad_button_index)
	add_to_group("debuggable")


func ensure_action(action_name: String) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, 0.2)


func ensure_key_event(action_name: String, physical_keycode: Key) -> void:
	var has_key_category: bool = false

	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventKey:
			has_key_category = true
			var key_event: InputEventKey = event as InputEventKey
			if key_event.physical_keycode == physical_keycode:
				return

	if preserve_existing_input_categories and has_key_category:
		return

	var new_key_event: InputEventKey = InputEventKey.new()
	new_key_event.physical_keycode = physical_keycode
	InputMap.action_add_event(action_name, new_key_event)


func ensure_joypad_event(action_name: String, button_index: int) -> void:
	var has_joypad_category: bool = false

	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventJoypadButton:
			has_joypad_category = true
			var joy_event: InputEventJoypadButton = event as InputEventJoypadButton
			if joy_event.button_index == button_index:
				return

	if preserve_existing_input_categories and has_joypad_category:
		return

	var new_joy_event: InputEventJoypadButton = InputEventJoypadButton.new()
	new_joy_event.button_index = button_index
	InputMap.action_add_event(action_name, new_joy_event)


func get_debug_data() -> Dictionary:
	return {
		"heavy_action": heavy_action_name,
		"events": InputMap.action_get_events(heavy_action_name).size() if InputMap.has_action(heavy_action_name) else 0,
		"preserves_existing_categories": preserve_existing_input_categories,
	}
