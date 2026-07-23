extends Node
class_name WeaponInputBootstrap

@export_group("Light Attack")
@export var light_action_name: String = "weapon_light_attack"
@export var light_keyboard_key: Key = KEY_J
@export var light_mouse_button: MouseButton = MOUSE_BUTTON_LEFT
@export var light_joypad_button: JoyButton = JOY_BUTTON_LEFT_SHOULDER

@export_group("Heavy Attack")
@export var heavy_action_name: String = "weapon_heavy_attack"
@export var heavy_keyboard_key: Key = KEY_K
@export var heavy_mouse_button: MouseButton = MOUSE_BUTTON_XBUTTON1
@export var heavy_joypad_button: JoyButton = JOY_BUTTON_RIGHT_SHOULDER


func _ready() -> void:
	ensure_complete_attack_action(
		light_action_name,
		light_keyboard_key,
		light_mouse_button,
		light_joypad_button
	)
	ensure_complete_attack_action(
		heavy_action_name,
		heavy_keyboard_key,
		heavy_mouse_button,
		heavy_joypad_button
	)
	remove_mouse_event(heavy_action_name, MOUSE_BUTTON_RIGHT)
	remove_joypad_event(light_action_name, JOY_BUTTON_X)
	add_to_group("debuggable")


func ensure_complete_attack_action(
	action_name: String,
	keyboard_key: Key,
	mouse_button: MouseButton,
	joypad_button: JoyButton
) -> void:
	ensure_action(action_name)
	ensure_key_event(action_name, keyboard_key)
	ensure_mouse_event(action_name, mouse_button)
	ensure_joypad_event(action_name, joypad_button)


func ensure_action(action_name: String) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, 0.2)


func ensure_key_event(action_name: String, physical_keycode: Key) -> void:
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventKey:
			var key_event: InputEventKey = event as InputEventKey
			if key_event.physical_keycode == physical_keycode:
				return

	var new_key_event: InputEventKey = InputEventKey.new()
	new_key_event.physical_keycode = physical_keycode
	InputMap.action_add_event(action_name, new_key_event)


func ensure_mouse_event(action_name: String, button_index: MouseButton) -> void:
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventMouseButton:
			var mouse_event: InputEventMouseButton = event as InputEventMouseButton
			if mouse_event.button_index == button_index:
				return

	var new_mouse_event: InputEventMouseButton = InputEventMouseButton.new()
	new_mouse_event.button_index = button_index
	InputMap.action_add_event(action_name, new_mouse_event)


func ensure_joypad_event(action_name: String, button_index: JoyButton) -> void:
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventJoypadButton:
			var joy_event: InputEventJoypadButton = event as InputEventJoypadButton
			if joy_event.button_index == button_index:
				return

	var new_joy_event: InputEventJoypadButton = InputEventJoypadButton.new()
	new_joy_event.button_index = button_index
	InputMap.action_add_event(action_name, new_joy_event)


func remove_mouse_event(action_name: String, button_index: MouseButton) -> void:
	if not InputMap.has_action(action_name):
		return
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventMouseButton:
			var mouse_event: InputEventMouseButton = event as InputEventMouseButton
			if mouse_event.button_index == button_index:
				InputMap.action_erase_event(action_name, event)


func remove_joypad_event(action_name: String, button_index: JoyButton) -> void:
	if not InputMap.has_action(action_name):
		return
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventJoypadButton:
			var joy_event: InputEventJoypadButton = event as InputEventJoypadButton
			if joy_event.button_index == button_index:
				InputMap.action_erase_event(action_name, event)


func get_debug_data() -> Dictionary:
	return {
		"light_action": light_action_name,
		"light_events": InputMap.action_get_events(light_action_name).size() if InputMap.has_action(light_action_name) else 0,
		"heavy_action": heavy_action_name,
		"heavy_events": InputMap.action_get_events(heavy_action_name).size() if InputMap.has_action(heavy_action_name) else 0,
		"controller_pair": "L/R shoulders",
		"focus_cast_pair": "ZL/ZR triggers",
		"complete_keyboard_mouse_controller_pairs": true,
	}
