extends Node
class_name AirborneReactionController

signal air_state_changed(previous_state: String, new_state: String)
signal landed(recovery_time: float)
signal ground_bounced(bounce_count: int)
signal plunge_started

enum AirState {
	GROUNDED,
	LAUNCHED,
	AIRBORNE,
	FALLING,
	LANDING,
}

@export_group("Airborne Motion")
@export var launch_velocity_threshold: float = 0.45
@export var apex_velocity_threshold: float = 0.1
@export var launch_state_duration: float = 0.12
@export var landing_recovery_duration: float = 0.24

@export_group("Juggle Control")
@export var base_air_hitstun: float = 0.32
@export var minimum_air_hitstun: float = 0.08
@export var juggle_resistance_per_hit: float = 0.18
@export var juggle_resistance_decay_per_second: float = 0.24
@export_range(0.0, 0.95, 0.01) var max_juggle_resistance: float = 0.78
@export_range(0.05, 1.0, 0.01) var minimum_launch_multiplier: float = 0.34

@export_group("Ground Bounce")
@export var ground_bounce_min_fall_speed: float = 5.5
@export var ground_bounce_velocity: float = 4.6
@export var max_ground_bounces: int = 1

var air_state: AirState = AirState.GROUNDED
var air_state_timer: float = 0.0
var air_hitstun_timer: float = 0.0
var juggle_resistance: float = 0.0
var pending_launch_multiplier: float = 1.0
var pending_ground_bounce: bool = false
var ground_bounces_used: int = 0
var last_payload_summary: String = "none"

var actor: CharacterBody3D
var force_receiver: Node
var status_receiver: Node


func _ready() -> void:
	add_to_group("debuggable")
	resolve_components()
	set_physics_process(actor != null)


func resolve_components() -> void:
	actor = get_parent() as CharacterBody3D
	if actor == null:
		return
	force_receiver = actor.get_node_or_null("ForceReceiver")
	status_receiver = actor.get_node_or_null("StatusReceiver")


func _physics_process(delta: float) -> void:
	if actor == null:
		resolve_components()
		if actor == null:
			return

	air_state_timer = maxf(air_state_timer - delta, 0.0)
	air_hitstun_timer = maxf(air_hitstun_timer - delta, 0.0)
	juggle_resistance = move_toward(
		juggle_resistance,
		0.0,
		maxf(juggle_resistance_decay_per_second, 0.0) * delta
	)

	consume_launch_impulse()
	update_air_state()
	sustain_airborne_action_lock()


func register_payload(payload: DamagePayload) -> void:
	if payload == null:
		return

	last_payload_summary = payload.source_name + " | " + ",".join(payload.tags)
	var launcher: bool = (
		payload.knockback_up_strength > launch_velocity_threshold
		or payload.tags.has("launcher")
		or payload.tags.has("technique_launcher")
	)
	var aerial_hit: bool = (
		is_airborne()
		or launcher
		or payload.tags.has("context_aerial")
		or payload.tags.has("technique_aerial_neutral")
		or payload.tags.has("technique_aerial_forward")
		or payload.tags.has("technique_aerial_down")
	)

	if aerial_hit:
		var resistance_before_hit: float = juggle_resistance
		pending_launch_multiplier = minf(
			pending_launch_multiplier,
			clampf(1.0 - resistance_before_hit, minimum_launch_multiplier, 1.0)
		)
		air_hitstun_timer = maxf(
			air_hitstun_timer,
			maxf(
				base_air_hitstun * (1.0 - resistance_before_hit),
				minimum_air_hitstun
			)
		)
		juggle_resistance = minf(
			juggle_resistance + maxf(juggle_resistance_per_hit, 0.0),
			max_juggle_resistance
		)

	if is_plunging_payload(payload) and is_airborne():
		pending_ground_bounce = true
		actor.velocity.y = minf(actor.velocity.y, -absf(ground_bounce_min_fall_speed))
		set_air_state(AirState.FALLING)
		plunge_started.emit()


func consume_launch_impulse() -> void:
	if force_receiver == null:
		force_receiver = actor.get_node_or_null("ForceReceiver")
	if force_receiver == null or not force_receiver.has_method("consume_vertical_impulse"):
		return

	var vertical_impulse: float = float(force_receiver.call("consume_vertical_impulse"))
	if vertical_impulse <= launch_velocity_threshold:
		return

	var applied_velocity: float = vertical_impulse * pending_launch_multiplier
	pending_launch_multiplier = 1.0
	actor.velocity.y = maxf(actor.velocity.y, applied_velocity)
	air_hitstun_timer = maxf(air_hitstun_timer, minimum_air_hitstun)
	set_air_state(AirState.LAUNCHED, launch_state_duration)


func update_air_state() -> void:
	var grounded: bool = actor.is_on_floor()

	match air_state:
		AirState.GROUNDED:
			if not grounded and actor.velocity.y > launch_velocity_threshold:
				set_air_state(AirState.LAUNCHED, launch_state_duration)
		AirState.LAUNCHED:
			if air_state_timer <= 0.0:
				set_air_state(
					AirState.AIRBORNE if actor.velocity.y > apex_velocity_threshold else AirState.FALLING
				)
		AirState.AIRBORNE:
			if actor.velocity.y <= apex_velocity_threshold:
				set_air_state(AirState.FALLING)
		AirState.FALLING:
			if grounded:
				resolve_landing()
		AirState.LANDING:
			if not grounded and actor.velocity.y > launch_velocity_threshold:
				set_air_state(AirState.LAUNCHED, launch_state_duration)
			elif air_state_timer <= 0.0:
				pending_ground_bounce = false
				ground_bounces_used = 0
				set_air_state(AirState.GROUNDED)


func resolve_landing() -> void:
	if pending_ground_bounce and ground_bounces_used < maxi(max_ground_bounces, 0):
		pending_ground_bounce = false
		ground_bounces_used += 1
		var bounce_multiplier: float = clampf(
			1.0 - juggle_resistance * 0.5,
			minimum_launch_multiplier,
			1.0
		)
		actor.velocity.y = absf(ground_bounce_velocity) * bounce_multiplier
		air_hitstun_timer = maxf(air_hitstun_timer, minimum_air_hitstun)
		set_air_state(AirState.LAUNCHED, launch_state_duration)
		ground_bounced.emit(ground_bounces_used)
		return

	pending_ground_bounce = false
	actor.velocity.y = minf(actor.velocity.y, -0.1)
	var recovery: float = maxf(
		landing_recovery_duration * (1.0 + juggle_resistance * 0.35),
		0.0
	)
	set_air_state(AirState.LANDING, recovery)
	landed.emit(recovery)


func sustain_airborne_action_lock() -> void:
	if status_receiver == null:
		status_receiver = actor.get_node_or_null("StatusReceiver")
	if status_receiver == null or not status_receiver.has_method("sustain_status"):
		return
	if air_state == AirState.GROUNDED:
		return

	var lock_duration: float = maxf(air_hitstun_timer, 0.12)
	if air_state == AirState.LANDING:
		lock_duration = maxf(lock_duration, air_state_timer)
	status_receiver.call("sustain_status", "staggered", lock_duration, 1.0, "Airborne Reaction")


func is_plunging_payload(payload: DamagePayload) -> bool:
	return (
		payload.tags.has("plunging")
		or payload.tags.has("aerial_down")
		or payload.tags.has("technique_aerial_down")
		or payload.tags.has("ground_bounce")
	)


func is_airborne() -> bool:
	return air_state in [AirState.LAUNCHED, AirState.AIRBORNE, AirState.FALLING]


func set_air_state(new_state: AirState, duration: float = 0.0) -> void:
	var previous_state: AirState = air_state
	air_state = new_state
	air_state_timer = maxf(duration, 0.0)
	if previous_state != new_state:
		air_state_changed.emit(
			AirState.keys()[previous_state],
			AirState.keys()[new_state]
		)


func reset_reaction() -> void:
	air_state = AirState.GROUNDED
	air_state_timer = 0.0
	air_hitstun_timer = 0.0
	juggle_resistance = 0.0
	pending_launch_multiplier = 1.0
	pending_ground_bounce = false
	ground_bounces_used = 0
	last_payload_summary = "none"


func get_debug_data() -> Dictionary:
	return {
		"air": AirState.keys()[air_state],
		"vy": snapped(actor.velocity.y, 0.01) if actor != null else 0.0,
		"hitstun": snapped(air_hitstun_timer, 0.01),
		"juggle": snapped(juggle_resistance, 0.01),
		"bounce": str(ground_bounces_used) + "/" + str(max_ground_bounces),
		"last": last_payload_summary,
	}
