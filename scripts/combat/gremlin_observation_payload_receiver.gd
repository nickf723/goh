extends "res://scripts/combat/payload_receiver.gd"

const CreatureObservationAccess = preload(
	"res://scripts/animals/creature_observation_access.gd"
)


func resolve_reactions(target: Node, payload: DamagePayload) -> Dictionary:
	var batch: Dictionary = super.resolve_reactions(target, payload)
	var reactions_value: Variant = batch.get("reactions", [])
	if not reactions_value is Array:
		return batch
	for reaction_value: Variant in reactions_value as Array:
		if reaction_value is Dictionary:
			CreatureObservationAccess.call_service(
				get_tree(),
				"report_reaction",
				[target, reaction_value as Dictionary, payload]
			)
	return batch
