extends "res://scripts/visuals/grace_0_5_blockout_model_v7.gd"
class_name Grace05BlockoutModelV8

# V8 adds tiny pupil motion on top of blink/secondary motion. It is intentionally
# measured in millimeters because the production proxy eyes are simple geometry.

@export_group("Eye Gaze")
@export_range(0.0, 0.02, 0.001) var maximum_horizontal_eye_shift: float = 0.008
@export_range(0.0, 0.02, 0.001) var maximum_vertical_eye_shift: float = 0.004
@export_range(0.0, 0.01, 0.0005) var neutral_eye_drift: float = 0.0015
@export_range(10.0, 90.0, 1.0) var full_eye_yaw_degrees: float = 38.0
@export_range(10.0, 90.0, 1.0) var full_eye_pitch_degrees: float = 28.0

var eye_gaze_horizontal: float = 0.0
var eye_gaze_vertical: float = 0.0
var eye_gaze_has_target: bool = false


func _process(delta: float) -> void:
	super._process(delta)
	_update_eye_gaze(maxf(delta, 0.0))
	_apply_eye_gaze()


func _update_eye_gaze(delta: float) -> void:
	if secondary_actor == null:
		eye_gaze_has_target = false
		return
	var target_horizontal: float = 0.0
	var target_vertical: float = 0.0
	var target_value: Variant = null
	if "lock_on_target" in secondary_actor:
		target_value = secondary_actor.get("lock_on_target")
	eye_gaze_has_target = target_value is Node3D
	if eye_gaze_has_target:
		var target: Node3D = target_value as Node3D
		if not is_instance_valid(target):
			eye_gaze_has_target = false
		else:
			var offset: Vector3 = target.global_position - (
				secondary_actor.global_position + Vector3.UP * 1.35
			)
			if offset.length_squared() > 0.0001:
				var local: Vector3 = (
					secondary_actor.global_transform.basis.orthonormalized().inverse()
					* offset.normalized()
				)
				var yaw_degrees: float = rad_to_deg(atan2(-local.x, -local.z))
				var pitch_degrees: float = rad_to_deg(asin(clampf(local.y, -1.0, 1.0)))
				target_horizontal = clampf(
					-yaw_degrees / maxf(full_eye_yaw_degrees, 1.0),
					-1.0,
					1.0
				)
				target_vertical = clampf(
					pitch_degrees / maxf(full_eye_pitch_degrees, 1.0),
					-1.0,
					1.0
				)
	if not eye_gaze_has_target:
		# Neutral drift is low-frequency and asymmetric. It is not intended to read
		# as deliberate looking around, only to prevent perfectly static pupils.
		target_horizontal = sin(secondary_phase * 0.47 + 0.8) * 0.18
		target_vertical = sin(secondary_phase * 0.31 + 2.1) * 0.12

	var response: float = 1.0 - exp(-maxf(14.0, secondary_response) * delta)
	eye_gaze_horizontal = lerpf(eye_gaze_horizontal, target_horizontal, response)
	eye_gaze_vertical = lerpf(eye_gaze_vertical, target_vertical, response)


func _apply_eye_gaze() -> void:
	if skeleton == null:
		return
	var head_index: int = skeleton.find_bone("Head")
	if head_index < 0:
		return
	var head_pose: Transform3D = skeleton.get_bone_global_pose(head_index)
	var horizontal_amount: float = (
		eye_gaze_horizontal * maximum_horizontal_eye_shift
		if eye_gaze_has_target
		else eye_gaze_horizontal * neutral_eye_drift
	)
	var vertical_amount: float = (
		eye_gaze_vertical * maximum_vertical_eye_shift
		if eye_gaze_has_target
		else eye_gaze_vertical * neutral_eye_drift
	)
	var offset: Vector3 = (
		head_pose.basis.x.normalized() * horizontal_amount
		+ head_pose.basis.y.normalized() * vertical_amount
	)
	for part_name: String in ["EyeLeft", "EyeRight", "EyeGlintLeft", "EyeGlintRight"]:
		var part: MeshInstance3D = get_node_or_null(part_name) as MeshInstance3D
		if part != null:
			part.position += offset


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["grace_0_5_eye_gaze_v8"] = true
	data["eye_gaze_target"] = eye_gaze_has_target
	data["eye_gaze_horizontal"] = snappedf(eye_gaze_horizontal, 0.01)
	data["eye_gaze_vertical"] = snappedf(eye_gaze_vertical, 0.01)
	return data
