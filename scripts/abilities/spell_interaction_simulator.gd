extends RefCounted
class_name SpellInteractionSimulator


const ReactionTargetScene: PackedScene = preload(
	"res://scenes/actors/testing/goblin_reaction_target.tscn"
)


static func get_default_recipes() -> Array[Dictionary]:
	return [
		{
			"recipe_id": "wet_conduction_chain",
			"display_name": "Water into Conduct",
			"expected_reactions": ["wet_conduction"],
			"steps": [
				_payload_step(
					"Water Jet",
					"water",
					["water", "wet", "setup"],
					"wet",
					5.0
				),
				_payload_step(
					"Lightning Spark",
					"lightning",
					["lightning", "projectile"]
				),
			],
		},
		{
			"recipe_id": "freeze_steam_chain",
			"display_name": "Water into Freeze into Steam",
			"expected_reactions": ["wet_freeze", "steam_burst"],
			"steps": [
				_payload_step(
					"Water Jet",
					"water",
					["water", "wet", "setup"],
					"wet",
					5.0
				),
				_payload_step(
					"Ice Lance",
					"ice",
					["ice", "control"],
					"chill",
					4.0
				),
				_payload_step(
					"Firebolt",
					"fire",
					["fire", "burn", "projectile"]
				),
			],
		},
		{
			"recipe_id": "frozen_shatter_chain",
			"display_name": "Frozen into Shatter",
			"expected_reactions": ["shatter"],
			"steps": [
				_status_step("frozen", 6.0, 1.0, "recipe_setup"),
				_payload_step(
					"Heavy Impact",
					"neutral",
					["force", "heavy_impact", "weapon"]
				),
			],
		},
		{
			"recipe_id": "resonant_reveal_chain",
			"display_name": "Obscured into Resonant Reveal",
			"expected_reactions": ["resonant_reveal"],
			"steps": [
				_status_step("obscured", 6.0, 1.0, "recipe_setup"),
				_payload_step(
					"Echolocation",
					"sound",
					["sound", "detection", "reveal", "pulse"]
				),
			],
		},
	]


static func simulate_default_recipes(host: Node) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for recipe: Dictionary in get_default_recipes():
		results.append(simulate_recipe(host, recipe))
	return results


static func simulate_recipe(host: Node, recipe: Dictionary) -> Dictionary:
	var trace: Array[Dictionary] = []
	var observed_reactions: Array[String] = []
	var target: Node = ReactionTargetScene.instantiate()
	target.name = "Simulation_" + str(recipe.get("recipe_id", "recipe"))
	host.add_child(target)

	var status_receiver: Node = target.get_node_or_null("StatusReceiver")
	var payload_receiver: Node = target.get_node_or_null("PayloadReceiver")
	var step_index: int = 0
	for raw_step: Variant in recipe.get("steps", []) as Array:
		if not raw_step is Dictionary:
			continue
		var step: Dictionary = raw_step as Dictionary
		var kind: String = str(step.get("kind", "payload"))
		var result: Dictionary = {}
		if kind == "status":
			if status_receiver != null and status_receiver.has_method("apply_status"):
				status_receiver.call(
					"apply_status",
					str(step.get("status", "")),
					float(step.get("duration", 1.0)),
					float(step.get("strength", 1.0)),
					str(step.get("source", "simulation"))
				)
		else:
			var payload: DamagePayload = _make_payload(step)
			if target.has_method("receive_damage_payload"):
				var raw_result: Variant = target.call(
					"receive_damage_payload",
					payload
				)
				if raw_result is Dictionary:
					result = raw_result as Dictionary

		var reaction_summary: String = "none"
		var transaction: Dictionary = {}
		if payload_receiver != null:
			reaction_summary = str(
				payload_receiver.get("last_reaction_summary")
			)
			var transaction_value: Variant = payload_receiver.get(
				"last_transaction_data"
			)
			if transaction_value is Dictionary:
				transaction = (
					transaction_value as Dictionary
				).duplicate(true)
		_append_reaction_summary(observed_reactions, reaction_summary)
		trace.append({
			"step": step_index,
			"kind": kind,
			"source": str(step.get("source", step.get("status", "status"))),
			"reaction_summary": reaction_summary,
			"statuses": _get_status_names(status_receiver),
			"transaction": transaction,
			"message": str(result.get("message", "")),
		})
		step_index += 1

	var expected_reactions: Array[String] = _string_array(
		recipe.get("expected_reactions", [])
	)
	var missing_reactions: Array[String] = []
	for reaction_id: String in expected_reactions:
		if not observed_reactions.has(reaction_id):
			missing_reactions.append(reaction_id)

	if target.get_parent() != null:
		target.get_parent().remove_child(target)
	target.free()
	return {
		"recipe_id": str(recipe.get("recipe_id", "recipe")),
		"display_name": str(recipe.get("display_name", "Recipe")),
		"passed": missing_reactions.is_empty(),
		"expected_reactions": expected_reactions,
		"observed_reactions": observed_reactions,
		"missing_reactions": missing_reactions,
		"trace": trace,
	}


static func _payload_step(
	source: String,
	element: String,
	tags: Array[String],
	status: String = "",
	duration: float = 0.0,
	strength: float = 1.0
) -> Dictionary:
	return {
		"kind": "payload",
		"source": source,
		"element": element,
		"tags": tags,
		"status": status,
		"duration": duration,
		"strength": strength,
	}


static func _status_step(
	status: String,
	duration: float,
	strength: float,
	source: String
) -> Dictionary:
	return {
		"kind": "status",
		"status": status,
		"duration": duration,
		"strength": strength,
		"source": source,
	}


static func _make_payload(step: Dictionary) -> DamagePayload:
	var payload := DamagePayload.new()
	payload.amount = int(step.get("damage", 0))
	payload.stance_damage = int(step.get("stance_damage", 0))
	payload.element = str(step.get("element", "neutral"))
	payload.source_name = str(step.get("source", "Simulation Payload"))
	payload.hit_type = str(step.get("hit_type", "magic"))
	payload.tags = _string_array(step.get("tags", []))
	payload.status_effect = str(step.get("status", ""))
	payload.status_duration = float(step.get("duration", 0.0))
	payload.status_strength = float(step.get("strength", 1.0))
	payload.knockback_strength = float(step.get("force", 0.0))
	payload.knockback_up_strength = float(step.get("force_up", 0.0))
	return payload


static func _append_reaction_summary(
	observed: Array[String],
	summary: String
) -> void:
	if summary == "" or summary == "none":
		return
	for raw_reaction: String in summary.split(","):
		var reaction: String = raw_reaction.strip_edges()
		if reaction != "" and not observed.has(reaction):
			observed.append(reaction)


static func _get_status_names(status_receiver: Node) -> Array[String]:
	if status_receiver == null:
		return []
	if status_receiver.has_method("get_active_status_names"):
		var result: Variant = status_receiver.call("get_active_status_names")
		return _string_array(result)
	var active_value: Variant = status_receiver.get("active_statuses")
	var names: Array[String] = []
	if active_value is Dictionary:
		for key: Variant in (active_value as Dictionary).keys():
			names.append(str(key))
	return names


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value as Array:
			var text: String = str(raw).strip_edges().to_lower()
			if text != "" and not result.has(text):
				result.append(text)
	return result
