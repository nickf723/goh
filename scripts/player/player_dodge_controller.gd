extends Node
class_name PlayerDodgeController

@export var dodge_speed: float = 9.0
@export var dodge_duration: float = 0.24
@export var dodge_cooldown: float = 0.15
@export var invulnerability_duration: float = 0.18
@export_range(0, 5, 1) var stamina_cost: int = 1

@export var use_camera_relative_direction: bool = true
@export var fallback_to_forward_when_no_input: bool = true

@export var show_debug_prints: bool = true

var is_active: bool = false
var dodge_timer: float = 0.0
var cooldown_timer: float = 0.0
var dodge_direction: Vector3 = Vector3.FORWARD

@onready var actor: CharacterBody3D = get_parent() as CharacterBody3D
@onready var action_state: PlayerActionState = get_parent().get_node_or_null("PlayerActionState")


func _ready() -> void:
	add_to_group("debuggable")

func _process(delta: float) -> void:
	if cooldown_timer > 0.0:
		cooldown_timer -= delta

	if not is_active:
		return

	dodge_timer -= delta

	if dodge_timer <= 0.0:
		is_active = false
		dodge_timer = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("dodge"):
		try_dodge()

func try_dodge() -> void:
	if actor == null:
		return

	if action_state != null and not action_state.can_dodge():
		return

	if cooldown_timer > 0.0:
		return

	if stamina_cost > 0:
		if not GameState.spend_stamina(stamina_cost):
			show_message("Not enough stamina.")
			return

	dodge_direction = get_requested_dodge_direction()

	if dodge_direction.length() <= 0.01:
		return

	is_active = true
	dodge_timer = dodge_duration
	cooldown_timer = dodge_duration + dodge_cooldown

	if action_state != null:
		action_state.begin_dodge(dodge_duration)

	GameState.begin_player_invulnerability(invulnerability_duration)

	show_message("Grace dodges.")

func get_requested_dodge_direction() -> Vector3:
	var input_vector: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_back"
	)

	if input_vector.length() <= 0.01:
		if fallback_to_forward_when_no_input:
			return get_actor_forward()

		return Vector3.ZERO

	var forward: Vector3 = get_actor_forward()
	var right: Vector3 = get_actor_right()

	if use_camera_relative_direction:
		var camera: Camera3D = get_viewport().get_camera_3d()

		if camera != null:
			forward = -camera.global_transform.basis.z
			forward.y = 0.0

			if forward.length() > 0.01:
				forward = forward.normalized()

			right = camera.global_transform.basis.x
			right.y = 0.0

			if right.length() > 0.01:
				right = right.normalized()

	var direction: Vector3 = right * input_vector.x + forward * -input_vector.y

	if direction.length() <= 0.01:
		return Vector3.ZERO

	return direction.normalized()

func get_dodge_velocity() -> Vector3:
	if not is_active:
		return Vector3.ZERO

	var progress: float = 1.0 - (dodge_timer / max(dodge_duration, 0.01))
	var speed_multiplier: float = lerp(1.0, 0.55, progress)

	return dodge_direction * dodge_speed * speed_multiplier

func is_dodge_active() -> bool:
	return is_active


func cancel_into_weapon_technique() -> Vector3:
	if not is_active:
		return Vector3.ZERO
	var carried_direction: Vector3 = dodge_direction
	is_active = false
	dodge_timer = 0.0
	if action_state != null:
		action_state.end_dodge()
	return carried_direction

func get_actor_forward() -> Vector3:
	if actor == null:
		return Vector3.FORWARD

	var forward: Vector3 = -actor.global_transform.basis.z
	forward.y = 0.0

	if forward.length() <= 0.01:
		return Vector3.FORWARD

	return forward.normalized()

func get_actor_right() -> Vector3:
	if actor == null:
		return Vector3.RIGHT

	var right: Vector3 = actor.global_transform.basis.x
	right.y = 0.0

	if right.length() <= 0.01:
		return Vector3.RIGHT

	return right.normalized()

func show_message(text: String) -> void:
	if show_debug_prints:
		print(text)

	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui != null and ui.has_method("show_message"):
		ui.show_message(text)

func get_debug_data() -> Dictionary:
	return {
		"active": is_active,
		"time": snapped(dodge_timer, 0.01),
		"cooldown": snapped(cooldown_timer, 0.01),
		"iframe": GameState.is_player_invulnerable(),
	}
