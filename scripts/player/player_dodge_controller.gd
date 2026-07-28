extends Node
class_name PlayerDodgeController

signal dodge_started(direction: Vector3, direction_kind: String, chain_index: int)
signal dodge_phase_changed(previous_phase: String, next_phase: String)
signal dodge_finished(reason: String)
signal dodge_iframe_changed(active: bool)
signal dodge_follow_up_buffered(follow_up: String)
signal dodge_follow_up_executed(follow_up: String)

@export var profile: DodgeMotionProfile
@export var use_camera_relative_direction: bool = true
@export var fallback_to_forward_when_no_input: bool = true
@export var show_debug_prints: bool = false

const FALLBACK_DISTANCE: float = 1.65
const FALLBACK_DURATION: float = 0.24
const FALLBACK_COOLDOWN: float = 0.15
const FALLBACK_STAMINA_COST: int = 1
const FOLLOW_UP_NONE: String = ""
const FOLLOW_UP_CAST: String = "cast"
const FOLLOW_UP_GUARD: String = "guard"

var is_active: bool = false
var dodge_timer: float = 0.0
var dodge_elapsed: float = 0.0
var dodge_duration: float = FALLBACK_DURATION
var dodge_speed: float = 0.0
var dodge_distance: float = FALLBACK_DISTANCE
var cooldown_timer: float = 0.0
var dodge_direction: Vector3 = Vector3.FORWARD
var dodge_kind: String = "forward"
var dodge_phase: String = "idle"
var dodge_progress: float = 0.0
var iframe_active: bool = false
var iframe_started: bool = false
var chain_count: int = 0
var last_dodge_velocity: Vector3 = Vector3.ZERO
var last_finish_reason: String = "ready"

var buffered_chain_remaining: float = 0.0
var buffered_chain_direction: Vector3 = Vector3.ZERO
var buffered_chain_kind: String = "forward"
var buffered_follow_up: String = FOLLOW_UP_NONE
var buffered_follow_up_remaining: float = 0.0

@onready var actor: CharacterBody3D = get_parent() as CharacterBody3D
@onready var action_state: PlayerActionState = get_parent().get_node_or_null("PlayerActionState") as PlayerActionState
@onready var ability_caster: Node3D = get_parent().get_node_or_null("AbilityCaster") as Node3D
@onready var defense_controller: PlayerDefenseController = (
	get_parent().get_node_or_null("PlayerDefenseController") as PlayerDefenseController
)


func _ready() -> void:
	add_to_group("debuggable")
	add_to_group("player_dodge_motion_controller")


func _process(delta: float) -> void:
	cooldown_timer = maxf(cooldown_timer - maxf(delta, 0.0), 0.0)
	_update_buffer_timers(delta)

	if not is_active:
		if cooldown_timer <= 0.0:
			chain_count = 0
		return

	_capture_follow_up_inputs()
	dodge_elapsed = minf(dodge_elapsed + maxf(delta, 0.0), dodge_duration)
	dodge_timer = maxf(dodge_duration - dodge_elapsed, 0.0)
	dodge_progress = clampf(dodge_elapsed / maxf(dodge_duration, 0.001), 0.0, 1.0)

	_apply_late_steering(delta)
	_update_phase()
	_update_invulnerability_window()
	_try_execute_buffered_actions()

	if is_active and dodge_timer <= 0.0:
		_finish_dodge("completed")


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("dodge"):
		return
	if is_active:
		request_dodge_chain()
	else:
		try_dodge()
	get_viewport().set_input_as_handled()


func try_dodge() -> bool:
	if actor == null:
		return false
	if action_state != null and not action_state.can_dodge():
		return false
	if cooldown_timer > 0.0:
		return false

	var direction: Vector3 = get_requested_dodge_direction()
	if direction.length() <= 0.01:
		return false
	return _start_dodge(direction, classify_dodge_direction(direction), false)


func begin_dodge_in_direction(
	direction: Vector3,
	direction_kind: String = "forward",
	ignore_cooldown: bool = false
) -> bool:
	if actor == null or direction.length_squared() <= 0.0001:
		return false
	if not ignore_cooldown and cooldown_timer > 0.0:
		return false
	if action_state != null and not action_state.can_dodge():
		return false
	return _start_dodge(direction.normalized(), direction_kind, false)


func request_dodge_chain() -> bool:
	if not is_active:
		return false
	var direction: Vector3 = get_requested_dodge_direction()
	if direction.length_squared() <= 0.0001:
		direction = dodge_direction
	var direction_kind: String = classify_dodge_direction(direction)
	if can_chain_dodge():
		return _start_dodge(direction, direction_kind, true)

	buffered_chain_direction = direction
	buffered_chain_kind = direction_kind
	buffered_chain_remaining = get_input_buffer_seconds()
	return true


func buffer_follow_up(follow_up: String) -> bool:
	if not is_active or follow_up not in [FOLLOW_UP_CAST, FOLLOW_UP_GUARD]:
		return false
	if _can_execute_follow_up(follow_up):
		return _execute_follow_up(follow_up)
	buffered_follow_up = follow_up
	buffered_follow_up_remaining = get_input_buffer_seconds()
	dodge_follow_up_buffered.emit(follow_up)
	return true


func get_requested_dodge_direction() -> Vector3:
	var input_vector: Vector2 = _get_movement_input()
	if input_vector.length() <= 0.01:
		if _has_lock_on_target():
			return -get_actor_forward()
		if fallback_to_forward_when_no_input:
			return get_actor_forward()
		return Vector3.ZERO
	return _direction_from_input(input_vector)


func classify_dodge_direction(direction: Vector3) -> String:
	if direction.length_squared() <= 0.0001:
		return "forward"
	if _get_movement_input().length() <= 0.01 and _has_lock_on_target():
		return "backstep"
	var alignment: float = get_actor_forward().dot(direction.normalized())
	if alignment >= 0.5:
		return "forward"
	if alignment <= -0.5:
		return "backward"
	return "side"


func get_dodge_velocity() -> Vector3:
	if not is_active:
		return Vector3.ZERO
	var multiplier: float = (
		profile.sample_speed_multiplier(dodge_progress)
		if profile != null
		else lerpf(1.0, 0.55, dodge_progress)
	)
	last_dodge_velocity = dodge_direction * dodge_speed * multiplier
	return last_dodge_velocity


func get_normalized_progress() -> float:
	return dodge_progress


func get_dodge_phase() -> String:
	return dodge_phase


func get_visual_pose_weight() -> float:
	if not is_active:
		return 0.0
	match dodge_phase:
		"launch":
			return smoothstep(0.0, 1.0, dodge_progress / maxf(get_launch_end(), 0.001))
		"travel":
			return 1.0
		"landing":
			var landing_weight: float = inverse_lerp(get_travel_end(), get_landing_end(), dodge_progress)
			return lerpf(1.0, 0.72, smoothstep(0.0, 1.0, landing_weight))
		"recovery":
			var recovery_weight: float = inverse_lerp(get_landing_end(), 1.0, dodge_progress)
			return lerpf(0.72, 0.0, smoothstep(0.0, 1.0, recovery_weight))
	return 0.0


func get_iframe_visual_weight() -> float:
	if not is_active:
		return 0.0
	var start: float = get_invulnerability_start()
	var finish: float = get_invulnerability_end()
	if dodge_progress < start or dodge_progress >= finish:
		return 0.0
	var fade_span: float = minf(0.08, maxf((finish - start) * 0.25, 0.01))
	var fade_in: float = smoothstep(start, start + fade_span, dodge_progress)
	var fade_out: float = 1.0 - smoothstep(finish - fade_span, finish, dodge_progress)
	return clampf(minf(fade_in, fade_out), 0.0, 1.0)


func is_dodge_active() -> bool:
	return is_active


func is_invulnerability_window_active() -> bool:
	return iframe_active


func can_cancel_into_weapon_technique() -> bool:
	return is_active and dodge_progress >= get_attack_cancel_start()


func can_cancel_into_cast() -> bool:
	return is_active and dodge_progress >= get_cast_cancel_start()


func can_cancel_into_guard() -> bool:
	return is_active and dodge_progress >= get_guard_cancel_start()


func can_chain_dodge() -> bool:
	if not is_active or chain_count >= get_maximum_consecutive_dodges():
		return false
	return dodge_progress >= get_chain_start() and dodge_progress <= get_chain_end()


func cancel_into_weapon_technique() -> Vector3:
	if not can_cancel_into_weapon_technique():
		return Vector3.ZERO
	var carried_direction: Vector3 = dodge_direction
	_finish_dodge("weapon_technique")
	return carried_direction


func cancel_dodge(reason: String = "cancelled") -> Vector3:
	if not is_active:
		return Vector3.ZERO
	var carried_velocity: Vector3 = last_dodge_velocity
	_finish_dodge(reason)
	return carried_velocity


func apply_debug_steering(requested_direction: Vector3, delta: float) -> void:
	if not is_active or requested_direction.length_squared() <= 0.0001:
		return
	_apply_steering_direction(requested_direction.normalized(), delta)


func get_actor_forward() -> Vector3:
	if actor == null:
		return Vector3.FORWARD
	var forward: Vector3 = -actor.global_transform.basis.z
	forward.y = 0.0
	return forward.normalized() if forward.length() > 0.01 else Vector3.FORWARD


func get_actor_right() -> Vector3:
	if actor == null:
		return Vector3.RIGHT
	var right: Vector3 = actor.global_transform.basis.x
	right.y = 0.0
	return right.normalized() if right.length() > 0.01 else Vector3.RIGHT


func get_debug_data() -> Dictionary:
	return {
		"active": is_active,
		"phase": dodge_phase,
		"progress": snappedf(dodge_progress, 0.01),
		"time": snappedf(dodge_timer, 0.01),
		"duration": snappedf(dodge_duration, 0.01),
		"cooldown": snappedf(cooldown_timer, 0.01),
		"direction": dodge_direction,
		"kind": dodge_kind,
		"distance": snappedf(dodge_distance, 0.01),
		"base_speed": snappedf(dodge_speed, 0.01),
		"velocity": last_dodge_velocity,
		"speed": snappedf(last_dodge_velocity.length(), 0.01),
		"iframe": iframe_active,
		"iframe_weight": snappedf(get_iframe_visual_weight(), 0.01),
		"chain_count": chain_count,
		"chain_ready": can_chain_dodge(),
		"attack_cancel_ready": can_cancel_into_weapon_technique(),
		"cast_cancel_ready": can_cancel_into_cast(),
		"guard_cancel_ready": can_cancel_into_guard(),
		"buffered_chain": snappedf(buffered_chain_remaining, 0.01),
		"buffered_follow_up": buffered_follow_up,
		"buffered_follow_up_time": snappedf(buffered_follow_up_remaining, 0.01),
		"last_finish_reason": last_finish_reason,
		"profile_ready": profile != null,
	}


func _start_dodge(direction: Vector3, direction_kind: String, chained: bool) -> bool:
	if direction.length_squared() <= 0.0001:
		return false
	if chained and chain_count >= get_maximum_consecutive_dodges():
		return false
	if not _spend_dodge_stamina():
		return false

	is_active = true
	dodge_elapsed = 0.0
	dodge_progress = 0.0
	dodge_duration = get_profile_duration()
	dodge_timer = dodge_duration
	dodge_direction = direction.normalized()
	dodge_kind = direction_kind if direction_kind != "" else classify_dodge_direction(direction)
	dodge_distance = get_profile_distance() * get_distance_multiplier(dodge_kind)
	var curve_average: float = profile.get_average_speed_multiplier() if profile != null else 0.775
	dodge_speed = dodge_distance / maxf(dodge_duration * curve_average, 0.001)
	last_dodge_velocity = dodge_direction * dodge_speed * (
		profile.sample_speed_multiplier(0.0) if profile != null else 1.0
	)
	cooldown_timer = dodge_duration + get_profile_cooldown()
	chain_count = chain_count + 1 if chained else 1
	iframe_active = false
	iframe_started = false
	buffered_chain_remaining = 0.0
	buffered_follow_up = FOLLOW_UP_NONE
	buffered_follow_up_remaining = 0.0
	_set_phase("launch")
	last_finish_reason = "active"

	if action_state != null:
		action_state.begin_dodge(dodge_duration)

	dodge_started.emit(dodge_direction, dodge_kind, chain_count)
	_show_message("Grace dodges" + (" again." if chained else "."))
	return true


func _finish_dodge(reason: String) -> void:
	if not is_active:
		return
	is_active = false
	dodge_timer = 0.0
	dodge_elapsed = dodge_duration
	dodge_progress = 1.0
	iframe_active = false
	iframe_started = false
	buffered_chain_remaining = 0.0
	buffered_follow_up = FOLLOW_UP_NONE
	buffered_follow_up_remaining = 0.0
	last_finish_reason = reason
	_set_phase("idle")
	if action_state != null:
		action_state.end_dodge()
	dodge_iframe_changed.emit(false)
	dodge_finished.emit(reason)


func _capture_follow_up_inputs() -> void:
	if InputMap.has_action("cast_spell") and Input.is_action_just_pressed("cast_spell"):
		buffer_follow_up(FOLLOW_UP_CAST)
	if InputMap.has_action("guard") and Input.is_action_just_pressed("guard"):
		buffer_follow_up(FOLLOW_UP_GUARD)


func _try_execute_buffered_actions() -> void:
	if buffered_chain_remaining > 0.0 and can_chain_dodge():
		var direction: Vector3 = buffered_chain_direction
		if direction.length_squared() <= 0.0001:
			direction = dodge_direction
		_start_dodge(direction, buffered_chain_kind, true)
		return

	if buffered_follow_up == FOLLOW_UP_NONE or buffered_follow_up_remaining <= 0.0:
		return
	if buffered_follow_up == FOLLOW_UP_GUARD and not Input.is_action_pressed("guard"):
		buffered_follow_up = FOLLOW_UP_NONE
		buffered_follow_up_remaining = 0.0
		return
	if _can_execute_follow_up(buffered_follow_up):
		_execute_follow_up(buffered_follow_up)


func _can_execute_follow_up(follow_up: String) -> bool:
	match follow_up:
		FOLLOW_UP_CAST:
			return can_cancel_into_cast()
		FOLLOW_UP_GUARD:
			return can_cancel_into_guard()
	return false


func _execute_follow_up(follow_up: String) -> bool:
	if not _can_execute_follow_up(follow_up):
		return false
	_finish_dodge(follow_up + "_follow_up")
	var executed: bool = false
	match follow_up:
		FOLLOW_UP_CAST:
			if ability_caster != null and ability_caster.has_method("cast_from_player"):
				ability_caster.call("cast_from_player", actor)
				executed = true
		FOLLOW_UP_GUARD:
			if defense_controller != null:
				executed = defense_controller.begin_guard()
	if executed:
		dodge_follow_up_executed.emit(follow_up)
	return executed


func _update_buffer_timers(delta: float) -> void:
	buffered_chain_remaining = maxf(buffered_chain_remaining - maxf(delta, 0.0), 0.0)
	buffered_follow_up_remaining = maxf(
		buffered_follow_up_remaining - maxf(delta, 0.0),
		0.0
	)
	if buffered_chain_remaining <= 0.0:
		buffered_chain_direction = Vector3.ZERO
	if buffered_follow_up_remaining <= 0.0:
		buffered_follow_up = FOLLOW_UP_NONE


func _update_phase() -> void:
	var next_phase: String = profile.get_phase(dodge_progress) if profile != null else (
		"launch" if dodge_progress < 0.2 else "travel" if dodge_progress < 0.68 else "landing" if dodge_progress < 0.88 else "recovery"
	)
	_set_phase(next_phase)


func _set_phase(next_phase: String) -> void:
	if dodge_phase == next_phase:
		return
	var previous_phase: String = dodge_phase
	dodge_phase = next_phase
	dodge_phase_changed.emit(previous_phase, dodge_phase)


func _update_invulnerability_window() -> void:
	var should_be_active: bool = (
		dodge_progress >= get_invulnerability_start()
		and dodge_progress < get_invulnerability_end()
	)
	if should_be_active and not iframe_started:
		var remaining_normalized: float = maxf(get_invulnerability_end() - dodge_progress, 0.0)
		GameState.begin_player_invulnerability(remaining_normalized * dodge_duration)
		iframe_started = true
	if iframe_active != should_be_active:
		iframe_active = should_be_active
		dodge_iframe_changed.emit(iframe_active)


func _apply_late_steering(delta: float) -> void:
	if profile == null:
		return
	if dodge_progress < profile.steering_start or dodge_progress > profile.steering_end:
		return
	var input_vector: Vector2 = _get_movement_input()
	if input_vector.length() <= 0.08:
		return
	var requested_direction: Vector3 = _direction_from_input(input_vector)
	if requested_direction.length_squared() <= 0.0001:
		return
	_apply_steering_direction(requested_direction, delta)


func _apply_steering_direction(requested_direction: Vector3, delta: float) -> void:
	if profile == null or requested_direction.length_squared() <= 0.0001:
		return
	var target_direction: Vector3 = dodge_direction.slerp(
		requested_direction.normalized(),
		clampf(profile.steering_strength, 0.0, 1.0)
	).normalized()
	var angle: float = dodge_direction.angle_to(target_direction)
	if angle <= 0.0001:
		return
	var maximum_turn: float = deg_to_rad(profile.steering_turn_speed_degrees) * maxf(delta, 0.0)
	var weight: float = minf(1.0, maximum_turn / angle)
	dodge_direction = dodge_direction.slerp(target_direction, weight).normalized()


func _get_movement_input() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")


func _direction_from_input(input_vector: Vector2) -> Vector3:
	var forward: Vector3 = get_actor_forward()
	var right: Vector3 = get_actor_right()
	if not _has_lock_on_target() and use_camera_relative_direction:
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
	direction.y = 0.0
	return direction.normalized() if direction.length() > 0.01 else Vector3.ZERO


func _has_lock_on_target() -> bool:
	return (
		actor != null
		and actor.has_method("has_lock_on_target")
		and bool(actor.call("has_lock_on_target"))
	)


func _spend_dodge_stamina() -> bool:
	var cost: int = profile.stamina_cost if profile != null else FALLBACK_STAMINA_COST
	if cost <= 0:
		return true
	if GameState.spend_stamina(cost):
		return true
	_show_message("Not enough stamina.")
	return false


func get_profile_duration() -> float:
	return maxf(profile.duration, 0.01) if profile != null else FALLBACK_DURATION


func get_profile_distance() -> float:
	return maxf(profile.distance, 0.0) if profile != null else FALLBACK_DISTANCE


func get_profile_cooldown() -> float:
	return maxf(profile.cooldown, 0.0) if profile != null else FALLBACK_COOLDOWN


func get_distance_multiplier(direction_kind: String) -> float:
	return profile.get_distance_multiplier(direction_kind) if profile != null else 1.0


func get_input_buffer_seconds() -> float:
	return maxf(profile.input_buffer_seconds, 0.01) if profile != null else 0.16


func get_maximum_consecutive_dodges() -> int:
	return maxi(profile.maximum_consecutive_dodges, 1) if profile != null else 1


func get_launch_end() -> float:
	return profile.launch_end if profile != null else 0.2


func get_travel_end() -> float:
	return profile.travel_end if profile != null else 0.68


func get_landing_end() -> float:
	return profile.landing_end if profile != null else 0.88


func get_invulnerability_start() -> float:
	return profile.invulnerability_start if profile != null else 0.0


func get_invulnerability_end() -> float:
	return profile.invulnerability_end if profile != null else 0.75


func get_attack_cancel_start() -> float:
	return profile.attack_cancel_start if profile != null else 0.0


func get_cast_cancel_start() -> float:
	return profile.cast_cancel_start if profile != null else 0.72


func get_guard_cancel_start() -> float:
	return profile.guard_cancel_start if profile != null else 0.76


func get_chain_start() -> float:
	return profile.chain_start if profile != null else 0.76


func get_chain_end() -> float:
	return profile.chain_end if profile != null else 0.96


func _show_message(text: String) -> void:
	if show_debug_prints:
		print(text)
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
