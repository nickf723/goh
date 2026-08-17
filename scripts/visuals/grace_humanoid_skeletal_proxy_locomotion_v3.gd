extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_locomotion_v2d.gd"
class_name GraceHumanoidSkeletalProxyLocomotionV3

# V3 is the transition boundary. When a landing flows directly into movement,
# seed the gait from the leg already prepared to receive Grace and prevent the
# ordinary idle-to-run start logic from replacing that physical continuity.

var landing_to_run_count: int = 0


func _pose_locomotion(targets: Dictionary, delta: float) -> Vector3:
	var rolling_from_air: bool = previous_pose_state in ["jump", "fall"]
	if rolling_from_air:
		landing_support_sign = takeoff_support_sign
		stride_phase = 0.0 if landing_support_sign > 0.0 else PI
		landing_phase_seeded = true
		landing_to_run_count += 1
		# V2 treats any non-locomotion predecessor as a fresh run start. For this one
		# frame, present the landing as an already-established locomotion stride.
		previous_pose_state = "locomotion"
	return super._pose_locomotion(targets, delta)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["locomotion_v3"] = true
	data["landing_to_run_count"] = landing_to_run_count
	data["physical_transition_continuity"] = true
	return data
