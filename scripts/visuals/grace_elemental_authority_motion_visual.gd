extends "res://scripts/visuals/grace_incarnation_motion_visual.gd"
class_name GraceElementalAuthorityMotionVisual

var elemental_authority_controller: PlayerElementalAuthorityController
var last_authority_pose_id: String = ""
var last_authority_pose_phase: String = "idle"


func _ready() -> void:
	super._ready()
	elemental_authority_controller = get_parent().get_node_or_null(
		"ElementalAuthorityController"
	) as PlayerElementalAuthorityController
	add_to_group("elemental_authority_motion_visual")


func sample_animation_pose(delta: float) -> void:
	super.sample_animation_pose(delta)
	_apply_authority_cast_pose(delta)


func get_animation_debug_data() -> Dictionary:
	var data: Dictionary = super.get_animation_debug_data()
	data["authority_cast_pose_id"] = last_authority_pose_id
	data["authority_cast_pose_phase"] = last_authority_pose_phase
	if elemental_authority_controller != null:
		var authority: Dictionary = elemental_authority_controller.get_debug_data()
		data["authority_active"] = bool(authority.get("active", false))
		data["authority_id"] = str(authority.get("authority_id", "none"))
		data["authority_element"] = str(authority.get("element", "none"))
		data["authority_last_weave"] = str(authority.get("last_weave", "none"))
		data["authority_owned_fields"] = int(authority.get("owned_fields", 0))
	else:
		data["authority_active"] = false
		data["authority_id"] = "none"
		data["authority_element"] = "none"
		data["authority_last_weave"] = "none"
		data["authority_owned_fields"] = 0
	return data


func _apply_authority_cast_pose(delta: float) -> void:
	last_authority_pose_id = ""
	last_authority_pose_phase = "idle"
	if elemental_authority_controller == null:
		return
	var sample: Dictionary = elemental_authority_controller.get_cast_pose_sample()
	if sample.is_empty() or presentation_state != "cast":
		return
	last_authority_pose_id = str(sample.get("profile_id", "authority_cast"))
	last_authority_pose_phase = str(sample.get("phase", "idle"))
	var response: float = pose_response * 1.7
	pose_node(
		body_root,
		sample.get("body", Vector3.ZERO),
		Vector3.ZERO,
		delta,
		response
	)
	pose_node(
		head_root,
		sample.get("head", Vector3.ZERO),
		Vector3.ZERO,
		delta,
		response
	)
	pose_node(
		left_shoulder,
		sample.get("left_arm", Vector3.ZERO),
		Vector3.ZERO,
		delta,
		response
	)
	pose_node(
		right_shoulder,
		sample.get("right_arm", Vector3.ZERO),
		Vector3.ZERO,
		delta,
		response
	)
	pose_node(
		right_hand,
		sample.get("right_hand_rotation", Vector3.ZERO),
		sample.get("right_hand_position", Vector3.ZERO),
		delta,
		response * 1.15
	)
	sync_animation_anchors()
