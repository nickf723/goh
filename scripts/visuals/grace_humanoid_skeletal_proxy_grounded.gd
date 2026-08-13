extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_v1.gd"

# Grounding and rest-pose correction for the active skeletal proxy.
#
# Two different Skeleton3D position contracts matter here:
# 1. the pelvis animation must preserve its authored 0.88 m rest position; and
# 2. every child bone must begin from its authored rest translation before we
#    animate rotations. The first v1 rig built bone rests but never reset the
#    live pose to those rests, so forearms, hands, shins, feet, neck, and head
#    could collapse around the pelvis. That produced the tiny "toddler" body and
#    put the weapon hand near the torso instead of at the end of the arm.


func _build_skeleton() -> void:
	super._build_skeleton()
	if skeleton == null:
		return
	# Populate the live pose positions from the hierarchy we just authored.
	# After this, normal animation changes rotations while preserving limb length.
	skeleton.reset_bone_poses()
	for bone_name_variant: Variant in bones.keys():
		var bone_name: String = str(bone_name_variant)
		var index: int = int(bones[bone_name])
		current_rotations[bone_name] = skeleton.get_bone_pose_rotation(index)


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

	var hand_span: float = 0.0
	if bones.has("hand_l") and bones.has("hand_r"):
		var left_hand: Vector3 = skeleton.get_bone_global_pose(int(bones["hand_l"])).origin
		var right_hand: Vector3 = skeleton.get_bone_global_pose(int(bones["hand_r"])).origin
		hand_span = left_hand.distance_to(right_hand)

	var leg_span: float = 0.0
	if bones.has("thigh_l") and bones.has("foot_l"):
		var thigh: Vector3 = skeleton.get_bone_global_pose(int(bones["thigh_l"])).origin
		var foot: Vector3 = skeleton.get_bone_global_pose(int(bones["foot_l"])).origin
		leg_span = thigh.distance_to(foot)

	data["grounding_fix"] = true
	data["rest_pose_initialized"] = true
	data["foot_height"] = snappedf(foot_height, 0.001)
	data["head_height"] = snappedf(head_height, 0.001)
	data["head_to_foot_span"] = snappedf(head_height - foot_height, 0.001)
	data["hand_span"] = snappedf(hand_span, 0.001)
	data["leg_span"] = snappedf(leg_span, 0.001)
	data["pelvis_rest_height"] = snappedf(pelvis_rest_height, 0.001)
	data["pelvis_pose_height"] = snappedf(pelvis_pose_height, 0.001)
	data["pelvis_rest_preserved"] = absf(
		pelvis_pose_height - (pelvis_rest_height + current_pelvis_offset.y)
	) < 0.0015
	return data
