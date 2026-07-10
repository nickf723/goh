extends Node
class_name ReactionResolver

const ComboRuleRegistryScript = preload("res://scripts/systems/combo_rule_registry.gd")


static func resolve_payload_reactions(target: Node, payload: DamagePayload) -> Array[Dictionary]:
	return ComboRuleRegistryScript.resolve_payload_reactions(target, payload)


static func target_has_status_or_tag(target: Node, name: String) -> bool:
	return ComboRuleRegistryScript.target_has_status_or_tag(target, name)


static func get_debug_matrix_rows() -> Array[Dictionary]:
	return ComboRuleRegistryScript.get_debug_matrix_rows()
