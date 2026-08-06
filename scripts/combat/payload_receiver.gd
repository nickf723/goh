extends Node
class_name PayloadReceiver

const ReactionResolverScript = preload("res://scripts/systems/reaction_resolver.gd")
const CombatFeedback = preload("res://scripts/combat/combat_feedback.gd")

var last_payload_summary: String = "none"
var last_reaction_summary: String = "none"
var last_reaction_data: Dictionary = {}
var last_transaction_data: Dictionary = {}


func _ready() -> void:
	add_to_group("debuggable")


func receive_payload(payload: DamagePayload) -> Dictionary:
	if payload == null:
		return {
			"message": get_target_node().name + " receives an empty payload.",
			"objective": ""
		}

	var target: Node = get_target_node()
	remember_payload(payload)

	# Chemistry resolves from a snapshot captured before this payload applies its
	# own direct status or mutates thermal/material components.
	var reaction_batch: Dictionary = resolve_reactions(target, payload)
	if not bool(reaction_batch.get("consume_incoming_status", false)):
		apply_direct_status(target, payload)

	apply_force(target, payload)
	apply_airborne_reaction(target, payload)
	var thermal_result: Dictionary = apply_thermal(target, payload)
	var combustion_result: Dictionary = apply_combustion(target, payload)
	var electrical_result: Dictionary = apply_electrical_material_response(target, payload)
	var structural_result: Dictionary = apply_structural_integrity(target, payload)

	var reaction_messages: Array[String] = []
	var raw_messages: Variant = reaction_batch.get("messages", [])
	if raw_messages is Array:
		for raw_message: Variant in raw_messages as Array:
			reaction_messages.append(str(raw_message))

	var result: Dictionary = apply_hit(target, payload)
	append_component_result(target, result, reaction_messages, thermal_result)
	append_component_result(target, result, reaction_messages, combustion_result)
	append_component_result(target, result, reaction_messages, electrical_result)
	append_component_result(target, result, reaction_messages, structural_result)

	var combined_result: Dictionary = combine_messages(result, reaction_messages)
	combined_result["reaction_transaction"] = last_transaction_data.duplicate(true)
	if str(combined_result.get("message", "")).strip_edges() == "":
		combined_result["message"] = payload.source_name + " affects " + target.name + "."
	return combined_result


func get_target_node() -> Node:
	var parent: Node = get_parent()
	return parent if parent != null else self


func remember_payload(payload: DamagePayload) -> void:
	last_payload_summary = (
		payload.source_name
		+ " | "
		+ payload.element
		+ " | "
		+ str(payload.tags)
	)


func apply_direct_status(target: Node, payload: DamagePayload) -> void:
	if payload.status_effect == "" or payload.status_duration <= 0.0:
		return
	var status_receiver: Node = get_component(target, "StatusReceiver")
	if status_receiver == null or not status_receiver.has_method("apply_status"):
		return
	status_receiver.apply_status(
		payload.status_effect,
		payload.status_duration,
		payload.status_strength,
		payload.source_name
	)


func apply_thermal(target: Node, payload: DamagePayload) -> Dictionary:
	return call_payload_component(target, "ThermalState", payload)


func apply_combustion(target: Node, payload: DamagePayload) -> Dictionary:
	return call_payload_component(target, "CombustionState", payload)


func apply_electrical_material_response(target: Node, payload: DamagePayload) -> Dictionary:
	return call_payload_component(target, "ElectricalMaterialResponse", payload)


func apply_structural_integrity(target: Node, payload: DamagePayload) -> Dictionary:
	return call_payload_component(target, "StructuralIntegrity", payload)


func call_payload_component(
	target: Node,
	component_name: String,
	payload: DamagePayload
) -> Dictionary:
	var component: Node = get_component(target, component_name)
	if component == null or not component.has_method("receive_damage_payload"):
		return {}
	var raw_result: Variant = component.call("receive_damage_payload", payload)
	return raw_result as Dictionary if raw_result is Dictionary else {}


func append_component_result(
	target: Node,
	result: Dictionary,
	reaction_messages: Array[String],
	component_result: Dictionary
) -> void:
	if component_result.is_empty():
		return
	var component_message: String = str(component_result.get("message", ""))
	if component_message == "":
		return
	if get_component(target, "HitReceiver") == null and str(result.get("message", "")) == "":
		result["message"] = component_message
		result["objective"] = str(component_result.get("objective", ""))
		return
	reaction_messages.append(component_message)


func resolve_reactions(target: Node, payload: DamagePayload) -> Dictionary:
	var reaction_messages: Array[String] = []
	var reaction_names: Array[String] = []
	var batch: Dictionary = ReactionResolverScript.resolve_payload_transaction(
		target,
		payload
	)
	var raw_reactions: Variant = batch.get("reactions", [])
	if raw_reactions is Array:
		for reaction_value: Variant in raw_reactions as Array:
			if not reaction_value is Dictionary:
				continue
			var reaction: Dictionary = reaction_value as Dictionary
			if reaction.has("reaction"):
				var reaction_name: String = str(reaction["reaction"])
				reaction_names.append(reaction_name)
				CombatFeedback.show_reaction_feedback(target, reaction_name, reaction)
				last_reaction_data = reaction.duplicate(true)
			if reaction.has("message"):
				reaction_messages.append(str(reaction["message"]))

	if reaction_names.is_empty():
		last_reaction_summary = "none"
		last_reaction_data.clear()
	else:
		last_reaction_summary = ", ".join(reaction_names)

	var transaction_value: Variant = batch.get("transaction", {})
	last_transaction_data = (
		(transaction_value as Dictionary).duplicate(true)
		if transaction_value is Dictionary
		else {}
	)
	batch["messages"] = reaction_messages
	batch["reaction_names"] = reaction_names
	return batch


func apply_hit(target: Node, payload: DamagePayload) -> Dictionary:
	var hit_receiver: Node = get_component(target, "HitReceiver")
	if hit_receiver != null:
		if hit_receiver.has_method("receive_payload"):
			var payload_result: Dictionary = hit_receiver.receive_payload(payload)
			play_hit_feedback(payload, payload_result)
			return payload_result
		if hit_receiver.has_method("receive_hit"):
			var hit_result: Dictionary = hit_receiver.receive_hit(payload.amount)
			play_hit_feedback(payload, hit_result)
			return hit_result
	return {"message": "", "objective": ""}


func play_hit_feedback(payload: DamagePayload, _result: Dictionary) -> void:
	if payload == null:
		return
	if should_play_heavy_impact(payload):
		GameFeedback.play("heavy_impact", {"source": payload.source_name})
		return
	GameFeedback.play("hit_collision", {"source": payload.source_name})


func should_play_heavy_impact(payload: DamagePayload) -> bool:
	if payload.source_name.to_lower().contains("charged"):
		return true
	for tag: String in payload.tags:
		if tag in ["charged", "heavy_impact"]:
			return true
	return false


func combine_messages(result: Dictionary, reaction_messages: Array[String]) -> Dictionary:
	if reaction_messages.is_empty():
		return result
	var combined_message: String = "\n".join(reaction_messages)
	if result.has("message") and result["message"] != "":
		combined_message += "\n" + str(result["message"])
	result["message"] = combined_message
	return result


func get_component(target: Node, component_name: String) -> Node:
	return target.get_node_or_null(component_name) if target != null else null


func get_debug_data() -> Dictionary:
	return {
		"last": last_payload_summary,
		"rx": last_reaction_summary,
		"rx_visual": str(last_reaction_data.get("visual_style", "none")),
		"rx_transaction": str(last_transaction_data.get("transaction_id", "none")),
		"rx_depth": int(last_transaction_data.get("depth", 0)),
		"rx_suppressed": (
			(last_transaction_data.get("suppressed", []) as Array).size()
			if last_transaction_data.get("suppressed", null) is Array
			else 0
		),
	}


func apply_force(target: Node, payload: DamagePayload) -> void:
	if payload.knockback_strength <= 0.0 and payload.knockback_up_strength <= 0.0:
		return
	var force_receiver: Node = get_component(target, "ForceReceiver")
	if force_receiver == null or not force_receiver.has_method("apply_impulse"):
		return

	# Directional projectiles and physical techniques can author the exact force
	# vector they carry. Older payloads leave it at zero and retain the previous
	# away-from-player fallback, so this enriches the contract without changing
	# legacy spell or weapon behavior.
	var impulse_direction: Vector3 = payload.knockback_direction
	if impulse_direction.length_squared() <= 0.0001:
		var source_position: Vector3 = get_payload_source_position(payload)
		var target_position: Vector3 = get_target_position(target)
		impulse_direction = target_position - source_position

	force_receiver.apply_impulse(
		impulse_direction,
		payload.knockback_strength,
		payload.knockback_up_strength,
		payload.source_name
	)


func apply_airborne_reaction(target: Node, payload: DamagePayload) -> void:
	var airborne_controller: Node = get_component(target, "AirborneReactionController")
	if airborne_controller != null and airborne_controller.has_method("register_payload"):
		airborne_controller.call("register_payload", payload)


func get_payload_source_position(_payload: DamagePayload) -> Vector3:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	return player.global_position if player != null else Vector3.ZERO


func get_target_position(target: Node) -> Vector3:
	if target is Node3D:
		return (target as Node3D).global_position
	var parent: Node = target.get_parent() if target != null else null
	return (parent as Node3D).global_position if parent is Node3D else Vector3.ZERO
