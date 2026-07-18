extends RefCounted
class_name ReactionBurstResolver

const CombatFeedbackScript = preload("res://scripts/combat/combat_feedback.gd")


static func apply_area_effect(
	rule: Resource,
	source: Node,
	origin: Vector3
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var radius: float = get_rule_float(rule, "area_effect_radius", 0.0)

	if rule == null or source == null or radius <= 0.0:
		return results

	var world: World3D = get_world_3d(source)
	if world == null:
		return results

	var shape := SphereShape3D.new()
	shape.radius = radius

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), origin)
	query.collision_mask = 0xFFFFFFFF
	query.collide_with_bodies = true
	query.collide_with_areas = true

	var overlaps: Array[Dictionary] = world.direct_space_state.intersect_shape(query, 96)
	var seen_targets: Dictionary = {}

	for overlap: Dictionary in overlaps:
		var collider: Node = overlap.get("collider") as Node
		var target: Node = find_reaction_target(collider)

		if target == null or is_source_branch(target, source):
			continue

		var target_id: int = target.get_instance_id()
		if seen_targets.has(target_id):
			continue

		seen_targets[target_id] = true
		results.append(apply_effect_to_target(rule, target, origin))

	return results


static func apply_effect_to_target(
	rule: Resource,
	target: Node,
	origin: Vector3
) -> Dictionary:
	var status_name: String = get_rule_string(rule, "area_output_status", "")
	var status_duration: float = get_rule_float(rule, "area_output_status_duration", 0.0)
	var status_strength: float = get_rule_float(rule, "area_output_status_strength", 1.0)
	var source_name: String = get_rule_string(
		rule,
		"area_output_status_source",
		get_rule_string(rule, "reaction_name", "Reaction Burst")
	)
	var applied_status: bool = false

	var status_receiver: Node = target.get_node_or_null("StatusReceiver")
	if (
		status_name != ""
		and status_duration > 0.0
		and status_receiver != null
		and status_receiver.has_method("apply_status")
	):
		status_receiver.apply_status(
			status_name,
			status_duration,
			status_strength,
			source_name
		)
		applied_status = true

	var area_damage: int = get_rule_int(rule, "area_output_damage", 0)
	var area_stance_damage: int = get_rule_int(rule, "area_output_stance_damage", 0)
	var payload_result: Dictionary = {}

	if area_damage > 0 or area_stance_damage > 0:
		var hit_receiver: Node = target.get_node_or_null("HitReceiver")
		if hit_receiver != null and hit_receiver.has_method("receive_payload"):
			var payload := DamagePayload.new()
			payload.amount = area_damage
			payload.stance_damage = area_stance_damage
			payload.element = get_rule_string(rule, "area_output_element", "neutral")
			payload.source_name = get_rule_string(rule, "reaction_name", "Reaction Burst")
			payload.hit_type = "reaction_burst"
			payload.tags = get_rule_string_array(rule, "area_output_tags")
			payload_result = hit_receiver.receive_payload(payload)

	var force_strength: float = get_rule_float(rule, "area_force_strength", 0.0)
	var force_up_strength: float = get_rule_float(rule, "area_force_up_strength", 0.0)
	var force_applied: bool = false
	var force_receiver: Node = target.get_node_or_null("ForceReceiver")

	if (
		(force_strength > 0.0 or force_up_strength > 0.0)
		and force_receiver != null
		and force_receiver.has_method("apply_impulse")
	):
		var direction: Vector3 = get_target_position(target) - origin
		direction.y = 0.0
		if direction.length() <= 0.01:
			direction = Vector3.FORWARD
		force_receiver.apply_impulse(
			direction,
			force_strength,
			force_up_strength,
			get_rule_string(rule, "reaction_name", "Reaction Burst")
		)
		force_applied = true

	if applied_status and get_rule_bool(rule, "area_show_status_feedback", true):
		CombatFeedbackScript.show_status_feedback(target, status_name)

	return {
		"target": target.name,
		"status": status_name if applied_status else "none",
		"damage": area_damage,
		"stance_damage": area_stance_damage,
		"force": force_applied,
		"payload_result": payload_result,
	}


static func find_reaction_target(start_node: Node) -> Node:
	var current: Node = start_node

	while current != null:
		if has_reaction_receivers(current):
			return current
		current = current.get_parent()

	return null


static func has_reaction_receivers(node: Node) -> bool:
	if node == null:
		return false

	return (
		node.get_node_or_null("StatusReceiver") != null
		or node.get_node_or_null("HitReceiver") != null
		or node.get_node_or_null("ForceReceiver") != null
	)


static func is_source_branch(target: Node, source: Node) -> bool:
	if target == source:
		return true
	if target.is_ancestor_of(source):
		return true
	if source.is_ancestor_of(target):
		return true
	return false


static func get_world_3d(node: Node) -> World3D:
	var current: Node = node
	while current != null:
		if current is Node3D:
			return (current as Node3D).get_world_3d()
		current = current.get_parent()
	return null


static func get_target_position(target: Node) -> Vector3:
	if target is Node3D:
		return (target as Node3D).global_position

	var parent: Node = target.get_parent()
	if parent is Node3D:
		return (parent as Node3D).global_position

	return Vector3.ZERO


static func get_rule_string(rule: Resource, property_name: String, fallback: String = "") -> String:
	if rule == null:
		return fallback
	var value: Variant = rule.get(property_name)
	return fallback if value == null else str(value)


static func get_rule_int(rule: Resource, property_name: String, fallback: int = 0) -> int:
	if rule == null:
		return fallback
	var value: Variant = rule.get(property_name)
	return fallback if value == null else int(value)


static func get_rule_float(rule: Resource, property_name: String, fallback: float = 0.0) -> float:
	if rule == null:
		return fallback
	var value: Variant = rule.get(property_name)
	return fallback if value == null else float(value)


static func get_rule_bool(rule: Resource, property_name: String, fallback: bool = false) -> bool:
	if rule == null:
		return fallback
	var value: Variant = rule.get(property_name)
	return fallback if value == null else bool(value)


static func get_rule_string_array(rule: Resource, property_name: String) -> Array[String]:
	var result: Array[String] = []
	if rule == null:
		return result

	var value: Variant = rule.get(property_name)
	if not value is Array:
		return result

	for raw_value: Variant in value as Array:
		var text: String = str(raw_value)
		if text != "":
			result.append(text)

	return result
