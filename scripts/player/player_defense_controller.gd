extends Node
class_name PlayerDefenseController

signal guard_started
signal guard_ended
signal attack_blocked(result: Dictionary)
signal perfect_guarded(result: Dictionary)
signal guard_broken(result: Dictionary)
signal player_hit(result: Dictionary)
signal defense_state_changed(debug_data: Dictionary)

@export_group("Input")
@export var guard_action_name: StringName = &"guard"
@export var guard_keyboard_key: Key = KEY_F
@export var guard_mouse_button: MouseButton = MOUSE_BUTTON_XBUTTON2
@export_range(0, 20, 1) var guard_joypad_button: int = 2

@export_group("Guard")
@export_range(30.0, 180.0, 1.0) var guard_angle_degrees: float = 150.0
@export_range(0.05, 0.5, 0.01) var perfect_guard_window: float = 0.16
@export_range(1, 8, 1) var minimum_stamina_cost: int = 1
@export_range(1, 8, 1) var minimum_stance_damage: int = 1
@export_range(0.1, 2.0, 0.05) var guard_recoil_seconds: float = 0.18
@export_range(0.5, 8.0, 0.1) var guard_recoil_speed: float = 2.4

@export_group("Perfect Guard")
@export_range(0, 12, 1) var perfect_guard_stance_damage: int = 2
@export_range(0.1, 2.0, 0.05) var perfect_guard_stagger_seconds: float = 0.65

@export_group("Hit Reactions")
@export_range(0.1, 2.0, 0.05) var hit_reaction_seconds: float = 0.28
@export_range(0.5, 12.0, 0.1) var hit_reaction_speed: float = 4.5
@export_range(0.1, 3.0, 0.05) var guard_break_seconds: float = 0.85
@export_range(0.5, 12.0, 0.1) var guard_break_speed: float = 6.0

var is_guarding: bool = false
var perfect_guard_remaining: float = 0.0
var hit_reaction_remaining: float = 0.0
var hit_reaction_velocity: Vector3 = Vector3.ZERO
var feedback_flash_remaining: float = 0.0
var last_outcome: String = "ready"

var actor: CharacterBody3D
var action_state: PlayerActionState
var guard_visual: MeshInstance3D
var guard_material: StandardMaterial3D


func _ready() -> void:
	actor = get_parent() as CharacterBody3D
	if actor != null:
		action_state = actor.get_node_or_null("PlayerActionState") as PlayerActionState
	ensure_guard_input_map()
	create_guard_visual()
	add_to_group("debuggable")


func _exit_tree() -> void:
	if is_guarding:
		end_guard()


func _process(delta: float) -> void:
	perfect_guard_remaining = maxf(perfect_guard_remaining - delta, 0.0)
	hit_reaction_remaining = maxf(hit_reaction_remaining - delta, 0.0)
	feedback_flash_remaining = maxf(feedback_flash_remaining - delta, 0.0)

	if is_guarding and (
		action_state == null
		or action_state.is_defeated
		or action_state.is_staggered
		or action_state.is_focus_menu_open
		or action_state.is_attacking
		or action_state.is_casting
		or action_state.is_interacting
		or action_state.is_dodging
		or action_state.is_manipulating
		or action_state.is_flying
	):
		end_guard()

	if is_guarding and not Input.is_action_pressed(guard_action_name):
		end_guard()

	update_guard_visual()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(guard_action_name):
		if begin_guard():
			get_viewport().set_input_as_handled()
		return

	if event.is_action_released(guard_action_name):
		end_guard()
		get_viewport().set_input_as_handled()


func begin_guard() -> bool:
	if is_guarding:
		return true
	if action_state == null or not action_state.begin_guard():
		return false

	is_guarding = true
	perfect_guard_remaining = perfect_guard_window
	last_outcome = "guarding"
	guard_started.emit()
	emit_defense_state()
	return true


func end_guard() -> void:
	if not is_guarding:
		return

	is_guarding = false
	perfect_guard_remaining = 0.0
	if action_state != null:
		action_state.end_guard()
	guard_ended.emit()
	emit_defense_state()


func resolve_incoming_attack(payload: DamagePayload, attacker: Node3D = null) -> Dictionary:
	if payload == null:
		return {"outcome": "ignored", "message": ""}

	if GameState.is_player_invulnerable():
		last_outcome = "dodged"
		var dodge_result: Dictionary = make_result("dodged", payload, "Grace avoids " + payload.source_name + ".")
		emit_defense_state()
		return dodge_result

	var incoming_direction: Vector3 = get_incoming_direction(attacker)

	if is_guarding and is_attack_inside_guard(incoming_direction):
		if perfect_guard_remaining > 0.0:
			return resolve_perfect_guard(payload, attacker, incoming_direction)
		return resolve_block(payload, incoming_direction)

	return resolve_direct_hit(payload, incoming_direction)


func resolve_perfect_guard(payload: DamagePayload, attacker: Node3D, incoming_direction: Vector3) -> Dictionary:
	perfect_guard_remaining = 0.0
	last_outcome = "perfect_guard"
	start_hit_reaction(-incoming_direction, guard_recoil_seconds, guard_recoil_speed * 0.45)
	flash_feedback(Color(1.0, 0.78, 0.16, 0.95), 0.24)
	punish_attacker(attacker)

	var result: Dictionary = make_result(
		"perfect_guard",
		payload,
		"Perfect Guard! Grace deflects " + payload.source_name + "."
	)
	perfect_guarded.emit(result)
	emit_defense_state()
	return result


func resolve_block(payload: DamagePayload, incoming_direction: Vector3) -> Dictionary:
	var stamina_cost: int = maxi(minimum_stamina_cost, payload.amount)
	var stance_cost: int = maxi(minimum_stance_damage, payload.stance_damage)
	var current_stamina: int = GameState.get_stat("stamina")

	if current_stamina < stamina_cost:
		if current_stamina > 0:
			GameState.spend_stamina(current_stamina)
		return resolve_guard_break(payload, incoming_direction, "Stamina broke")

	GameState.spend_stamina(stamina_cost)
	GameState.damage_stance(stance_cost)

	if GameState.get_stat("stance") <= 0:
		return resolve_guard_break(payload, incoming_direction, "Stance broke")

	last_outcome = "blocked"
	start_hit_reaction(-incoming_direction, guard_recoil_seconds, guard_recoil_speed)
	flash_feedback(Color(0.24, 0.7, 1.0, 0.92), 0.15)

	var result: Dictionary = make_result(
		"blocked",
		payload,
		"Guarded " + payload.source_name + " (-" + str(stamina_cost) + " stamina, -" + str(stance_cost) + " stance)."
	)
	result["stamina_cost"] = stamina_cost
	result["stance_cost"] = stance_cost
	attack_blocked.emit(result)
	emit_defense_state()
	return result


func resolve_guard_break(payload: DamagePayload, incoming_direction: Vector3, reason: String) -> Dictionary:
	var remaining_stance: int = GameState.get_stat("stance")
	if remaining_stance > 0:
		GameState.damage_stance(remaining_stance)

	end_guard()
	last_outcome = "guard_broken"
	if action_state != null:
		action_state.begin_stagger(guard_break_seconds)
	start_hit_reaction(-incoming_direction, guard_break_seconds, guard_break_speed)
	flash_feedback(Color(1.0, 0.18, 0.12, 0.95), 0.42)

	var result: Dictionary = make_result(
		"guard_broken",
		payload,
		reason + "! Grace is staggered."
	)
	guard_broken.emit(result)
	emit_defense_state()
	return result


func resolve_direct_hit(payload: DamagePayload, incoming_direction: Vector3) -> Dictionary:
	var health_before: int = GameState.get_stat("health")
	GameState.take_damage(payload.amount)
	GameState.damage_stance(payload.stance_damage)
	var health_damage: int = health_before - GameState.get_stat("health")

	last_outcome = "hit"
	if action_state != null:
		action_state.begin_stagger(hit_reaction_seconds)
	start_hit_reaction(-incoming_direction, hit_reaction_seconds, hit_reaction_speed)
	flash_feedback(Color(1.0, 0.12, 0.18, 0.92), 0.28)

	var result: Dictionary = make_result(
		"hit",
		payload,
		payload.source_name + " hits Grace for " + str(health_damage) + "."
	)
	result["health_damage"] = health_damage
	player_hit.emit(result)
	emit_defense_state()
	return result


func punish_attacker(attacker: Node3D) -> void:
	if attacker == null or not is_instance_valid(attacker):
		return

	var receiver: Node = attacker.get_node_or_null("HitReceiver")
	if receiver != null and receiver.has_method("receive_payload"):
		var counter_payload: DamagePayload = DamagePayload.new()
		counter_payload.amount = 0
		counter_payload.stance_damage = perfect_guard_stance_damage
		counter_payload.element = "metal"
		counter_payload.source_name = "Perfect Guard"
		counter_payload.hit_type = "deflection"
		counter_payload.tags = ["physical", "deflection", "perfect_guard", "player_defense"]
		receiver.call("receive_payload", counter_payload)

	var status_receiver: Node = attacker.get_node_or_null("StatusReceiver")
	if status_receiver != null and status_receiver.has_method("apply_status"):
		status_receiver.call(
			"apply_status",
			"staggered",
			perfect_guard_stagger_seconds,
			1.0,
			"Perfect Guard"
		)


func get_incoming_direction(attacker: Node3D) -> Vector3:
	if actor == null:
		return Vector3.FORWARD
	if attacker == null or not is_instance_valid(attacker):
		var fallback: Vector3 = -actor.global_transform.basis.z
		fallback.y = 0.0
		return fallback.normalized()

	var direction: Vector3 = attacker.global_position - actor.global_position
	direction.y = 0.0
	if direction.length() <= 0.01:
		direction = -actor.global_transform.basis.z
		direction.y = 0.0
	return direction.normalized()


func is_attack_inside_guard(incoming_direction: Vector3) -> bool:
	if actor == null:
		return true
	var forward: Vector3 = -actor.global_transform.basis.z
	forward.y = 0.0
	if forward.length() <= 0.01 or incoming_direction.length() <= 0.01:
		return true
	var minimum_dot: float = cos(deg_to_rad(guard_angle_degrees * 0.5))
	return forward.normalized().dot(incoming_direction.normalized()) >= minimum_dot


func start_hit_reaction(direction: Vector3, duration: float, speed: float) -> void:
	var horizontal: Vector3 = direction
	horizontal.y = 0.0
	if horizontal.length() <= 0.01 and actor != null:
		horizontal = actor.global_transform.basis.z
		horizontal.y = 0.0
	hit_reaction_velocity = horizontal.normalized() * speed
	hit_reaction_remaining = maxf(duration, 0.01)


func is_hit_reaction_active() -> bool:
	return hit_reaction_remaining > 0.0


func get_hit_reaction_velocity() -> Vector3:
	return hit_reaction_velocity


func reset_defense() -> void:
	end_guard()
	hit_reaction_remaining = 0.0
	hit_reaction_velocity = Vector3.ZERO
	feedback_flash_remaining = 0.0
	last_outcome = "ready"
	update_guard_visual()
	emit_defense_state()


func make_result(outcome: String, payload: DamagePayload, message: String) -> Dictionary:
	return {
		"outcome": outcome,
		"source": payload.source_name,
		"damage": payload.amount,
		"stance_damage": payload.stance_damage,
		"message": message,
	}


func show_message(message: String) -> void:
	if message == "":
		return
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", message)


func ensure_guard_input_map() -> void:
	if not InputMap.has_action(guard_action_name):
		InputMap.add_action(guard_action_name)

	if not action_has_key(guard_action_name, guard_keyboard_key):
		var key_event: InputEventKey = InputEventKey.new()
		key_event.physical_keycode = guard_keyboard_key
		InputMap.action_add_event(guard_action_name, key_event)

	if not action_has_mouse_button(guard_action_name, guard_mouse_button):
		var mouse_event: InputEventMouseButton = InputEventMouseButton.new()
		mouse_event.button_index = guard_mouse_button
		InputMap.action_add_event(guard_action_name, mouse_event)

	remove_joypad_button("weapon_light_attack", guard_joypad_button)
	if not action_has_joy_button(guard_action_name, guard_joypad_button):
		var joy_event: InputEventJoypadButton = InputEventJoypadButton.new()
		joy_event.button_index = guard_joypad_button
		InputMap.action_add_event(guard_action_name, joy_event)


func action_has_key(action_name: StringName, keycode: Key) -> bool:
	if not InputMap.has_action(action_name):
		return false
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventKey:
			var key_event: InputEventKey = event as InputEventKey
			if key_event.physical_keycode == keycode or key_event.keycode == keycode:
				return true
	return false


func action_has_mouse_button(action_name: StringName, button: MouseButton) -> bool:
	if not InputMap.has_action(action_name):
		return false
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == button:
			return true
	return false


func action_has_joy_button(action_name: StringName, button: int) -> bool:
	if not InputMap.has_action(action_name):
		return false
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == button:
			return true
	return false


func remove_joypad_button(action_name: StringName, button: int) -> void:
	if not InputMap.has_action(action_name):
		return
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == button:
			InputMap.action_erase_event(action_name, event)


func create_guard_visual() -> void:
	if actor == null:
		return
	guard_visual = MeshInstance3D.new()
	guard_visual.name = "GuardVisual"
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.82
	mesh.height = 1.64
	guard_visual.mesh = mesh
	guard_visual.position = Vector3(0.0, 0.65, -0.76)
	guard_visual.scale = Vector3(1.0, 1.0, 0.08)
	guard_material = StandardMaterial3D.new()
	guard_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	guard_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	guard_material.emission_enabled = true
	guard_material.albedo_color = Color(0.18, 0.62, 1.0, 0.38)
	guard_material.emission = Color(0.08, 0.4, 1.0)
	guard_material.emission_energy_multiplier = 1.6
	guard_visual.material_override = guard_material
	guard_visual.visible = false
	actor.call_deferred("add_child", guard_visual)


func flash_feedback(color: Color, duration: float) -> void:
	feedback_flash_remaining = maxf(feedback_flash_remaining, duration)
	if guard_material != null:
		guard_material.albedo_color = color
		guard_material.emission = Color(color.r, color.g, color.b)


func update_guard_visual() -> void:
	if guard_visual == null or not is_instance_valid(guard_visual):
		return
	guard_visual.visible = is_guarding or feedback_flash_remaining > 0.0
	if feedback_flash_remaining <= 0.0 and guard_material != null:
		guard_material.albedo_color = Color(0.18, 0.62, 1.0, 0.38)
		guard_material.emission = Color(0.08, 0.4, 1.0)
	if is_guarding:
		var readiness: float = perfect_guard_remaining / maxf(perfect_guard_window, 0.01)
		guard_visual.scale = Vector3.ONE * lerpf(1.0, 1.12, readiness)
		guard_visual.scale.z = 0.08
	else:
		guard_visual.scale = Vector3(1.0, 1.0, 0.08)


func emit_defense_state() -> void:
	defense_state_changed.emit(get_debug_data())


func get_debug_data() -> Dictionary:
	return {
		"guarding": is_guarding,
		"perfect_window": snapped(perfect_guard_remaining, 0.01),
		"hit_reaction": snapped(hit_reaction_remaining, 0.01),
		"last_outcome": last_outcome,
		"guard_angle": guard_angle_degrees,
	}
