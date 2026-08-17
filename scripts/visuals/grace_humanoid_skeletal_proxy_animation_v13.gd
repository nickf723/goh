extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_animation_v12.gd"
class_name GraceHumanoidSkeletalProxyAnimationV13

# V13 bridges locomotion into authored attack windups. Weapon animation remains
# authoritative; this adds only a brief lower-body/torso memory of the velocity
# and support foot Grace had when the attack began.

@export_group("Attack Entry Continuity")
@export_range(0.0, 1.0, 0.05) var attack_entry_strength: float = 0.72
@export_range(0.1, 0.9, 0.05) var attack_entry_startup_fraction: float = 0.48
@export_range(0.0, 0.12, 0.005) var attack_entry_forward_shift: float = 0.045
@export_range(0.0, 12.0, 0.5) var attack_entry_lean_degrees: float = 5.5

var attack_entry_local_velocity: Vector3 = Vector3.ZERO
var attack_entry_support_sign: float = 1.0
var attack_entry_stride_phase: float = 0.0
var last_attack_entry_weight: float = 0.0


func _on_animation_attack_started(attack: WeaponAttackDefinition) -> void:
	super._on_animation_attack_started(attack)
	attack_entry_local_velocity = Vector3.ZERO
	attack_entry_support_sign = 1.0 if last_left_support >= last_right_support else -1.0
	attack_entry_stride_phase = stride_phase
	if actor != null:
		var planar := Vector3(actor.velocity.x, 0.0, actor.velocity.z)
		attack_entry_local_velocity = (
			actor.global_transform.basis.orthonormalized().inverse() * planar
		)


func _pose_attack(targets: Dictionary) -> Vector3:
	var pelvis_offset: Vector3 = super._pose_attack(targets)
	last_attack_entry_weight = 0.0
	if weapon_controller == null or weapon_controller.current_attack == null:
		return pelvis_offset
	var attack: WeaponAttackDefinition = weapon_controller.current_attack
	if attack.extra_tags.has("weapon_charge_hold"):
		return pelvis_offset
	var speed: float = maxf(weapon_controller.get_attack_speed(), 0.05)
	var startup: float = maxf(attack.get_startup_duration(speed), 0.001)
	var elapsed_attack: float = maxf(weapon_controller.current_attack_elapsed, 0.0)
	if elapsed_attack >= startup:
		return pelvis_offset
	var startup_progress: float = clampf(elapsed_attack / startup, 0.0, 1.0)
	var memory_end: float = clampf(attack_entry_startup_fraction, 0.1, 0.95)
	var memory: float = 1.0 - smoothstep(0.0, memory_end, startup_progress)
	var planar_speed: float = Vector2(
		attack_entry_local_velocity.x,
		attack_entry_local_velocity.z
	).length()
	var speed_weight: float = clampf(
		planar_speed / maxf(locomotion_speed_reference, 0.1),
		0.0,
		1.0
	)
	if speed_weight <= 0.03:
		return pelvis_offset
	# Dash attacks already own unusually large travel, so preserve less of the
	# ordinary gait to avoid double-leaning them.
	var context_scale: float = (
		0.42
		if attack.extra_tags.has("dash_light") or attack.extra_tags.has("dash_heavy")
		else 1.0
	)
	var weight: float = memory * speed_weight * attack_entry_strength * context_scale
	last_attack_entry_weight = weight

	var local_forward: float = clampf(
		-attack_entry_local_velocity.z / maxf(planar_speed, 0.001),
		-1.0,
		1.0
	)
	var local_side: float = clampf(
		attack_entry_local_velocity.x / maxf(planar_speed, 0.001),
		-1.0,
		1.0
	)
	var support: float = attack_entry_support_sign

	_add_deg(targets, "pelvis", Vector3(
		-local_forward * attack_entry_lean_degrees * 0.35 * weight,
		-local_side * 2.5 * weight,
		-local_side * 3.0 * weight
	))
	_add_deg(targets, "spine_01", Vector3(
		-local_forward * attack_entry_lean_degrees * 0.52 * weight,
		local_side * 1.5 * weight,
		local_side * 2.0 * weight
	))
	_add_deg(targets, "spine_02", Vector3(
		-local_forward * attack_entry_lean_degrees * 0.72 * weight,
		local_side * 2.0 * weight,
		local_side * 2.5 * weight
	))
	_add_deg(targets, "chest", Vector3(
		-local_forward * attack_entry_lean_degrees * weight,
		local_side * 2.5 * weight,
		local_side * 3.0 * weight
	))

	# Keep the previous support leg under Grace for the first slice of startup.
	var left_support: bool = support > 0.0
	_add_deg(targets, "thigh_l", Vector3((-8.0 if left_support else 5.0) * weight, 0.0, -local_side * 2.0 * weight))
	_add_deg(targets, "thigh_r", Vector3((-8.0 if not left_support else 5.0) * weight, 0.0, -local_side * 2.0 * weight))
	_add_deg(targets, "shin_l", Vector3((14.0 if left_support else 4.0) * weight, 0.0, 0.0))
	_add_deg(targets, "shin_r", Vector3((14.0 if not left_support else 4.0) * weight, 0.0, 0.0))
	_add_deg(targets, "foot_l", Vector3(-2.5 * weight if left_support else 2.0 * weight, 0.0, 0.0))
	_add_deg(targets, "foot_r", Vector3(-2.5 * weight if not left_support else 2.0 * weight, 0.0, 0.0))

	pelvis_offset += Vector3(
		-local_side * 0.012 * weight,
		-0.018 * weight,
		-local_forward * attack_entry_forward_shift * weight
	)
	return pelvis_offset


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["animation_v13"] = true
	data["attack_entry_continuity"] = true
	data["attack_entry_weight"] = snappedf(last_attack_entry_weight, 0.01)
	data["attack_entry_velocity"] = attack_entry_local_velocity
	data["attack_entry_support"] = "left" if attack_entry_support_sign > 0.0 else "right"
	return data
