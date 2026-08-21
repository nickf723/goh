extends "res://scripts/combat/authority_status_receiver_base.gd"
class_name PlayerStatusReceiver

const TRANSFERABLE_DEBUFFS: Array[String] = [
	"burning",
	"scorched",
	"poisoned",
	"toxic",
	"wet",
	"steamed",
	"frozen",
	"chill",
	"brittle",
	"stunned",
	"electrified",
	"conductive",
	"leaf_pelted",
	"rooted",
	"hexed",
	"oily",
	"obscured",
	"revealed",
]


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
				and defense_controller.has_method("resolve_bubble_absorb")
			):
				var result_value: Variant = defense_controller.call(
					"resolve_bubble_absorb",
					payload,
					null
				)
				if (
					result_value is Dictionary
					and not (result_value as Dictionary).is_empty()
				):
					return
	GameState.take_damage(payload.amount)


# Infection consumes a presentation-safe snapshot rather than reaching into the
# receiver's internal dictionary. Durations and strengths remain authoritative on
# this receiver; the projectile may scale them before applying them elsewhere.
func get_transferable_debuffs() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for raw_name: Variant in active_statuses.keys():
		var status_name: String = StatePolicy.normalize_state(str(raw_name))
		if not TRANSFERABLE_DEBUFFS.has(status_name):
			continue
		if not active_statuses.has(status_name):
			continue
		var status: Dictionary = active_statuses[status_name] as Dictionary
		var remaining: float = maxf(float(status.get("duration", 0.0)), 0.0)
		if remaining <= 0.0:
			continue
		rows.append({
			"status": status_name,
			"duration": remaining,
			"strength": maxf(float(status.get("strength", 1.0)), 0.0),
			"source": str(status.get("source", "player_status")),
			"element": str(
				status.get("element", StatePolicy.get_state_element(status_name))
			),
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("status", "")) < str(b.get("status", ""))
	)
	return rows


func get_receiver_group() -> String:
	return "player_status_receiver"


func get_tick_tag() -> String:
	return "player_status"
