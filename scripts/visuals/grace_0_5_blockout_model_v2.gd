extends "res://scripts/visuals/grace_0_5_blockout_model.gd"
class_name Grace05BlockoutModelV2

# Grace 0.5 deliberately stops using BoneAttachment3D. The attachment path was
# still collapsing modular pieces at runtime on the live imported presentation.
# Every visible form now remains a direct child of the model and samples its
# target bone's accumulated Skeleton3D pose explicitly each frame. This is the
# same dependable presentation pattern used by the original full-height proxy.

var bone_followers: Array[Dictionary] = []
var invalid_follower_bones: Array[String] = []
var last_follower_span: float = 0.0
var last_shoulder_span: float = 0.0


func _enter_tree() -> void:
	# super builds the skeleton and character. Calls to _add_mesh dispatch to this
	# override, so no BoneAttachment3D nodes are created during construction.
	super._enter_tree()
	process_priority = 230
	set_process(true)
	_refresh_bone_followers()
	set_meta("grace_0_5_direct_bone_follow", true)


func _process(_delta: float) -> void:
	_refresh_bone_followers()


func _add_mesh(
	part_name: String,
	bone_name: String,
	mesh: Mesh,
	material: Material,
	local_position: Vector3,
	local_rotation_degrees: Vector3 = Vector3.ZERO,
	local_scale: Vector3 = Vector3.ONE
) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = part_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = local_position
	instance.rotation_degrees = local_rotation_degrees
	instance.scale = local_scale
	add_child(instance)

	bone_followers.append({
		"node": instance,
		"part_name": part_name,
		"bone_name": bone_name,
		"local_transform": instance.transform,
	})
	visible_mesh_count += 1
	return instance


func _refresh_bone_followers() -> void:
	if skeleton == null:
		return
	skeleton.force_update_all_bone_transforms()
	invalid_follower_bones.clear()
	var minimum_y: float = INF
	var maximum_y: float = -INF
	for spec: Dictionary in bone_followers:
		var node: MeshInstance3D = spec.get("node") as MeshInstance3D
		var bone_name: String = str(spec.get("bone_name", ""))
		if node == null or not is_instance_valid(node):
			continue
		var bone_index: int = skeleton.find_bone(bone_name)
		if bone_index < 0:
			if not invalid_follower_bones.has(bone_name):
				invalid_follower_bones.append(bone_name)
			node.visible = false
			continue
		node.visible = true
		var bone_pose: Transform3D = skeleton.get_bone_global_pose(bone_index)
		var local_transform: Transform3D = spec.get(
			"local_transform",
			Transform3D.IDENTITY
		) as Transform3D
		node.transform = bone_pose * local_transform
		minimum_y = minf(minimum_y, node.position.y)
		maximum_y = maxf(maximum_y, node.position.y)

	last_follower_span = (
		maximum_y - minimum_y
		if minimum_y < INF and maximum_y > -INF
		else 0.0
	)
	var left_shoulder: MeshInstance3D = get_node_or_null(
		"LeftShoulderSleeve"
	) as MeshInstance3D
	var right_shoulder: MeshInstance3D = get_node_or_null(
		"RightShoulderSleeve"
	) as MeshInstance3D
	last_shoulder_span = (
		left_shoulder.position.distance_to(right_shoulder.position)
		if left_shoulder != null and right_shoulder != null
		else 0.0
	)


func get_follower_part(part_name: String) -> MeshInstance3D:
	return get_node_or_null(part_name) as MeshInstance3D


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["grace_0_5_blockout_v2"] = true
	data["direct_bone_follow"] = true
	data["bone_attachment_count"] = attachments.size()
	data["follower_count"] = bone_followers.size()
	data["invalid_follower_bones"] = invalid_follower_bones.duplicate()
	data["follower_span"] = snappedf(last_follower_span, 0.001)
	data["shoulder_span"] = snappedf(last_shoulder_span, 0.001)
	return data
