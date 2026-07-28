extends Node
class_name PlayerVerticalMotionController

signal vertical_state_changed(previous_state: String, next_state: String)
signal jump_buffered(remaining_seconds: float)
signal jump_started(kind: String, launch_velocity: float)
signal jump_released(resulting_velocity: float)
signal apex_entered
signal landed(kind: String, impact_speed: float, strength: float)

@export var profile: VerticalMotionProfile

var actor: CharacterBody3D
var action_state: PlayerActionState

var vertical_state: String = "grounded"
var coyote_remaining: float = 0.0
var jump_buffer_remaining: float = 0.0
var launch_remaining: float = 0.0
var landing_remaining: float = 0.0
var landing_duration: float = 0.0
var airborne_time: float = 0.0
var jump_hold_elapsed: float = 0.0
var jump_cut_applied: bool = false
var jump_release_queued: bool = false
var apex_announced: bool = false
var active_jump_kind: String = ""
var last_jump_kind: String = "none"
var last_launch_velocity: float = 0.0
var peak_downward_speed: float = 0.0
var last_pre_move_vertical_velocity: float = 0.0
var last_gravity_scale: float = 1.0
var last_landing_kind: String = "none"
var last_landing_speed: float = 0.0
var last_landing_strength: float = 0.0
var last_external_state: String = ""


func _ready() -> void:
	actor = get_parent() as CharacterBody3D
	if actor != null:
		action_state = actor.get_node_or_null("PlayerActionState") as PlayerActionState
	add_to_group("player_vertical_motion_controller")
	add_to_group("debuggable")


func prepare_frame(
	delta: float,
	grounded: bool,
	allow_jump_input: bool = true
) -> void:
	var step: float = maxf(delta, 0.0)
	jump_buffer_remaining = maxf(jump_buffer_remaining - step, 0.0)
	launch_remaining = maxf(launch_remaining - step, 0.0)
	landing_remaining = maxf(landing_remaining - step, 0.0)

	if allow_jump_input and Input.is_action_just_pressed("jump"):
		queue_jump_request()

	if grounded:
		coyote_remaining = get_coyote_seconds()
		airborne_time = 0.0
		peak_downward_speed = 0.0
		if landing_remaining > 0.0:
			_set_vertical_state("landing")
		else:
			_set_vertical_state("grounded")
	else:
		coyote_remaining = maxf(coyote_remaining - step, 0.0)
		airborne_time += step
		if active_jump_kind != "":
			jump_hold_elapsed += step
		if actor != null:
			peak_downward_speed = maxf(peak_downward_speed, -actor.velocity.y)
		_update_air_state()


func queue_jump_request(duration: float = -1.0) -> void:
	var requested_duration: float = duration
	if requested_duration < 0.0:
		requested_duration = get_jump_buffer_seconds()
	jump_buffer_remaining = maxf(requested_duration, 0.0)
	jump_buffered.emit(jump_buffer_remaining)


func has_buffered_jump_request() -> bool:
	return jump_buffer_remaining > 0.0


func clear_jump_buffer() -> void:
	jump_buffer_remaining = 0.0


func try_consume_ground_jump(
	launch_velocity: float,
	kind: String = "jump"
) -> bool:
	if actor == null or not has_buffered_jump_request():
		return false
	if not actor.is_on_floor() and coyote_remaining <= 0.0:
		return false
	_start_jump(launch_velocity, kind)
	return true


func try_consume_air_jump(
	launch_velocity: float,
	kind: String = "air_jump"
) -> bool:
	if actor == null or not has_buffered_jump_request():
		return false
	_start_jump(launch_velocity, kind)
	return true


func begin_debug_jump(
	launch_velocity: float,
	kind: String = "jump"
) -> bool:
	if actor == null:
		return false
	queue_jump_request(maxf(get_jump_buffer_seconds(), 0.01))
	_start_jump(launch_velocity, kind)
	return true


func apply_jump_release(force: bool = false) -> bool:
	if actor == null or active_jump_kind == "" or jump_cut_applied:
		return false
	if force or Input.is_action_just_released("jump"):
		jump_release_queued = true
	if not jump_release_queued:
		return false
	if not force and jump_hold_elapsed < get_minimum_hold_seconds():
		return false
	if actor.velocity.y <= get_minimum_release_velocity():
		jump_release_queued = false
		return false

	actor.velocity.y *= get_jump_release_velocity_multiplier()
	jump_cut_applied = true
	jump_release_queued = false
	jump_released.emit(actor.velocity.y)
	_update_air_state()
	return true


func apply_gravity(delta: float, base_gravity: float) -> void:
	if actor == null or delta <= 0.0 or base_gravity <= 0.0:
		return
	apply_jump_release(false)
	last_gravity_scale = get_gravity_scale(actor.velocity.y, jump_cut_applied)
	actor.velocity.y = maxf(
		actor.velocity.y - base_gravity * last_gravity_scale * delta,
		-get_terminal_fall_speed()
	)
	peak_downward_speed = maxf(peak_downward_speed, -actor.velocity.y)
	_update_air_state()


func note_pre_move_velocity() -> void:
	if actor == null:
		return
	last_pre_move_vertical_velocity = actor.velocity.y
	peak_downward_speed = maxf(peak_downward_speed, -actor.velocity.y)


func record_post_move(was_grounded: bool) -> void:
	if actor == null:
		return
	var grounded_now: bool = actor.is_on_floor()
	if not was_grounded and grounded_now:
		var impact_speed: float = maxf(
			peak_downward_speed,
			-last_pre_move_vertical_velocity
		)
		_register_landing(impact_speed)
		coyote_remaining = get_coyote_seconds()
		active_jump_kind = ""
		jump_release_queued = false
		jump_cut_applied = false
		apex_announced = false
		airborne_time = 0.0
		peak_downward_speed = 0.0
		return

	if was_grounded and not grounded_now:
		_update_air_state()
		return

	if grounded_now:
		if landing_remaining > 0.0:
			_set_vertical_state("landing")
		else:
			_set_vertical_state("grounded")
	else:
		_update_air_state()


func set_external_state(state_name: String, clear_jump_request: bool = false) -> void:
	last_external_state = state_name
	active_jump_kind = ""
	jump_release_queued = false
	jump_cut_applied = false
	launch_remaining = 0.0
	landing_remaining = 0.0
	landing_duration = 0.0
	if clear_jump_request:
		clear_jump_buffer()
		coyote_remaining = 0.0
	_set_vertical_state(state_name)


func reset_motion() -> void:
	vertical_state = "grounded"
	coyote_remaining = 0.0
	jump_buffer_remaining = 0.0
	launch_remaining = 0.0
	landing_remaining = 0.0
	landing_duration = 0.0
	airborne_time = 0.0
	jump_hold_elapsed = 0.0
	jump_cut_applied = false
	jump_release_queued = false
	apex_announced = false
	active_jump_kind = ""
	last_jump_kind = "none"
	last_launch_velocity = 0.0
	peak_downward_speed = 0.0
	last_pre_move_vertical_velocity = 0.0
	last_gravity_scale = 1.0
	last_landing_kind = "none"
	last_landing_speed = 0.0
	last_landing_strength = 0.0
	last_external_state = ""


func get_phase_progress() -> float:
	match vertical_state:
		"launch":
			return clampf(
				1.0 - launch_remaining / maxf(get_launch_phase_seconds(), 0.001),
				0.0,
				1.0
			)
		"rising":
			if actor == null:
				return 0.0
			return clampf(
				1.0 - actor.velocity.y / maxf(last_launch_velocity, 0.001),
				0.0,
				1.0
			)
		"apex":
			if actor == null:
				return 1.0
			return clampf(
				1.0 - absf(actor.velocity.y) / maxf(get_apex_velocity_threshold(), 0.001),
				0.0,
				1.0
			)
		"falling":
			if actor == null:
				return 0.0
			return clampf(
				-actor.velocity.y / maxf(get_hard_landing_speed(), 0.001),
				0.0,
				1.0
			)
		"landing":
			return clampf(
				1.0 - landing_remaining / maxf(landing_duration, 0.001),
				0.0,
				1.0
			)
	return 0.0


func get_landing_wave() -> float:
	if vertical_state != "landing":
		return 0.0
	return sin(get_phase_progress() * PI)


func get_debug_data() -> Dictionary:
	return {
		"state": vertical_state,
		"phase_progress": snappedf(get_phase_progress(), 0.01),
		"vertical_velocity": snappedf(actor.velocity.y, 0.01) if actor != null else 0.0,
		"coyote": snappedf(coyote_remaining, 0.01),
		"jump_buffer": snappedf(jump_buffer_remaining, 0.01),
		"launch_remaining": snappedf(launch_remaining, 0.01),
		"airborne_time": snappedf(airborne_time, 0.01),
		"jump_hold": snappedf(jump_hold_elapsed, 0.01),
		"jump_cut": jump_cut_applied,
		"active_jump_kind": active_jump_kind,
		"last_jump_kind": last_jump_kind,
		"last_launch_velocity": snappedf(last_launch_velocity, 0.01),
		"gravity_scale": snappedf(last_gravity_scale, 0.01),
		"peak_downward_speed": snappedf(peak_downward_speed, 0.01),
		"landing_kind": last_landing_kind,
		"landing_speed": snappedf(last_landing_speed, 0.01),
		"landing_strength": snappedf(last_landing_strength, 0.01),
		"landing_remaining": snappedf(landing_remaining, 0.01),
		"external_state": last_external_state,
		"profile_ready": profile != null,
	}


func _start_jump(launch_velocity: float, kind: String) -> void:
	if actor == null:
		return
	last_launch_velocity = maxf(launch_velocity, 0.0) * get_launch_velocity_multiplier()
	actor.velocity.y = last_launch_velocity
	active_jump_kind = kind if kind != "" else "jump"
	last_jump_kind = active_jump_kind
	jump_buffer_remaining = 0.0
	coyote_remaining = 0.0
	launch_remaining = get_launch_phase_seconds()
	landing_remaining = 0.0
	landing_duration = 0.0
	airborne_time = 0.0
	jump_hold_elapsed = 0.0
	jump_cut_applied = false
	jump_release_queued = false
	apex_announced = false
	peak_downward_speed = 0.0
	last_external_state = ""
	_set_vertical_state("launch")
	jump_started.emit(active_jump_kind, last_launch_velocity)


func _register_landing(impact_speed: float) -> void:
	last_landing_speed = maxf(impact_speed, 0.0)
	last_landing_kind = classify_landing(last_landing_speed)
	last_landing_strength = get_landing_strength(last_landing_speed)
	landing_duration = get_landing_pose_duration(last_landing_speed)
	landing_remaining = landing_duration if last_landing_strength > 0.0 else 0.0
	if landing_remaining > 0.0:
		_set_vertical_state("landing")
	else:
		_set_vertical_state("grounded")
	landed.emit(last_landing_kind, last_landing_speed, last_landing_strength)


func _update_air_state() -> void:
	if actor == null:
		return
	if launch_remaining > 0.0 and actor.velocity.y > 0.0:
		_set_vertical_state("launch")
		return
	var threshold: float = get_apex_velocity_threshold()
	if actor.velocity.y > threshold:
		_set_vertical_state("rising")
	elif actor.velocity.y >= -threshold:
		_set_vertical_state("apex")
	else:
		_set_vertical_state("falling")


func _set_vertical_state(next_state: String) -> void:
	if next_state == "apex" and not apex_announced and active_jump_kind != "":
		apex_announced = true
		apex_entered.emit()
	elif (
		next_state == "falling"
		and not apex_announced
		and active_jump_kind != ""
		and vertical_state in ["launch", "rising"]
	):
		apex_announced = true
		apex_entered.emit()
	if vertical_state == next_state:
		return
	var previous_state: String = vertical_state
	vertical_state = next_state
	vertical_state_changed.emit(previous_state, vertical_state)


func get_coyote_seconds() -> float:
	return maxf(profile.coyote_seconds, 0.0) if profile != null else 0.12


func get_jump_buffer_seconds() -> float:
	return maxf(profile.jump_buffer_seconds, 0.0) if profile != null else 0.12


func get_launch_velocity_multiplier() -> float:
	return maxf(profile.launch_velocity_multiplier, 0.01) if profile != null else 1.0


func get_jump_release_velocity_multiplier() -> float:
	return clampf(profile.jump_release_velocity_multiplier, 0.01, 1.0) if profile != null else 0.52


func get_minimum_hold_seconds() -> float:
	return maxf(profile.minimum_hold_seconds, 0.0) if profile != null else 0.035


func get_minimum_release_velocity() -> float:
	return maxf(profile.minimum_release_velocity, 0.0) if profile != null else 0.45


func get_launch_phase_seconds() -> float:
	return maxf(profile.launch_phase_seconds, 0.01) if profile != null else 0.08


func get_apex_velocity_threshold() -> float:
	return maxf(profile.apex_velocity_threshold, 0.01) if profile != null else 0.65


func get_terminal_fall_speed() -> float:
	return maxf(profile.terminal_fall_speed, 0.1) if profile != null else 22.0


func get_hard_landing_speed() -> float:
	return maxf(profile.hard_landing_speed, 0.1) if profile != null else 8.8


func get_gravity_scale(vertical_velocity: float, cut_active: bool = false) -> float:
	if profile != null:
		return profile.get_gravity_scale(vertical_velocity, cut_active)
	if vertical_velocity > 0.65:
		return 1.0
	if vertical_velocity >= -0.65:
		return 0.72
	return 1.18


func classify_landing(impact_speed: float) -> String:
	return profile.classify_landing(impact_speed) if profile != null else (
		"hard" if impact_speed >= 8.8 else "firm" if impact_speed >= 4.6 else "light"
	)


func get_landing_strength(impact_speed: float) -> float:
	return profile.get_landing_strength(impact_speed) if profile != null else clampf(
		inverse_lerp(2.8, 10.4, impact_speed),
		0.0,
		1.0
	)


func get_landing_pose_duration(impact_speed: float) -> float:
	return profile.get_landing_pose_duration(impact_speed) if profile != null else lerpf(
		0.1,
		0.28,
		get_landing_strength(impact_speed)
	)
