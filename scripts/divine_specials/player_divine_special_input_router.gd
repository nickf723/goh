extends Node


const RadialMenuScript = preload(
	"res://scripts/ui/divine_special_radial_menu.gd"
)

@export_group("Shoulder Chord")
@export var left_shoulder_button: int = 9
@export var right_shoulder_button: int = 10
@export var cancel_button: int = 1
@export_range(0.04, 0.3, 0.01) var simultaneous_window_seconds: float = 0.10
@export_range(0.1, 0.6, 0.01) var radial_hold_seconds: float = 0.18

@export_group("Radial Selection")
@export var right_stick_x_axis: int = 2
@export var right_stick_y_axis: int = 3
@export_range(0.2, 0.95, 0.05) var right_stick_deadzone: float = 0.55
@export_range(0.05, 1.0, 0.05) var radial_time_scale: float = 0.35

@export_group("Debug")
@export var force_debug_catalog_access: bool = false

var actor: CharacterBody3D
var special_controller: PlayerDivineSpecialController
var weapon_controller: WeaponController
var action_state: PlayerActionState
var radial_menu: Node

var device_states: Dictionary = {}
var active_device: int = -1
var previous_time_scale: float = 1.0
var applied_radial_time_scale: float = 1.0
var previous_focus_menu_open: bool = false
var last_availability_reason: String = ""
var last_activation_succeeded: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	actor = get_parent() as CharacterBody3D
	_resolve_bindings()
	add_to_group("divine_special_input_router")


func _exit_tree() -> void:
	if active_device >= 0:
		finish_active_chord(active_device, true, "router_exit")


func _process(_delta: float) -> void:
	if active_device < 0:
		return
	var state: Dictionary = _get_state(active_device)
	if not bool(state.get("chord_active", false)):
		return
	if not (
		bool(state.get("left_down", false))
		and bool(state.get("right_down", false))
	):
		return
	var now_msec: int = Time.get_ticks_msec()
	var chord_started_msec: int = int(state.get("chord_started_msec", now_msec))
	var held_seconds: float = float(now_msec - chord_started_msec) / 1000.0
	if (
		not bool(state.get("radial_open", false))
		and held_seconds >= radial_hold_seconds
	):
		open_radial_for_device(active_device)
		state = _get_state(active_device)
	if bool(state.get("radial_open", false)):
		update_selection_from_vector(_read_right_stick(active_device), active_device)


func _input(event: InputEvent) -> void:
	if not (event is InputEventJoypadButton):
		return
	var button_event: InputEventJoypadButton = event as InputEventJoypadButton
	var handled: bool = false
	if button_event.button_index in [left_shoulder_button, right_shoulder_button]:
		handled = handle_shoulder_button(
			button_event.device,
			button_event.button_index,
			button_event.pressed,
			Time.get_ticks_msec()
		)
	elif (
		button_event.pressed
		and button_event.button_index == cancel_button
		and is_chord_active(button_event.device)
	):
		handled = cancel_active_chord(button_event.device, "player_cancel")
	if handled:
		get_viewport().set_input_as_handled()


func handle_shoulder_button(
	device: int,
	button_index: int,
	pressed: bool,
	now_msec: int
) -> bool:
	if button_index not in [left_shoulder_button, right_shoulder_button]:
		return false
	var state: Dictionary = _get_state(device)
	var side: String = "left" if button_index == left_shoulder_button else "right"
	state[side + "_down"] = pressed
	if pressed:
		state[side + "_pressed_msec"] = now_msec
	device_states[device] = state

	if not pressed:
		if bool(state.get("chord_active", false)):
			finish_active_chord(device, false, "shoulder_release")
			return true
		_clear_device_lock_if_released(device)
		return false

	if bool(state.get("locked_until_release", false)):
		return false
	if bool(state.get("rejected_until_release", false)):
		return false
	if bool(state.get("chord_active", false)):
		return true
	if not (
		bool(state.get("left_down", false))
		and bool(state.get("right_down", false))
	):
		return false

	var left_pressed_msec: int = int(state.get("left_pressed_msec", now_msec))
	var right_pressed_msec: int = int(state.get("right_pressed_msec", now_msec))
	var separation_seconds: float = (
		float(absi(left_pressed_msec - right_pressed_msec)) / 1000.0
	)
	if separation_seconds > simultaneous_window_seconds:
		return false
	if try_begin_chord(device, now_msec):
		return true

	state = _get_state(device)
	state["rejected_until_release"] = true
	device_states[device] = state
	if last_availability_reason != "":
		_show_message(last_availability_reason)
	return false


func try_begin_chord(device: int, now_msec: int = -1) -> bool:
	_resolve_bindings()
	last_availability_reason = ""
	if active_device >= 0 and active_device != device:
		last_availability_reason = "Another controller already owns the Divine Special chord."
		return false
	var availability: Dictionary = get_gesture_availability()
	if not bool(availability.get("valid", false)):
		last_availability_reason = str(
			availability.get("reason", "Divine Special unavailable.")
		)
		return false

	if weapon_controller != null and weapon_controller.current_attack != null:
		if not weapon_controller.has_method("cancel_startup_attack_for_special"):
			last_availability_reason = "The current attack cannot convert into a Divine Special."
			return false
		if not bool(
			weapon_controller.call(
				"cancel_startup_attack_for_special",
				"divine_special_chord"
			)
		):
			last_availability_reason = "Finish the current attack before calling a Divine Special."
			return false

	var resolved_now_msec: int = now_msec if now_msec >= 0 else Time.get_ticks_msec()
	var state: Dictionary = _get_state(device)
	state["chord_active"] = true
	state["radial_open"] = false
	state["chord_started_msec"] = resolved_now_msec
	state["selected_index"] = _get_selected_available_index()
	state["rejected_until_release"] = false
	state["locked_until_release"] = false
	device_states[device] = state
	active_device = device
	last_activation_succeeded = false
	return true


func get_gesture_availability() -> Dictionary:
	_resolve_bindings()
	if special_controller == null:
		return {
			"valid": false,
			"reason": "Divine Special controller is missing.",
		}
	var force_debug: bool = _force_debug_access()
	var definition: DivineSpecialDefinition = special_controller.get_selected_special(
		force_debug
	)
	if definition == null:
		return {
			"valid": false,
			"reason": "No Divine Specials are unlocked.",
		}
	if special_controller.active_effect != null:
		return {
			"valid": false,
			"reason": "A Divine Special is already active.",
		}
	if special_controller.divine_charge + 0.001 < definition.required_charge:
		return {
			"valid": false,
			"reason": (
				"Divine Charge is only "
				+ str(roundi(special_controller.divine_charge))
				+ "% ready."
			),
		}
	if action_state != null and (
		action_state.is_defeated or action_state.is_staggered
	):
		return {
			"valid": false,
			"reason": "Grace cannot call a patron while incapacitated.",
		}
	if (
		action_state != null
		and action_state.is_attacking
		and (weapon_controller == null or weapon_controller.current_attack == null)
	):
		return {
			"valid": false,
			"reason": "The current attack cannot convert into a Divine Special.",
		}
	return {
		"valid": true,
		"definition": definition,
	}


func open_radial_for_device(device: int) -> bool:
	if active_device != device:
		return false
	var state: Dictionary = _get_state(device)
	if not bool(state.get("chord_active", false)):
		return false
	if bool(state.get("radial_open", false)):
		return true
	_resolve_bindings()
	var definitions: Array[DivineSpecialDefinition] = (
		special_controller.get_available_specials(_force_debug_access())
		if special_controller != null
		else []
	)
	if definitions.is_empty():
		cancel_active_chord(device, "no_available_specials")
		return false
	if radial_menu == null or not is_instance_valid(radial_menu):
		_create_radial_menu()
	if radial_menu == null:
		cancel_active_chord(device, "radial_missing")
		return false

	previous_time_scale = Engine.time_scale
	applied_radial_time_scale = minf(
		maxf(previous_time_scale, 0.01),
		maxf(radial_time_scale, 0.01)
	)
	Engine.time_scale = applied_radial_time_scale
	previous_focus_menu_open = (
		action_state.is_focus_menu_open
		if action_state != null
		else false
	)
	if action_state != null:
		action_state.set_focus_menu_open(true)

	var selected: int = clampi(
		int(state.get("selected_index", _get_selected_available_index())),
		0,
		definitions.size() - 1
	)
	state["selected_index"] = selected
	state["radial_open"] = true
	device_states[device] = state
	radial_menu.call("open_menu", definitions, selected, device)
	return true


func update_selection_from_vector(direction: Vector2, device: int) -> bool:
	if active_device != device:
		return false
	var state: Dictionary = _get_state(device)
	if not bool(state.get("radial_open", false)):
		return false
	if direction.length() < right_stick_deadzone:
		return false
	var definitions: Array[DivineSpecialDefinition] = (
		special_controller.get_available_specials(_force_debug_access())
		if special_controller != null
		else []
	)
	if definitions.is_empty():
		return false
	var new_index: int = selection_index_from_vector(direction, definitions.size())
	if new_index == int(state.get("selected_index", 0)):
		return false
	state["selected_index"] = new_index
	device_states[device] = state
	var definition: DivineSpecialDefinition = definitions[new_index]
	special_controller.select_special_by_id(
		definition.special_id,
		_force_debug_access()
	)
	if radial_menu != null and radial_menu.has_method("set_selection"):
		radial_menu.call("set_selection", new_index)
	return true


func selection_index_from_vector(direction: Vector2, count: int) -> int:
	if count <= 1:
		return 0
	var sector_angle: float = TAU / float(count)
	var angle: float = atan2(direction.y, direction.x)
	var normalized: float = fposmod(
		angle + PI * 0.5 + sector_angle * 0.5,
		TAU
	)
	return int(floor(normalized / sector_angle)) % count


func finish_active_chord(
	device: int,
	cancelled: bool = false,
	reason: String = "release"
) -> bool:
	if active_device != device:
		return false
	var state: Dictionary = _get_state(device)
	if not bool(state.get("chord_active", false)):
		return false
	var radial_was_open: bool = bool(state.get("radial_open", false))
	if radial_was_open:
		_close_radial_context()

	state["chord_active"] = false
	state["radial_open"] = false
	state["locked_until_release"] = true
	state["rejected_until_release"] = false
	device_states[device] = state
	active_device = -1

	if cancelled:
		last_activation_succeeded = false
		return true
	if special_controller == null:
		last_activation_succeeded = false
		return false
	last_activation_succeeded = special_controller.activate_selected_special(
		_force_debug_access()
	)
	if not last_activation_succeeded and reason != "":
		last_availability_reason = special_controller.last_failure
	return last_activation_succeeded


func cancel_active_chord(device: int, reason: String = "cancelled") -> bool:
	return finish_active_chord(device, true, reason)


func is_chord_active(device: int = -1) -> bool:
	if active_device < 0:
		return false
	if device >= 0 and active_device != device:
		return false
	var state: Dictionary = _get_state(active_device)
	return bool(state.get("chord_active", false))


func _close_radial_context() -> void:
	if radial_menu != null and radial_menu.has_method("close_menu"):
		radial_menu.call("close_menu")
	if action_state != null:
		action_state.set_focus_menu_open(previous_focus_menu_open)
	if is_equal_approx(Engine.time_scale, applied_radial_time_scale):
		Engine.time_scale = previous_time_scale


func _read_right_stick(device: int) -> Vector2:
	return Vector2(
		Input.get_joy_axis(device, right_stick_x_axis),
		Input.get_joy_axis(device, right_stick_y_axis)
	)


func _get_selected_available_index() -> int:
	if special_controller == null:
		return 0
	var definitions: Array[DivineSpecialDefinition] = (
		special_controller.get_available_specials(_force_debug_access())
	)
	var selected: DivineSpecialDefinition = special_controller.get_selected_special(
		_force_debug_access()
	)
	if selected == null:
		return 0
	for definition_index: int in range(definitions.size()):
		if definitions[definition_index].special_id == selected.special_id:
			return definition_index
	return 0


func _resolve_bindings() -> void:
	if actor == null or not is_instance_valid(actor):
		actor = get_parent() as CharacterBody3D
	if actor == null:
		return
	if special_controller == null or not is_instance_valid(special_controller):
		special_controller = actor.get_node_or_null(
			"DivineSpecialController"
		) as PlayerDivineSpecialController
	if weapon_controller == null or not is_instance_valid(weapon_controller):
		weapon_controller = actor.get_node_or_null(
			"WeaponController"
		) as WeaponController
	if action_state == null or not is_instance_valid(action_state):
		action_state = actor.get_node_or_null(
			"PlayerActionState"
		) as PlayerActionState
	if radial_menu == null or not is_instance_valid(radial_menu):
		radial_menu = actor.get_node_or_null("DivineSpecialRadialMenu")


func _create_radial_menu() -> void:
	if actor == null:
		return
	var menu: Node = RadialMenuScript.new()
	menu.name = "DivineSpecialRadialMenu"
	actor.add_child(menu)
	radial_menu = menu


func _get_state(device: int) -> Dictionary:
	if not device_states.has(device):
		device_states[device] = {
			"left_down": false,
			"right_down": false,
			"left_pressed_msec": -1000000,
			"right_pressed_msec": -1000000,
			"chord_active": false,
			"radial_open": false,
			"chord_started_msec": 0,
			"selected_index": 0,
			"rejected_until_release": false,
			"locked_until_release": false,
		}
	return device_states[device] as Dictionary


func _clear_device_lock_if_released(device: int) -> void:
	var state: Dictionary = _get_state(device)
	if (
		bool(state.get("left_down", false))
		or bool(state.get("right_down", false))
	):
		return
	state["rejected_until_release"] = false
	state["locked_until_release"] = false
	device_states[device] = state


func _force_debug_access() -> bool:
	return force_debug_catalog_access or OS.is_debug_build()


func _show_message(message: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", message)
