extends Node
class_name ReactionResolver


const ReactionEngine = preload(
	"res://scripts/systems/elemental_reaction_engine.gd"
)
const RuleCatalog = preload(
	"res://scripts/systems/reaction_rule_catalog.gd"
)
const StatePolicy = preload(
	"res://scripts/systems/reaction_state_policy.gd"
)


static func resolve_payload_transaction(
	target: Node,
	payload: DamagePayload
) -> Dictionary:
	var batch: Dictionary = ReactionEngine.resolve_payload_transaction(target, payload)
	_record_progression(batch)
	return batch


static func resolve_payload_reactions(
	target: Node,
	payload: DamagePayload
) -> Array[Dictionary]:
	var batch: Dictionary = resolve_payload_transaction(target, payload)
	var reactions: Array[Dictionary] = []
	var raw: Variant = batch.get("reactions", [])
	if raw is Array:
		for reaction_value: Variant in raw as Array:
			if reaction_value is Dictionary:
				reactions.append(reaction_value as Dictionary)
	return reactions


static func resolve_hazard_transaction(
	hazard: Node,
	payload: DamagePayload,
	source_position: Vector3 = Vector3.ZERO
) -> Dictionary:
	var batch: Dictionary = ReactionEngine.resolve_hazard_transaction(
		hazard,
		payload,
		source_position
	)
	_record_progression(batch)
	return batch


static func resolve_hazard_reactions(
	hazard: Node,
	payload: DamagePayload,
	source_position: Vector3 = Vector3.ZERO
) -> Array[Dictionary]:
	var batch: Dictionary = resolve_hazard_transaction(
		hazard,
		payload,
		source_position
	)
	var reactions: Array[Dictionary] = []
	var raw: Variant = batch.get("reactions", [])
	if raw is Array:
		for reaction_value: Variant in raw as Array:
			if reaction_value is Dictionary:
				reactions.append(reaction_value as Dictionary)
	return reactions


static func target_has_status_or_tag(target: Node, name: String) -> bool:
	return StatePolicy.snapshot_has_tag_or_status(
		StatePolicy.capture_target_state(target),
		name
	)


static func get_debug_matrix_rows() -> Array[Dictionary]:
	return RuleCatalog.get_debug_rows()


static func validate_rules() -> Array[String]:
	return RuleCatalog.validate_catalog()


static func _record_progression(batch: Dictionary) -> void:
	var main_loop: MainLoop = Engine.get_main_loop()
	if not main_loop is SceneTree:
		return
	var tree: SceneTree = main_loop as SceneTree
	var tracker: Node = tree.root.get_node_or_null(
		"FullMenuDirector/ProgressionTracker"
	)
	if tracker == null or not tracker.has_method("record_reaction_result"):
		return
	var raw: Variant = batch.get("reactions", [])
	if not raw is Array:
		return
	for reaction_value: Variant in raw as Array:
		if reaction_value is Dictionary:
			tracker.call("record_reaction_result", reaction_value)
