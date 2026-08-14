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
	_expect(CombatPlayerScene != null, "combat player preloads with Grace 0.5 active")
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
		"Grace 0.5 blockout passes the frozen production skeleton contract"
	)
	_expect(
		int(validation.get("mapped_count", 0)) == 23,
		"Grace 0.5 blockout maps all 23 production semantics"
	)
	_expect(
		model.has_method("get_debug_data"),
		"Grace 0.5 blockout exposes visual audit data"
	)
	if model.has_method("get_debug_data"):
		var data: Dictionary = model.call("get_debug_data") as Dictionary
		_expect(
			bool(data.get("grace_0_5_blockout", false)),
			"Grace 0.5 identifies itself as the active blockout"
		)
		_expect(
			bool(data.get("attachments_bound_after_parenting", false)),
			"Grace 0.5 binds BoneAttachment3D nodes after they enter the skeleton"
		)
		_expect(
			(data.get("invalid_attachment_bindings", []) as Array).is_empty(),
			"every Grace 0.5 modular part resolves a valid target bone"
		)
		_expect(
			float(data.get("attachment_span", 0.0)) > 1.35,
			"Grace 0.5 attachments occupy a humanoid head-to-foot span"
		)
		_expect(
			int(data.get("visible_meshes", 0)) >= 45,
			"Grace 0.5 contains a complete modular silhouette"
		)
		_expect(
			int(data.get("material_families", 0)) >= 10,
			"Grace 0.5 contains the authored material family"
		)

	var head_attachment: BoneAttachment3D = model.get_node_or_null(
		"Skeleton3D/HeadAttachment"
	) as BoneAttachment3D
	var left_foot_attachment: BoneAttachment3D = model.get_node_or_null(
		"Skeleton3D/LeftFootAttachment"
	) as BoneAttachment3D
	var right_foot_attachment: BoneAttachment3D = model.get_node_or_null(
		"Skeleton3D/RightFootAttachment"
	) as BoneAttachment3D
	var left_arm_attachment: BoneAttachment3D = model.get_node_or_null(
		"Skeleton3D/LeftUpperArmAttachment"
	) as BoneAttachment3D
	var right_arm_attachment: BoneAttachment3D = model.get_node_or_null(
		"Skeleton3D/RightUpperArmAttachment"
	) as BoneAttachment3D
	for attachment: BoneAttachment3D in [
		head_attachment,
		left_foot_attachment,
		right_foot_attachment,
		left_arm_attachment,
		right_arm_attachment,
	]:
		_expect(
			attachment != null and attachment.bone_idx >= 0,
			"major Grace 0.5 attachment resolves a valid bone index"
		)
	if (
		head_attachment != null
		and left_foot_attachment != null
		and right_foot_attachment != null
	):
		var feet_midpoint: Vector3 = left_foot_attachment.global_position.lerp(
			right_foot_attachment.global_position,
			0.5
		)
		_expect(
			head_attachment.global_position.y - feet_midpoint.y > 1.35,
			"Grace 0.5 head and feet do not collapse around the skeleton origin"
		)
	if left_arm_attachment != null and right_arm_attachment != null:
		_expect(
			left_arm_attachment.global_position.distance_to(
				right_arm_attachment.global_position
			) > 0.35,
			"Grace 0.5 shoulders remain separated"
		)

	_expect(
		model.get_node_or_null("Skeleton3D/HeadAttachment/HeadShape") != null,
		"Grace 0.5 includes a modeled head"
	)
	_expect(
		model.get_node_or_null("Skeleton3D/HipsAttachment/WaistSash") != null,
		"Grace 0.5 includes the exploration sash silhouette"
	)
	_expect(
		model.get_node_or_null("Skeleton3D/LeftUpperLegAttachment/FrontPanelLeft") != null
		and model.get_node_or_null("Skeleton3D/RightUpperLegAttachment/FrontPanelRight") != null,
		"Grace 0.5 uses split robe panels for combat deformation"
	)
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
