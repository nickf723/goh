extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_v1.gd"

# Grounding correction for the active skeletal proxy.
# Skeleton3D pose positions are absolute pose positions in the skeleton frame.
# The v1 driver accidentally wrote a small animation delta directly into the
# pelvis position, replacing its authored 0.88 m rest height and pulling Grace
# almost an entire meter downward. Preserve the rest position and add motion on
# top of it instead.


func _blend_skeleton_pose(
	targets: Dictionary,
	pelvis_offset: Vector3,
	delta: float
) -> void:
	var blend: float = 1.0 if delta <= 0.0 else 1.0 - exp(-pose_response * delta)
	blend = clampf(blend, 0.0, 1.0)

	for bone_name_variant: Variant in bones.keys():
		var bone_name: String = str(bone_name_variant)
		var index: int = int(bones[bone_name])
		var target_euler: Vector3 = targets.get(bone_name, Vector3.ZERO) as Vector3
		var target_rotation: Quaternion = Basis.from_euler(target_euler).get_rotation_quaternion()
		var current: Quaternion = current_rotations.get(
			bone_name,
			Quaternion.IDENTITY
		) as Quaternion
		current = current.slerp(target_rotation, blend).normalized()
		current_rotations[bone_name] = current
		skeleton.set_bone_pose_rotation(index, current)

	current_pelvis_offset = current_pelvis_offset.lerp(pelvis_offset, blend)
	if bones.has("pelvis"):
		var pelvis_index: int = int(bones["pelvis"])
		var pelvis_rest_position: Vector3 = skeleton.get_bone_rest(pelvis_index).origin
		skeleton.set_bone_pose_position(
			pelvis_index,
			pelvis_rest_position + current_pelvis_offset
		)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	if skeleton == null:
		return data

	var foot_height: float = INF
	for foot_name: String in ["foot_l", "foot_r"]:
		if bones.has(foot_name):
			foot_height = minf(
				foot_height,
				skeleton.get_bone_global_pose(int(bones[foot_name])).origin.y
			)
	if foot_height == INF:
		foot_height = 0.0

	var head_height: float = 0.0
	if bones.has("head"):
		head_height = skeleton.get_bone_global_pose(int(bones["head"])).origin.y

	var pelvis_rest_height: float = 0.0
	var pelvis_pose_height: float = 0.0
	if bones.has("pelvis"):
		var pelvis_index: int = int(bones["pelvis"])
		pelvis_rest_height = skeleton.get_bone_rest(pelvis_index).origin.y
		pelvis_pose_height = skeleton.get_bone_pose_position(pelvis_index).y

	data["grounding_fix"] = true
	data["foot_height"] = snappedf(foot_height, 0.001)
	data["head_height"] = snappedf(head_height, 0.001)
	data["head_to_foot_span"] = snappedf(head_height - foot_height, 0.001)
	data["pelvis_rest_height"] = snappedf(pelvis_rest_height, 0.001)
	data["pelvis_pose_height"] = snappedf(pelvis_pose_height, 0.001)
	data["pelvis_rest_preserved"] = absf(
		pelvis_pose_height - (pelvis_rest_height + current_pelvis_offset.y)
	) < 0.0015
	return data
