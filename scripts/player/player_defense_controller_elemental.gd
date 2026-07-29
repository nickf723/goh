extends "res://scripts/player/player_defense_controller.gd"
class_name PlayerDefenseControllerElemental

var elemental_authority_controller: PlayerElementalAuthorityController
var last_authority_result: Dictionary = {}


func _ready() -> void:
	super._ready()
	if actor != null:
		elemental_authority_controller = actor.get_node_or_null(
			"ElementalAuthorityController"
		) as PlayerElementalAuthorityController


func resolve_incoming_attack(
	payload: DamagePayload,
	attacker: Node3D = null
) -> Dictionary:
	last_authority_result.clear()
	if payload == null or elemental_authority_controller == null:
		return super.resolve_incoming_attack(payload, attacker)

	last_authority_result = elemental_authority_controller.resolve_incoming_payload(
		payload
	)
	if bool(last_authority_result.get("immune", false)):
		last_outcome = "elemental_authority"
		var avatar_name: String = "Grace"
		if actor != null:
			avatar_name = str(
				actor.get_meta("active_avatar_display_name", avatar_name)
			)
		var result: Dictionary = make_result(
			"elemental_authority",
			payload,
			avatar_name
			+ " walks through "
			+ payload.source_name
			+ " without harm."
		)
		result["authority_id"] = str(
			last_authority_result.get("authority_id", "none")
		)
		result["negated_element"] = payload.element
		result["damage"] = 0
		result["stance_damage"] = 0
		result["health_damage"] = 0
		result["stance_cost"] = 0
		show_message(str(result.get("message", "")))
		player_hit.emit(result)
		emit_defense_state()
		return result

	var resolved_value: Variant = last_authority_result.get("payload", payload)
	if resolved_value is DamagePayload:
		return super.resolve_incoming_attack(
			resolved_value as DamagePayload,
			attacker
		)
	return super.resolve_incoming_attack(payload, attacker)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["authority_ready"] = elemental_authority_controller != null
	data["authority_result"] = last_authority_result.duplicate(true)
	data["authority_id"] = (
		elemental_authority_controller.get_debug_data().get(
			"authority_id",
			"none"
		)
		if elemental_authority_controller != null
		else "none"
	)
	return data
