extends "res://scripts/combat/authority_status_receiver_base.gd"
class_name PlayerStatusReceiver


func deliver_status_tick(payload: DamagePayload) -> void:
	GameState.take_damage(payload.amount)


func get_receiver_group() -> String:
	return "player_status_receiver"


func get_tick_tag() -> String:
	return "player_status"
