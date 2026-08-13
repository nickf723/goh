extends Node
class_name CombatEngagementPresenter

@export_range(0.0, 1.0, 0.05) var body_commitment: float = 0.34
@export_range(0.0, 1.0, 0.05) var head_commitment: float = 0.58
@export_range(0.0, 0.3, 0.01) var forward_compression: float = 0.055
@export_range(0.0, 90.0, 1.0) var maximum_visual_yaw_degrees: float = 38.0
@export_range(0.0, 35.0, 1.0) var maximum_head_pitch_degrees: float = 14.0

var actor: CharacterBody3D
var weapon_controller: CombatWeaponControllerV2
var visual_root: Node3D
var body_root: Node3D
var head_root: Node3D

var _body_rotation_offset: Vector3 = Vector3.ZERO
var _body_position_offset: Vector3 = Vector3.ZERO
var _head_rotation_offset: Vector3 = Vector3.ZERO
var _last_target_name: String = "none"
var _last_weight: float = 0.0


func _ready() -> void:
	process_priority = 165
	actor = get_parent() as CharacterBody3D
	if actor != null:
		weapon_controller = actor.get_node_or_null("WeaponController") as CombatWeaponControllerV2
		visual_root = actor.get_node_or_null("GraceVisualV1/VisualRoot") as Node3D
		body_root = actor.get_node_or_null("GraceVisualV1/VisualRoot/BodyRoot") as Node3D
		head_root = actor.get_node_or_null("GraceVisualV1/VisualRoot/HeadRoot") as Node3D
	add_to_group("combat_engagement_presenter")
	add_to_group("debuggable")


func _process(_delta: float) -> void:
	_remove_previous_offsets()
	if actor == null or weapon_controller == null:
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
	var horizontal_distance: float = maxf(planar.length(), 0.01)
	var pitch: float = -atan2(target_offset.y - 0.9, horizontal_distance)
	pitch = clampf(
		pitch,
		-deg_to_rad(maximum_head_pitch_degrees),
		deg_to_rad(maximum_head_pitch_degrees)
	)

	var weight: float = _get_attack_commitment_weight(attack)
	_body_rotation_offset = Vector3(
		-0.025 * weight,
		yaw * body_commitment * weight,
		-local_direction.x * 0.035 * weight
	)
	_body_position_offset = Vector3(
		-local_direction.x * 0.012 * weight,
		-0.012 * weight,
		-forward_compression * weight
	)
	_head_rotation_offset = Vector3(
		pitch * head_commitment * weight,
		yaw * head_commitment * weight,
		0.0
	)
	_apply_offsets()
	_last_target_name = target.name
	_last_weight = weight


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


func _remove_previous_offsets() -> void:
	if body_root != null:
		body_root.rotation -= _body_rotation_offset
		body_root.position -= _body_position_offset
	if head_root != null:
		head_root.rotation -= _head_rotation_offset
	_body_rotation_offset = Vector3.ZERO
	_body_position_offset = Vector3.ZERO
	_head_rotation_offset = Vector3.ZERO


func _apply_offsets() -> void:
	if body_root != null:
		body_root.rotation += _body_rotation_offset
		body_root.position += _body_position_offset
	if head_root != null:
		head_root.rotation += _head_rotation_offset
	var grace_visual: Node = actor.get_node_or_null("GraceVisualV1") if actor != null else null
	if grace_visual != null and grace_visual.has_method("sync_animation_anchors"):
		grace_visual.call("sync_animation_anchors")


func get_debug_data() -> Dictionary:
	return {
		"combat_engagement_presenter": true,
		"target": _last_target_name,
		"weight": snappedf(_last_weight, 0.01),
		"body_rotation_offset": _body_rotation_offset,
		"head_rotation_offset": _head_rotation_offset,
	}
