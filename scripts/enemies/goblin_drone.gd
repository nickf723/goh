extends CharacterBody3D

@onready var payload_receiver: Node = get_node_or_null("PayloadReceiver")


func _ready() -> void:
	add_to_group("enemy")


func receive_damage_payload(payload: DamagePayload) -> Dictionary:
	if payload_receiver != null and payload_receiver.has_method("receive_payload"):
		return payload_receiver.receive_payload(payload)

	return {
		"message": payload.source_name + " hits " + name + ", but PayloadReceiver is missing.",
		"objective": ""
	}

func receive_magic_hit(power: int = 1) -> Dictionary:
	var payload: DamagePayload = DamagePayload.new()
	payload.amount = power
	payload.stance_damage = power
	payload.element = "neutral"
	payload.source_name = "Legacy Magic Hit"
	payload.hit_type = "magic"
	payload.tags = ["magic", "legacy"]

	return receive_damage_payload(payload)
