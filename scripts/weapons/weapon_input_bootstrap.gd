extends Node
class_name WeaponInputBootstrap

signal hand_role_preset_changed(preset: int, summary: Dictionary)

const PlayerControlRouterScript = preload(
	"res://scripts/input/player_control_router_contextual.gd"
)
const PlayerPresentationScript = preload(
	"res://scripts/ui/player_hud_combat_presentation.gd"
)
const ShowcaseTelemetryGateScript = preload(
	"res://scripts/ui/showcase_telemetry_gate.gd"
)

const PRESET_COMBAT_RIGHT_MAGIC_LEFT: int = 0
const PRESET_COMBAT_LEFT_MAGIC_RIGHT: int = 1

const LEFT_TRIGGER_AXIS: int = 4
const RIGHT_TRIGGER_AXIS: int = 5

const QUICK_ITEM_ACTION: StringName = &"quick_item_cycle_use"
const QUICK_SPELL_PREVIOUS_ACTION: StringName = &"quick_spell_previous"
const QUICK_SPELL_NEXT_ACTION: StringName = &"quick_spell_next"
const DIVINE_SPECIAL_ACTION: StringName = &"divine_special"

@export_group("Hand Roles")
@export_enum(
	"Combat Right / Magic Left",
	"Combat Left / Magic Right"
) var hand_role_preset: int = PRESET_COMBAT_RIGHT_MAGIC_LEFT
@export var allow_debug_preset_toggle: bool = true

@export_group("Light Attack")
@export var light_action_name: StringName = &"weapon_light_attack"
@export var light_keyboard_key: Key = KEY_J
@export var light_mouse_button: MouseButton = MOUSE_BUTTON_LEFT

@export_group("Heavy Attack")
@export var heavy_action_name: StringName = &"weapon_heavy_attack"
@export var heavy_keyboard_key: Key = KEY_K
@export var heavy_mouse_button: MouseButton = MOUSE_BUTTON_XBUTTON1

@export_group("Magic")
@export var focus_action_name: StringName = &"spell_menu"
@export var cast_action_name: StringName = &"cast_spell"


func _ready() -> void:
	ensure_action(light_action_name)
	ensure_action(heavy_action_name)
	ensure_action(focus_action_name)
	ensure_action(cast_action_name)
	ensure_key_event(light_action_name, light_keyboard_key)
	ensure_mouse_event(light_action_name, light_mouse_button)
	ensure_key_event(heavy_action_name, heavy_keyboard_key)
	ensure_mouse_event(heavy_action_name, heavy_mouse_button)
	remove_mouse_event(heavy_action_name, MOUSE_BUTTON_RIGHT)
	ensure_dpad_actions()
	apply_hand_role_preset(hand_role_preset, false)
	call_deferred("install_player_control_router")
	call_deferred("install_player_presentation_polish")
	call_deferred("install_showcase_telemetry_gate")
	add_to_group("debuggable")


func _input(event: InputEvent) -> void:
	if not allow_debug_preset_toggle or not OS.is_debug_build():
		return
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.physical_keycode != KEY_F4 and key_event.keycode != KEY_F4:
		return
	var next_preset: int = (
		PRESET_COMBAT_LEFT_MAGIC_RIGHT
		if hand_role_preset == PRESET_COMBAT_RIGHT_MAGIC_LEFT
		else PRESET_COMBAT_RIGHT_MAGIC_LEFT
	)
	set_hand_role_preset(next_preset, true)
	get_viewport().set_input_as_handled()


func set_hand_role_preset(preset: int, show_feedback: bool = true) -> void:
	apply_hand_role_preset(preset, show_feedback)


func apply_hand_role_preset(preset: int, show_feedback: bool = true) -> void:
	hand_role_preset = clampi(
		preset,
		PRESET_COMBAT_RIGHT_MAGIC_LEFT,
		PRESET_COMBAT_LEFT_MAGIC_RIGHT
	)

	for action_name: StringName in [
		light_action_name,
		heavy_action_name,
		focus_action_name,
		cast_action_name,
	]:
		remove_controller_events(action_name)

	if hand_role_preset == PRESET_COMBAT_LEFT_MAGIC_RIGHT:
		ensure_joypad_button(light_action_name, JOY_BUTTON_LEFT_SHOULDER)
		ensure_joypad_motion(heavy_action_name, LEFT_TRIGGER_AXIS, 1.0)
		ensure_joypad_button(focus_action_name, JOY_BUTTON_RIGHT_SHOULDER)
		ensure_joypad_motion(cast_action_name, RIGHT_TRIGGER_AXIS, 1.0)
	else:
		ensure_joypad_button(light_action_name, JOY_BUTTON_RIGHT_SHOULDER)
		ensure_joypad_motion(heavy_action_name, RIGHT_TRIGGER_AXIS, 1.0)
		ensure_joypad_button(focus_action_name, JOY_BUTTON_LEFT_SHOULDER)
		ensure_joypad_motion(cast_action_name, LEFT_TRIGGER_AXIS, 1.0)

	var summary: Dictionary = get_hand_role_summary()
	hand_role_preset_changed.emit(hand_role_preset, summary)
	if show_feedback:
		show_message(
			"Controls: "
			+ str(summary.get("display_name", "Hand roles updated"))
		)


func ensure_dpad_actions() -> void:
	ensure_action(QUICK_ITEM_ACTION)
	ensure_action(QUICK_SPELL_PREVIOUS_ACTION)
	ensure_action(QUICK_SPELL_NEXT_ACTION)
	ensure_action(DIVINE_SPECIAL_ACTION)

	remove_controller_events(QUICK_ITEM_ACTION)
	remove_controller_events(QUICK_SPELL_PREVIOUS_ACTION)
	remove_controller_events(QUICK_SPELL_NEXT_ACTION)
	remove_controller_events(DIVINE_SPECIAL_ACTION)

	ensure_joypad_button(QUICK_ITEM_ACTION, JOY_BUTTON_DPAD_UP)
	ensure_joypad_button(QUICK_SPELL_PREVIOUS_ACTION, JOY_BUTTON_DPAD_LEFT)
	ensure_joypad_button(QUICK_SPELL_NEXT_ACTION, JOY_BUTTON_DPAD_RIGHT)
	ensure_joypad_button(DIVINE_SPECIAL_ACTION, JOY_BUTTON_DPAD_DOWN)


func install_player_control_router() -> void:
	var weapon_controller: Node = get_parent()
	var player: Node = weapon_controller.get_parent() if weapon_controller != null else null
	if player == null or player.get_node_or_null("PlayerControlRouter") != null:
		return
	var router: Node = PlayerControlRouterScript.new()
	router.name = "PlayerControlRouter"
	player.add_child(router)


func install_player_presentation_polish() -> void:
	var weapon_controller: Node = get_parent()
	var player: Node = weapon_controller.get_parent() if weapon_controller != null else null
	if (
		player == null
		or player.get_node_or_null("PlayerHUDCombatPresentation") != null
	):
		return
	var presentation: Node = PlayerPresentationScript.new()
	presentation.name = "PlayerHUDCombatPresentation"
	player.add_child(presentation)


func install_showcase_telemetry_gate() -> void:
	var weapon_controller: Node = get_parent()
	var player: Node = weapon_controller.get_parent() if weapon_controller != null else null
	if (
		player == null
		or player.get_node_or_null("ShowcaseTelemetryGate") != null
	):
		return
	var gate: Node = ShowcaseTelemetryGateScript.new()
	gate.name = "ShowcaseTelemetryGate"
	player.add_child(gate)


func ensure_action(action_name: StringName) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, 0.2)


func ensure_key_event(action_name: StringName, physical_keycode: Key) -> void:
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventKey:
			var key_event: InputEventKey = event as InputEventKey
			if (
				key_event.physical_keycode == physical_keycode
				or key_event.keycode == physical_keycode
			):
				return
	var new_event: InputEventKey = InputEventKey.new()
	new_event.physical_keycode = physical_keycode
	InputMap.action_add_event(action_name, new_event)


func ensure_mouse_event(action_name: StringName, button_index: MouseButton) -> void:
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventMouseButton:
			var mouse_event: InputEventMouseButton = event as InputEventMouseButton
			if mouse_event.button_index == button_index:
				return
	var new_event: InputEventMouseButton = InputEventMouseButton.new()
	new_event.button_index = button_index
	InputMap.action_add_event(action_name, new_event)


func ensure_joypad_button(action_name: StringName, button_index: int) -> void:
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventJoypadButton:
			var joy_event: InputEventJoypadButton = event as InputEventJoypadButton
			if joy_event.button_index == button_index:
				return
	var new_event: InputEventJoypadButton = InputEventJoypadButton.new()
	new_event.button_index = button_index
	InputMap.action_add_event(action_name, new_event)


func ensure_joypad_motion(
	action_name: StringName,
	axis: int,
	axis_value: float
) -> void:
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventJoypadMotion:
			var motion_event: InputEventJoypadMotion = event as InputEventJoypadMotion
			if (
				motion_event.axis == axis
				and is_equal_approx(motion_event.axis_value, axis_value)
			):
				return
	var new_event: InputEventJoypadMotion = InputEventJoypadMotion.new()
	new_event.axis = axis
	new_event.axis_value = axis_value
	InputMap.action_add_event(action_name, new_event)


func remove_controller_events(action_name: StringName) -> void:
	if not InputMap.has_action(action_name):
		return
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			InputMap.action_erase_event(action_name, event)


func remove_mouse_event(action_name: StringName, button_index: MouseButton) -> void:
	if not InputMap.has_action(action_name):
		return
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventMouseButton:
			var mouse_event: InputEventMouseButton = event as InputEventMouseButton
			if mouse_event.button_index == button_index:
				InputMap.action_erase_event(action_name, event)


func get_hand_role_summary() -> Dictionary:
	if hand_role_preset == PRESET_COMBAT_LEFT_MAGIC_RIGHT:
		return {
			"preset": "combat_left_magic_right",
			"display_name": "Combat Left / Magic Right",
			"light": "L",
			"heavy": "ZL",
			"focus": "R",
			"cast": "ZR",
		}
	return {
		"preset": "combat_right_magic_left",
		"display_name": "Combat Right / Magic Left",
		"light": "R",
		"heavy": "ZR",
		"focus": "L",
		"cast": "ZL",
	}


func show_message(message: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", message)
	else:
		print(message)


func get_debug_data() -> Dictionary:
	return {
		"hand_roles": get_hand_role_summary(),
		"quick_item_action": str(QUICK_ITEM_ACTION),
		"quick_spell_previous_action": str(QUICK_SPELL_PREVIOUS_ACTION),
		"quick_spell_next_action": str(QUICK_SPELL_NEXT_ACTION),
		"divine_special_action": str(DIVINE_SPECIAL_ACTION),
		"authoritative_controller_bindings": true,
		"showcase_telemetry_gate": true,
	}
