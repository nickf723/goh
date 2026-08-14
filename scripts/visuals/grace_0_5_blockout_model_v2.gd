extends "res://scripts/visuals/grace_0_5_blockout_model.gd"
class_name Grace05BlockoutModelV2

# V1 assigned bone_name before the BoneAttachment3D had a Skeleton3D parent.
# At runtime those attachments could remain on bone index -1, collapsing every
# modular body piece around the model origin and turning Grace into a tiny orb.
# Parent first, then bind by both stable index and readable name.


func _get_attachment(bone_name: String) -> BoneAttachment3D:
	if attachments.has(bone_name):
		return attachments[bone_name] as BoneAttachment3D

	var attachment: BoneAttachment3D = BoneAttachment3D.new()
	attachment.name = bone_name + "Attachment"
	skeleton.add_child(attachment)

	var bone_index: int = skeleton.find_bone(bone_name)
	attachment.bone_idx = bone_index
	attachment.bone_name = bone_name
	attachment.override_pose = false
	attachments[bone_name] = attachment

	if bone_index < 0:
		push_error(
			"Grace 0.5 could not bind "
			+ attachment.name
			+ " to missing bone "
			+ bone_name
		)
	return attachment


func _enter_tree() -> void:
	super._enter_tree()
	if skeleton != null:
		skeleton.force_update_all_bone_transforms()
	for attachment_value: Variant in attachments.values():
		if attachment_value is BoneAttachment3D:
			(attachment_value as BoneAttachment3D).on_skeleton_update()
	set_meta("grace_0_5_attachment_fix", true)


func get_attachment_span() -> float:
	var head: BoneAttachment3D = attachments.get("Head") as BoneAttachment3D
	var left_foot: BoneAttachment3D = attachments.get("LeftFoot") as BoneAttachment3D
	var right_foot: BoneAttachment3D = attachments.get("RightFoot") as BoneAttachment3D
	if head == null or left_foot == null or right_foot == null:
		return 0.0
	var feet_midpoint: Vector3 = left_foot.global_position.lerp(
		right_foot.global_position,
		0.5
	)
	return absf(head.global_position.y - feet_midpoint.y)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	var invalid_bindings: Array[String] = []
	for bone_name_variant: Variant in attachments.keys():
		var bone_name: String = str(bone_name_variant)
		var attachment: BoneAttachment3D = attachments[bone_name] as BoneAttachment3D
		if attachment == null or attachment.bone_idx < 0:
			invalid_bindings.append(bone_name)
	data["grace_0_5_blockout_v2"] = true
	data["attachments_bound_after_parenting"] = true
	data["attachment_count"] = attachments.size()
	data["invalid_attachment_bindings"] = invalid_bindings
	data["attachment_span"] = snappedf(get_attachment_span(), 0.001)
	return data
