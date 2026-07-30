extends "res://scripts/combat/authority_status_receiver_base.gd"
class_name ManifestedAvatarStatusReceiver


func deliver_status_tick(payload: DamagePayload) -> void:
	if actor != null and actor.has_method("receive_damage_payload"):
		actor.call("receive_damage_payload", payload)


func get_receiver_group() -> String:
	return "manifested_avatar_status_receiver"


func get_tick_tag() -> String:
	return "manifestation_status"
