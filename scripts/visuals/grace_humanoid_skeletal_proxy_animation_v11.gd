extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_animation_v10.gd"
class_name GraceHumanoidSkeletalProxyAnimationV11

# V11 resolves two tiny transition tells: which foot starts a run, and how Grace
# turns while otherwise stationary. Both use existing gameplay orientation and
# never move the CharacterBody3D themselves.

@export_group("Start Step")
@export_range(0.0, 1.0, 0.05) var idle_weight_start_influence: float = 0.9

@export_group("Turn In Place")
@export_range(0.0, 18.0, 0.5) var turn_in_place_pelvis_lag_degrees: float = 6.0
@export_range(0.0, 18.0, 0.5) var turn_in_place_foot_yaw_degrees: float = 8.0
@export_range(0.1, 8.0, 0.1) var turn_in_place_full_speed: float = 2.4
@export_range(1.0, 30.0, 0.5) var turn_rate_response: float = 12.0

var previous_actor_yaw: float = 0.0
var actor_yaw_initialized: bool = false
var smoothed_actor_yaw_rate: float = 0.0
var last_start_foot: String = "none"
var last_turn_in_place_weight: float = 0.0
var last_turn_in_place_side: float = 0.0


func _process(delta: float) -> void:
	_update_actor_turn_rate(maxf(delta, 0.0))
	super._process(delta)


func _pose_locomotion(targets: Dictionary, delta: float) -> Vector3:
	if previous_pose_state == "idle" and actor != null and actor.is_on_floor():
		# V2 flips start_lead_sign immediately before choosing stride phase. Set the
		# pre-flip sign from the current idle weight: positive idle wave loads the
		# left leg, so the right leg becomes the first free step, and vice versa.
		var idle_weight_wave: float = sin(elapsed * 0.58)
		if absf(idle_weight_wave) < 0.08:
			idle_weight_wave = 1.0 if start_lead_sign >= 0.0 else -1.0
		var weighted_sign: float = 1.0 if idle_weight_wave >= 0.0 else -1.0
		if idle_weight_start_influence >= 0.5:
			start_lead_sign = weighted_sign
		last_start_foot = "right" if weighted_sign > 0.0 else "left"
	return super._pose_locomotion(targets, delta)


func _pose_idle(targets: Dictionary) -> Vector3:
	var pelvis_offset: Vector3 = super._pose_idle(targets)
	pelvis_offset += _apply_turn_in_place(targets)
	return pelvis_offset


func _update_actor_turn_rate(delta: float) -> void:
	if actor == null or delta <= 0.0001:
		return
	var forward: Vector3 = -actor.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.0001:
		return
	forward = forward.normalized()
	var yaw: float = atan2(forward.x, forward.z)
	if not actor_yaw_initialized:
		previous_actor_yaw = yaw
		actor_yaw_initialized = true
		return
	var delta_yaw: float = wrapf(yaw - previous_actor_yaw, -PI, PI)
	previous_actor_yaw = yaw
	var raw_rate: float = delta_yaw / delta
	var blend: float = 1.0 - exp(-maxf(turn_rate_response, 0.01) * delta)
	smoothed_actor_yaw_rate = lerpf(smoothed_actor_yaw_rate, raw_rate, blend)


func _apply_turn_in_place(targets: Dictionary) -> Vector3:
	last_turn_in_place_weight = 0.0
	last_turn_in_place_side = 0.0
	if actor == null:
		return Vector3.ZERO
	var speed: float = Vector2(actor.velocity.x, actor.velocity.z).length()
	if speed > 0.18:
		return Vector3.ZERO
	if action_state != null and (
		action_state.is_attacking
		or action_state.is_casting
		or action_state.is_interacting
		or action_state.is_manipulating
		or action_state.is_using_item
	):
		return Vector3.ZERO
	var rate: float = smoothed_actor_yaw_rate
	var weight: float = clampf(absf(rate) / maxf(turn_in_place_full_speed, 0.1), 0.0, 1.0)
	if weight <= 0.04:
		return Vector3.ZERO
	weight = smoothstep(0.0, 1.0, weight)
	var side: float = 1.0 if rate > 0.0 else -1.0
	last_turn_in_place_weight = weight
	last_turn_in_place_side = side

	# Root rotation has already happened. A small local counter-rotation through the
	# hips/feet creates visual lag, while the head slightly leads the new heading.
	_add_deg(targets, "pelvis", Vector3(2.0 * weight, -side * turn_in_place_pelvis_lag_degrees * weight, -side * 1.5 * weight))
	_add_deg(targets, "spine_01", Vector3(0.0, side * 1.5 * weight, side * 1.0 * weight))
	_add_deg(targets, "spine_02", Vector3(0.0, side * 2.5 * weight, side * 1.2 * weight))
	_add_deg(targets, "chest", Vector3(0.0, side * 3.5 * weight, side * 1.5 * weight))
	_add_deg(targets, "neck", Vector3(0.0, side * 3.0 * weight, 0.0))
	_add_deg(targets, "head", Vector3(0.0, side * 5.0 * weight, -side * 0.8 * weight))

	var plant_left: bool = side > 0.0
	if plant_left:
		_add_deg(targets, "thigh_l", Vector3(-5.0 * weight, side * 3.0 * weight, 0.0))
		_add_deg(targets, "shin_l", Vector3(10.0 * weight, 0.0, 0.0))
		_add_deg(targets, "foot_l", Vector3(-2.0 * weight, side * turn_in_place_foot_yaw_degrees * weight, 0.0))
		_add_deg(targets, "toe_l", Vector3(4.0 * weight, side * 2.0 * weight, 0.0))
		_add_deg(targets, "foot_r", Vector3(1.0 * weight, side * turn_in_place_foot_yaw_degrees * 0.35 * weight, 0.0))
	else:
		_add_deg(targets, "thigh_r", Vector3(-5.0 * weight, side * 3.0 * weight, 0.0))
		_add_deg(targets, "shin_r", Vector3(10.0 * weight, 0.0, 0.0))
		_add_deg(targets, "foot_r", Vector3(-2.0 * weight, side * turn_in_place_foot_yaw_degrees * weight, 0.0))
		_add_deg(targets, "toe_r", Vector3(4.0 * weight, side * 2.0 * weight, 0.0))
		_add_deg(targets, "foot_l", Vector3(1.0 * weight, side * turn_in_place_foot_yaw_degrees * 0.35 * weight, 0.0))
	return Vector3(side * support_weight_shift * 0.45 * weight, -0.016 * weight, 0.0)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["animation_v11"] = true
	data["idle_weight_start_step"] = true
	data["last_start_foot"] = last_start_foot
	data["turn_in_place"] = true
	data["turn_in_place_weight"] = snappedf(last_turn_in_place_weight, 0.01)
	data["turn_in_place_side"] = last_turn_in_place_side
	data["actor_yaw_rate"] = snappedf(smoothed_actor_yaw_rate, 0.01)
	return data
