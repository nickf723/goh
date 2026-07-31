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
		if not reaction_value is Dictionary:
			continue
		var reaction: Dictionary = (reaction_value as Dictionary).duplicate(false)
		if str(reaction.get("reaction_id", "")) == "":
			reaction["reaction_id"] = str(reaction.get("reaction", ""))
		if str(reaction.get("reaction_name", "")) == "":
			reaction["reaction_name"] = str(reaction.get("reaction", ""))
		CreatureObservationAccess.call_service(
			get_tree(),
			"report_reaction",
			[target, reaction, payload]
		)
	return batch
