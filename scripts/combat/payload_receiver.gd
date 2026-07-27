extends Node
class_name PayloadReceiver

const ReactionResolverScript = preload("res://scripts/systems/reaction_resolver.gd")
const CombatFeedback = preload("res://scripts/combat/combat_feedback.gd")

var last_payload_summary: String = "none"
var last_reaction_summary: String = "none"
var last_reaction_data: Dictionary = {}


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
	apply_direct_status(target, payload)
	apply_force(target, payload)
	apply_airborne_reaction(target, payload)
	var thermal_result: Dictionary = apply_thermal(target, payload)
	var combustion_result: Dictionary = apply_combustion(target, payload)
	var electrical_result: Dictionary = apply_electrical_material_response(target, payload)
	var structural_result: Dictionary = apply_structural_integrity(target, payload)

	var reaction_messages: Array[String] = resolve_reactions(target, payload)
	var result: Dictionary = apply_hit(target, payload)
	append_component_result(target, result, reaction_messages, thermal_result)
	append_component_result(target, result, reaction_messages, combustion_result)
	append_component_result(target, result, reaction_messages, electrical_result)
	append_component_result(target, result, reaction_messages, structural_result)

	var combined_result: Dictionary = combine_messages(result, reaction_messages)
	if str(combined_result.get("message", "")).strip_edges() == "":
		combined_result["message"] = payload.source_name + " affects " + target.name + "."
	return combined_result


func get_target_node() -> Node:
	var parent: Node = get_parent()

	if parent != null:
		return parent

	return self


func remember_payload(payload: DamagePayload) -> void:
	last_payload_summary = (
		payload.source_name
		+ " | "
		+ payload.element
		+ " | "
		+ str(payload.tags)
	)


func apply_direct_status(target: Node, payload: DamagePayload) -> void:
	if payload.status_effect == "":
		return
	if payload.status_duration <= 0.0:
		return

	var status_receiver: Node = get_component(target, "StatusReceiver")

	if status_receiver == null:
		return

	if not status_receiver.has_method("apply_status"):
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
	if raw_result is Dictionary:
		return raw_result as Dictionary
	return {}


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


func resolve_reactions(target: Node, payload: DamagePayload) -> Array[String]:
	var reaction_messages: Array[String] = []
	var reaction_names: Array[String] = []

	var reactions: Array[Dictionary] = ReactionResolverScript.resolve_payload_reactions(target, payload)

	for reaction: Dictionary in reactions:
		if reaction.has("reaction"):
			var reaction_name: String = str(reaction["reaction"])
			reaction_names.append(reaction_name)
			CombatFeedback.show_reaction_feedback(target, reaction_name, reaction)
			last_reaction_data = reaction.duplicate(true)

		if reaction.has("message"):
			reaction_messages.append(str(reaction["message"]))

	if reaction_names.size() > 0:
		last_reaction_summary = ", ".join(reaction_names)
	else:
		last_reaction_summary = "none"
		last_reaction_data.clear()

	return reaction_messages


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

	return {
		"message": "",
		"objective": ""
	}


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
		if tag == "charged" or tag == "heavy_impact":
			return true

	return false


func combine_messages(result: Dictionary, reaction_messages: Array[String]) -> Dictionary:
	if reaction_messages.size() == 0:
		return result

	var combined_message: String = "\n".join(reaction_messages)

	if result.has("message") and result["message"] != "":
		combined_message += "\n" + str(result["message"])

	result["message"] = combined_message
	return result


func get_component(target: Node, component_name: String) -> Node:
	if target == null:
		return null

	return target.get_node_or_null(component_name)


func get_debug_data() -> Dictionary:
	return {
		"last": last_payload_summary,
		"rx": last_reaction_summary,
		"rx_visual": str(last_reaction_data.get("visual_style", "none")),
	}


func apply_force(target: Node, payload: DamagePayload) -> void:
	if payload.knockback_strength <= 0.0 and payload.knockback_up_strength <= 0.0:
		return

	var force_receiver: Node = get_component(target, "ForceReceiver")

	if force_receiver == null:
		return

	if not force_receiver.has_method("apply_impulse"):
		return

	var source_position: Vector3 = get_payload_source_position(payload)
	var target_position: Vector3 = get_target_position(target)
	var direction: Vector3 = target_position - source_position

	force_receiver.apply_impulse(
		direction,
		payload.knockback_strength,
		payload.knockback_up_strength,
		payload.source_name
	)


func apply_airborne_reaction(target: Node, payload: DamagePayload) -> void:
	var airborne_controller: Node = get_component(target, "AirborneReactionController")
	if airborne_controller == null or not airborne_controller.has_method("register_payload"):
		return
	airborne_controller.call("register_payload", payload)


func get_payload_source_position(_payload: DamagePayload) -> Vector3:
	var player: Node3D = get_tree().get_first_node_in_group("player")

	if player != null:
		return player.global_position

	return Vector3.ZERO


func get_target_position(target: Node) -> Vector3:
	if target is Node3D:
		return target.global_position

	var parent: Node = target.get_parent()

	if parent is Node3D:
		return parent.global_position

	return Vector3.ZERO
