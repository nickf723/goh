extends Node
class_name PlayerAerialLocomotion

signal traversal_state_changed(previous_state: String, new_state: String)
signal flight_started(reservation_fraction: float)
signal flight_stopped(controlled_descent: bool)
signal hover_updated(remaining_seconds: float, maximum_seconds: float)

const ElementVisuals = preload("res://scripts/visuals/element_visuals.gd")

@export_group("Progression Unlocks")
@export var double_jump_unlocked: bool = false
@export var hover_unlocked: bool = false
@export var flight_unlocked: bool = false
@export_range(0, 3, 1) var maximum_air_jumps: int = 1

@export_group("Jump and Hover")
@export_range(0.0, 0.4, 0.01) var coyote_time: float = 0.12
@export var double_jump_velocity: float = 5.2
@export_range(0.1, 5.0, 0.1) var hover_duration: float = 1.5
@export var hover_target_fall_speed: float = -0.35
@export var hover_vertical_response: float = 8.0
@export var hover_activation_upward_speed: float = 1.0
@export var ground_acceleration: float = 32.0
@export var air_acceleration: float = 13.0

@export_group("Flight")
@export var flight_spell_id: String = "flight_concentration"
@export var flight_speed: float = 7.2
@export var flight_vertical_speed: float = 5.2
@export var flight_acceleration: float = 17.0
@export var flight_brake_acceleration: float = 23.0
@export var flight_vertical_acceleration: float = 15.0
@export var controlled_descent_speed: float = 3.4
@export var controlled_descent_acceleration: float = 8.0
@export var activation_lift_speed: float = 0.75

@export_group("Airflow")
@export var body_mass_kg: float = 65.0
@export_range(0.0, 2.0, 0.01) var grounded_airflow_response: float = 0.42
@export_range(0.0, 2.0, 0.01) var airborne_airflow_response: float = 0.9
@export_range(0.0, 2.0, 0.01) var flight_airflow_response: float = 0.65

@export_group("Presentation")
@export var show_messages: bool = true
@export var flight_visual_spin_speed: float = 1.8

var actor: CharacterBody3D = null
var action_state: PlayerActionState = null
var airflow_response: AirflowResponse = null
var concentration_manager: Node = null
var active_flight_definition: Resource = null

var traversal_state: String = "grounded"
var air_jumps_used: int = 0
var coyote_timer: float = 0.0
var hover_remaining: float = 0.0
var hover_armed: bool = false
var was_hovering: bool = false
var flight_active: bool = false
var controlled_descent_active: bool = false

var flight_visual_root: Node3D = null
var visual_elapsed: float = 0.0
var last_airflow_acceleration: Vector3 = Vector3.ZERO


func _ready() -> void:
	actor = get_parent() as CharacterBody3D
	if actor != null:
		action_state = actor.get_node_or_null("PlayerActionState") as PlayerActionState
		airflow_response = actor.get_node_or_null("AirflowResponse") as AirflowResponse
	add_to_group("debuggable")
	ensure_flight_input_map()
	build_flight_visual()
	hover_remaining = hover_duration


func _process(delta: float) -> void:
	visual_elapsed += max(delta, 0.0)
	update_flight_visual(delta)


func _exit_tree() -> void:
	if flight_active:
		finish_flight(false, false)


func _unhandled_input(event: InputEvent) -> void:
	if not flight_active or not event.is_action_pressed("cast_spell"):
		return
	if not current_ability_is_flight():
		return
	finish_flight(true, true)
	get_viewport().set_input_as_handled()


func should_handle_locomotion() -> bool:
	if flight_active or controlled_descent_active or double_jump_unlocked or hover_unlocked:
		return true
	return airflow_response != null and actor != null and airflow_response.has_active_airflow(actor.global_position)


func process_locomotion(delta: float) -> bool:
	if actor == null or not should_handle_locomotion():
		return false
	if bool(actor.get("is_defeated")):
		return false

	if flight_active:
		process_flight(delta)
	else:
		process_jump_hover(delta)
	return true


func process_jump_hover(delta: float) -> void:
	var was_on_floor: bool = actor.is_on_floor()
	var move_input: Vector2 = get_move_input()
	var requested_direction: Vector3 = get_camera_relative_horizontal_direction(move_input)
	var move_speed: float = float(actor.get("move_speed"))
	var gravity_value: float = float(actor.get("gravity"))
	var jump_speed: float = float(actor.get("jump_velocity"))
	var can_move: bool = action_state == null or action_state.can_move()

	if not can_move:
		requested_direction = Vector3.ZERO

	var target_horizontal: Vector3 = requested_direction * move_speed
	var acceleration: float = ground_acceleration if was_on_floor else air_acceleration
	actor.velocity.x = move_toward(actor.velocity.x, target_horizontal.x, acceleration * delta)
	actor.velocity.z = move_toward(actor.velocity.z, target_horizontal.z, acceleration * delta)

	if was_on_floor:
		coyote_timer = coyote_time
		air_jumps_used = 0
		hover_remaining = hover_duration
		hover_armed = false
		controlled_descent_active = false
		was_hovering = false
		set_traversal_state("grounded")
	else:
		coyote_timer = max(coyote_timer - delta, 0.0)

	if can_move and Input.is_action_just_pressed("jump"):
		if was_on_floor or coyote_timer > 0.0:
			actor.velocity.y = jump_speed
			coyote_timer = 0.0
			set_traversal_state("jumping")
		elif double_jump_unlocked and air_jumps_used < maximum_air_jumps:
			actor.velocity.y = double_jump_velocity
			air_jumps_used += 1
			hover_armed = hover_unlocked
			hover_remaining = hover_duration
			set_traversal_state("double_jump")

	var hover_requested: bool = (
		hover_unlocked
		and hover_armed
		and Input.is_action_pressed("jump")
		and hover_remaining > 0.0
		and actor.velocity.y <= hover_activation_upward_speed
	)

	if hover_requested:
		hover_remaining = max(hover_remaining - delta, 0.0)
		actor.velocity.y = move_toward(
			actor.velocity.y,
			hover_target_fall_speed,
			hover_vertical_response * delta
		)
		was_hovering = true
		set_traversal_state("hovering")
		hover_updated.emit(hover_remaining, hover_duration)
	else:
		if was_hovering and not Input.is_action_pressed("jump"):
			hover_armed = false
		was_hovering = false
		if controlled_descent_active:
			actor.velocity.y = move_toward(
				actor.velocity.y,
				-controlled_descent_speed,
				controlled_descent_acceleration * delta
			)
			set_traversal_state("controlled_descent")
		else:
			actor.velocity.y -= gravity_value * delta
			if not was_on_floor and traversal_state not in ["jumping", "double_jump"]:
				set_traversal_state("falling")

	apply_airflow(delta, grounded_airflow_response if was_on_floor else airborne_airflow_response)
	actor.move_and_slide()

	if actor.is_on_floor():
		air_jumps_used = 0
		hover_remaining = hover_duration
		hover_armed = false
		controlled_descent_active = false
		set_traversal_state("grounded")
	elif traversal_state in ["jumping", "double_jump"] and actor.velocity.y <= 0.0:
		set_traversal_state("falling")


func process_flight(delta: float) -> void:
	var move_input: Vector2 = get_move_input()
	var horizontal_direction: Vector3 = get_camera_relative_horizontal_direction(move_input)
	var can_move: bool = action_state == null or action_state.can_move()
	if not can_move:
		horizontal_direction = Vector3.ZERO

	var horizontal_target: Vector3 = horizontal_direction * flight_speed
	var horizontal_acceleration: float = flight_acceleration if horizontal_direction.length() > 0.01 else flight_brake_acceleration
	actor.velocity.x = move_toward(actor.velocity.x, horizontal_target.x, horizontal_acceleration * delta)
	actor.velocity.z = move_toward(actor.velocity.z, horizontal_target.z, horizontal_acceleration * delta)

	var vertical_input: float = 0.0
	if can_move and Input.is_action_pressed("jump"):
		vertical_input += 1.0
	if can_move and Input.is_action_pressed("flight_descend"):
		vertical_input -= 1.0

	var vertical_target: float = vertical_input * flight_vertical_speed
	actor.velocity.y = move_toward(
		actor.velocity.y,
		vertical_target,
		flight_vertical_acceleration * delta
	)

	apply_airflow(delta, flight_airflow_response)
	actor.move_and_slide()
	set_traversal_state("flying")


func apply_airflow(delta: float, response_multiplier: float) -> void:
	last_airflow_acceleration = Vector3.ZERO
	if airflow_response == null or actor == null:
		return
	last_airflow_acceleration = airflow_response.get_airflow_acceleration(
		actor.global_position,
		actor.velocity,
		body_mass_kg,
		response_multiplier
	)
	actor.velocity += last_airflow_acceleration * max(delta, 0.0)


func activate_flight(definition: Resource) -> bool:
	if not flight_unlocked:
		show_message("Flight has not been unlocked yet.")
		return false
	if actor == null or definition == null:
		return false
	if flight_active:
		return true
	if action_state != null and not action_state.can_cast():
		return false

	concentration_manager = find_concentration_manager()
	if concentration_manager == null or not concentration_manager.has_method("activate_effect"):
		show_message("Flight needs a Concentration Manager in this scene.")
		return false

	var ability_caster: Node = actor.get_node_or_null("AbilityCaster")
	if not bool(concentration_manager.call("activate_effect", definition, ability_caster)):
		return false

	active_flight_definition = definition
	flight_active = true
	controlled_descent_active = false
	actor.velocity.y = max(actor.velocity.y, activation_lift_speed)
	if action_state != null:
		action_state.begin_flight()
	connect_concentration_signal()
	set_flight_visual_visible(true)
	set_traversal_state("flying")
	flight_started.emit(float(definition.get("mana_reservation_fraction")))
	show_message("Flight sustained. Jump ascends, Dodge descends, and local airflow shapes the route.")
	return true


func finish_flight(release_concentration: bool = true, show_feedback: bool = true) -> void:
	if not flight_active:
		return

	flight_active = false
	var begin_controlled_descent: bool = actor != null and not actor.is_on_floor()
	controlled_descent_active = begin_controlled_descent
	active_flight_definition = null
	if action_state != null:
		action_state.end_flight()
	set_flight_visual_visible(false)

	if release_concentration and concentration_manager != null:
		var active_effect: Variant = concentration_manager.get("active_effect")
		if active_effect != null and str(active_effect.get("effect_id")) == flight_spell_id:
			concentration_manager.call("deactivate_effect", false)

	if begin_controlled_descent:
		set_traversal_state("controlled_descent")
	else:
		set_traversal_state("grounded")
	flight_stopped.emit(begin_controlled_descent)
	if show_feedback:
		show_message("Flight released." + (" Grace descends safely." if begin_controlled_descent else ""))


func _on_concentration_effect_deactivated(effect_id: String) -> void:
	if effect_id == flight_spell_id and flight_active:
		finish_flight(false, true)


func connect_concentration_signal() -> void:
	if concentration_manager == null or not concentration_manager.has_signal("effect_deactivated"):
		return
	var callback := Callable(self, "_on_concentration_effect_deactivated")
	if not concentration_manager.is_connected("effect_deactivated", callback):
		concentration_manager.connect("effect_deactivated", callback)


func find_concentration_manager() -> Node:
	var manager: Node = get_tree().get_first_node_in_group("concentration_manager")
	if manager != null:
		return manager
	if get_tree().current_scene != null:
		return get_tree().current_scene.get_node_or_null("ConcentrationManager")
	return null


func current_ability_is_flight() -> bool:
	if actor == null:
		return false
	var ability_caster: Node = actor.get_node_or_null("AbilityCaster")
	if ability_caster == null or not ability_caster.has_method("get_current_ability"):
		return false
	var ability: Variant = ability_caster.call("get_current_ability")
	return ability != null and str(ability.get("spell_id")) == flight_spell_id


func get_move_input() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")


func get_camera_relative_horizontal_direction(input_vector: Vector2) -> Vector3:
	if input_vector.length() <= 0.01:
		return Vector3.ZERO

	var forward: Vector3 = -actor.global_transform.basis.z
	var right: Vector3 = actor.global_transform.basis.x
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null:
		forward = -camera.global_transform.basis.z
		right = camera.global_transform.basis.x

	forward.y = 0.0
	right.y = 0.0
	if forward.length() > 0.01:
		forward = forward.normalized()
	if right.length() > 0.01:
		right = right.normalized()

	var direction: Vector3 = right * input_vector.x + forward * -input_vector.y
	return direction.normalized() if direction.length() > 0.01 else Vector3.ZERO


func set_traversal_state(new_state: String) -> void:
	if traversal_state == new_state:
		return
	var previous_state: String = traversal_state
	traversal_state = new_state
	traversal_state_changed.emit(previous_state, traversal_state)


func ensure_flight_input_map() -> void:
	if not InputMap.has_action("flight_descend"):
		InputMap.add_action("flight_descend", 0.2)

	if not input_action_has_key("flight_descend", KEY_C):
		var key_event := InputEventKey.new()
		key_event.physical_keycode = KEY_C
		InputMap.action_add_event("flight_descend", key_event)

	if not input_action_has_joy_button("flight_descend", 0):
		var joy_event := InputEventJoypadButton.new()
		joy_event.button_index = 0
		InputMap.action_add_event("flight_descend", joy_event)


func input_action_has_key(action_name: String, physical_keycode: Key) -> bool:
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == physical_keycode:
			return true
	return false


func input_action_has_joy_button(action_name: String, button_index: int) -> bool:
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == button_index:
			return true
	return false


func build_flight_visual() -> void:
	if actor == null or flight_visual_root != null:
		return
	flight_visual_root = Node3D.new()
	flight_visual_root.name = "FlightConcentrationVisual"
	flight_visual_root.position = Vector3(0.0, 0.15, 0.0)
	actor.add_child(flight_visual_root)
	ElementVisuals.add_torus(
		flight_visual_root,
		"LowerOrbit",
		0.72,
		0.84,
		Color(0.42, 0.84, 1.0, 1.0),
		Vector3(0.0, -0.65, 0.0),
		Vector3.ZERO,
		1.5,
		0.3
	)
	ElementVisuals.add_torus(
		flight_visual_root,
		"UpperOrbit",
		0.48,
		0.58,
		Color(0.72, 0.94, 1.0, 1.0),
		Vector3(0.0, 0.75, 0.0),
		Vector3(90.0, 0.0, 0.0),
		1.8,
		0.24
	)
	set_flight_visual_visible(false)


func update_flight_visual(delta: float) -> void:
	if flight_visual_root == null or not flight_visual_root.visible:
		return
	flight_visual_root.rotate_y(flight_visual_spin_speed * delta)
	var pulse: float = 1.0 + sin(visual_elapsed * 4.0) * 0.06
	flight_visual_root.scale = Vector3.ONE * pulse


func set_flight_visual_visible(value: bool) -> void:
	if flight_visual_root != null:
		flight_visual_root.visible = value
		if not value:
			flight_visual_root.scale = Vector3.ONE


func show_message(text: String) -> void:
	if not show_messages:
		return
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	else:
		print(text)


func get_debug_data() -> Dictionary:
	return {
		"traversal_state": traversal_state,
		"double_jump_unlocked": double_jump_unlocked,
		"air_jumps_used": air_jumps_used,
		"hover_unlocked": hover_unlocked,
		"hover_remaining": snapped(hover_remaining, 0.01),
		"flight_unlocked": flight_unlocked,
		"flight_active": flight_active,
		"controlled_descent": controlled_descent_active,
		"velocity": actor.velocity if actor != null else Vector3.ZERO,
		"airflow_acceleration": last_airflow_acceleration,
		"airflow": airflow_response.get_debug_data() if airflow_response != null else {},
	}
