extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_locomotion_v2c.gd"
class_name GraceHumanoidSkeletalProxyLocomotionV2D

# V2C's contact helpers author rotations in-place through the shared Dictionary,
# but Vector3 translation arguments are value types. Restore the support/pivot
# center-of-mass deltas here without duplicating the foot-contact pose logic.


func _pose_locomotion(targets: Dictionary, delta: float) -> Vector3:
	var pelvis_offset: Vector3 = super._pose_locomotion(targets, delta)
	if actor == null:
		return pelvis_offset
	var speed_weight: float = clampf(
		Vector2(actor.velocity.x, actor.velocity.z).length()
		/ maxf(locomotion_speed_reference, 0.1),
		0.0,
		1.0
	)
	pelvis_offset.x += (
		last_left_support - last_right_support
	) * support_weight_shift * speed_weight
	pelvis_offset.y -= 0.022 * last_pivot_weight
	if ground_motion_motor != null:
		var motion: Dictionary = ground_motion_motor.get_debug_data()
		var reversal: float = clampf(
			float(motion.get("reversal_weight", 0.0)),
			0.0,
			1.0
		)
		pelvis_offset.y -= 0.028 * reversal * speed_weight
	return pelvis_offset


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["locomotion_v2d"] = true
	data["support_center_of_mass"] = true
	data["pivot_center_of_mass"] = true
	return data
