extends "res://scripts/visuals/stylized_actor_visual.gd"
class_name GraceWireMotionVisual

@onready var wire_skeleton_renderer: GraceWireSkeletonRenderer = (
	get_node_or_null("WireSkeletonRenderer") as GraceWireSkeletonRenderer
)


func _ready() -> void:
	super._ready()
	add_to_group("grace_wire_motion_rig")
	if wire_skeleton_renderer != null:
		wire_skeleton_renderer.call_deferred("sample_now")


func sync_animation_anchors() -> void:
	super.sync_animation_anchors()
	_sync_anchor_transform(head_root, head_anchor, Vector3(0.0, 0.05, 0.0))
	_sync_anchor_transform(left_hand, left_hand_anchor)
	_sync_anchor_transform(right_hand, right_hand_anchor)
	_sync_anchor_transform(body_root, chest_vfx_anchor, Vector3(0.0, 0.34, -0.18))

	if right_hand_anchor != null and weapon_hand_anchor != null:
		weapon_hand_anchor.global_transform = right_hand_anchor.global_transform


func set_wire_outfit(outfit_id: String) -> void:
	if wire_skeleton_renderer != null:
		wire_skeleton_renderer.set_outfit_id(outfit_id)


func get_animation_debug_data() -> Dictionary:
	var debug_data: Dictionary = super.get_animation_debug_data()
	debug_data["rig_mode"] = "wire_skeleton"
	if wire_skeleton_renderer != null:
		var wire_data: Dictionary = wire_skeleton_renderer.get_debug_data()
		var grounding: Dictionary = wire_data.get("grounding", {}) as Dictionary
		debug_data["wire_joint_count"] = int(wire_data.get("joint_count", 0))
		debug_data["wire_segment_count"] = int(wire_data.get("segment_count", 0))
		debug_data["wire_finite_pose"] = bool(wire_data.get("finite_pose", false))
		debug_data["wire_outfit_id"] = str(wire_data.get("outfit_id", ""))
		debug_data["wire_grounding_active"] = bool(grounding.get("active", false))
		debug_data["wire_left_ground_hit"] = bool(grounding.get("left_hit", false))
		debug_data["wire_right_ground_hit"] = bool(grounding.get("right_hit", false))
		debug_data["wire_left_toe_offset"] = float(grounding.get("left_toe_offset", 0.0))
		debug_data["wire_right_toe_offset"] = float(grounding.get("right_toe_offset", 0.0))
	return debug_data


func _sync_anchor_transform(
	source: Node3D,
	target: Node3D,
	local_offset: Vector3 = Vector3.ZERO
) -> void:
	if source == null or target == null:
		return
	var basis: Basis = source.global_basis.orthonormalized()
	target.global_transform = Transform3D(basis, source.to_global(local_offset))
