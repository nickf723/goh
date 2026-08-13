extends Node
class_name CombatEngagementPresenter

@export_range(0.0, 1.0, 0.05) var body_commitment: float = 0.34
@export_range(0.0, 0.3, 0.01) var forward_compression: float = 0.055
@export_range(0.0, 90.0, 1.0) var maximum_visual_yaw_degrees: float = 38.0

var actor: CharacterBody3D
var weapon_controller: CombatWeaponControllerV2
var grace_visual: GraceWireMotionVisualCombatV2

var _last_target_name: String = "none"
var _last_weight: float = 0.0
var _last_body_rotation: Vector3 = Vector3.ZERO
var _last_body_position: Vector3 = Vector3.ZERO


func _ready() -> void:
	# Grace samples her canonical pose at priority 40 and weapon-control visuals at
	# 120. Add engagement last, but feed it through Grace's existing motion-accent
	# bookkeeping so the next frame removes it cleanly before sampling again.
	process_priority = 165
	actor = get_parent() as CharacterBody3D
	if actor != null:
		weapon_controller = actor.get_node_or_null("WeaponController") as CombatWeaponControllerV2
		grace_visual = actor.get_node_or_null("GraceVisualV1") as GraceWireMotionVisualCombatV2
	add_to_group("combat_engagement_presenter")
	add_to_group("debuggable")


func _process(_delta: float) -> void:
	_last_body_rotation = Vector3.ZERO
	_last_body_position = Vector3.ZERO
	if actor == null or weapon_controller == null or grace_visual == null:
		return
	var attack: WeaponAttackDefinition = weapon_controller.current_attack
	var target: Node3D = weapon_controller.get_engagement_target()
	if attack == null or target == null:
		_last_target_name = "none"
		_last_weight = 0.0
		return

	var aim_point: Vector3 = weapon_controller.get_engagement_aim_point()
	var target_offset: Vector3 = aim_point - actor.global_position
	var planar: Vector3 = target_offset
	planar.y = 0.0
	if planar.length_squared() <= 0.0001:
		return

	var local_direction: Vector3 = (
		actor.global_transform.basis.orthonormalized().inverse()
		* planar.normalized()
	)
	var yaw: float = atan2(-local_direction.x, -local_direction.z)
	yaw = clampf(
		yaw,
		-deg_to_rad(maximum_visual_yaw_degrees),
		deg_to_rad(maximum_visual_yaw_degrees)
	)

	var weight: float = _get_attack_commitment_weight(attack)
	var body_rotation := Vector3(
		-0.025 * weight,
		yaw * body_commitment * weight,
		-local_direction.x * 0.035 * weight
	)
	var body_position := Vector3(
		-local_direction.x * 0.012 * weight,
		-0.012 * weight,
		-forward_compression * weight
	)

	# Reuse the same additive/removal contract as locomotion, dodge, footwork, and
	# the combat-continuity pass. This prevents target commitment from becoming a
	# second animator that slowly drifts the rig away from its authored base pose.
	grace_visual.call(
		"_add_continuity_accent",
		Vector3.ZERO,
		Vector3.ZERO,
		body_position,
		body_rotation,
		Vector3.ZERO,
		Vector3.ZERO
	)
	_last_target_name = target.name
	_last_weight = weight
	_last_body_rotation = body_rotation
	_last_body_position = body_position


func _get_attack_commitment_weight(attack: WeaponAttackDefinition) -> float:
	if attack == null or weapon_controller == null:
		return 0.0
	var speed: float = maxf(weapon_controller.get_attack_speed(), 0.05)
	var startup: float = maxf(attack.get_startup_duration(speed), 0.001)
	var active: float = maxf(attack.get_active_duration(speed), 0.001)
	var recovery: float = maxf(attack.get_recovery_duration(speed), 0.001)
	var time: float = maxf(weapon_controller.current_attack_elapsed, 0.0)
	if time < startup:
		return smoothstep(0.0, 1.0, clampf(time / startup, 0.0, 1.0))
	if time < startup + active:
		return 1.0
	var recovery_progress: float = clampf(
		(time - startup - active) / recovery,
		0.0,
		1.0
	)
	return 1.0 - smoothstep(0.45, 1.0, recovery_progress)


func get_debug_data() -> Dictionary:
	return {
		"combat_engagement_presenter": true,
		"target": _last_target_name,
		"weight": snappedf(_last_weight, 0.01),
		"body_rotation_offset": _last_body_rotation,
		"body_position_offset": _last_body_position,
	}
