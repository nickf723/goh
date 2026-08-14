extends Node

const HumanoidContractScript = preload(
	"res://scripts/visuals/grace_humanoid_rig_contract.gd"
)
const ProductionContractScript = preload(
	"res://scripts/visuals/grace_production_skeleton_contract.gd"
)
const Grace05Scene: PackedScene = preload(
	"res://scenes/actors/player/grace_0_5_blockout.tscn"
)
const CombatPlayerScene: PackedScene = preload(
	"res://scenes/actors/player/player_combat_v2.tscn"
)

var failures: Array[String] = []


func _ready() -> void:
	await _validate_blockout()
	_finish()


func _validate_blockout() -> void:
	_expect(Grace05Scene != null, "Grace 0.5 scene preloads")
	_expect(
		CombatPlayerScene != null,
		"combat player preloads with Grace 0.5 active"
	)
	if Grace05Scene == null:
		return

	var model: Node3D = Grace05Scene.instantiate() as Node3D
	if model == null:
		failures.append("Grace 0.5 scene does not instantiate as Node3D")
		return
	add_child(model)
	await get_tree().process_frame

	var skeleton: Skeleton3D = HumanoidContractScript.find_skeleton(model)
	var validation: Dictionary = (
		ProductionContractScript.validate_production_skeleton(skeleton)
	)
	_expect(
		bool(validation.get("production_ready", false)),
		"Grace 0.5 passes the frozen production skeleton contract"
	)
	_expect(
		int(validation.get("mapped_count", 0)) == 23,
		"Grace 0.5 maps all 23 production semantics"
	)
	_expect(
		model.has_method("get_debug_data"),
		"Grace 0.5 exposes visual audit data"
	)

	var data: Dictionary = (
		model.call("get_debug_data") as Dictionary
		if model.has_method("get_debug_data")
		else {}
	)
	_expect(
		bool(data.get("grace_0_5_blockout", false)),
		"Grace 0.5 identifies itself as the active blockout"
	)
	_expect(
		bool(data.get("direct_bone_follow", false)),
		"Grace 0.5 uses explicit bone-pose following"
	)
	_expect(
		bool(data.get("grace_0_5_silhouette_v4", false)),
		"Grace 0.5 uses the corrected adolescent silhouette"
	)
	_expect(
		bool(data.get("adolescent_head_ratio", false))
		and bool(data.get("visible_leg_contrast", false))
		and bool(data.get("shortened_robe_panels", false)),
		"Grace 0.5 preserves the anti-hamster silhouette contract"
	)
	_expect(
		int(data.get("bone_attachment_count", -1)) == 0,
		"Grace 0.5 no longer depends on BoneAttachment3D"
	)
	_expect(
		(data.get("invalid_follower_bones", []) as Array).is_empty(),
		"every Grace 0.5 part resolves a target bone"
	)
	_expect(
		float(data.get("follower_span", 0.0)) > 1.35,
		"Grace 0.5 direct followers occupy a humanoid vertical span"
	)
	_expect(
		float(data.get("shoulder_span", 0.0)) > 0.35,
		"Grace 0.5 shoulders remain separated"
	)
	_expect(
		int(data.get("follower_count", 0)) >= 45,
		"Grace 0.5 contains a complete modular silhouette"
	)
	_expect(
		int(data.get("visible_meshes", 0)) >= 45,
		"Grace 0.5 retains all visible modeled pieces"
	)
	_expect(
		int(data.get("material_families", 0)) >= 10,
		"Grace 0.5 contains the authored material family"
	)

	var head: MeshInstance3D = model.get_node_or_null(
		"HeadShape"
	) as MeshInstance3D
	var left_foot: MeshInstance3D = model.get_node_or_null(
		"LeftBootFoot"
	) as MeshInstance3D
	var right_foot: MeshInstance3D = model.get_node_or_null(
		"RightBootFoot"
	) as MeshInstance3D
	var left_shoulder: MeshInstance3D = model.get_node_or_null(
		"LeftShoulderSleeve"
	) as MeshInstance3D
	var right_shoulder: MeshInstance3D = model.get_node_or_null(
		"RightShoulderSleeve"
	) as MeshInstance3D
	var left_panel: MeshInstance3D = model.get_node_or_null(
		"FrontPanelLeft"
	) as MeshInstance3D
	for part: MeshInstance3D in [
		head,
		left_foot,
		right_foot,
		left_shoulder,
		right_shoulder,
		left_panel,
	]:
		_expect(part != null, "major Grace 0.5 follower part exists")

	if head != null and left_foot != null and right_foot != null:
		var feet_midpoint: Vector3 = left_foot.position.lerp(
			right_foot.position,
			0.5
		)
		_expect(
			head.position.y - feet_midpoint.y > 1.35,
			"Grace 0.5 head and feet do not collapse around model origin"
		)
		_expect(
			head.scale.x < 0.86 and head.scale.y < 0.94,
			"Grace 0.5 head is reduced from mascot proportions"
		)
	if left_shoulder != null and right_shoulder != null:
		_expect(
			left_shoulder.position.distance_to(right_shoulder.position) > 0.35,
			"Grace 0.5 shoulder geometry does not collapse"
		)
	if left_panel != null:
		_expect(
			left_panel.scale.y < 0.75,
			"Grace 0.5 robe panels stop above the lower-leg silhouette"
		)

	_expect(
		model.get_node_or_null("WaistSash") != null,
		"Grace 0.5 includes the exploration sash silhouette"
	)
	_expect(
		model.get_node_or_null("FrontPanelLeft") != null
		and model.get_node_or_null("FrontPanelRight") != null,
		"Grace 0.5 uses split robe panels"
	)

	# Verify that geometry follows a changed bone pose rather than remaining in a
	# decorative pile at model origin.
	var right_hand: MeshInstance3D = model.get_node_or_null(
		"RightHandShape"
	) as MeshInstance3D
	var upper_arm_index: int = (
		skeleton.find_bone("RightUpperArm")
		if skeleton != null
		else -1
	)
	if right_hand != null and upper_arm_index >= 0:
		var initial_hand_position: Vector3 = right_hand.position
		skeleton.set_bone_pose_rotation(
			upper_arm_index,
			Quaternion(Vector3.FORWARD, deg_to_rad(52.0))
		)
		skeleton.force_update_all_bone_transforms()
		if model.has_method("_refresh_bone_followers"):
			model.call("_refresh_bone_followers")
		_expect(
			right_hand.position.distance_to(initial_hand_position) > 0.08,
			"Grace 0.5 hand follows an articulated upper-arm pose"
		)
	else:
		failures.append("Grace 0.5 articulation probe could not initialize")

	model.queue_free()


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("GRACE_0_5_BLOCKOUT_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("GRACE_0_5_BLOCKOUT_SMOKE_TEST: " + failure)
	get_tree().quit(1)
