extends "res://scripts/visuals/grace_0_5_blockout_model_v4.gd"
class_name Grace05BlockoutModelV5

# Grace 0.5 remains a rigid modular blockout, but its largest silhouette pieces
# no longer need to look welded to the skeleton. V5 applies restrained additive
# inertia after the direct-bone follower pass, so every frame still begins from
# the authoritative skeletal pose and cannot accumulate drift.

@export_group("Secondary Motion")
@export_range(1.0, 30.0, 0.5) var secondary_response: float = 10.0
@export_range(0.0, 16.0, 0.5) var hair_pitch_degrees: float = 7.0
@export_range(0.0, 16.0, 0.5) var hair_roll_degrees: float = 5.0
@export_range(0.0, 20.0, 0.5) var robe_swing_degrees: float = 8.0
@export_range(0.0, 26.0, 0.5) var sash_swing_degrees: float = 13.0
@export_range(0.0, 10.0, 0.5) var landing_flutter_degrees: float = 4.0

var secondary_actor: CharacterBody3D
var previous_actor_velocity: Vector3 = Vector3.ZERO
var secondary_local_acceleration: Vector3 = Vector3.ZERO
var secondary_local_velocity: Vector3 = Vector3.ZERO
var secondary_vertical_impulse: float = 0.0
var secondary_phase: float = 0.0
var secondary_initialized: bool = false
var secondary_applied_frames: int = 0


func _process(delta: float) -> void:
	# Parent first restores every piece to its bone-authored transform.
	super._process(delta)
	_resolve_secondary_actor()
	if secondary_actor == null:
		return
	_update_secondary_state(maxf(delta, 0.0))
	_apply_secondary_motion()
	secondary_applied_frames += 1


func _resolve_secondary_actor() -> void:
	if secondary_actor != null and is_instance_valid(secondary_actor):
		return
	var cursor: Node = get_parent()
	while cursor != null:
		if cursor is CharacterBody3D:
			secondary_actor = cursor as CharacterBody3D
			previous_actor_velocity = secondary_actor.velocity
			secondary_initialized = true
			return
		cursor = cursor.get_parent()


func _update_secondary_state(delta: float) -> void:
	if secondary_actor == null:
		return
	secondary_phase += delta
	var basis: Basis = secondary_actor.global_transform.basis.orthonormalized()
	var local_velocity: Vector3 = basis.inverse() * secondary_actor.velocity
	var raw_acceleration: Vector3 = Vector3.ZERO
	if secondary_initialized and delta > 0.0001:
		raw_acceleration = basis.inverse() * (
			(secondary_actor.velocity - previous_actor_velocity) / delta
		)
	previous_actor_velocity = secondary_actor.velocity
	secondary_initialized = true

	var blend: float = 1.0 - exp(-maxf(secondary_response, 0.01) * delta)
	secondary_local_velocity = secondary_local_velocity.lerp(local_velocity, blend)
	var clamped_accel := Vector3(
		clampf(raw_acceleration.x, -28.0, 28.0),
		clampf(raw_acceleration.y, -35.0, 35.0),
		clampf(raw_acceleration.z, -28.0, 28.0)
	)
	secondary_local_acceleration = secondary_local_acceleration.lerp(clamped_accel, blend)
	var vertical_target: float = clampf(-raw_acceleration.y / 30.0, -1.0, 1.0)
	secondary_vertical_impulse = lerpf(secondary_vertical_impulse, vertical_target, blend)


func _apply_secondary_motion() -> void:
	var speed: float = Vector2(
		secondary_local_velocity.x,
		secondary_local_velocity.z
	).length()
	var speed_weight: float = clampf(speed / 6.0, 0.0, 1.0)
	var forward_lag: float = clampf(
		-secondary_local_acceleration.z / 22.0,
		-1.0,
		1.0
	)
	var side_lag: float = clampf(
		-secondary_local_acceleration.x / 22.0,
		-1.0,
		1.0
	)
	var vertical_lag: float = clampf(
		secondary_vertical_impulse,
		-1.0,
		1.0
	)
	var gait_flutter: float = sin(secondary_phase * lerpf(4.0, 8.5, speed_weight)) * speed_weight

	# Hair stays quiet at idle, then trails the skull under acceleration and aerial
	# changes. Side locks get opposite micro-phase so the silhouette never moves as
	# one rigid helmet.
	_add_part_rotation(
		"HairBack",
		Vector3(
			deg_to_rad(forward_lag * hair_pitch_degrees + vertical_lag * 2.5),
			0.0,
			deg_to_rad(side_lag * hair_roll_degrees)
		)
	)
	_add_part_rotation(
		"HairLockLeft",
		Vector3(
			deg_to_rad(forward_lag * hair_pitch_degrees * 1.15 + gait_flutter * 1.2),
			deg_to_rad(-side_lag * 1.8),
			deg_to_rad(side_lag * hair_roll_degrees * 1.2 + gait_flutter * 0.8)
		)
	)
	_add_part_rotation(
		"HairLockRight",
		Vector3(
			deg_to_rad(forward_lag * hair_pitch_degrees * 1.1 - gait_flutter * 1.0),
			deg_to_rad(-side_lag * 1.6),
			deg_to_rad(side_lag * hair_roll_degrees * 1.15 - gait_flutter * 0.7)
		)
	)

	var robe_pitch: float = forward_lag * robe_swing_degrees
	var robe_roll: float = side_lag * robe_swing_degrees * 0.62
	var landing_flutter: float = vertical_lag * landing_flutter_degrees
	_add_part_rotation(
		"FrontPanelLeft",
		Vector3(
			deg_to_rad(robe_pitch + landing_flutter + gait_flutter * 1.4),
			0.0,
			deg_to_rad(robe_roll * 0.75)
		)
	)
	_add_part_rotation(
		"FrontPanelRight",
		Vector3(
			deg_to_rad(robe_pitch + landing_flutter - gait_flutter * 1.2),
			0.0,
			deg_to_rad(robe_roll * 0.75)
		)
	)
	_add_part_rotation(
		"SidePanelLeft",
		Vector3(
			deg_to_rad(robe_pitch * 0.75 + landing_flutter * 0.8),
			deg_to_rad(-side_lag * 2.0),
			deg_to_rad(robe_roll + gait_flutter * 0.7)
		)
	)
	_add_part_rotation(
		"SidePanelRight",
		Vector3(
			deg_to_rad(robe_pitch * 0.75 + landing_flutter * 0.8),
			deg_to_rad(-side_lag * 2.0),
			deg_to_rad(robe_roll - gait_flutter * 0.7)
		)
	)
	_add_part_rotation(
		"BackRobePanel",
		Vector3(
			deg_to_rad(robe_pitch * 0.82 - vertical_lag * 1.5),
			0.0,
			deg_to_rad(robe_roll * 0.7)
		)
	)

	# Sash tails are the most permissive secondary forms, but remain far below a
	# cloth-simulation amplitude. They provide readable lag during vaults/dodges.
	var sash_wave: float = sin(secondary_phase * 5.7) * lerpf(0.35, 1.0, speed_weight)
	_add_part_rotation(
		"SashTailLeft",
		Vector3(
			deg_to_rad(forward_lag * sash_swing_degrees + vertical_lag * 3.0 + sash_wave * 2.0),
			deg_to_rad(-side_lag * 4.0),
			deg_to_rad(side_lag * sash_swing_degrees * 0.72 + sash_wave * 1.5)
		)
	)
	_add_part_rotation(
		"SashTailRight",
		Vector3(
			deg_to_rad(forward_lag * sash_swing_degrees * 0.92 + vertical_lag * 2.8 - sash_wave * 1.7),
			deg_to_rad(-side_lag * 3.5),
			deg_to_rad(side_lag * sash_swing_degrees * 0.68 - sash_wave * 1.35)
		)
	)


func _add_part_rotation(part_name: String, rotation_delta: Vector3) -> void:
	var part: MeshInstance3D = get_node_or_null(part_name) as MeshInstance3D
	if part == null:
		return
	part.rotation += rotation_delta


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["grace_0_5_secondary_motion_v5"] = true
	data["secondary_actor_found"] = secondary_actor != null
	data["secondary_velocity"] = secondary_local_velocity
	data["secondary_acceleration"] = secondary_local_acceleration
	data["secondary_vertical_impulse"] = snappedf(secondary_vertical_impulse, 0.01)
	data["secondary_applied_frames"] = secondary_applied_frames
	return data
