extends Resource
class_name DamagePayload

@export var amount: int = 1
@export var stance_damage: int = 1
@export var element: String = "neutral"
@export var source_name: String = "Unknown"
@export var hit_type: String = "magic"

@export var status_effect: String = ""
@export var status_duration: float = 0.0
@export var status_strength: float = 1.0

@export var tags: Array[String] = []

@export var knockback_strength: float = 0.0
@export var knockback_up_strength: float = 0.0
@export var knockback_direction: Vector3 = Vector3.ZERO

# Weapon attacks copy their equipped weapon's critical identity into the payload.
# Receivers decide whether a valid stance-break window may consume it.
@export_range(1.0, 6.0, 0.05) var critical_multiplier: float = 2.0

# Runtime-only reaction lineage. These fields are intentionally not exported,
# because authored payload resources should begin as root impacts.
var reaction_chain_id: String = ""
var reaction_depth: int = 0
var reaction_history: Array[String] = []
var reaction_source_rule: String = ""
var suppress_reactions: bool = false


func is_reaction_payload() -> bool:
	return (
		reaction_depth > 0
		or reaction_source_rule != ""
		or hit_type in ["reaction", "reaction_burst"]
		or tags.has("reaction")
	)


func inherit_reaction_lineage(
	parent_payload: DamagePayload,
	rule_id: String,
	chain_id: String = ""
) -> void:
	if parent_payload != null:
		reaction_chain_id = parent_payload.reaction_chain_id
		reaction_depth = parent_payload.reaction_depth + 1
		reaction_history = parent_payload.reaction_history.duplicate()
	else:
		reaction_depth = 1
	if reaction_chain_id == "":
		reaction_chain_id = chain_id
	reaction_source_rule = rule_id
	if rule_id != "":
		reaction_history.append(rule_id)
	if not tags.has("reaction"):
		tags.append("reaction")


func get_reaction_debug_data() -> Dictionary:
	return {
		"chain_id": reaction_chain_id,
		"depth": reaction_depth,
		"history": reaction_history.duplicate(),
		"source_rule": reaction_source_rule,
		"suppressed": suppress_reactions,
	}
