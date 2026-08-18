extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_animation_v30.gd"
class_name GraceHumanoidSkeletalProxyAnimationV31

# V31 is a footage-driven redirect cleanup. The full animation stack already
# gives Grace support-foot transfers, strafing, pivots, reversals, and turn lead.
# During fast redirects those layers can overlap enough to briefly widen the
# lower-body silhouette more than the motion needs. Keep the authored intent,
# but shorten the stride and reduce sidestep contribution while the pivot owns
# the turn.

@export_group("Redirect Cleanup")
@export_range(0.0, 1.0, 0.05) var redirect_stride_compression: float = 0.22
@export_range(0.0, 1.0, 0.05) var redirect_strafe_suppression: float = 0.42
@export_range(0.0, 1.0, 0.05) var redirect_arm_compression: float = 0.12
@export_range(0.0, 1.0, 0.05) var redirect_begin_weight: float = 0.18

var last_redirect_cleanup_weight: float = 0.0
var last_redirect_strafe_scale: float = 1.0


func _pose_locomotion(targets: Dictionary, delta: float) -> Vector3:
	var pelvis_offset: Vector3 = super._pose_locomotion(targets, delta)
	var redirect: float = _get_redirect_weight()
	last_redirect_cleanup_weight = redirect
	if redirect <= redirect_begin_weight:
		return pelvis_offset

	var normalized: float = inverse_lerp(
		redirect_begin_weight,
		1.0,
		redirect
	)
	normalized = smoothstep(0.0, 1.0, clampf(normalized, 0.0, 1.0))
	var leg_scale: float = 1.0 - redirect_stride_compression * normalized
	var arm_scale: float = 1.0 - redirect_arm_compression * normalized

	# Shorten the fore/aft stride during a redirect. The planted-foot/pivot layers
	# keep their lateral/yaw information, so the turn still reads clearly without
	# the feet splaying into a skating stance.
	for bone_name: String in ["thigh_l", "thigh_r"]:
		if targets.has(bone_name):
			var value: Vector3 = targets[bone_name] as Vector3
			value.x *= leg_scale
			targets[bone_name] = value
	for bone_name: String in ["upper_arm_l", "upper_arm_r"]:
		if targets.has(bone_name):
			var value: Vector3 = targets[bone_name] as Vector3
			value.x *= arm_scale
			targets[bone_name] = value

	return pelvis_offset


func _apply_strafe_gait(
	targets: Dictionary,
	side: float,
	weight: float
) -> void:
	var redirect: float = _get_redirect_weight()
	var suppression: float = smoothstep(
		redirect_begin_weight,
		1.0,
		redirect
	)
	var scale: float = 1.0 - redirect_strafe_suppression * suppression
	last_redirect_strafe_scale = clampf(scale, 0.0, 1.0)
	super._apply_strafe_gait(
		targets,
		side,
		weight * last_redirect_strafe_scale
	)


func _get_redirect_weight() -> float:
	if ground_motion_motor == null:
		return clampf(last_pivot_weight, 0.0, 1.0)
	return clampf(
		maxf(
			last_pivot_weight,
			maxf(
				ground_motion_motor.turning_weight,
				ground_motion_motor.reversal_weight
			)
		),
		0.0,
		1.0
	)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["animation_v31"] = true
	data["footage_redirect_cleanup"] = true
	data["redirect_cleanup_weight"] = snappedf(
		last_redirect_cleanup_weight,
		0.01
	)
	data["redirect_strafe_scale"] = snappedf(
		last_redirect_strafe_scale,
		0.01
	)
	return data
