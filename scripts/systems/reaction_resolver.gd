extends Node
class_name ReactionResolver


static func resolve_payload_reactions(target: Node, payload: DamagePayload) -> Array[Dictionary]:
	var reactions: Array[Dictionary] = []

	if payload.tags.has("fire") and target_has_status_or_tag(target, "oily"):
		reactions.append(_ignite_oily_target(target))

	if payload.tags.has("lightning") and target_has_status_or_tag(target, "wet"):
		reactions.append(_shock_wet_target(target))
	
	if payload.tags.has("ice") and target_has_status_or_tag(target, "wet"):
		reactions.append(_freeze_wet_target(target))
		
	if payload.tags.has("force") and target_has_status_or_tag(target, "frozen"):
		reactions.append(_shatter_frozen_target(target))
		
	return reactions

static func target_has_status_or_tag(target: Node, name: String) -> bool:
	var tag_component: Node = target.get_node_or_null("TagComponent")

	if tag_component != null and tag_component.has_method("has_tag"):
		if tag_component.has_tag(name):
			return true

	var status_receiver: Node = target.get_node_or_null("StatusReceiver")

	if status_receiver != null and status_receiver.has_method("has_status"):
		if status_receiver.has_status(name):
			return true

	return false

static func _ignite_oily_target(target: Node) -> Dictionary:
	var status_receiver: Node = target.get_node_or_null("StatusReceiver")

	if status_receiver != null and status_receiver.has_method("apply_status"):
		status_receiver.apply_status("burning", 4.0, 1.0, "oil_ignition")

	return {
		"reaction": "ignite_oil",
		"message": target.name + " ignites from the oil.",
	}

static func _shock_wet_target(target: Node) -> Dictionary:
	var status_receiver: Node = target.get_node_or_null("StatusReceiver")

	if status_receiver != null and status_receiver.has_method("apply_status"):
		status_receiver.apply_status("stunned", 2.0, 1.0, "wet_conduction")

	return {
		"reaction": "wet_conduction",
		"message": target.name + " conducts the lightning and is stunned.",
	}

static func _freeze_wet_target(target: Node) -> Dictionary:
	var status_receiver: Node = target.get_node_or_null("StatusReceiver")

	if status_receiver != null and status_receiver.has_method("apply_status"):
		status_receiver.apply_status("frozen", 10.0, 1.0, "wet_freeze")

	return {
		"reaction": "wet_freeze",
		"message": target.name + " freezes solid.",
	}

static func _shatter_frozen_target(target: Node) -> Dictionary:
	var status_receiver: Node = target.get_node_or_null("StatusReceiver")

	if status_receiver != null:
		if status_receiver.has_method("remove_status"):
			status_receiver.remove_status("frozen")

	var hit_receiver: Node = target.get_node_or_null("HitReceiver")

	if hit_receiver != null and hit_receiver.has_method("receive_payload"):
		var shatter_payload: DamagePayload = DamagePayload.new()
		shatter_payload.amount = 3
		shatter_payload.stance_damage = 2
		shatter_payload.element = "ice"
		shatter_payload.source_name = "Shatter"
		shatter_payload.hit_type = "reaction"
		shatter_payload.tags = ["ice", "force", "reaction", "shatter"]

		hit_receiver.receive_payload(shatter_payload)

	return {
		"reaction": "shatter",
		"message": target.name + " shatters from the impact.",
	}
