extends RefCounted
class_name ReactionClaimRegistry


const Blackboard = preload(
	"res://scripts/ai/tactical_blackboard.gd"
)


static func reserve_setup(
	squad_id: String,
	owner_id: int,
	owner_name: String,
	reaction_id: String,
	target_id: int = 0,
	duration: float = 0.9,
	priority: float = 0.0,
	metadata: Dictionary = {}
) -> Dictionary:
	return Blackboard.reserve_reaction_phase(
		squad_id,
		owner_id,
		owner_name,
		"setup",
		reaction_id,
		target_id,
		duration,
		priority,
		metadata
	)


static func reserve_payoff(
	squad_id: String,
	owner_id: int,
	owner_name: String,
	reaction_id: String,
	target_id: int = 0,
	duration: float = 0.9,
	priority: float = 0.0,
	metadata: Dictionary = {}
) -> Dictionary:
	return Blackboard.reserve_reaction_phase(
		squad_id,
		owner_id,
		owner_name,
		"payoff",
		reaction_id,
		target_id,
		duration,
		priority,
		metadata
	)


static func get_claims(
	squad_id: String,
	exclude_owner_id: int = 0,
	target_id: int = 0
) -> Dictionary:
	return Blackboard.get_coordination_context(
		squad_id,
		exclude_owner_id,
		target_id
	)
