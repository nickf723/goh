extends "res://scripts/combat/authority_status_receiver_base.gd"
class_name PlayerStatusReceiver


func deliver_status_tick(payload: DamagePayload) -> void:
	var actor: Node = get_parent()
	if actor != null:
		var bubble_controller: Node = actor.get_node_or_null(
			"BubbleShieldController"
		)
		if (
			bubble_controller != null
			and bubble_controller.has_method("is_bubble_active")
			and bool(bubble_controller.call("is_bubble_active"))
		):
			var defense_controller: Node = actor.get_node_or_null(
				"PlayerDefenseController"
			)
			if (
				defense_controller != null
				and defense_controller.has_method("resolve_incoming_attack")
			):
				defense_controller.call(
					"resolve_incoming_attack",
					payload,
					null
				)
				return
	GameState.take_damage(payload.amount)


func get_receiver_group() -> String:
	return "player_status_receiver"


func get_tick_tag() -> String:
	return "player_status"
