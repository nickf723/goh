extends Area3D

@export var prompt_text: String = "Inspect"
@export_multiline var inspect_text: String = "There is something strange here."
@export var objective_after: String = ""
@export var damage_payload: DamagePayload

var has_been_inspected: bool = false

func interact() -> Dictionary:
	has_been_inspected = true

	return {
		"message": inspect_text,
		"objective": objective_after,
	}

func receive_magic_hit(power: int = 1) -> Dictionary:
	var hit_receiver: Node = get_node_or_null("HitReceiver")

	if hit_receiver == null:
		return {
			"message": "Arcane Spark hits " + name + ", but nothing happens.",
			"objective": ""
		}

	return hit_receiver.receive_hit(power)

func receive_damage_payload(payload: DamagePayload) -> Dictionary:
	var hit_receiver: Node = get_node_or_null("HitReceiver")

	if hit_receiver == null:
		return {
			"message": payload.source_name + " hits " + name + ", but nothing happens.",
			"objective": ""
		}

	if hit_receiver.has_method("receive_payload"):
		return hit_receiver.receive_payload(payload)

	return hit_receiver.receive_hit(payload.amount)
