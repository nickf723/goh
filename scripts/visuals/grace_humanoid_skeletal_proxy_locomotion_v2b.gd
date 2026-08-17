extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_locomotion_v2.gd"
class_name GraceHumanoidSkeletalProxyLocomotionV2B

# V2's pose helpers correctly layer bone rotations, but Vector3 pelvis offsets
# are value types. Reapply the corresponding translation deltas here so stops
# and landings visibly carry Grace's center of mass as well as her joints.


func _pose_idle(targets: Dictionary) -> Vector3:
	var pelvis_offset: Vector3 = super._pose_idle(targets)
	pelvis_offset += _get_stop_translation_delta()
	pelvis_offset += _get_landing_translation_delta()
	return pelvis_offset


func _pose_locomotion(targets: Dictionary, delta: float) -> Vector3:
	var pelvis_offset: Vector3 = super._pose_locomotion(targets, delta)
	pelvis_offset += _get_landing_translation_delta()
	return pelvis_offset


func _get_stop_translation_delta() -> Vector3:
	var since_stop: float = elapsed - locomotion_stopped_at
	if since_stop < 0.0 or since_stop > stop_pose_seconds:
		return Vector3.ZERO
	var progress: float = clampf(
		since_stop / maxf(stop_pose_seconds, 0.01),
		0.0,
		1.0
	)
	var weight: float = (
		1.0 - smoothstep(0.0, 1.0, progress)
	) * stop_speed_weight
	return Vector3(0.0, -0.045 * weight, 0.025 * weight)


func _get_landing_translation_delta() -> Vector3:
	if (
		locomotion_vertical_controller == null
		or locomotion_vertical_controller.vertical_state != "landing"
	):
		return Vector3.ZERO
	var strength: float = clampf(
		locomotion_vertical_controller.last_landing_strength,
		0.0,
		1.0
	)
	if strength <= 0.001:
		return Vector3.ZERO
	var progress: float = locomotion_vertical_controller.get_phase_progress()
	var compression: float
	if progress < 0.3:
		compression = smoothstep(0.0, 1.0, progress / 0.3)
	else:
		compression = 1.0 - smoothstep(0.3, 1.0, progress)
	compression *= strength
	var moving: float = 0.0
	if actor != null:
		moving = clampf(
			Vector2(actor.velocity.x, actor.velocity.z).length()
			/ maxf(locomotion_speed_reference, 0.1),
			0.0,
			1.0
		)
	return Vector3(
		0.0,
		-landing_compression_depth * compression,
		-0.025 * moving * compression
	)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["locomotion_v2b"] = true
	data["landing_center_of_mass"] = true
	data["stop_center_of_mass"] = true
	return data
