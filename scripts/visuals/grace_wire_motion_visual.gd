extends "res://scripts/visuals/stylized_actor_visual.gd"
class_name GraceWireMotionVisual

const WeaponCharacterPoseCatalogScript = preload(
	"res://scripts/weapons/weapon_character_pose_catalog.gd"
)

@onready var wire_skeleton_renderer: GraceWireSkeletonRenderer = (
	get_node_or_null("WireSkeletonRenderer") as GraceWireSkeletonRenderer
)

var control_pose_sample: Dictionary = {}


func _ready() -> void:
	super._ready()
	add_to_group("grace_wire_motion_rig")
	if wire_skeleton_renderer != null:
		wire_skeleton_renderer.call_deferred("sample_now")


func sample_animation_pose(delta: float) -> void:
	control_pose_sample = _resolve_control_pose_sample()
	super.sample_animation_pose(delta)
	_pose_controlled_hands(delta)
	sync_animation_anchors()


func build_attack_pose() -> Dictionary:
	if control_pose_sample.is_empty():
		return super.build_attack_pose()
	return {
		"body": control_pose_sample.get("body", Vector3.ZERO),
		"head": control_pose_sample.get("head", Vector3.ZERO),
		"left_arm": control_pose_sample.get("left_arm", Vector3.ZERO),
		"right_arm": control_pose_sample.get("right_arm", Vector3.ZERO),
	}


func get_pose_nodes() -> Array[Node3D]:
	var nodes: Array[Node3D] = super.get_pose_nodes()
	for hand: Node3D in [left_hand, right_hand]:
		if hand != null and not nodes.has(hand):
			nodes.append(hand)
	return nodes


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
	debug_data["control_pose_id"] = str(control_pose_sample.get("profile_id", ""))
	debug_data["control_pose_phase"] = str(control_pose_sample.get("phase", "idle"))
	debug_data["control_pose_weight"] = snappedf(
		float(control_pose_sample.get("phase_weight", 0.0)),
		0.01
	)
	debug_data["right_hand_drive"] = (
		control_pose_sample.get("right_hand_position", Vector3.ZERO) as Vector3
	).length()
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


func _resolve_control_pose_sample() -> Dictionary:
	if weapon_controller == null:
		return {}
	var attack: WeaponAttackDefinition = (
		weapon_controller.get("current_attack") as WeaponAttackDefinition
	)
	if attack == null or not WeaponCharacterPoseCatalogScript.has_profile(attack.character_pose_id):
		return {}
	var attack_speed: float = 1.0
	if weapon_controller.has_method("get_attack_speed"):
		attack_speed = float(weapon_controller.call("get_attack_speed"))
	return WeaponCharacterPoseCatalogScript.sample_attack(
		attack,
		float(weapon_controller.get("current_attack_elapsed")),
		attack_speed
	)


func _pose_controlled_hands(delta: float) -> void:
	var left_rotation: Vector3 = control_pose_sample.get(
		"left_hand_rotation",
		Vector3.ZERO
	)
	var right_rotation: Vector3 = control_pose_sample.get(
		"right_hand_rotation",
		Vector3.ZERO
	)
	var left_position: Vector3 = control_pose_sample.get(
		"left_hand_position",
		Vector3.ZERO
	)
	var right_position: Vector3 = control_pose_sample.get(
		"right_hand_position",
		Vector3.ZERO
	)
	var response: float = pose_response * (1.35 if not control_pose_sample.is_empty() else 1.0)
	pose_node(left_hand, left_rotation, left_position, delta, response)
	pose_node(right_hand, right_rotation, right_position, delta, response)


func _sync_anchor_transform(
	source: Node3D,
	target: Node3D,
	local_offset: Vector3 = Vector3.ZERO
) -> void:
	if source == null or target == null:
		return
	var basis: Basis = source.global_basis.orthonormalized()
	target.global_transform = Transform3D(basis, source.to_global(local_offset))
