extends "res://scripts/combat/payload_receiver.gd"
class_name EchoListenerPayloadReceiver


func receive_payload(payload: DamagePayload) -> Dictionary:
	var target: Node = get_target_node()
	if target != null and target.has_method("notify_attacked"):
		target.call("notify_attacked", payload)
	return super.receive_payload(payload)
