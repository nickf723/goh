extends "res://scripts/player/soul_grip_controller.gd"
class_name SoulGripSpellController

@export_group("Spell Channel")
@export var handled_spell_id: String = "soul_grip"
@export var channel_action: String = "cast_spell"
@export_range(0.1, 2.0, 0.05) var mouse_distance_step: float = 0.75

var channel_requested: bool = false
var active_ability: AbilityDefinition = null


func _ready() -> void:
	player = get_parent() as CharacterBody3D
	if player != null:
		action_state = player.get_node_or_null("PlayerActionState") as PlayerActionState

	ensure_spell_input_map()
	create_feedback_visuals()
	add_to_group("debuggable")
	add_to_group("soul_grip_controllers")
	add_to_group("player_ability_channels")


func _process(delta: float) -> void:
	if player == null:
		return

	if player.has_method("is_focus_spell_menu_open") and bool(player.call("is_focus_spell_menu_open")):
		cancel_ability_channel()
		clear_target_preview()
		return

	if not is_soul_grip_equipped():
		cancel_ability_channel()
		clear_target_preview()
		return

	if held_target != null and not held_target.is_being_manipulated():
		release_grip()

	if not channel_requested:
		if held_target != null:
			release_grip()
		update_target_preview()
		return

	if not Input.is_action_pressed(channel_action):
		cancel_ability_channel()
		update_target_preview()
		return

	if held_target == null:
		update_target_preview()
		acquisition_retry_timer -= delta
		if acquisition_retry_timer <= 0.0:
			try_begin_grip(false)
			acquisition_retry_timer = maxf(acquisition_retry_interval, 0.02)
		if held_target == null:
			return

	update_hold_controls(delta)
	update_target_pose()
	update_feedback_visuals()


func _unhandled_input(event: InputEvent) -> void:
	if not channel_requested or held_target == null:
		return

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if not mouse_event.pressed:
			return
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			hold_distance = clampf(
				hold_distance + mouse_distance_step,
				minimum_hold_distance,
				maximum_hold_distance
			)
			get_viewport().set_input_as_handled()
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			hold_distance = clampf(
				hold_distance - mouse_distance_step,
				minimum_hold_distance,
				maximum_hold_distance
			)
			get_viewport().set_input_as_handled()
		return

	if event is InputEventJoypadButton:
		var button_event := event as InputEventJoypadButton
		if (
			button_event.pressed
			and button_event.button_index in [
				JOY_BUTTON_LEFT_SHOULDER,
				JOY_BUTTON_RIGHT_SHOULDER,
				JOY_BUTTON_DPAD_UP,
				JOY_BUTTON_DPAD_DOWN,
			]
		):
			get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	cancel_ability_channel()


func can_handle_ability(ability: AbilityDefinition) -> bool:
	return ability != null and ability.get_spell_id() == handled_spell_id


func begin_ability_channel(source_player: Node3D, ability: AbilityDefinition) -> bool:
	if source_player != player or not can_handle_ability(ability):
		return false

	channel_requested = true
	active_ability = ability
	acquisition_retry_timer = maxf(acquisition_retry_interval, 0.02)
	update_target_preview()
	try_begin_grip(true)
	if held_target != null:
		show_message(
			"Soul Grasp: right stick aims, D-pad up/down changes depth, and L/R rotates."
		)
	return true


func cancel_ability_channel() -> void:
	channel_requested = false
	active_ability = null
	acquisition_retry_timer = 0.0
	release_grip()


func is_soul_grip_equipped() -> bool:
	if player == null:
		return false
	var ability_caster: Node = player.get_node_or_null("AbilityCaster")
	if ability_caster == null or not ability_caster.has_method("get_current_ability"):
		return false
	var ability: AbilityDefinition = ability_caster.call("get_current_ability") as AbilityDefinition
	return can_handle_ability(ability)


func ensure_spell_input_map() -> void:
	ensure_action(push_action, 0.2)
	ensure_action(pull_action, 0.2)
	ensure_action(rotate_left_action, 0.2)
	ensure_action(rotate_right_action, 0.2)

	ensure_key(rotate_left_action, KEY_Z)
	ensure_key(rotate_right_action, KEY_X)
	ensure_joy_button(push_action, JOY_BUTTON_DPAD_UP)
	ensure_joy_button(pull_action, JOY_BUTTON_DPAD_DOWN)
	ensure_joy_button(rotate_left_action, JOY_BUTTON_LEFT_SHOULDER)
	ensure_joy_button(rotate_right_action, JOY_BUTTON_RIGHT_SHOULDER)

	# The spell owns these controls only while its cast channel is active. Remove
	# the older D-pad rotation map so depth and rotation match object reproduction.
	remove_joy_button(rotate_left_action, JOY_BUTTON_DPAD_LEFT)
	remove_joy_button(rotate_right_action, JOY_BUTTON_DPAD_RIGHT)

	# Remove bindings written by the legacy dedicated-button controller. Soul
	# Grip is selected in Focus and held through the normal Cast action.
	remove_joy_button("soul_grip", JOY_BUTTON_LEFT_SHOULDER)
	remove_key_binding("soul_grip", KEY_F)
	remove_key_binding(push_action, KEY_T)
	remove_key_binding(pull_action, KEY_G)


func remove_key_binding(action_name: String, physical_keycode: Key) -> void:
	if not InputMap.has_action(action_name):
		return
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventKey:
			var key_event: InputEventKey = event as InputEventKey
			if key_event.physical_keycode == physical_keycode:
				InputMap.action_erase_event(action_name, event)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["spell_id"] = handled_spell_id
	data["equipped"] = is_soul_grip_equipped()
	data["channel_requested"] = channel_requested
	data["channel_action"] = channel_action
	data["shared_context_controls"] = true
	return data
