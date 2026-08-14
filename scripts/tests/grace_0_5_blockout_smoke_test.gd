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
	_validate_blockout()
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
			int(data.get("visible_meshes", 0)) >= 45,
			"Grace 0.5 contains a complete modular silhouette"
		)
		_expect(
			int(data.get("material_families", 0)) >= 10,
			"Grace 0.5 contains the authored material family"
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
