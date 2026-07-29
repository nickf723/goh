extends Node

const RadialMenuScript = preload(
	"res://scripts/ui/divine_special_radial_menu.gd"
)

@export_group("Divine Special Gesture")
@export var special_action: StringName = &"divine_special"
@export var special_button: int = JOY_BUTTON_DPAD_DOWN
@export var cancel_button: int = 1
@export_range(0.1, 0.6, 0.01) var radial_hold_seconds: float = 0.28

@export_group("Radial Selection")
@export var right_stick_x_axis: int = JOY_AXIS_RIGHT_X
@export var right_stick_y_axis: int = JOY_AXIS_RIGHT_Y
@export_range(0.2, 0.95, 0.05) var right_stick_deadzone: float = 0.55
@export_range(0.05, 1.0, 0.05) var radial_time_scale: float = 0.35

@export_group("Debug")
@export var force_debug_catalog_access: bool = false

var actor: CharacterBody3D
var special_controller: PlayerDivineSpecialController
var action_state: PlayerActionState
var radial_menu: Node

var active_device: int = -1
var button_down: bool = false
var gesture_active: bool = false
var radial_open: bool = false
var gesture_started_msec: int = 0
var selected_index: int = 0

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
	if gesture_active and active_device >= 0:
		finish_active_gesture(active_device, true, "router_exit")


func _process(_delta: float) -> void:
	if not gesture_active or not button_down or active_device < 0:
		return
	var held_seconds: float = (
		float(Time.get_ticks_msec() - gesture_started_msec) / 1000.0
	)
	if not radial_open and held_seconds >= radial_hold_seconds:
		open_radial_for_device(active_device)
	if radial_open:
		update_selection_from_vector(
			_read_right_stick(active_device),
			active_device
		)


func _input(event: InputEvent) -> void:
	if not (event is InputEventJoypadButton):
		return
	var button_event: InputEventJoypadButton = event as InputEventJoypadButton
	var handled: bool = false
	if button_event.button_index == special_button:
		handled = handle_special_button(
			button_event.device,
			button_event.pressed,
			Time.get_ticks_msec()
		)
	elif (
		button_event.pressed
		and button_event.button_index == cancel_button
		and is_gesture_active(button_event.device)
	):
		handled = cancel_active_gesture(button_event.device, "player_cancel")
	if handled:
		get_viewport().set_input_as_handled()


func handle_special_button(
	device: int,
	pressed: bool,
	now_msec: int = -1
) -> bool:
	if pressed:
		if active_device >= 0 and active_device != device:
			return false
		if button_down and active_device == device:
			return true
		active_device = device
		button_down = true
		if try_begin_gesture(device, now_msec):
			return true
		button_down = false
		active_device = -1
		if last_availability_reason != "":
			_show_message(last_availability_reason)
		# D-pad Down still belongs exclusively to Divine Specials even when the
		# current Special cannot activate.
		return true

	if active_device != device:
		return false
	button_down = false
	if gesture_active:
		return finish_active_gesture(device, false, "dpad_release")
	active_device = -1
	return true


func try_begin_gesture(device: int, now_msec: int = -1) -> bool:
	_resolve_bindings()
	last_availability_reason = ""
	if active_device >= 0 and active_device != device:
		last_availability_reason = "Another controller already owns the Divine Special input."
		return false
	var availability: Dictionary = get_gesture_availability()
	if not bool(availability.get("valid", false)):
		last_availability_reason = str(
			availability.get("reason", "Divine Special unavailable.")
		)
		return false
	active_device = device
	button_down = true
	gesture_active = true
	radial_open = false
	gesture_started_msec = (
		now_msec if now_msec >= 0 else Time.get_ticks_msec()
	)
	selected_index = _get_selected_available_index()
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
	if action_state != null and action_state.is_attacking:
		return {
			"valid": false,
			"reason": "Finish the current attack before calling a Divine Special.",
		}
	return {
		"valid": true,
		"definition": definition,
	}


func open_radial_for_device(device: int) -> bool:
	if active_device != device or not gesture_active:
		return false
	if radial_open:
		return true
	_resolve_bindings()
	var definitions: Array[DivineSpecialDefinition] = (
		special_controller.get_available_specials(_force_debug_access())
		if special_controller != null
		else []
	)
	if definitions.is_empty():
		cancel_active_gesture(device, "no_available_specials")
		return false
	if radial_menu == null or not is_instance_valid(radial_menu):
		_create_radial_menu()
	if radial_menu == null:
		cancel_active_gesture(device, "radial_missing")
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

	selected_index = clampi(selected_index, 0, definitions.size() - 1)
	radial_open = true
	radial_menu.call("open_menu", definitions, selected_index, device)
	return true


func update_selection_from_vector(direction: Vector2, device: int) -> bool:
	if active_device != device or not radial_open:
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
	if new_index == selected_index:
		return false
	selected_index = new_index
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


func finish_active_gesture(
	device: int,
	cancelled: bool = false,
	reason: String = "release"
) -> bool:
	if active_device != device or not gesture_active:
		return false
	if radial_open:
		_close_radial_context()
	gesture_active = false
	radial_open = false
	button_down = false
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


func cancel_active_gesture(device: int, reason: String = "cancelled") -> bool:
	return finish_active_gesture(device, true, reason)


func is_gesture_active(device: int = -1) -> bool:
	if not gesture_active or active_device < 0:
		return false
	return device < 0 or device == active_device


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


# Compatibility aliases for older debug tools while the input grammar migrates.
func try_begin_chord(device: int, now_msec: int = -1) -> bool:
	return try_begin_gesture(device, now_msec)


func finish_active_chord(
	device: int,
	cancelled: bool = false,
	reason: String = "release"
) -> bool:
	return finish_active_gesture(device, cancelled, reason)


func cancel_active_chord(device: int, reason: String = "cancelled") -> bool:
	return cancel_active_gesture(device, reason)


func is_chord_active(device: int = -1) -> bool:
	return is_gesture_active(device)


func handle_shoulder_button(
	_device: int,
	_button_index: int,
	_pressed: bool,
	_now_msec: int
) -> bool:
	return false


func _force_debug_access() -> bool:
	return force_debug_catalog_access or OS.is_debug_build()


func _show_message(message: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", message)
	else:
		print(message)


func get_debug_data() -> Dictionary:
	return {
		"active_device": active_device,
		"button_down": button_down,
		"gesture_active": gesture_active,
		"radial_open": radial_open,
		"selected_index": selected_index,
		"last_availability_reason": last_availability_reason,
		"last_activation_succeeded": last_activation_succeeded,
		"input": "D-pad Down",
	}
