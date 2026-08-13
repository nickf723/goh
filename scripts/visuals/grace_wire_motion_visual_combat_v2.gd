extends "res://scripts/visuals/grace_wire_motion_visual.gd"
class_name GraceWireMotionVisualCombatV2

# Combat-feel polish layer for the Arsenal Dojo player. The canonical wire rig
# still owns locomotion, attack poses, dodge accents, and footwork. This subclass
# only adds connective tissue between those authored states: movement carry into
# startup, follow-through after contact, braking during recovery, and a short
# residual settle after an attack ends.

@export_group("Combat Continuity")
@export_range(0.0, 0.3, 0.01) var light_settle_seconds: float = 0.11
@export_range(0.0, 0.4, 0.01) var heavy_settle_seconds: float = 0.18
@export_range(0.0, 1.0, 0.05) var locomotion_entry_carry: float = 0.42
@export_range(0.0, 2.0, 0.05) var followthrough_strength: float = 1.0
@export_range(0.0, 2.0, 0.05) var braking_strength: float = 1.0

var _active_attack: WeaponAttackDefinition
var _entry_local_velocity: Vector3 = Vector3.ZERO
var _swing_sign: float = 1.0
var _settle_remaining: float = 0.0
var _settle_duration: float = 0.0
var _settle_strength: float = 0.0
var _settle_sign: float = 1.0


func _ready() -> void:
	# Slightly quicker body response makes attack entry feel deliberate; the
	# residual settle below prevents the faster response from snapping back out.
	pose_response = maxf(pose_response, 15.5)
	super._ready()
	if weapon_controller != null:
		if weapon_controller.has_signal("attack_started"):
			weapon_controller.connect(
				"attack_started",
				Callable(self, "_on_continuity_attack_started")
			)
		if weapon_controller.has_signal("attack_finished"):
			weapon_controller.connect(
				"attack_finished",
				Callable(self, "_on_continuity_attack_finished")
			)
	add_to_group("combat_continuity_visual")


func _exit_tree() -> void:
	if weapon_controller != null:
		var started := Callable(self, "_on_continuity_attack_started")
		var finished := Callable(self, "_on_continuity_attack_finished")
		if weapon_controller.is_connected("attack_started", started):
			weapon_controller.disconnect("attack_started", started)
		if weapon_controller.is_connected("attack_finished", finished):
			weapon_controller.disconnect("attack_finished", finished)


func sample_animation_pose(delta: float) -> void:
	# The parent removes last frame's stored motion accent first, then builds the
	# canonical pose. Add our continuity delta afterward and register it in the
	# same accent bookkeeping so the next frame removes it cleanly.
	super.sample_animation_pose(delta)
	_apply_combat_continuity(maxf(delta, 0.0))


func get_animation_debug_data() -> Dictionary:
	var data: Dictionary = super.get_animation_debug_data()
	data["combat_continuity"] = true
	data["continuity_attack"] = (
		_active_attack.attack_id if _active_attack != null else "none"
	)
	data["continuity_swing_sign"] = _swing_sign
	data["continuity_settle_remaining"] = snappedf(_settle_remaining, 0.001)
	data["continuity_settle_strength"] = snappedf(_settle_strength, 0.01)
	return data


func _on_continuity_attack_started(attack: WeaponAttackDefinition) -> void:
	if attack == null:
		return
	_active_attack = attack
	_settle_remaining = 0.0
	_settle_duration = 0.0
	_settle_strength = 0.0
	_swing_sign = _resolve_swing_sign(attack)
	_entry_local_velocity = Vector3.ZERO
	if actor != null:
		var planar_velocity := Vector3(actor.velocity.x, 0.0, actor.velocity.z)
		_entry_local_velocity = (
			actor.global_transform.basis.orthonormalized().inverse()
			* planar_velocity
		)


func _on_continuity_attack_finished(_attack_id: String) -> void:
	if _active_attack == null:
		return
	var heavy: bool = _active_attack.input_kind == "heavy"
	_settle_duration = heavy_settle_seconds if heavy else light_settle_seconds
	_settle_remaining = _settle_duration
	_settle_strength = (
		clampf(_active_attack.damage_multiplier, 0.8, 2.2)
		* (1.12 if heavy else 0.82)
	)
	_settle_sign = _swing_sign
	_active_attack = null


func _apply_combat_continuity(delta: float) -> void:
	var root_position := Vector3.ZERO
	var root_rotation := Vector3.ZERO
	var body_position := Vector3.ZERO
	var body_rotation := Vector3.ZERO
	var left_leg_rotation := Vector3.ZERO
	var right_leg_rotation := Vector3.ZERO

	var attack: WeaponAttackDefinition = null
	if weapon_controller != null:
		attack = weapon_controller.get("current_attack") as WeaponAttackDefinition

	if attack != null:
		_active_attack = attack
		_swing_sign = _resolve_swing_sign(attack)
		var speed: float = 1.0
		if weapon_controller.has_method("get_attack_speed"):
			speed = maxf(float(weapon_controller.call("get_attack_speed")), 0.05)
		var elapsed_attack: float = float(
			weapon_controller.get("current_attack_elapsed")
		)
		var startup: float = maxf(attack.get_startup_duration(speed), 0.001)
		var active: float = maxf(attack.get_active_duration(speed), 0.001)
		var recovery: float = maxf(attack.get_recovery_duration(speed), 0.001)
		var heavy: bool = attack.input_kind == "heavy"
		var weight: float = clampf(attack.damage_multiplier, 0.8, 2.2)

		if elapsed_attack < startup:
			var progress: float = clampf(elapsed_attack / startup, 0.0, 1.0)
			var carry: float = (1.0 - smoothstep(0.0, 1.0, progress)) * locomotion_entry_carry
			var local_speed: float = clampf(_entry_local_velocity.length() / 6.0, 0.0, 1.0)
			body_rotation.x += clampf(
				-_entry_local_velocity.z * 0.012,
				-0.08,
				0.08
			) * carry
			body_rotation.z += clampf(
				-_entry_local_velocity.x * 0.01,
				-0.065,
				0.065
			) * carry
			root_position.y -= 0.018 * carry * local_speed
			# Plant the stance progressively instead of instantly erasing the stride.
			left_leg_rotation.x -= 0.07 * carry * _swing_sign
			right_leg_rotation.x += 0.07 * carry * _swing_sign
		elif elapsed_attack < startup + active:
			var progress: float = clampf(
				(elapsed_attack - startup) / active,
				0.0,
				1.0
			)
			var drive: float = sin(progress * PI) * followthrough_strength
			root_position.z -= (0.018 if heavy else 0.012) * weight * drive
			root_position.y -= (0.012 if heavy else 0.006) * drive
			body_rotation.x -= (0.04 if heavy else 0.025) * drive
			body_rotation.y += _swing_sign * (0.07 if heavy else 0.045) * drive
			left_leg_rotation.x += _swing_sign * 0.06 * drive
			right_leg_rotation.x -= _swing_sign * 0.09 * drive
		else:
			var progress: float = clampf(
				(elapsed_attack - startup - active) / recovery,
				0.0,
				1.0
			)
			# Continue past contact before braking. The first half carries the strike;
			# the second half compresses into a catch step and returns authority to
			# locomotion rather than linearly dissolving toward neutral.
			var overshoot: float = sin(progress * PI) * (1.0 - 0.2 * progress)
			var brake: float = smoothstep(0.48, 1.0, progress)
			var follow: float = followthrough_strength * weight
			root_position.z -= (0.036 if heavy else 0.022) * overshoot * follow
			body_rotation.y += _swing_sign * (0.13 if heavy else 0.085) * overshoot * follow
			body_rotation.x -= (0.045 if heavy else 0.025) * overshoot
			root_position.y -= (0.04 if heavy else 0.024) * brake * braking_strength
			body_rotation.x += (0.09 if heavy else 0.055) * brake * braking_strength
			body_position.y -= (0.018 if heavy else 0.01) * brake
			left_leg_rotation.x += _swing_sign * (0.12 * overshoot - 0.08 * brake)
			right_leg_rotation.x -= _swing_sign * (0.16 * overshoot - 0.1 * brake)
	else:
		_update_settle(delta)
		if _settle_remaining > 0.0 and _settle_duration > 0.0:
			var normalized: float = clampf(
				_settle_remaining / _settle_duration,
				0.0,
				1.0
			)
			var weight: float = normalized * normalized * _settle_strength
			root_position.y -= 0.018 * weight
			root_position.z -= 0.014 * weight
			body_rotation.x += 0.045 * weight
			body_rotation.y += _settle_sign * 0.06 * weight
			left_leg_rotation.x -= _settle_sign * 0.055 * weight
			right_leg_rotation.x += _settle_sign * 0.075 * weight

	_add_continuity_accent(
		root_position,
		root_rotation,
		body_position,
		body_rotation,
		left_leg_rotation,
		right_leg_rotation
	)


func _update_settle(delta: float) -> void:
	if _settle_remaining <= 0.0:
		_settle_remaining = 0.0
		return
	_settle_remaining = maxf(_settle_remaining - delta, 0.0)


func _add_continuity_accent(
	root_position: Vector3,
	root_rotation: Vector3,
	body_position: Vector3,
	body_rotation: Vector3,
	left_leg_rotation: Vector3,
	right_leg_rotation: Vector3
) -> void:
	if visual_root != null:
		visual_root.position += root_position
		visual_root.rotation += root_rotation
		motion_accent_root_position += root_position
		motion_accent_root_rotation += root_rotation
	if body_root != null:
		body_root.position += body_position
		body_root.rotation += body_rotation
		motion_accent_body_position += body_position
		motion_accent_body_rotation += body_rotation
	if left_leg != null:
		left_leg.rotation += left_leg_rotation
		motion_accent_left_leg_rotation += left_leg_rotation
	if right_leg != null:
		right_leg.rotation += right_leg_rotation
		motion_accent_right_leg_rotation += right_leg_rotation
	if (
		root_position != Vector3.ZERO
		or root_rotation != Vector3.ZERO
		or body_position != Vector3.ZERO
		or body_rotation != Vector3.ZERO
		or left_leg_rotation != Vector3.ZERO
		or right_leg_rotation != Vector3.ZERO
	):
		sync_animation_anchors()
		if wire_skeleton_renderer != null:
			wire_skeleton_renderer.sample_now(0.0)


func _resolve_swing_sign(attack: WeaponAttackDefinition) -> float:
	if attack == null:
		return 1.0
	var yaw_delta: float = (
		attack.strike_rotation_degrees.y
		- attack.windup_rotation_degrees.y
	)
	if absf(yaw_delta) > 1.0:
		return signf(yaw_delta)
	var profile_id: String = attack.character_pose_id.to_lower()
	if profile_id.contains("left"):
		return -1.0
	return 1.0
